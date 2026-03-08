data "terraform_remote_state" "talos_configure" {
  backend = "local"
  config = {
    path = "${var.infra_root}/states/03-talos-configure"
  }
}
