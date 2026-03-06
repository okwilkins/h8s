data "terraform_remote_state" "talos_factory" {
  backend = "local"
  config = {
    path = "${var.infra_root}/states/00-talos-factory.tfstate"
  }
}
