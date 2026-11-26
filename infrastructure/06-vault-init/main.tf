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

provider "kubernetes" {
  host                   = "https://${data.terraform_remote_state.talos_configure.outputs.first_node_ip}:6443"
  cluster_ca_certificate = data.terraform_remote_state.talos_configure.outputs.ca_cert
  client_certificate     = data.terraform_remote_state.talos_configure.outputs.client_cert
  client_key             = data.terraform_remote_state.talos_configure.outputs.client_key
}

data "kubernetes_service_v1" "api" {
  metadata {
    name      = "kubernetes"
    namespace = "default"
  }
}

resource "vault_auth_backend" "kubernetes" {
  type       = "kubernetes"
  depends_on = [null_resource.vault_bootstrap]
  lifecycle { prevent_destroy = true }
}

resource "vault_kubernetes_auth_backend_config" "cluster" {
  backend            = vault_auth_backend.kubernetes.path
  kubernetes_host    = "https://${data.kubernetes_service_v1.api.spec[0].cluster_ip}:443"
  kubernetes_ca_cert = data.terraform_remote_state.talos_configure.outputs.ca_cert
}

resource "vault_mount" "kv" {
  path       = "kubernetes-homelab"
  type       = "kv"
  options    = { version = "2" }
  depends_on = [null_resource.vault_bootstrap]
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "pki" {
  path                  = "pki"
  type                  = "pki"
  max_lease_ttl_seconds = 8760 * 3600
  depends_on            = [null_resource.vault_bootstrap]
  lifecycle { prevent_destroy = true }
}

# ============================================================
# Create Policies
# ============================================================

resource "vault_policy" "external_secrets_reader" {
  name       = "external-secrets-reader"
  policy     = <<-POLICY
    path "kubernetes-homelab/data/*" {
      capabilities = ["create", "read", "update", "delete", "patch"]
    }
    path "kubernetes-homelab/metadata/*" {
      capabilities = ["list", "delete"]
    }
  POLICY
  depends_on = [vault_mount.kv]
}

provider "vault" {
  address = "http://127.0.0.1:18200"
  token   = terraform_data.vault_credentials.output.root_token
}

resource "vault_policy" "pki" {
  name       = "pki"
  policy     = <<-POLICY
    path "pki*"                   { capabilities = ["read", "list"] }
    path "pki/sign/okwilkins-dot-dev"    { capabilities = ["create", "update"] }
    path "pki/issue/okwilkins-dot-dev"   { capabilities = ["create"] }
  POLICY
  depends_on = [vault_mount.pki]
}

# ============================================================
# Create Kubernetes Auth Roles
# ============================================================

resource "vault_kubernetes_auth_backend_role" "external_secrets" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "external-secrets-vault-auth"
  bound_service_account_names      = ["external-secrets-vault-auth"]
  bound_service_account_namespaces = ["external-secrets"]
  token_policies                   = [vault_policy.external_secrets_reader.name]
  token_ttl                        = 24 * 60 * 60
}

resource "vault_kubernetes_auth_backend_role" "vault_issuer" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "vault-issuer"
  bound_service_account_names      = ["vault-issuer"]
  bound_service_account_namespaces = ["cert-manager"]
  token_policies                   = [vault_policy.pki.name]
  token_ttl                        = 20 * 60
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

  depends_on = [vault_mount.pki]
}

resource "vault_pki_secret_backend_config_urls" "pki" {
  backend                 = vault_mount.pki.path
  issuing_certificates    = ["http://127.0.0.1:8200/v1/pki/ca"]
  crl_distribution_points = ["http://127.0.0.1:8200/v1/pki/crl"]
  depends_on              = [null_resource.vault_pki_root_ca]
}

resource "vault_pki_secret_backend_role" "domain" {
  backend            = vault_mount.pki.path
  name               = "okwilkins-dot-dev"
  allowed_domains    = ["okwilkins.dev"]
  allow_bare_domains = true
  allow_subdomains   = true
  max_ttl            = 72 * 3600
  depends_on         = [vault_pki_secret_backend_config_urls.pki]
}

resource "vault_policy" "snapshot" {
  name       = "vault-snapshot"
  policy     = <<-POLICY
    path "sys/storage/raft/snapshot" {
      capabilities = ["read"]
    }
    path "auth/token/revoke-self" {
      capabilities = ["update"]
    }
  POLICY
  depends_on = [null_resource.vault_bootstrap]
}

resource "vault_kubernetes_auth_backend_role" "snapshot" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "vault-snapshot"
  bound_service_account_names      = ["vault-snapshot"]
  bound_service_account_namespaces = ["vault"]
  audience                         = "vault"
  token_policies                   = [vault_policy.snapshot.name]
  token_no_default_policy          = true
  token_ttl                        = 600
  token_max_ttl                    = 600
}
