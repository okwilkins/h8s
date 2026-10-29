# ============================================================
# Vault Credentials
# ============================================================
# Retains the original Vault initialisation JSON in encrypted OpenTofu state.
# Later runs use the stored credentials without requiring this input again.

variable "vault_credentials" {
  description = "Vault initialisation JSON for first-time setup. Leave unset to use the credentials already retained in encrypted state."
  type        = any
  default     = null
  sensitive   = true
}

resource "terraform_data" "vault_credentials" {
  input = var.vault_credentials

  lifecycle {
    ignore_changes  = [input]
    prevent_destroy = true

    postcondition {
      condition = try(
        length(trimspace(self.input.root_token)) > 0 &&
        alltrue([for key in tolist(self.input.unseal_keys_b64) : length(trimspace(key)) > 0]) &&
        self.input.unseal_threshold >= 1 &&
        self.input.unseal_threshold == floor(self.input.unseal_threshold) &&
        self.input.unseal_threshold <= length(self.input.unseal_keys_b64),
        false
      )
      error_message = "Vault credentials must contain a root token, unseal keys and a valid unseal threshold."
    }
  }
}

moved {
  from = terraform_data.vault_recovery
  to   = terraform_data.vault_credentials
}

# ============================================================
# Wait for Kubernetes API
# ============================================================
# Uses a script to poll the Kubernetes API until it's ready.
# This handles the "connection refused" error that can occur
# when attempting to connect immediately after cluster bootstrap.

resource "null_resource" "wait_for_kubernetes_api" {
  provisioner "local-exec" {
    command = "bash ${var.infra_root}/scripts/wait-for-k8s-api.sh"

    environment = {
      TF_DIR = "${var.infra_root}/03-talos-configure"
    }
  }
}

# ============================================================
# Vault Readiness
# ============================================================
# Refuses to provision an uninitialised or sealed Vault.
# Initialisation and unsealing are deliberate manual actions.

resource "null_resource" "vault_bootstrap" {
  provisioner "local-exec" {
    command = "bash ${var.infra_root}/scripts/vault-bootstrap.sh"

    environment = {
      TF_DIR = "${var.infra_root}/03-talos-configure"
    }
  }

  depends_on = [null_resource.wait_for_kubernetes_api, terraform_data.vault_credentials]
}

# ============================================================
# Enable Kubernetes Authentication
# ============================================================
# Enables Kubernetes auth method for service account authentication.

resource "null_resource" "vault_k8s_auth" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(terraform_data.vault_credentials.output.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault auth list | grep -q kubernetes || vault auth enable kubernetes || exit 1
        vault write auth/kubernetes/config \\
          kubernetes_host=\"https://\$KUBERNETES_PORT_443_TCP_ADDR:443\" \\
          kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt || exit 1
        echo 'Kubernetes auth enabled'
      "
    EOT
  }

  depends_on = [null_resource.vault_bootstrap]
}

# ============================================================
# Enable Vault KV v2 Secrets Engine
# ============================================================
# Enables the KV v2 secrets engine at the kubernetes-homelab path.

resource "null_resource" "vault_enable_kv" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(terraform_data.vault_credentials.output.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault secrets list | grep -q kubernetes-homelab || vault secrets enable -path=kubernetes-homelab kv-v2 || exit 1
        echo 'KV v2 secrets engine enabled'
      "
    EOT
  }

  depends_on = [null_resource.vault_k8s_auth]
}

# ============================================================
# Enable PKI Secrets Engine
# ============================================================
# Enables the PKI secrets engine for certificate management.

resource "null_resource" "vault_enable_pki" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(terraform_data.vault_credentials.output.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault secrets list | grep -q pki || vault secrets enable pki || exit 1
        vault secrets tune -max-lease-ttl=8760h pki || exit 1
        echo 'PKI secrets engine enabled'
      "
    EOT
  }

  depends_on = [null_resource.vault_k8s_auth]
}

# ============================================================
# Create Policies
# ============================================================

resource "null_resource" "vault_policy_external_secrets" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(terraform_data.vault_credentials.output.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        
        vault policy write external-secrets-reader - <<'POLICY'
path \"kubernetes-homelab/data/*\" {
  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"patch\"]
}
path \"kubernetes-homelab/metadata/*\" {
  capabilities = [\"list\", \"delete\"]
}
POLICY
      "
      
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to create external-secrets-reader policy"
        exit 1
      fi
    EOT
  }

  depends_on = [null_resource.vault_enable_kv]
}

