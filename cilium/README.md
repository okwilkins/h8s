# Cilium

Cilium is an open source, cloud native solution for providing, securing, and observing network connectivity between workloads, fueled by the revolutionary Kernel technology eBPF.

## Installing

Installation is handled by the TalosOS itself on boot. The manifests for Cilium are generated within the script that [generates the Talos machine configs](../talos/scripts/gen_configs.sh). To update the version of Cilium or anything to the `values.yaml`, change the version within that script, apply the configs to Talos and then reboot.

The settings for Cilium were carefully followed from the [Talos guide on deploying a Cilium CNI](https://www.talos.dev/v1.8/kubernetes-guides/network/deploying-cilium).
For other OSes/systems you will want to follow a different set of instructions and Helm values!
The TalosOS cluster I setup doesn't use the standard kube-proxy also. Please bare this in mind when using the values here.
Also note that because of TalosOS' bareboned nature, the `SYS_MODULE` capability for the agents had to be tured off. This is because TalosOS does not have the relevant binaries and the deployment will break.
