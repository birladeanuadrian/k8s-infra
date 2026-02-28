# Prometheus Monitoring

This document describes how to set up Prometheus monitoring using the `kube-prometheus-stack` Helm chart.

## 1. Install kube-prometheus-stack via Helm

Add the Prometheus community Helm repository and install the stack:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --version 82.4.3 \
  -n monitoring \
  -f values.yaml
```

This installs:
- **Prometheus** — metrics collection and alerting
- **Grafana** — dashboards and visualization (default credentials: `admin` / `admin`)
- **Alertmanager** — alert routing and notifications
- **Node Exporter** — host-level metrics
- **kube-state-metrics** — Kubernetes object metrics

See [`values.yaml`](values.yaml) for the custom configuration.

## 2. Monitors

Two monitors are provided:

1. **`ServiceMonitor`** ([`envoy-service-monitor.yaml`](envoy-service-monitor.yaml)) — Scrapes the **Envoy Gateway Controller** (management plane) in the `envoy-gateway-system` namespace.
2. **`PodMonitor`** ([`envoy-data-plane-monitor.yaml`](envoy-data-plane-monitor.yaml)) — Scrapes the **Envoy Proxy** pods (data plane) directly. This is required because the proxy pods expose metrics on port `19001`, which is not always exposed via the main service.

The Prometheus instance is configured to pick up `ServiceMonitor` and `PodMonitor` resources with the label `release: prometheus`.

### Why separate monitors?

We use two different monitor types because they target different Kubernetes abstractions:

1. **`ServiceMonitor`**: Discovers targets based on **Service** endpoints. The Envoy Gateway Controller has a standard Kubernetes Service specifically for the control plane metrics, so `ServiceMonitor` is the natural choice.
2. **`PodMonitor`**: Discovers targets based on **Pod** labels directly, bypassing Services. The Envoy Gateway data plane (the proxy pods) exposes metrics on port `19001`, but the `LoadBalancer` Service sitting in front of them typically only forwards traffic to the application ports (e.g., 80/443), not the metrics port. Therefore, we cannot reach the metrics endpoint via the Service, forcing us to use a `PodMonitor` to scrape the pods directly.

These are distinct Custom Resource Definitions (CRDs) in the Prometheus Operator and cannot be merged into a single resource.

Apply:

```bash
kubectl apply -f envoy-service-monitor.yaml
kubectl apply -f envoy-data-plane-monitor.yaml
```

## 3. Accessing the UIs

With these routes, you can access the UIs via the Gateway (ensure you have port-forwarded the Envoy service or have a LoadBalancer IP, and added entries to your `/etc/hosts`):

- **Prometheus:** `http://prometheus.local/`
- **Grafana:** `http://grafana.local/`

You need to add these to your hosts file:
```
127.0.0.1 prometheus.local
127.0.0.1 grafana.local
```

## Automated Setup

The `setup.sh` script automates all steps. It is idempotent and can be run multiple times:

```bash
./setup.sh
```
