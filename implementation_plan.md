# Infrastructure Setup Plan

This plan breaks down the objectives for setting up your Kubernetes infrastructure to ensure each component works together harmoniously on your Docker Desktop cluster.

## 1. Kubernetes Cluster (Prerequisite)
- **Status:** Done (Docker Desktop).
- **Action Items:** Ensure the cluster has enough resources allocated in Docker Desktop (recommended at least 4-6 CPUs and 8GB+ RAM, as Prometheus and a MySQL cluster can be resource-intensive).

## 2. Envoy Gateway and Gateway API Setup
Envoy Gateway natively supports the Kubernetes Gateway API, and a backend application can be exposed through it.
- **Step 2.1:** Install Envoy Gateway via Helm (`helm upgrade --install envoy-gateway oci://docker.io/envoyproxy/gateway-helm`).
- **Step 2.2:** Create a `GatewayClass` (managed by Envoy Gateway) and a `Gateway` listener on port 80.
- **Step 2.3:** Deploy a backend pod/deployment to act as your application service.
- **Step 2.4:** Create an `HTTPRoute` mapping the backend service to the Envoy Gateway.

## 3. Prometheus Monitoring
- **Step 3.1:** Add the Prometheus community Helm repository.
- **Step 3.2:** Install the `kube-prometheus-stack` (via Helm), which provides Prometheus, Grafana, and standard Kubernetes node exporters.
- **Step 3.3:** Configure Prometheus `ServiceMonitors` or `PodMonitors` to discover and scrape metrics from Envoy Gateway, the backend application, and the MySQL cluster.

## 4. MySQL Cluster via Percona Operator
- **Step 4.1:** Add the Percona Helm repository to your local Helm configuration.
- **Step 4.2:** Install the Percona Operator for MySQL.
- **Step 4.3:** Create a Kubernetes `Secret` to securely hold the MySQL root and user passwords.
- **Step 4.4:** Deploy the Custom Resource (CR) - e.g., `PerconaXtraDBCluster` or `InnoDBCluster` depending on the operator version - to provision the MySQL database instances.

## Verification Plan
After deploying everything, we will do the following checks:
1. **Routing:** Access the backend service through the Envoy Gateway API (via port-forward or LoadBalancer).
2. **Observability:** Port-forward to the Prometheus UI and ensure targets (Envoy Gateway, MySQL, backend) show up as `UP`.
3. **Database:** Exec into a pod containing a MySQL client, securely connect using the provided secrets, and verify database cluster topology.
