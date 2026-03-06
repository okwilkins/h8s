terraform {
  backend "local" {
    path = "${var.infra_root}/states/02-proxmox-provision"
  }
}
