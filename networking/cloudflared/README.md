# Cloudflared

Cloudflared connects the cluster to Cloudflare without opening inbound ports.

## Connector token

[`platform-config`](../../infrastructure/platform-config/README.md#cloudflare) uses `h8s-tunnel-cloudflared` to fetch the connector token for `h8s_prod`. It writes the connector token to `kubernetes-homelab/cloudflare/cloudflared-token` in Vault. External Secrets Operator copies it to the `cloudflared-token` Secret.

