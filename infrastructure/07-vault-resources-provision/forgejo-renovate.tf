# ============================================================
# Forgejo Renovate
# ============================================================

resource "random_password" "forgejo_renovate" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "tls_private_key" "forgejo_renovate_signing" {
  algorithm = "ED25519"
}

locals {
  forgejo_renovate_credentials = sensitive(jsonencode({
    username             = "renovate"
    password             = random_password.forgejo_renovate.result
    "signing-key"        = tls_private_key.forgejo_renovate_signing.private_key_openssh
    "signing-public-key" = trimspace(tls_private_key.forgejo_renovate_signing.public_key_openssh)
  }))
}

resource "terraform_data" "vault_secret_forgejo_renovate" {
  triggers_replace = [sha256(local.forgejo_renovate_credentials)]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN          = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
      KUBECONFIG_CONTENT   = sensitive(data.terraform_remote_state.talos_configure.outputs.kubeconfig)
      KUBERNETES_SERVER    = "https://${data.terraform_remote_state.talos_configure.outputs.first_node_ip}:6443"
      RENOVATE_CREDENTIALS = local.forgejo_renovate_credentials
      VAULT_SECRET_PATH    = "kubernetes-homelab/renovate/forgejo"
    }

    command = <<-EOT
      set -euo pipefail
      {
        printf '%s\n' "$VAULT_TOKEN"
        printf '%s' "$RENOVATE_CREDENTIALS"
      } | kubectl --kubeconfig <(printf '%s' "$KUBECONFIG_CONTENT") \
        --server="$KUBERNETES_SERVER" exec -i -n vault vault-0 -- \
        /bin/sh -ec '
          IFS= read -r VAULT_TOKEN
          export VAULT_TOKEN
          vault kv put "$1" - >/dev/null
        ' sh "$VAULT_SECRET_PATH"
    EOT
  }
}
