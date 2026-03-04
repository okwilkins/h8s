# CoreDNS

[CoreDNS](https://coredns.io/) is a DNS server. It is written in Go. It can be used in a multitude of environments because of its flexibility.
CoreDNS integrates with Kubernetes via the Kubernetes plugin, or with etcd with the etcd plugin.

This implementation does not replace the CoreDNS installed by [Talos](../../infrastructure/bootstrap/README.md) and is meant only to serve as a DNS server and LAN ad blocker.

## Features

The deployments [found in base](./base/) include a CRON job that downloads [hagezi's pro hosts list](https://github.com/hagezi/dns-blocklists) daily. This acts as a ad and malware blocker.

## Proxmox Hosts Configuration

Proxmox host DNS entries are managed via the `hosts` plugin with IPs synced from Vault via External Secrets Operator.

### Plugin Ordering Workaround

Due to CoreDNS plugin chain ordering (template executes before hosts in CoreDNS 1.14.1), **zone-specific server blocks** are used to ensure Proxmox hosts resolve correctly:

- `pve1.okwilkins.dev pve2.okwilkins.dev:53` - Dedicated server block for Proxmox hosts using the hosts plugin
- `okwilkins.dev:53` - Wildcard template for all other okwilkins.dev subdomains

This ensures queries for Proxmox hosts match the most specific zone first, bypassing the template plugin's broad wildcard match.

See [GitHub issue #5350](https://github.com/coredns/coredns/issues/5350) for details on the plugin ordering limitation.

