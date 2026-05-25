# Fluent Bit

[Fluent Bit](https://fluentbit.io/) is the metrics/logs/traces collection, processing and forwarding component of the observability stack.

Deployed via the [`fluent-bit-collector`](https://artifacthub.io/packages/helm/fluent/fluent-bit-collector) Helm chart. Collects container logs (`/var/log/containers/*.log`) and Kubernetes audit logs, processes them with parsers and Lua scripts, then forwards to [Victoria Logs](../victoria-logs/).

The data flow is: **Fluent Bit** → **Victoria Logs** → **Grafana**.
