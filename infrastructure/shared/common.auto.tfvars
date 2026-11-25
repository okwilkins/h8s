# ============================================================
# Talos
# ============================================================

talos_version      = "v1.14.7"
talos_cluster_name = "talos-homelab"
kubernetes_version = "v1.37.3"

# ============================================================
# Proxmox
# ============================================================
# Datastore for the Talos ISO (must support 'iso' content type - 'local' usually works)
proxmox_iso_datastore = "local"

# Datastore for VM disks (e.g. 'local-lvm', 'local-zfs')
proxmox_disk_datastore = "local-lvm"
