# ============================================================
# External Secrets (from Environment Variables)
# ============================================================
# These secrets are populated from environment variables.
# They will overwrite any existing values in Vault.
#
# Usage:
#   export TF_VAR_cloudflare_tunnel_token="your-token"
#   export TF_VAR_github_app_private_key="$(cat /path/to/private-key.pem)"
#   terraform apply

resource "null_resource" "vault_secret_cloudflare" {
  triggers = {
    secret_hash = md5("token=${var.cloudflare_tunnel_token}")
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
        vault kv put kubernetes-homelab/cloudflare/cloudflared-token \\
          token='${var.cloudflare_tunnel_token}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

resource "null_resource" "vault_secret_renovate" {
  triggers = {
    secret_hash = md5("private-key=${var.github_app_private_key}")
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
        vault kv put kubernetes-homelab/renovate/github-app \\
          private-key='${var.github_app_private_key}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}
