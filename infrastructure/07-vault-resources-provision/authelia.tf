# ============================================================
# Authelia
# ============================================================

resource "null_resource" "vault_secret_authelia_encryption" {
  triggers = {
    secret_hash = md5("encryption-key=${random_password.authelia_encryption_key.result}")
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
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      HASH=$(authelia crypto hash generate --password '${random_password.authelia_user_password.result}' 2>/dev/null | cut -d ' ' -f2-)

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
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
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
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
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault kv put kubernetes-homelab/authelia/hmac-secret \\
          hmac-secret='${random_password.authelia_hmac_secret.result}' || exit 1
      "
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

resource "tls_private_key" "authelia_oidc_rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "null_resource" "vault_secret_authelia_rsa" {
  triggers = {
    secret_hash = md5(tls_private_key.authelia_oidc_rsa.private_key_pem)
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      cat << 'EOF' > /tmp/authelia_rsa.pem
      ${tls_private_key.authelia_oidc_rsa.private_key_pem}
      EOF

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"

        echo \"$(cat /tmp/authelia_rsa.pem)\" > /tmp/vault_rsa.pem
        vault kv put kubernetes-homelab/authelia/oidc-rsa-key rsa-private-key=@/tmp/vault_rsa.pem || exit 1
        rm /tmp/vault_rsa.pem
      "
      rm /tmp/authelia_rsa.pem
    EOT
  }
}

resource "null_resource" "vault_secret_authelia_grafana_oidc" {
  triggers = {
    secret_hash = md5("client-secret=${random_password.authelia_grafana_oidc_client_secret.result}")
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      printf '%s' '${bcrypt(random_password.authelia_grafana_oidc_client_secret.result)}' \
        | tr -d '[:space:]' \
        | base64 > /tmp/grafana_hash_b64.txt
      printf '%s' '${random_password.authelia_grafana_oidc_client_secret.result}' \
        | base64 > /tmp/grafana_plaintext_b64.txt

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"

        printf '%s' \"$(cat /tmp/grafana_hash_b64.txt)\" | base64 -d > /tmp/vault_grafana_hash.txt
        printf '%s' \"$(cat /tmp/grafana_plaintext_b64.txt)\" | base64 -d > /tmp/vault_grafana_plaintext.txt

        vault kv put kubernetes-homelab/authelia/grafana-oidc \
          client-secret-hash=@/tmp/vault_grafana_hash.txt \
          client-secret-plaintext=@/tmp/vault_grafana_plaintext.txt || exit 1

        rm /tmp/vault_grafana_hash.txt /tmp/vault_grafana_plaintext.txt
      "
      rm /tmp/grafana_hash_b64.txt /tmp/grafana_plaintext_b64.txt
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

resource "null_resource" "vault_secret_authelia_argocd_oidc" {
  triggers = {
    secret_hash = md5("client-secret=${random_password.authelia_argocd_oidc_client_secret.result}")
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      printf '%s' '${bcrypt(random_password.authelia_argocd_oidc_client_secret.result)}' \
        | tr -d '[:space:]' \
        | base64 > /tmp/argocd_hash_b64.txt
      printf '%s' '${random_password.authelia_argocd_oidc_client_secret.result}' \
        | base64 > /tmp/argocd_plaintext_b64.txt

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"

        printf '%s' \"$(cat /tmp/argocd_hash_b64.txt)\" | base64 -d > /tmp/vault_argocd_hash.txt
        printf '%s' \"$(cat /tmp/argocd_plaintext_b64.txt)\" | base64 -d > /tmp/vault_argocd_plaintext.txt

        vault kv put kubernetes-homelab/authelia/argocd-oidc \
          client-secret-hash=@/tmp/vault_argocd_hash.txt \
          client-secret-plaintext=@/tmp/vault_argocd_plaintext.txt || exit 1

        rm /tmp/vault_argocd_hash.txt /tmp/vault_argocd_plaintext.txt
      "
      rm /tmp/argocd_hash_b64.txt /tmp/argocd_plaintext_b64.txt
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}

resource "null_resource" "vault_secret_authelia_searxng_oidc" {
  triggers = {
    secret_hash = md5("client-secret=${random_password.authelia_searxng_oidc_client_secret.result}")
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      printf '%s' '${bcrypt(random_password.authelia_searxng_oidc_client_secret.result)}' \
        | tr -d '[:space:]' \
        | base64 > /tmp/searxng_hash_b64.txt
      printf '%s' '${random_password.authelia_searxng_oidc_client_secret.result}' \
        | base64 > /tmp/searxng_plaintext_b64.txt

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"

        printf '%s' \"$(cat /tmp/searxng_hash_b64.txt)\" | base64 -d > /tmp/vault_searxng_hash.txt
        printf '%s' \"$(cat /tmp/searxng_plaintext_b64.txt)\" | base64 -d > /tmp/vault_searxng_plaintext.txt

        vault kv put kubernetes-homelab/authelia/searxng-oidc \
          client-secret-hash=@/tmp/vault_searxng_hash.txt \
          client-secret-plaintext=@/tmp/vault_searxng_plaintext.txt || exit 1

        rm /tmp/vault_searxng_hash.txt /tmp/vault_searxng_plaintext.txt
      "
      rm /tmp/searxng_hash_b64.txt /tmp/searxng_plaintext_b64.txt
    EOT
  }

  depends_on = [data.terraform_remote_state.vault_init]
}
