# H8s (Homernetes)

[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.36-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io) [![Talos Linux](https://img.shields.io/badge/Talos-v1.13.4-00A3E0?style=for-the-badge&logo=linux&logoColor=white)](https://www.talos.dev) [![Cilium](https://img.shields.io/badge/Cilium-1.19.1-F8C517?style=for-the-badge&logo=cilium&logoColor=black)](https://cilium.io) [![ArgoCD](https://img.shields.io/badge/ArgoCD-9.4.7-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)](https://argoproj.github.io/cd) [![Nix Flakes](https://img.shields.io/badge/Nix-Flakes-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](https://nixos.org) [![Stars](https://img.shields.io/github/stars/okwilkins/h8s?style=for-the-badge&logo=github&color=brightgreen)](https://github.com/okwilkins/h8s/stargazers)

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
- Automated Bootstrap: Fully declaritive pipeline for complete cluster provisioning from bare metal in under 10 mins.
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
│   ├── chhoto-url                  | Self-hosted URL shortener.
│   ├── excalidraw                  | Self-hosted Excalidraw.
│   ├── mazanoke                    | Browser-based image optimizer.
│   └── searxng                     | Privacy-focused metasearch engine.
├── ci-cd
│   ├── argo-workflows              | CI/CD pipelines (WIP).
│   ├── argocd                      | GitOps CD for Kubernetes resources.
│   └── renovate                    | Automated dependency updates.
├── images
│   ├── coredns
│   ├── image-buildah
│   └── terraform
├── infrastructure                  | 8-stage Terraform pipeline for cluster bootstrapping from bare metal via Proxmox and Talos + platform configuration.
├── namespaces                      | Holds all namespaces for the cluster.
├── networking
│   ├── cert-manager                | Certificate controller for the self-hosted certificate authority.
│   ├── cilium                      | The cluster's eBPF CNI.
│   ├── cloudflared                 | Allows Cloudflare to ingress internet traffic in.
│   ├── coredns                     | Home-wide DNS services and ad-blocking.
│   └── gateways                    | Ingress and networking routing management.
├── observability
│   ├── fluent-bit                  | Metrics/logs/traces collection, processing and forwarding.
│   ├── grafana                     | Metrics and log observability.
│   ├── prometheus                  | Metrics collection.
│   └── victoria-logs               | Log storage and query engine.
├── security
│   ├── authelia                    | Authentication and authorisation server with SSO and MFA.
│   ├── cosign                      | Secrets to sign containers and binaries going to Harbor.
│   ├── external-secrets-operator   | Syncs secrets from Vault into the cluster.
│   └── vault                       | Secrets storage and certificate authority.
└── storage
    ├── cloudnative-pg              | PostgreSQL database management for applications.
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
