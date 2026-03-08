output "proxmox_talos_iso_ids" {
  description = "Map of Proxmox node names to their Talos ISO file IDs"
  value       = { for node, iso in proxmox_virtual_environment_download_file.talos_iso : node => iso.id }
}
