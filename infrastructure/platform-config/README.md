# Platform Configuration

Terraform configurations for managing platform-level resources that don't have mature Kubernetes operators.

## Getting Started

From the repository root, open your infrastructure shell:

```bash
nix develop .#infra --command "$SHELL"
```

State is stored in B2 at `h8s-terraform-backend/h8s/platform-config/terraform.tfstate`.
It uses the same enforced state and plan encryption as the bootstrap stages.

**IMPORTANT**: Run only one infrastructure operation at a time because B2 state locking is disabled.
This was done as Backblaze B2 does not have locking built in.

Kubernetes access comes directly from the sensitive stage `03` state outputs, so no local kubeconfig or home context is required.
Harbor must be running, and External Secrets Operator must have created its login Secrets from Vault before applying this stage.

Forgejo must also be running with `forgejo-admin-secret` synced in the `forgejo` namespace.
Vault must be unsealed with its KV mount configured, and stage `06` state must contain its bootstrap credentials.
Apply stage `07` first and wait for ESO to create `renovate-forgejo-credentials` in the `renovate` namespace.

```bash
task --dir "$INFRA_ROOT" platform:configure
```

## Signing Into Harbor

Sign in at https://harbor.okwilkins.dev with Authelia, then copy your **CLI secret** from **User Profile**. Use it as the password below, not your Authelia password:

```bash
docker login harbor.okwilkins.dev -u okwilkins
```

Pull through caches:
```bash
docker pull harbor.okwilkins.dev/docker-hub-cache/hello-world:latest
```

Pattern: `harbor.okwilkins.dev/<project>/<image>:<tag>`


## Harbor Configuration

This manages Harbor container registry resources including:
- Projects (main, docker-hub-cache, ghcr-cache)
- Registries (Docker Hub, Quay, GHCR pull-through caches)
- Authelia OIDC authentication (`admins` grants Harbor administrator access)
- Robot accounts and permissions


## Cloudflare

Store both tokens in the private `h8s-secrets/secrets.yaml` with SOPS. Reopen the infrastructure shell after saving.

### Infrastructure token

Set `TF_CLOUDFLARE_TOKEN` to the `h8s-terraform` account token. The shell exports it as `CLOUDFLARE_API_TOKEN`.
OpenTofu uses it to manage tunnels, DNS records and firewall rules.

Grant `h8s-terraform` these permissions:

| Scope | Dashboard selections | Token summary |
| --- | --- | --- |
| Entire Account | Argo Tunnel (Legacy): Read and Edit | Cloudflare Tunnel Read, Cloudflare Tunnel Write |
| Specified Domains: `okwilkins.dev` | DNS: Read and Edit, Zone: Read, Zone WAF Rules under App Security: Read and Edit | DNS Read, DNS Write, Zone Read, Zone WAF Read, Zone WAF Write |

### User token manager

Create a user token named `h8s-token-manager` with Cloudflare's [Create additional tokens template](https://developers.cloudflare.com/fundamentals/api/how-to/create-via-api/). Under **User**, grant only **API Tokens Edit**. Store the token as `TF_VAR_cloudflare_token_manager`.

OpenTofu uses this token to manage `h8s-tunnel-cloudflared` and the [CrowdSec bouncer token](https://docs.crowdsec.net/u/bouncers/cloudflare/#cloudflare-api-token). It stores the bouncer token in Vault at `kubernetes-homelab/crowdsec/cloudflare-token`.

OpenTofu uses `h8s-tunnel-cloudflared` to fetch the connector token for `h8s_prod`. See the [cloudflared migration steps](../../networking/cloudflared/README.md#connector-token).
