# BookOrbit

[BookOrbit](https://github.com/bookorbit/bookorbit) is a self-hosted library and reading platform for ebooks, PDFs, audiobooks, and comics.

Access it at **[books.okwilkins.dev](https://books.okwilkins.dev)**.

## Initial setup

Run from the repository root:

```bash
nix develop --command kubectl -n bookorbit get secret bookorbit-secret \
  -o jsonpath='{.data.setup-bootstrap-token}' | base64 --decode
```

Paste the output into **Setup Token** when creating your first administrator.

## SSO

Open **Settings → Admin → [OIDC / SSO](https://books.okwilkins.dev/settings/admin/oidc)**. Select **Add Provider**, or click **Authelia** to edit.

| Setting | Value |
| --- | --- |
| Slug | `authelia` |
| Display name | `Authelia` |
| Icon URL | `https://www.authelia.com/svgs/branding/logo.svg` |
| Issuer URI | `https://auth.okwilkins.dev` |
| Client ID | `bookorbit` |
| Client secret | Leave blank |
| Scopes | `openid profile email groups` |

1. Test the connection and enable the provider.
2. Under **Auto-Provisioning**, immediately below **Claim Mapping**, set:
   - **Auto-provision users:** off
   - **Allow local account linking:** on

**“Your account has not been set up”**: enable local account linking and ensure usernames match, not emails.

Only set `DISABLE_LOCAL_AUTH=true` after your superuser can sign in through SSO.
