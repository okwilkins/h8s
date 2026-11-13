######################
# Kubernetes Secrets #
######################
data "kubernetes_secret_v1" "harbor_admin_secret" {
  metadata {
    name      = "harbor-admin-credentials"
    namespace = "harbor"
  }
}

data "kubernetes_secret_v1" "harbor_argo_workflows_credentials" {
  metadata {
    name      = "harbor-argo-workflows-credentials"
    namespace = "argo-workflows"
  }
}

data "kubernetes_secret_v1" "harbor_image_pull_robot_secret" {
  metadata {
    name      = "harbor-image-pull-robot-secret"
    namespace = "harbor"
  }
}

data "kubernetes_secret_v1" "harbor_oidc_secret" {
  metadata {
    name      = "harbor-oidc"
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
  harbor_user     = data.kubernetes_secret_v1.harbor_admin_secret.data.HARBOR_ADMIN_USERNAME
  harbor_pass     = data.kubernetes_secret_v1.harbor_admin_secret.data.HARBOR_ADMIN_PASSWORD
}


############
# Projects #
############
resource "harbor_project" "main" {
  name                        = "main"
  deployment_security         = null # Disable vulnerability-based pull blocking
  vulnerability_scanning      = true
  public                      = true
  enable_content_trust_cosign = true
}

resource "harbor_project" "docker_cache" {
  name        = "docker-hub-cache"
  public      = "false"
  registry_id = harbor_registry.docker.registry_id
}

# resource "harbor_project" "quay_cache" {
#   name        = "quay-cache"
#   public      = "false"
#   registry_id = harbor_registry.quay.registry_id
# }

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

##################
# Authentication #
##################
resource "harbor_config_auth" "authelia" {
  auth_mode          = "oidc_auth"
  primary_auth_mode  = true
  oidc_name          = "Authelia"
  oidc_endpoint      = "https://auth.okwilkins.dev"
  oidc_client_id     = data.kubernetes_secret_v1.harbor_oidc_secret.data["client-id"]
  oidc_client_secret = data.kubernetes_secret_v1.harbor_oidc_secret.data["client-secret"]
  oidc_scope         = "openid,profile,email,groups,offline_access"
  oidc_verify_cert   = true
  oidc_auto_onboard  = true
  oidc_user_claim    = "preferred_username"
  oidc_groups_claim  = "groups"
  oidc_admin_group   = "admins"
}

##################
# Robot Accounts #
##################
resource "harbor_robot_account" "argo_workflows" {
  name        = "argo-workflows"
  description = "Dedicated image build and publishing account for Argo Workflows"
  level       = "system"
  secret      = data.kubernetes_secret_v1.harbor_argo_workflows_credentials.data.password

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
  permissions {
    access {
      action   = "pull"
      resource = "repository"
    }
    kind      = "project"
    namespace = harbor_project.docker_cache.name
  }

  lifecycle {
    postcondition {
      condition     = self.full_name == data.kubernetes_secret_v1.harbor_argo_workflows_credentials.data.username
      error_message = "The workflow credentials username must match the full Harbor robot name, including its prefix."
    }
  }
}

resource "harbor_robot_account" "image_pull" {
  name        = "image-pull"
  description = "robot account for general K8s image pulls from cache projects"
  level       = "system"
  secret      = data.kubernetes_secret_v1.harbor_image_pull_robot_secret.data.ROBOT_PASSWORD

  permissions {
    access {
      action   = "pull"
      resource = "repository"
    }
    kind      = "project"
    namespace = harbor_project.docker_cache.name
  }
  permissions {
    access {
      action   = "pull"
      resource = "repository"
    }
    kind      = "project"
    namespace = harbor_project.ghcr_cache.name
  }
}
