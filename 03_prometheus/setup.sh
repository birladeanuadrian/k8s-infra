#!/bin/bash

set -e

echo "Starting Prometheus Monitoring Setup..."

echo "1. Adding Prometheus community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "2. Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

echo "3. Installing kube-prometheus-stack..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --version 82.4.3 \
  -n monitoring \
  -f values.yaml

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
echo "  User: admin / Password: admin"
echo ""
echo "Access Prometheus UI:"
echo "  URL: http://prometheus.local/"
echo ""
echo "Note: Ensure '127.0.0.1 grafana.local prometheus.local' is in your /etc/hosts file."
echo "      And that the Envoy Gateway is port-forwarded (if on local cluster)."
