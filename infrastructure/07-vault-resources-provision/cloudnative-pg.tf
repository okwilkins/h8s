# ============================================================
# CloudNativePG Database Secrets
# ============================================================

resource "null_resource" "vault_secret_cnpg_harbor" {
  triggers = {
    secret_hash = md5("username=harbor password=${random_password.cnpg_harbor_password.result}")
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
        vault kv put kubernetes-homelab/cnpg/cnpg-harbor-prod-app-user-credentials \\
          username=harbor \\
          password='${random_password.cnpg_harbor_password.result}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

resource "null_resource" "vault_secret_cnpg_authelia" {
  triggers = {
    secret_hash = md5("username=authelia password=${random_password.cnpg_authelia_password.result}")
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
        vault kv put kubernetes-homelab/cnpg/cnpg-authelia-prod-app-user-credentials \\
          username=authelia \\
          password='${random_password.cnpg_authelia_password.result}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}
