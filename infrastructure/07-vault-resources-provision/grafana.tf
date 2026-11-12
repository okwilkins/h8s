# ============================================================
# Grafana Secrets
# ============================================================

resource "null_resource" "vault_secret_grafana" {
  triggers = {
    secret_hash = md5("GF_SECURITY_ADMIN_USER=admin GF_SECURITY_ADMIN_PASSWORD=${random_password.grafana_admin_password.result}")
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
        vault kv put kubernetes-homelab/grafana/grafana-admin-credentials \\
          GF_SECURITY_ADMIN_USER=admin \\
          GF_SECURITY_ADMIN_PASSWORD='${random_password.grafana_admin_password.result}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}
