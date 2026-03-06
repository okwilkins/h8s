terraform {
  backend "local" {
    path = "${var.infra_root}/states/01-proxmox-iso-upload"
  }
}
