terraform {
  backend "local" {
    path = "${var.infra_root}/states/03-talos-configure"
  }
}
