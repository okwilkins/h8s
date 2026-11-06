output "forgejo_renovate_token" {
  description = "Forgejo Renovate runner's RENOVATE_TOKEN; also stored automatically in Vault."
  value       = forgejo_personal_access_token.renovate.token
  sensitive   = true
}

output "forgejo_renovate_vault_path" {
  description = "Vault KV path containing the Forgejo-generated token and commit identity."
  value       = local.forgejo_renovate_vault_path
  depends_on  = [terraform_data.vault_secret_forgejo_renovate]
}

output "forgejo_renovate_git_author" {
  description = "Commit author for the Forgejo Renovate runner."
  value       = "${forgejo_user.renovate.full_name} <${forgejo_user.renovate.email}>"
}
