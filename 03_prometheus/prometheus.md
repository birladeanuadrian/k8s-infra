# Prometheus Monitoring

This document describes how to set up Prometheus monitoring using the `kube-prometheus-stack` Helm chart.

## 1. Install kube-prometheus-stack via Helm

Add the Prometheus community Helm repository and install the stack. The `values.yaml` file requires the `GRAFANA_ADMIN_PASSWORD` environment variable to be set. You also need to set `PROMETHEUS_ADMIN_PASSWORD` for Basic Auth access to Prometheus.

```bash
export GRAFANA_ADMIN_PASSWORD=<your-admin-password>
export PROMETHEUS_ADMIN_PASSWORD=<your-prometheus-password>

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
envsubst < values.yaml | helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --version 82.4.3 \
  -n monitoring \
  -f -
```

This installs:
- **Prometheus** — metrics collection and alerting (secured via Basic Auth, user: `admin`, password: `PROMETHEUS_ADMIN_PASSWORD`)
- **Grafana** — dashboards and visualization (default user: `admin`, password: as set in `GRAFANA_ADMIN_PASSWORD`)
- **Alertmanager** — alert routing and notifications
- **Node Exporter** — host-level metrics
- **kube-state-metrics** — Kubernetes object metrics

See [`values.yaml`](values.yaml) for the custom configuration.

## 2. Monitors

Two monitors are provided:

### 2.1 ServiceMonitor — Envoy Gateway Controller (Control Plane)

File: [`envoy-service-monitor.yaml`](envoy-service-monitor.yaml)

Scrapes the **Envoy Gateway Controller** via the `envoy-gateway` Service in `envoy-gateway-system` (port `19001`, path `/metrics`).

**In short:** Monitors the health of the management plane — is the controller successfully reconciling Gateway resources, how fast is it processing changes, and is it communicating properly with the Kubernetes API.

Key metrics exposed:

| Metric | Type | Description |
|---|---|---|
| `controller_runtime_reconcile_total` | counter | Total number of reconciliations per controller |
| `controller_runtime_reconcile_errors_total` | counter | Total number of reconciliation errors |
| `controller_runtime_reconcile_time_seconds` | histogram | Time taken by reconciliations |
| `controller_runtime_reconcile_panics_total` | counter | Total number of reconciliation panics |
| `controller_runtime_active_workers` | gauge | Number of currently active workers |
| `controller_runtime_max_concurrent_reconciles` | gauge | Maximum number of concurrent reconciles |
| `controller_runtime_webhook_requests_total` | counter | Total number of webhook requests |
| `controller_runtime_webhook_latency_seconds` | histogram | Webhook request latency |
| `certwatcher_read_certificate_total` | counter | Total number of certificate reads |
| `certwatcher_read_certificate_errors_total` | counter | Total certificate read errors |
| `resource_apply_total` | counter | Total resource apply operations |
| `resource_apply_duration_seconds` | histogram | Duration of resource apply operations |
| `resource_delete_total` | counter | Total resource delete operations |
| `status_update_total` | counter | Total status update operations |
| `status_update_duration_seconds` | histogram | Duration of status updates |
| `xds_snapshot_create_total` | counter | Total xDS snapshot creations |
| `xds_snapshot_update_total` | counter | Total xDS snapshot updates |
| `xds_stream_duration_seconds` | histogram | Duration of xDS streams |
| `watchable_subscribe_total` | counter | Total watchable subscriptions |
| `watchable_publish_total` | counter | Total watchable publishes |
| `watchable_depth` | gauge | Current watchable queue depth |
| `leader_election_master_status` | gauge | Whether this instance is the leader |
| `workqueue_adds_total` | counter | Total items added to the work queue |
| `workqueue_depth` | gauge | Current depth of the work queue |
| `workqueue_retries_total` | counter | Total number of retries in the work queue |
| `rest_client_requests_total` | counter | Total HTTP requests to the Kubernetes API |
| `rest_client_request_duration_seconds` | histogram | Duration of HTTP requests to the Kubernetes API |
| `process_resident_memory_bytes` | gauge | Resident memory size of the process |
| `go_goroutines` | gauge | Number of active goroutines |

### 2.2 PodMonitor — Envoy Proxy (Data Plane)

File: [`envoy-data-plane-monitor.yaml`](envoy-data-plane-monitor.yaml)

