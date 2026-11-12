# Argo Workflows

Argo Workflows is an open source container-native workflow engine for orchestrating parallel jobs on Kubernetes.

## Logging In

Open https://workflows.okwilkins.dev and sign in with Authelia SSO using an account in the `admins` group.

Alternatively, use the workflow-admin service-account token:

```bash
ARGO_TOKEN=$(kubectl get secret -n argo-workflows argo-workflows-ui-user-admin-sa-token -o json | jq -r '.data.token' | base64 -d)
echo "Bearer $ARGO_TOKEN"
```
