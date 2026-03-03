# ============================================================
# Cluster Access Credentials
# ============================================================
# Both outputs are marked sensitive so they don't print to stdout on apply.
#
# Usage after apply:
#   terraform output -raw talosconfig > ~/.talos/config
#   terraform output -raw kubeconfig  > ~/.kube/config
#
# Or to write both at once:
#   terraform output -raw talosconfig > /tmp/talosconfig && \
#     talosctl config merge /tmp/talosconfig && rm /tmp/talosconfig
#   terraform output -raw kubeconfig  > ~/.kube/config

output "talosconfig" {
  description = "Talosconfig for use with talosctl. Write to ~/.talos/config or merge with talosctl config merge."
  value       = talos_machine_secrets.this.client_configuration.ca_certificate != "" ? data.talos_client_configuration.this.talos_config : null
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubeconfig for use with kubectl. Write to ~/.kube/config."
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "schematic_id" {
  description = "Talos image factory schematic ID for this cluster's extension set. Useful for talosctl upgrade."
  value       = talos_image_factory_schematic.this.id
}

output "talos_iso_url" {
  description = "URL of the Talos ISO that was uploaded to Proxmox."
  value       = data.talos_image_factory_urls.this.urls.iso
}

output "talos_installer_url" {
  description = "Installer image URL for use with talosctl upgrade --image."
  value       = data.talos_image_factory_urls.this.urls.installer
}

output "node_ips" {
  description = "Map of node name to IP address."
  value       = { for name, node in var.nodes : name => node.ip_address }
}

# ============================================================
# Client Configuration Data Source
# ============================================================

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for name, node in var.nodes : node.ip_address]
  nodes                = [for name, node in var.nodes : node.ip_address]
}
