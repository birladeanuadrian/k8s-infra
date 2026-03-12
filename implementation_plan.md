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

## 4. MySQL InnoDB Cluster via Percona Operator
- **Step 4.1:** Add the Percona Helm repository and install the Percona Operator for MySQL (`ps-operator`).
- **Step 4.2:** Create a Kubernetes `Secret` to securely hold the MySQL root and application user passwords.
- **Step 4.3:** Deploy the `PerconaServerMySQL` CR with 3-node InnoDB group replication and MySQL Router.
- **Step 4.4:** Deploy a `mysqld_exporter` sidecar on each MySQL pod and create a `ServiceMonitor` for Prometheus scraping.
- **Step 4.5:** Configure scheduled S3 backups (daily, 7-day retention) with credentials stored in a Kubernetes `Secret`.

## 5. Istio Service Mesh (Ambient Mode)
- **Step 5.1:** Install Istio CLI (`istioctl`) on your local machine and install Istio into the cluster using the `ambient` profile.
- **Step 5.2:** Verify installation of key components: `istiod`, `ztunnel` (DaemonSet), and `istio-cni` (DaemonSet).
- **Step 5.3:** Enable Ambient mode for all application namespaces (e.g., `default`, `mysql`, `monitoring`) by applying the label `istio.io/dataplane-mode=ambient`.
- **Step 5.4:** Configure strict mTLS for the entire mesh by applying a cluster-wide `PeerAuthentication` policy with `mtls.mode: STRICT`.
- **Step 5.5:** Create `AuthorizationPolicy` rules to define allowed service-to-service communication (e.g., allow `gateway` to talk to `backend`, deny others).
- **Step 5.6:** Verify mTLS enforcement and access control ensuring only authorized services can communicate.

## 6. OpenSearch Cluster
- **Step 6.1:** Add the Opensearch Helm repository.
- **Step 6.2:** Generate self-signed certificates for the transport layer (wildcard certs for secure inter-node communication).
- **Step 6.3:** Create a Kubernetes `Secret` containing the transport certificates.
- **Step 6.4:** Configure the OpenSearch Helm values:
    - Set replicas to 3.
    - Enable TLS for transport layer with strict hostname verification (using generated certs).
    - Disable TLS for HTTP layer (9200) - use plain HTTP.
    - Set up the S3 repository plugin reading endpoint and bucket from environment variables.
- **Step 6.5:** Deploy the OpenSearch cluster using Helm.
- **Step 6.6:** Deploy OpenSearch Dashboards (Kibana) using Helm.
- **Step 6.7:** Configure a snapshot repository for the S3 backup.

## Verification Plan
After deploying everything, we will do the following checks:
1. **Routing:** Access the backend service through the Envoy Gateway API (via port-forward or LoadBalancer).
2. **Observability:** Port-forward to the Prometheus UI and ensure targets (Envoy Gateway, MySQL, backend) show up as `UP`.
3. **Database:** Exec into a pod containing a MySQL client, securely connect using the provided secrets, and verify database cluster topology.
4. **Service Mesh (Ambient):** Validate that services are part of the mesh (ztunnel handling traffic), mTLS is enforced, and AuthorizationPolicies restrict unauthorized access.
5. **OpenSearch:** Access the OpenSearch cluster using the HTTP endpoint, verify cluster health. Access OpenSearch Dashboards to verify UI connectivity. Ensure indices are being backed up to S3.
