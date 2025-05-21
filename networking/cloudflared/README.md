# Cloudflared

Cloudflared is a lightweight daemon that creates secure tunnels between your local Kubernetes cluster and Cloudflare's edge network, allowing you to expose your services to the internet without opening ports or requiring public IP addresses.

I use this to facilitate connections to my K8s cluster over the web.

## Cloudflared Token

To get the values for the first 3 variables:
- `CLOUDFLARE_ACCOUNT_ID`: Read [this guide here](https://developers.cloudflare.com/fundamentals/setup/find-account-and-zone-ids/).
- `CLOUDFLARE_API_KEY`: Go to your [accounts api-tokens page](https://dash.cloudflare.com/profile/api-tokens). Create an API key with permissions for `Cloudflate One Connector: cloudflared` with `Read`.
- `TUNNEL_NAME`: The name of the tunnel to use for the cluster. [Read more here](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-remote-tunnel/).

Place the `TUNNEL_TOKEN` into a secret in your cloud platform. Put the key name as `token` and the value the contents of the script below:

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

echo $TUNNEL_TOKEN
```

This secret is used by the Cloudflared deployment.

