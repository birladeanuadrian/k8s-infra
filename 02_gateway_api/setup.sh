#!/bin/bash

set -e

echo "Starting Kubernetes Infrastructure Setup (Envoy Gateway API)..."

echo "0. Installing Gateway API CRDs..."
# Check if Gateway API CRDs are installed, if not, install Standard Channel
if ! kubectl get crd gatewayclasses.gateway.networking.k8s.io &> /dev/null; then
  echo "Installing Standard Gateway API CRDs (v1.2.0)..."
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
else
  echo "Gateway API CRDs already present. Skipping..."
fi

echo "0.1. Installing Envoy Gateway Custom CRDs..."
# Install Envoy Gateway specific CRDs manually to avoid Helm bundling issues with Experimental Gateway API CRDs
# Use helm template to get the exact CRDs for this version and filter them using python
helm template envoy-gateway oci://docker.io/envoyproxy/gateway-helm --version v1.7.0 --include-crds > full-install.yaml
if [ -f filter_crds.py ]; then
    python3 filter_crds.py full-install.yaml > envoy-gateway-crds.yaml
    kubectl apply -f envoy-gateway-crds.yaml --server-side
    rm full-install.yaml envoy-gateway-crds.yaml
else
    echo "Error: filter_crds.py not found. Cannot filter CRDs."
    exit 1
fi

echo "1. Installing Envoy Controller..."
helm upgrade --install envoy-gateway oci://docker.io/envoyproxy/gateway-helm \
  --version v1.7.0 -n envoy-gateway-system \
  --create-namespace \
  --skip-crds

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