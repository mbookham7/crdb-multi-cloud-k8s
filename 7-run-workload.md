# Run the movr Workload

As we will be using the Azure region for the Doom demo we will deploy our sample workload in the AWS region. This will ensure when we kill the the CockroachDB pods in the Azure region are workload will keep running.
```
kubectl config use-context $context_eks
kubectl create -f https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/client-secure.yaml --namespace $aws_region
```

Exec into the secure client pod and get a shell command.
```
kubectl exec -it cockroachdb-client-secure -n $eks_region -- sh
```

Now we can run the simulated workload. First initalise the database the run the workload.
```
cockroach workload init movr 'postgresql://craig:cockroach@cockroachdb-public:26257/movr?sslmode=verify-full&sslrootcert=/cockroach-certs/ca.crt'

cockroach workload run movr --tolerate-errors --duration=99999m 'postgresql://craig:cockroach@cockroachdb-public:26257/movr?sslmode=verify-full&sslrootcert=/cockroach-certs/ca.crt'
```

Doom details.

```
VNC Password: idbehold

Doom Cheats: 

IDDQD - invulnerability
IDKFA - full health, ammo, etc
IDSPISPOPD - no clipping / walk through walls