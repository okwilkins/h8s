# [Argo Events](https://argoproj.github.io/argo-events/)

Argo Events is an event-driven workflow automation framework for Kubernetes which helps you trigger K8s objects, Argo Workflows, Serverless workloads, etc. on events from a variety of sources like webhooks, S3, schedules, messaging queues, gcp pubsub, sns, sqs, etc.

## GitHub Webhook

In the GitHub repository, open **Settings → Webhooks → Add webhook**:

- **Payload URL:** Use the EventSource's webhook URL, including its endpoint.
    - Example: `https://events.okwilkins.dev/github`
- **Content type:** `application/json`
- **Secret:** Use the same Vault secret as the EventSource.
- **Events:** Match the EventSource.
    - Example: **Just the push event** for `push`.
- Keep **SSL verification** and **Active** enabled.

Check **Recent deliveries** for a successful ping.

