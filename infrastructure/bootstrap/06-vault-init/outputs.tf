output "first_node_ip" {
  description = "IP of the first control plane node"
  value       = local.first_node_ip
}

output "ca_cert" {
  description = "Kubernetes CA certificate (base64 decoded)"
  value       = base64decode(data.terraform_remote_state.talos_configure.outputs.kubernetes_client_configuration.ca_certificate)
  sensitive   = true
}

output "client_cert" {
  description = "Kubernetes client certificate (base64 decoded)"
  value       = base64decode(data.terraform_remote_state.talos_configure.outputs.kubernetes_client_configuration.client_certificate)
  sensitive   = true
}

output "client_key" {
  description = "Kubernetes client key (base64 decoded)"
  value       = base64decode(data.terraform_remote_state.talos_configure.outputs.kubernetes_client_configuration.client_key)
  sensitive   = true
}

