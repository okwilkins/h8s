# ============================================================
# Talos
# ============================================================

talos_version      = "v1.13.4"
talos_cluster_name = "talos-homelab"

# ============================================================
# Proxmox
# ============================================================
# Datastore for the Talos ISO (must support 'iso' content type - 'local' usually works)
proxmox_iso_datastore = "local"

# Datastore for VM disks (e.g. 'local-lvm', 'local-zfs')
proxmox_disk_datastore = "local-lvm"


