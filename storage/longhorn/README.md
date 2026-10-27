# Longhorn

Longhorn is a distributed block storage system for Kubernetes. Longhorn is cloud-native storage built using Kubernetes and container primitives.

![alt](https://longhorn.io/img/diagrams/architecture/how-longhorn-works.svg)

## Encrypted Backups to B2

Store these in `h8s-secrets/secrets.yaml` using SOPS:

- `TF_VAR_longhorn_backup_access_key_id`
- `TF_VAR_longhorn_backup_secret_access_key`
- `TF_VAR_longhorn_encryption_key`

**IMPORTANT**: Keep the encryption key in a password manager too!

For `h8s-longhorn-backups`, select B2's **Keep only the last version of the file**, without expiry for active objects.
Longhorn manages the lifecycle of data, not B2.

From the repository root:

```bash
nix develop .#infra --command "$SHELL"
tofu -chdir="$INFRA_ROOT/05-argocd" apply
```

Commit and push for Argo CD to deploy the configuration.
Use `longhorn-encrypted` for encrypted volumes and backups.

