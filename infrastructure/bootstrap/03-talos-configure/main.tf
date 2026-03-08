# ============================================================
# Dependencies
# ============================================================
# For this step to run, the previous step will have had to provisioned the VMs and be pingable.
resource "terraform_data" "wait_for_nodes" {
  for_each = var.nodes

  provisioner "local-exec" {
    command = "for i in {1..30}; do if nc -z ${each.value.ip_address} 50000; then exit 0; fi; sleep 10; done; exit 1"
  }
}

# ============================================================
# Cluster Secrets
# ============================================================
# Generates the cluster PKI (CA certs, keys, tokens) once and persists them
# in local state. This replaces the `talosctl gen secrets` call in gen_configs.sh.
#
# WARNING: terraform.tfstate contains these secrets. Treat it like secret.yaml -
# back it up to encrypted storage and never commit it to git.

resource "talos_machine_secrets" "this" {}

# ============================================================
# Per-Node Machine Configurations
# ============================================================
# Generates the full machine config for each node, equivalent to the
# `talosctl gen config --output-types controlplane` calls in gen_configs.sh.
#
# All patches are inlined as config_patches so all configuration lives in one place.

locals {
  # Extract the numeric suffix from the node name for use in hostname patch.
  # "controlplane-worker-2" -> "2"
  node_numbers = {
    for name, node in var.nodes :
    name => regex("(\\d+)$", name)[0]
  }
}

data "talos_machine_configuration" "nodes" {
  for_each = var.nodes

  cluster_name       = var.talos_cluster_name
  machine_type       = "controlplane"
  cluster_endpoint   = "https://${var.talos_cluster_vip}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = null # use the version bundled with talos_version

  config_patches = [
    # Hostname per node
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      hostname   = each.key
      auto       = "off"
    }),

    # Per-node identity - hostname, install image, VIP on ens18.
    yamlencode({
      machine = {
        install = {
          disk  = "/dev/vda"
          wipe  = true
          image = "factory.talos.dev/installer/${data.terraform_remote_state.talos_factory.outputs.schematic_id}:${var.talos_version}"
        }
        network = {
          nameservers = ["1.1.1.1", "1.0.0.1", "8.8.8.8", "8.8.4.4"]
          interfaces = [
            {
              interface = "ens18"
              dhcp      = true
              vip = {
                ip = var.talos_cluster_vip
              }
            }
          ]
        }
      }
    }),

    # Machine-level features - KubePrism + Longhorn bind mount.
    yamlencode({
      machine = {
        features = {
          kubePrism = {
            enabled = true
            port    = 7445
          }
        }
        kubelet = {
          extraMounts = [
            {
              destination = "/var/lib/longhorn"
              type        = "bind"
              source      = "/var/lib/longhorn"
              options     = ["bind", "rshared", "rw"]
            }
          ]
        }
      }
    }),

    # Cluster-level settings - Cilium CNI, no kube-proxy, VIP endpoint.
    yamlencode({
      cluster = {
        allowSchedulingOnControlPlanes = true
        network = {
          cni = {
            name = "none"
          }
        }
        proxy = {
          disabled = true
        }
        coreDNS = {
          disabled = false
        }
        controlPlane = {
          endpoint = "https://${var.talos_cluster_vip}:6443"
        }
      }
    }),
  ]
}

# ============================================================
# Apply Configurations to Nodes
# ============================================================
# Pushes the generated machine config to each node over the Talos API.
# Replaces apply_configs.sh. On a fresh node (maintenance mode) Talos
# requires --insecure; the provider handles this automatically when the
# node is not yet part of a cluster.
#
# endpoint = each node's own IP because fresh nodes are not yet in a cluster,
# so we cannot route through another node's API. See:
# https://github.com/siderolabs/terraform-provider-talos/issues/199

