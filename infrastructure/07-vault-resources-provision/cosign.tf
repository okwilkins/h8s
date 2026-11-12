# ============================================================
# Cosign Secrets
# ============================================================

resource "null_resource" "vault_secret_cosign" {
  triggers = {
    secret_hash = md5("COSIGN_PASSWORD=${random_password.cosign_password.result} ${tls_private_key.cosign_key.private_key_pem} ${tls_private_key.cosign_key.public_key_pem}")
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      # Write the key files temporarily
      echo '${tls_private_key.cosign_key.private_key_pem}' > /tmp/cosign.key
      echo '${tls_private_key.cosign_key.public_key_pem}' > /tmp/cosign.pub

      # Copy to vault pod
      kubectl_wrapper cp /tmp/cosign.key vault-0:/tmp/cosign.key -n vault
      kubectl_wrapper cp /tmp/cosign.pub vault-0:/tmp/cosign.pub -n vault

      # Store in Vault
      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
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
