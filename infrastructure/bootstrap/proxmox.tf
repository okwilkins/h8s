# ============================================================
# Talos ISO
# ============================================================
# Downloads the factory-customised Talos ISO into each Proxmox node's local
# storage. Each node gets its own copy because local storage is not shared
# across Proxmox cluster nodes.
#
# The ISO URL is derived from the schematic resource in talos.tf, ensuring
# the correct extensions (QEMU guest agent, iscsi-tools, util-linux-tools)
# and Talos version are baked in.

locals {
  # Unique set of Proxmox nodes that have at least one VM assigned to them
  pve_nodes = toset([for node in var.nodes : node.pve_node])
}

resource "proxmox_virtual_environment_download_file" "talos_iso" {
  for_each = local.pve_nodes

  content_type = "iso"
  datastore_id = var.proxmox_iso_datastore
  node_name    = each.key

  url       = data.talos_image_factory_urls.this.urls.iso
  file_name = "talos-${var.talos_version}-${talos_image_factory_schematic.this.id}.iso"

  # Overwrite if Talos version or schematic changes (e.g. extension update)
  overwrite = true
}

# ============================================================
# Virtual Machines
# ============================================================
# One VM per node, driven by the var.nodes map. The map key is the hostname,
# which maps to a stable node number - this is the fix for the Longhorn
# diskUUID pitfall documented in infrastructure/talos/README.md.

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
    file_id   = proxmox_virtual_environment_download_file.talos_iso[each.value.pve_node].id
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

# ============================================================
# ISO Detachment
# ============================================================
# After Talos installs itself to disk and the node reboots, the CDROM
# must be detached so subsequent reboots boot from disk without re-running
# the installer.
#
# We wait for the QEMU guest agent on each VM to report ready (which means
# Talos has booted from disk and the agent is running), then detach the ISO
# via the Proxmox API. This uses a null_resource with local-exec as
# proxmox_virtual_environment_vm doesn't natively support post-boot hooks.
#
# The detach is idempotent - setting cdrom.file_id = "none" on an already-
# empty drive is a no-op.

resource "terraform_data" "detach_iso" {
  for_each = var.nodes

  # Re-run if the VM is recreated
  input = proxmox_virtual_environment_vm.nodes[each.key].id

  provisioner "local-exec" {
    # Wait until the guest agent reports the node IP (confirms Talos is up
    # and running from disk, not still in installer mode), then detach.
    # Requires: curl, jq, and PROXMOX_VE_ENDPOINT / credentials in environment.
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      VM_ID="${each.value.vm_id}"
      NODE="${each.value.pve_node}"
      ENDPOINT="${var.proxmox_node_address}"
      MAX_WAIT=300
      WAITED=0

      echo "Waiting for QEMU guest agent on ${each.key} (VM $VM_ID)..."
      until curl -sk \
          -H "Authorization: $${PROXMOX_VE_API_TOKEN:-}" \
          "https://$ENDPOINT:8006/api2/json/nodes/$NODE/qemu/$VM_ID/agent/network-get-interfaces" \
          2>/dev/null | jq -e '.data.result // empty' > /dev/null 2>&1; do
        if [ $WAITED -ge $MAX_WAIT ]; then
          echo "Timed out waiting for guest agent on ${each.key}"
          exit 1
        fi
        sleep 5
        WAITED=$((WAITED + 5))
      done

      echo "Guest agent ready on ${each.key}. Detaching ISO..."
      curl -sk -X PUT \
        -H "Authorization: $${PROXMOX_VE_API_TOKEN:-}" \
        -H "Content-Type: application/json" \
        -d '{"ide2": "none,media=cdrom"}' \
        "https://$ENDPOINT:8006/api2/json/nodes/$NODE/qemu/$VM_ID/config"

      echo "ISO detached from ${each.key}."
    EOT
  }

  depends_on = [proxmox_virtual_environment_vm.nodes]
}
