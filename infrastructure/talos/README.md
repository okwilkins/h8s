# Talos

[Talos Linux](https://www.talos.dev/) is a specialised operating system built specifically for running Kubernetes clusters. It's designed to be minimal, secure, and immutable, meaning the system files remain read-only and cannot be modified during runtime.

[Proxmox VE](https://www.proxmox.com/en/) is used as the [hypervisor](https://en.wikipedia.org/wiki/Hypervisor) that runs Talos.

## Getting Started

### Initalising the Cluster

In my homelab I have two GMKtec G3s that each have an Intel N100 CPU, 32GB RAM and 1TB of NVME storage. With the ISOs loaded onto a computer, it will display its IP. You can also get this IP from the router.

Set your variables:

```bash
export NODE_1_IP=192.168.xxx.xxx
export NODE_2_IP=192.168.xxx.xxx
export NODE_X_IP=192.168.xxx.xxx
export VIP_IP=192.168.xxx.xxx
```

- Node `X` will be the IP of each of your nodes on your LAN.
- `VIP_IP` is the Virtual IP of all the controlplane nodes in the cluster. This means only one IP address is needed to access the cluster's controlplane. [Read more here](https://www.talos.dev/v1.10/talos-guides/network/vip).

Generate the Talos configs:
```bash
bash scripts/gen_configs.sh
```

***NOTE***: It is a good idea to save the configs generated from this script. This is because it contains certificates and keys to access the nodes!
This can be found at `$XDG_CONFIG_HOME/talos/secret.yaml`.

Apply the Talos configs:
```bash
bash scripts/apply_configs.sh
```

***WARNING***: You may need to edit the commands with the `--insecure` flag.

Wait for the nodes to automatically restart. Then run bootstrap the cluster with:

```bash
talosctl bootstrap \
    --nodes $NODE_1_IP \
    --endpoints $NODE_1_IP \
    --talosconfig $XDG_CONFIG_HOME/talos/talosconfig 
```

***NOTE:*** It doesn't matter which controlplane-worker we do this for. As both nodes are control planes, it doesn't matter which one is chosen to bootstrap.


You can generate your kubeconfig like so, it will be placed in your `$HOME/.kube` directory. **WARNING**: This will replace your current config!

```bash
talosctl kubeconfig $HOME/.kube/config \
    --nodes $NODE_1_IP \
    --endpoints $NODE_1_IP \
    --talosconfig $XDG_CONFIG_HOME/talos/talosconfig
```

Enjoy your cluster!


### Patching Nodes

There will be times where you will need to patch the underlying system itself. You can do this by applying patches, like in this example:

```bash
 talosctl patch mc \
    --patch @cluster_patches/patch_cilium.yaml \
    --patch @cluster_patches/patch_control_plane_scheduling.yaml \
    --nodes $NODE_1_IP \
    --endpoints $NODE_1_IP \
    --talosconfig $XDG_CONFIG_HOME/talos/talosconfig
```

#### ⚠️Node IP Swaps and Stateful Storage

**Potential Pitfall:** When regenerating or applying new Talos machine configurations, be cautious if you re-assign `NODE_1_IP` and `NODE_2_IP`. If these IP addresses are effectively swapped between your physical machines, it can disrupt stateful services, particularly Longhorn.

Longhorn associates specific storage (identified by a disk UUID on the physical disk at `/var/lib/longhorn/`) with a Kubernetes node name (e.g., `controlplane-worker-1`). If an IP swap causes the Kubernetes node name to point to a different physical machine (and thus different storage) than before, Longhorn will detect a "diskUUID doesn't match" error. This renders the Longhorn disks unusable and can halt your workloads.

### Saving Talos Nodes, Endpoints and Talosconfig Location

To save the need to manually (which can be tedious) apply the `nodes`, `endpoints` and `talosconfig` flags, you can run the following:

```bash
export TALOSCONFIG=$XDG_CONFIG_HOME/talos/talosconfig

talosctl config endpoint \
    $NODE_1_IP $NODE_2_IP \
    --talosconfig $XDG_CONFIG_HOME/talos/talosconfig

talosctl config nodes \
    $NODE_1_IP $NODE_2_IP \
    --talosconfig $XDG_CONFIG_HOME/talos/talosconfig
```

It is probably a good idea to save `TALOSCONFIG` to your shell's config also.

## Starting the Cluster From Scratch

There will be times where the entire cluster will need to be installed from scratch. There are two steps to get everything in the cluster:

1. Install Cilium as per the [README](../../networking/cilium/README.md).
2. Wait for Cilium to be installed then [install ArgoCD](../../ci-cd/argocd/README.md). This will install the rest of the cluster for you.
3. Review which secrets need to be added to [Vault](../../security/vault/README.md). Search the repo for `ExternalSecret` manifests for guidance.

