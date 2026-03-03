# Proxmox

[Proxmox VE](https://www.proxmox.com/en/) is the bare-metal [Type-1 hypervisor](https://en.wikipedia.org/wiki/Hypervisor) running on each physical machine. It hosts the virtual machines that run [Talos Linux](https://www.talos.dev/), which in turn form the Kubernetes cluster. Once the VMs are running and have their IPs, the [Talos setup](../talos/README.md) takes over.

## Hardware

The cluster runs on two [GMKtec G3](https://www.gmktec.com/products/gmktec-g3-mini-pc) mini-PCs. Each node has:

- **CPU**: Intel N100
- **RAM**: 32 GB
- **Storage**: 1 TB NVMe

## Accessing Proxmox

Each physical node runs its own Proxmox instance with its own web UI. To access it, open a browser on the LAN and navigate to:

```
https://<node-lan-ip>:8006
```

If you are unsure of the IP, check your router's DHCP lease table. Log in with:

- **Username**: `root`
- **Password**: saved during Proxmox installation (see your password manager)

***NOTE***: Proxmox uses a self-signed certificate by default, so your browser will warn you about an untrusted certificate. This is expected — proceed past the warning.

## Initial Proxmox Setup

To set up Proxmox on a new machine from scratch:

1. Download the [Proxmox VE ISO](https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso) from the official site.
2. Flash it to a USB drive (e.g. with [Balena Etcher](https://etcher.balena.io/) or `dd`).
3. Boot the machine from the USB drive and follow the installer:
   - Set a hostname (e.g. `pve-1`).
   - Configure a static IP on your LAN.
   - Set a root password — save this securely.
4. Once the installer finishes and the node reboots, access the UI at `https://<node-ip>:8006`.

## Loading the Talos Image

The Talos VMs require a custom Talos ISO that includes several system extensions. The extensions are defined in [`../talos/iso_factory_patch.yaml`](../talos/iso_factory_patch.yaml):

| Extension | Purpose |
|---|---|
| `siderolabs/qemu-guest-agent` | Allows Proxmox to communicate with the VM (shutdown, IP reporting, snapshots) |
| `siderolabs/iscsi-tools` | Required by Longhorn for persistent storage |
| `siderolabs/util-linux-tools` | Required by Longhorn for persistent storage |

The [`gen_configs.sh`](../talos/scripts/gen_configs.sh) script automatically fetches a schematic ID from the [Talos Image Factory](https://factory.talos.dev) using this patch file. However, the ISO itself must be manually downloaded and uploaded into Proxmox:

1. Go to [https://factory.talos.dev](https://factory.talos.dev), paste the contents of `iso_factory_patch.yaml` into the schematic field, and download the resulting ISO.
2. In the Proxmox UI, navigate to: **Datacenter → \<node\> → local → ISO Images → Upload**.
3. Upload the downloaded ISO. It will then be available when creating VMs.

***NOTE***: The `gen_configs.sh` script fetches the schematic ID at config-generation time. Make sure the ISO you upload to Proxmox matches the same schematic (i.e. was generated from the same `iso_factory_patch.yaml`).

## VM Configuration

Create one VM per node using the uploaded Talos ISO as the boot CD. Keep the following in mind:

- **BIOS/UEFI**: Use UEFI (`OVMF`) for compatibility with Talos.
- **CPU type**: Use `host` to pass through the host CPU flags — this improves performance and is required by some Talos features.
- **Disk**: Use `VirtIO SCSI` for the disk controller. Talos will install itself to this disk on first boot.
- **Network**: Attach the VM's network interface to your LAN bridge (e.g. `vmbr0`).
- **QEMU guest agent**: Enable this in the VM's **Options** tab. The Talos image already includes the `qemu-guest-agent` extension, so Proxmox can communicate with the VM once it is running.

Once each VM is booted from the ISO, it will display its IP address on the console. Note these IPs — they are needed for the next step.

## Next Steps

With the VMs running and their IPs known, proceed to the [Talos README](../talos/README.md) to generate and apply the Talos machine configs and bootstrap the cluster.

