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
  argocd_app = yamldecode(
    file("${var.project_root}/ci-cd/argocd/environments/prod/apps/argocd-helm.yaml")
  )
  argocd_chart_version = try(
    local.argocd_app.spec.sources[0].targetRevision,
    null
  )
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
    manifest      = yamlencode(local.app_of_apps_manifest)
    infra_root    = var.infra_root
  }

  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    command = <<-EOT
      source ${self.triggers.infra_root}/scripts/common.sh  # Change to self.triggers
      load_tf_kube_env
      create_cert_dir
      kubectl_wrapper apply -f - \
        <<'MANIFEST'
      ${self.triggers.manifest}  # Change to self.triggers
      MANIFEST
    EOT
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      source ${self.triggers.infra_root}/scripts/common.sh  # Change to self.triggers
      load_tf_kube_env
      create_cert_dir
      kubectl_wrapper delete application --ignore-not-found -f - \
        <<'MANIFEST'
      ${self.triggers.manifest}  # Change to self.triggers
      MANIFEST
    EOT
  }
}
