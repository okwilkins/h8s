locals {
  bootstrap_backend = {
    bucket                      = "h8s-terraform-backend"
    region                      = "eu-central-003"
    endpoints                   = { s3 = "https://s3.eu-central-003.backblazeb2.com" }
    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }

  first_node_name = tolist(sort(keys(var.nodes)))[0]
  first_node_ip   = var.nodes[local.first_node_name].ip_address

  # Find the node that matches proxmox_node_name and get its Proxmox IP
  proxmox_ssh_node = [
    for name, node in var.nodes : node
    if node.pve_node == var.proxmox_node_name
  ][0]
  proxmox_ssh_address = local.proxmox_ssh_node.proxmox_ip
}
