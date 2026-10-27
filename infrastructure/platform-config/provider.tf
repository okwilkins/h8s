terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.4.0"
    }
    harbor = {
      source  = "goharbor/harbor"
      version = "3.12.5"
    }
  }
}

data "terraform_remote_state" "talos_configure" {
  backend = "s3"
  config = {
    bucket                      = "h8s-terraform-backend"
    key                         = "h8s/bootstrap/03-talos-configure/terraform.tfstate"
    region                      = "eu-central-003"
    endpoints                   = { s3 = "https://s3.eu-central-003.backblazeb2.com" }
    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
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

