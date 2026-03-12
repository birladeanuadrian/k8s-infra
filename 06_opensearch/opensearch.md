# OpenSearch Cluster Setup

This directory contains the configuration and scripts to deploy an OpenSearch cluster on Kubernetes.

## Architecture

- **Cluster:** Single-node or Multi-node OpenSearch cluster (configurable via `values.yaml`).
- **TLS:** 
  - **Transport Layer (9300):** Generic self-signed certificates for inter-node communication.
  - **HTTP Layer (9200):** Plain HTTP (no TLS) as per requirements.
- **Storage:** Persistent Volume Claims for data storage.
- **Backup:** S3 repository plugin configured for snapshots using a custom S3 endpoint (e.g., MinIO or AWS S3 compatible).
- **Visualization:** OpenSearch Dashboards (Kibana) deployed alongside.

## Prerequisites

- Kubernetes cluster running.
- `helm` installed.
- `kubectl` installed.
- `openssl` installed (for certificate generation).

## Setup Steps

1. **Configure Environment Variables:**
   Copy `.env.example` to `.env` and fill in the required values:
   ```bash
   cp .env.example .env
   # Edit .env with your specific configuration
   ```

2. **Run Setup Script:**
   The `setup.sh` script will automate the deployment process:
   - Create the `opensearch` namespace.
   - Generate self-signed certificates for transport layer encryption.
   - Create Kubernetes secrets for certificates and S3 credentials.
   - Install the OpenSearch Helm chart.
   - Install the OpenSearch Dashboards Helm chart.

   ```bash
   ./setup.sh
   ```

3. **Verify Deployment:**
   - Check if pods are running:
     ```bash
     kubectl get pods -n opensearch
     ```
   - Port-forward to OpenSearch Dashboards:
     ```bash
     kubectl port-forward -n opensearch svc/opensearch-dashboards 5601:5601
     ```
   - Access Dashboards at `http://localhost:5601`.

## Backup Configuration

The cluster is configured with the S3 repository plugin. You need to register the snapshot repository manually or via a job after the cluster is up.

Example API call to register repository:
```bash
curl -XPUT "http://localhost:9200/_snapshot/s3-backup" -H 'Content-Type: application/json' -d'
{
  "type": "s3",
  "settings": {
    "bucket": "my-backup-bucket",
    "endpoint": "s3.custom-endpoint.com"
  }
}'
```

## Teardown

To remove the OpenSearch cluster and all associated resources:

```bash
./teardown.sh
```

