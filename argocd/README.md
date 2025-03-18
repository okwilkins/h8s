# ArgoCD

Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes.

## Installation

```bash
export CLUSTER_ENV=prod
export ARGOCD_VERSION=7.8.12

helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade argocd argo/argo-cd \
    --install \
    --namespace argocd \
    --create-namespace \
    --version ${ARGOCD_VERSION} \
    -f environments/${CLUSTER_ENV}/values.yaml
```

## Web UI

To gain access to the admin account via the web UI, run this command:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
