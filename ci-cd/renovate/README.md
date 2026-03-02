# Renovate

Self-hosted dependency update automation using [Mend Renovate Community Edition](https://github.com/mend/renovate-ce-ee/tree/main/docs).

## Setup

### 1. Create GitHub App

Go to GitHub → Settings → Developer Settings → GitHub Apps → **New GitHub App**:

- **Name**: `h8s-renovate` (Renovate is taken on github.com)
- **Homepage URL**: `https://github.com/okwilkins/h8s`
- **Webhook URL**: `http://your-server-ip:8080/webhook` (or internal cluster URL)
- **Webhook secret**: `renovate` (default)

**Repository permissions**:
- Administration: **Read-only**
- Checks: **Read & write**
- Commit statuses: **Read & write**
- Contents: **Read & write**
- Dependabot alerts: **Read-only** (optional)
- Issues: **Read & write**
- Metadata: **Read-only**
- Pull requests: **Read & write**
- Workflows: **Read & write**

**Organization permissions**:
- Members: **Read-only**

**Subscribe to events**:
- Security Advisory
- Check run
- Check suite
- Issues
- Pull request
- Push
- Repository
- Status

**Install on**: Only this account

Note the **App ID** and generate a **private key** (download `.pem` file).

Store this key in vault under `renovate/github-app`. Store a key of `private-key`, with the `.pem` file.

Read more [here with the official docs](https://docs.mend.io/renovate/latest/set-up-mend-renovate-self-hosted-app-for-github).

### 2. Store Secret

Create a secret at path `renovate/github-app` with key `private-key` containing the full contents of the downloaded `.pem` file.

### 3. Configure

Edit `environments/prod/values.yaml`:

```yaml
renovate:
  mendRnvGithubAppId: ""
```

### 4. Install GitHub App on Repository

**Important**: The `mendRnvAutodiscoverFilter` setting does not work properly in Renovate CE. Instead, you must restrict the GitHub App to only the repositories you want Renovate to process.

After creating the GitHub App:

1. Go to GitHub → Settings → GitHub Apps → **h8s-renovate** → **Install App**
2. Select **Only select repositories** and choose only `okwilkins/h8s`
3. Click **Install**

**Do NOT** select "All repositories" - Renovate will attempt to process every repo the app has access to (up to the 10-repo limit for the free CE license).

The Renovate pod will automatically discover the repository on the next sync cycle (every 4 hours). To trigger immediately, restart the pod:

```bash
kubectl delete pod -n renovate -l app.kubernetes.io/name=mend-renovate-ce
```

