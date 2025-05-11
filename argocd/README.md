# ArgoCD

Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes.

## Installation

```bash
export CLUSTER_ENV=prod
export ARGOCD_HELM_VER=8.0.0

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade argocd argo/argo-cd \
    --install \
    --namespace argocd \
    --create-namespace \
    --version ${ARGOCD_HELM_VER} \
    -f environments/${CLUSTER_ENV}/values.yaml
```

### App of Apps

Installing the app of apps will install everything the cluster needs to get going. It is based from [ArgoCD's docs found here](https://github.com/argoproj/argo-cd/blob/a06cdb3880fe89f2e0512b07a4b2df2cfe83634e/docs/operator-manual/cluster-bootstrapping.md).

![alt](https://github.com/argoproj/argo-cd/blob/a06cdb3880fe89f2e0512b07a4b2df2cfe83634e/docs/assets/application-of-applications.png)

To install the app of apps, that will install everything else, run:

```bash
kubectl apply -k environments/$CLUSTER_ENV
```

## Web UI

To gain access to the admin account via the web UI, run this command:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
