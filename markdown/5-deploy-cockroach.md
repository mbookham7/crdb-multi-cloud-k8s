# Step: Deploy CockroachDB

kubectl config get-contexts -- Insert instructions
Before we deploy CockroachDB, we need to first set up the values for the 3 Kubernetes Contexts, as these may be different for each user the best way to get them is to run the below command, then be sure to edit the variables in the next step with the corresponding values.

```
kubectl config get-contexts
```

Setting Variables 

```
export context_eks="bookham@mb-eu-eks-cluster-1.eu-west-1.eksctl.io"
export context_gke="gke_cockroach-bookham_europe-west4_mb-eu-gke-cluster-1"
export context_aks="mb-uksouth-aks-cluster-1"
```
## Configure DNS in all regions

Name resolution needs to work across all three clouds. We do this by exposing DNS outside of Kubernetes to allow for cross cluster name resolution.
Apply the `yaml` below to expose the coreDNS service as a service type of `LoadBalancer`

```
kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/eks/dns-lb-eks.yaml --context $context_eks
kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/dns-lb.yaml --context $context_gke
kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/dns-lb.yaml --context $context_aks
```

Once these are applied the service `kube-dns-lb` will appear in each cluster exposing the dns service. Make a note of the external IP of Azure and GCP, collect the three IP's for AWS by doing a `dig` on the `FQDN` of the service
```
kubectl get svc --namespace kube-system --selector k8s-app=kube-dns --context $context_aks
kubectl get svc --namespace kube-system --selector k8s-app=kube-dns --context $context_gke
kubectl get svc --namespace kube-system --selector k8s-app=kube-dns --context $context_eks
```

Out of the three providers GKE is the only one still using `kube-dns`. So we are going to replace this with CoreDNS.
Run the set of commands below to achieve this.
```
kubectx $context_gke
git clone https://github.com/coredns/deployment.git
cd deployment/kubernetes
./deploy.sh > corends-deployment.yaml
kubectl apply -f corends-deployment.yaml
kubectl scale --replicas=0 deployment/kube-dns-autoscaler --namespace=kube-system
kubectl scale --replicas=0 deployment/kube-dns --namespace=kube-system
```

Now we have a the same DNS provider across the three solutions we can update our config to allow DNS request to be fowrarded to the correct CoreDNS in the correct cluster.
First we take a backup of the existing configmap in case we need to rollback.
```
kubectl -n kube-system get configmap coredns --context $context_eks -o yaml > eks-configmap-back.yaml
kubectl -n kube-system get configmap coredns --context $context_gke -o yaml > gke-configmap-back.yaml
kubectl -n kube-system get configmap coredns --context $context_aks -o yaml > aks-configmap-back.yaml
```

In the manifests folder there are some templates that can be updated. Make sure you update the region name if you have changed them and the IP of the external DNS services.
Below is an example of where the updates need to be made. Region1 and Region2 and IP1 and IP2 need to be updated.
```
   region1.svc.cluster.local:53 {       # <---- Modify
       log
       errors
       ready
       cache 10
       forward . IP1 {      # <---- Modify
       }
   }
   region2.svc.cluster.local:53 {       # <---- Modify
       log
       errors
       ready
       cache 10
       forward . IP2 {      # <---- Modify
       }
   }
```

A configmap for each region needs to be applied using the template.

```
kubectl -n kube-system replace -f manifests/aws-coredns-configmap.yaml --context $context_eks
kubectl -n kube-system replace -f manifests/gcp-coredns-configmap.yaml --context $context_gke
kubectl -n kube-system apply -f manifests/azure-coredns-configmap.yaml --context $context_aks
```

To ensure the new configmap is applied we delete the CoreDNS pods.
```
kubectl delete pod --namespace kube-system --selector k8s-app=kube-dns --context $context_aks
kubectl delete pod --namespace kube-system --selector k8s-app=kube-dns --context $context_gke
kubectl delete pod --namespace kube-system --selector k8s-app=kube-dns --context $context_eks
```

Now we have updated DNS we can deploy CockroachDB. First we create a namespace in each region reflecting the region names.
```
kubectl create namespace $aws_region --context $context_eks
kubectl create namespace $gcp_region --context $context_gke
kubectl create namespace $az_region --context $context_aks
```

CockroachDB will be running in secure mode so we need to create some certificates. We create two directories to store these.
```
mkdir certs my-safe-directory
```
Using the Cockroach binary we create our CA certificate.
```
cockroach cert create-ca \
--certs-dir=certs \
--ca-key=my-safe-directory/ca.key
```

And our client certificate.
```
cockroach cert create-client \
root \
--certs-dir=certs \
--ca-key=my-safe-directory/ca.key
```

Upload these as Kubernetes secrets. In each Region.
Region 1
```
kubectl create secret \
generic cockroachdb.client.root \
--from-file=certs \
--context $context_eks \
--namespace $aws_region
```
Region 2
```
kubectl create secret \
generic cockroachdb.client.root \
--from-file=certs \
--context $context_gke \
--namespace $gcp_region
```
Region 3
```
kubectl create secret \
generic cockroachdb.client.root \
--from-file=certs \
--context $context_aks \
--namespace $az_region
```

