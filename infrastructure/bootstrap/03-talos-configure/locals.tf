locals {
  first_node_name = tolist(sort(keys(var.nodes)))[0]
  first_node_ip   = var.nodes[local.first_node_name].ip_address
  #
  # # Find the node that matches proxmox_node_name and get its Proxmox IP
  # proxmox_ssh_node = [
  #   for name, node in var.nodes : node
  #   if node.pve_node == var.proxmox_node_name
  # ][0]
  # proxmox_ssh_address = local.proxmox_ssh_node.proxmox_ip
}
