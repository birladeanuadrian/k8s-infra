# Infrastructure Setup Plan

This plan breaks down the objectives for setting up your Kubernetes infrastructure to ensure each component works together harmoniously on your Docker Desktop cluster.

## 1. Kubernetes Cluster (Prerequisite)
- **Status:** Done (Docker Desktop).
- **Action Items:** Ensure the cluster has enough resources allocated in Docker Desktop (recommended at least 4-6 CPUs and 8GB+ RAM, as Istio, Prometheus, and a MySQL cluster can be resource-intensive).

## 2. Cilium and Gateway API Setup
Cilium natively supports the Kubernetes Gateway API, and an NGINX deployment can be exposed through it.
- **Step 2.1:** Install the standard Kubernetes Gateway API Custom Resource Definitions (CRDs).
- **Step 2.2:** Install or upgrade Cilium via Helm with Gateway API integration enabled (`--set gatewayAPI.enabled=true`).
- **Step 2.3:** Create a standard `GatewayClass` (managed by Cilium) and a `Gateway` listener on port 80/443.
- **Step 2.4:** Deploy an NGINX pod/deployment to act as your backend service.
- **Step 2.5:** Create an `HTTPRoute` mapping the NGINX service to your Cilium Gateway.

## 3. Istio & mTLS Configuration
We will configure Istio to handle service-mesh responsibilities.
- **Step 3.1:** Download and install `istioctl` (the Istio CLI).
- **Step 3.2:** Install the base Istio components (typically using the `default` or `minimal` profile). *Note: We need to ensure Istio sidecar injection doesn't conflict with Cilium's routing where unnecessary, so we will use namespace-level injection.*
- **Step 3.3:** Enable automatic sidecar injection on your application namespaces by labeling them (`istio-injection=enabled`).
- **Step 3.4:** Apply a `PeerAuthentication` policy in the `istio-system` namespace setting `mtls.mode: STRICT`. This globally enforces mTLS mesh-wide.

## 4. Prometheus Monitoring
- **Step 4.1:** Add the Prometheus community Helm repository.
- **Step 4.2:** Install the `kube-prometheus-stack` (via Helm), which provides Prometheus, Grafana, and standard Kubernetes node exporters.
- **Step 4.3:** Configure Prometheus `ServiceMonitors` or `PodMonitors` to discover and scrape metrics from Istio (Envoy proxies), Cilium, NGINX, and the MySQL cluster.

## 5. MySQL Cluster via Percona Operator
- **Step 5.1:** Add the Percona Helm repository to your local Helm configuration.
- **Step 5.2:** Install the Percona Operator for MySQL.
- **Step 5.3:** Create a Kubernetes `Secret` to securely hold the MySQL root and user passwords.
- **Step 5.4:** Deploy the Custom Resource (CR) - e.g., `PerconaXtraDBCluster` or `InnoDBCluster` depending on the operator version - to provision the MySQL database instances.

## Verification Plan
After deploying everything, we will do the following checks:
1. **Routing:** Access the NGINX service through the Cilium Gateway API external IP/port.
2. **Security (mTLS):** Deploy two test pods (one in mesh with sidecar, one outside). Verify that the pod outside the mesh gets connection resets when trying to access a restricted in-mesh service.
3. **Observability:** Port-forward to the Prometheus UI and ensure targets (Istio, MySQL, NGINX) show up as `UP`.
4. **Database:** Exec into a pod containing a MySQL client, securely connect using the provided secrets, and verify database cluster topology.
