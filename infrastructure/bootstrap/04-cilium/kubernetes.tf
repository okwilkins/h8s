provider "kubernetes" {
  host                   = "https://${local.first_node_ip}:6443"
  client_certificate     = base64decode(data.terraform_remote_state.talos_configure.outputs.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(data.terraform_remote_state.talos_configure.outputs.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(data.terraform_remote_state.talos_configure.outputs.kubernetes_client_configuration.ca_certificate)
}
