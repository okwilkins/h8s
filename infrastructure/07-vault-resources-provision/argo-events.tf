resource "random_password" "argo_events_github_webhook_secret" {
  length  = 64
  special = false
}

resource "null_resource" "vault_secret_argo_events_github_webhook" {
  triggers = {
    secret_hash = sha256(random_password.argo_events_github_webhook_secret.result)
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      INFRA_ROOT         = var.infra_root
      KUBECONFIG_CONTENT = sensitive(data.terraform_remote_state.talos_configure.outputs.kubeconfig)
      SERVER             = data.terraform_remote_state.talos_configure.outputs.first_node_ip
      VAULT_TOKEN        = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
      WEBHOOK_SECRET     = sensitive(random_password.argo_events_github_webhook_secret.result)
    }
    command = <<-EOT
      set -euo pipefail
      source "$INFRA_ROOT/scripts/common.sh"
      printf '%s\n%s' "$VAULT_TOKEN" "$WEBHOOK_SECRET" | kubectl_wrapper exec -i -n vault vault-0 -- sh -ec '
        IFS= read -r VAULT_TOKEN
        export VAULT_TOKEN
        vault kv put kubernetes-homelab/argo-events/github-webhook secret=- >/dev/null
      '
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}
