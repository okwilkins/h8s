locals {
  cloudflare_http_origin     = "http://20.0.0.0:80"
  cloudflare_tunnel_hostname = "${cloudflare_zero_trust_tunnel_cloudflared.h8s_prod.id}.cfargotunnel.com"

  cloudflare_routes_dir = "${path.module}/../../networking/gateways/base/http-routes"
  cloudflare_http_hosts = {
    "argo-events/0"      = one(yamldecode(file("${local.cloudflare_routes_dir}/argo-events.yaml")).spec.hostnames)
    "authelia/0"         = one(yamldecode(file("${local.cloudflare_routes_dir}/authelia.yaml")).spec.hostnames)
    "bookorbit/0"        = one(yamldecode(file("${local.cloudflare_routes_dir}/bookorbit.yaml")).spec.hostnames)
    "chhoto-url/0"       = one(yamldecode(file("${local.cloudflare_routes_dir}/chhoto-url.yaml")).spec.hostnames)
    "excalidraw/0"       = one(yamldecode(file("${local.cloudflare_routes_dir}/excalidraw.yaml")).spec.hostnames)
    "forgejo/0"          = one(yamldecode(file("${local.cloudflare_routes_dir}/forgejo.yaml")).spec.hostnames)
    "grafana/0"          = one(yamldecode(file("${local.cloudflare_routes_dir}/grafana.yaml")).spec.hostnames)
    "harbor/0"           = one(yamldecode(file("${local.cloudflare_routes_dir}/harbor.yaml")).spec.hostnames)
    "mazanoke/0"         = one(yamldecode(file("${local.cloudflare_routes_dir}/mazanoke.yaml")).spec.hostnames)
    "personal-website/0" = yamldecode(file("${local.cloudflare_routes_dir}/personal-website.yaml")).spec.hostnames[0]
    "personal-website/1" = yamldecode(file("${local.cloudflare_routes_dir}/personal-website.yaml")).spec.hostnames[1]
    "searxng/0"          = one(yamldecode(file("${local.cloudflare_routes_dir}/searxng.yaml")).spec.hostnames)
  }
}

# ============================================================
# CrowdSec bouncer token
# ============================================================

# https://docs.crowdsec.net/u/bouncers/cloudflare/#cloudflare-api-token
resource "cloudflare_api_token" "crowdsec_bouncer" {
  provider = cloudflare.token_manager
  name     = "h8s-crowdsec-bouncer"
  policies = [
    {
      effect = "allow"
      permission_groups = [
        { id = "28f4b596e7d643029c524985477ae49a" }, # Workers Routes Write
        { id = "c8fed203ed3043cba015a93ad1616f1f" }, # Zone Read
        { id = "82e64a83756745bbbb1c9c2701bf816b" }, # DNS Read
      ]
      resources = jsonencode({ "com.cloudflare.api.account.zone.${local.cloudflare_zone_id}" = "*" })
    },
    {
      effect = "allow"
      permission_groups = [
        { id = "c1fde68c7bcc44588cbb6ddbc16d6480" }, # Account Settings Read
        { id = "755c05aa014b4f9ab263aa80b8167bd8" }, # Turnstile Sites Write
        { id = "f7f0eda5697f475c90846e879bab8666" }, # Workers KV Storage Write
        { id = "e086da7e2179491d91ee5f35b3ca210a" }, # Workers Scripts Write
        { id = "b89a480218d04ceb98b4fe57ca29dc1f" }, # Account Analytics Read
      ]
      resources = jsonencode({ "com.cloudflare.api.account.${local.cloudflare_account_id}" = "*" })
    },
    {
      effect            = "allow"
      permission_groups = [{ id = "8acbe5bb0d54464ab867149d7f7cf8ac" }] # User Details Read
      resources         = jsonencode({ "com.cloudflare.api.user.${local.cloudflare_user_id}" = "*" })
    },
  ]
}

# ============================================================
# Tunnel
# ============================================================

