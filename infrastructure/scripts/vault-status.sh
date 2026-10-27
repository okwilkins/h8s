#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

load_tf_kube_env

kubectl_wrapper exec "$POD_NAME" -n "$NAMESPACE" -- vault status

