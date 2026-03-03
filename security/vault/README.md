# Hashicorp Vault

Vault is a tool for securely accessing secrets. A secret is anything that you want to tightly control access to, such as API keys, passwords, certificates, and more. Vault provides a unified interface to any secret, while providing tight access control and recording a detailed audit log.

## Installation

[ArgoCD](../../ci-cd/argocd/README.md) handles the installation of Vault. The [bootstrap Terraform](../../infrastructure/bootstrap/README.md) automatically initializes, unseals, and configures Vault during cluster setup.

### Automated Initialization (Bootstrap)

When you run `terraform apply` in the bootstrap directory, the following happens automatically:

1. **Vault Initialization**: Terraform runs `vault operator init` and saves the output to `vault-init.json`
2. **Vault Unsealing**: Terraform unseals Vault using the unseal keys from the init output
3. **Kubernetes Auth**: Terraform enables and configures the Kubernetes auth method
4. **Secret Engines**: Terraform enables KV v2 and PKI secret engines
5. **Policies & Roles**: Terraform creates policies and Kubernetes auth roles for ESO and cert-manager
6. **Secrets**: Terraform generates and stores passwords, keys, and certificates

**IMPORTANT**: The `vault-init.json` file in `infrastructure/bootstrap/` contains the unseal keys and root token. It is gitignored and must be backed up securely alongside `terraform.tfstate`. Losing this file means losing access to Vault forever.

### Manual Operations

The following sections document manual operations that may be needed in certain scenarios.

#### First Time Installation (Manual Alternative)

If you need to initialize Vault manually (e.g., if the automated process failed), run:

```bash
kubectl exec -ti vault-0 -n vault -- vault operator init
```

***BE SURE TO SAVE THE OUTPUT SOMEWHERE SAFE!***

You will then need to unseal the server:

```bash
kubectl exec -ti vault-0 -n vault -- vault operator unseal
```

#### Kubernetes Service Accounts (Manual)

If the automated setup didn't complete successfully, you can manually configure Kubernetes auth:

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

#### Cert Manager Root CA Service (Manual)

If PKI wasn't configured automatically:

```bash
kubectl exec -ti vault-0 -n vault -- /bin/sh

DOMAIN="okwilkins.dev"
ROLE_NAME=$(echo $DOMAIN | sed 's/\./\-dot\-/')
echo "Vault role name: $ROLE_NAME"

# Enable PKI secrets engine
vault secrets enable pki

# Increase TTL from 30 days -> 1 year
vault secrets tune -max-lease-ttl=8760h pki

# Create self-signed root CA 
vault write pki/root/generate/internal \
    common_name=$DOMAIN \
    ttl=8760h

# Update the CRL location and issuing certificates
vault write pki/config/urls \
    issuing_certificates="http://127.0.0.1:8200/v1/pki/ca" \
    crl_distribution_points="http://127.0.0.1:8200/v1/pki/crl"

# Configure a role that maps a name in Vault to a procedure for generating a certificate
vault write pki/roles/$ROLE_NAME \
    allowed_domains=$DOMAIN \
    allow_bare_domains=true \
    allow_subdomains=true \
    max_ttl=72h

# Create a policy to enable read access to the PKI secrets engine paths
vault policy write pki - <<EOF
path "pki*"                   { capabilities = ["read", "list"] }
path "pki/sign/$ROLE_NAME"    { capabilities = ["create", "update"] }
path "pki/issue/$ROLE_NAME"   { capabilities = ["create"] }
EOF

# Create role for a K8s service account to use
vault write auth/kubernetes/role/vault-issuer \
    bound_service_account_names=vault-issuer \
    bound_service_account_namespaces=cert-manager \
    policies=pki \
    ttl=20m
```

Read more here:
- https://developer.hashicorp.com/vault/docs/secrets/pki/setup
- https://developer.hashicorp.com/vault/tutorials/archive/kubernetes-cert-manager

### Pod Rescheduling

Whenever the pod(s) for Vault are rescheduled, they will need to be [unsealed](https://developer.hashicorp.com/vault/docs/concepts/seal) again. Use the unseal keys from `vault-init.json`:

```bash
# Extract unseal keys from vault-init.json and unseal Vault
for key in $(cat infrastructure/bootstrap/vault-init.json | jq -r '.unseal_keys_b64[]'); do
  kubectl exec -ti vault-0 -n vault -- vault operator unseal "$key"
done
```

Enter in 3 of the keys produced from the initialization.

