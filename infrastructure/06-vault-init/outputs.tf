# ============================================================
# Vault Init Outputs
# ============================================================

output "vault_initialised" {
  description = "Whether Vault initialisation has been attempted"
  value       = length(null_resource.vault_bootstrap) > 0
}

output "vault_init_file" {
  description = "Path to the Vault initialisation output file"
  value       = "${var.infra_root}/06-vault-init/secrets/vault-init.json"
}
