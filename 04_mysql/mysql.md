# MySQL Cluster with Percona Operator

This document describes how to deploy a 3-node MySQL InnoDB cluster using the Percona Operator for MySQL (Percona Server), with Prometheus monitoring.

## 1. Install Percona Operator via Helm

Add the Percona Helm repository and install the operator:

```bash
helm repo add percona https://percona.github.io/percona-helm-charts/
helm repo update
helm upgrade --install percona-mysql-operator percona/ps-operator \
  --version 1.0.0 \
  -n mysql \
  --create-namespace
```

Wait for the operator to be ready:

```bash
kubectl wait --timeout=5m -n mysql deployment/percona-mysql-operator-ps-operator --for=condition=Available
```

## 2. Create MySQL Secrets

The `secrets.yaml` file is a template that references environment variables. Set them before applying:

```bash
export MYSQL_ROOT_PASSWORD=<root-password>
export MYSQL_DATABASE=<database-name>
export MYSQL_USER=<app-user>
export MYSQL_PASSWORD=<app-password>
```

See [`secrets.yaml`](secrets.yaml) for the template.

Apply:

```bash
envsubst < secrets.yaml | kubectl apply -f -
```

## 3. Deploy the MySQL InnoDB Cluster

The `cluster.yaml` file defines a `PerconaServerMySQL` custom resource with the following configuration:

- **3 MySQL nodes** using group replication (InnoDB Cluster)
- **MySQL Router** for automatic connection routing and failover
- **mysqld_exporter sidecar** on each MySQL pod for Prometheus metrics (port `9104`)
- **10Gi persistent storage** per MySQL node
- **Scheduled S3 backups** — daily at 03:00 UTC, retaining the last 7 backups

See [`cluster.yaml`](cluster.yaml) for the full resource definition.

Apply:

```bash
kubectl apply -f cluster.yaml
```


## 4. S3 Backups

The cluster is configured with automated daily backups to S3. The backup configuration in `cluster.yaml` defines:

- **Storage:** S3 bucket `mysql-backups` in `eu-central-1`
- **Schedule:** Daily at 03:00 UTC (`0 3 * * *`)
- **Retention:** Last 7 backups

### S3 Credentials

The `s3-backup-secret.yaml` file is a template that references environment variables. Set them before applying:

```bash
export AWS_ACCESS_KEY_ID=<s3-access-key>
export AWS_SECRET_ACCESS_KEY=<s3-secret-key>
```

See [`s3-backup-secret.yaml`](s3-backup-secret.yaml) for the template.

For S3-compatible storage (e.g. MinIO), uncomment and set the `endpointUrl` field in `cluster.yaml`.

Apply:

```bash
envsubst < s3-backup-secret.yaml | kubectl apply -f -
```

### Manual Backup

To trigger a backup manually outside the schedule, create a one-off `PerconaServerMySQLBackup` resource:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: ps.percona.com/v1
kind: PerconaServerMySQLBackup
metadata:
  name: manual-backup-$(date +%Y%m%d%H%M%S)
  namespace: mysql
spec:
  clusterName: mysql-cluster
  storageName: s3-backup
EOF
```

### Checking Backup Status

```bash
kubectl get ps-backup -n mysql
```

## 5. MySQL Exporter Configuration

The `mysqld_exporter` requires a configuration file with database credentials. The `mysql-exporter-config.yaml` template creates a Secret mounted by the exporter sidecar.

Apply:
```bash
envsubst < mysql-exporter-config.yaml | kubectl apply -f -
```

## 6. Prometheus Monitoring

The `mysql-service-monitor.yaml` file creates a `ServiceMonitor` that instructs Prometheus to scrape the `mysqld_exporter` sidecar running on each MySQL pod. It uses the `release: prometheus` label to be picked up by the kube-prometheus-stack.

Key metrics exposed by the exporter:

| Metric | Type | Description |
|---|---|---|
| `mysql_global_status_threads_connected` | gauge | Current number of open connections |
| `mysql_global_status_threads_running` | gauge | Number of threads not sleeping |
| `mysql_global_status_queries` | counter | Total number of queries executed |
| `mysql_global_status_slow_queries` | counter | Number of slow queries |
| `mysql_global_status_innodb_buffer_pool_reads` | counter | Reads from disk (buffer pool misses) |
| `mysql_global_status_innodb_buffer_pool_read_requests` | counter | Total buffer pool read requests |
| `mysql_global_status_innodb_row_ops_total` | counter | Row operations (reads, inserts, updates, deletes) |
| `mysql_global_status_innodb_deadlocks` | counter | Total InnoDB deadlocks |
| `mysql_global_status_innodb_data_reads` | counter | Total InnoDB data reads |
| `mysql_global_status_innodb_data_writes` | counter | Total InnoDB data writes |
| `mysql_global_status_bytes_received` | counter | Total bytes received from all clients |
| `mysql_global_status_bytes_sent` | counter | Total bytes sent to all clients |
| `mysql_global_status_aborted_connects` | counter | Failed connection attempts |
| `mysql_global_status_aborted_clients` | counter | Connections closed without proper shutdown |
| `mysql_info_schema_innodb_metrics_*` | various | Detailed InnoDB engine metrics (tablespaces, transactions, etc.) |

See [`mysql-service-monitor.yaml`](mysql-service-monitor.yaml) for the full resource definition.

Apply:

```bash
kubectl apply -f mysql-service-monitor.yaml
```

## 7. Accessing the Cluster

### From within the cluster

Connect to the MySQL cluster from any pod:

```bash
kubectl run mysql-client --rm -it --restart=Never --namespace=mysql \
  --image=percona/percona-server:8.0.45 -- \
  mysql -h mysql-cluster-mysql.mysql.svc.cluster.local -u root -p
```

### From a local MySQL client

Port-forward the MySQL Router service to your local machine:

```bash
kubectl port-forward svc/mysql-cluster-router -n mysql 3306:3306
```

Then connect using any local MySQL client:

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p
```

## Automated Setup

The `setup.sh` script automates all steps. It is idempotent and can be run multiple times:

```bash
./setup.sh
```
