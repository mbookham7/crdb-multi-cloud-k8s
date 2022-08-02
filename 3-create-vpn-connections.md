# Create a VPN tunnels between Azure, AWS and Google

## Create AWS VPN Tunnel to Azure

1. Create a Customer Gateway in AWS. This will require the Public IP address of the Azure Virtual Gateway.

Retrieve the IP of the Azure VPN Gateway and add to a variable.
```
az_vpn_gateway_ip_add=$(az network public-ip show -g $rg -n $az_vpn_gateway_ip --query "{address: ipAddress}" --output tsv) 
```

```
aws ec2 create-customer-gateway --type ipsec.1 --public-ip $az_vpn_gateway_ip_add --bgp-asn 65534 --region $aws_region --tag-specifications 'ResourceType=customer-gateway,Tags=[{Key=Name,Value=$clus2-cg-azure}]'
```

## AWS Create a VPN Connection

With the customer gateway created in the AWS with the details of the Azure Virtual Gateway we can now standup the first end of the VPN tunnel. The below command obtains the Customer Gateway ID and adds it to an environment variable.
```
aws_customergateway_id=$(aws ec2 describe-customer-gateways --region $aws_region --filter "Name=tag:Name,Values=$clus2-cg-azure" --query "VpnConnections[*].[VpnConnectionId]" --output text)
```

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
aws_vpn_connection_id_azure=$(aws ec2 describe-vpn-connections --region $aws_region --filter "Name=tag:Name,Values=$clus2-vpn-to-azure" --query "VpnConnections[*].[VpnConnectionId]" --output text)
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

Add a route to the AWS routing table to send traffic intended for Azure over the VPN Tunnel.
```
aws ec2 create-route --route-table-id rtb-05eb431805f4de46c --region $aws_region --destination-cidr-block $az_vnet_addressspace --gateway-id $aws_vpngateway_id
```

## Azure Create a VPN connection

Now that we have all the required values in environment variable we can create the two local network gateways in Azure.
```
az network local-gateway create -g $rg -n $clus1-aws-vpn-1 \
    --gateway-ip-address $aws_vpn_outsideipaddress_1 --local-address-prefixes $aws_vpc_cidr

az network local-gateway create -g $rg -n $clus1-aws-vpn-2 \
    --gateway-ip-address $aws_vpn_outsideipaddress_2 --local-address-prefixes $aws_vpc_cidr
```

Create two VPN connections in Azure.
```
az network vpn-connection create -g $rg -l $azregion -n $clus1-aws-vpn-con-1 --vnet-gateway1 $az_vpn_gw --local-gateway2 $clus1-aws-vpn-1 --shared-key $aws_vpn_presharedkey_1

az network vpn-connection create -g $rg -l $azregion -n $clus1-aws-vpn-con-2 --vnet-gateway1 $az_vpn_gw --local-gateway2 $clus1-aws-vpn-2 --shared-key $aws_vpn_presharedkey_2
```

## GCP Create a VPN Connection to Azure





Add security group rules in all three clouds for each Cluster
