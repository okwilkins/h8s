data "terraform_remote_state" "vault_init" {
  backend = "local"
  config = {
    path = "${var.infra_root}/states/06-vault-init"
  }
}
