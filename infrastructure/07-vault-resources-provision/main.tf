provider "vault" {
  address = "http://127.0.0.1:18200"
  token   = data.terraform_remote_state.vault_init.outputs.vault_credentials.root_token
}

locals {
  # INFO: Keys are Vault paths. Each value maps the fields an app reads to its credential inputs.
  kv_credentials = merge(local.forgejo_vault_secrets, local.oidc_credentials, {
    "argo-events/github-webhook"                    = { secret = random_password.argo_events_github_webhook_secret.result }
    "argo-workflows/github-app"                     = { private-key = var.h8s_workflows_github_app_private_key }
    "argo-workflows/github-status"                  = { token = var.github_commit_status_token }
    "authelia/encryption-key"                       = { encryption-key = random_password.authelia_encryption_key.result }
    "authelia/session-secret"                       = { session-secret = random_password.authelia_session_secret.result }
    "authelia/hmac-secret"                          = { hmac-secret = random_password.authelia_hmac_secret.result }
    "authelia/password-reset-jwt-secret"            = { jwt-secret = random_password.authelia_password_reset_jwt_secret.result }
    "authelia/oidc-rsa-key"                         = { rsa-private-key = "${chomp(tls_private_key.authelia_oidc_rsa.private_key_pem)}\n" }
    "bookorbit/bookorbit-secret"                    = { jwt-secret = random_password.bookorbit_jwt_secret.result, setup-bootstrap-token = random_password.bookorbit_setup_bootstrap_token.result }
    "cnpg/cnpg-bookorbit-prod-app-user-credentials" = { username = "bookorbit", password = random_password.cnpg_bookorbit_password.result }
    # The original Cosign writer used echo, appending a newline to each PEM.
    "cosign/key-pair" = {
      COSIGN_PASSWORD = random_password.cosign_password.result
      "cosign.key"    = "${tls_private_key.cosign_key.private_key_pem}\n"
      "cosign.pub"    = "${tls_private_key.cosign_key.public_key_pem}\n"
    }
    "crowdsec/cloudflare"                = jsondecode(local.crowdsec_cloudflare_credentials)
    "crowdsec/console"                   = { enroll_key = var.crowdsec_enroll_key }
    "harbor/argo-workflows"              = local.harbor_argo_workflows_credentials
    "harbor/image-pull"                  = { ROBOT_PASSWORD = random_password.harbor_image_pull_robot_password.result }
    "monitoring/telegram"                = { BOT_TOKEN = var.telegram_bot_token, CHAT_ID = var.telegram_chat_id }
    "oauth2-proxy/searxng-cookie-secret" = { cookie-secret = random_password.oauth2_proxy_searxng_cookie_secret.result }
    "renovate/forgejo"                   = jsondecode(local.forgejo_renovate_credentials)
    "renovate/github-app"                = { private-key = var.h8s_renovate_github_app_private_key }
    "searxng/exa"                        = { api-key = var.exa_api_key }
    "searxng/searxng-secret"             = { SECRET = random_password.searxng_secret.result }
    "vault/backup-b2"                    = { AWS_ACCESS_KEY_ID = var.vault_backup_access_key_id, AWS_SECRET_ACCESS_KEY = var.vault_backup_secret_access_key }
    "harbor/harbor-admin-credentials" = {
      HARBOR_ADMIN_USERNAME = "admin"
      HARBOR_ADMIN_PASSWORD = random_password.harbor_admin_password.result
    }
    "grafana/grafana-admin-credentials" = {
      GF_SECURITY_ADMIN_USER     = "admin"
      GF_SECURITY_ADMIN_PASSWORD = random_password.grafana_admin_password.result
    }
    "chhoto-url/chhoto-url-secret" = {
      password = random_password.chhoto_url_password.result
    }
    "cnpg/cnpg-harbor-prod-app-user-credentials" = {
      username = "harbor"
      password = random_password.cnpg_harbor_password.result
    }
    "cnpg/cnpg-authelia-prod-app-user-credentials" = {
      username = "authelia"
      password = random_password.cnpg_authelia_password.result
    }
    "authelia/user-okwilkins-password-hash" = {}
  })
}

locals {
  credential_paths = toset([for path, _ in local.kv_credentials : path])

  # INFO: credential-inputs.tf supplies the extra verifier field for Authelia entries.
  password_hash_fields = {
    for path, source in local.hash_sources : path => {
      (source.field) = sensitive(data.external.password_hash[path].result.hash)
    }
  }

  # INFO: Include hash settings so a salt or cost change triggers a Vault write.
  version_inputs = {
    for path, fields in local.kv_credentials : path => (
      contains(keys(local.hash_sources), path)
      ? jsonencode([fields, local.hash_sources[path].password, terraform_data.hash_settings.input[path]])
      : jsonencode(fields)
    )
  }
}

resource "vault_kv_secret_v2" "credentials" {
  for_each = local.credential_paths

  mount = "kubernetes-homelab"
  name  = each.key

  data_json_wo = jsonencode(merge(
    local.kv_credentials[each.key],
    lookup(local.password_hash_fields, each.key, {}),
  ))

  data_json_wo_version = parseint(substr(nonsensitive(sha256(local.version_inputs[each.key])), 0, 12), 16) + 1

  lifecycle { prevent_destroy = true }
}
