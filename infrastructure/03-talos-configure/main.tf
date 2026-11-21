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
# in encrypted remote state. This replaces `talosctl gen secrets` in gen_configs.sh.
#
# WARNING: terraform.tfstate contains these secrets. Treat it like secret.yaml -
# back it up to encrypted storage and never commit it to git.

resource "talos_machine_secrets" "this" {}

# ============================================================
# Per-Node Machine Configurations
# ============================================================
# Generates the full machine config for each node, equivalent to the
# `talosctl gen config --output-types controlplane` calls in gen_configs.sh.

locals {
  # RuntimeDefault snapshot from Talos 1.14.3 / containerd 2.3.7, amd64, without capability expansions.
  seccomp_runtime_default = jsondecode(file("${path.module}/seccomp-containerd-2.3.7-amd64.json"))

  # Buildah's chroot isolation needs user/mount/UTS namespaces and mounts inside them.
  buildah_seccomp_profile = merge(local.seccomp_runtime_default, {
    syscalls = concat(local.seccomp_runtime_default.syscalls, [
      {
        names  = ["chroot", "mount", "pivot_root", "sethostname", "setns", "umount2"]
        action = "SCMP_ACT_ALLOW"
      },
      {
        names  = ["clone", "unshare"]
        action = "SCMP_ACT_ALLOW"
        args = [{
          index = 0
          # CLONE_NEWTIME | CLONE_NEWCGROUP | CLONE_NEWIPC | CLONE_NEWPID | CLONE_NEWNET.
          # Keep those blocked while permitting user/mount/UTS namespaces.
          value    = 1778385024
          valueTwo = 0
          op       = "SCMP_CMP_MASKED_EQ"
        }]
      },
    ])
  })

  # Extract the numeric suffix from the node name for use in hostname patch.
  # "controlplane-worker-2" -> "2"
  node_numbers = {
    for name, node in var.nodes :
    name => regex("(\\d+)$", name)[0]
  }

  tailscale_authkeys = {
    for name, node in var.nodes :
    name => trimspace(try(node.tailscale_authkey, ""))
  }

  tailscale_routes = {
    for name, node in var.nodes :
    name => try(node.tailscale_routes, [])
  }

  tailscale_exit_nodes = {
    for name, node in var.nodes :
    name => try(node.tailscale_exit_node, false)
  }
}

data "talos_machine_configuration" "nodes" {
  for_each = var.nodes

  cluster_name       = var.talos_cluster_name
  machine_type       = "controlplane"
  cluster_endpoint   = "https://${var.talos_cluster_vip}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = concat([
    # Hostname per node
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      hostname   = each.key
      auto       = "off"
    }),

    # Installer settings use the 1.14 document format.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "UnattendedInstallConfig"
      installer = {
        image = local.installer_image
      }
      provisioning = {
        diskSelector = { match = "disk.dev_path == '/dev/vda'" }
        wipe         = true
      }
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "ResolverConfig"
      nameservers = [
        for address in ["1.1.1.1", "1.0.0.1", "8.8.8.8", "8.8.4.4"] : { address = address }
      ]
    }),

    # Keep DHCP and the VIP. Advertise the LAN IP for etcd while listening on both networks.
    yamlencode({
      machine = {
        network = {
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
      cluster = {
        etcd = {
          advertisedSubnets = ["${each.value.ip_address}/32"]
          listenSubnets     = ["0.0.0.0/0"]
        }
      }
    }),

    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubePrismConfig"
      port       = 7445
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "SysctlConfig"
      params = {
        "net.ipv6.conf.all.forwarding" = "1"
        "user.max_user_namespaces"     = "256"
      }
    }),

    # KubeletConfig has no extraMounts field in 1.14. Retain the supported
    # legacy kubelet block so Longhorn keeps its existing bind mount.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeletConfig"
      "$patch"   = "delete"
    }),
    yamlencode({
      machine = {
        seccompProfiles = [
          {
            name  = "buildah.json"
            value = local.buildah_seccomp_profile
          }
        ]
        kubelet = {
          image                               = "ghcr.io/siderolabs/kubelet:${var.kubernetes_version}"
          defaultRuntimeSeccompProfileEnabled = true
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

    # Allow workloads on control-plane nodes and preserve node IP selection.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeNodeConfig"
      nodeIP = {
        validSubnets = var.node_ip_valid_subnets
      }
      taints = {
        "node-role.kubernetes.io/control-plane" = { "$patch" = "delete" }
      }
    }),
    # Cilium supplies the CNI instead of the generated Flannel deployment.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeFlannelCNIConfig"
      "$patch"   = "delete"
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeProxyConfig"
      enabled    = false
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeCoreDNSConfig"
      enabled    = true
      image      = "docker.io/coredns/coredns:1.15.0@sha256:0a9d8c8ddf34347eb59aad9a8784f0710de88d6d112726d11d271f9bc6daca26"
    }),
    # The generator already sets the cluster endpoint from cluster_endpoint.
    # Keep the authenticated metrics endpoints reachable by Prometheus.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeControllerManagerConfig"
      extraArgs = {
        "bind-address" = "0.0.0.0"
      }
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeSchedulerConfig"
      extraArgs = {
        "bind-address" = "0.0.0.0"
      }
    }),
    ], lookup(local.tailscale_authkeys, each.key, "") != "" ? [
    # Configure the optional Tailscale system extension when an auth key is supplied.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "ExtensionServiceConfig"
      name       = "tailscale"
      environment = concat([
        "TS_AUTHKEY=${local.tailscale_authkeys[each.key]}",
        "TS_HOSTNAME=${each.key}",
        # TS_AUTH_ONCE=false: re-run `tailscale up` on every container start so
        # changes to TS_ROUTES/TS_EXTRA_ARGS apply without re-provisioning.
        # Requires a reusable Tailscale auth key (single-use keys would fail after the first login).
        "TS_AUTH_ONCE=false",
        "TS_ACCEPT_DNS=${lower(tostring(var.tailscale_accept_dns))}",
        ], length(local.tailscale_routes[each.key]) > 0 ? [
        "TS_ROUTES=${join(",", local.tailscale_routes[each.key])}",
        ] : [], local.tailscale_exit_nodes[each.key] ? [
        "TS_EXTRA_ARGS=--advertise-exit-node",
      ] : [])
    })
    ] : [], each.value.longhorn_disk == null ? [] : [
    # Match only the optional data disk, never the Talos installation disk.
    # Talos propagates user-volume mounts into the kubelet container.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "UserVolumeConfig"
      name       = "longhorn-extra"
      provisioning = {
        diskSelector = {
          match = "disk.serial == 'longhorn-extra'"
        }
        minSize = "1GiB"
        grow    = true
      }
      filesystem = {
        type = "ext4"
      }
    })
  ])
}

# ============================================================
# Kubeconfig
# ============================================================
# Retrieves the kubeconfig once the cluster is up. Replaces `talosctl kubeconfig`.

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_node_ip
  endpoint             = local.first_node_ip
  depends_on           = [talos_cluster.this]
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
