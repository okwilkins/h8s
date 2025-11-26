# H8s (Homernetes)

H8s is a home infrastructure project that combines the power of Kubernetes with the security-first approach of Talos OS.
This project provides a my setup, designed specifically for home labs and personal cloud environments.

This cluster uses 2 N100 CPU-based mini PCs, both retrofitted with 32GB of RAM and 1TB of NVME SSDs. They are happily tucked away under my TV `:)`.

## Motivations

Doing a homelab Kubernetes cluster has been a source of a lot of joy for me personally. I got these mini PCs as I wanted to learn as much as possible when it came to:
- Best DevOps and SWE practices.
- Sharpen my Kubernetes skills (at work I heavily use Kubernetes).
- Bring some of the stack back back within my control.
- Self-host things that I find useful.

Most importantly: ***I find it fun!*** It keeps me excited and hungry at work and on my other personal projects.

## Features
- Container registry.
- Home-wide ad blocker and DNS.
- Internal certificate authority.
- Routing to private services only accessible at home.
- Secrets management.
- Metric and log observability.
- Full CI/CD capabilities.
- Internet access to services via Cloudflare. Give these a try:
    - [Excalidraw](https://draw.okwilkins.dev)
    - [Grafana](https://grafana.okwilkins.dev)
    - [Harbor](https://harbor.okwilkins.dev), you can pull from the `main` project here.
- Postgres databases for internal services like Terraform and Harbor.
- Full network encryption, observability, IPAM, kube-proxy replacement and L2 annoucements with Cilium.

## Repo Structure

```text
├── applications
│   └── excalidraw                  | Self-hosted Excalidraw.
├── ci-cd
│   ├── argo-workflows              | CI/CD pipelines (WIP).
│   └── argocd                      | GitOps CD for Kubernetes resources.
├── images
│   ├── coredns
│   ├── terraform
│   └── image-buildah
├── infrastructure
│   ├── talos                       | Scripts and definintions for Talos running on Proxmox.
│   └── terraform                   | Terraform for internal infrastructure.
├── namespaces                      | Holds all namespaces for the cluster.
├── networking
│   ├── cert-manager                | Certificate controller for the self-hosted certificate authority.
│   ├── cilium                      | The cluster's eBPF CNI.
│   ├── cloudflared                 | Allows Cloudflare to ingress internet traffic in.
│   ├── coredns                     | Home-wide DNS services and ad-blocking.
│   └── gateways                    | Ingress and networking routing management.
├── observability
│   ├── grafana                     | Metrics and log observability.
│   ├── loki                        | Log collection.
│   ├── prometheus                  | Metrics collection.
│   └── promtail                    | Log transport agent. 
├── security
│   ├── cosign                      | Secrets to sign containers and binaries going to Harbor.
│   ├── external-secrets-operator   | Takes secrets hosted internally with Vault and manages them inside the cluster.
│   ├── keycloak                    | (WIP) Cluster SSO.
│   └── vault                       | Secrets storage and certificate authority. 
├── storage
    ├── cloudnative-pg              | PostrgreSQL database management for various Applications.
    ├── harbor                      | Container and binary registry.
    └── longhorn                    | Cluster CSI.
```

## Getting Started

### CLI Tools

This repo uses [Nix Flakes](https://nixos.wiki/wiki/flakes) to install all dependencies to run all commands and scripts. To get started:

1. Enable experimental-features. Read the Nix Flakes wiki for more information.
2. Run the following to drop into a shell with all dependencies:

```bash
nix shell
```

### Taskfile

The `Taskfile.yaml` is used for useful commands orchestration. To get a list of available functionality, within any directory of this repo run:

```bash
task
```
