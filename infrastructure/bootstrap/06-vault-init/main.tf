# ============================================================
# Vault Bootstrap
# ============================================================
# Initialises and unseals Vault during cluster bootstrap.
# Uses the external vault-bootstrap.sh script for maintainability.
#
# The script handles:
# - Waiting for the Vault pod to be ready
# - Initialising Vault (if not already initialised)
# - Unsealing Vault with the threshold of unseal keys
# - Saving credentials to vault-init.json
#
# IMPORTANT: vault-init.json contains unseal keys and root token.
# Back it up securely alongside terraform.tfstate!

# ============================================================
# Wait for Kubernetes API
# ============================================================
# Uses a script to poll the Kubernetes API until it's ready.
# This handles the "connection refused" error that can occur
# when attempting to connect immediately after cluster bootstrap.

resource "null_resource" "wait_for_kubernetes_api" {
  provisioner "local-exec" {
    command = "bash ${var.infra_root}/scripts/wait-for-k8s-api.sh"

    environment = {
      TF_DIR = "${var.infra_root}/03-talos-configure"
    }
  }
}

# ============================================================
# Vault Initialisation and Unseal
# ============================================================
# Runs the vault-bootstrap.sh script which handles all Vault
# initialisation logic. The script saves credentials locally
# rather than storing them in Kubernetes secrets.

resource "null_resource" "vault_bootstrap" {
  triggers = {
    # Always run on apply - the script handles idempotency
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "bash ${var.infra_root}/scripts/vault-bootstrap.sh"

    environment = {
      TF_DIR   = "${var.infra_root}/03-talos-configure"
      OUT_FILE = "${var.infra_root}/06-vault-init/secrets/vault-init.json"
    }
  }

  depends_on = [null_resource.wait_for_kubernetes_api]
}

# ============================================================
# Enable Vault KV v2 Secrets Engine
# ============================================================
# Enables the KV v2 secrets engine at the kubernetes-homelab path.
# This must be done before any secrets can be stored.

resource "null_resource" "vault_enable_kv" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      # Extract root token from vault-init.json
      VAULT_TOKEN=$(jq -r '.root_token' ${var.infra_root}/06-vault-init/secrets/vault-init.json)
      export VAULT_TOKEN

      # Enable KV v2 secrets engine
      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        vault secrets enable -path=kubernetes-homelab kv-v2 2>/dev/null || echo 'KV secrets engine already enabled'
      "
    EOT
  }

  depends_on = [null_resource.vault_bootstrap]
}
