#!/bin/bash
# Generates the configs for Talos, controlplanes and workers

set -e

for var in XDG_CONFIG_HOME NODE_1_IP NODE_2_IP; do
    eval "value=\$$var"
    if [ -z "$value" ]; then
        echo "Please set your $var environment variable before running this!"
        exit 1
    fi
done

TALOS_SECRET_FILE=$XDG_CONFIG_HOME/talos/secret.yaml

if [ ! -f $TALOS_SECRET_FILE ]; then
    echo "Talos secrets not found! Generating them in: ${TALOS_SECRET_FILE}"
    talosctl gen secrets -o $TALOS_SECRET_FILE    
else
    echo "Talos secrets already exists (${TALOS_SECRET_FILE}), skipping..."
fi


# Generate the Cilium manifests here so that when the cluster starts it can network via Cilium's CNI
# Also gen here so that sensitive keys are not committed  to a repo
CILIUM_VER="1.16.3"
echo "Generating Cilium version $CILIUM_VER manifests..."
helm repo add cilium https://helm.cilium.io/
export CILIUM_MANIFEST=$(
    helm template cilium cilium/cilium \
        --version $CILIUM_VER \
        --namespace kube-system \
        -f ../cilium/environments/prod/values.yaml
)

TMP_FILE=$(mktemp /tmp/cilium_patch.XXXXXX)
yq --null-input '.cluster.inlineManifests = [{"name": "cilium", "contents": env(CILIUM_MANIFEST)}]' | \
    # For some reason YQ's literal style doesn't work so using sed to put in the pipe char...?
    sed 's/contents:\([[:space:]]*\)/contents: |/' > $TMP_FILE

echo "Generating talosconfig..."
talosctl gen config \
    --with-secrets $TALOS_SECRET_FILE \
    --output-types talosconfig \
    -o $XDG_CONFIG_HOME/talos/talosconfig \
    --force \
    talos-homelab \
    https://$NODE_1_IP:6443

echo "Generating config for controlplane-worker-1..."
talosctl gen config \
    --with-secrets $TALOS_SECRET_FILE \
    --output-types controlplane \
    -o $XDG_CONFIG_HOME/talos/controlplane_worker_1.yaml \
    --force \
    --config-patch @machine_patches/controlplane_worker_1.yaml \
    --config-patch @machine_patches/machine_patch.yaml \
    --config-patch @cluster_patch.yaml \
    --config-patch @$TMP_FILE \
    talos-homelab \
    https://$NODE_1_IP:6443

echo "Generating config for controlplane-worker-2..."
talosctl gen config \
    --with-secrets $TALOS_SECRET_FILE \
    --output-types controlplane \
    -o $XDG_CONFIG_HOME/talos/controlplane_worker_2.yaml \
    --force \
    --config-patch @machine_patches/controlplane_worker_2.yaml \
    --config-patch @machine_patches/machine_patch.yaml \
    --config-patch @cluster_patch.yaml \
    --config-patch @$TMP_FILE \
    talos-homelab \
    https://$NODE_2_IP:6443

rm $TMP_FILE

talosctl config endpoint \
    $NODE_1_IP $NODE_2_IP \
    --talosconfig $XDG_CONFIG_HOME/talos/talosconfig

talosctl config nodes \
    $NODE_1_IP $NODE_2_IP \
    --talosconfig $XDG_CONFIG_HOME/talos/talosconfig
