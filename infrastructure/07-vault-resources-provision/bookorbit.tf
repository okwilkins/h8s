# ============================================================
# BookOrbit Secrets
# ============================================================

resource "random_password" "bookorbit_jwt_secret" {
  length  = 64
  special = false
}

resource "random_password" "bookorbit_setup_bootstrap_token" {
  length  = 32
  special = false
}

resource "random_password" "cnpg_bookorbit_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "null_resource" "vault_secret_bookorbit" {
  triggers = {
    credentials_hash = sha256(jsonencode({
      jwt-secret            = random_password.bookorbit_jwt_secret.result
      setup-bootstrap-token = random_password.bookorbit_setup_bootstrap_token.result
    }))
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      INFRA_ROOT         = var.infra_root
      KUBECONFIG_CONTENT = sensitive(data.terraform_remote_state.talos_configure.outputs.kubeconfig)
      SERVER             = data.terraform_remote_state.talos_configure.outputs.first_node_ip
      VAULT_TOKEN        = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
      BOOKORBIT_CREDENTIALS = sensitive(jsonencode({
        jwt-secret            = random_password.bookorbit_jwt_secret.result
        setup-bootstrap-token = random_password.bookorbit_setup_bootstrap_token.result
      }))
    }
    command = <<-EOT
      set -euo pipefail
      source "$INFRA_ROOT/scripts/common.sh"
      printf '%s\n%s' "$VAULT_TOKEN" "$BOOKORBIT_CREDENTIALS" | kubectl_wrapper exec -i -n vault vault-0 -- sh -ec '
        IFS= read -r VAULT_TOKEN
        export VAULT_TOKEN
        vault kv put kubernetes-homelab/bookorbit/bookorbit-secret - >/dev/null
      '
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

resource "null_resource" "vault_secret_cnpg_bookorbit" {
  triggers = {
    credentials_hash = sha256(jsonencode({
      username = "bookorbit"
      password = random_password.cnpg_bookorbit_password.result
    }))
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      INFRA_ROOT         = var.infra_root
      KUBECONFIG_CONTENT = sensitive(data.terraform_remote_state.talos_configure.outputs.kubeconfig)
      SERVER             = data.terraform_remote_state.talos_configure.outputs.first_node_ip
      VAULT_TOKEN        = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
      BOOKORBIT_DATABASE_CREDENTIALS = sensitive(jsonencode({
        username = "bookorbit"
        password = random_password.cnpg_bookorbit_password.result
      }))
    }
    command = <<-EOT
      set -euo pipefail
      source "$INFRA_ROOT/scripts/common.sh"
      printf '%s\n%s' "$VAULT_TOKEN" "$BOOKORBIT_DATABASE_CREDENTIALS" | kubectl_wrapper exec -i -n vault vault-0 -- sh -ec '
        IFS= read -r VAULT_TOKEN
        export VAULT_TOKEN
        vault kv put kubernetes-homelab/cnpg/cnpg-bookorbit-prod-app-user-credentials - >/dev/null
      '
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}
