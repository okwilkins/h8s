# Cert Manger

Cert manager is a powerful and extensible X.509 certificate controller for Kubernetes and OpenShift workloads. It will obtain certificates from a variety of Issuers, both popular public Issuers as well as private Issuers, and ensure the certificates are valid and up-to-date, and will attempt to renew certificates at a configured time before expiry.

[Read more here](https://cert-manager.io/).

## Setting Up a New HTTPS Route

This cluster makes use of [Cilium's Gateway API implementation](https://docs.cilium.io/en/latest/network/servicemesh/gateway-api/gateway-api/). To enable a new HTTPS route add the following:

1. The certificate:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: <SUBDOMAIN>-okwilkins-dev
  namespace: <SUBDOMAIN>
spec:
  secretName: <SUBDOMAIN>-okwilkins-dev-tls
  issuerRef:
    name: vault-issuer
    kind: ClusterIssuer
  commonName: <SUBDOMAIN>.okwilkins.dev
  dnsNames:
    - <SUBDOMAIN>.okwilkins.dev
```

2. Add to the gateway `.spec.listeners`:

```yaml
- protocol: HTTPS
  name: home-lan-<SUBDOMAIN>
  hostname: <SUBDOMAIN>.okwilkins.dev
  port: 443
  allowedRoutes:
    namespaces:
      from: All
  tls:
    mode: Terminate
    certificateRefs:
      - name: <SUBDOMAIN>-okwilkins-dev-tls
        namespace: <SUBDOMAIN>
```

[Read more here](https://cert-manager.io/docs/usage/gateway/#use-cases) for details on how to make these listeners for cert-managers.

3. Add a reference grant to the TLS secret generated in part `1` (if the secret is in a different namespace to the gateway):

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: <SUBDOMAIN>-tls-access
  namespace: <SUBDOMAIN>
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: Gateway
      namespace: default
  to:
    - group: ""
      kind: Secret
      name: <SUBDOMAIN>-okwilkins-dev-tls
```

4. Create the HTTPRoute like so:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: <SUBDOMAIN>
  namespace: <SUBDOMAIN>
spec:
  parentRefs:
    - name: default-gateway
      namespace: default
      sectionName: home-lan-<SUBDOMAIN>
  hostnames:
    - <SUBDOMAIN>.okwilkins.dev
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: <SUBDOMAIN>-server
          port: 80
```

## Obtaining Vault CA Certificate

Once everything is setup and you start trying to connect to HTTPS endpoints you will find that your browser will not trust the website. This is because Vault's CA must be added to your system's trusted CA store. To get your CA certificate run:

```bash
kubectl get secrets -A -o json | \
    jq -r 'first(.items[] | select(.metadata.annotations."cert-manager.io/issuer-name" == "vault-issuer")) | .data."ca.crt"' | \
    base64 -d > /tmp/vault-ca.crt
```

To then add this to your trusted CA store run the following for Linux:

```bash
sudo cp /tmp/vault-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

And for macOS:

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/vault-ca.crt
```

