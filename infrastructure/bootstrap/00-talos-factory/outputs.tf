output "schematic_id" {
  description = "The Talos schematic ID from the image factory (with your custom extensions)"
  value       = talos_image_factory_schematic.this.id
}

output "image_urls" {
  description = "Full set of image URLs from the factory"
  value       = data.talos_image_factory_urls.this
}
