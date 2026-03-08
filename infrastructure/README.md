# Infrastructure

This directory contains all infrastructure configuration for the H8s (Homernetes) cluster.

## Bootstrap

OpenTofu configuration for bootstrapping a Talos Linux cluster on Proxmox from scratch.

The bootstrap process runs through 8 sequential stages, each managed by its own OpenTofu configuration:

1. **Talos Factory** (`00-talos-factory`) - Registers a custom extension schematic with the [Talos image factory](https://factory.talos.dev) and retrieves the ISO URL
2. **Proxmox ISO Upload** (`01-proxmox-iso-upload`) - Downloads the custom Talos ISO into Proxmox storage
3. **Proxmox Provision** (`02-proxmox-provision`) - Creates the VMs on Proxmox with proper configuration
4. **Talos Configure** (`03-talos-configure`) - Generates per-node machine configs, applies them, bootstraps etcd, and retrieves credentials
5. **Cilium Install** (`04-cilium`) - Installs Cilium CNI for networking
6. **ArgoCD Install** (`05-argocd`) - Installs ArgoCD for GitOps management
7. **Vault Init** (`06-vault-init`) - Initialises Vault and generates bootstrap outputs
8. **Vault Secrets** (`07-vault-resources-provision`) - Provisions all secrets in Vault (passwords, keys, external secrets)

All stages are orchestrated via a Taskfile. Run `task cluster:bootstrap` to execute the full sequence.

## Platform Configuration

The `platform-config/` directory contains Terraform configurations for managing platform-level resources that don't have mature Kubernetes operators, such as:

- **Harbor** - Container registry projects, users, robot accounts, and pull-through caches

See [platform-config/README.md](platform-config/README.md) for detailed setup instructions.

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

## Configure

Copy the example secrets file and fill in your values:

```bash
cp shared/secrets.auto.tfvars.example shared/secrets.auto.tfvars
```

`shared/secrets.auto.tfvars` is gitignored. See [Saving your vars](#saving-your-vars).

### Example Configuration

The `secrets.auto.tfvars` file contains all sensitive configuration including:
- Proxmox endpoint and credentials
- Talos cluster virtual IP
- Node definitions (VM IDs, IPs, MAC addresses)
- External secrets (Cloudflare tunnel token, GitHub App private key)

**Important notes:**
- Replace all placeholder values (e.g., `<PROXMOX_IP>`, `<YOUR_PROXMOX_PASSWORD>`, `<VIRTUAL_IP>`) with your actual values
- The `proxmox_node_name` must match the `pve_node` field of one of your nodes
- Generate MAC addresses using: `printf "BC:24:11:%02X:%02X:%02X\n" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))`
- Configure static DHCP leases in your router for each node's MAC address

**Node names are the Kubernetes hostnames.** Keep them stable across rebuilds — renaming or swapping node entries will cause Longhorn to detect a disk UUID mismatch and refuse to start. Add new nodes by adding new keys; never reorder or rename existing ones.

### Generating MAC Addresses

To generate a random MAC address with the Proxmox OUI prefix:

```bash
printf "BC:24:11:%02X:%02X:%02X\n" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
```

Copy the output into your `terraform.tfvars` file and configure a static DHCP lease in your router for that MAC address.

## Saving Your State

The bootstrap process generates critical files that must be backed up securely. Losing these files will require a complete cluster rebuild:

### 1. OpenTofu State Files (`states/` directory)

All OpenTofu state is stored in the `states/` directory, with separate files for each stage:
- `00-talos-factory.tfstate` - Talos image factory registration
- `01-proxmox-iso-upload` - ISO upload state
- `02-proxmox-provision` - VM provisioning state
- `03-talos-configure` - Talos configuration and cluster PKI (CA certs, keys, join tokens)
- `04-cilium` - Cilium CNI installation state
- `05-argocd` - ArgoCD installation state
- `06-vault-init` - Vault initialisation state
- `07-vault-resources-provision` - Vault secrets provisioning state

**The `03-talos-configure` state file is particularly critical** as it contains the cluster's PKI (Certificate Authority certificates, keys, and join tokens).

### 2. Credential Files (`03-talos-configure/secrets/` directory)

After bootstrap completes, credentials are written to:
- `03-talos-configure/secrets/talosconfig.yaml` - Talos configuration file
- `03-talos-configure/secrets/kubeconfig.yaml` - Kubernetes configuration file

### 3. Vault Initialisation File

During the Vault initialisation stage, a `vault-init.json` file is generated containing:
- Vault unseal keys
- Vault root token

### Backup Strategy

Store all files from `states/`, `03-talos-configure/secrets/`, and `vault-init.json` in your password manager or encrypted storage. These files are all gitignored and must be preserved for cluster recovery.


## Bootstrap

> **Note:** If you have a saved backup of your cluster state, restore the files from your backup into the `states/` directory before running the commands below. This preserves your cluster PKI (CA certs, keys, join tokens) and allows you to restore without a full rebuild.

Run the complete bootstrap sequence:

```bash
task cluster:bootstrap
```

This command executes all 7 stages in sequence:
1. Generates Talos schematic with custom extensions
2. Downloads Talos ISO to Proxmox nodes
3. Creates VMs on Proxmox
4. Configures Talos nodes, bootstraps etcd, and retrieves credentials
5. Installs Cilium CNI
6. Installs ArgoCD for GitOps
7. Initialises Vault and provisions secrets

Apply takes several minutes. The slow steps are the ISO download to Proxmox (~500 MB) and waiting for Talos to install to disk and reboot before the ISO detachment and config apply can proceed.

## Retrieve Credentials

After `task cluster:bootstrap` completes, credentials are written to the `03-talos-configure/secrets/` directory:

- **Talos config**: `03-talos-configure/secrets/talosconfig.yaml`
- **Kubeconfig**: `03-talos-configure/secrets/kubeconfig.yaml`

```bash
# Use talosconfig from the secrets directory
talosctl --talosconfig 03-talos-configure/secrets/talosconfig.yaml version

# Use kubeconfig from the secrets directory
kubectl --kubeconfig 03-talos-configure/secrets/kubeconfig.yaml get nodes
```

To use these credentials as your default configurations:

```bash
# Copy kubeconfig to default location (merges with existing contexts)
cp 03-talos-configure/secrets/kubeconfig.yaml ~/.kube/config

# Or set environment variables
export KUBECONFIG=$(pwd)/03-talos-configure/secrets/kubeconfig.yaml
export TALOSCONFIG=$(pwd)/03-talos-configure/secrets/talosconfig.yaml
```

**Note:** The kubeconfig merge preserves any existing contexts/clusters you have. The new cluster context will be added alongside them.

### Troubleshooting

#### Bootstrap fails at Cilium installation

If the bootstrap fails during the Cilium stage with errors about the Kubernetes API not being ready, this is normal. Talos restarts the node after etcd bootstrap, which can cause transient API unavailability. Simply run the bootstrap again:

```bash
task cluster:bootstrap
```

The process is idempotent and will skip already-completed stages.

#### VMs fail to boot from ISO

If VMs boot into the Proxmox UEFI shell instead of the Talos ISO:
1. Check that the ISO was uploaded successfully to the correct datastore
2. Verify the VM's boot order is set correctly (disk first, CDROM second)
3. Ensure the ISO is attached to the VM's CDROM drive

#### SSH authentication fails during ISO upload

The `bpg/proxmox` provider requires SSH access to upload the ISO. Ensure:
1. Your SSH agent is running: `eval $(ssh-agent -s)`
2. Your key is added: `ssh-add ~/.ssh/id_rsa`
3. You can SSH to the Proxmox host as root without password: `ssh root@<proxmox-ip>`

#### Talos nodes not joining the cluster

If nodes fail to join after configuration:
1. Check node network connectivity: `ping <node-ip>`
2. Verify static DHCP leases are correctly configured in your router
3. Check Talos logs: `talosctl --talosconfig 03-talos-configure/secrets/talosconfig.yaml logs --nodes <node-ip>`
4. Ensure MAC addresses in your configuration match the router's static leases

#### Vault fails to initialise

If Vault initialisation fails:
1. Check that the Kubernetes API is accessible: `kubectl --kubeconfig 03-talos-configure/secrets/kubeconfig.yaml get nodes`
2. Verify Cilium is running: `kubectl --kubeconfig 03-talos-configure/secrets/kubeconfig.yaml get pods -n kube-system`
3. Check Vault pod logs: `kubectl --kubeconfig 03-talos-configure/secrets/kubeconfig.yaml logs -n vault vault-0`

### Set External Secrets

**How to obtain these credentials:**
- **Cloudflare tunnel token**: See `networking/cloudflared/README.md` for instructions on generating the token using the Cloudflare API
- **GitHub App private key**: See `ci-cd/renovate/README.md` for instructions on creating the GitHub App and downloading the private key

These environment variables are required. Terraform will fail if they are not set.

### Access ArgoCD

Get the ArgoCD admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Access the UI at `https://argocd.okwilkins.dev`

### Ongoing Operations

**Vault Unsealing**: After pod rescheduling, Vault will need to be unsealed using the keys from `vault-init.json`:

```bash
# Extract unseal keys from vault-init.json and unseal
for key in $(cat vault-init.json | jq -r '.unseal_keys_b64[]'); do
  kubectl exec -ti vault-0 -n vault -- vault operator unseal "$key"
done
```

**Secret Rotation**: Update Vault secrets as needed. ESO will automatically sync changes to Kubernetes.

