#!/bin/bash
# autopkgtest: Create a Kubernetes-in-Docker (Kind) cluster to test basic
# kubectl functionalities, including creating a namespace, deploying an
# application, scaling it to two replicas, and then deleting it.
# Author: Arthur Diniz <arthurbdiniz@gmail.com>

set -euxo pipefail

CLIENT_VERSION=$(kubectl version 2>/dev/null | grep 'Client Version' | sed -E 's/.*Client Version: (v[0-9]+\.[0-9]+\.[0-9]+).*/\1/' || true)

systemctl start docker

kind create cluster --name test-cluster-1 --image kindest/node:$CLIENT_VERSION 2>&1
kind create cluster --name test-cluster-2 --image kindest/node:$CLIENT_VERSION 2>&1

kind export kubeconfig --name test-cluster-1 --kubeconfig $HOME/.kube/test-cluster-1-config
kind export kubeconfig --name test-cluster-2 --kubeconfig $HOME/.kube/test-cluster-2-config

kubectl config use-context kind-test-cluster-2

kubectl config use-context kind-test-cluster-1

kubectl cluster-info

# Check if nodes are available
kubectl get nodes

# Create a namespace for testing
kubectl create namespace test-ns

# Create a deployment
kubectl create deployment nginx --image=nginx --namespace=test-ns

# Verify pod is running
kubectl wait --for=condition=available --timeout=60s deployment/nginx -n test-ns

# Expose deployment
kubectl expose deployment nginx --port=80 --target-port=80 --type=ClusterIP -n test-ns

# Get logs from the pod
POD_NAME=$(kubectl get pods -n test-ns -o jsonpath="{.items[0].metadata.name}")
kubectl logs $POD_NAME -n test-ns

# Execute a command in the pod
kubectl exec $POD_NAME -n test-ns -- ls /

# Scale the deployment
kubectl scale deployment nginx --replicas=2 -n test-ns
kubectl wait --for=condition=available --timeout=60s deployment/nginx -n test-ns
kubectl get pods -n test-ns

# Delete a pod and check if it restarts
kubectl delete pod $POD_NAME -n test-ns
kubectl get pods -n test-ns

# Delete namespace
kubectl delete namespace test-ns

kind delete cluster --name test-cluster-1 2>&1
kind delete cluster --name test-cluster-2 2>&1

docker rmi kindest/node:$CLIENT_VERSION