resource "cloudflare_api_token" "tunnel_cloudflared" {
  provider = cloudflare.token_manager
  name     = "h8s-tunnel-cloudflared"
  policies = [{
    effect            = "allow"
    permission_groups = [{ id = "c07321b023e944ff818fec44d8203567" }] # Cloudflare Tunnel Write
    resources         = jsonencode({ "com.cloudflare.api.account.${local.cloudflare_account_id}" = "*" })
  }]
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "h8s_prod" {
  account_id = local.cloudflare_account_id
  config_src = "cloudflare"
  name       = "h8s_prod"
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "h8s_prod" {
  provider   = cloudflare.tunnel_connector
  account_id = local.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.h8s_prod.id

  # On a fresh install, wait for the management token before requesting the connector token.
  depends_on = [cloudflare_api_token.tunnel_cloudflared]
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "h8s_prod" {
  account_id = local.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.h8s_prod.id
  source     = "cloudflare"
  config = {
    ingress = concat([
      for hostname in values(local.cloudflare_http_hosts) : {
        hostname = hostname
        service  = local.cloudflare_http_origin
      }
      ], [
      {
        hostname = "git-ssh.okwilkins.dev"
        service  = "ssh://forgejo-ssh.forgejo.svc.cluster.local:22"
      },
      {
        service = "http_status:404"
      },
    ])
  }
}

# ============================================================
# Vault
# ============================================================

locals {
  cloudflare_vault_tokens = {
    "cloudflare/cloudflared-token" = data.cloudflare_zero_trust_tunnel_cloudflared_token.h8s_prod.token
    "crowdsec/cloudflare-token"    = cloudflare_api_token.crowdsec_bouncer.value
  }
}

resource "terraform_data" "vault_cloudflare_token" {
  for_each         = toset([for path, _ in local.cloudflare_vault_tokens : path])
  triggers_replace = [sha256(local.cloudflare_vault_tokens[each.key])]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      INFRA_ROOT        = var.infra_root
      VAULT_SECRET_PATH = "kubernetes-homelab/${each.key}"
      TOKEN_VALUE       = sensitive(local.cloudflare_vault_tokens[each.key])
    }
    command = <<-EOT
      source "${var.infra_root}/scripts/common.sh"
      : "$${TOKEN_VALUE:?missing Cloudflare token for $VAULT_SECRET_PATH}"
      load_tf_kube_env
      VAULT_TOKEN="$(tofu -chdir="$INFRA_ROOT/06-vault-init" output -json vault_credentials | jq -er '.root_token')"
      printf '%s\n%s' "$VAULT_TOKEN" "$TOKEN_VALUE" | kubectl_wrapper exec -i -n vault vault-0 -- sh -ec '
        IFS= read -r VAULT_TOKEN
        export VAULT_TOKEN
        vault kv put "$1" token=- >/dev/null
      ' sh "$VAULT_SECRET_PATH"
    EOT
  }
}

# ============================================================
# DNS Records
# ============================================================

resource "cloudflare_dns_record" "http" {
  for_each = local.cloudflare_http_hosts

  zone_id = local.cloudflare_zone_id
  name    = each.value
  type    = "CNAME"
  content = local.cloudflare_tunnel_hostname
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "git_ssh" {
  zone_id = local.cloudflare_zone_id
  name    = "git-ssh.okwilkins.dev"
  type    = "CNAME"
  content = local.cloudflare_tunnel_hostname
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "mx_eforward1" {
  zone_id  = local.cloudflare_zone_id
  name     = "okwilkins.dev"
  type     = "MX"
  content  = "eforward1.registrar-servers.com"
  priority = 10
  proxied  = false
  ttl      = 1
}

resource "cloudflare_dns_record" "mx_eforward2" {
  zone_id  = local.cloudflare_zone_id
  name     = "okwilkins.dev"
  type     = "MX"
  content  = "eforward2.registrar-servers.com"
  priority = 10
  proxied  = false
  ttl      = 1
}

resource "cloudflare_dns_record" "mx_eforward3" {
  zone_id  = local.cloudflare_zone_id
  name     = "okwilkins.dev"
  type     = "MX"
  content  = "eforward3.registrar-servers.com"
  priority = 10
  proxied  = false
  ttl      = 1
}

resource "cloudflare_dns_record" "mx_eforward4" {
  zone_id  = local.cloudflare_zone_id
  name     = "okwilkins.dev"
  type     = "MX"
  content  = "eforward4.registrar-servers.com"
  priority = 15
  proxied  = false
  ttl      = 1
}

resource "cloudflare_dns_record" "mx_eforward5" {
  zone_id  = local.cloudflare_zone_id
  name     = "okwilkins.dev"
  type     = "MX"
  content  = "eforward5.registrar-servers.com"
  priority = 20
  proxied  = false
  ttl      = 1
}

# ============================================================
# Rulesets
# ============================================================

resource "cloudflare_ruleset" "http_ratelimit" {
  zone_id = local.cloudflare_zone_id
  kind    = "zone"
  name    = "default"
  phase   = "http_ratelimit"
  rules = [
    {
      action      = "block"
      description = "Limit excessive requests"
      enabled     = true
      expression  = "(http.request.uri.path wildcard r\"/*\")"
      ratelimit = {
        characteristics     = ["ip.src", "cf.colo.id"]
        mitigation_timeout  = 10
        period              = 10
        requests_per_period = 100
        requests_to_origin  = false
      }
      ref = "limit_excessive_requests"
    },
  ]
}

resource "cloudflare_ruleset" "http_request_firewall_custom" {
  zone_id = local.cloudflare_zone_id
  kind    = "zone"
  name    = "default"
  phase   = "http_request_firewall_custom"
  rules = [
    {
      action      = "managed_challenge"
      description = "Ban Bots Looking at .env"
      enabled     = true
      expression  = "(http.request.uri wildcard r\"/.env*\") or (http.request.uri wildcard r\"*/.env\")"
      ref         = "challenge_env_scanners"
    },
  ]
}
