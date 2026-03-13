#!/bin/bash

echo "Tearing down OpenSearch Cluster and Dashboards..."

# Uninstall Helm Releases
helm uninstall opensearch-dashboards -n opensearch --wait || echo "Dashboards not installed"
helm uninstall opensearch -n opensearch --wait || echo "Cluster not installed"

# Delete Jobs
kubectl delete job update-admin-password -n opensearch --ignore-not-found
kubectl delete job create-monitoring-user -n opensearch --ignore-not-found
kubectl delete podmonitor opensearch-exporter -n opensearch --ignore-not-found

# Delete Secrets
kubectl delete secret opensearch-transport-certs -n opensearch --ignore-not-found
kubectl delete secret opensearch-s3-secret -n opensearch --ignore-not-found
kubectl delete secret opensearch-exporter-creds -n opensearch --ignore-not-found
kubectl delete secret opensearch-admin-password -n opensearch --ignore-not-found

# Delete PVCs (Optional - usually good to keep data, but tearing down implies cleanup)
read -p "Delete Persistent Volume Claims? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete pvc -l app.kubernetes.io/instance=opensearch -n opensearch
    echo "PVCs deleted."
fi

# Delete Namespace (Optional)
read -p "Delete Namespace 'opensearch'? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete namespace opensearch
    echo "Namespace deleted."
fi

echo "Teardown complete."

