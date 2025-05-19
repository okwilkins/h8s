# CoreDNS

[CoreDNS](https://coredns.io/) is a DNS server. It is written in Go. It can be used in a multitude of environments because of its flexibility.
CoreDNS integrates with Kubernetes via the Kubernetes plugin, or with etcd with the etcd plugin.

This also replaces the default [TalosOS](../talos/README.md) CoreDNS installation for flexibility of settings and GitOps with [ArgoCD](../argocd/README.md).

## Features

The deployments [found in base](./base/) include a CRON job that downloads [StevenBlack's hosts list](https://github.com/StevenBlack/hosts) daily. This acts as a ad and malware blocker.

## Installation

To begin the cluster from scratch, CoreDNS will need to be installed before ArgoCD. This is that it can properly function:

```bash
export CLUSTER_ENV=prod
kubectl apply -k environments/$CLUSTER_ENV
```

## Extra Information

Manifests were mainly derived from the TalosOS templates for CoreDNS. Find them [here](https://github.com/siderolabs/talos/blob/7aeb15f73094a23aea1d6b263ca2eca061c8a257/internal/app/machined/pkg/controllers/k8s/templates/core-dns-template.yaml).

