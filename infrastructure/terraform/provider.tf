terraform {
  required_providers {
    harbor = {
      source  = "goharbor/harbor"
      version = "3.10.21"
    }
  }
}

provider "kubernetes" {
  config_path    = "$HOME/.kube/config"
  config_context = "talos-homelab"
}

provider "harbor" {}
