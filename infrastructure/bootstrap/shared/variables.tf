# ============================================================
# General
# ============================================================

variable "project_root" {
  description = "Root directory for infrastructure"
  type        = string
}

variable "infra_root" {
  description = "Root directory for infrastructure"
  type        = string
}

# ============================================================
# Proxmox
# ============================================================

variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint, for example https://pve.example.com:8006/"
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for the Proxmox API"
  type        = bool
  default     = true
}

variable "proxmox_username" {
  description = "Proxmox username with realm, for example root@pam"
  type        = string
  sensitive   = true
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "proxmox_iso_datastore" {
  description = "Proxmox datastore ID to upload the Talos ISO into (must support 'iso' content type)."
  type        = string
  default     = "local"
}

variable "proxmox_node_name" {
  description = "Name of the Proxmox node used for SSH by the bpg provider. This must match the 'pve_node' field of one of your nodes in the nodes map."
  type        = string
}

variable "proxmox_disk_datastore" {
  description = "Proxmox datastore ID to store VM disks (e.g. 'local-lvm', 'local-zfs')."
  type        = string
  default     = "local-lvm"
}

# ============================================================
# Talos
# ============================================================

variable "talos_version" {
  description = "Talos Linux version to deploy. Keep in sync with the siderolabs/talos release."
  type        = string
  default     = "v1.12.0"
}

variable "talos_cluster_name" {
  description = "Kubernetes cluster name, used in generated configs and kubeconfig context."
  type        = string
  default     = "talos-homelab"
}

variable "talos_cluster_vip" {
  description = "Virtual IP shared across all controlplane nodes. Must be within the subnet but outside DHCP range."
  type        = string
}

# ============================================================
# Nodes
# ============================================================

variable "nodes" {
  description = <<-EOT
    Map of cluster nodes. The map key becomes the Kubernetes node hostname
    (e.g. "controlplane-worker-1"). Each node's number must be stable - changing
    it or swapping node IPs will cause Longhorn diskUUID mismatches on existing
    clusters. Add new nodes by adding new keys; never reorder existing ones.
  EOT

  type = map(object({
    # Proxmox VM settings
    vm_id        = number # Must be unique across the entire Proxmox cluster
    pve_node     = string # Proxmox node name to place this VM on (e.g., "server-01")
    pve_dns_name = string # DNS name for this Proxmox node (e.g., "pve1.okwilkins.dev")
    proxmox_ip   = string # IP address of the Proxmox server hosting this VM

    # Hardware resources
    cpu_cores = number
    memory_mb = number
    disk_gb   = number

    # Network
    # mac_address must match the static DHCP lease in your router so the node
    # always gets the expected IP. Format: "BC:24:11:xx:xx:xx".
    # Proxmox requires the locally-administered bit to be set (second hex digit
    # must be 2, 6, A, or E) - the BC:24:11 prefix is Proxmox's own OUI and
    # is a safe choice.
    ip_address  = string
    mac_address = string
  }))
}
