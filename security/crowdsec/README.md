# CrowdSec

[CrowdSec](https://www.crowdsec.net/security-engine) is an open-source intrusion detection and prevention system.

CrowdSec checks the public gateway logs for repeated requests to missing or forbidden paths.
Cloudflare blocks those scanners for 15 minutes.
It also blocks addresses on CrowdSec's community blocklist.

## Setup

1. Check the [Cloudflare provider token permissions](../../infrastructure/platform-config/README.md#cloudflare). In `nix develop .#infra`, review and apply `07-vault-resources-provision` for the local CrowdSec keys.
2. Review and apply `platform-config` to create the bouncer token and store it in Vault. Push the manifests so Argo CD syncs them.
3. In Cloudflare's **Worker Routes**, set **Request limit failure mode** to **Fail open** for each `h8s-crowdsec` route.

Cloudflare's [free KV write limit](https://developers.cloudflare.com/kv/platform/limits/) can prevent the first sync from loading the full community blocklist.

## CrowdSec Console

1. Get an enrolment key from [Security Engines](https://app.crowdsec.net/security-engines) and store it in the private SOPS file.
2. Pass the key through Vault and External Secrets Operator to Helm's `lapi.env` as `ENROLL_KEY`. Set `ENROLL_INSTANCE_NAME` to `h8s` and sync with Argo CD.
3. In the Console, accept the enrolment for `h8s` once. Run `kubectl -n crowdsec rollout restart deployment/crowdsec-lapi`.
4. Open **Alert Explorer** to see new scanner alerts.

## Configuration

Edit [`values.yaml`](environments/prod/values.yaml) for detection and notifications. After Argo CD syncs a change to the [bouncer ConfigMap](environments/prod/bouncer/configmap.yaml), restart the bouncer:

```sh
kubectl -n crowdsec rollout restart deployment/crowdsec-cloudflare-bouncer
```

Blocking pauses while the bouncer recreates its Worker and routes. Check **Fail open** after each restart.
