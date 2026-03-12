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

# ...existing code...
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
# ...existing code...
  --set "config.opensearch\.yml.s3\.client\.default\.path_style_access=true"

# Deploy Dashboards
echo "Deploying OpenSearch Dashboards..."
helm upgrade --install opensearch-dashboards opensearch/opensearch-dashboards \
  -n opensearch \
  --version 3.5.0 \
  -f dashboards-values.yaml

echo "Setup complete!"
echo "You can check the status with: kubectl get pods -n opensearch"
echo "You can access OpenSearch Dashboards with: kubectl port-forward -n opensearch svc/opensearch-dashboards 5601:5601"
echo "You can access OpenSearch Cluster with: kubectl port-forward -n opensearch svc/opensearch-cluster-master 9200:9200"
