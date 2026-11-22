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
# Tunnel
# ============================================================

resource "cloudflare_zero_trust_tunnel_cloudflared" "h8s_prod" {
  account_id = local.cloudflare_account_id
  config_src = "cloudflare"
  name       = "h8s_prod"
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
