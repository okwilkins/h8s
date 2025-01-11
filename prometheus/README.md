# Prometheus

This section deploys a full Prometheus stack. This includes the following tools:

- Prometheus
- Grafana
- Alertmanager
- ServiceMonitor
- PodMonitor
- Probe
- PrometheusRule
- AlertmanagerConfig
- PrometheusAgent
- ScrapeConfig

To read more, go to the [Prometheus Operator docs](https://prometheus-operator.dev/docs/getting-started/introduction/).

## Deployment

To deploy any Kubernetes manifest files, run the following:

```bash
ENV_NAME=prod
kubectl apply -f environments/${ENV_NAME}
```

```bash
kubectl label namespace monitoring \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged
```

To deploy this stack via Helm, run the following command:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade prometheus-stack prometheus-community/kube-prometheus-stack \
    --install \
    --namespace "monitoring" \
    --create-namespace \
    -f environments/base/values.yaml
```




