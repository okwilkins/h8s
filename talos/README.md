# Talos

Talos Linux is a specialised operating system built specifically for running Kubernetes clusters. It's designed to be minimal, secure, and immutable, meaning the system files remain read-only and cannot be modified during runtime.


## Getting Started

### TalosOS ISOs

To generate the appropriate ISO for the system the [Talos Linux Image Factory can be used](https://factory.talos.dev/). This gives a nice UI to retrieve system-appropriate ISOs. Instead of using the UI, a schematic file is used:

```bash
curl -X POST \
    --data-binary @iso_factory_patch.yaml \
    https://factory.talos.dev/schematics
```

This will return:

```bash
{"id":"ed036d0640097a4e7af413ee089851a12963cd2e2e1715f8866d551d17c2ec62"}
```

This ID can then be used in each of the [machine config patches](./machine_patches):

```yaml
machine:
  install:
    image: factory.talos.dev/installer/ed036d0640097a4e7af413ee089851a12963cd2e2e1715f8866d551d17c2ec62:v1.8.2
```


### Initalising the Cluster

In my homelab I have two GMKtec G3s that each have an Intel N100 CPU, 32GB RAM and 1TB of NVME storage. With the ISOs loaded onto a computer, it will display its IP. You can also get this IP from the router.

Set your variables:

```bash
export NODE_1_IP=192.168.xxx.xxx
export NODE_2_IP=192.168.xxx.xxx
```

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

Wait for the nodes to automatically restart. Then run bootstrap the cluster with:

```bash
talosctl bootstrap \
    --nodes $NODE_1_IP \
    --endpoints $NODE_1_IP \
    --talosconfig $XDG_CONFIG_HOME/talos/talosconfig 
```

***NOTE:*** It doesn't matter which controlplane-worker we do this for. As both nodes are control planes, it doesn't matter which one is chosen to bootstrap.


You can generate your kubeconfig like so, it will be placed in your current working directory:

```bash
talosctl kubeconfig ./ \
    --nodes $NODE_1_IP,$NODE_2_IP \
    --endpoints $NODE_1_IP, $NODE_2_IP \
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

