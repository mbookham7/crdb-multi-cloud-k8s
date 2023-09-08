# Create a Kubernetes cluster in Azure, AWS and Google

First we are going to set a number of variables please update these to reflect your environment. IP subnets must not overlap or you will face routing issues!!

```
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
```

## Cloud One - Azure

### Create AKS cluster

Next thing we need to do is to create a resource group to store all of the resources we create.
```
az group create --name $rg --location $az_region
```

Create a virtual network within the specified region along with a subnet.
```
az network vnet create -g $rg -n crdb-$az_region --address-prefix $az_vnet_addressspace \
    --subnet-name crdb-$az-region-sub1 --subnet-prefix $az_subnet_prefix
```

Create the AKS cluster and place it on the subnet created in the previous step. To do this we first need to get the subnet ID using the `az network vnet subnet list` command.
```
loc1subid=$(az network vnet subnet list --resource-group $rg --vnet-name crdb-$az_region | jq -r '.[].id')
```

Now that we have stored the subnet ID as an environment variable we can create the AKS cluster.
```
az aks create \
--name $clus1 \
--resource-group $rg \
--network-plugin azure \
--zones 1 2 3 \
--vnet-subnet-id $loc1subid \
--node-vm-size $vm_type \
--node-count $n_nodes \
--kubernetes-version $az_kubernetes_version
```

Store the Kubeconfig
```
az aks get-credentials --resource-group $rg --name $clus1
```

## Cloud Two - AWS

### Create EKS Cluster

Next we are going to create an EKS cluster in AWS. We are going to use the `eksctl` CLI tool to do this.
```
eksctl create cluster \
--name $clus2 \
--nodegroup-name standard-workers \
--node-type m5.2xlarge \
--nodes 3 \
--region $aws_region \
--vpc-cidr $aws_vpc_cidr \
--version $aws_kubernetes_version
```

In EKS you need to install the AWS EBS CSI Driver. Follow the next three steps to deploy.
```
eksctl utils associate-iam-oidc-provider --region=$aws_region --cluster=$clus2 --approve
```

Create and IAM Service Account for the cluster.
```
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster $clus2 \
  --region $aws_region \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --role-only \
  --role-name AmazonEKS_EBS_CSI_DriverRole_$clus2
```

Create the addon with the role.
```
eksctl create addon --name aws-ebs-csi-driver --cluster $clus2 --region $aws_region --service-account-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/AmazonEKS_EBS_CSI_DriverRole_$clus2 --force
```

## Cloud Three - GCP

### Create GKE Cluster

Next we created a Virtual Private Network along with a subnet. First command is to create the network.
```
gcloud compute networks create $gcp_vcp_name \
    --subnet-mode=auto \
    --bgp-routing-mode=$gcp_dynamic_routing_mode \
    --mtu=$gcp_mtu_size \
    --project=$gcp_project
```

Then create the subnet.
```
gcloud compute networks subnets create $gke_vcp_sub \
    --network=$gcp_vcp_name \
    --range=$gcp_vpc_cidr \
    --region=$gcp_region \
    --project=$gcp_project
```

Create Firewall rules.
```
gcloud compute firewall-rules create allowazureandaws --network $gcp_vcp_name --allow tcp,udp,icmp --source-ranges $aws_vpc_cidr,$az_subnet_prefix --project=$gcp_project
gcloud compute firewall-rules create allowsshping --network $gcp_vcp_name --allow tcp:22,icmp --project=$gcp_project
```

Now we have the network with the required IP addressing.
```
gcloud container clusters create $clus3 \
    --region=$gcp_region \
    --enable-ip-alias \
    --network=$gcp_vcp_name \
    --machine-type=$gke_machine_type \
    --cluster-ipv4-cidr=$cluster_pod_ip_range \
    --subnetwork=$gke_vcp_sub \
    --cluster-version=$gcp_kubernetes_version \
    --project=$gcp_project
```

[next](2-create-vpn-devices.md)