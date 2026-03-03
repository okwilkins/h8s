# ============================================================
# ArgoCD Bootstrap
# ============================================================
# Installs ArgoCD immediately after Cilium CNI bootstrap.
# This allows GitOps management of all cluster workloads.
#
# Based on: ci-cd/argocd/environments/prod/values.yaml
#
# After this runs, the cluster will have:
# - ArgoCD installed and running
# - App of Apps deployed (manages all other Applications)
# - Default AppProject configured
# - Full GitOps capability available

locals {
  # Load ArgoCD values from the existing local file
  argocd_values = file("${path.module}/../../ci-cd/argocd/environments/prod/values.yaml")
}

# ============================================================
# ArgoCD Version from ArgoCD App
# ============================================================
# Extract the ArgoCD Helm chart version from the ArgoCD Application
# manifest to ensure consistency between bootstrap and GitOps.

data "external" "argocd_version" {
  program = ["bash", "-c", <<-EOT
    version=$(yq '.spec.sources[0].targetRevision' ${path.module}/../../ci-cd/argocd/environments/prod/apps/argocd-helm.yaml)
    echo "{\"version\": \"$version\"}"
  EOT
  ]
}

# ============================================================
# ArgoCD Helm Release
# ============================================================
# Installs ArgoCD from the official Helm chart using the same
# values as ci-cd/argocd/environments/prod/values.yaml

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = data.external.argocd_version.result.version
  namespace  = "argocd"

  values = [local.argocd_values]

  # Wait for the release to be fully deployed
  wait             = true
  wait_for_jobs    = true
  timeout          = 600
  create_namespace = true

  depends_on = [helm_release.cilium]
}

# ============================================================
# ArgoCD App of Apps and Default AppProject
# ============================================================
# Apply ArgoCD core manifests using kubectl with explicit node IP connection.
# This deploys the app-of-apps which then manages all other Applications.

resource "null_resource" "argocd_manifests" {
  provisioner "local-exec" {
    command = <<-EOT
      CERT_FILE=$(mktemp)
      KEY_FILE=$(mktemp)
      
      cat <<'CERT_EOF' > "$CERT_FILE"
${base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)}
CERT_EOF
      
      cat <<'KEY_EOF' > "$KEY_FILE"
${base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)}
KEY_EOF
      
      kubectl kustomize ${path.module}/../../ci-cd/argocd/environments/prod | \
      kubectl --server=https://${local.first_node_ip}:6443 \
              --client-certificate="$CERT_FILE" \
              --client-key="$KEY_FILE" \
              --insecure-skip-tls-verify=true \
              apply -f -
      
      rm -f "$CERT_FILE" "$KEY_FILE"
    EOT
  }

  depends_on = [helm_release.argocd]
}
