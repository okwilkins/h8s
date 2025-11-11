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

data "kubernetes_secret" "main_user_secret" {
  metadata {
    name      = "harbor-main-user-secret"
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
  deployment_security         = "critical"
  public                      = true
  enable_content_trust_cosign = true
}

resource "harbor_project" "docker_cache" {
  name        = "docker-hub-cache"
  public      = "false"
  registry_id = harbor_registry.docker.registry_id
}

resource "harbor_project" "quay_cache" {
  name        = "quay-cache"
  public      = "false"
  registry_id = harbor_registry.quay.registry_id
}

resource "harbor_project" "ghcr_cache" {
  name        = "ghcr-cache"
  public      = "false"
  registry_id = harbor_registry.ghcr.registry_id
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

#########
# Users #
#########
resource "harbor_user" "main" {
  username  = "oli"
  password  = data.kubernetes_secret.main_user_secret.data.PASSWORD
  full_name = "Oliver Kenyon Wilkins"
  email     = "okwilkins@googlemail.com"
}

resource "harbor_project_member_user" "oli_docker_cache_member" {
  project_id = harbor_project.docker_cache.id
  user_name  = harbor_user.main.username
  role       = "developer"
}

resource "harbor_project_member_user" "oli_quay_cache_member" {
  project_id = harbor_project.quay_cache.id
  user_name  = harbor_user.main.username
  role       = "developer"
}

resource "harbor_project_member_user" "oli_ghcr_cache_member" {
  project_id = harbor_project.ghcr_cache.id
  user_name  = harbor_user.main.username
  role       = "developer"
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
    access {
      action   = "create"
      resource = "artifact"
    }
    access {
      action   = "read"
      resource = "artifact"
    }
    access {
      action   = "delete"
      resource = "artifact"
    }
    kind      = "project"
    namespace = harbor_project.main.name
  }
}
