# CoreDNS

[CoreDNS](https://coredns.io/) is a DNS server. It is written in Go. It can be used in a multitude of environments because of its flexibility.
CoreDNS integrates with Kubernetes via the Kubernetes plugin, or with etcd with the etcd plugin.

This implementation does not replace the CoreDNS installed by [Talos](../../infrastructure/talos/README.md) and is meant only to serve as a DNS server and LAN ad blocker.

## Features

The deployments [found in base](./base/) include a CRON job that downloads [hagezi's pro hosts list](https://github.com/hagezi/dns-blocklists) daily. This acts as a ad and malware blocker.
