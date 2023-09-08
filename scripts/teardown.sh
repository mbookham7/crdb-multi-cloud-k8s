#!/bin/sh

# Delete the resources from Azure
az group delete --resource-group $rg


# Delete AWS Resources
# Remove VPN connections
aws_vpn_connection_id_azure=$(aws ec2 describe-vpn-connections --region $aws_region --filter "Name=tag:Name,Values=$clus2-vpn-to-azure" --query "VpnConnections[?State=='available'].[VpnConnectionId]" --output text)
aws ec2 delete-vpn-connection --region $aws_region --vpn-connection-id $aws_vpn_connection_id_azure
aws_vpn_connection_id_gcp=$(aws ec2 describe-vpn-connections --region $aws_region --filter "Name=tag:Name,Values=$clus2-vpn-to-gcp" --query "VpnConnections[?State=='available'].[VpnConnectionId]" --output text)
aws ec2 delete-vpn-connection --region $aws_region --vpn-connection-id $aws_vpn_connection_id_gcp
# Delete the Customer Gateways
aws_customergateway_id=$(aws ec2 describe-customer-gateways --region $aws_region --filter "Name=tag:Name,Values=$clus2-cg-azure" --query "CustomerGateways[?State=='available'].[CustomerGatewayId]" --output text)
aws ec2 delete-customer-gateway --region $aws_region --customer-gateway-id $aws_customergateway_id
aws_customergateway_id_gcp=$(aws ec2 describe-customer-gateways --region $aws_region --filter "Name=tag:Name,Values=$clus2-cg-gcp" --query "CustomerGateways[?State=='available'].[CustomerGatewayId]" --output text)
aws ec2 delete-customer-gateway --region $aws_region --customer-gateway-id $aws_customergateway_id_gcp
# Delete VPN device
aws_vpngateway_id=$(aws ec2 describe-vpn-gateways --region $aws_region --filter "Name=tag:Name,Values=$clus2" --query "VpnGateways[*].[VpnGatewayId]" --output text)
aws ec2 detach-vpn-gateway --vpn-gateway-id $aws_vpngateway_id --vpc-id $aws_vpc_id --region $aws_region
sleep 2m
aws_vpc_id=$(aws ec2 describe-vpcs --region $aws_region --filter "Name=tag:alpha.eksctl.io/cluster-name,Values=$clus2" --query "Vpcs[*].[VpcId]" --output text)
aws ec2 delete-vpn-gateway --vpn-gateway-id $aws_vpngateway_id --region $aws_region
sleep 2m
# Delete EKS Cluster
eksctl delete cluster --name $clus2 --region $aws_region


# Delete Google Resources
# Delete VPN TUnnels
gcloud compute vpn-tunnels delete $clus3-azure-vpn-con-1 --region=$gcp_region --project=$gcp_project --quiet
gcloud compute vpn-tunnels delete $clus3-aws-vpn-con-1 --region=$gcp_region --project=$gcp_project --quiet

# Delete Forwarding rules
gcloud compute forwarding-rules delete fr-$gcp_mb_gke_gw-udp4500 --region=$gcp_region --project=$gcp_project --quiet
gcloud compute forwarding-rules delete fr-$gcp_mb_gke_gw-udp500 --region=$gcp_region --project=$gcp_project --quiet
gcloud compute forwarding-rules delete fr-$gcp_mb_gke_gw-esp --region=$gcp_region --project=$gcp_project --quiet

# Delete VPN Device
gcloud compute target-vpn-gateways delete $gcp_mb_gke_gw  --region=$gcp_region --project=$gcp_project --quiet
gcloud compute addresses delete $gcp_gw_ip_name   --region=$gcp_region --project=$gcp_project --quiet

# Delete GKE Cluster
gcloud container clusters delete $clus3  --region=$gcp_region --project=$gcp_project --quiet

# Delete firewall rules
gcloud compute firewall-rules delete allowazureandaws --quiet
gcloud compute firewall-rules delete allowsshping --quiet

# Delete VPN
gcloud compute networks delete $gcp_vcp_name --project=$gcp_project --quiet

rm -r certs my-safe-directory
