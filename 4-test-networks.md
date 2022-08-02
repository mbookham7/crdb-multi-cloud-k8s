# Network Test

We can now perform a network test to check that the mesh is established and we are able to communicate from a pod in one cluster to a pos in the other cluster.

Set Context for $clus1
```
kubectl config use-context $clus1
```
Create a test pod to ping
```
kubectl run network-test --image=alpine --restart=Never -- sleep 999999
```

Get Ip addresss of pod to ping
```
kubectl describe pod network-test
```

Switch to $clus2 context
```
kubectl config use-context $clus2
```
Create a pod and ping the test pod. Replace $podip with the ip of the pod from the output of the `kubectl describe pod network-test`
```
kubectl run -it network-test --image=alpine --restart=Never -- ping $podip
```
Now you are ready to move to the next step. [Cockroach setup](cockroach-setup.md)

[Back](README.md)