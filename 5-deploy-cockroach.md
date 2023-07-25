# Step: Deploy CockroachDB

kubectl config get-contexts -- Insert instructions
Before we deploy CockroachDB, we need to first set up the values for the 3 Kubernetes Contexts, as these may be different for each user the best way to get them is to run the below command, then be sure to edit the variables in the next step with the corresponding valiues.

```
kubectl config get-contexts
```

Setting Variables 

```
export context_eks="dsheldon@mb-eu-eks-cluster-1.eu-west-1.eksctl.io"
export context_gke="gke_cockroach-dsheldon_europe-west4_mb-eu-gke-cluster-1"
export context_aks="mb-uksouth-aks-cluster-1

export eks_region="eu-west-1"
export gke_region="europe-west4"
export aks_region="uksouth"
```


```
kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/eks/dns-lb-eks.yaml --context $context_eks
kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/dns-lb.yaml --context $context_gke
kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/dns-lb.yaml --context $context_aks
```

Retrieve the IP addresses of the LB in each region and add these to the config maps.

```
kubectl create namespace $eks_region --context $context_eks
kubectl create namespace $gke_region --context $context_gke
kubectl create namespace $aks_region --context $context_aks
```

Replace kube-dns for CoreDNS in GKE

```
kubectx $context_gke
git clone https://github.com/coredns/deployment.git
cd deployment/kubernetes
./deploy.sh > corends-deployment.yaml
kubectl apply -f corends-deployment.yaml
kubectl scale --replicas=0 deployment/kube-dns-autoscaler --namespace=kube-system
kubectl scale --replicas=0 deployment/kube-dns --namespace=kube-system
```


```
kubectl -n kube-system get configmap coredns --context $context_eks -o yaml > eks-configmap-back.yaml
kubectl -n kube-system get configmap coredns --context $context_gke -o yaml > gke-configmap-back.yaml
kubectl -n kube-system get configmap coredns --context $context_aks -o yaml > aks-configmap-back.yaml
```

```
kubectl -n kube-system replace -f aws-coredns-configmap.yaml --context $context_eks
kubectl -n kube-system replace -f gcp-coredns-configmap.yaml --context $context_gke
kubectl -n kube-system apply -f azure-coredns-configmap.yaml --context $context_aks
```

```
kubectl delete pod --namespace kube-system --selector k8s-app=kube-dns --context $context_aks
kubectl delete pod --namespace kube-system --selector k8s-app=kube-dns --context $context_gke
```

```
kubectl -n kube-system describe configmap coredns --context $context_eks
kubectl -n kube-system describe configmap coredns --context $context_gke
kubectl -n kube-system describe configmap coredns --context $context_aks
```

```
mkdir certs my-safe-directory
```

```
cockroach cert create-ca \
--certs-dir=certs \
--ca-key=my-safe-directory/ca.key
```

```
cockroach cert create-client \
root \
--certs-dir=certs \
--ca-key=my-safe-directory/ca.key
```

```
kubectl create secret \
generic cockroachdb.client.root \
--from-file=certs \
--context $context_eks \
--namespace $eks_region
```

```
kubectl create secret \
generic cockroachdb.client.root \
--from-file=certs \
--context $context_gke \
--namespace $gke_region
```

```
kubectl create secret \
generic cockroachdb.client.root \
--from-file=certs \
--context $context_aks \
--namespace $aks_region
```

```
cockroach cert create-node \
localhost 127.0.0.1 \
cockroachdb-public \
cockroachdb-public.$eks_region \
cockroachdb-public.$eks_region.svc.cluster.local \
"*.cockroachdb" \
"*.cockroachdb.$eks_region" \
"*.cockroachdb.$eks_region.svc.cluster.local" \
--certs-dir=certs \
--ca-key=my-safe-directory/ca.key
```

```
kubectl create secret \
generic cockroachdb.node \
--from-file=certs \
--context $context_eks \
--namespace $eks_region
```

