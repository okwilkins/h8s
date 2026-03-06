data "terraform_remote_state" "talos_configure" {
  backend = "local"
  config = {
    path = "${var.infra_root}/states/03-talos-configure"
  }
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