resource "talos_machine_configuration_apply" "nodes" {
  for_each = var.nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.nodes[each.key].machine_configuration

  # For a fresh (maintenance-mode) node, endpoint must be the node's own IP
  node     = each.value.ip_address
  endpoint = each.value.ip_address

  # On destroy, reset the node to maintenance mode so it can be re-bootstrapped
  on_destroy = {
    graceful = true
    reset    = true
    reboot   = true
  }

  depends_on = [terraform_data.wait_for_nodes]
}

# ============================================================
# Bootstrap etcd
# ============================================================
# Triggers etcd bootstrap on the first controlplane node. This only needs to
# happen once - Talos detects an already-bootstrapped cluster and is idempotent.
# Replaces the manual `talosctl bootstrap` step.

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_node_ip
  endpoint             = local.first_node_ip

  # All nodes must have their configs applied before etcd can bootstrap
  depends_on = [talos_machine_configuration_apply.nodes]
}

# ============================================================
# Kubeconfig
# ============================================================
# Retrieves the kubeconfig once the cluster is up. Replaces `talosctl kubeconfig`.

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_node_ip
  endpoint             = local.first_node_ip

  depends_on = [talos_machine_bootstrap.this]
}

# ============================================================
# Talos Client Configuration Data Source
# ============================================================
# Generates the talosconfig for use with talosctl.

data "talos_client_configuration" "this" {
  cluster_name         = var.talos_cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for name, node in var.nodes : node.ip_address]
  nodes                = [for name, node in var.nodes : node.ip_address]
}

# ============================================================
# Write Secrets to Files
# ============================================================
# Writes talosconfig and kubeconfig to the secrets/ directory for safekeeping.
# These files contain sensitive credentials and should never be committed to git.

resource "local_file" "talosconfig" {
  content  = data.talos_client_configuration.this.talos_config
  filename = "${path.module}/secrets/talosconfig.yaml"
}

resource "local_file" "kubeconfig" {
  content  = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = "${path.module}/secrets/kubeconfig.yaml"
}

# ============================================================
# Merge Kubeconfig into ~/.kube/config
# ============================================================
# Merges the generated kubeconfig into the user's default kubeconfig location.
# This allows kubectl to work without specifying --kubeconfig explicitly.

resource "null_resource" "kubeconfig_merge" {
  triggers = {
    kubeconfig = talos_cluster_kubeconfig.this.kubeconfig_raw
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Create ~/.kube if it doesn't exist
      mkdir -p ~/.kube
      
      # Write the new kubeconfig to a temp file
      cat > /tmp/new_kubeconfig.yaml << 'EOF'
      ${talos_cluster_kubeconfig.this.kubeconfig_raw}
      EOF
      
      # Extract cluster and context names from new config
      NEW_CLUSTER=$(grep -A1 "^clusters:" /tmp/new_kubeconfig.yaml | grep "name:" | awk '{print $2}')
      NEW_CONTEXT=$(grep -A1 "^contexts:" /tmp/new_kubeconfig.yaml | grep "name:" | awk '{print $2}')
      
      # If ~/.kube/config exists, remove old cluster/context first, then merge
      if [ -f ~/.kube/config ]; then
        # Delete old cluster and context if they exist (to avoid cert mismatch)
        kubectl config delete-cluster "$NEW_CLUSTER" 2>/dev/null || true
        kubectl config delete-context "$NEW_CONTEXT" 2>/dev/null || true
        
        # Now merge: new config takes precedence
        KUBECONFIG=/tmp/new_kubeconfig.yaml:~/.kube/config kubectl config view --flatten > /tmp/merged_kubeconfig.yaml
        mv /tmp/merged_kubeconfig.yaml ~/.kube/config
      else
        cp /tmp/new_kubeconfig.yaml ~/.kube/config
      fi
      
      # Cleanup
      rm -f /tmp/new_kubeconfig.yaml /tmp/merged_kubeconfig.yaml
    EOT
  }

  depends_on = [talos_cluster_kubeconfig.this]
}
