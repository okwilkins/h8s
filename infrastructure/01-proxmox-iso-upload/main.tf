# ============================================================
# Talos ISO
# ============================================================
# Downloads the factory-customised Talos ISO into each Proxmox node's local
# storage. Each node gets its own copy because local storage is not shared
# across Proxmox cluster nodes.
#
# The ISO URL is derived from the schematic resource in talos.tf, ensuring
# the correct extensions (QEMU guest agent, iscsi-tools, util-linux-tools)
# and Talos version are baked in.

locals {
  # Unique set of Proxmox nodes that have at least one VM assigned to them
  pve_nodes = toset([for node in var.nodes : node.pve_node])
}

resource "proxmox_virtual_environment_download_file" "talos_iso" {
  for_each = local.pve_nodes

  content_type = "iso"
  datastore_id = var.proxmox_iso_datastore
  node_name    = each.key

  url       = data.terraform_remote_state.talos_factory.outputs.image_urls.urls.iso
  file_name = "talos-${var.talos_version}-${data.terraform_remote_state.talos_factory.outputs.schematic_id}.iso"

  # Overwrite if Talos version or schematic changes (e.g. extension update)
  overwrite = true
}

