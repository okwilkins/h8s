# Hashicorp Vault

Vault is a tool for securely accessing secrets. A secret is anything that you want to tightly control access to, such as API keys, passwords, certificates, and more. Vault provides a unified interface to any secret, while providing tight access control and recording a detailed audit log.


## Installation

[ArgoCD](../../argocd/README.md) handles the installation of Vault. There are some steps to take after ArgoCD has installed everything however.

### First Time Installation

If installing for the first time, you will need to [initialise the vault](https://developer.hashicorp.com/vault/docs/commands/operator/init). Run:

```bash
kubectl exec -ti vault-0 -n vault -- vault operator init
```

***BE SURE TO SAVE THE OUTPUT SOMEWHERE SAFE!***

You will then need to unseal the server:

```bash
kubectl exec -ti vault-0 -n vault -- vault operator unseal
```

### Kubernetes Service Accounts

In order for ESO to use a service account to access Vault, run the following:

```bash
kubectl exec -ti vault-0 -n vault -- /bin/sh
vault login
vault auth enable kubernetes
vault secrets enable -path=kubernetes-homelab kv-v2
vault write auth/kubernetes/config \
    kubernetes_host=https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt 

vault policy write external-secrets-reader - <<EOF
path "kubernetes-homelab/data/*" {
  capabilities = ["create", "read", "update", "delete", "patch"]
}
path "kubernetes-homelab/metadata/*" {
  capabilities = ["list", "delete"]
}
EOF

vault write auth/kubernetes/role/external-secrets-vault-auth \
    bound_service_account_names=external-secrets-vault-auth \
    bound_service_account_namespaces=external-secrets \
    policies=external-secrets-reader \
    ttl=24h
```


### Pod Rescheduling

Whenever the pod(s) for Vault are rescheduled, they will need to be [unsealed](https://developer.hashicorp.com/vault/docs/concepts/seal) again. Run:

```bash
kubectl exec -ti vault-0 -n vault -- vault operator unseal
```

Enter in 3 of the keys produced from the [first time installation](#first-time-installation).

