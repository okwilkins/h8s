terraform {
  required_providers {
    harbor = {
      source  = "goharbor/harbor"
      version = "3.10.21"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "admin@talos-homelab"
}

provider "harbor" {}
