# ArgoCD

Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes.

## Installation

ArgoCD is now automatically installed during cluster bootstrap via Terraform.

### After Bootstrapping

After bootstrapping, the above command will need to be run again in order to run again to have the Prometheus service monitors be installed. They will only be available after [Prometheus is installed](../../observability/prometheus).

**TODO**: Install Prometheus CRDs before cluster bootstrap to avoid this side effect.

### App of Apps

Installing the app of apps will install everything the cluster needs to get going. It is based from [ArgoCD's docs found here](https://github.com/argoproj/argo-cd/blob/a06cdb3880fe89f2e0512b07a4b2df2cfe83634e/docs/operator-manual/cluster-bootstrapping.md).

![alt](https://github.com/argoproj/argo-cd/blob/a06cdb3880fe89f2e0512b07a4b2df2cfe83634e/docs/assets/application-of-applications.png)

To install the app of apps, that will install everything else, run:

```bash
kubectl apply -k environments/$CLUSTER_ENV
```

## Access

ArgoCD is accessible at https://argocd.okwilkins.dev

Login is via Authelia SSO only. The local `admin` account is disabled.

## Bootstrapping / Emergency Access

If OIDC is unavailable (e.g. Authelia is down or misconfigured), the ArgoCD CLI
can bypass the API server entirely using core mode, which talks directly to the
Kubernetes API via kubeconfig:

```bash
kubectl exec -it -n argocd deploy/argocd-server -- argocd login --core
argocd app list
argocd app sync <app-name>
```

Or from your local machine with a valid kubeconfig:

```bash
argocd login --core
```
