# Chhoto-URL

[Chhoto-URL](https://github.com/SinTan1729/chhoto-url) is a self-hosted URL shortener with a simple web interface and API.

Access it at **[link.okwilkins.dev](https://link.okwilkins.dev)**.

## Login

The admin password is auto-generated and stored in a Kubernetes secret. To retrieve it:

```bash
kubectl get secret -n chhoto-url chhoto-url-secret -o jsonpath='{.data.password}' | base64 -d
```
