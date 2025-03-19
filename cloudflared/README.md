# Cloudflared

Cloudflared is a lightweight daemon that creates secure tunnels between your local Kubernetes cluster and Cloudflare's edge network, allowing you to expose your services to the internet without opening ports or requiring public IP addresses.

I use this to facilitate connections to my K8s cluster over the web.

## Cloudflared Token

The following script will create a [sealed-secret](../sealed-secrets/README.md) for the token that provides access to the Cloudflare tunnel.
This will create a file called `cloudflared-token.yaml` the secret contains a single key called `token`. Place this where needed, after creation.

To get the values for the first 3 variables:
- `CLOUDFLARE_ACCOUNT_ID`: Read [this guide here](https://developers.cloudflare.com/fundamentals/setup/find-account-and-zone-ids/).
- `CLOUDFLARE_API_KEY`: Go to your [accounts api-tokens page](https://dash.cloudflare.com/profile/api-tokens). Create an API key with permissions for `Cloudflate One Connector: cloudflared` with `Read`.
- `TUNNEL_NAME`: The name of the tunnel to use for the cluster. [Read more here](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-remote-tunnel/).

```bash
CLOUDFLARE_ACCOUNT_ID="<account ID>"
CLOUDFLARE_API_KEY="<api key>"
TUNNEL_NAME="<tunnel>"

TUNNEL_ID=$(
    curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel" \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer $CLOUDFLARE_API_KEY" | \
    jq -r --arg name $TUNNEL_NAME '.result[] | select(.name == $name) | .id'
)
TUNNEL_TOKEN=$(
    curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/token" \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer $CLOUDFLARE_API_KEY" | \
    jq -r '.result'
)
# Create the secret manifest
kubectl create secret generic cloudflared-token \
    --dry-run=client \
    --from-literal="token=$TUNNEL_TOKEN" \
    --namespace cloudflare -o yaml > cloudflared-token.yaml
# Encrypt via Kubeseal
kubeseal --controller-name sealed-secrets \
    --controller-namespace kubeseal \
    -f cloudflared-token.yaml \
    -w cloudflared-token.yaml 
```

This secret is used by the Cloudflared deployment.

