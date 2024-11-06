#!/bin/bash
# Applies pre-generated configs for Talos, controlplanes and workers

for var in XDG_CONFIG_HOME NODE_1_IP NODE_2_IP; do
    eval "value=\$$var"
    if [ -z "$value" ]; then
        echo "Please set your $var environment variable before running this!"
        exit 1
    fi
done

echo "Applying config for controlplane-worker-1..."
talosctl apply-config \
    --insecure \
    --nodes $NODE_1_IP \
    --endpoints $NODE_1_IP \
    --file $XDG_CONFIG_HOME/talos/controlplane-worker-1.yaml

echo "Applying config for controlplane-worker-2..."
talosctl apply-config \
    --insecure \
    --nodes $NODE_2_IP \
    --endpoints $NODE_2_IP \
    --file $XDG_CONFIG_HOME/talos/controlplane-worker-2.yaml

