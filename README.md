# UNDER DEVELOPMENT

# CockroachDB Multi Cloud Kubernetes Deployment 

In this demo you will deploy a Kubernetes cluster into each of the cloud providers using their hosted offerings. Once this is deployed you will join the networks together using VPNs, and deploy CockroachDB across all three cloud providers.

This demo will be broken down into a number of stages.

1. Create a Kubernetes cluster in Azure, AWS and Google.
2. Create VPN connections between the three clouds.
3. Configure DNS resolution across the three Kubernetes clusters.
4. Deploy CockroachDB across the three cloud providers.

```
export rg="mb-eu-multi-cloud-demo"
export azregion="uksouth"
export clus1="mb-uksouth-aks-cluster-1"
export vm_type="Standard_D8s_v3"
export n_nodes="3"
export az_kubernetes_version="1.23"
export az_vnet_addressspace="10.1.0.0/16"
export az_subnet_prefix="10.1.16.0/20"
export az_vpn_gw="mb-az-vnet-gateway"
export az_vpn_gateway_ip="mb-az-vnet-gateway-ip"

export aws_region="eu-west-1"
export aws_vpc_cidr="10.2.0.0/16"
export clus2="mb-eu-eks-cluster-1"
export aws_kubernetes_version="1.23"

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
export gcp_project="cockroach-dsheldon"
export cluster_pod_ip_range="10.4.0.0/14"
export gcp_kubernetes_version="1.23"
```