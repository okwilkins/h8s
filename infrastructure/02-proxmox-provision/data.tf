data "terraform_remote_state" "proxmox_talos_iso_ids" {
  backend = "s3"
  config = merge(local.bootstrap_backend, {
    key = "h8s/bootstrap/01-proxmox-iso-upload/terraform.tfstate"
  })
}
