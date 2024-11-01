# Cloudflared

Cloudflared is a lightweight daemon that creates secure tunnels between your local Kubernetes cluster and Cloudflare's edge network, allowing you to expose your services to the internet without opening ports or requiring public IP addresses.

I use this to facilitate connections to my K8s cluster over the web.

## Installation

### Cloudflared Token

Follow the steps [provided by Cloudflare](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-remote-tunnel/) to create a tunnel. This guide should provide instructions on token generation. Once you have your token, you may run the following command:

```bash
TOKEN=<your-token-here>
kubectl create secret generic cloudflared-token \
    --from-literal=token=$TOKEN \
    --namespace=cloudflare
```

This secret is used by the Cloudflared deployment.

### Manifest Deployment

```bash
CLUSTER_ENV=prod
kubectl apply -k environments/$CLUSTER_ENV
```
