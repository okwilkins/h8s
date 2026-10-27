variable "longhorn_backup_access_key_id" {
  description = "B2 application key ID for Longhorn backups."
  type        = string
  sensitive   = true
}

variable "longhorn_backup_secret_access_key" {
  description = "B2 application key for Longhorn backups."
  type        = string
  sensitive   = true
}

variable "longhorn_encryption_key" {
  description = "Longhorn volume encryption passphrase retained in SOPS and Bitwarden."
  type        = string
  sensitive   = true
}

locals {
  longhorn_namespace = yamldecode(
    file("${var.project_root}/namespaces/base/longhorn-system-namespace.yaml")
  ).metadata.name
}

# Create the namespace before Secrets are needed during a fresh bootstrap.
# ArgoCD continues managing the same namespace manifest afterwards.
resource "terraform_data" "longhorn_namespace" {
  triggers_replace = filesha256("${var.project_root}/namespaces/base/longhorn-system-namespace.yaml")

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      INFRA_ROOT         = var.infra_root
      PROJECT_ROOT       = var.project_root
      KUBECONFIG_CONTENT = sensitive(data.terraform_remote_state.talos_configure.outputs.kubeconfig)
      SERVER             = local.first_node_ip
    }
    command = <<-EOT
      source "$INFRA_ROOT/scripts/common.sh"
      kubectl_wrapper apply -f "$PROJECT_ROOT/namespaces/base/longhorn-system-namespace.yaml"
    EOT
  }
}

resource "kubernetes_secret_v1" "longhorn_crypto" {
  metadata {
    name      = "longhorn-crypto"
    namespace = local.longhorn_namespace
    labels = {
      "app.kubernetes.io/name"    = "longhorn-crypto"
      "app.kubernetes.io/part-of" = "longhorn"
    }
  }

  data = {
    CRYPTO_KEY_PROVIDER = "secret"
    CRYPTO_KEY_VALUE    = var.longhorn_encryption_key
  }

  depends_on = [terraform_data.longhorn_namespace]
}

resource "kubernetes_secret_v1" "longhorn_b2" {
  metadata {
    name      = "longhorn-b2"
    namespace = local.longhorn_namespace
    labels = {
      "app.kubernetes.io/name"    = "longhorn-b2"
      "app.kubernetes.io/part-of" = "longhorn"
    }
  }

  data = {
    AWS_ACCESS_KEY_ID     = var.longhorn_backup_access_key_id
    AWS_SECRET_ACCESS_KEY = var.longhorn_backup_secret_access_key
    AWS_ENDPOINTS         = "https://s3.eu-central-003.backblazeb2.com"
  }

  depends_on = [terraform_data.longhorn_namespace]
}
