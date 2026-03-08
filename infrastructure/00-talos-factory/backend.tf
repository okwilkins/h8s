terraform {
  backend "local" {
    path = "${var.infra_root}/states/00-talos-factory.tfstate"
  }
}
