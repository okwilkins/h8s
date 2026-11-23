# ============================================================
# CrowdSec Cloudflare Bouncer
# ============================================================

variable "crowdsec_cloudflare_token" {
  description = "Dedicated Cloudflare user API token for the CrowdSec Worker bouncer."
  type        = string
  sensitive   = true
  default     = null
}

resource "random_password" "crowdsec_lapi_secret" {
  length  = 64
  special = false
}

resource "random_password" "crowdsec_registration_token" {
  length  = 64
  special = false
}

resource "random_password" "crowdsec_bouncer_key" {
  length  = 32
  special = false
}

locals {
  crowdsec_cloudflare_credentials = jsonencode({
    account_id         = local.cloudflare_account_id
    zone_id            = local.cloudflare_zone_id
    token              = var.crowdsec_cloudflare_token
    lapi_secret        = random_password.crowdsec_lapi_secret.result
    registration_token = random_password.crowdsec_registration_token.result
    bouncer_key        = random_password.crowdsec_bouncer_key.result
  })
}

resource "null_resource" "vault_secret_crowdsec_cloudflare" {
  count = nonsensitive(var.crowdsec_cloudflare_token != null) ? 1 : 0

  triggers = {
    credentials_hash = sha256(local.crowdsec_cloudflare_credentials)
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
      CREDENTIALS = sensitive(local.crowdsec_cloudflare_credentials)
    }
    command = <<-EOT
      set -euo pipefail
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env
      printf '%s\n%s' "$VAULT_TOKEN" "$CREDENTIALS" | kubectl_wrapper exec -i -n vault vault-0 -- sh -ec '
        IFS= read -r VAULT_TOKEN
        export VAULT_TOKEN
        vault kv put kubernetes-homelab/crowdsec/cloudflare - >/dev/null
      '
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}
