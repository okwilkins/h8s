# CoreDNS

CoreDNS is a DNS server. It is written in Go. It can be used in a multitude of environments because of its flexibility.
CoreDNS integrates with Kubernetes via the Kubernetes plugin, or with etcd with the etcd plugin.

This also replaces the default [TalosOS](../talos/README.md) CoreDNS installation for flexibility of settings and GitOps with [ArgoCD](../argocd/README.md).

