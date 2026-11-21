terraform {
  required_version = ">= 1.11"
}

# Generate drain credentials from the existing CA without depending on the
# post-bootstrap kubeconfig resource, which would create a dependency cycle.
ephemeral "talos_cluster_kubeconfig" "drain" {
  cluster_name    = var.talos_cluster_name
  machine_secrets = talos_machine_secrets.this.machine_secrets
  endpoint        = "https://${var.talos_cluster_vip}:6443"
}

locals {
  installer_image = "factory.talos.dev/metal-installer/${data.terraform_remote_state.talos_factory.outputs.schematic_id}:${var.talos_version}"
}

# Explicit dependencies stop the rollout if a node upgrade fails.
resource "talos_machine" "controlplane-worker-1" {
  client_configuration            = talos_machine_secrets.this.client_configuration
  machine_configuration           = data.talos_machine_configuration.nodes["controlplane-worker-1"].machine_configuration
  node                            = var.nodes["controlplane-worker-1"].ip_address
  endpoint                        = var.nodes["controlplane-worker-1"].ip_address
  image                           = local.installer_image
  kubeconfig_wo                   = ephemeral.talos_cluster_kubeconfig.drain.kubeconfig_raw
  drain_on_upgrade                = true
  drain_timeout                   = "30m"
  ignore_kubernetes_upgrade_drift = true

  on_destroy = {
    reset  = false
    reboot = false
  }

  timeouts = {
    create = "30m"
    update = "45m"
  }

  lifecycle {
    precondition {
      condition     = toset(keys(var.nodes)) == toset(["controlplane-worker-1", "controlplane-worker-2", "controlplane-worker-3"])
      error_message = "Update the Talos upgrade chain before changing the configured control-plane nodes."
    }
  }
}

resource "talos_machine" "controlplane-worker-2" {
  client_configuration            = talos_machine_secrets.this.client_configuration
  machine_configuration           = data.talos_machine_configuration.nodes["controlplane-worker-2"].machine_configuration
  node                            = var.nodes["controlplane-worker-2"].ip_address
  endpoint                        = var.nodes["controlplane-worker-2"].ip_address
  image                           = local.installer_image
  kubeconfig_wo                   = ephemeral.talos_cluster_kubeconfig.drain.kubeconfig_raw
  drain_on_upgrade                = true
  drain_timeout                   = "30m"
  ignore_kubernetes_upgrade_drift = true

  on_destroy = {
    reset  = false
    reboot = false
  }

  timeouts = {
    create = "30m"
    update = "45m"
  }

  depends_on = [talos_machine.controlplane-worker-1]
}

resource "talos_machine" "controlplane-worker-3" {
  client_configuration            = talos_machine_secrets.this.client_configuration
  machine_configuration           = data.talos_machine_configuration.nodes["controlplane-worker-3"].machine_configuration
  node                            = var.nodes["controlplane-worker-3"].ip_address
  endpoint                        = var.nodes["controlplane-worker-3"].ip_address
  image                           = local.installer_image
  kubeconfig_wo                   = ephemeral.talos_cluster_kubeconfig.drain.kubeconfig_raw
  drain_on_upgrade                = true
  drain_timeout                   = "30m"
  ignore_kubernetes_upgrade_drift = true

  on_destroy = {
    reset  = false
    reboot = false
  }

  timeouts = {
    create = "30m"
    update = "45m"
  }

  depends_on = [talos_machine.controlplane-worker-2]
}

moved {
  from = talos_machine.nodes["controlplane-worker-1"]
  to   = talos_machine.controlplane-worker-1
}

moved {
  from = talos_machine.nodes["controlplane-worker-2"]
  to   = talos_machine.controlplane-worker-2
}

moved {
  from = talos_machine.nodes["controlplane-worker-3"]
  to   = talos_machine.controlplane-worker-3
}

resource "talos_cluster" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_node_ip
  endpoint             = local.first_node_ip
  control_plane_nodes  = [for node in values(var.nodes) : node.ip_address]
  kubernetes_version   = var.kubernetes_version

  depends_on = [talos_machine.controlplane-worker-3]
}
