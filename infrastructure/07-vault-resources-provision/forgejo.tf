# ============================================================
# Forgejo Secrets
# ============================================================

resource "random_password" "forgejo" {
  for_each = toset(["admin", "database", "internal-token", "metrics-token", "oidc-client", "secret-key"])

  length  = 64
  special = false
}

resource "random_bytes" "forgejo_jwt" {
  for_each = toset(["lfs", "oauth2"])

  length = 32
}

locals {
  forgejo_jwt_secrets = {
    for name, secret in random_bytes.forgejo_jwt :
    name => replace(replace(trimsuffix(secret.base64, "="), "+", "-"), "/", "_")
  }

  forgejo_vault_secrets = {
    "forgejo/admin" = {
      username = "forgejo-admin"
      password = random_password.forgejo["admin"].result
    }
    "forgejo/app" = {
      secret_key        = random_password.forgejo["secret-key"].result
      internal_token    = random_password.forgejo["internal-token"].result
      metrics_token     = random_password.forgejo["metrics-token"].result
      lfs_jwt_secret    = local.forgejo_jwt_secrets["lfs"]
      oauth2_jwt_secret = local.forgejo_jwt_secrets["oauth2"]
    }
    "authelia/forgejo-oidc" = {
      client-secret-plaintext = random_password.forgejo["oidc-client"].result
      client-secret-hash      = bcrypt(random_password.forgejo["oidc-client"].result)
    }
    "cnpg/cnpg-forgejo-prod-app-user-credentials" = {
      username = "forgejo"
      password = random_password.forgejo["database"].result
    }
  }
}

resource "null_resource" "vault_secret_forgejo" {
  for_each = toset([
    "forgejo/admin",
    "forgejo/app",
    "authelia/forgejo-oidc",
    "cnpg/cnpg-forgejo-prod-app-user-credentials",
  ])

  triggers = {
    credentials_hash = sha256(jsonencode({
      passwords = { for name, password in random_password.forgejo : name => password.result }
      jwt       = local.forgejo_jwt_secrets
    }))
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      INFRA_ROOT          = var.infra_root
      KUBECONFIG_CONTENT  = sensitive(data.terraform_remote_state.talos_configure.outputs.kubeconfig)
      SERVER              = data.terraform_remote_state.talos_configure.outputs.first_node_ip
      VAULT_TOKEN         = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
      FORGEJO_CREDENTIALS = sensitive(jsonencode(local.forgejo_vault_secrets[each.key]))
    }
    command = <<-EOT
      set -euo pipefail
      source "$INFRA_ROOT/scripts/common.sh"
      printf '%s\n%s' "$VAULT_TOKEN" "$FORGEJO_CREDENTIALS" | kubectl_wrapper exec -i -n vault vault-0 -- sh -ec '
        IFS= read -r VAULT_TOKEN
        export VAULT_TOKEN
        vault kv put kubernetes-homelab/${each.key} - >/dev/null
      '
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}
