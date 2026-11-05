# Forgejo

[Forgejo](https://forgejo.org/) is self-hosted Git hosting, available at **[git.okwilkins.dev](https://git.okwilkins.dev)**.

Sign in with **Authelia**. Registration is SSO-only and repositories are private by default.

## Cloudflare Tunnel

Add these published application routes to the existing tunnel, with SSH before any wildcard route:

| Hostname | Service |
| --- | --- |
| `git.okwilkins.dev` | `http://cilium-gateway-cloudflare-gateway.cloudflare.svc.cluster.local:80` |
| `git-ssh.okwilkins.dev` | `ssh://forgejo-ssh.forgejo.svc.cluster.local:22` |

Do not put an interactive Cloudflare Access login in front of the HTTPS route; Git clients use Forgejo tokens. The SSH route can have an Access policy.

## SSH

Add your SSH public key in Forgejo, install `cloudflared` on your client, and add this to `~/.ssh/config`:

```sshconfig
Host git-ssh.okwilkins.dev
    User git
    ProxyCommand cloudflared access ssh --hostname %h
```

```bash
git clone git@git-ssh.okwilkins.dev:okwilkins/example.git
```

## Emergency login

The local administrator is `forgejo-admin`. Retrieve its password with:

```bash
nix develop --command kubectl -n forgejo get secret forgejo-admin-secret \
  -o jsonpath='{.data.password}' | base64 --decode
```
