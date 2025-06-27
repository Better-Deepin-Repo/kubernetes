#!/bin/bash
# autopkgtest: Create a Kubernetes-in-Docker (Kind) cluster to test basic
# kubectl functionalities, including creating a namespace, deploying an
# application, scaling it to two replicas, and then deleting it.
# Author: Arthur Diniz <arthurbdiniz@gmail.com>

set -euo pipefail

echo "Getting kubectl client version"
CLIENT_VERSION=$(kubectl version --client | grep 'Client Version' | sed -E 's/.*Client Version: (v[0-9]+\.[0-9]+\.[0-9]+).*/\1/')

echo "Starting Docker service"
systemctl start docker

echo "Creating Kind clusters"
kind create cluster --name test-cluster-1 --image kindest/node:$CLIENT_VERSION 2>&1
kind create cluster --name test-cluster-2 --image kindest/node:$CLIENT_VERSION 2>&1

echo "Exporting kubeconfig files"
kind export kubeconfig --name test-cluster-1 --kubeconfig $HOME/.kube/test-cluster-1-config 2>&1
kind export kubeconfig --name test-cluster-2 --kubeconfig $HOME/.kube/test-cluster-2-config 2>&1

echo "Switching to test-cluster-2 context"
kubectl config use-context kind-test-cluster-2

echo "Switching to test-cluster-1 context"
kubectl config use-context kind-test-cluster-1

echo "Getting cluster info"
kubectl cluster-info

echo "Checking available nodes"
kubectl get nodes

echo "Creating test namespace"
kubectl create namespace test-ns

echo "Creating nginx deployment"
kubectl create deployment nginx --image=nginx --namespace=test-ns

echo "Waiting for deployment to be available"
kubectl wait --for=condition=available --timeout=60s deployment/nginx -n test-ns

echo "Exposing nginx deployment"
kubectl expose deployment nginx --port=80 --target-port=80 --type=ClusterIP -n test-ns

echo "Getting pod name and logs"
POD_NAME=$(kubectl get pods -n test-ns -o jsonpath="{.items[0].metadata.name}")
kubectl logs $POD_NAME -n test-ns

echo "Executing command in pod"
kubectl exec $POD_NAME -n test-ns -- ls /

echo "Scaling deployment to 2 replicas"
kubectl scale deployment nginx --replicas=2 -n test-ns
kubectl wait --for=condition=available --timeout=60s deployment/nginx -n test-ns
kubectl get pods -n test-ns

echo "Deleting pod to test restart"
kubectl delete pod $POD_NAME -n test-ns
kubectl get pods -n test-ns

echo "Deleting test namespace"
kubectl delete namespace test-ns

echo "Deleting Kind clusters"
kind delete cluster --name test-cluster-1 2>&1
kind delete cluster --name test-cluster-2 2>&1

echo "Removing Docker image"
docker rmi kindest/node:$CLIENT_VERSION
