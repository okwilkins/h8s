# Hashicorp Vault

Vault is a tool for securely accessing secrets. A secret is anything that you want to tightly control access to, such as API keys, passwords, certificates, and more. Vault provides a unified interface to any secret, while providing tight access control and recording a detailed audit log.

## Installation

[ArgoCD](../../ci-cd/argocd/README.md) installs Vault.
Follow [Fresh Vault Initialisation](../../infrastructure/README.md#fresh-vault-initialisation) to initialise it manually and store the original recovery JSON in encrypted OpenTofu state and Bitwarden.

### Bootstrap Configuration

Stages `06` and `07` configure an initialised, unsealed Vault:

1. **Kubernetes Auth**: Terraform enables and configures the Kubernetes auth method
2. **Secret Engines**: Terraform enables KV v2 and PKI secret engines
3. **Policies & Roles**: Terraform creates policies and Kubernetes auth roles for ESO and cert-manager
4. **Secrets**: Terraform generates and stores passwords, keys, and certificates

Bootstrap does not initialise or unseal Vault, create a local recovery file or cache a login token.
See [Recovery Credentials](../../infrastructure/README.md#2-recovery-credentials) for the state-backed outputs and [Extracting the Vault CA Certificate](../../infrastructure/README.md#extracting-the-vault-ca-certificate) for the public CA.

### Manual Operations

The following sections document manual operations that may be needed in certain scenarios.
Inside the [infrastructure Nix shell](../../infrastructure/README.md#configure), this example opens an authenticated Vault shell using credentials retrieved from encrypted state.

You can use your existing user-managed kubeconfig instead by omitting the kubeconfig fetch and `--kubeconfig` flag.

```bash
(
  kubeconfig="$(tofu -chdir="$INFRA_ROOT/03-talos-configure" output -raw kubeconfig)" || exit 1
  credentials="$(tofu -chdir="$INFRA_ROOT/06-vault-init" output -json vault_credentials)" || exit 1
  token="$(jq -er '.root_token' <<<"$credentials")" || exit 1
  kubectl --kubeconfig <(printf '%s' "$kubeconfig") exec -it -n vault vault-0 -- \
    env VAULT_TOKEN="$token" /bin/sh
)
```

Run the commands below inside that Vault shell, then type `exit` when finished.

#### Kubernetes Service Accounts (Manual)

If the automated setup didn't complete successfully, you can manually configure Kubernetes auth:

```bash
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

Whenever the pod(s) for Vault are rescheduled, they will need to be [unsealed](https://developer.hashicorp.com/vault/docs/concepts/seal) again.
Use the [manual unseal command](../../infrastructure/README.md#ongoing-operations), which retrieves the required number of keys from encrypted state.

### Raft Backups

Hourly snapshots go to `h8s-vault/raft/` in B2.

### Restore

1. Pause Vault's Argo reconciliation and start the same Vault version on fresh encrypted storage.
2. Download the B2 snapshot into the Pod, then initialise, unseal and authenticate the empty Vault with temporary credentials.
3. Run `vault operator raft snapshot restore -force /path/to/backup.snap` inside the Pod.
4. Restart the Pod and unseal with the original keys from Bitwarden or encrypted state.
5. Authenticate with the original credentials, check a known secret, the CA and ESO, then resume Argo and remove temporary files and credentials.

On a rebuilt cluster, update Vault's Kubernetes auth configuration with the new API server and CA.
