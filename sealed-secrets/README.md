# Sealed Secrets

Sealed Secrets are "one-way" encrypted K8s Secrets that can be created by anyone, but can only be decrypted by the controller running in the target cluster recovering the original object.

To read more on Sealed Secrets here:
https://artifacthub.io/packages/helm/bitnami-labs/sealed-secrets

To read more about Kubeseal, go here:
https://github.com/bitnami-labs/sealed-secrets

## Installing

```bash
ENV_NAME=prod
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm upgrade sealed-secrets sealed-secrets/sealed-secrets --install
```

## Using Kubeseal

```bash
# Create a json/yaml-encoded Secret somehow:
# (note use of `--dry-run` - this is just a local file!)
echo -n bar | kubectl create secret generic mysecret --dry-run=client --from-file=foo=/dev/stdin -o yaml > mysecret.yaml

# This is the important bit:
kubeseal --controller-name sealed-secrets --controller-namespace default \
    -f mysecret.yaml -w mysealedsecret.yaml

# At this point mysealedsecret.json is safe to upload to Github,
# post on Twitter, etc.

# Eventually:
kubectl create -f mysealedsecret.yaml

# Profit!
kubectl get secret mysecret
```

A `.env` file can be converted into a Kubernetes secret like so:

```bash
kubectl create secret generic my-secret --from-env-file=.env
```

## Saving the Private Key

The private key is crucial for decrypting Sealed Secrets. Losing it will make it impossible to recover or unseal your secrets.
K9s can be used to inspect and decode the `sealed-secrets-key` in the cluster.