```
rm certs/node.crt
rm certs/node.key
```

```
cockroach cert create-node \
localhost 127.0.0.1 \
cockroachdb-public \
cockroachdb-public.$gke_region \
cockroachdb-public.$gke_region.svc.cluster.local \
"*.cockroachdb" \
"*.cockroachdb.$gke_region" \
"*.cockroachdb.$gke_region.svc.cluster.local" \
--certs-dir=certs \
--ca-key=my-safe-directory/ca.key
```

```
kubectl create secret \
generic cockroachdb.node \
--from-file=certs \
--context $context_gke \
--namespace $gke_region
```

```
rm certs/node.crt
rm certs/node.key
```

```
cockroach cert create-node \
localhost 127.0.0.1 \
cockroachdb-public \
cockroachdb-public.$aks_region \
cockroachdb-public.$aks_region.svc.cluster.local \
"*.cockroachdb" \
"*.cockroachdb.$aks_region" \
"*.cockroachdb.$aks_region.svc.cluster.local" \
--certs-dir=certs \
--ca-key=my-safe-directory/ca.key
```

```
kubectl create secret \
generic cockroachdb.node \
--from-file=certs \
--context $context_aks \
--namespace $aks_region
```

```
rm certs/node.crt
rm certs/node.key
```

```
kubectl -n $eks_region apply -f aws-cockroachdb-statefulset-secure.yaml --context $context_eks
kubectl -n $gke_region apply -f gke-cockroachdb-statefulset-secure.yaml --context $context_gke
kubectl -n $aks_region apply -f azure-cockroachdb-statefulset-secure.yaml --context $context_aks
```

```
kubectl -n $eks_region delete -f aws-cockroachdb-statefulset-secure.yaml --context $context_eks
kubectl -n $gke_region delete -f gke-cockroachdb-statefulset-secure.yaml --context $context_gke
kubectl -n $aks_region delete -f azure-cockroachdb-statefulset-secure.yaml --context $context_aks
```

```
kubectl exec \
--context $context_eks \
--namespace $eks_region \
-it cockroachdb-0 \
-- /cockroach/cockroach init \
--certs-dir=/cockroach/cockroach-certs
```

```
kubectl get pods --context $context_eks --namespace $eks_region
kubectl get pods --context $context_gke --namespace $gke_region
kubectl get pods --context $context_aks --namespace $aks_region
```

```
kubectl config use-context $context_eks
kubectl create -f https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/client-secure.yaml --namespace $eks_region
```

```
kubectl exec -it cockroachdb-client-secure -n $eks_region -- ./cockroach sql --certs-dir=/cockroach-certs --host=cockroachdb-public
```
```
CREATE USER craig WITH PASSWORD 'cockroach';
GRANT admin TO cockroach;
\q
```

```
./crl-lic -type Evaluation -org "Cockroach Labs" -site -expiration "2022-10-03 00:00 America/New_York"
```

```
SET CLUSTER SETTING cluster.organization = 'Cockroach Labs';
SET CLUSTER SETTING enterprise.license = 'crl-0-EMC86ZkGGAIiDkNvY2tyb2FjaCBMYWJz';
```

```
INSERT INTO system.locations VALUES
  ('region', 'uksouth', 50.941, -0.799),
  ('region', 'europe-west4', 53.4386, 6.8355),
  ('region', 'eu-west-1', 53.142367, -7.692054);

```
kubectl port-forward cockroachdb-0 8080 -n $eks_region
```

```
kubectl apply -f aws-svc-admin-ui.yaml --context $context_eks --namespace $eks_region
kubectl apply -f gke-svc-admin-ui.yaml --context $context_gke --namespace $gke_region
kubectl apply -f azure-svc-admin-ui.yaml --context $context_aks --namespace $aks_region
```

kubectl get svc --context $context_eks --namespace $eks_region
kubectl get svc  --context $context_gke --namespace $gke_region
kubectl get svc --context $context_aks --namespace $aks_region