Scrapes the **Envoy Proxy** pods directly (port `19001`, path `/stats/prometheus`). This is required because the proxy's `LoadBalancer` Service only exposes the application port (80/443), not the metrics port.

**In short:** Monitors the actual traffic flowing through the gateway — request rates, response codes, latencies, connection counts, upstream (backend) health, and proxy resource usage.

Key metrics exposed:

| Metric | Type | Description |
|---|---|---|
| `envoy_http_downstream_rq_total` | counter | Total downstream (client) requests |
| `envoy_http_downstream_rq_xx` | counter | Downstream requests by response code class (2xx, 4xx, 5xx) |
| `envoy_http_downstream_rq_completed` | counter | Total completed downstream requests |
| `envoy_http_downstream_rq_time` | histogram | Request duration (ms) |
| `envoy_http_downstream_rq_active` | gauge | Currently active downstream requests |
| `envoy_http_downstream_rq_timeout` | counter | Requests that timed out |
| `envoy_http_downstream_cx_total` | counter | Total downstream connections |
| `envoy_http_downstream_cx_active` | gauge | Currently active downstream connections |
| `envoy_http_downstream_cx_destroy` | counter | Total destroyed downstream connections |
| `envoy_http_downstream_cx_length_ms` | histogram | Connection duration (ms) |
| `envoy_http_downstream_cx_rx_bytes_total` | counter | Total bytes received from downstream |
| `envoy_http_downstream_cx_tx_bytes_total` | counter | Total bytes sent to downstream |
| `envoy_cluster_upstream_rq_total` | counter | Total upstream (backend) requests |
| `envoy_cluster_upstream_rq_xx` | counter | Upstream requests by response code class |
| `envoy_cluster_upstream_rq_time` | histogram | Upstream request duration (ms) |
| `envoy_cluster_upstream_rq_active` | gauge | Currently active upstream requests |
| `envoy_cluster_upstream_rq_timeout` | counter | Upstream requests that timed out |
| `envoy_cluster_upstream_rq_retry` | counter | Total upstream request retries |
| `envoy_cluster_upstream_cx_total` | counter | Total upstream connections |
| `envoy_cluster_upstream_cx_active` | gauge | Currently active upstream connections |
| `envoy_cluster_upstream_cx_connect_fail` | counter | Failed upstream connection attempts |
| `envoy_cluster_upstream_cx_connect_ms` | histogram | Upstream connection time (ms) |
| `envoy_cluster_upstream_cx_rx_bytes_total` | counter | Total bytes received from upstream |
| `envoy_cluster_upstream_cx_tx_bytes_total` | counter | Total bytes sent to upstream |
| `envoy_cluster_membership_healthy` | gauge | Number of healthy upstream hosts |
| `envoy_cluster_membership_total` | gauge | Total number of upstream hosts |
| `envoy_listener_downstream_cx_total` | counter | Total connections per listener |
| `envoy_listener_downstream_cx_active` | gauge | Active connections per listener |
| `envoy_server_live` | gauge | Whether the server is live (1 = live) |
| `envoy_server_uptime` | gauge | Server uptime in seconds |
| `envoy_server_memory_allocated` | gauge | Current memory allocated |
| `envoy_server_memory_heap_size` | gauge | Current heap size |
| `envoy_server_concurrency` | gauge | Number of worker threads |


The Prometheus instance is configured to pick up `ServiceMonitor` and `PodMonitor` resources with the label `release: prometheus`.

Apply:

```bash
kubectl apply -f envoy-service-monitor.yaml
kubectl apply -f envoy-data-plane-monitor.yaml
```

## 3. Accessing the UIs

With these routes, you can access the UIs via the Gateway (ensure you have port-forwarded the Envoy service or have a LoadBalancer IP, and added entries to your `/etc/hosts`):

- **Grafana:** `http://grafana.local/`

You need to add these to your hosts file:
```
127.0.0.1 grafana.local
```

### Accessing Prometheus

Since Prometheus is not exposed via the Gateway, use port-forwarding:

```bash
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090
```

Then access at [http://127.0.0.1:9090/](http://127.0.0.1:9090/).

## Automated Setup

The `setup.sh` script automates all steps. It is idempotent and can be run multiple times:

```bash
./setup.sh
```
