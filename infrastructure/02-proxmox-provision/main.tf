# ============================================================
# Virtual Machines
# ============================================================
# One VM per node, driven by the var.nodes map. The map key is the hostname,
# which maps to a stable node number - this is the fix for the Longhorn
# diskUUID pitfall documented in infrastructure/bootstrap/README.md.

resource "proxmox_virtual_environment_vm" "nodes" {
  for_each = var.nodes

  name        = each.key
  description = "Talos Linux controlplane-worker node. Managed by Terraform (infrastructure/bootstrap)."
  tags        = ["terraform", "talos", "kubernetes"]

  node_name = each.value.pve_node
  vm_id     = each.value.vm_id

  # Shutdown gracefully via QEMU guest agent (baked into the Talos ISO)
  stop_on_destroy = true

  # Start on Proxmox host boot
  on_boot = true

  agent {
    enabled = true
    trim    = true
    type    = "virtio"
  }

  cpu {
    cores = each.value.cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory_mb
  }

  # Boot disk - Talos installs itself here from the ISO on first boot
  disk {
    datastore_id = var.proxmox_disk_datastore
    interface    = "virtio0"
    size         = each.value.disk_gb
    file_format  = "raw"
    discard      = "on"
    ssd          = true
  }

  # Talos ISO - used only for first boot / installation.
  # References the ISO downloaded to this VM's specific Proxmox node.
  cdrom {
    interface = "ide2"
    file_id   = data.terraform_remote_state.proxmox_talos_iso_ids.outputs.proxmox_talos_iso_ids[each.value.pve_node]
  }

  # Boot order: disk first so the node boots from disk after installation,
  # CDROM second so it can boot from ISO when disk is blank on first run.
  boot_order = ["virtio0", "ide2"]

  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    firewall    = false
    mac_address = each.value.mac_address
  }

  # Required for Talos - QEMU guest agent channel
  serial_device {}

  # OVMF (UEFI) is recommended for Talos
  bios = "ovmf"

  efi_disk {
    datastore_id = var.proxmox_disk_datastore
    file_format  = "raw"
    type         = "4m"
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    # Prevent accidental VM destruction on Talos version/schematic upgrades -
    # upgrades are handled by Talos itself via talosctl upgrade, not by
    # recreating VMs. Remove this ignore if you intentionally want to rebuild.
    ignore_changes = [
      cdrom,
      boot_order,
    ]
  }
}

