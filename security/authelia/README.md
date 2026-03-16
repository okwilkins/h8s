# Authelia

[Authelia](https://www.authelia.com/) is an open-source authentication and authorization server and portal fulfilling the identity and access management (IAM) role of information security in providing multi-factor authentication and single sign-on (SSO) for your applications via a web portal.

## Getting Started

### Getting the Admin Password

1. Navigate to [`infrastructure/07-vault-resources-provision`](../../infrastructure/07-vault-resources-provision/).
2. Run `nix develop -c tofu state show -show-sensitive random_password.authelia_user_password`.
3. The password will be under `result`.

### Setting Up Authentication Method

As an SMTP server has not been setup to send emails, Authelia's text based notification system has been used. To get the OTP run:

```bash
kubectl exec -it deploy/authelia -n authelia -c authelia -- cat /config/notification.txt
```

