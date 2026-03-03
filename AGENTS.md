# AGENTS.md - H8s Development Guide

This repository is H8s (Homernetes), a home Kubernetes infrastructure project using Talos OS.

## Project Overview

This is a **Kubernetes infrastructure-as-code repository** containing:
- Kubernetes manifests (YAML) for cluster configuration
- Kustomize overlays for environment-specific configurations
- Containerfiles/Dockerfiles for custom images
- Nix flake for development environment
- Taskfile for build automation

## Internet Usage is Key

It is **extremely** important that you use the internet. Kubernetes projects change frequently and you will likely implement the wrong thing if you do not utilise it.

## Build Commands

### Development Environment
```bash
# Enter shell with all dependencies (Nix flakes required)
nix shell

# List available tasks
task
```

### Kubernetes Operations

```bash
# Apply configurations (from nix shell)
kubectl apply -k <directory>

# Apply specific file
kubectl apply -f <file.yaml>

# Dry-run to validate
kubectl apply -k <directory> --dry-run=server
```

## Testing

There are no traditional unit tests in this repository. Validation is done via:
- `kubectl --dry-run=server` - Server-side validation
- Kustomize build validation: `kubectl kustomize <directory>`
- Container build validation: Ensure Containerfile/Dockerfile builds successfully

## Code Style Guidelines

### YAML/Kubernetes Manifests

**File Organization:**
- Use Kustomize for environment-specific configurations
- Structure: `base/` for common resources, `environments/<env>/` for overrides
- Each component should have its own directory with `kustomization.yaml`

**Naming Conventions:**
- Files: kebab-case (e.g., `deployment.yaml`, `corefile-configmap.yaml`)
- Resources: kebab-case matching file names
- Namespaces: lowercase with hyphens (e.g., `coredns-lan`, `monitoring`)

**Required Fields:**
```yaml
apiVersion: <api-group>/v1  # Always specify apiVersion
kind: <ResourceType>         # Required
metadata:
  name: <resource-name>      # Required
  namespace: <namespace>     # Required for namespaced resources
  labels:                    # Always include app/component labels
    app.kubernetes.io/name: <name>
    app.kubernetes.io/part-of: <app>
```

**Best Practices:**
- Always set `imagePullPolicy: IfNotPresent` or `Always`
- Include resource limits and requests for all containers
- Use security contexts: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`
- Define liveness and readiness probes
- Use pod anti-affinity for high availability

### Secrets Handling

- Store secrets in `environments/prod/secrets/` directory
- Use External Secrets Operator to sync from Vault
- Never commit plain secrets; use SealedSecrets or ESO
- Base64 encode secret values in YAML

### GitOps/ArgoCD

**IMPORTANT**: Remember that if you are applying files locally, that there is a strong chance that ArgoCD will "heal" the manifests back.
When wanting to do this, prompt the user to git commit and push. Never Git commit yourself.

- Applications defined in `ci-cd/argocd/environments/prod/apps/`
- Use Helm charts where possible for upstream resources
- Override values via `values.yaml` in environment overlays

### Container Images

**Dockerfile/Containerfile Conventions:**
- Use specific tags, never `latest` in production
- Multi-stage builds to minimize size
- Run as non-root user
- Include health checks where applicable

**Image Publishing:**
- Images pushed to Harbor (`harbor.okwilkins.dev`)
- Use Cosign for signing
- Use multi-arch builds (linux/amd64, linux/arm64)

## Directory Structure

```text
├── applications
│   ├── excalidraw                  | Self-hosted Excalidraw.
│   └── searxng                     | Privacy-focused metasearch engine.
├── ci-cd
│   ├── argo-workflows              | CI/CD pipelines (WIP).
│   ├── argocd                      | GitOps CD for Kubernetes resources.
│   └── renovate                    | Automated dependency updates.
├── images
│   ├── coredns
│   ├── terraform
│   └── image-buildah
├── infrastructure
│   ├── bootstrap                   | Cluster bootstrap configuration.
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
│   └── promtail                    | Log collection and shipping agent.
├── security
│   ├── cosign                      | Secrets to sign containers and binaries going to Harbor.
│   ├── external-secrets-operator   | Takes secrets hosted internally with Vault and manages them inside the cluster.
│   ├── keycloak                    | (WIP) Cluster SSO.
│   └── vault                       | Secrets storage and certificate authority.
└── storage
    ├── cloudnative-pg              | PostrgreSQL database management for various Applications.
    ├── harbor                      | Container and binary registry.
    └── longhorn                    | Cluster CSI.
```

It's important to node that if you make changes to this structure that you change both AGENTS.md and README.md to reflect this.

## Common Patterns

### Kustomize Overlay
```yaml
# environments/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
patches:
  - path: values-patch.yaml
configMapGenerator:
  - behavior: replace
    files:
      - values.yaml
```

### Adding a New Application
1. Create directory under appropriate component
2. Add `base/` with base manifests and `kustomization.yaml`
3. Add `environments/prod/` with environment-specific overrides
4. Create ArgoCD Application in `ci-cd/argocd/environments/prod/apps/`

## Dependencies

Tools available in nix shell:
- kubectl
- kubernetes-helm
- talosctl
- argocd
- cilium-cli
- task
- jq
- terraform
