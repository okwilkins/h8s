# Cilium


## Installing

The settings for Cilium were carefully followed from the [Talos guide on depoying a Cilium CNI](https://www.talos.dev/v1.8/kubernetes-guides/network/deploying-cilium).
For other OSes/systems you will want to follow a different set of instuctions and Helm values!
The TalosOS cluster I setup doesn't use the standard kube-proxy also. Please bare this in mind when using the values here.
Also note that because of TalosOS' bareboned nature, the `SYS_MODULE` capability for the agents had to be tured off. This is because TalosOS does not have the relevent binaries and the deployment will break.

```bash
CLUSTER_ENV=prod

helm repo add cilium https://helm.cilium.io/
helm upgrade cilium cilium/cilium --version 1.16.3 \
    --install \
    --namespace kube-system \
    -f environments/$CLUSTER_ENV/values.yaml    
```

