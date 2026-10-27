data "terraform_remote_state" "talos_factory" {
  backend = "s3"
  config = merge(local.bootstrap_backend, {
    key = "h8s/bootstrap/00-talos-factory/terraform.tfstate"
  })
}
