# External DNS

ExternalDNS synchronises exposed Kubernetes Services and Ingresses with DNS providers.

## Generating Secrets For ETCD

To allow External DNS to configure [CoreDNS](../coredns/README.md), it needs to connect to ETCD. To do this, 4 things are needed:

```bash
export NODE_IP=$(talosctl etcd status | awk -F '\\s\\s' '{print $1}' | awk 'NR==2')

# ETCD URL
echo "https://$NODE_IP:2379"

# ETCD CA
talosctl get etcdrootsecret -o yaml | yq 'select(.node == env(NODE_IP)) | .spec.etcdCA.crt' | base64 -d

# ETCD CRT
talosctl get etcdsecret -o yaml | yq 'select(.node == env(NODE_IP)) | .spec.etcd.crt' | base64 -d

# ETCD KEY
talosctl get etcdsecret -o yaml | yq 'select(.node == env(NODE_IP)) | .spec.etcd.key' | base64 -d
```

Make sure these are [configured in the secret](./base/etcd-secret.yaml).

