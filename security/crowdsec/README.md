# CrowdSec

[CrowdSec](https://www.crowdsec.net/security-engine) is an open-source intrusion detection and prevention system.

CrowdSec checks the public gateway logs for repeated requests to missing or forbidden paths.
Cloudflare blocks those scanners for 15 minutes.
It also blocks addresses on CrowdSec's community blocklist.

## Setup

1. Enable [Workers Analytics Engine](https://dash.cloudflare.com/?to=/:account/workers/analytics-engine) once in the Cloudflare dashboard. OpenTofu cannot enable it. Without it, Cloudflare rejects the bouncer's Worker with error `10089`.
   If Cloudflare shows **Create Blank Dataset**, enter `h8s_crowdsec` for **Dataset Name** and `CROWDSECCFBOUNCER_AE` for **Dataset Binding**.
2. Check the [Cloudflare provider token permissions](../../infrastructure/platform-config/README.md#cloudflare). In `nix develop .#infra`, review and apply `07-vault-resources-provision` for the local CrowdSec keys.
3. Review and apply `platform-config` to create the bouncer and read-only analytics tokens and store them in Vault. Push the manifests so Argo CD syncs them.
4. Once the bouncer creates the route, open **Worker Routes** in the Cloudflare dashboard. For each `h8s-crowdsec` route, set **Request limit failure mode** to **Fail open**. If you reach the Worker request limit, visitors can still reach the site without the CrowdSec check.

Cloudflare's [free KV write limit](https://developers.cloudflare.com/kv/platform/limits/) can prevent the first sync from loading the full community blocklist.

## CrowdSec Console

1. Get an enrolment key from [Security Engines](https://app.crowdsec.net/security-engines). Store it as `TF_VAR_crowdsec_enroll_key` in the private `h8s-secrets/secrets.yaml` using SOPS.
2. Reopen the infrastructure shell and apply stage 07 to write the key to Vault. Sync CrowdSec in Argo CD. The Local API reads `ENROLL_KEY` from the `crowdsec-console` Secret at startup.
3. In the Console, accept the enrolment for `h8s` once. Run `kubectl -n crowdsec rollout restart deployment/crowdsec-lapi`.
4. Open **Alert Explorer** to see new scanner alerts.

## Daily ban summary

At midnight UTC, Alertmanager sends a [Telegram summary](environments/prod/daily-summary/cronjob.yaml) if CrowdSec issued any local scanner bans the previous day. Cloudflare's estimate includes requests its Worker blocked using CrowdSec's community blocklist.

## Count Blocked Requests

Run this query against `h8s_crowdsec` in [Workers Analytics Engine](https://dash.cloudflare.com/?to=/:account/workers/analytics-engine) using the [SQL API](https://developers.cloudflare.com/analytics/analytics-engine/sql-api/). It counts requests the Worker blocked in the last 24 hours. The Worker records the IP version but not the visitor's address, so the dataset cannot count unique IPs.

```sql
SELECT SUM(_sample_interval * double1) AS blocked_requests
FROM h8s_crowdsec
WHERE timestamp >= NOW() - INTERVAL '1' DAY
  AND blob1 = 'dropped'
  AND blob4 = 'ban'
```

## Configuration

Edit [`values.yaml`](environments/prod/values.yaml) for detection and ban duration. After Argo CD syncs a change to the [bouncer ConfigMap](environments/prod/bouncer/configmap.yaml), restart the bouncer:

```sh
kubectl -n crowdsec rollout restart deployment/crowdsec-cloudflare-bouncer
```

Blocking pauses while the bouncer recreates its Worker and routes. Check **Fail open** after each restart.
