# Argo Workflows

Argo Workflows is an open source container-native workflow engine for orchestrating parallel jobs on Kubernetes.

## Logging In

To login to the Argo Workflows frontend, simply obtain the `argo-workflow` service account's token secret:

```bash
ARGO_TOKEN=$(kubectl get secret -n argo-workflows argo-workflows-ui-user-admin-sa-token -o json | jq -r '.data.token' | base64 -d)
echo "Bearer $ARGO_TOKEN"
```
