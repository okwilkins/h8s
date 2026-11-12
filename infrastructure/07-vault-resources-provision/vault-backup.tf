# ============================================================
# Vault Backup Credentials
# ============================================================

variable "vault_backup_access_key_id" {
  description = "B2 application key ID for the Vault snapshot bucket."
  type        = string
  sensitive   = true
}

variable "vault_backup_secret_access_key" {
  description = "B2 application key for the Vault snapshot bucket."
  type        = string
  sensitive   = true
}

resource "null_resource" "vault_secret_backup_b2" {
  triggers = {
    credentials_hash = sha256(jsonencode([var.vault_backup_access_key_id, var.vault_backup_secret_access_key]))
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
      BACKUP_CREDENTIALS = sensitive(jsonencode({
        AWS_ACCESS_KEY_ID     = var.vault_backup_access_key_id
        AWS_SECRET_ACCESS_KEY = var.vault_backup_secret_access_key
      }))
    }
    command = <<-EOT
      set -euo pipefail
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env
      printf '%s\n%s' "$VAULT_TOKEN" "$BACKUP_CREDENTIALS" | kubectl_wrapper exec -i -n vault vault-0 -- sh -ec '
        IFS= read -r VAULT_TOKEN
        export VAULT_TOKEN
        vault kv put kubernetes-homelab/vault/backup-b2 - >/dev/null
      '
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}
