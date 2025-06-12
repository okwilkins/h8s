######################
# Kubernetes Secrets #
######################
data "kubernetes_secret" "harbor_admin_secret" {
  metadata {
    name      = "harbor-admin-credentials"
    namespace = "harbor"
  }
}

data "kubernetes_secret" "harbor_dagger_robot_secret" {
  metadata {
    name      = "harbor-dagger-robot-secret"
    namespace = "harbor"
  }
}

# Gateway route
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


############
# Projects #
############
resource "harbor_project" "main" {
  name                        = "main"
  deployment_security         = "high"
  enable_content_trust        = true
  enable_content_trust_cosign = true
  public                      = true
}


##############
# Registries #
##############
resource "harbor_registry" "docker" {
  provider_name = "docker-hub"
  name          = "docker"
  endpoint_url  = "https://registry-1.docker.io"
}

resource "harbor_registry" "quay" {
  provider_name = "quay"
  name          = "quay"
  endpoint_url  = "https://quay.io"
}

resource "harbor_registry" "ghcr" {
  provider_name = "github"
  name          = "ghcr"
  endpoint_url  = "https://ghcr.io"
}


##################
# Robot Accounts #
##################
resource "harbor_robot_account" "terraform" {
  name        = "dagger"
  description = "robot for dagger to perform ci-cd operations"
  level       = "project"
  secret      = data.kubernetes_secret.harbor_dagger_robot_secret.data.SECRET
  permissions {
    access {
      action   = "push"
      resource = "repository"
    }
    access {
      action   = "pull"
      resource = "repository"
    }
    kind      = "project"
    namespace = harbor_project.main.name
  }
}
