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

