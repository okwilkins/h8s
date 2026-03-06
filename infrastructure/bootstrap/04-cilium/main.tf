# ============================================================
# Cilium CNI Bootstrap
# ============================================================
# Installs Cilium CNI immediately after Talos cluster bootstrap.
# This eliminates the VIP chicken-and-egg problem - by the time
# terraform apply completes, Cilium is running and the VIP works.
#
# Based on: networking/cilium/environments/prod/values.yaml
#           networking/cilium/base/*.yaml
#
# After this runs, the cluster will have:
# - Cilium CNI installed and running
# - L2 announcement policies configured
# - LoadBalancer IP pools defined
# - VIP (192.168.1.120) functional

locals {
  cilium_values = file("${var.project_root}/networking/cilium/environments/prod/values.yaml")
  # Extract the Cilium Helm chart version from the ArgoCD Application
  # manifest to ensure consistency between bootstrap and GitOps.
  cilium_app = yamldecode(
    file("${var.project_root}/ci-cd/argocd/environments/prod/apps/cilium-helm.yaml")
  )
  cilium_chart_version = try(
    local.cilium_app.spec.sources[0].targetRevision,
    null
  )
}

# ============================================================
# Cilium Helm Release
# ============================================================
# Installs Cilium from the official Helm chart using the same
# values as networking/cilium/environments/prod/values.yaml

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = local.cilium_chart_version
  namespace  = "kube-system"

  values = [local.cilium_values]

  wait             = true
  wait_for_jobs    = true
  timeout          = 600
  create_namespace = false

  depends_on = [data.kubernetes_namespace_v1.probe]
}

