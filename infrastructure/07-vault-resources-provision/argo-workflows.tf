resource "null_resource" "vault_secret_argo_workflows_github_app" {
  triggers = {
    credentials_hash = sha256(var.h8s_workflows_github_app_private_key)
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      INFRA_ROOT         = var.infra_root
      KUBECONFIG_CONTENT = sensitive(data.terraform_remote_state.talos_configure.outputs.kubeconfig)
      SERVER             = data.terraform_remote_state.talos_configure.outputs.first_node_ip
      VAULT_TOKEN        = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
      GITHUB_CREDENTIALS = sensitive(jsonencode({
        private-key = var.h8s_workflows_github_app_private_key
      }))
    }
    command = <<-EOT
      set -euo pipefail
      source "$INFRA_ROOT/scripts/common.sh"
      printf '%s\n%s' "$VAULT_TOKEN" "$GITHUB_CREDENTIALS" | kubectl_wrapper exec -i -n vault vault-0 -- sh -ec '
        IFS= read -r VAULT_TOKEN
        export VAULT_TOKEN
        vault kv put kubernetes-homelab/argo-workflows/github-app - >/dev/null
      '
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

variable "github_commit_status_token" {
  description = "GitHub token with commit-status write permission. Supply TF_VAR_github_commit_status_token through the private SOPS secrets repo."
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = length(trimspace(var.github_commit_status_token)) > 0
    error_message = "The GitHub commit-status token must not be empty."
  }
}

resource "null_resource" "vault_secret_argo_workflows_github_status" {
  triggers = {
    credentials_hash = sha256(var.github_commit_status_token)
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      INFRA_ROOT         = var.infra_root
      KUBECONFIG_CONTENT = sensitive(data.terraform_remote_state.talos_configure.outputs.kubeconfig)
      SERVER             = data.terraform_remote_state.talos_configure.outputs.first_node_ip
      VAULT_TOKEN        = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
      GITHUB_CREDENTIALS = sensitive(jsonencode({
        token = var.github_commit_status_token
      }))
    }
    command = <<-EOT
      set -euo pipefail
      source "$INFRA_ROOT/scripts/common.sh"
      printf '%s\n%s' "$VAULT_TOKEN" "$GITHUB_CREDENTIALS" | kubectl_wrapper exec -i -n vault vault-0 -- sh -ec '
        IFS= read -r VAULT_TOKEN
        export VAULT_TOKEN
        vault kv put kubernetes-homelab/argo-workflows/github-status - >/dev/null
      '
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

resource "random_password" "authelia_argo_workflows_oidc_client_secret" {
  length  = 64
  special = false
}

resource "null_resource" "vault_secret_authelia_argo_workflows_oidc" {
  triggers = {
    credentials_hash = sha256(random_password.authelia_argo_workflows_oidc_client_secret.result)
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      INFRA_ROOT         = var.infra_root
      KUBECONFIG_CONTENT = sensitive(data.terraform_remote_state.talos_configure.outputs.kubeconfig)
      SERVER             = data.terraform_remote_state.talos_configure.outputs.first_node_ip
      VAULT_TOKEN        = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
      OIDC_CREDENTIALS = sensitive(jsonencode({
        client-secret-plaintext = random_password.authelia_argo_workflows_oidc_client_secret.result
        client-secret-hash      = bcrypt(random_password.authelia_argo_workflows_oidc_client_secret.result)
      }))
    }
    command = <<-EOT
      set -euo pipefail
      source "$INFRA_ROOT/scripts/common.sh"
      printf '%s\n%s' "$VAULT_TOKEN" "$OIDC_CREDENTIALS" | kubectl_wrapper exec -i -n vault vault-0 -- sh -ec '
        IFS= read -r VAULT_TOKEN
        export VAULT_TOKEN
        vault kv put kubernetes-homelab/authelia/argo-workflows-oidc - >/dev/null
      '
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}
