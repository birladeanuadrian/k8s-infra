# Istio Service Mesh (Ambient Mode)

## Prerequisites
- **istioctl**: The Istio command-line utility must be installed on your local machine (laptop). It is used to install Istio into the cluster and manage the mesh configuration.

## Setup
Run the setup script to download `istioctl` (locally) and install Istio (into the cluster).

```bash
cd 05_istio
./setup.sh
```

## Manual Installation
If you prefer to install `istioctl` manually:
1. Download the latest release from [GitHub](https://github.com/istio/istio/releases).
2. Extract the archive.
3. Add the `bin` directory to your system PATH.

## Verification
Check the status of the mesh:
```bash
istioctl verify-install
```

