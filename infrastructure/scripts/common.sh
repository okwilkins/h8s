#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

: "${INFRA_ROOT:?INFRA_ROOT must be set}"
: "${TF_DIR:=$INFRA_ROOT/03-talos-configure}"
: "${NAMESPACE:=vault}"
: "${POD_NAME:=vault-0}"

kubectl_wrapper() {
  kubectl --kubeconfig <(printf '%s' "$KUBECONFIG_CONTENT") --server="https://${SERVER}:6443" "$@"
}

tf_output_raw() {
  local output

  if ! output=$(tofu -chdir="$TF_DIR" output -no-color -raw "$1"); then
    echo "Failed to read Terraform output '$1' from $TF_DIR" >&2
    exit 1
  fi
  printf '%s' "${output%$'\n'}"
}

load_tf_kube_env() {
  KUBECONFIG_CONTENT="$(tf_output_raw kubeconfig)" || return
  SERVER="$(tf_output_raw first_node_ip)" || return
}
