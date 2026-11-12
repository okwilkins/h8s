# ============================================================
# Harbor Secrets
# ============================================================

resource "null_resource" "vault_secret_harbor_admin" {
  triggers = {
    secret_hash = md5("HARBOR_ADMIN_USERNAME=admin HARBOR_ADMIN_PASSWORD=${random_password.harbor_admin_password.result}")
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
        vault kv put kubernetes-homelab/harbor/harbor-admin-credentials \\
          HARBOR_ADMIN_USERNAME=admin \\
          HARBOR_ADMIN_PASSWORD='${random_password.harbor_admin_password.result}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

resource "null_resource" "vault_secret_harbor_main_user" {
  triggers = {
    secret_hash = md5("PASSWORD=${random_password.harbor_main_user_password.result}")
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
        vault kv put kubernetes-homelab/harbor/main-user-secret \\
          PASSWORD='${random_password.harbor_main_user_password.result}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

resource "null_resource" "vault_secret_harbor_dagger" {
  triggers = {
    secret_hash = md5("SECRET=${random_password.harbor_dagger_robot_secret.result}")
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
        vault kv put kubernetes-homelab/harbor/dagger-robot-secret \\
          SECRET='${random_password.harbor_dagger_robot_secret.result}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

resource "null_resource" "vault_secret_harbor_image_pull" {
  triggers = {
    secret_hash = md5("ROBOT_PASSWORD=${random_password.harbor_image_pull_robot_password.result}")
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
        vault kv put kubernetes-homelab/harbor/image-pull \\
          ROBOT_PASSWORD='${random_password.harbor_image_pull_robot_password.result}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}
