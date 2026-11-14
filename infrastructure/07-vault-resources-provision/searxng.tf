# ============================================================
# SearxNG Secrets
# ============================================================

variable "exa_api_key" {
  description = "Exa API key for SearXNG. Supply TF_VAR_exa_api_key through the private SOPS secrets repo."
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = length(trimspace(var.exa_api_key)) > 0
    error_message = "The Exa API key must not be empty."
  }
}

resource "terraform_data" "vault_secret_searxng_exa" {
  triggers_replace = [sha256(var.exa_api_key)]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN        = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
      KUBECONFIG_CONTENT = sensitive(data.terraform_remote_state.talos_configure.outputs.kubeconfig)
      KUBERNETES_SERVER  = "https://${data.terraform_remote_state.talos_configure.outputs.first_node_ip}:6443"
      EXA_CREDENTIALS = sensitive(jsonencode({
        "api-key" = var.exa_api_key
      }))
    }

    command = <<-EOT
      set -euo pipefail
      {
        printf '%s\n' "$VAULT_TOKEN"
        printf '%s' "$EXA_CREDENTIALS"
      } | kubectl --kubeconfig <(printf '%s' "$KUBECONFIG_CONTENT") \
        --server="$KUBERNETES_SERVER" exec -i -n vault vault-0 -- \
        /bin/sh -ec '
          IFS= read -r VAULT_TOKEN
          export VAULT_TOKEN
          vault kv put kubernetes-homelab/searxng/exa - >/dev/null
        '
    EOT
  }
}

resource "null_resource" "vault_secret_searxng" {
  triggers = {
    secret_hash = md5("SECRET=${random_password.searxng_secret.result}")
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault kv put kubernetes-homelab/searxng/searxng-secret \\
          SECRET='${random_password.searxng_secret.result}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}
