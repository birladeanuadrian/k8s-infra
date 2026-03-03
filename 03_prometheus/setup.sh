#!/bin/bash

set -e

# Load .env file automatically if it exists
if [ -f .env ]; then
  echo "Loading variables from .env..."
  set -a
  source .env
  set +a
fi

if [ -z "${GRAFANA_ADMIN_PASSWORD}" ]; then
  echo "Error: environment variable GRAFANA_ADMIN_PASSWORD is not set."
  echo ""
  echo "Usage:"
  echo "  export GRAFANA_ADMIN_PASSWORD=<password>"
  echo "  ./setup.sh"
  exit 1
fi

echo "Starting Prometheus Monitoring Setup..."

echo "1. Adding Prometheus community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "2. Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

echo "3. Installing kube-prometheus-stack..."
envsubst < values.yaml | helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --version 82.4.3 \
  -n monitoring \
  -f -

echo "4. Waiting for Prometheus pods to be ready..."
kubectl wait --timeout=5m -n monitoring deployment/prometheus-kube-prometheus-operator --for=condition=Available
kubectl wait --timeout=5m -n monitoring deployment/prometheus-grafana --for=condition=Available

echo "5. Applying ServiceMonitors and PodMonitors..."
kubectl apply -f envoy-service-monitor.yaml
kubectl apply -f envoy-data-plane-monitor.yaml

echo "6. Exposing Prometheus and Grafana via Gateway..."
kubectl apply -f prometheus-gateway.yaml

echo "Setup completed."
echo ""
echo "Access Grafana:"
echo "  URL: http://grafana.local/"
echo "  User: admin / Password: <your-grafana-password>"
echo ""
echo "Access Prometheus UI:"
echo "  kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090"
echo "  URL: http://127.0.0.1:9090"
echo ""
echo "Note: Ensure '127.0.0.1 grafana.local' is in your /etc/hosts file."
echo "      And that the Envoy Gateway is port-forwarded (if on local cluster)."
