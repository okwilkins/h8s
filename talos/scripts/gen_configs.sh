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
    talos-homelab \
    https://$NODE_2_IP:6443

talosctl config endpoint \
    $NODE_1_IP $NODE_2_IP \
    --talosconfig $XDG_CONFIG_HOME/talos/talosconfig

talosctl config nodes \
    $NODE_1_IP $NODE_2_IP \
    --talosconfig $XDG_CONFIG_HOME/talos/talosconfig
