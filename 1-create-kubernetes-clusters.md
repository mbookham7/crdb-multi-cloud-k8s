# Create a Kubernetes cluster in Azure, AWS and Google

## Cloud One - Azure

### Create AKS cluster

Next thing we need to do is to create a resource group to store all of the resources we create.
```
az group create --name $rg --location $azregion
```

Create a virtual network within the specified region along with a subnet.
```
az network vnet create -g $rg -n crdb-$azregion --address-prefix $az_vnet_addressspace \
    --subnet-name crdb-$az-region-sub1 --subnet-prefix $az_subnet_prefix
```

Create the AKS cluster and place it on the subnet created in the previous step. To do this we first need to get the subnet ID using the `az network vnet subnet list` command.
```
loc1subid=$(az network vnet subnet list --resource-group $rg --vnet-name crdb-$azregion | jq -r '.[].id')
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

## Cloud Three - GCP

### Create GKE Cluster

Next we created a Virtual Private Network along with a subnet. First command is to create the network.
```
gcloud compute networks create $gcp_vcp_name \
    --subnet-mode=auto \
    --bgp-routing-mode=$gcp_dynamic_routing_mode \
    --mtu=$gcp_mtu_size
```

Then create the subnet.
```
gcloud compute networks subnets create $gke_vcp_sub \
    --network=$gcp_vcp_name \
    --range=$gcp_vpc_cidr \
    --region=$gcp_region
```

Create Firewall rules.
```
gcloud compute firewall-rules create allowazureandaws --network $gcp_vcp_name --allow tcp,udp,icmp --source-ranges $aws_vpc_cidr,$az_subnet_prefix
gcloud compute firewall-rules create allowsshping --network $gcp_vcp_name --allow tcp:22,icmp
```

Now we have the network with the required IP addressing.
```
gcloud container clusters create $clus3 \
    --region=$gcp_region \
    --enable-ip-alias \
    --network=$gcp_vcp_name \
    --machine-type=$gke_machine_type \
    --cluster-ipv4-cidr=$cluster_pod_ip_range \
    --subnetwork=$gke_vcp_sub
```

[next](2-create-vpn-devices.md)