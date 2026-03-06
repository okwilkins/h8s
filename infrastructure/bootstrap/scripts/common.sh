#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Default TF_DIR to 06-vault-init if not set
: "${TF_DIR:=$INFRA_ROOT/06-vault-init}"
: "${OUT_FILE:=./secrets/vault-init.json}"
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
  tofu -chdir="$TF_DIR" output -raw "$1"
}

load_tf_kube_env() {
  SERVER="$(tf_output_raw first_node_ip)"
  CA_CERT="$(tf_output_raw ca_cert)"
  CLIENT_CERT="$(tf_output_raw client_cert)"
  CLIENT_KEY="$(tf_output_raw client_key)"
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

