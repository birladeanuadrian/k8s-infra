# OpenSearch Cluster Setup

This directory contains the configuration and scripts to deploy a secure, monitored OpenSearch cluster on Kubernetes with automated backups.

## Architecture

- **Cluster:** 3-node OpenSearch cluster (StatefulSet).
- **Security:**
  - **Transport Layer (9300):** TLS enabled with self-signed certificates (auto-generated).
  - **HTTP Layer (9200):** Plain HTTP (internal cluster communication), but with **Basic Authentication** enabled via the Security plugin.
  - **User Management:**
    - **Admin:** Credentials managed via `opensearch-admin-password` secret.
    - **Monitoring:** Dedicated `prom_exporter` user with restricted permissions managed via `opensearch-exporter-creds` secret.
- **Microservices:**
  - **Dashboards:** OpenSearch Dashboards (Kibana) with enhanced discover features (Workspaces, Data Sources, Explore) enabled.
  - **Exporter:** Prometheus metrics exposed via the `opensearch-prometheus-exporter` plugin at `/_prometheus/metrics`.
- **Storage:**
  - **Data:** Persistent Volume Claims for data storage.
  - **Backups:** Automated S3 snapshots using the `repository-s3` plugin.
  - **Config:** `opensearch-backup-config` ConfigMap stores backup settings.

## Prerequisites

- Kubernetes cluster running.
- `helm` installed.
- `kubectl` installed.
- `openssl` installed (for certificate & password generation).

## Configuration

1. **Environment Variables:**
   Create a `.env` file in this directory or the parent directory with the following variables:
   ```bash
   AWS_ACCESS_KEY_ID=your_access_key
   AWS_SECRET_ACCESS_KEY=your_secret_key
   AWS_REGION=your_aws_region
   S3_ENDPOINT=s3.amazonaws.com # or custom endpoint
   S3_BUCKET=your_backup_bucket
   ```

## Setup Steps

The `setup.sh` script automates the entire deployment process:

1. **Namespace & Repo:** Creates `opensearch` namespace and adds the Helm repository.
2. **Certificates:** Generates self-signed certificates for transport layer TLS if they don't exist in `certs/`.
3. **Secrets Management:**
   - `opensearch-transport-certs`: Transport layer certificates.
   - `opensearch-s3-secret`: S3 credentials for backups.
   - `opensearch-admin-password`: Admin user credentials (created if missing).
   - `opensearch-exporter-creds`: Monitoring user credentials (auto-generated if missing).
4. **Deployments:**
   - Installs OpenSearch Cluster (v3.5.0) via Helm.
   - Installs OpenSearch Dashboards (v3.5.0) via Helm.
5. **Post-Deployment Automation (Jobs):**
   - **`update-admin-password`**: Updates the internal `admin` user password to match the secret.
   - **`create-monitoring-user`**: Creates the `prom_exporter` user and custom roles for Prometheus scraping.
   - **`create-backup-policy`**: Registers the S3 snapshot repository and creates a daily backup policy.
6. **Monitoring:**
   - Applies a `PodMonitor` `opensearch-exporter` to scrape metrics from port 9200.

### Running Setup

```bash
./setup.sh
```

## Verification

### 1. Cluster Status
Check if all pods are running:
```bash
kubectl get pods -n opensearch
```

### 2. Access Dashboards
Port-forward and access at `http://localhost:5601`. Log in with username `admin` and the password from the secret.
```bash
# Get Admin Password
kubectl get secret opensearch-admin-password -n opensearch -o jsonpath='{.data.password}' | base64 -d
# Port-forward
kubectl port-forward -n opensearch svc/opensearch-dashboards 5601:5601
```

### 3. Monitoring (Prometheus)
Port-forward the OpenSearch service to verify metrics are exposed (requires Basic Auth):
```bash
kubectl port-forward -n opensearch svc/opensearch-cluster-master 9200:9200
# In another terminal (using exporter creds)
curl -u prom_exporter:<password> http://localhost:9200/_prometheus/metrics
```

### 4. Backups
The `create-backup-policy` job configures a policy named `daily-backups`.
- **Schedule:** Daily at 00:00 UTC.
- **Retention:** 30 days.

**Trigger a manual backup:**
```bash
# Verify repository status
curl -XGET "http://localhost:9200/_snapshot/s3-repo?pretty" -u admin:<password>

# Trigger manual snapshot
kubectl run trigger-backup --rm -i --restart=Never --image=curlimages/curl -n opensearch --command -- /bin/sh -c "curl -XPOST -u admin:<password> http://opensearch-cluster-master:9200/_plugins/_sm/policies/daily-backups/_trigger"
```

## Teardown

To remove the OpenSearch cluster and all associated resources (including secrets, jobs, and PVCs):

```bash
./teardown.sh
```

