terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.29.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.5.0"
    }
    harbor = {
      source  = "goharbor/harbor"
      version = "3.12.5"
    }
    forgejo = {
      source  = "svalabs/forgejo"
      version = "1.7.0"
    }
  }
}

# The infrastructure shell exports TF_CLOUDFLARE_TOKEN as CLOUDFLARE_API_TOKEN.
# The cloudflared connector token cannot authenticate the management API.
provider "cloudflare" {}

data "terraform_remote_state" "talos_configure" {
  backend = "s3"
  config = merge(local.bootstrap_backend, {
    key = "h8s/bootstrap/03-talos-configure/terraform.tfstate"
  })
}

provider "kubernetes" {
  host                   = "https://${data.terraform_remote_state.talos_configure.outputs.first_node_ip}:6443"
  client_certificate     = base64decode(data.terraform_remote_state.talos_configure.outputs.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(data.terraform_remote_state.talos_configure.outputs.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(data.terraform_remote_state.talos_configure.outputs.kubernetes_client_configuration.ca_certificate)
}

provider "harbor" {
  url      = local.harbor_url
  password = local.harbor_pass
  username = local.harbor_user
}

# Access token creation requires basic authentication, not an API token.
provider "forgejo" {
  host     = var.forgejo_url
  username = data.kubernetes_secret_v1.forgejo_admin_secret.data.username
  password = data.kubernetes_secret_v1.forgejo_admin_secret.data.password
}
