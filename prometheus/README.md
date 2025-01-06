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

To deploy this stack via Helm, run the following command:

```bash
ENV_NAME=prod

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade prometheus-stack prometheus-community/kube-prometheus-stack \
    --install \
    --namespace "monitoring" \
    --create-namespace \
    -f environments/${ENV_NAME}/values.yaml
```
