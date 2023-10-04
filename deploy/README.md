# Cloud Deployment Tutorial

Deployment tutorial for setting up a full-stack demo using multi-region cloud deployment.

## Prerequisites

- A multi region CockroachDB cluster running in Kubernetes.
- A local KUBECONFIG with access to all Kubernetes clusters.

## Create CockroachDB Cluster

First create a CockroachDB cluster with a cloud provider of choice.

- There is an example available [here](https://github.com/mbookham7/mb-crdb-multi-region-aks) to create such a cluster in Azure AKS.

- There are step by step instructions for AWS EKS [here](https://www.cockroachlabs.com/docs/stable/orchestrate-cockroachdb-with-kubernetes-multi-cluster.html).

- There are step by step instructions for GCP GKE [here](https://www.cockroachlabs.com/docs/stable/orchestrate-cockroachdb-with-kubernetes-multi-cluster.html?filters=eks).

## Create RoachBank Database

First to allow for ease of use of these instructions we need to set some variables. These variables need to set the context of each of the Kubernetes cluster
```
export clus1="bookham@mb-eu-eks-cluster-1.eu-west-1.eksctl.io"
export clus2="gke_cockroach-bookham_europe-west4_mb-eu-gke-cluster-1"
export clus3="mb-uksouth-aks-cluster-1"
```

Once you have a multi region CockroachDB cluster, connect to the cluster and create a database called `roach_bank`

To do this `exec` into the pod using the CockraochDB SQL client.
```
kubectl exec -it cockroachdb-client-secure -n $aws_region --context $clus1 -- ./cockroach sql --certs-dir=/cockroach-certs --host=cockroachdb-public
```
Create a user, make that user an admin and create the `roach_bank` database.
```
CREATE USER craig WITH PASSWORD 'cockroach';
GRANT admin TO craig;
CREATE database roach_bank;
USE roach_bank;
\q
```

### Deploy Bank

Bank Server needs to be deployed into each region. This is done by applying a simple Kubernetes manifest that contains a deployment and a service.
To make our lives easier lets set our Kubernetes contexts as environment variables.
> If you followed my AKS guide and used the same regions then you can use the values below. If you didn't make sure you update them to the correct values for your environment.
```
clus1="crdb-aks-uksouth"
clus2="crdb-aks-ukwest"
clus3="crdb-aks-northeurope"
```

Create a new namespace for Roach Bank to be deployed into in each region.
```
kubectl create namespace roach-bank --context $clus1
kubectl create namespace roach-bank --context $clus2
kubectl create namespace roach-bank --context $clus3
```

Deploy Roach Bank server pod into each of the clusters and create a service to expose this to the outside world.
```
kubectl apply -f ./manifests/eu-west-1-deployment.yaml -n roach-bank --context $clus1
kubectl apply -f ./manifests/europe-west4-deployment.yaml -n roach-bank --context $clus2
kubectl apply -f ./manifests/uksouth-deployment.yaml -n roach-bank --context $clus3
```
Check each cluster to ensure the pods are running.
```
kubectl get po -n roach-bank --context $clus1
kubectl get po -n roach-bank --context $clus2
kubectl get po -n roach-bank --context $clus3
```

```
ALTER DATABASE roach_bank PRIMARY REGION "eu-west-1";
ALTER DATABASE roach_bank ADD REGION "uksouth";
ALTER DATABASE roach_bank ADD REGION "europe-west4";
```

```
DELETE  from region where 1=1;
INSERT into region
VALUES 
('azure','aws-eu-west-1', 'stockholm,copenhagen,helsinki,oslo,riga,tallinn'),
('azure','azure-uksouth', 'london,birmingham,leeds,amsterdam,rotterdam,antwerp,hague,ghent,brussels'),
('azure','gcp-europe-west4', 'dublin,belfast,london,liverpool,manchester,glasgow,birmingham,leeds');
\q
```

If all the pods are running and the service has been able to create a load balancer successfully then you can move to the next stage.

## Demo Instructions

Once the cluster is setup and the bank is deployed, you can issue workload commands to create traffic.

### Starting the Client

The Roach Bank Client is the application component that is able to generate load against Roach Bank Server. Roach Bank Server takes API calls and converts these into database transactions. THis generates load against the CockroachDB cluster.

A configMap containing the Roach Bank client configuration needs to be created.
Apply the config map
```
kubectl apply -f scalability/bank-client-config.yaml -n roach-bank --context $clus1
kubectl apply -f scalability/bank-client-config.yaml -n roach-bank --context $clus2
kubectl apply -f scalability/bank-client-config.yaml -n roach-bank --context $clus3
```

Deploy the Bank Client across all three region.
```
kubectl apply -f manifests/bank-client-deploy.yaml -n roach-bank --context $clus1
kubectl apply -f manifests/bank-client-deploy.yaml -n roach-bank --context $clus2
kubectl apply -f manifests/bank-client-deploy.yaml -n roach-bank --context $clus3
```