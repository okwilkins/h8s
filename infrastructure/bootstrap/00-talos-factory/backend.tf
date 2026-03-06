terraform {
  backend "local" {
    path = "$INFRA_ROOT/states/00-talos-factory.tfstate"
  }
}
