data "kubernetes_secret_v1" "forgejo_admin_secret" {
  metadata {
    name      = "forgejo-admin-secret"
    namespace = "forgejo"
  }
}

data "kubernetes_secret_v1" "forgejo_renovate_credentials" {
  metadata {
    name      = "renovate-forgejo-credentials"
    namespace = "renovate"
  }
}

resource "forgejo_user" "renovate" {
  login                     = "renovate"
  full_name                 = "Renovate Bot"
  email                     = var.forgejo_renovate_email
  password                  = data.kubernetes_secret_v1.forgejo_renovate_credentials.data.password
  active                    = true
  admin                     = false
  must_change_password      = false
  allow_create_organization = false
  allow_git_hook            = false
  allow_import_local        = false
  max_repo_creation         = 0
  visibility                = "private"
  send_notify               = false
  deactivate_on_destroy     = true
}

resource "forgejo_ssh_key" "renovate_signing" {
  user  = forgejo_user.renovate.login
  title = "Renovate commit signing"
  key   = data.kubernetes_secret_v1.forgejo_renovate_credentials.data["signing-public-key"]
}

data "forgejo_repository" "renovate" {
  for_each = var.forgejo_renovate_repositories

  owner = split("/", each.value)[0]
  name  = split("/", each.value)[1]
}

resource "forgejo_collaborator" "renovate" {
  for_each = var.forgejo_renovate_repositories

  repository_id = data.forgejo_repository.renovate[each.key].id
  user          = forgejo_user.renovate.login
  permission    = "write"
}

resource "forgejo_personal_access_token" "renovate" {
  user = forgejo_user.renovate.login
  name = "renovate"
  scopes = [
    "write:repository",
    "write:issue",
    "read:user",
    "read:organization",
    "read:package",
  ]
}

locals {
  forgejo_renovate_vault_path = "kubernetes-homelab/renovate/forgejo-token"
  forgejo_renovate_credentials = sensitive(jsonencode({
    username     = forgejo_user.renovate.login
    token        = forgejo_personal_access_token.renovate.token
    "git-author" = "${forgejo_user.renovate.full_name} <${forgejo_user.renovate.email}>"
  }))
}

resource "terraform_data" "vault_secret_forgejo_renovate" {
  triggers_replace = [
    local.forgejo_renovate_vault_path,
    sha256(local.forgejo_renovate_credentials),
  ]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      INFRA_ROOT           = var.infra_root
      RENOVATE_CREDENTIALS = local.forgejo_renovate_credentials
      VAULT_SECRET_PATH    = local.forgejo_renovate_vault_path
    }

    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      load_tf_kube_env
      VAULT_TOKEN="$(tofu -chdir="$INFRA_ROOT/06-vault-init" output -json vault_credentials | jq -er '.root_token')"

      {
        printf '%s\n' "$VAULT_TOKEN"
        printf '%s' "$RENOVATE_CREDENTIALS"
      } | kubectl_wrapper exec -i -n vault vault-0 -- \
        /bin/sh -ec '
          IFS= read -r VAULT_TOKEN
          export VAULT_TOKEN
          vault kv put "$1" - >/dev/null
        ' sh "$VAULT_SECRET_PATH"
    EOT
  }
}
