# Gateway API and Cilium Setup

This document describes the steps to install and configure Cilium with Kubernetes Gateway API support, and how to expose an NGINX deployment securely.

## 1. Install Gateway API CRDs
Before installing Cilium with Gateway API support, the standard Kubernetes Gateway API Custom Resource Definitions (CRDs) must be installed in the cluster. We use the standard sig-network repository for these CRDs.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml
```

## 2. Install Cilium via Helm
We will install Cilium using Helm and explicitly enable Gateway API support. This allows Cilium to act as the Gateway controller.

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium --version 1.19.1 \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set gatewayAPI.enabled=true
```

Wait for the Cilium pods to be ready before proceeding.

## 3. Deploy NGINX Application
We'll deploy a simple NGINX application and a Service that exposes it on port 80.

```bash
kubectl apply -f nginx.yaml
```

## 4. Configure Gateway API Resources
We need to create the `GatewayClass`, `Gateway`, and `HTTPRoute` to route traffic to our NGINX service for the hostname `my-app.local`.

Create a file `gateway.yaml`:

```yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: cilium
spec:
  controllerName: io.cilium/gateway-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: default
spec:
  gatewayClassName: cilium
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: my-app.local
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: nginx-route
  namespace: default
spec:
  parentRefs:
  - name: my-gateway
  hostnames:
  - my-app.local
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: nginx
      port: 80
```

Apply these resources:
```bash
kubectl apply -f gateway.yaml
```

## 5. Local DNS Configuration
To test this locally from your machine, you need to map `my-app.local` to the IP address of the Gateway.
Find the Gateway IP:
```bash
kubectl get gateway my-gateway
```
Then add an entry to your `/etc/hosts` file:
```
<GATEWAY_IP> my-app.local
```
