terraform {
  required_version = ">= 1.5"

  # Local state backend - this root exists to bootstrap the cluster from scratch,
  # before the in-cluster PostgreSQL backend is available. State is stored locally
  # and gitignored because it contains cluster PKI secrets (treat like secret.yaml).
  # Back it up somewhere safe (encrypted storage, password manager, etc.).

  required_providers {
    # see https://registry.terraform.io/providers/bpg/proxmox
    # see https://github.com/bpg/terraform-provider-proxmox
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.97"
    }

    # see https://registry.terraform.io/providers/siderolabs/talos
    # see https://github.com/siderolabs/terraform-provider-talos
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.10"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }

    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}

# Get the first node IP for initial Kubernetes API access (before VIP is ready)
locals {
  first_node_name = tolist(sort(keys(var.nodes)))[0]
  first_node_ip   = var.nodes[local.first_node_name].ip_address
}

# Credentials are supplied exclusively via environment variables - never hardcoded.
#
# Required env vars:
#   PROXMOX_VE_ENDPOINT  - e.g. "https://192.168.1.10:8006"
#   PROXMOX_VE_INSECURE  - "true" if using Proxmox's self-signed cert (typical homelab)
#   PROXMOX_VE_USERNAME + PROXMOX_VE_PASSWORD  - e.g. "root@pam" (simple, less secure)
#
# For production prefer an API token scoped to:
#   VM.Config.*, VM.PowerMgmt, VM.Allocate, Datastore.AllocateTemplate,
#   Datastore.AllocateSpace, Datastore.Audit on the relevant storage and node.
provider "proxmox" {
  # SSH access is required by bpg/proxmox for certain operations (e.g. uploading
  # ISO files via SFTP). Configure the node address to match your Proxmox host.
  ssh {
    agent    = true
    username = "root"
    node {
      name    = var.proxmox_node_name
      address = var.proxmox_node_address
    }
  }
}

provider "talos" {}

provider "helm" {
  kubernetes = {
    host                   = "https://${local.first_node_ip}:6443"
    client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
    cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
  }
}

provider "kubernetes" {
  host                   = "https://${local.first_node_ip}:6443"
  client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
}
