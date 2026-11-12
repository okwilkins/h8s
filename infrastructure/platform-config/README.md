# Platform Configuration

Terraform configurations for managing platform-level resources that don't have mature Kubernetes operators.

## Harbor Configuration

This manages Harbor container registry resources including:
- Projects (main, docker-hub-cache, ghcr-cache)
- Registries (Docker Hub, Quay, GHCR pull-through caches)
- Authelia OIDC authentication (`admins` grants Harbor administrator access)
- Robot accounts and permissions

## Getting Started

From the repository root, open your infrastructure shell:

```bash
nix develop .#infra --command "$SHELL"
```

State is stored in B2 at `h8s-terraform-backend/h8s/platform-config/terraform.tfstate`.
It uses the same enforced state and plan encryption as the bootstrap stages.

**IMPORTANT**: Run only one infrastructure operation at a time because B2 state locking is disabled.
This was done as Backblaze B2 does not have locking built in.

Kubernetes access comes directly from the sensitive stage `03` state outputs, so no local kubeconfig or home context is required.
Harbor must be running, and External Secrets Operator must have created its login Secrets from Vault before applying this stage.

Forgejo must also be running with `forgejo-admin-secret` synced in the `forgejo` namespace.
Vault must be unsealed with its KV mount configured, and stage `06` state must contain its bootstrap credentials.
Apply stage `07` first and wait for ESO to create `renovate-forgejo-credentials` in the `renovate` namespace.

```bash
task --dir "$INFRA_ROOT" platform:configure
```

### Using Harbor Pull-Through Caches

Sign in at https://harbor.okwilkins.dev with Authelia, then copy your **CLI secret** from **User Profile**. Use it as the password below, not your Authelia password:

```bash
docker login harbor.okwilkins.dev -u okwilkins
```

Pull through caches:
```bash
docker pull harbor.okwilkins.dev/docker-hub-cache/hello-world:latest
```

Pattern: `harbor.okwilkins.dev/<project>/<image>:<tag>`

