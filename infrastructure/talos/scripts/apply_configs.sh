#!/bin/bash
# Applies pre-generated configs for Talos, controlplanes and workers

set -e

FOUND_ANY=0

for var in $(compgen -v | grep -E '^NODE_[1-9]+_IP$'); do
    FOUND_ANY=1
    value="${!var}"
    if [ -z "$value" ]; then
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

for var in $(compgen -v | grep -E '^NODE_[1-9]+_IP$'); do
    node_num=${var//[^0-9]/}

    echo "Applying config for controlplane-worker-1..."
    talosctl apply-config \
        --nodes ${!var} \
        --endpoints ${!var} \
        --file $XDG_CONFIG_HOME/talos/controlplane_worker_${node_num}.yaml
done

