# Create a VPN tunnels between Azure, AWS and Google

## Create AWS VPN Tunnel to Azure

Create a Customer Gateway in AWS. This will require the Public IP address of the Azure Virtual Gateway.

Retrieve the IP of the Azure VPN Gateway and add to a variable.
```
az_vpn_gateway_ip_add=$(az network public-ip show -g $rg -n $az_vpn_gateway_ip --query "{address: ipAddress}" --output tsv) 
```
Create the Customer Gateway in AWS.
```
aws ec2 create-customer-gateway --type ipsec.1 --public-ip $az_vpn_gateway_ip_add --bgp-asn 65534 --region $aws_region --tag-specifications 'ResourceType=customer-gateway,Tags=[{Key=Name,Value='$clus2'-cg-azure}]'
```

Create the VPN Connection in AWS

With the customer gateway created in the AWS with the details of the Azure Virtual Gateway we can now standup the first end of the VPN tunnel. The below command obtains the Customer Gateway ID and adds it to an environment variable.
```
aws_customergateway_id=$(aws ec2 describe-customer-gateways --region $aws_region --filter "Name=tag:Name,Values=$clus2-cg-azure" --query "CustomerGateways[?State=='available'].[CustomerGatewayId]" --output text)
```

Now we create the VPN Connection in AWS using the details we have added to environment variables.
```
aws ec2 create-vpn-connection \
    --type ipsec.1 \
    --region $aws_region \
    --customer-gateway-id $aws_customergateway_id \
    --vpn-gateway-id $aws_vpngateway_id \
    --options "{\"StaticRoutesOnly\":true,\"LocalIpv4NetworkCidr\": \"10.1.0.0/16\"}" \
    --tag-specifications 'ResourceType=vpn-connection,Tags=[{Key=Name,Value='$clus2-vpn-to-azure'}]'
```

Once created get the VPN connection id and add this to an environment variable.
```
aws_vpn_connection_id_azure=$(aws ec2 describe-vpn-connections --region $aws_region --filter "Name=tag:Name,Values=$clus2-vpn-to-azure" --query "VpnConnections[?State=='available'].[VpnConnectionId]" --output text)
```

Add a route to the VPN Connection
```
aws ec2 create-vpn-connection-route --region $aws_region --vpn-connection-id $aws_vpn_connection_id_azure --destination-cidr-block 10.1.0.0/16
```

To complete the creation of the VPN we need to create the connection on the Azure side, however before we do this we need the Virtual Private Gateway Address for each tunnel along with both PSK's for each tunnel as well. We will store these as environment variables.
```
aws_vpn_outsideipaddress_1=$(aws ec2 describe-vpn-connections --region $aws_region --filter "Name=tag:Name,Values=$clus2-vpn-to-azure" --query "VpnConnections[*].Options.TunnelOptions[].OutsideIpAddress| [0]" --output text)
aws_vpn_outsideipaddress_2=$(aws ec2 describe-vpn-connections --region $aws_region --filter "Name=tag:Name,Values=$clus2-vpn-to-azure" --query "VpnConnections[*].Options.TunnelOptions[].OutsideIpAddress| [1]" --output text)

aws_vpn_presharedkey_1=$(aws ec2 describe-vpn-connections --region $aws_region --filter "Name=tag:Name,Values=$clus2-vpn-to-azure" --query "VpnConnections[*].Options.TunnelOptions[].PreSharedKey| [0]" --output text)
aws_vpn_presharedkey_2=$(aws ec2 describe-vpn-connections --region $aws_region --filter "Name=tag:Name,Values=$clus2-vpn-to-azure" --query "VpnConnections[*].Options.TunnelOptions[].PreSharedKey| [1]" --output text)
```

Add a route to the AWS routing table to send traffic intended for Azure over the VPN Tunnel. First we need to grab the routing table id and add this to a variable.
```
aws_route_table_id=$(aws ec2 describe-route-tables --region $aws_region --filter "Name=tag:Name,Values=eksctl-$clus2-cluster/PublicRouteTable" --query "RouteTables[*].[RouteTableId]" --output text)
```

Now we have the routing table ID we can add the relevant route.
```
aws ec2 create-route --route-table-id $aws_route_table_id --region $aws_region --destination-cidr-block $az_subnet_prefix --gateway-id $aws_vpngateway_id
```

Create the VPN Connection in Azure.

