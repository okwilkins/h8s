# ============================================================
# Telegram Alerting Credentials
# ============================================================

variable "telegram_bot_token" {
  description = "Telegram bot token for cluster alerts."
  type        = string
  sensitive   = true
}

variable "telegram_chat_id" {
  description = "Numeric Telegram chat ID for cluster alerts."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^-?[0-9]+$", var.telegram_chat_id))
    error_message = "The Telegram chat ID must be a number, not the bot username."
  }
}

resource "null_resource" "vault_secret_telegram" {
  triggers = {
    credentials_hash = sha256(jsonencode([var.telegram_bot_token, var.telegram_chat_id]))
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
      TELEGRAM_CREDENTIALS = sensitive(jsonencode({
        BOT_TOKEN = var.telegram_bot_token
        CHAT_ID   = var.telegram_chat_id
      }))
    }
    command = <<-EOT
      set -euo pipefail
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env
      printf '%s\n%s' "$VAULT_TOKEN" "$TELEGRAM_CREDENTIALS" | kubectl_wrapper exec -i -n vault vault-0 -- sh -ec '
        IFS= read -r VAULT_TOKEN
        export VAULT_TOKEN
        vault kv put kubernetes-homelab/monitoring/telegram - >/dev/null
      '
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}
