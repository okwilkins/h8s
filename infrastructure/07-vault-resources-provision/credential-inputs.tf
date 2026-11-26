# ============================================================
# Argo Events
# ============================================================

resource "random_password" "argo_events_github_webhook_secret" {
  length  = 64
  special = false
}

# ============================================================
# Argo Workflows
# ============================================================

variable "github_commit_status_token" {
  description = "GitHub token with commit-status write permission. Supply TF_VAR_github_commit_status_token through the private SOPS secrets repo."
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = length(trimspace(var.github_commit_status_token)) > 0
    error_message = "The GitHub commit-status token must not be empty."
  }
}

# ============================================================
# Authelia
# ============================================================

resource "random_password" "authelia_argo_workflows_oidc_client_secret" {
  length  = 64
  special = false
}

resource "random_password" "authelia_argocd_oidc_client_secret" {
  length  = 64
  special = false
}

resource "random_password" "authelia_encryption_key" {
  length  = 64
  special = false
}

resource "random_password" "authelia_grafana_oidc_client_secret" {
  length  = 64
  special = false
}

resource "random_password" "authelia_harbor_oidc_client_secret" {
  length  = 64
  special = false
}

resource "random_password" "authelia_hmac_secret" {
  length  = 64
  special = false
}

resource "tls_private_key" "authelia_oidc_rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "random_password" "authelia_password_reset_jwt_secret" {
  length  = 128
  special = false
}

resource "random_password" "authelia_searxng_oidc_client_secret" {
  length  = 64
  special = false
}


resource "random_password" "authelia_session_secret" {
  length  = 64
  special = false
}

resource "random_password" "authelia_user_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

# ============================================================
# Authelia password hashes
# ============================================================

locals {
  oidc_passwords = {
    "authelia/argocd-oidc"         = { result = random_password.authelia_argocd_oidc_client_secret.result, bcrypt_hash = random_password.authelia_argocd_oidc_client_secret.bcrypt_hash }
    "authelia/argo-workflows-oidc" = { result = random_password.authelia_argo_workflows_oidc_client_secret.result, bcrypt_hash = random_password.authelia_argo_workflows_oidc_client_secret.bcrypt_hash }
    "authelia/forgejo-oidc"        = { result = random_password.forgejo["oidc-client"].result, bcrypt_hash = random_password.forgejo["oidc-client"].bcrypt_hash }
    "authelia/grafana-oidc"        = { result = random_password.authelia_grafana_oidc_client_secret.result, bcrypt_hash = random_password.authelia_grafana_oidc_client_secret.bcrypt_hash }
    "authelia/harbor-oidc"         = { result = random_password.authelia_harbor_oidc_client_secret.result, bcrypt_hash = random_password.authelia_harbor_oidc_client_secret.bcrypt_hash }
    "authelia/searxng-oidc"        = { result = random_password.authelia_searxng_oidc_client_secret.result, bcrypt_hash = random_password.authelia_searxng_oidc_client_secret.bcrypt_hash }
  }
  oidc_credentials = { for path, pw in local.oidc_passwords : path => { client-secret-plaintext = pw.result } }
  hash_sources = merge({ for path, pw in local.oidc_passwords : path => {
    field           = "client-secret-hash", password = pw.result
    default_setting = substr(pw.bcrypt_hash, 0, 29)
    } }, {
    "authelia/user-okwilkins-password-hash" = {
      field           = "hash", password = random_password.authelia_user_password.result
      default_setting = format("$argon2id$v=19$m=65536,t=3,p=4$%s:32", base64encode(substr(sha256(random_password.authelia_user_password.bcrypt_hash), 0, 18)))
    }
  })
}

resource "terraform_data" "hash_settings" {
  input = { for path, source in local.hash_sources : path => source.default_setting }
  lifecycle { ignore_changes = [input] }
}

data "external" "password_hash" {
  for_each = toset([for path, _ in local.hash_sources : path])
  program  = ["hash-password"]

  query = {
    password = local.hash_sources[each.key].password
    setting  = terraform_data.hash_settings.input[each.key]
  }
}

# ============================================================
# BookOrbit
# ============================================================

resource "random_password" "bookorbit_jwt_secret" {
  length  = 64
  special = false
}

resource "random_password" "bookorbit_setup_bootstrap_token" {
  length  = 32
  special = false
}

# ============================================================
# Chhoto URL
# ============================================================

resource "random_password" "chhoto_url_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

# ============================================================
# CloudNativePG
# ============================================================

resource "random_password" "cnpg_authelia_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "cnpg_bookorbit_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "cnpg_harbor_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

# ============================================================
# Cosign
# ============================================================

resource "tls_private_key" "cosign_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "random_password" "cosign_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

