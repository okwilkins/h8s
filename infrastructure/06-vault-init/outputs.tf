# ============================================================
# Vault Init Outputs
# ============================================================

output "vault_initialised" {
  description = "Whether Vault readiness has been verified"
  value       = length(null_resource.vault_bootstrap) > 0
}

output "vault_credentials" {
  description = "Vault unseal keys, root token and initialisation metadata retained in encrypted state"
  value       = sensitive(terraform_data.vault_credentials.output)
  sensitive   = true
}
