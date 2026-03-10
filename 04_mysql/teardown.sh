#!/bin/bash

# This script removes the MySQL cluster and all associated resources.
# WARNING: This will delete all data!

echo "1. Deleting MySQL Cluster instance..."
kubectl delete -f cluster.yaml --ignore-not-found

echo "2. Deleting ServiceMonitor..."
kubectl delete -f mysql-service-monitor.yaml --ignore-not-found

echo "3. Deleting Secrets..."
kubectl delete secret mysql-cluster-secrets mysql-s3-backup-credentials mysqld-exporter-config -n mysql --ignore-not-found

echo "4. Deleting PVCs (Data Volume) - THIS ERASES ALL DATABASE DATA..."
# Deleting PVCs is necessary to re-initialize the database with new user credentials
kubectl delete pvc --all -n mysql

echo "5. Uninstalling Percona Operator..."
helm uninstall percona-mysql-operator -n mysql

echo "6. Deleting Namespace..."
kubectl delete namespace mysql --ignore-not-found

echo "Teardown complete."

