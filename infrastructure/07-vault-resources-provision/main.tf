# ============================================================
# Vault Secrets Provisioning
# ============================================================
# Provisions all secret values in Vault using kubectl exec commands.
# These values are NOT stored in Terraform state.
#
# Generated secrets:
# - Random passwords for Harbor accounts
# - Cosign key pair
# - Database credentials
#
# External secrets (provided via environment variables):
# - Cloudflare tunnel token (TF_VAR_cloudflare_tunnel_token)
# - GitHub App private key (TF_VAR_github_app_private_key)
#
# To obtain these credentials:
# - Cloudflare: See networking/cloudflared/README.md for tunnel token generation
# - Renovate: See ci-cd/renovate/README.md for GitHub App creation and private key download
#
# IMPORTANT: All secrets depend on Vault being initialized and
# the KV secrets engine being enabled (null_resource.vault_enable_kv in 06-vault-init)

# ============================================================
# Random Password Generators
# ============================================================

resource "random_password" "harbor_admin_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "harbor_main_user_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "harbor_dagger_robot_secret" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "harbor_image_pull_robot_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "grafana_admin_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "searxng_secret" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "cnpg_harbor_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "cnpg_authelia_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "cnpg_terraform_backend_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "authelia_encryption_key" {
  length  = 64
  special = false
}

resource "random_password" "authelia_user_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "authelia_session_secret" {
  length  = 64
  special = false
}

resource "random_password" "authelia_hmac_secret" {
  length  = 64
  special = false
}

resource "random_password" "pocket_id_encryption_key" {
  length  = 32
  special = false
}

# ============================================================
# Cosign Key Pair Generation
# ============================================================

resource "tls_private_key" "cosign_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "random_password" "cosign_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

# ============================================================
# Harbor Secrets
# ============================================================

resource "null_resource" "vault_secret_harbor_admin" {
  triggers = {
    secret_hash = md5("HARBOR_ADMIN_USERNAME=admin HARBOR_ADMIN_PASSWORD=${random_password.harbor_admin_password.result}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${data.terraform_remote_state.vault_init.outputs.vault_init_file})
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login -no-store \"\$VAULT_TOKEN\" || exit 1
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
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${data.terraform_remote_state.vault_init.outputs.vault_init_file})
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login -no-store \"\$VAULT_TOKEN\" || exit 1
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
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${data.terraform_remote_state.vault_init.outputs.vault_init_file})
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login -no-store \"\$VAULT_TOKEN\" || exit 1
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
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${data.terraform_remote_state.vault_init.outputs.vault_init_file})
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login -no-store \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/harbor/image-pull \\
          ROBOT_PASSWORD='${random_password.harbor_image_pull_robot_password.result}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

# ============================================================
# Grafana Secrets
# ============================================================

