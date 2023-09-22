# Demo 2 - CockroachDB Scalability under load

The purpose of this demonstration is to show how CockroachDB is able to scale to meet the needs of an increased load without any interruption to the workload that is running. We will use Roach Bank to increase the stress on  the CockroachDB cluster. Once it is under stress we will increase the number of CockroachDB node and observer the affect on the cluster.

Check the pods are running.
```
kubectl get po -n roach-bank --context $clus1
kubectl get po -n roach-bank --context $clus2
kubectl get po -n roach-bank --context $clus3
```

Increase the number of replicas for each of the StatefulSet in each of the regions.
```
kubectl scale statefulsets cockroachdb --replicas=6 -n $loc1 --context $clus1
kubectl scale statefulsets cockroachdb --replicas=6 -n $loc2 --context $clus2
kubectl scale statefulsets cockroachdb --replicas=6 -n $loc3 --context $clus3
```

Get the statefulSet from each region.
```
kubectl get statefulset cockroachdb -n $loc1 --context $clus1
kubectl get statefulset cockroachdb -n $loc2 --context $clus2
kubectl get statefulset cockroachdb -n $loc3 --context $clus3
```

It will now take a few mins for the new nodes to be added to the cluster and participate in the workload.
Check in the UI the load on the CockroachDB Cluster. What do you notice?

[CockroachDB UI Cluster Hardware Metrics](https://uksouth.mikebookham.co.uk:8080/#/metrics/hardware/cluster)

Scale Bank Client to increase the load on the Database.
```
kubectl scale deployment bank-client --replicas=4 -n roach-bank --context $clus1
kubectl scale deployment bank-client --replicas=4 -n roach-bank --context $clus2
kubectl scale deployment bank-client --replicas=4 -n roach-bank --context $clus3
```

See the new pod that have been created.
```
kubectl get po -n roach-bank --context $clus1
kubectl get po -n roach-bank --context $clus2
kubectl get po -n roach-bank --context $clus3
```

Once you scale the bank-client replicas you will see an distinct increase in the number of QPS the cluster is now able to support.