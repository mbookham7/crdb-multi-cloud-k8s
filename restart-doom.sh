#!/bin/bash
source ~/.bash_profile
unset kubedoom_pod
kubectx mb-aks-cluster-1
kubectl scale deployment/kubedoom -n kubedoom --replicas=0
sleep 2
kubectl scale deployment/kubedoom -n kubedoom --replicas=1
sleep 5
kubedoom_pod=$(kubectl get pods -n kubedoom -o name --no-headers=true)
echo $kubedoom_pod
kubectl port-forward -n kubedoom $kubedoom_pod 5900