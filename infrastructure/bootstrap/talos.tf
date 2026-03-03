# ============================================================
# Image Factory - Schematic & URLs
# ============================================================
# Registers the customisation (extensions) with the Talos image factory and
# retrieves the resulting ISO and installer URLs. The schematic ID is stored
# in state, so it won't be re-fetched on every apply (unlike the old curl in
# gen_configs.sh).
#
# Extensions match infrastructure/talos/iso_factory_patch.yaml:
#   - siderolabs/qemu-guest-agent   (Proxmox VM integration)
#   - siderolabs/iscsi-tools        (Longhorn iSCSI support)
#   - siderolabs/util-linux-tools   (Longhorn util-linux support)

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = [
          "siderolabs/qemu-guest-agent",
          "siderolabs/iscsi-tools",
          "siderolabs/util-linux-tools",
        ]
      }
    }
  })
}

data "talos_image_factory_urls" "this" {
  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.this.id
  platform      = "metal"
  architecture  = "amd64"
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
# The three patch files from infrastructure/talos/machine_patches/ are inlined
# here as config_patches so all configuration lives in one place.

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

  cluster_name       = var.cluster_name
  machine_type       = "controlplane"
  cluster_endpoint   = "https://${var.cluster_vip}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = null # use the version bundled with talos_version

  config_patches = [
    # Patch 1: Per-node identity - hostname, install image, VIP on eth0.
    # Mirrors controlplane_worker_template.yaml with placeholders resolved.
    yamlencode({
      machine = {
        install = {
          image = "factory.talos.dev/installer/${talos_image_factory_schematic.this.id}:${var.talos_version}"
        }
        network = {
          hostname    = each.key
          nameservers = ["1.1.1.1", "1.0.0.1", "8.8.8.8", "8.8.4.4"]
          interfaces = [
            {
              interface = "eth0"
              dhcp      = true
              vip = {
                ip = var.cluster_vip
              }
            }
          ]
        }
      }
    }),

    # Patch 2: Machine-level features - KubePrism + Longhorn bind mount.
    # Mirrors machine_patches/machine_patch.yaml verbatim.
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

    # Patch 3: Cluster-level settings - Cilium CNI, no kube-proxy, VIP endpoint.
    # Mirrors cluster_patch.yaml with VIP placeholder resolved.
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
          endpoint = "https://${var.cluster_vip}:6443"
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

  depends_on = [proxmox_virtual_environment_vm.nodes]
}

# ============================================================
# Bootstrap etcd
# ============================================================
# Triggers etcd bootstrap on the first controlplane node. This only needs to
# happen once - Talos detects an already-bootstrapped cluster and is idempotent.
# Replaces the manual `talosctl bootstrap` step.

locals {
  # Stable first node: sort by name and take the first entry
  first_node_name = tolist(sort(keys(var.nodes)))[0]
  first_node_ip   = var.nodes[local.first_node_name].ip_address
}

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
