# ============================================================
# Vault Secrets
# ============================================================
# Manages secret values in Vault using kubectl exec commands.
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
# Kubernetes auth being enabled (null_resource.vault_k8s_auth)

# ============================================================
# Variables
# ============================================================

variable "cloudflare_tunnel_token" {
  description = "Cloudflare tunnel token for cloudflared. See networking/cloudflared/README.md for how to generate this token using the Cloudflare API."
  type        = string
}

variable "github_app_private_key" {
  description = "GitHub App private key for Renovate. See ci-cd/renovate/README.md for how to create the GitHub App and download the private key."
  type        = string
}

# ============================================================
# Random Password Generators
# ============================================================

resource "random_password" "harbor_admin_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
}

resource "random_password" "harbor_main_user_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
}

resource "random_password" "harbor_dagger_robot_secret" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
}

resource "random_password" "harbor_image_pull_robot_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
}

resource "random_password" "grafana_admin_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
}

resource "random_password" "searxng_secret" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
}

resource "random_password" "cnpg_harbor_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
}

resource "random_password" "cnpg_terraform_backend_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
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
  override_special = "!#$%&*()-_=+[]{}<>?"
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
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      kubectl exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/harbor/harbor-admin-credentials \\
          HARBOR_ADMIN_USERNAME=admin \\
          HARBOR_ADMIN_PASSWORD='${random_password.harbor_admin_password.result}' || exit 1
      "
    EOT
  }

  depends_on = [null_resource.vault_enable_kv]
}

resource "null_resource" "vault_secret_harbor_main_user" {
  triggers = {
    secret_hash = md5("PASSWORD=${random_password.harbor_main_user_password.result}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      kubectl exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/harbor/main-user-secret \\
          PASSWORD='${random_password.harbor_main_user_password.result}' || exit 1
      "
    EOT
  }

  depends_on = [null_resource.vault_enable_kv]
}

resource "null_resource" "vault_secret_harbor_dagger" {
  triggers = {
    secret_hash = md5("SECRET=${random_password.harbor_dagger_robot_secret.result}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      kubectl exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/harbor/dagger-robot-secret \\
          SECRET='${random_password.harbor_dagger_robot_secret.result}' || exit 1
      "
    EOT
  }

  depends_on = [null_resource.vault_enable_kv]
}

resource "null_resource" "vault_secret_harbor_image_pull" {
  triggers = {
    secret_hash = md5("ROBOT_PASSWORD=${random_password.harbor_image_pull_robot_password.result}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      kubectl exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/harbor/image-pull \\
          ROBOT_PASSWORD='${random_password.harbor_image_pull_robot_password.result}' || exit 1
      "
    EOT
  }

  depends_on = [null_resource.vault_enable_kv]
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
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      kubectl exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/grafana/grafana-admin-credentials \\
          GF_SECURITY_ADMIN_USER=admin \\
          GF_SECURITY_ADMIN_PASSWORD='${random_password.grafana_admin_password.result}' || exit 1
      "
    EOT
  }

  depends_on = [null_resource.vault_enable_kv]
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
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      
      # Write the key files temporarily
      echo '${tls_private_key.cosign_key.private_key_pem}' > /tmp/cosign.key
      echo '${tls_private_key.cosign_key.public_key_pem}' > /tmp/cosign.pub
      
      # Copy to vault pod
      kubectl cp /tmp/cosign.key vault-0:/tmp/cosign.key -n vault
      kubectl cp /tmp/cosign.pub vault-0:/tmp/cosign.pub -n vault
      
      # Store in Vault
      kubectl exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/cosign/key-pair \\
          COSIGN_PASSWORD='${random_password.cosign_password.result}' \\
          cosign.key=@/tmp/cosign.key \\
          cosign.pub=@/tmp/cosign.pub || exit 1
      "
      
      # Cleanup
      rm -f /tmp/cosign.key /tmp/cosign.pub
      kubectl exec vault-0 -n vault -- rm -f /tmp/cosign.key /tmp/cosign.pub
    EOT
  }

  depends_on = [null_resource.vault_enable_kv]
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
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      kubectl exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/searxng/searxng-secret \\
          SECRET='${random_password.searxng_secret.result}' || exit 1
      "
    EOT
  }

  depends_on = [null_resource.vault_enable_kv]
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
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      kubectl exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/cnpg/cnpg-harbor-prod-app-user-credentials \\
          username=harbor \\
          password='${random_password.cnpg_harbor_password.result}' || exit 1
      "
    EOT
  }

  depends_on = [null_resource.vault_enable_kv]
}

resource "null_resource" "vault_secret_cnpg_terraform" {
  triggers = {
    secret_hash = md5("username=terraform password=${random_password.cnpg_terraform_backend_password.result}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      kubectl exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/cnpg/cnpg-terraform-backend-prod-app-user-credentials \\
          username=terraform \\
          password='${random_password.cnpg_terraform_backend_password.result}' || exit 1
      "
    EOT
  }

  depends_on = [null_resource.vault_enable_kv]
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
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      kubectl exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/cloudflare/cloudflared-token \\
          token='${var.cloudflare_tunnel_token}' || exit 1
      "
    EOT
  }

  depends_on = [null_resource.vault_enable_kv]
}

resource "null_resource" "vault_secret_renovate" {
  triggers = {
    secret_hash = md5("private-key=${var.github_app_private_key}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      kubectl exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        vault kv put kubernetes-homelab/renovate/github-app \\
          private-key='${var.github_app_private_key}' || exit 1
      "
    EOT
  }

  depends_on = [null_resource.vault_enable_kv]
}
