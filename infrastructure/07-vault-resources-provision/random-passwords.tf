# ============================================================
# Random Password Generators
# ============================================================

resource "random_password" "harbor_admin_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "harbor_main_user_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "harbor_dagger_robot_secret" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "harbor_image_pull_robot_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "grafana_admin_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "searxng_secret" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "cnpg_harbor_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "cnpg_authelia_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "authelia_encryption_key" {
  length  = 64
  special = false
}

resource "random_password" "authelia_user_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "authelia_session_secret" {
  length  = 64
  special = false
}

resource "random_password" "authelia_hmac_secret" {
  length  = 64
  special = false
}

resource "random_password" "authelia_grafana_oidc_client_secret" {
  length  = 64
  special = false
}

resource "random_password" "authelia_argocd_oidc_client_secret" {
  length  = 64
  special = false
}

resource "random_password" "authelia_searxng_oidc_client_secret" {
  length  = 64
  special = false
}


resource "random_password" "oauth2_proxy_searxng_cookie_secret" {
  length  = 32
  special = false
}
