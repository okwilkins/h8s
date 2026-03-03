# Bootstrap

Terraform root for bootstrapping a Talos Linux cluster on Proxmox from scratch.

A single `terraform apply` handles the full bootstrap sequence:

1. Registers the extension schematic with the [Talos image factory](https://factory.talos.dev) and retrieves the ISO URL
2. Downloads the custom Talos ISO into Proxmox storage
3. Creates the VMs on Proxmox
4. Waits for Talos to install itself to disk, then detaches the ISO
5. Generates per-node machine configs (with all patches applied)
6. Applies configs to each node
7. Bootstraps etcd on the first node
8. Retrieves the kubeconfig and talosconfig

It does **not** install cluster workloads beyond Cilium and ArgoCD — see [What to do next](#what-to-do-next).

## Hardware

Two GMKtec G3 mini-PCs, each with:
- CPU: Intel N100
- RAM: 32 GB
- Storage: 1 TB NVMe

## Proxmox Setup

Proxmox VE is the bare-metal Type-1 hypervisor running on each physical machine. It hosts VMs
running Talos Linux, which form the Kubernetes cluster.

### Initial Installation

1. Download the Proxmox VE ISO.
2. Flash to USB and boot the machine from it.
3. Set hostname (e.g. `pve-1`), static IP, and root password during installation.
4. Access the UI at `https://<node-ip>:8006` (uses a self-signed certificate — proceed past browser warning).

```
Username: root
Password: saved in password manager
```

### Talos Image

Terraform automatically registers the customisation schematic with the [Talos image factory](https://factory.talos.dev)
and downloads the resulting ISO into each Proxmox node's local storage. The following extensions are baked in:

| Extension                       | Purpose                                                      |
|---------------------------------|--------------------------------------------------------------|
| `siderolabs/qemu-guest-agent`   | Proxmox VM communication (shutdown, IP reporting, snapshots) |
| `siderolabs/iscsi-tools`        | Required by Longhorn for persistent storage                  |
| `siderolabs/util-linux-tools`   | Required by Longhorn for persistent storage                  |

### VM Configuration

VMs are created and configured entirely by Terraform. For reference, the settings used are:

- **BIOS/UEFI**: OVMF (UEFI)
- **CPU type**: `x86-64-v2-AES`
- **Disk**: VirtIO (`virtio0`), raw format, discard + SSD emulation enabled
- **Network**: LAN bridge (`vmbr0`), VirtIO model
- **QEMU guest agent**: enabled (VirtIO channel)
- **Boot order**: disk first, CDROM second (boots from ISO when disk is blank; boots from disk thereafter)

## Prerequisites

- Proxmox is installed and reachable on the LAN (see [Proxmox Setup](#proxmox-setup) above)
- An SSH agent is running with a key authorised for `root` on the Proxmox host — the `bpg/proxmox` provider uses SSH for ISO upload
- Node IPs are reserved as static DHCP leases in your router so they don't change between reboots
- The Nix shell is active (`nix shell` from the repo root), providing `terraform`, `talosctl`, and `kubectl`

## Configure

Copy the example vars file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` is gitignored. See [Saving your vars](#saving-your-vars).

### Example `terraform.tfvars`

```hcl
proxmox_node_name    = "pve"
proxmox_node_address = "192.168.1.10"

proxmox_iso_datastore  = "local"
proxmox_disk_datastore = "local-lvm"

talos_version = "v1.10.3"
cluster_name  = "talos-homelab"
cluster_vip   = "192.168.1.100"

nodes = {
  "controlplane-worker-1" = {
    vm_id       = 100
    pve_node    = "server-01"
    cpu_cores   = 4
    memory_mb   = 16384
    disk_gb     = 100
    ip_address  = "192.168.1.101"
    mac_address = "BC:24:11:xx:xx:xx" # Must match your router's static DHCP lease for this IP
  }
  "controlplane-worker-2" = {
    vm_id       = 101
    pve_node    = "server-02"
    cpu_cores   = 4
    memory_mb   = 16384
    disk_gb     = 100
    ip_address  = "192.168.1.102"
    mac_address = "BC:24:11:xx:xx:xx" # Must match your router's static DHCP lease for this IP
  }
}
```

**Node names are the Kubernetes hostnames.** Keep them stable across rebuilds — renaming or swapping node entries will cause Longhorn to detect a disk UUID mismatch and refuse to start. Add new nodes by adding new keys; never reorder or rename existing ones.

### Generating MAC Addresses

To generate a random MAC address with the Proxmox OUI prefix:

```bash
printf "BC:24:11:%02X:%02X:%02X\n" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
```

Copy the output into your `terraform.tfvars` file and configure a static DHCP lease in your router for that MAC address.

## Saving your vars

`terraform.tfvars` and `terraform.tfstate` are both gitignored because the state contains the cluster PKI (CA certs, keys, join tokens). If you lose either on a rebuild you will need to fully wipe and re-bootstrap.

Store both in a password manager as secure notes or file attachments.

## Set credentials

Export these before running any Terraform commands:

```bash
# Proxmox credentials
export PROXMOX_VE_ENDPOINT="https://192.168.1.10:8006"
export PROXMOX_VE_INSECURE="true"

export PROXMOX_VE_USERNAME="root@pam"
export PROXMOX_VE_PASSWORD="your-proxmox-password"

# External secrets (required)
export TF_VAR_cloudflare_tunnel_token="your-token-here"
export TF_VAR_github_app_private_key="$(cat /path/to/private-key.pem)"
```

## Bootstrap

> **Note:** If you have a saved backup of your cluster state, place the `terraform.tfstate` file in this directory before running the commands below. This preserves your cluster PKI (CA certs, keys, join tokens) and allows you to restore without a full rebuild.

```bash
terraform init
terraform apply
```

**Note:** You may need to run `terraform apply` 2-3 times for it to complete successfully. During bootstrap, Talos restarts the node after etcd bootstrap, causing the initial Helm Cilium installation to fail when the Kubernetes API isn't ready yet. Subsequent runs will succeed once the API comes back online.

Apply takes several minutes. The slow steps are the ISO download to Proxmox (~500 MB) and waiting for Talos to install to disk and reboot before the ISO detachment and config apply can proceed.

## Retrieve credentials

After `terraform apply` completes, credentials are automatically configured:

- **Talos config**: Written to `talosconfig.yaml` in this directory
- **Kubeconfig**: Merged into `~/.kube/config` (creates file if it doesn't exist, merges with existing contexts if it does)

```bash
# Use talosconfig from this directory
talosctl --talosconfig $(pwd)/talosconfig.yaml version

# Kubeconfig is already in the standard location
kubectl get nodes
```

**Note:** The kubeconfig merge preserves any existing contexts/clusters you have. The new cluster context will be added alongside them.

## Ongoing operations

### Upgrading Talos

Bump `talos_version` in `terraform.tfvars`, then:

```bash
terraform apply
```

This regenerates and re-applies machine configs (the `install.image` URL updates to the new version) but does **not** recreate VMs. The actual OS upgrade is then triggered node-by-node using the installer URL from state:

```bash
INSTALLER=$(terraform output -raw talos_installer_url)

talosctl upgrade --nodes 192.168.1.101 --image "$INSTALLER"
talosctl upgrade --nodes 192.168.1.102 --image "$INSTALLER"
```

Wait for each node to rejoin the cluster before upgrading the next.

### Adding a node

Add a new entry to `nodes` in `terraform.tfvars` with a unique `vm_id` and a reserved IP, then:

```bash
terraform apply
```

Terraform will create only the new VM and apply its config. Existing nodes are not touched.

### Tearing down

```bash
terraform destroy
```

This resets each node to Talos maintenance mode (graceful etcd leave, disk wipe, reboot) before removing the VMs from Proxmox. After destroy completes the machines are ready to be re-bootstrapped.

Save `terraform.tfstate` before destroying if you want to preserve the cluster PKI for a future rebuild with the same certificates.

## What to do next

After `terraform apply` completes, the cluster is running with Cilium CNI, ArgoCD, and a fully configured Vault. The following steps are required to fully operationalize the cluster:

### 1. Save Critical Files

**IMPORTANT**: The bootstrap process generates two critical files that must be backed up securely:

1. **`terraform.tfstate`** - Contains cluster PKI (CA certs, keys, tokens)
2. **`vault-init.json`** - Contains Vault unseal keys and root token

Both files are gitignored. Store them in your password manager or encrypted storage. Losing these files will require a complete cluster rebuild.

### 2. Set External Secrets

Some secrets require external credentials that cannot be auto-generated. These are provided via environment variables:

```bash
# Cloudflare tunnel token - see networking/cloudflared/README.md for how to generate
export TF_VAR_cloudflare_tunnel_token="your-token-here"

# GitHub App private key - see ci-cd/renovate/README.md for how to create the app and download the key
export TF_VAR_github_app_private_key="$(cat /path/to/private-key.pem)"
```

**How to obtain these credentials:**

- **Cloudflare tunnel token**: See `networking/cloudflared/README.md` for instructions on generating the token using the Cloudflare API
- **GitHub App private key**: See `ci-cd/renovate/README.md` for instructions on creating the GitHub App and downloading the private key

These environment variables are required. Terraform will fail if they are not set.

### 3. Verify External Secrets Operator

Once Vault secrets are populated, verify ESO is syncing them to Kubernetes:

```bash
# Check External Secrets
kubectl get externalsecrets -A

# Check synced secrets
kubectl get secrets -n harbor
kubectl get secrets -n monitoring
```

### 4. Harbor Configuration (Terraform)

After ESO has synced the Harbor secrets, apply the Harbor Terraform:

```bash
cd infrastructure/terraform
terraform apply -target=harbor_project.main
```

This creates Harbor projects, registries, users, and robot accounts using the secrets synced from Vault.

### 5. Access ArgoCD

Get the ArgoCD admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Access the UI at `https://argocd.okwilkins.dev`

### 6. Ongoing Operations

**Vault Unsealing**: After pod rescheduling, Vault will need to be unsealed using the keys from `vault-init.json`:

```bash
# Extract unseal keys from vault-init.json and unseal
for key in $(cat vault-init.json | jq -r '.unseal_keys_b64[]'); do
  kubectl exec -ti vault-0 -n vault -- vault operator unseal "$key"
done
```

**Secret Rotation**: Update Vault secrets as needed. ESO will automatically sync changes to Kubernetes.
