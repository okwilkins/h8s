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
  }
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
