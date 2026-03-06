terraform {
  backend "local" {
    path = "${var.infra_root}/states/04-cilium"
  }
}
