set -e

# Load .env file automatically if it exists
if [ -f .env ]; then
  echo "Loading variables from .env..."
  set -a
  source .env
  set +a
fi

# Required environment variables:
#   MYSQL_ROOT_PASSWORD    - Root password for the MySQL cluster
#   MYSQL_DATABASE         - Application database name
#   MYSQL_USER             - Application user name
#   MYSQL_PASSWORD         - Application user password
#   AWS_ACCESS_KEY_ID      - S3 backup access key
#   AWS_SECRET_ACCESS_KEY  - S3 backup secret key

REQUIRED_VARS=(
  MYSQL_ROOT_PASSWORD
  MYSQL_DATABASE
  MYSQL_USER
  MYSQL_PASSWORD
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
)

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    echo "Error: environment variable $var is not set."
    echo ""
    echo "Usage:"
    echo "  export MYSQL_ROOT_PASSWORD=<root-password>"
    echo "  export MYSQL_DATABASE=<database-name>"
    echo "  export MYSQL_USER=<app-user>"
    echo "  export MYSQL_PASSWORD=<app-password>"
    echo "  export AWS_ACCESS_KEY_ID=<s3-access-key>"
    echo "  export AWS_SECRET_ACCESS_KEY=<s3-secret-key>"
    echo "  ./setup.sh"
    exit 1
  fi
done

echo "Starting MySQL Cluster Setup (Percona Operator for MySQL - InnoDB)..."

echo "1. Creating mysql namespace..."
kubectl create namespace mysql --dry-run=client -o yaml | kubectl apply -f -

echo "2. Adding Percona Helm repository..."
helm repo add percona https://percona.github.io/percona-helm-charts/
helm repo update

echo "3. Installing Percona Operator for MySQL (InnoDB)..."
helm upgrade --install percona-mysql-operator percona/ps-operator \
  --version 1.0.0 \
  -n mysql \
  --create-namespace

echo "4. Waiting for Percona Operator to be ready..."
kubectl wait --timeout=5m -n mysql deployment/percona-mysql-operator-ps-operator --for=condition=Available

echo "5. Creating MySQL secrets..."
envsubst < secrets.yaml | kubectl apply -f -

echo "6. Creating S3 backup credentials secret..."
envsubst < s3-backup-secret.yaml | kubectl apply -f -

echo "6.1. Creating mysqld_exporter config secret..."
envsubst < mysql-exporter-config.yaml | kubectl apply -f -

echo "7. Deploying MySQL InnoDB Cluster (3 nodes)..."
kubectl apply -f cluster.yaml

echo "8. Applying ServiceMonitor for Prometheus..."
kubectl apply -f mysql-service-monitor.yaml

echo "Setup completed."
echo ""
echo "MySQL cluster connection details:"
echo "  Host (in-cluster): mysql-cluster-mysql.mysql.svc.cluster.local"
echo "  Port: 3306"
echo "  Root password: stored in secret 'mysql-cluster-secrets' in namespace 'mysql'"
echo ""
echo "To connect from a local MySQL client, port-forward the router service:"
echo "  kubectl port-forward svc/mysql-cluster-router -n mysql 3306:3306"
echo "  mysql -h 127.0.0.1 -P 3306 -u root -p"
