# External DNS

ExternalDNS synchronises exposed Kubernetes Services and Ingresses with DNS providers.

## Generating Secrets For ETCD

To allow External DNS to configure [CoreDNS](../coredns/README.md), it needs to connect to ETCD. To do this, 4 things are needed:

1. ETCD URLs: `talosctl etcd status | awk -F '\\s\\s' '{print $1}'`
2. ETCD CA: `talosctl read /etc/kubernetes/pki/ca.crt -n <NODE IP>`
3. ETCD Client CA Cert: `cat ~/.config/talos/controlplane-worker-1.yaml -p | yq ".machine.ca.crt" | base64 -d`
4. ETCD Client CA Key: `cat ~/.config/talos/controlplane-worker-1.yaml -p | yq ".machine.ca.key" | base64 -d`

Make sure these are [configured in the secret](./base/etcd-urls-secret.yaml).

