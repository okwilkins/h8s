# ============================================================
# Vault Configuration
# ============================================================
# Configures Vault after it has been initialized and unsealed.
# This runs after ArgoCD has installed Vault via the app-of-apps.
#
# Vault initialization is handled by vault-init.tf which:
# - Initializes Vault and saves credentials to vault-init.json
# - Unseals Vault using unseal keys
# - Enables Kubernetes authentication
#
# IMPORTANT: vault-init.json contains unseal keys and root token.
# Back it up securely alongside terraform.tfstate!

# ============================================================
# Enable Secret Engines
# ============================================================

resource "null_resource" "vault_enable_kv" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Enabling KV v2 secrets engine..."
      
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      
      kubectl exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        vault secrets list | grep -q kubernetes-homelab || vault secrets enable -path=kubernetes-homelab kv-v2 || exit 1
        echo 'KV v2 secrets engine enabled'
      "
      
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to enable KV v2 secrets engine"
        exit 1
      fi
    EOT
  }

  depends_on = [null_resource.vault_k8s_auth]
}

resource "null_resource" "vault_enable_pki" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Enabling PKI secrets engine..."
      
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      
      kubectl exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        vault secrets list | grep -q pki || vault secrets enable pki || exit 1
        vault secrets tune -max-lease-ttl=8760h pki || exit 1
        echo 'PKI secrets engine enabled'
      "
      
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to enable PKI secrets engine"
        exit 1
      fi
    EOT
  }

  depends_on = [null_resource.vault_k8s_auth]
}

# ============================================================
# Create Policies
# ============================================================

resource "null_resource" "vault_policy_external_secrets" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating external-secrets-reader policy..."
      
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      
      kubectl exec vault-0 -n vault -- /bin/sh -c "
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
  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating pki policy..."
      
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      
      kubectl exec vault-0 -n vault -- /bin/sh -c "
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
  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating external-secrets-vault-auth role..."
      
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      
      kubectl exec vault-0 -n vault -- /bin/sh -c "
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
  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating vault-issuer role..."
      
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      
      kubectl exec vault-0 -n vault -- /bin/sh -c "
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
  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating PKI root CA..."
      
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      
      kubectl exec vault-0 -n vault -- /bin/sh -c "
        export VAULT_TOKEN=\"$VAULT_TOKEN\"
        vault login \"\$VAULT_TOKEN\" || exit 1
        
        # Check if root CA already exists
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
    command = <<-EOT
      echo "Configuring PKI URLs..."
      
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      
      kubectl exec vault-0 -n vault -- /bin/sh -c "
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
  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating PKI role..."
      
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      
      kubectl exec vault-0 -n vault -- /bin/sh -c "
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
