# Cloudflared

Cloudflared is a lightweight daemon that creates secure tunnels between your local Kubernetes cluster and Cloudflare's edge network, allowing you to expose your services to the internet without opening ports or requiring public IP addresses.

I use this to facilitate connections to my K8s cluster over the web.

## Cloudflared Token

To get your Cloudflare Tunnel token:

1. Log in to the [Cloudflare dashboard](https://dash.cloudflare.com) and open **Zero Trust**.

2. Go to **Networks** → **Connectors** → **Cloudflare Tunnels**.

3. Click the tunnel you want to run in Kubernetes, then choose **Edit**.

4. Scroll to **Install and run a connector**.

5. Select an environment tab (Docker is often the easiest to copy).

6. Copy the command shown (it will include `--token <…>`), then extract just the token value (it usually starts with `eyJ...`).

7. Set the token as an environment variable for Terraform:
   ```bash
   export TF_VAR_cloudflare_tunnel_token="eyJ..."
   ```

This token is used by the Cloudflared deployment and will be stored in Vault during bootstrap.

### Alternative: API Method

If you prefer to use the Cloudflare API to retrieve the token programmatically:

1. Get your `CLOUDFLARE_ACCOUNT_ID`: Read [this guide](https://developers.cloudflare.com/fundamentals/setup/find-account-and-zone-ids/).

2. Get your `CLOUDFLARE_API_KEY`: Go to your [API tokens page](https://dash.cloudflare.com/profile/api-tokens) and create a token with `Cloudflare Tunnel:Edit` permissions.

3. Set your `TUNNEL_NAME`: The name of your existing tunnel.

4. Run the following script to retrieve the token:

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

5. Set the token as an environment variable:
   ```bash
   export TF_VAR_cloudflare_tunnel_token="$TUNNEL_TOKEN"
   ```

