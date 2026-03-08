#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

: "${INFRA_ROOT:?INFRA_ROOT must be set}"
: "${TF_DIR:=$INFRA_ROOT/03-talos-configure}"
: "${OUT_FILE:=$INFRA_ROOT/secrets/vault-init.json}"
: "${NAMESPACE:=vault}"
: "${POD_NAME:=vault-0}"

kubectl_wrapper() {
  kubectl \
    --server="https://${SERVER}:6443" \
    --certificate-authority="$CERT_DIR/ca.crt" \
    --client-certificate="$CERT_DIR/client.crt" \
    --client-key="$CERT_DIR/client.key" \
    "$@"
}

tf_output_raw() {
  local output

  if ! output=$(tofu -chdir="$TF_DIR" output -no-color -raw "$1" 2>/dev/null); then
    echo "Failed to read Terraform output '$1' from $TF_DIR" >&2
    exit 1
  fi
  printf '%s' "${output%$'\n'}"
}

load_tf_kube_env() {
  SERVER="$(tf_output_raw first_node_ip)"
  CA_CERT="$(tf_output_raw ca_cert)"
  CLIENT_CERT="$(tf_output_raw client_cert)"
  CLIENT_KEY="$(tf_output_raw client_key)"

  export SERVER CA_CERT CLIENT_CERT CLIENT_KEY
}

create_cert_dir() {
  CERT_DIR="$(mktemp -d)"
  trap 'rm -rf "$CERT_DIR"' EXIT

  printf '%s' "$CA_CERT" > "$CERT_DIR/ca.crt"
  printf '%s' "$CLIENT_CERT" > "$CERT_DIR/client.crt"
  printf '%s' "$CLIENT_KEY" > "$CERT_DIR/client.key"

  chmod 700 "$CERT_DIR"
  chmod 600 "$CERT_DIR/ca.crt" "$CERT_DIR/client.crt" "$CERT_DIR/client.key"
}
