data "terraform_remote_state" "talos_configure" {
  backend = "s3"
  config = merge(local.bootstrap_backend, {
    key = "h8s/bootstrap/03-talos-configure/terraform.tfstate"
  })
}
