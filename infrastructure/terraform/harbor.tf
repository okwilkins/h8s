data "kubernetes_secret" "harbor_admin_secret" {
  metadata {
    name      = "harbor-admin-credentials"
    namespace = "harbor"
  }
}

data "kubernetes_resource" "harbor_route" {
  api_version = "gateway.networking.k8s.io/v1"
  kind        = "HTTPRoute"
  metadata {
    name      = "harbor"
    namespace = "harbor"
  }
}

locals {
  harbor_hostname = data.kubernetes_resource.harbor_route.object.spec.hostnames[0]
  harbor_path     = data.kubernetes_resource.harbor_route.object.spec.rules[0].matches[0].path.value
  harbor_scheme   = "https"
  harbor_url      = "${local.harbor_scheme}://${local.harbor_hostname}${local.harbor_path}"
  harbor_user     = data.kubernetes_secret.harbor_admin_secret.data.HARBOR_ADMIN_USERNAME
  harbor_pass     = data.kubernetes_secret.harbor_admin_secret.data.HARBOR_ADMIN_PASSWORD
}

