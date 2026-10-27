#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

load_tf_kube_env

echo "Waiting for Vault pod to be created..."
kubectl_wrapper wait \
  --for=create \
  "pod/${POD_NAME}" \
  -n "$NAMESPACE" \
  --timeout=1800s >/dev/null

echo "Waiting for Vault pod to start running..."
kubectl_wrapper wait \
  --for=jsonpath='{.status.phase}'=Running \
  "pod/${POD_NAME}" \
  -n "$NAMESPACE" \
  --timeout=1800s >/dev/null

echo "Checking Vault status..."
STATUS_JSON="$(
  kubectl_wrapper exec "$POD_NAME" -n "$NAMESPACE" -- \
    vault status -format=json 2>/dev/null || true
)"

if ! jq -e 'type == "object" and (.initialized | type == "boolean") and (.sealed | type == "boolean")' >/dev/null 2>&1 <<<"$STATUS_JSON"; then
  echo "ERROR: Could not read a valid Vault status." >&2
  exit 1
fi

if ! jq -e '.initialized == true' >/dev/null <<<"$STATUS_JSON"; then
  echo "ERROR: Initialise Vault manually and preserve its original credentials before applying this stage." >&2
  exit 1
fi

if ! jq -e '.sealed == false' >/dev/null <<<"$STATUS_JSON"; then
  echo "ERROR: Unseal Vault manually with its existing unseal keys before applying this stage." >&2
  exit 1
fi

echo "Vault is initialised and unsealed."

