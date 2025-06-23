#!/bin/bash
# Generates the configs for Talos, controlplanes and workers

set -e

FOUND_ANY=0

for var in $(compgen -v | grep -E '^NODE_[1-9]+_IP$'); do
    FOUND_ANY=1
    value="${!var}"
    if [ -z ${value+x} ]; then
        echo "Warning: $var is set but empty! Exiting..."
        exit 1
    else
        echo "$var is set to $value"
    fi
done

if [ $FOUND_ANY -eq 0 ]; then
    echo "No NODE_X_IP environment variables are set! Exiting..."
    exit 0
fi

if [ -z ${VIP_IP+x} ]; then
    echo "Virtual IP (VIP_IP) is not set Exiting..."
    exit 1
else
    echo "Virtual IP (VIP_IP) is set to ${VIP_IP}"
fi

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

TALOS_VER="v1.10.3"
schematic_id=$(curl -s -X POST \
    --data-binary @iso_factory_patch.yaml \
    https://factory.talos.dev/schematics | jq -r '.id')

for var in $(compgen -v | grep -E '^NODE_[1-9]+_IP$'); do
    node_num=${var//[^0-9]/}
    echo "Generating config for controlplane-worker-${node_num}..."
    
    talosctl gen config \
        --with-secrets "$TALOS_SECRET_FILE" \
        --output-types controlplane \
        -o "$XDG_CONFIG_HOME/talos/controlplane_worker_${node_num}.yaml" \
        --force \
        --config-patch @<(sed "s/__NODE_NUMBER__/${node_num}/g; s/__SCHEMATIC_ID__/${schematic_id}/g; s/__TALOS_VER__/${TALOS_VER}/g; s/__VIP_IP__/${VIP_IP}/g;" machine_patches/controlplane_worker_template.yaml) \
        --config-patch @machine_patches/machine_patch.yaml \
        --config-patch @<(sed "s/__VIP_IP__/${VIP_IP}/g;" cluster_patch.yaml) \
        talos-homelab \
        "https://${!var}:6443"
done

controlplane_ips=()
for var in $(compgen -v | grep -E '^NODE_[1-9]+_IP$'); do
    controlplane_ips+=("${!var}")  # Resolve variable value
done

talosctl config endpoint "${controlplane_ips[@]}" \
    --talosconfig "$XDG_CONFIG_HOME/talos/talosconfig"

talosctl config nodes "${controlplane_ips[@]}" \
    --talosconfig "$XDG_CONFIG_HOME/talos/talosconfig"

