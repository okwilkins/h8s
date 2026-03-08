terraform {
  backend "local" {
    path = "${var.infra_root}/states/05-argocd"
  }
}
