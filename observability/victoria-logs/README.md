# Victoria Logs

[Victoria Logs](https://docs.victoriametrics.com/victorialogs/) is the log storage, query engine, and alerting component of the observability stack.

Deployed via the [`victoria-logs-single`](https://artifacthub.io/packages/helm/victoriametrics/victoria-logs-single) Helm chart. Receives logs from [Fluent Bit](../fluent-bit/) via HTTP intake at `/insert/jsonline` and provides log tailing, querying via LogsQL, and alerting rules.

The Grafana dashboard is bundled via the chart and included in the [Grafana dashboards](../grafana/).
