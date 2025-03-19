# Gateways

This part of the project deals with the ingress into the cluster via the [Gateway API](https://gateway-api.sigs.k8s.io/).

![alt](https://gateway-api.sigs.k8s.io/images/resource-model.png)

## Getting Started

### Deploying Gateway API CRDs

By default, currently Kuberentes does not include the Gateway API by default. [ArgoCD](../argocd/README.md) manages the CRDs needed.

### Deploying Resources

To deploy the manifests:

```bash
CLUSTER_ENV=prod
kubectl apply -k environments/$CLUSTER_ENV
```

## Creating New Gateways

There are two important pieces of information to take into consideration when [deploying new gateways](https://gateway-api.sigs.k8s.io/api-types/gateway/):

1. When referencing a `spec.gatewayClassName`, as the cluster uses Cilium and its Gateway API implementation, use `cilium` as your value.
2. When referencing IP addresses to assign, firstly check that other gateways don't have the same IP and also check the [deployed Cilium IP pools](../cilium/base/ip-pools/) for availble IP addresses to assign.

## Creating New Routes

There are several steps to take when creating new routes:

1. Specify a value for `spec.hostnames`, and take note of this for later. This is needed so that a single Gateway API can serve multiple subdomains with the same path (by default it's `/`).
2. This cluster uses [Cloudflare Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) for public access to the cluster. When creating a new public hostname for the Tunnel for the cluster follow these steps:
    - When giving a value for a new subdomain, make sure it is the same as the value given in your route's `spec.hostnames`.
    - The path can be kept as `/`, or make it the same as the `spec.rules.matches.path.value`.
    - For the service, reference `spec.listeners.port` and `spec.listeners.protocol` values in the `spec.listeners` within your Gateway.
        - The URL for this will be the IP address assigned to the Gateway, for example `http://1.0.0.0:8080`.

