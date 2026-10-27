# Platform Configuration

Terraform configurations for managing platform-level resources that don't have mature Kubernetes operators.

## Harbor Configuration

This manages Harbor container registry resources including:
- Projects (main, docker-hub-cache, ghcr-cache)
- Registries (Docker Hub, Quay, GHCR pull-through caches)
- Users and robot accounts
- Project memberships and permissions

## Getting Started

From the repository root, open your infrastructure shell:

```bash
nix develop .#infra --command "$SHELL"
```

State is stored in B2 at `h8s-terraform-backend/h8s/platform-config/terraform.tfstate`.
It uses the same enforced state and plan encryption as the bootstrap stages.

**IMPORTANT**: Run only one infrastructure operation at a time because B2 state locking is disabled.
This was done as Backblaze B2 does not have locking built in.

```bash
task --dir infrastructure platform:configure
```

### Using Harbor Pull-Through Caches

Login to Harbor:
```bash
docker login harbor.okwilkins.dev -u oli
```

Pull through caches:
```bash
docker pull harbor.okwilkins.dev/docker-hub-cache/hello-world:latest
```

Pattern: `harbor.okwilkins.dev/<project>/<image>:<tag>`