resource "null_resource" "vault_policy_pki" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(terraform_data.vault_credentials.output.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        
        vault policy write pki - <<'POLICY'
path \"pki*\"                   { capabilities = [\"read\", \"list\"] }
path \"pki/sign/okwilkins-dot-dev\"    { capabilities = [\"create\", \"update\"] }
path \"pki/issue/okwilkins-dot-dev\"   { capabilities = [\"create\"] }
POLICY
      "
      
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to create pki policy"
        exit 1
      fi
    EOT
  }

  depends_on = [null_resource.vault_enable_pki]
}

# ============================================================
# Create Kubernetes Auth Roles
# ============================================================

resource "null_resource" "vault_role_external_secrets" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(terraform_data.vault_credentials.output.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        
        vault write auth/kubernetes/role/external-secrets-vault-auth \\
          bound_service_account_names=external-secrets-vault-auth \\
          bound_service_account_namespaces=external-secrets \\
          policies=external-secrets-reader \\
          ttl=24h || exit 1
        
        echo 'external-secrets-vault-auth role created'
      "
      
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to create external-secrets-vault-auth role"
        exit 1
      fi
    EOT
  }

  depends_on = [null_resource.vault_policy_external_secrets]
}

resource "null_resource" "vault_role_vault_issuer" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(terraform_data.vault_credentials.output.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        
        vault write auth/kubernetes/role/vault-issuer \\
          bound_service_account_names=vault-issuer \\
          bound_service_account_namespaces=cert-manager \\
          policies=pki \\
          ttl=20m || exit 1
        
        echo 'vault-issuer role created'
      "
      
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to create vault-issuer role"
        exit 1
      fi
    EOT
  }

  depends_on = [null_resource.vault_policy_pki]
}

# ============================================================
# PKI Configuration
# ============================================================

resource "null_resource" "vault_pki_root_ca" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(terraform_data.vault_credentials.output.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        
        vault read pki/ca/pem > /dev/null 2>&1 && echo 'Root CA already exists' && exit 0
        
        vault write pki/root/generate/internal \\
          common_name=okwilkins.dev \\
          ttl=8760h || exit 1
        
        echo 'PKI root CA created'
      "
      
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to create PKI root CA"
        exit 1
      fi
    EOT
  }

  depends_on = [null_resource.vault_enable_pki]
}

resource "null_resource" "vault_pki_config_urls" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(terraform_data.vault_credentials.output.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        
        vault write pki/config/urls \\
          issuing_certificates=\"http://127.0.0.1:8200/v1/pki/ca\" \\
          crl_distribution_points=\"http://127.0.0.1:8200/v1/pki/crl\" || exit 1
        
        echo 'PKI URLs configured'
      "
      
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to configure PKI URLs"
        exit 1
      fi
    EOT
  }

  depends_on = [null_resource.vault_pki_root_ca]
}

resource "null_resource" "vault_pki_role" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(terraform_data.vault_credentials.output.root_token)
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        
        vault write pki/roles/okwilkins-dot-dev \\
          allowed_domains=okwilkins.dev \\
          allow_bare_domains=true \\
          allow_subdomains=true \\
          max_ttl=72h || exit 1
        
        echo 'PKI role created'
      "
      
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to create PKI role"
        exit 1
      fi
    EOT
  }

  depends_on = [null_resource.vault_pki_config_urls]
}

# ============================================================
# Vault Snapshot Authentication
# ============================================================

resource "null_resource" "vault_snapshot_auth" {
  triggers = {
    config_version = "1"
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      VAULT_TOKEN = sensitive(terraform_data.vault_credentials.output.root_token)
    }
    command = <<-EOT
      set -euo pipefail
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env
      printf '%s\n' "$VAULT_TOKEN" | kubectl_wrapper exec -i -n vault vault-0 -- sh -ec '
        IFS= read -r VAULT_TOKEN
        export VAULT_TOKEN
        vault policy write vault-snapshot - <<POLICY
      path "sys/storage/raft/snapshot" {
        capabilities = ["read"]
      }
      path "auth/token/revoke-self" {
        capabilities = ["update"]
      }
      POLICY
        vault write auth/kubernetes/role/vault-snapshot \
          bound_service_account_names=vault-snapshot \
          bound_service_account_namespaces=vault \
          audience=vault \
          token_policies=vault-snapshot \
          token_no_default_policy=true \
          token_ttl=10m token_max_ttl=10m
      '
    EOT
  }

  depends_on = [null_resource.vault_k8s_auth]
}
