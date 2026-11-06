# Forgejo

[Forgejo](https://forgejo.org/) is self-hosted Git hosting, available at **[git.okwilkins.dev](https://git.okwilkins.dev)**.

Sign in with **Authelia**. Registration is SSO-only and repositories are private by default.

## Cloudflare Tunnel

Add these published application routes to the existing tunnel, with SSH before any wildcard route:

| Hostname | Service |
| --- | --- |
| `git.okwilkins.dev` | `http://20.0.0.0:80` |
| `git-ssh.okwilkins.dev` | `ssh://forgejo-ssh.forgejo.svc.cluster.local:22` |

The HTTP origin uses the same Gateway as the existing tunnel routes; Cloudflare serves HTTPS publicly. The existing cluster connector handles both routes.

Do not put an interactive Cloudflare Access login in front of the HTTPS route; Git clients use Forgejo tokens. The SSH route can have an Access policy.

## SSH

The tunnel carries SSH over WebSockets, not a public TCP/22 port, so each SSH client needs `cloudflared`. HTTPS clone/push does not need it.

Add your SSH public key in Forgejo, install `cloudflared` on your client, and add this to `~/.ssh/config`:

```sshconfig
Host git-ssh.okwilkins.dev
    User git
    ProxyCommand cloudflared access ssh --hostname %h
```

```bash
ssh -T git@git-ssh.okwilkins.dev
```

## Emergency login

The local administrator is `forgejo-admin`. Retrieve its password with:

```bash
nix develop --command kubectl -n forgejo get secret forgejo-admin-secret \
  -o jsonpath='{.data.password}' | base64 --decode
```
