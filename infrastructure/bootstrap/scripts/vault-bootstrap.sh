#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

load_tf_kube_env()
create_cert_dir()

echo "Waiting for Vault pod..."
kubectl_wrapper wait \
  --for=jsonpath='{.status.phase}'=Running \
  "pod/${POD_NAME}" \
  -n "$NAMESPACE" \
  --timeout=180s >/dev/null

echo "Checking Vault status..."
STATUS_JSON="$(
  kubectl_wrapper exec "$POD_NAME" -n "$NAMESPACE" -- \
    vault status -format=json 2>/dev/null || true
)"

if jq -e '.initialized == true' >/dev/null 2>&1 <<<"$STATUS_JSON"; then
  echo "Vault is already initialised; skipping bootstrap."
  exit 0
fi

mkdir -p "$(dirname "$OUT_FILE")"
umask 077

echo "Initialising Vault..."
INIT_JSON="$(
  kubectl_wrapper exec "$POD_NAME" -n "$NAMESPACE" -- \
    vault operator init -format=json
)"

printf '%s\n' "$INIT_JSON" > "$OUT_FILE"
chmod 600 "$OUT_FILE"

THRESHOLD="$(jq -r '.unseal_threshold' <<<"$INIT_JSON")"

echo "Unsealing Vault..."
jq -r '.unseal_keys_b64[]' <<<"$INIT_JSON" | head -n "$THRESHOLD" | while IFS= read -r KEY; do
  kubectl_wrapper exec "$POD_NAME" -n "$NAMESPACE" -- \
    vault operator unseal "$KEY" >/dev/null
done

echo "Vault initialised and unsealed."
echo "Init JSON written to $OUT_FILE"