Now that we have all the required values in environment variable we can create the two local network gateways in Azure.
```
az network local-gateway create -g $rg -n $clus1-aws-vpn-1 \
    --gateway-ip-address $aws_vpn_outsideipaddress_1 --local-address-prefixes $aws_vpc_cidr

az network local-gateway create -g $rg -n $clus1-aws-vpn-2 \
    --gateway-ip-address $aws_vpn_outsideipaddress_2 --local-address-prefixes $aws_vpc_cidr
```

Create two VPN connections in Azure.
```
az network vpn-connection create -g $rg -l $az_region -n $clus1-aws-vpn-con-1 --vnet-gateway1 $az_vpn_gw --local-gateway2 $clus1-aws-vpn-1 --shared-key $aws_vpn_presharedkey_1

az network vpn-connection create -g $rg -l $az_region -n $clus1-aws-vpn-con-2 --vnet-gateway1 $az_vpn_gw --local-gateway2 $clus1-aws-vpn-2 --shared-key $aws_vpn_presharedkey_2
```

## GCP Create a VPN Connection to Azure

Create a VPN connection in GCP.

Create Pre-Shared key to be used for the VPN tunnel.
```
gcp_vpn_presharedkey_1=$(openssl rand -base64 24)
```

Create the route-based tunnel in GCP to Azure.
```
gcloud compute vpn-tunnels create $clus3-azure-vpn-con-1 \
    --peer-address=$az_vpn_gateway_ip_add \
    --ike-version=2 \
    --shared-secret=$gcp_vpn_presharedkey_1 \
    --local-traffic-selector=0.0.0.0/0 \
    --remote-traffic-selector=0.0.0.0/0 \
    --target-vpn-gateway=$gcp_mb_gke_gw \
    --region=$gcp_region \
    --project=$gcp_project
```

Create a route to route the correct subnet across the VPN.
```
gcloud compute routes create $clus3-azure-route-1 \
    --destination-range=$az_subnet_prefix \
    --next-hop-vpn-tunnel=$clus3-azure-vpn-con-1 \
    --network=$gcp_vcp_name \
    --next-hop-vpn-tunnel-region=$gcp_region \
    --project=$gcp_project
```

Now we are going to create the configuration on the Azure side. First we need to gather the required information for the Local Network Gateway on the Azure side, starting with the outside IP address of the VPN appliance in GCP.
```
gcp_vpn_outsideipaddress=$(gcloud compute addresses describe $gcp_gw_ip_name \
   --region=$gcp_region \
   --project=$gcp_project \
   --format='value(address)')
```

Create the local network gateway in Azure.
```
az network local-gateway create -g $rg -n $clus3-gcp-vpn-1 \
    --gateway-ip-address $gcp_vpn_outsideipaddress --local-address-prefixes $gcp_vpc_cidr $cluster_pod_ip_range
```

Create the VPN connection with GCP
```
az network vpn-connection create -g $rg -l $az_region -n $clus3-gcp-vpn-con-1 --vnet-gateway1 $az_vpn_gw --local-gateway2 $clus3-gcp-vpn-1 --shared-key $gcp_vpn_presharedkey_1
```

## AWS Create VPN to Google Cloud Platform

Create a Local Gateway in AWS for the GCP VPN device.
```
aws ec2 create-customer-gateway --type ipsec.1 --public-ip $gcp_vpn_outsideipaddress --bgp-asn 65536 --region $aws_region --tag-specifications 'ResourceType=customer-gateway,Tags=[{Key=Name,Value='$clus2'-cg-gcp}]'
```

The next task is to create vpn connection in AWS to GCP. First obtain the customer gateway id and store this in an environment variable.
```
aws_customergateway_id_gcp=$(aws ec2 describe-customer-gateways --region $aws_region --filter "Name=tag:Name,Values=$clus2-cg-gcp" --query "CustomerGateways[?State=='available'].[CustomerGatewayId]" --output text)
```

Now create the connection itself in AWS.
```
aws ec2 create-vpn-connection \
    --type ipsec.1 \
    --region $aws_region \
    --customer-gateway-id $aws_customergateway_id_gcp \
    --vpn-gateway-id $aws_vpngateway_id \
    --options "{\"StaticRoutesOnly\":true,\"LocalIpv4NetworkCidr\": \"10.4.0.0/14"}" \
    --tag-specifications 'ResourceType=vpn-connection,Tags=[{Key=Name,Value='$clus2-vpn-to-gcp'}]'
```

