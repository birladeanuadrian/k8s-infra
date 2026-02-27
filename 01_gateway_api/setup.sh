#!/bin/bash

set -e

echo "Starting Kubernetes Infrastructure Setup (Cilium & Gateway API)..."

echo "1. Installing Gateway API CRDs..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml

echo "2. Installing Cilium..."
helm repo add cilium https://helm.cilium.io/
helm repo update
helm upgrade --install cilium cilium/cilium --version 1.19.1 \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set gatewayAPI.enabled=true

echo "Waiting for Cilium pods to be ready..."
kubectl wait --namespace kube-system --for=condition=ready pod -l k8s-app=cilium --timeout=300s

echo "3. Deploying NGINX app..."
kubectl apply -f nginx.yaml

echo "4. Creating Gateway API resources..."
kubectl apply -f gateway.yaml

echo "Setup script completed."
echo "Wait for the Gateway to be assigned an IP address using: kubectl get gateway my-gateway"
echo "Then, add the IP to your /etc/hosts file:"
echo "<IP> my-app.local"
