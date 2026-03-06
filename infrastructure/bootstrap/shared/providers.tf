terraform {
  required_version = ">= 1.5"

  # Local state backend - this root exists to bootstrap the cluster from scratch,
  # before the in-cluster PostgreSQL backend is available. State is stored locally
  # and gitignored because it contains cluster PKI secrets (treat like secret.yaml).
  # Back it up somewhere safe (encrypted storage, password manager, etc.).

  required_providers {
    # https://registry.terraform.io/providers/bpg/proxmox
    # https://github.com/bpg/terraform-provider-proxmox
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.97"
    }

    # https://registry.terraform.io/providers/siderolabs/talos
    # https://github.com/siderolabs/terraform-provider-talos
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.10"
    }

    helm = {
      # https://registry.terraform.io/providers/hashicorp/helm
      # https://github.com/hashicorp/terraform-provider-helm
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }

    kubernetes = {
      # https://registry.terraform.io/providers/hashicorp/kubernetes
      # https://github.com/hashicorp/terraform-provider-kubernetes
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }

    null = {
      # https://registry.terraform.io/providers/hashicorp/null
      # https://github.com/hashicorp/terraform-provider-null
      source  = "hashicorp/null"
      version = "~> 3.2"
    }

    external = {
      # https://registry.terraform.io/providers/hashicorp/external
      # https://github.com/hashicorp/terraform-provider-external
      source  = "hashicorp/external"
      version = "~> 2.3"
    }

    random = {
      # https://registry.terraform.io/providers/hashicorp/random
      # https://github.com/hashicorp/terraform-provider-random
      source  = "hashicorp/random"
      version = "~> 3.6"
    }

    tls = {
      # https://registry.terraform.io/providers/hashicorp/tls
      # https://github.com/hashicorp/terraform-provider-tls
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