Once created get the VPN connection id and add this to an environment variable.
```
aws_vpn_connection_id_gcp=$(aws ec2 describe-vpn-connections --region $aws_region --filter "Name=tag:Name,Values=$clus2-vpn-to-gcp" --query "VpnConnections[?State=='available'].[VpnConnectionId]" --output text)
```

Add a route to the VPN Connection
```
aws ec2 create-vpn-connection-route --region $aws_region --vpn-connection-id $aws_vpn_connection_id_gcp --destination-cidr-block $cluster_pod_ip_range
```

To complete the creation of the VPN we need to create the connection on the GCP side, however before we do this we need the Virtual Private Gateway Address for each tunnel along with both PSK's for each tunnel as well. We will store these as environment variables.
```
aws_vpn_outsideipaddress_3=$(aws ec2 describe-vpn-connections --region $aws_region --filter "Name=tag:Name,Values=$clus2-vpn-to-gcp" --query "VpnConnections[*].Options.TunnelOptions[].OutsideIpAddress| [0]" --output text)
aws_vpn_outsideipaddress_4=$(aws ec2 describe-vpn-connections --region $aws_region --filter "Name=tag:Name,Values=$clus2-vpn-to-gcp" --query "VpnConnections[*].Options.TunnelOptions[].OutsideIpAddress| [1]" --output text)

aws_vpn_presharedkey_3=$(aws ec2 describe-vpn-connections --region $aws_region --filter "Name=tag:Name,Values=$clus2-vpn-to-azure" --query "VpnConnections[*].Options.TunnelOptions[].PreSharedKey| [0]" --output text)
aws_vpn_presharedkey_4=$(aws ec2 describe-vpn-connections --region $aws_region --filter "Name=tag:Name,Values=$clus2-vpn-to-azure" --query "VpnConnections[*].Options.TunnelOptions[].PreSharedKey| [1]" --output text)
```

Add a route to the AWS routing table to send traffic intended for GCP over the VPN Tunnel. First we need to grab the routing table id and add this to a variable.
```
aws_route_table_id=$(aws ec2 describe-route-tables --region $aws_region --filter "Name=tag:Name,Values=eksctl-$clus2-cluster/PublicRouteTable" --query "RouteTables[*].[RouteTableId]" --output text)
```

Now we have the routing table ID we can add the relevant route.
```
aws ec2 create-route --route-table-id $aws_route_table_id --region $aws_region --destination-cidr-block $cluster_pod_ip_range --gateway-id $aws_vpngateway_id
```

Now create the corresponding end of the tunnel in GCP. Create the route-based tunnel in GCP to AWS.
```
gcloud compute vpn-tunnels create $clus3-aws-vpn-con-1 \
    --peer-address=$aws_vpn_outsideipaddress_3 \
    --ike-version=2 \
    --shared-secret=$aws_vpn_presharedkey_3 \
    --local-traffic-selector=0.0.0.0/0 \
    --remote-traffic-selector=0.0.0.0/0 \
    --target-vpn-gateway=$gcp_mb_gke_gw \
    --region=$gcp_region \
    --project=$gcp_project
```

Create a route to route the correct subnet across the VPN.
```
gcloud compute routes create $clus3-aws-route-1 \
    --destination-range=$aws_vpc_cidr \
    --next-hop-vpn-tunnel=$clus3-aws-vpn-con-1 \
    --network=$gcp_vcp_name \
    --next-hop-vpn-tunnel-region=$gcp_region \
    --project=$gcp_project
```

Create a second resilient connection

```
gcloud compute vpn-tunnels create $clus3-aws-vpn-con-2 \
    --peer-address=$aws_vpn_outsideipaddress_4 \
    --ike-version=2 \
    --shared-secret=$aws_vpn_presharedkey_4 \
    --local-traffic-selector=0.0.0.0/0 \
    --remote-traffic-selector=0.0.0.0/0 \
    --target-vpn-gateway=$gcp_mb_gke_gw \
    --region=$gcp_region \
    --project=$gcp_project
```

Create a route to route the correct subnet across the VPN.
```
gcloud compute routes create $clus3-aws-route-2 \
    --destination-range=$aws_vpc_cidr \
    --next-hop-vpn-tunnel=$clus3-aws-vpn-con-2 \
    --network=$gcp_vcp_name \
    --next-hop-vpn-tunnel-region=$gcp_region \
    --project=$gcp_project
```

Add security group rules in all three clouds for each Cluster.


[next](4-test-network-connections.md)
