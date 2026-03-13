#!/bin/bash
set -e

# Load .env if exists
if [ -f ../.env ]; then
  echo "Loading variables from ../.env..."
  set -a
  source ../.env
  set +a
elif [ -f .env ]; then
  echo "Loading variables from .env..."
  set -a
  source .env
  set +a
fi

REQUIRED_VARS=(
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
  S3_ENDPOINT
  S3_BUCKET
)

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    echo "Error: $var not set."
    exit 1
  fi
done

echo "Starting OpenSearch Cluster Setup..."

# Namespace
echo "Creating namespace 'opensearch'..."
kubectl create namespace opensearch --dry-run=client -o yaml | kubectl apply -f -

# Helm Repo
echo "Adding OpenSearch Helm repository..."
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update

# Certificates Generation
if [ -f "certs/root-ca.pem" ] && [ -f "certs/node.pem" ] && [ -f "certs/admin.pem" ]; then
  echo "Certificates found in certs/ directory. reusing them..."
else
  echo "Generating self-signed certificates for transport layer..."
  # Clean up existing certs
  rm -rf certs
  mkdir -p certs
  cd certs

  # Root CA
  openssl genrsa -out root-ca-key.pem 2048
  openssl req -new -x509 -sha256 -key root-ca-key.pem -subj "/CN=root-ca" -out root-ca.pem -days 365

  # Admin Cert
  openssl genrsa -out admin-key-temp.pem 2048
  openssl pkcs8 -inform PEM -outform PEM -in admin-key-temp.pem -topk8 -nocrypt -out admin-key.pem
  openssl req -new -key admin-key.pem -subj "/CN=admin" -out admin.csr
  openssl x509 -req -in admin.csr -CA root-ca.pem -CAkey root-ca-key.pem -CAcreateserial -sha256 -out admin.pem -days 365

  # Node Cert
  openssl genrsa -out node-key-temp.pem 2048
  openssl pkcs8 -inform PEM -outform PEM -in node-key-temp.pem -topk8 -nocrypt -out node-key.pem
  openssl req -new -key node-key.pem -subj "/CN=node" -out node.csr
  echo "subjectAltName=DNS:localhost,IP:127.0.0.1,DNS:opensearch-cluster-master-headless,DNS:opensearch-cluster-master-headless.opensearch.svc,DNS:*.opensearch-cluster-master-headless,DNS:*.opensearch-cluster-master-headless.opensearch.svc,DNS:*.opensearch-cluster-master-headless.opensearch.svc.cluster.local,DNS:opensearch-cluster-master-0.opensearch-cluster-master-headless.opensearch.svc.cluster.local,DNS:opensearch-cluster-master-1.opensearch-cluster-master-headless.opensearch.svc.cluster.local,DNS:opensearch-cluster-master-2.opensearch-cluster-master-headless.opensearch.svc.cluster.local" > node.ext
  openssl x509 -req -in node.csr -CA root-ca.pem -CAkey root-ca-key.pem -CAcreateserial -sha256 -out node.pem -days 365 -extfile node.ext

  # Cleanup
  rm admin-key-temp.pem admin.csr node-key-temp.pem node.csr node.ext

  cd ..
fi

# Transport Secret
echo "Creating transport certificates secret..."
kubectl create secret generic opensearch-transport-certs -n opensearch \
  --from-file=transport-key.pem=certs/node-key.pem \
  --from-file=transport.pem=certs/node.pem \
  --from-file=transport-ca.pem=certs/root-ca.pem \
  --from-file=admin-key.pem=certs/admin-key.pem \
  --from-file=admin.pem=certs/admin.pem \
  --dry-run=client -o yaml | kubectl apply -f -

# S3 Secret
echo "Creating S3 credentials secret..."
kubectl create secret generic opensearch-s3-secret -n opensearch \
  --from-literal=s3.client.default.access_key="$AWS_ACCESS_KEY_ID" \
  --from-literal=s3.client.default.secret_key="$AWS_SECRET_ACCESS_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy OpenSearch
echo "Deploying OpenSearch Cluster..."
helm upgrade --install opensearch opensearch/opensearch \
  -n opensearch \
  --version 3.5.0 \
  -f opensearch-values.yaml \
  --set "config.opensearch\.yml.s3\.client\.default\.endpoint=$S3_ENDPOINT" \
  --set "config.opensearch\.yml.s3\.client\.default\.protocol=https" \
  --set "config.opensearch\.yml.s3\.client\.default\.path_style_access=true"

# Deploy Dashboards
echo "Deploying OpenSearch Dashboards..."
helm upgrade --install opensearch-dashboards opensearch/opensearch-dashboards \
  -n opensearch \
  --version 3.5.0 \
  -f dashboards-values.yaml

# Wait for OpenSearch Cluster to be ready
echo "Waiting for OpenSearch Cluster (statefulset/opensearch-cluster-master) to be ready..."
kubectl rollout status statefulset/opensearch-cluster-master -n opensearch --timeout=300s || {
  echo "Error: OpenSearch Cluster failed to become ready within 5 minutes."
  exit 1
}

# Create Exporter User
if kubectl get secret opensearch-exporter-creds -n opensearch >/dev/null 2>&1; then
  echo "Secret 'opensearch-exporter-creds' already exists. Retrieving password..."
  EXPORTER_PASSWORD=$(kubectl get secret opensearch-exporter-creds -n opensearch -o jsonpath='{.data.password}' | base64 -d)
else
  echo "Creating OpenSearch Exporter credentials and user..."
  EXPORTER_PASSWORD=$(openssl rand -base64 12)
  kubectl create secret generic opensearch-exporter-creds -n opensearch \
    --from-literal=username=prom_exporter \
    --from-literal=password="$EXPORTER_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

# Run Job to create user in OpenSearch
kubectl delete job create-exporter-user -n opensearch --ignore-not-found
kubectl apply -f create-user-job.yaml
echo "Waiting for user creation job to complete..."
kubectl wait --for=condition=complete job/create-exporter-user -n opensearch --timeout=300s

# Deploy Prometheus Exporter
echo "Deploying Prometheus OpenSearch Exporter..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install opensearch-exporter prometheus-community/prometheus-elasticsearch-exporter \
  -n opensearch \
  -f exporter-values.yaml \
  --set es.uri="http://prom_exporter:$EXPORTER_PASSWORD@opensearch-cluster-master:9200"

echo "Setup complete!"
echo "You can check the status with: kubectl get pods -n opensearch"
echo "You can access OpenSearch Dashboards with: kubectl port-forward -n opensearch svc/opensearch-dashboards 5601:5601"
echo "You can access OpenSearch Cluster with: kubectl port-forward -n opensearch svc/opensearch-cluster-master 9200:9200"
echo "You can access OpenSearch Exporter metrics with: kubectl port-forward -n opensearch svc/opensearch-exporter-prometheus-elasticsearch-exporter 9114:9114"
