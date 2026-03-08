terraform {
  backend "local" {
    path = "${var.infra_root}/states/07-vault-resources-provision"
  }
}
