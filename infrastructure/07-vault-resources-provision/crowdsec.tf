# ============================================================
# CrowdSec Cloudflare Bouncer
# ============================================================

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
    lapi_secret        = random_password.crowdsec_lapi_secret.result
    registration_token = random_password.crowdsec_registration_token.result
    bouncer_key        = random_password.crowdsec_bouncer_key.result
  })
}

resource "null_resource" "vault_secret_crowdsec_cloudflare" {
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

# CrowdSec Console enrolment
variable "crowdsec_enroll_key" {
  description = "CrowdSec Console enrolment key from the private SOPS secrets."
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = length(trimspace(var.crowdsec_enroll_key)) > 0
    error_message = "Set TF_VAR_crowdsec_enroll_key to the CrowdSec Console enrolment key."
  }
}

resource "terraform_data" "vault_secret_crowdsec_console" {
  triggers_replace = [sha256(var.crowdsec_enroll_key)]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN        = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
      KUBECONFIG_CONTENT = sensitive(data.terraform_remote_state.talos_configure.outputs.kubeconfig)
      KUBERNETES_SERVER  = "https://${data.terraform_remote_state.talos_configure.outputs.first_node_ip}:6443"
      ENROLL_KEY         = var.crowdsec_enroll_key
    }
    command = <<-EOT
      set -euo pipefail
      printf '%s\n%s' "$VAULT_TOKEN" "$ENROLL_KEY" | kubectl --kubeconfig <(printf '%s' "$KUBECONFIG_CONTENT") \
        --server="$KUBERNETES_SERVER" exec -i -n vault vault-0 -- sh -ec '
          IFS= read -r VAULT_TOKEN
          export VAULT_TOKEN
          vault kv put kubernetes-homelab/crowdsec/console enroll_key=- >/dev/null
        '
    EOT
  }
}