# ============================================================
# CrowdSec
# ============================================================

resource "random_password" "crowdsec_bouncer_key" {
  length  = 32
  special = false
}

locals {
  crowdsec_cloudflare_credentials = jsonencode({
    account_id         = local.cloudflare_account_id
    zone_id            = local.cloudflare_zone_id
    lapi_secret        = random_password.crowdsec_lapi_secret.result
    registration_token = random_password.crowdsec_registration_token.result
    bouncer_key        = random_password.crowdsec_bouncer_key.result
  })
}

# CrowdSec Console enrolment
variable "crowdsec_enroll_key" {
  description = "CrowdSec Console enrolment key from the private SOPS secrets."
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = length(trimspace(var.crowdsec_enroll_key)) > 0
    error_message = "Set TF_VAR_crowdsec_enroll_key to the CrowdSec Console enrolment key."
  }
}

resource "random_password" "crowdsec_lapi_secret" {
  length  = 64
  special = false
}

resource "random_password" "crowdsec_registration_token" {
  length  = 64
  special = false
}

# ============================================================
# Forgejo
# ============================================================

resource "random_password" "forgejo" {
  for_each = toset(["admin", "database", "internal-token", "metrics-token", "oidc-client", "secret-key"])

  length  = 64
  special = false
}

resource "random_bytes" "forgejo_jwt" {
  for_each = toset(["lfs", "oauth2"])

  length = 32
}

locals {
  forgejo_jwt_secrets = {
    for name, secret in random_bytes.forgejo_jwt :
    name => replace(replace(trimsuffix(secret.base64, "="), "+", "-"), "/", "_")
  }

  forgejo_vault_secrets = {
    "forgejo/admin" = {
      username = "forgejo-admin"
      password = random_password.forgejo["admin"].result
    }
    "forgejo/app" = {
      secret_key        = random_password.forgejo["secret-key"].result
      internal_token    = random_password.forgejo["internal-token"].result
      metrics_token     = random_password.forgejo["metrics-token"].result
      lfs_jwt_secret    = local.forgejo_jwt_secrets["lfs"]
      oauth2_jwt_secret = local.forgejo_jwt_secrets["oauth2"]
    }
    "cnpg/cnpg-forgejo-prod-app-user-credentials" = {
      username = "forgejo"
      password = random_password.forgejo["database"].result
    }
  }
}

# ============================================================
# Forgejo Renovate
# ============================================================

resource "random_password" "forgejo_renovate" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

locals {
  forgejo_renovate_credentials = sensitive(jsonencode({
    username             = "renovate"
    password             = random_password.forgejo_renovate.result
    "signing-key"        = tls_private_key.forgejo_renovate_signing.private_key_openssh
    "signing-public-key" = trimspace(tls_private_key.forgejo_renovate_signing.public_key_openssh)
  }))
}

resource "tls_private_key" "forgejo_renovate_signing" {
  algorithm = "ED25519"
}

# ============================================================
# Grafana
# ============================================================

resource "random_password" "grafana_admin_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

# ============================================================
# Harbor
# ============================================================

resource "random_password" "harbor_admin_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

locals {
  harbor_argo_workflows_credentials = {
    username = "robot$argo-workflows"
    password = random_password.harbor_argo_workflows_robot_password.result
  }
}

resource "random_password" "harbor_argo_workflows_robot_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "harbor_image_pull_robot_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

# ============================================================
# OAuth2 Proxy
# ============================================================

resource "random_password" "oauth2_proxy_searxng_cookie_secret" {
  length  = 32
  special = false
}

# ============================================================
# SearXNG
# ============================================================

variable "exa_api_key" {
  description = "Exa API key for SearXNG. Supply TF_VAR_exa_api_key through the private SOPS secrets repo."
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = length(trimspace(var.exa_api_key)) > 0
    error_message = "The Exa API key must not be empty."
  }
}

resource "random_password" "searxng_secret" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

# ============================================================
# Telegram
# ============================================================

variable "telegram_bot_token" {
  description = "Telegram bot token for cluster alerts."
  type        = string
  sensitive   = true
}

variable "telegram_chat_id" {
  description = "Numeric Telegram chat ID for cluster alerts."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^-?[0-9]+$", var.telegram_chat_id))
    error_message = "The Telegram chat ID must be a number, not the bot username."
  }
}

# ============================================================
# Vault Backup
# ============================================================

variable "vault_backup_access_key_id" {
  description = "B2 application key ID for the Vault snapshot bucket."
  type        = string
  sensitive   = true
}

variable "vault_backup_secret_access_key" {
  description = "B2 application key for the Vault snapshot bucket."
  type        = string
  sensitive   = true
}
