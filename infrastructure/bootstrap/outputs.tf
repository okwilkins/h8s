# ============================================================
# Cluster Access Credentials
# ============================================================
# Both outputs are marked sensitive so they don't print to stdout on apply.
# 
# Files generated:
#   - talosconfig.yaml (Talos client config, in this directory)
#   - ~/.kube/config (Kubernetes config, merged with existing)
#
# Usage after apply:
#   export KUBECONFIG=~/.kube/config
#   talosctl --talosconfig $(pwd)/talosconfig.yaml version

output "talosconfig" {
  description = "Talosconfig for use with talosctl. Also written to talosconfig.yaml."
  value       = talos_machine_secrets.this.client_configuration.ca_certificate != "" ? data.talos_client_configuration.this.talos_config : null
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubeconfig for use with kubectl. Merged into ~/.kube/config."
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

# ============================================================
# Write configs to files
# ============================================================

# Write talosconfig to bootstrap directory
resource "local_file" "talosconfig" {
  content  = data.talos_client_configuration.this.talos_config
  filename = "${path.module}/talosconfig.yaml"
}

# Merge kubeconfig into ~/.kube/config
resource "null_resource" "kubeconfig_merge" {
  triggers = {
    kubeconfig = talos_cluster_kubeconfig.this.kubeconfig_raw
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Create ~/.kube if it doesn't exist
      mkdir -p ~/.kube
      
      # Write the new kubeconfig to a temp file
      cat > /tmp/new_kubeconfig.yaml << 'EOF'
      ${talos_cluster_kubeconfig.this.kubeconfig_raw}
      EOF
      
      # If ~/.kube/config exists, merge; otherwise just copy
      if [ -f ~/.kube/config ]; then
        # Merge existing with new using kubectl
        KUBECONFIG=~/.kube/config:/tmp/new_kubeconfig.yaml kubectl config view --flatten > /tmp/merged_kubeconfig.yaml
        mv /tmp/merged_kubeconfig.yaml ~/.kube/config
      else
        cp /tmp/new_kubeconfig.yaml ~/.kube/config
      fi
      
      # Cleanup
      rm -f /tmp/new_kubeconfig.yaml /tmp/merged_kubeconfig.yaml
    EOT
  }

  depends_on = [talos_cluster_kubeconfig.this]
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
