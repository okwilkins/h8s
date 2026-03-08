# Wait for Kubernetes API to be ready
# This script polls the Kubernetes API until it responds, handling the
# "connection refused" error that occurs immediately after Talos bootstrap.
#
#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

load_tf_kube_env
create_cert_dir

echo "Waiting for Kubernetes API to be ready at https://${SERVER}:6443..."

MAX_ATTEMPTS=60
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  
  if kubectl_wrapper get namespace kube-system >/dev/null 2>&1; then
    echo "Kubernetes API is ready!"
    exit 0
  fi
  
  echo "  Attempt $ATTEMPT/$MAX_ATTEMPTS: Kubernetes API not ready yet, retrying in 5 seconds..."
  sleep 5
done

echo "ERROR: Timeout waiting for Kubernetes API after $MAX_ATTEMPTS attempts"
exit 1

