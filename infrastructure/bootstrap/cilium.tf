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
  # Load Cilium values from the existing local file
  cilium_values = file("${path.module}/../../networking/cilium/environments/prod/values.yaml")
}

# ============================================================
# Cilium Version from ArgoCD App
# ============================================================
# Extract the Cilium Helm chart version from the ArgoCD Application
# manifest to ensure consistency between bootstrap and GitOps.

data "external" "cilium_version" {
  program = ["bash", "-c", <<-EOT
    version=$(yq '.spec.sources[0].targetRevision' ${path.module}/../../ci-cd/argocd/environments/prod/apps/cilium-helm.yaml)
    echo "{\"version\": \"$version\"}"
  EOT
  ]
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
  version    = data.external.cilium_version.result.version
  namespace  = "kube-system"

  values = [local.cilium_values]

  # Wait for the release to be fully deployed
  wait             = true
  wait_for_jobs    = true
  timeout          = 600
  create_namespace = false

  depends_on = [talos_machine_bootstrap.this]
}

# ============================================================
# Cilium Manifests (IP Pools & L2 Policies)
# ============================================================
# Apply Cilium manifests using kubectl with explicit node IP connection.
# This bypasses the VIP entirely during bootstrap.

resource "null_resource" "cilium_manifests" {
  provisioner "local-exec" {
    command = <<-EOT
      kubectl kustomize ${path.module}/../../networking/cilium/environments/prod | \
      kubectl --server=https://${local.first_node_ip}:6443 \
              --certificate-authority=<(echo '${base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)}' | base64 -d) \
              --client-certificate=<(echo '${base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)}' | base64 -d) \
              --client-key=<(echo '${base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)}' | base64 -d) \
              --insecure-skip-tls-verify=true \
              apply -f -
    EOT
  }

  depends_on = [helm_release.cilium]
}
