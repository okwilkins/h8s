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
  argocd_values = file("${var.project_root}/ci-cd/argocd/environments/prod/values.yaml")
  # Extract the ArgoCD Helm chart version from the ArgoCD Application
  # manifest to ensure consistency between bootstrap and GitOps.
  argocd_app = yamldecode(
    file("${var.project_root}/ci-cd/argocd/environments/prod/apps/argocd-helm.yaml")
  )
  argocd_chart_version = try(
    local.argocd_app.spec.sources[0].targetRevision,
    null
  )
  # Load the app-of-apps manifest
  app_of_apps_manifest = yamldecode(
    file("${var.project_root}/ci-cd/argocd/environments/prod/app-of-apps.yaml")
  )
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
  version    = local.argocd_chart_version
  namespace  = "argocd"

  values = [local.argocd_values]

  wait             = true
  wait_for_jobs    = true
  timeout          = 600
  create_namespace = true

  depends_on = [data.kubernetes_namespace_v1.probe]
}

# ============================================================
# App of Apps Deployment
# ============================================================
# Deploys the root Application that manages all other ArgoCD
# Applications via the app-of-apps pattern using kubectl.
# Uses null_resource because kubernetes_manifest validates during
# plan phase before ArgoCD CRDs exist.

resource "null_resource" "app_of_apps" {
  triggers = {
    manifest_hash = md5(yamlencode(local.app_of_apps_manifest))
  }

  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    command = <<-EOT
      CERT_DIR=$(mktemp -d)
      trap "rm -rf $CERT_DIR" EXIT
      
      echo "$CA_CERT" > "$CERT_DIR/ca.crt"
      echo "$CLIENT_CERT" > "$CERT_DIR/client.crt"
      echo "$CLIENT_KEY" > "$CERT_DIR/client.key"
      
      kubectl apply -f - \
        --server=https://${local.first_node_ip}:6443 \
        --certificate-authority="$CERT_DIR/ca.crt" \
        --client-certificate="$CERT_DIR/client.crt" \
        --client-key="$CERT_DIR/client.key" \
        <<'MANIFEST'
      ${yamlencode(local.app_of_apps_manifest)}
      MANIFEST
    EOT

    environment = {
      CA_CERT     = sensitive(base64decode(data.terraform_remote_state.talos_configure.outputs.kubernetes_client_configuration.ca_certificate))
      CLIENT_CERT = sensitive(base64decode(data.terraform_remote_state.talos_configure.outputs.kubernetes_client_configuration.client_certificate))
      CLIENT_KEY  = sensitive(base64decode(data.terraform_remote_state.talos_configure.outputs.kubernetes_client_configuration.client_key))
    }
  }
}
