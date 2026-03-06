output "kubernetes_client_configuration" {
  description = "Kubernetes client configuration from Talos"
  value       = talos_cluster_kubeconfig.this.kubernetes_client_configuration
  sensitive   = true
}
