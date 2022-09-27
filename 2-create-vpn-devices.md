# Create a VPN Device in Azure, AWS and Google

## Cloud One - Azure

First thing we need to do is to create a `GatewaySubnet`. This is a requirement for a VPN Gateway in Azure. This subnet must be called `GatewaySubnet`.
```
az network vnet subnet create \
  --vnet-name crdb-$azregion \
  -n GatewaySubnet \
  -g $rg \
  --address-prefix 10.1.255.0/27
```

Next we need to create a Public IP for our VPN Gateway.
```
az network public-ip create --name $az_vpn_gateway_ip --resource-group $rg --allocation-method Dynamic
```

With the subnet created we can create our VPN Gateway.
```
az network vnet-gateway create -g $rg -n $az_vpn_gw --public-ip-address $az_vpn_gateway_ip \
    --vnet crdb-$azregion --gateway-type Vpn --sku VpnGw1 --vpn-type RouteBased --no-wait
```

## Cloud Two - AWS

With AWS you create the VPN Gateway first then attach this to a VPC. The below command to creates the VPN Gateway. We are adding a tag of the cluster name so we can use this to reference it in a later step.
```
aws ec2 create-vpn-gateway --type ipsec.1 --region $aws_region --tag-specifications 'ResourceType=vpn-gateway,Tags=[{Key=Name,Value='$clus2'}]'
```
To attach the VPN Gateway to a VPC we need to pieces of information, the VPC ID and the VPN Gateway ID. We will get these and add them as environment variables. We can the substitute these variables into our command for ease of use.
```
aws_vpc_id=$(aws ec2 describe-vpcs --region $aws_region --filter "Name=tag:alpha.eksctl.io/cluster-name,Values=$clus2" --query "Vpcs[*].[VpcId]" --output text)

aws_vpngateway_id=$(aws ec2 describe-vpn-gateways --region $aws_region --filter "Name=tag:Name,Values=$clus2" --query "VpnGateways[*].[VpnGatewayId]" --output text)
```

Now attach the VPN Gateway to the VPC.
```
aws ec2 attach-vpn-gateway --vpn-gateway-id $aws_vpngateway_id --vpc-id $aws_vpc_id --region $aws_region
```

## Cloud Three - GCP

Create the target VPN gateway object:

```
gcloud compute target-vpn-gateways create $gcp_mb_gke_gw \
   --network=$gcp_vcp_name \
   --region=$gcp_region \
   --project=$gcp_project
```

Reserve a regional external (static) IP address:
```
gcloud compute addresses create $gcp_gw_ip_name \
   --region=$gcp_region \
   --project=$gcp_project
```
Note the IP address (so you can use it when you configure your peer VPN gateway):
```
gcloud compute addresses describe $gcp_gw_ip_name \
   --region=$gcp_region \
   --project=$gcp_project \
   --format='flattened(address)'
```

Create three forwarding rules; these rules instruct Google Cloud to send ESP (IPsec), UDP 500, and UDP 4500 traffic to the gateway:
```
gcloud compute forwarding-rules create fr-$gcp_mb_gke_gw-esp \
   --load-balancing-scheme=EXTERNAL \
   --network-tier=PREMIUM \
   --ip-protocol=ESP \
   --address=$gcp_gw_ip_name \
   --target-vpn-gateway=$gcp_mb_gke_gw \
   --region=$gcp_region \
   --project=$gcp_project
```
```
gcloud compute forwarding-rules create fr-$gcp_mb_gke_gw-udp500 \
   --load-balancing-scheme=EXTERNAL \
   --network-tier=PREMIUM \
   --ip-protocol=UDP \
   --ports=500 \
   --address=$gcp_gw_ip_name \
   --target-vpn-gateway=$gcp_mb_gke_gw \
   --region=$gcp_region \
   --project=$gcp_project
```
```
gcloud compute forwarding-rules create fr-$gcp_mb_gke_gw-udp4500 \
   --load-balancing-scheme=EXTERNAL \
   --network-tier=PREMIUM \
   --ip-protocol=UDP \
   --ports=4500 \
   --address=$gcp_gw_ip_name \
   --target-vpn-gateway=$gcp_mb_gke_gw \
   --region=$gcp_region \
   --project=$gcp_project
```
[next](3-create-vpn-connections.md)