Now we create node certificates for each region. Create the certificate
```
cockroach cert create-node \
localhost 127.0.0.1 \
cockroachdb-public \
cockroachdb-public.$aws_region \
cockroachdb-public.$aws_region.svc.cluster.local \
"*.cockroachdb" \
"*.cockroachdb.$aws_region" \
"*.cockroachdb.$aws_region.svc.cluster.local" \
--certs-dir=certs \
--ca-key=my-safe-directory/ca.key
```
And upload it as a Kubernetes secret.
```
kubectl create secret \
generic cockroachdb.node \
--from-file=certs \
--context $context_eks \
--namespace $aws_region
```
Remove it from the directory ready for the next region. (In production you would keep these safe.)
```
rm certs/node.crt
rm certs/node.key
```
Do the same for the second region.
```
cockroach cert create-node \
localhost 127.0.0.1 \
cockroachdb-public \
cockroachdb-public.$gcp_region \
cockroachdb-public.$gcp_region.svc.cluster.local \
"*.cockroachdb" \
"*.cockroachdb.$gcp_region" \
"*.cockroachdb.$gcp_region.svc.cluster.local" \
--certs-dir=certs \
--ca-key=my-safe-directory/ca.key
```
Upload the secret.
```
kubectl create secret \
generic cockroachdb.node \
--from-file=certs \
--context $context_gke \
--namespace $gcp_region
```
Remove the files.
```
rm certs/node.crt
rm certs/node.key
```
Finally the third region
```
cockroach cert create-node \
localhost 127.0.0.1 \
cockroachdb-public \
cockroachdb-public.$az_region \
cockroachdb-public.$az_region.svc.cluster.local \
"*.cockroachdb" \
"*.cockroachdb.$az_region" \
"*.cockroachdb.$az_region.svc.cluster.local" \
--certs-dir=certs \
--ca-key=my-safe-directory/ca.key
```
Upload the secret.
```
kubectl create secret \
generic cockroachdb.node \
--from-file=certs \
--context $context_aks \
--namespace $az_region
```
Remove the files.
```
rm certs/node.crt
rm certs/node.key
```

We are now ready to deploy the CockroachDB StatefulSet files. If you have changed the regions ensure you update these files and there are a couple of hard coded values. You may also want to update the CockroachDB version.
```
kubectl -n $aws_region apply -f manifests/aws-cockroachdb-statefulset-secure.yaml --context $context_eks
kubectl -n $gcp_region apply -f manifests/gke-cockroachdb-statefulset-secure.yaml --context $context_gke
kubectl -n $az_region apply -f manifests/azure-cockroachdb-statefulset-secure.yaml --context $context_aks
```
Once deployed we can connect to one region and initialize the cluster.
```
kubectl exec \
--context $context_eks \
--namespace $aws_region \
-it cockroachdb-0 \
-- /cockroach/cockroach init \
--certs-dir=/cockroach/cockroach-certs
```

Once you have done this all of the pods should go into a ready state. If this is not the case the most likely issue is with the configmaps not being correct. You will see 'no such host' error in the pod logs for CockroachDB. Use the command below to check the status of the pods.
```
kubectl get pods --context $context_eks --namespace $aws_region
kubectl get pods --context $context_gke --namespace $gcp_region
kubectl get pods --context $context_aks --namespace $az_region
```

Create a secure pod to connect to the cluster.
```
kubectl config use-context $context_eks
kubectl create -f https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/client-secure.yaml --namespace $aws_region
```
Now `exec` into the pod.
```
kubectl exec -it cockroachdb-client-secure -n $aws_region -- ./cockroach sql --certs-dir=/cockroach-certs --host=cockroachdb-public
```
Use the SQL client to create a use and grant them the admin role.
```
CREATE USER craig WITH PASSWORD 'cockroach';
GRANT admin TO craig;
```

To enable enterprise features you can request an evaluation licence from [here](https://www.cockroachlabs.com/docs/v23.1/get-started-with-enterprise-trial)

Set your license like this.
```
SET CLUSTER SETTING cluster.organization = '';
SET CLUSTER SETTING enterprise.license = '';
```

Below is a how to update the map view. Again, if you have used other regions these will need to be changed. You can find the referaqnces [here](https://www.cockroachlabs.com/docs/stable/enable-node-map)
```
INSERT INTO system.locations VALUES
  ('region', 'uksouth', 50.941, -0.799),
  ('region', 'europe-west4', 53.4386, 6.8355),
  ('region', 'eu-west-1', 53.142367, -7.692054);

```

To gain access to the CockroachDB Console we can expose the service externally.
```
kubectl apply -f manifests/aws-svc-admin-ui.yaml --context $context_eks --namespace $aws_region
kubectl apply -f manifests/gke-svc-admin-ui.yaml --context $context_gke --namespace $gcp_region
kubectl apply -f manifests/azure-svc-admin-ui.yaml --context $context_aks --namespace $az_region
```

To obtain the IP of the external service use the command below.
```
kubectl get svc --context $context_eks --namespace $aws_region
kubectl get svc  --context $context_gke --namespace $gcp_region
kubectl get svc --context $context_aks --namespace $az_region
```

Put one of these in to your browser like `http://x.x.x.x:8080` and you will be able to log in with the creds we created earlier. This it it! If you have got this far you will have a multi-cloud CockroachDB cluster. Well Done! Go and make a cup of tea!

[Back](../README.md)
