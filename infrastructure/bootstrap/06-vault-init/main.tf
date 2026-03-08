# ============================================================
# Vault Bootstrap
# ============================================================
# Initialises and unseals Vault during cluster bootstrap.
# Uses the external vault-bootstrap.sh script for maintainability.
#
# The script handles:
# - Waiting for the Vault pod to be ready
# - Initialising Vault (if not already initialised)
# - Unsealing Vault with the threshold of unseal keys
# - Saving credentials to vault-init.json
#
# IMPORTANT: vault-init.json contains unseal keys and root token.
# Back it up securely alongside terraform.tfstate!

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
# Vault Initialisation and Unseal
# ============================================================
# Runs the vault-bootstrap.sh script which handles all Vault
# initialisation logic. The script saves credentials locally
# rather than storing them in Kubernetes secrets.

resource "null_resource" "vault_bootstrap" {
  triggers = {
    # Always run on apply - the script handles idempotency
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "bash ${var.infra_root}/scripts/vault-bootstrap.sh"

    environment = {
      TF_DIR   = "${var.infra_root}/03-talos-configure"
      OUT_FILE = "${var.infra_root}/06-vault-init/secrets/vault-init.json"
    }
  }

  depends_on = [null_resource.wait_for_kubernetes_api]
}

# ============================================================
# Enable Kubernetes Authentication
# ============================================================
# Enables Kubernetes auth method for service account authentication.

resource "null_resource" "vault_k8s_auth" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${var.infra_root}/06-vault-init/secrets/vault-init.json)
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        vault auth list | grep -q kubernetes || vault auth enable kubernetes || exit 1
        vault write auth/kubernetes/config \\
          kubernetes_host=\"https://\$KUBERNETES_PORT_443_TCP_ADDR:443\" \\
          token_reviewer_jwt=\"\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)\" \\
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
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${var.infra_root}/06-vault-init/secrets/vault-init.json)
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
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
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${var.infra_root}/06-vault-init/secrets/vault-init.json)
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
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
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${var.infra_root}/06-vault-init/secrets/vault-init.json)
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        
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
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${var.infra_root}/06-vault-init/secrets/vault-init.json)
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        
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
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${var.infra_root}/06-vault-init/secrets/vault-init.json)
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        
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
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${var.infra_root}/06-vault-init/secrets/vault-init.json)
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        
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
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${var.infra_root}/06-vault-init/secrets/vault-init.json)
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        
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
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${var.infra_root}/06-vault-init/secrets/vault-init.json)
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        
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
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      source ${var.infra_root}/scripts/common.sh
      load_tf_kube_env
      create_cert_dir

      VAULT_TOKEN=$(jq -r '.root_token' ${var.infra_root}/06-vault-init/secrets/vault-init.json)
      export VAULT_TOKEN

      kubectl_wrapper exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        
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
