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

This replaces the old `scripts/gen_configs.sh` + `scripts/apply_configs.sh` bash workflow.

It does **not** install Cilium, ArgoCD, or any cluster workloads — see [What to do next](#what-to-do-next).

## Prerequisites

- Proxmox is installed and reachable on the LAN
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

Store both in a password manager (e.g. 1Password, Bitwarden, or KeePassXC) as secure notes or file attachments:

```bash
# Copy tfvars content into a secure note, or attach the file directly.
# For state - do this after every apply:
cat terraform.tfstate  # paste into secure note
# or attach the file if your password manager supports attachments
```

Alternatively, use an encrypted archive:

```bash
# Save
tar czf - terraform.tfvars terraform.tfstate | age -r <your-age-public-key> > bootstrap-secrets.age
# Restore
age -d bootstrap-secrets.age | tar xz
```

The bare minimum to save is `terraform.tfstate` — the tfvars can be reconstructed from memory/notes but the state PKI cannot.

## Set credentials

Export these before running any Terraform commands:

```bash
export PROXMOX_VE_ENDPOINT="https://192.168.1.10:8006"
export PROXMOX_VE_INSECURE="true"

export PROXMOX_VE_USERNAME="root@pam"
export PROXMOX_VE_PASSWORD="your-proxmox-password"
```

## Bootstrap

> **Note:** If you have a saved backup of your cluster state, place the `terraform.tfstate` file in this directory before running the commands below. This preserves your cluster PKI (CA certs, keys, join tokens) and allows you to restore without a full rebuild.

```bash
terraform init
terraform apply
```

Apply takes several minutes. The slow steps are the ISO download to Proxmox (~500 MB) and waiting for Talos to install to disk and reboot before the ISO detachment and config apply can proceed.

## Retrieve credentials

Both outputs are marked sensitive so they are not printed automatically. Write them after apply completes:

```bash
# kubeconfig - WARNING: overwrites your current context
terraform output -raw kubeconfig > ~/.kube/config

# talosconfig - merges with any existing config
terraform output -raw talosconfig > /tmp/talosconfig \
  && talosctl config merge /tmp/talosconfig \
  && rm /tmp/talosconfig

# Verify
kubectl get nodes
talosctl --nodes 192.168.1.101 version
```

## What to do next

The cluster is running but has no CNI — pods will not schedule until Cilium is installed.

1. Install Cilium — see [`networking/cilium/README.md`](../../networking/cilium/README.md)
2. Install ArgoCD — see [`ci-cd/argocd/README.md`](../../ci-cd/argocd/README.md). ArgoCD will then reconcile the rest of the cluster from git.
3. Populate Vault secrets — search the repo for `ExternalSecret` manifests to find what needs adding.

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

