# Hashicorp Vault

Vault is a tool for securely accessing secrets. A secret is anything that you want to tightly control access to, such as API keys, passwords, certificates, and more. Vault provides a unified interface to any secret, while providing tight access control and recording a detailed audit log.


## Installation

[ArgoCD](../argocd/README.md) handles the installation of Vault. There are some steps to take after ArgoCD has installed everything however.

### First Time Installation

If installing for the first time, you will need to [initialise the vault](https://developer.hashicorp.com/vault/docs/commands/operator/init). Run:

```bash
kubectl exec -ti vault-0 -- vault operator init
```

***BE SURE TO SAVE THE OUTPUT SOMEWHERE SAFE!***

### Pod Rescheduling

Whenever the pod(s) for Vault are rescheduled, they will need to be [unsealed](https://developer.hashicorp.com/vault/docs/concepts/seal) again. Run:

```bash
kubectl exec -ti vault-0 -- vault operator unseal
```

Enter in 3 of the keys produced from the [first time installation](#first-time-installation).

