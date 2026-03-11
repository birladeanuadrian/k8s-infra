#!/bin/bash
set -e

# Load .env file automatically if it exists (for consistency with other scripts)
if [ -f .env ]; then
  echo "Loading variables from .env..."
  set -a
  source .env
  set +a
fi

ISTIO_VERSION="1.28.4"

# Check if istioctl is already in path
if command -v istioctl &> /dev/null; then
    echo "istioctl found in PATH: $(which istioctl)"
else
    echo "istioctl not found in PATH."

    # Check if we already downloaded it locally
    if [ -d "istio-${ISTIO_VERSION}" ]; then
        echo "Found local Istio directory: istio-${ISTIO_VERSION}"
    else
        echo "Downloading Istio ${ISTIO_VERSION}..."
        # Use the official download script
        curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} TARGET_ARCH=x86_64 sh -
    fi

    # Add to PATH for this session
    echo "Adding local istioctl to PATH..."
    export PATH="$PWD/istio-${ISTIO_VERSION}/bin:$PATH"
fi

echo "Verifying istioctl setup..."
istioctl version --short --remote=false

echo "Installing Istio using 'ambient' profile..."
istioctl install --set profile=ambient -y

echo "Applying Ambient label to namespaces..."
# Add label to all application namespaces
kubectl label namespace default istio.io/dataplane-mode=ambient --overwrite
kubectl label namespace application istio.io/dataplane-mode=ambient --overwrite
kubectl label namespace mysql istio.io/dataplane-mode=ambient --overwrite
kubectl label namespace monitoring istio.io/dataplane-mode=ambient --overwrite
kubectl label namespace envoy-gateway-system istio.io/dataplane-mode=ambient --overwrite

# Create PeerAuthentication policy (strict mTLS)
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
EOF

echo "Istio (Ambient mode) setup complete."


