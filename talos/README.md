# Talos

This page will get you setup and running with TalosOS VMs running locally in VMWare.

## Getting Started

### TalosOS ISOs

To create the VMs within VMWare, go to the [TalosOS releases page](https://github.com/siderolabs/talos/releases) and download an ISO appropriate for your system.

### Installing the VMs

To begin with, create VMWare VMs. The naming can be arbitary but I created two VMs. One named `talos-control-plane-1` and the other `talos-worker-1`.
Once the VMs have booted up, get the IP Addresses of these from the main screen.

Set your variables:

```bash
TALOS_VER=1.8
CONTROL_PLANE_IP=192.168.xxx.xxx
WORKER_NODE_IP=192.168.xxx.xxx
```

Download the VMWare patch for Talos:

```bash
curl -fsSLO https://raw.githubusercontent.com/siderolabs/talos/master/website/content/v$TALOS_VER/talos-guides/install/virtualized-platforms/vmware/cp.patch.yaml \
    --output-dir talos
sed -i "s/<VIP>/$CONTROL_PLANE_IP/g" talos/cp.patch.yaml
```

Generate the Talos configs:
```bash
talosctl gen config talos-cluster https://$CONTROL_PLANE_IP:6443 \
    --config-patch-control-plane @talos/cp.patch.yaml \
    --output-dir $XDG_CONFIG_HOME/talos
```

Apply the Talos config to control plane VM:
```bash
talosctl apply-config --insecure --nodes $CONTROL_PLANE_IP \
    --file $XDG_CONFIG_HOME/talos/controlplane.yaml
```

Apply config to worker node(s):
```bash
talosctl apply-config --insecure --nodes $WORKER_NODE_IP \
    --file $XDG_CONFIG_HOME/talos/worker.yaml
```

After, wait for the VMs to automatically restart. Because of this, you may need to reset your IPs and config:

```bash
CONTROL_PLANE_IP=192.168.xxx.xxx
```

Once they restart, you will see in the control plane VM the following log:

```txt
"etcd is waiting to join the cluster, if this node is the first node in the cluster, please run `talosctl bootstrap` against one of the following IPs:
```

To bootstrap ETCD run:

```bash
talosctl bootstrap \
    -e $CONTROL_PLANE_IP \
    -n $CONTROL_PLANE_IP \
    --talosconfig $XDG_CONFIG_HOME/talos/talosconfig 
```

Add the following endpoints for your VMs to your Talos config with:

```bash
talosctl config endpoint $CONTROL_PLANE_IP \
    --talosconfig $XDG_CONFIG_HOME/talos/talosconfig

talosctl config node $CONTROL_PLANE_IP \
    --talosconfig $XDG_CONFIG_HOME/talos/talosconfig
```

The following will make a temp dir for the kubeconfig for your K8s cluster. **WARNING:** This will overwrite your pre-existing config. Use with caution!
```bash
TMP_DIR=$(mktemp -d)
talosctl kubeconfig $TMP_DIR \
    --talosconfig $XDG_CONFIG_HOME/talos/talosconfig
export KUBECONFIG=$KUBECONFIG:$HOME/.kube/config:$TMP_DIR/kubeconfig
kubectl config view --flatten > $HOME/.kube/config
```

Finally, inspect the config and ensure you have the correct IP.
