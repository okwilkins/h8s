data "terraform_remote_state" "talos_configure" {
  backend = "s3"
  config = merge(local.bootstrap_backend, {
    key = "h8s/bootstrap/03-talos-configure/terraform.tfstate"
  })
}

# # ============================================================
# # Wait for Kubernetes API
# # ============================================================
# # Ensures the Kubernetes API server is ready before installing Cilium.
# # This prevents "connection refused" errors during helm_release.
data "kubernetes_namespace_v1" "probe" {
  metadata {
    name = "kube-system"
  }
}