resource "null_resource" "vault_secret_grafana" {
  triggers = {
    secret_hash = md5("GF_SECURITY_ADMIN_USER=admin GF_SECURITY_ADMIN_PASSWORD=${random_password.grafana_admin_password.result}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${data.terraform_remote_state.vault_init.outputs.vault_init_file})
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login -no-store \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/grafana/grafana-admin-credentials \\
          GF_SECURITY_ADMIN_USER=admin \\
          GF_SECURITY_ADMIN_PASSWORD='${random_password.grafana_admin_password.result}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

# ============================================================
# Cosign Secrets
# ============================================================

resource "null_resource" "vault_secret_cosign" {
  triggers = {
    secret_hash = md5("COSIGN_PASSWORD=${random_password.cosign_password.result} ${tls_private_key.cosign_key.private_key_pem} ${tls_private_key.cosign_key.public_key_pem}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${data.terraform_remote_state.vault_init.outputs.vault_init_file})
      export VAULT_TOKEN

      # Write the key files temporarily
      echo '${tls_private_key.cosign_key.private_key_pem}' > /tmp/cosign.key
      echo '${tls_private_key.cosign_key.public_key_pem}' > /tmp/cosign.pub

      # Copy to vault pod
      kubectl_wrapper cp /tmp/cosign.key vault-0:/tmp/cosign.key -n vault
      kubectl_wrapper cp /tmp/cosign.pub vault-0:/tmp/cosign.pub -n vault

      # Store in Vault
      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login -no-store \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/cosign/key-pair \\
          COSIGN_PASSWORD='${random_password.cosign_password.result}' \\
          cosign.key=@/tmp/cosign.key \\
          cosign.pub=@/tmp/cosign.pub || exit 1
      "

      # Cleanup
      rm -f /tmp/cosign.key /tmp/cosign.pub
      kubectl_wrapper exec vault-0 -n vault -- rm -f /tmp/cosign.key /tmp/cosign.pub
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

# ============================================================
# SearxNG Secrets
# ============================================================

resource "null_resource" "vault_secret_searxng" {
  triggers = {
    secret_hash = md5("SECRET=${random_password.searxng_secret.result}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${data.terraform_remote_state.vault_init.outputs.vault_init_file})
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login -no-store \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/searxng/searxng-secret \\
          SECRET='${random_password.searxng_secret.result}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

# ============================================================
# CloudNativePG Database Secrets
# ============================================================

resource "null_resource" "vault_secret_cnpg_harbor" {
  triggers = {
    secret_hash = md5("username=harbor password=${random_password.cnpg_harbor_password.result}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${data.terraform_remote_state.vault_init.outputs.vault_init_file})
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login -no-store \"\$VAULT_TOKEN\" || exit 1
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
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${data.terraform_remote_state.vault_init.outputs.vault_init_file})
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login -no-store \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/cnpg/cnpg-authelia-prod-app-user-credentials \\
          username=authelia \\
          password='${random_password.cnpg_authelia_password.result}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

resource "null_resource" "vault_secret_cnpg_terraform" {
  triggers = {
    secret_hash = md5("username=terraform password=${random_password.cnpg_terraform_backend_password.result}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${data.terraform_remote_state.vault_init.outputs.vault_init_file})
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login -no-store \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/cnpg/cnpg-terraform-backend-prod-app-user-credentials \\
          username=terraform \\
          password='${random_password.cnpg_terraform_backend_password.result}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}


# ============================================================
# Authelia
# ============================================================

resource "null_resource" "vault_secret_authelia_encryption" {
  triggers = {
    secret_hash = md5("encryption-key=${random_password.authelia_encryption_key.result}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${data.terraform_remote_state.vault_init.outputs.vault_init_file})
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login -no-store \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/authelia/encryption-key \\
          encryption-key='${random_password.authelia_encryption_key.result}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

resource "null_resource" "vault_secret_authelia_user_password" {
  triggers = {
    secret_hash = md5("password=${random_password.authelia_user_password.result}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      HASH=$(authelia crypto hash generate --password '${random_password.authelia_user_password.result}' 2>/dev/null | cut -d ' ' -f2-)

      VAULT_TOKEN=$(jq -r '.root_token' ${data.terraform_remote_state.vault_init.outputs.vault_init_file})
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login -no-store \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/authelia/user-okwilkins-password-hash \\
          hash='$HASH' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

resource "null_resource" "vault_secret_authelia_session" {
  triggers = {
    secret_hash = md5("session-secret=${random_password.authelia_session_secret.result}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${data.terraform_remote_state.vault_init.outputs.vault_init_file})
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login -no-store \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/authelia/session-secret \\
          session-secret='${random_password.authelia_session_secret.result}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

resource "null_resource" "vault_secret_authelia_hmac" {
  triggers = {
    secret_hash = md5("session-secret=${random_password.authelia_hmac_secret.result}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${data.terraform_remote_state.vault_init.outputs.vault_init_file})
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login -no-store \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/authelia/hmac-secret \\
          hmac-secret='${random_password.authelia_hmac_secret.result}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

# ============================================================
# Pocket ID Secrets
# ============================================================

resource "null_resource" "vault_secret_pocket_id_encryption" {
  triggers = {
    secret_hash = md5("ENCRYPTION_KEY=${random_password.pocket_id_encryption_key.result}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${data.terraform_remote_state.vault_init.outputs.vault_init_file})
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login -no-store \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/pocket-id/encryption-key \\
          ENCRYPTION_KEY='${random_password.pocket_id_encryption_key.result}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

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
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${data.terraform_remote_state.vault_init.outputs.vault_init_file})
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login -no-store \"\$VAULT_TOKEN\" || exit 1
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
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${data.terraform_remote_state.vault_init.outputs.vault_init_file})
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login -no-store \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/renovate/github-app \\
          private-key='${var.github_app_private_key}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

