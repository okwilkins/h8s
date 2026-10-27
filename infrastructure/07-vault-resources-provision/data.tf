data "terraform_remote_state" "vault_init" {
  backend = "s3"
  config = merge(local.bootstrap_backend, {
    key = "h8s/bootstrap/06-vault-init/terraform.tfstate"
  })
}
