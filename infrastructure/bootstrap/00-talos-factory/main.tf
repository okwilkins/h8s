# ============================================================
# Image Factory - Schematic & URLs
# ============================================================
# Registers the customisation (extensions) with the Talos image factory and
# retrieves the resulting ISO and installer URLs. The schematic ID is stored
# in state, so it won't be re-fetched on every apply (unlike the old curl in
# gen_configs.sh).
#
# Extensions baked into the ISO:
#   - siderolabs/qemu-guest-agent   (Proxmox VM integration)
#   - siderolabs/iscsi-tools        (Longhorn iSCSI support)
#   - siderolabs/util-linux-tools   (Longhorn util-linux support)

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = [
          "siderolabs/qemu-guest-agent",
          "siderolabs/iscsi-tools",
          "siderolabs/util-linux-tools",
        ]
      }
    }
  })
}

data "talos_image_factory_urls" "this" {
  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.this.id
  platform      = "metal"
  architecture  = "amd64"
}

