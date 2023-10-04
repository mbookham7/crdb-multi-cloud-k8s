#!/bin/sh

export rg="mb-eu-multi-cloud-demo"
export az_region="uksouth"
export clus1="mb-uksouth-aks-cluster-1"
export vm_type="Standard_D8s_v3"
export n_nodes="3"
export az_kubernetes_version="1.26"
export az_vnet_addressspace="10.1.0.0/16"
export az_subnet_prefix="10.1.16.0/20"
export az_vpn_gw="mb-az-vnet-gateway"
export az_vpn_gateway_ip="mb-az-vnet-gateway-ip"

export aws_region="eu-west-1"
export aws_vpc_cidr="10.2.0.0/16"
export clus2="mb-eu-eks-cluster-1"
export aws_kubernetes_version="1.26"

export gcp_region="europe-west4"
export gcp_vpc_cidr="10.3.0.0/16"
export clus3="mb-eu-gke-cluster-1"
export gke_vcp_sub="mb-eu-gke-vcp-sub"
export gcp_vcp_name="mb-eu-gke-vcp-1"
export gcp_mtu_size="1460"
export gcp_dynamic_routing_mode="global"
export gke_machine_type="e2-standard-8"
export gcp_mb_gke_gw="mb-eu-gke-gw-1"
export gcp_gw_ip_name="mb-eu-gke-gw-ip-1"
export gcp_project="cockroach-bookham"
export cluster_pod_ip_range="10.4.0.0/14"
export gcp_kubernetes_version="1.26"

# Delete the resources from Azure
az group delete --resource-group $rg -y


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
aws_vpc_id=$(aws ec2 describe-vpcs --region $aws_region --filter "Name=tag:alpha.eksctl.io/cluster-name,Values=$clus2" --query "Vpcs[*].[VpcId]" --output text)
aws ec2 detach-vpn-gateway --vpn-gateway-id $aws_vpngateway_id --vpc-id $aws_vpc_id --region $aws_region
sleep 120
aws ec2 delete-vpn-gateway --vpn-gateway-id $aws_vpngateway_id --region $aws_region
sleep 120
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

# Delete VPC
gcloud compute networks delete $gcp_vcp_name --project=$gcp_project --quiet

rm -r certs my-safe-directory
