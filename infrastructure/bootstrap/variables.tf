# ============================================================
# Proxmox
# ============================================================

variable "proxmox_node_name" {
  description = "Name of the Proxmox node used for SSH by the bpg provider. In a multi-node cluster this should be the node whose IP is set in proxmox_node_address."
  type        = string
}

variable "proxmox_node_address" {
  description = "IP address or hostname of the Proxmox node, used for SSH by the bpg provider."
  type        = string
}

variable "proxmox_iso_datastore" {
  description = "Proxmox datastore ID to upload the Talos ISO into (must support ISO content type)."
  type        = string
  default     = "local"
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
  default     = "v1.10.3"
}

variable "cluster_name" {
  description = "Kubernetes cluster name, used in generated configs and kubeconfig context."
  type        = string
  default     = "talos-homelab"
}

variable "cluster_vip" {
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
    vm_id    = number # Must be unique across the entire Proxmox cluster
    pve_node = string # Proxmox node name to place this VM on

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

  default = {
    "controlplane-worker-1" = {
      vm_id       = 100
      pve_node    = "server-01"
      cpu_cores   = 4
      memory_mb   = 16384
      disk_gb     = 100
      ip_address  = "192.168.1.101"
      mac_address = "BC:24:11:00:00:01"
    }
    "controlplane-worker-2" = {
      vm_id       = 101
      pve_node    = "server-02"
      cpu_cores   = 4
      memory_mb   = 16384
      disk_gb     = 100
      ip_address  = "192.168.1.102"
      mac_address = "BC:24:11:00:00:02"
    }
  }
}
