terraform {
  backend "local" {
    path = "../../states/00-talos-factory.tfstate"
  }
}
