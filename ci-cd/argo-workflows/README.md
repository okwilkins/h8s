# Argo Workflows

Argo Workflows is an open source container-native workflow engine for orchestrating parallel jobs on Kubernetes.

## Logging In

To login to the Argo Workflows frontend, simply obtain the `argo-workflow` service account's token secret:

```bash
ARGO_TOKEN=$(kubectl get secret -n argo-workflows argo-workflows-ui-user-read-only-sa-token -o json | jq -r '.data.token' | base64 -d)
echo "Bearer $ARGO_TOKEN"
```


## Dagger Pipelines

[Dagger](https://dagger.io/) is heavily used in Argo Workflows. This allows the same pipelines to be run locally as they run in the cluster.

Dagger requires heavy-handed permissions however as it creates containers itself, requiring privileged permissions. To reduce the security risks, such workflows **must** be run within the `dagger-workflows` namespace.
Failing to do so will mean that the workflow will fail due to TalosOS' pod security admission standards. 

