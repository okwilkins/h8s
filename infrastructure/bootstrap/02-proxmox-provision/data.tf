data "terraform_remote_state" "proxmox_talos_iso_ids" {
  backend = "local"
  config = {
    path = "${var.infra_root}/states/01-proxmox-iso-upload"
  }
}
