#!/bin/bash

set -e

echo "Starting Kubernetes Infrastructure Setup (Envoy Gateway API)..."

echo "1. Installing Envoy Controller..."
helm upgrade --install envoy-gateway oci://docker.io/envoyproxy/gateway-helm \
  --version v1.7.0 -n envoy-gateway-system \
  --create-namespace

echo "2. Waiting for Envoy pods to be ready..."
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

echo "3. Creating Gateway API resources..."
kubectl apply -f gateway.yaml

echo "4. Creating application namespace..."
kubectl create namespace application --dry-run=client -o yaml | kubectl apply -f -

echo "5. Deploying NGINX app..."
kubectl apply -f nginx.yaml

echo "Setup script completed."
echo "Wait for the Gateway to be assigned an IP address using: kubectl get gateway main-gateway"
echo "Then, add the IP to your /etc/hosts file:"
echo "<IP> my-app.local"
# On windows you need to forward the port:
#kubectl port-forward svc/envoy-default-main-gateway-0c7e158b -n envoy-gateway-system 80:80