# Argo Workflows

Argo Workflows is an open source container-native workflow engine for orchestrating parallel jobs on Kubernetes.

## Logging In

Open https://workflows.okwilkins.dev and sign in with Authelia SSO using an account in the `admins` group.

Alternatively, use the workflow-admin service-account token:

```bash
ARGO_TOKEN=$(kubectl get secret -n argo-workflows argo-workflows-ui-user-admin-sa-token -o json | jq -r '.data.token' | base64 -d)
echo "Bearer $ARGO_TOKEN"
```

See [Argo Events](../argo-events/README.md#github-webhook) for GitHub image-build triggers.

## GitHub Build Status

1. Create a fine-grained GitHub token for the repository with **Commit statuses: Read and write**.
2. Use SOPS to add it as `TF_VAR_github_commit_status_token` in the private `h8s-secrets/secrets.yaml`.
3. Apply Terraform Stage 07 from `nix develop .#infra`.

