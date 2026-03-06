locals {
  first_node_name = tolist(sort(keys(var.nodes)))[0]
  first_node_ip   = var.nodes[local.first_node_name].ip_address
}
