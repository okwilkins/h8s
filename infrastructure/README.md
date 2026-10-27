# Infrastructure

This directory contains all infrastructure configuration for the cluster.

## Bootstrap

OpenTofu configuration for bootstrapping a Talos Linux cluster on Proxmox from scratch.

The bootstrap process runs through 9 sequential stages, each managed by its own OpenTofu configuration. Stages 1-8 are automated via `task cluster:bootstrap`. Stage 9 (Platform Configuration) must be run manually after bootstrap completes.

1. **Talos Factory** (`00-talos-factory`) - Registers a custom extension schematic with the [Talos image factory](https://factory.talos.dev) and retrieves the ISO URL
2. **Proxmox ISO Upload** (`01-proxmox-iso-upload`) - Downloads the custom Talos ISO into Proxmox storage
3. **Proxmox Provision** (`02-proxmox-provision`) - Creates the VMs on Proxmox with proper configuration
4. **Talos Configure** (`03-talos-configure`) - Generates per-node machine configs, applies them, bootstraps etcd, and retrieves credentials
5. **Cilium Install** (`04-cilium`) - Installs Cilium CNI for networking
6. **ArgoCD Install** (`05-argocd`) - Installs ArgoCD for GitOps management
7. **Vault Init** (`06-vault-init`) - Initialises Vault and generates bootstrap outputs
8. **Vault Secrets** (`07-vault-resources-provision`) - Provisions all secrets in Vault (passwords, keys, external secrets)
9. **Platform Configuration** (`platform-config/`) - Configures Harbor registry and other platform resources (run manually after bootstrap via `task platform:configure`)

All stages are orchestrated via a Taskfile. Run `task cluster:bootstrap` to execute stages 1-8, then run `task platform:configure` for stage 9.

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

Proxmox VE is the bare-metal Type-1 hypervisor running on each physical machine. It hosts VMs running Talos Linux, which form the Kubernetes cluster.

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

Terraform automatically registers the customisation schematic with the [Talos image factory](https://factory.talos.dev) and downloads the resulting ISO into each Proxmox node's local storage.
The following extensions are baked in:

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
- **Boot order**: disk first, CDROM second (boots from ISO when disk is blank and from disk thereafter)

## Prerequisites

- Proxmox is installed and reachable on the LAN (see [Proxmox Setup](#proxmox-setup) above)
- An SSH agent is running with a key authorised for `root` on the Proxmox host — the `bpg/proxmox` provider uses SSH for ISO upload
- Node IPs are reserved as static DHCP leases in your router so they don't change between reboots

## Configure

Clone the private `h8s-secrets` repo alongside this repo.
Edit `secrets.yaml` in the sibling secrets repo's Nix shell, following its README.
From the H8s repo root, all infrastructure tools and secrets can be accessed with:

```bash
nix develop .#infra --command "$SHELL"
```

### Example Configuration

The encrypted `TF_VAR_*` entries supply sensitive configuration including:
- Proxmox endpoint and credentials
- Talos cluster virtual IP
- Node definitions (VM IDs, IPs, MAC addresses)
- External secrets (Cloudflare tunnel token, GitHub App private key)

**Important notes:**
- Replace all placeholder values (e.g., `<PROXMOX_IP>`, `<YOUR_PROXMOX_PASSWORD>`, `<VIRTUAL_IP>`) with your actual values
- The `proxmox_node_name` must match the `pve_node` field of one of your nodes
- Generate MAC addresses using: `printf "BC:24:11:%02X:%02X:%02X\n" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))`
- Configure static DHCP leases in your router for each node's MAC address

**Node names are the Kubernetes hostnames.** Keep them stable across rebuilds, renaming or swapping node entries will cause Longhorn to detect a disk UUID mismatch and refuse to start. Add new nodes by adding new keys. Never reorder or rename existing ones.

### Generating MAC Addresses

To generate a random MAC address with the Proxmox OUI prefix:

```bash
printf "BC:24:11:%02X:%02X:%02X\n" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
```

Set the MAC address in the encrypted `TF_VAR_nodes` value and configure a static DHCP lease in your router.

## Saving State

Encrypted OpenTofu state holds the generated cluster credentials and Vault recovery material.
Preserve access to the B2 bucket and the state encryption passphrase in the private secrets repo.

### 1. OpenTofu State in B2

Bootstrap stages `00`–`07` are configured to use bucket `h8s-terraform-backend` at `https://s3.eu-central-003.backblazeb2.com`, each under `h8s/bootstrap/<stage>/terraform.tfstate`.

OpenTofu encrypts state and saved plans with AES-GCM before storage. State and plan encryption is enforced.
B2 also has server-side encryption and keeps versions.

**IMPORTANT**: Native locking is disabled because B2 does not support the conditional writes it requires.
Run only one infrastructure operation at a time across your laptop and pipelines.
When Argo workflows are added, give them a shared mutex to serialise runs.

The `platform-config` backend uses the same encrypted B2 bucket at `h8s/platform-config/terraform.tfstate`.

Inside the infrastructure shell, run OpenTofu directly:

```bash
tofu -chdir="$INFRA_ROOT/02-proxmox-provision" plan
```

**The `03-talos-configure` state file is particularly critical** as it contains the cluster's PKI (Certificate Authority certificates, keys, and join tokens).

### 2. Recovery Credentials

Stage `03` exposes sensitive `kubeconfig` and `talosconfig` outputs.
Stage `06` exposes the complete original Vault initialisation JSON as the sensitive `vault_credentials` output, including its unseal keys and root token.
Keep an independent copy of the Vault recovery JSON.

## Bootstrap

> **Important:** Run bootstrap commands inside the shell opened by `nix develop .#infra --command "$SHELL"`.
> This provides the tools, secrets and environment variables required by the commands below.

> **Note:** Connect to the existing B2 state before running bootstrap.
> Restoring the existing state preserves cluster PKI and resource identities.
> Starting with empty state can attempt to recreate existing infrastructure.

Run the complete bootstrap sequence:

```bash
task --dir "$INFRA_ROOT" cluster:bootstrap
```

This command executes all 7 stages in sequence:
1. Generates Talos schematic with custom extensions
2. Downloads Talos ISO to Proxmox nodes
3. Creates VMs on Proxmox
4. Configures Talos nodes, bootstraps etcd, and retrieves credentials
5. Installs Cilium CNI
6. Installs ArgoCD for GitOps
7. Configures Vault and provisions secrets, after manual initialisation and unsealing if required

Apply takes several minutes. The slow steps are the ISO download to Proxmox (~500 MB) and waiting for Talos to install to disk and reboot before the ISO detachment and config apply can proceed.

On a fresh installation, stage `06` stops until Vault has been initialised and unsealed.
Follow [Fresh Vault Initialisation](#fresh-vault-initialisation), then rerun bootstrap.

### Complete the Setup

Once `task cluster:bootstrap` completes successfully:

1. **Configure kubectl** - Follow the instructions in [Retrieve Credentials](#retrieve-credentials) to configure kubectl for normal use
2. **Wait for ArgoCD sync** - Allow ArgoCD time to deploy Harbor and its credentials
3. **Configure platform resources** - Run the platform configuration to set up Harbor:

   ```bash
   task --dir "$INFRA_ROOT" platform:configure
   ```

> **Note:** The `platform:configure` task requires Harbor and its credentials to be available.

### Tailscale

#### Tailscale LAN Access

If enabling the Talos Tailscale extension config, there are two extra manual steps required before devices on the tailnet can reach LAN-only services such as `https://argocd.okwilkins.dev` or LAN IPs.

1. Configure one Talos node to advertise the LAN subnet, for example `tailscale_routes = ["192.168.100.0/24"]`.
2. Apply the Talos config changes by re-running the `03-talos-configure` Terraform apply, then restart the extension.
3. In the Tailscale admin console, approve the advertised subnet route.
4. In Tailscale DNS settings, add the in-cluster CoreDNS listener (`192.168.1.120`) as a **global nameserver** and enable **Override DNS servers**. This replaces the old split-DNS approach. It makes CoreDNS resolve every tailnet query, including ad-blocking.

> **Note:** If clients use the exit nodes, also enable **Use with exit node** on the nameserver (DNS page → ⋯ → Edit nameserver), otherwise exit-node clients fall back to the exit node's own resolvers and internal hostnames fail to resolve.

#### Tailscale Exit Nodes

Control plane nodes can advertise themselves as Tailscale exit nodes, letting tailnet clients route all their internet traffic through the cluster's LAN.

1. Set `tailscale_exit_node = true` on the control plane nodes in the encrypted `TF_VAR_nodes` value.
2. Apply the Talos config changes by re-running the `03-talos-configure` Terraform apply.
3. In the Tailscale admin console, approve "Use as exit node" on each advertised node.
4. Keep the default allow-all grant in the tailnet policy file (`src: ["*"]`, `dst: ["*"]`) - this also grants exit node use to every tailnet device. To track which clients may use exit nodes, tag them and add the grant below (note: with allow-all present the tag is informational, not enforced):
   ```json
   {
     "grants": [
       { "src": ["*"], "dst": ["*"], "ip": ["*"] },
       { "src": ["tag:exitnode-client"], "dst": ["autogroup:internet"], "ip": ["*"] }
     ],
     "tagOwners": { "tag:exitnode-client": ["autogroup:admin"] }
   }
   ```
   Tag the devices that should use exit nodes with `tag:exitnode-client`.
   To strictly enforce tagged-only exit node use, replace `dst: ["*"]` with explicit ranges (`192.168.1.0/24`, `10.244.0.0/16`, `100.64.0.0/10`) - grants have no "except internet" form, so allow-all and restriction are mutually exclusive.

Exit node traffic exits from the cluster's public IP. Tailnet clients have no access to the cluster LAN by default (unless they enable "Allow Local Network Access" client-side), and Talos enables IPv4 forwarding out of the box, so no sysctl changes are required.

#### Applying Tailscale Configuration Changes

Tailscale settings are split across two files:

- The encrypted `TF_VAR_nodes` value in `h8s-secrets` - per-node `tailscale_authkey`, `tailscale_routes`, `tailscale_exit_node`.
- `shared/variables.tf` - `tailscale_accept_dns` (cluster-wide, default `false`).

When you change any of these values:

1. Re-apply the Talos config: `task talos:configure:install`. Talos automatically restarts the `ext-tailscale` extension service when the `ExtensionServiceConfig` changes, and containerboot re-runs `tailscale up` on every start (this requires the auth key to be **reusable** — a single-use key will fail after the first login).
2. Verify the change was applied:
   - `talosctl ... get extensionserviceconfig tailscale -n runtime -o yaml` - shows the env vars on the node
   - `talosctl ... logs ext-tailscale` - shows the `tailscale up` invocation with the new flags
   - Tailscale admin console - approve new subnet routes or exit nodes

## Retrieve Credentials

Keep using your existing user-managed configurations for normal `kubectl` and `talosctl` commands.
For optional temporary access or recovery, fetch a client configuration from state into a subshell variable and pass it through a process substitution.
Each configuration disappears when its command finishes, and standard input remains available for interactive commands.

```bash
(
  talosconfig="$(tofu -chdir="$INFRA_ROOT/03-talos-configure" output -raw talosconfig)" || exit 1
  talosctl --talosconfig <(printf '%s' "$talosconfig") version
)

(
  kubeconfig="$(tofu -chdir="$INFRA_ROOT/03-talos-configure" output -raw kubeconfig)" || exit 1
  kubectl --kubeconfig <(printf '%s' "$kubeconfig") get nodes
)
```

### Troubleshooting

#### Bootstrap fails at Cilium installation

If the bootstrap fails during the Cilium stage with errors about the Kubernetes API not being ready, this is normal.
Talos restarts the node after etcd bootstrap, which can cause transient API unavailability.
Simply run the bootstrap again:

```bash
task --dir "$INFRA_ROOT" cluster:bootstrap
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
3. Use the state-backed Talos command above with `logs --nodes <node-ip> kubelet` in place of `version`
4. Ensure MAC addresses in your configuration match the router's static leases

#### Vault fails to initialise

If Vault initialisation fails:
1. Check that the Kubernetes API is accessible using the state-backed `kubectl get nodes` command above
2. Repeat that command with `get pods -n kube-system` to verify Cilium
3. Repeat it with `logs -n vault vault-0` to inspect Vault

#### Cilium GatewayClass fails on initial cluster setup

The Cilium GatewayClass resource often fails to be created properly during the initial cluster bootstrap. If you see errors related to GatewayClass not being ready or missing:

1. Delete the existing GatewayClass:
   ```bash
   (
     kubeconfig="$(tofu -chdir="$INFRA_ROOT/03-talos-configure" output -raw kubeconfig)" || exit 1
     kubectl --kubeconfig <(printf '%s' "$kubeconfig") delete gatewayclass cilium
   )
   ```

2. Let ArgoCD recreate it by syncing the application

3. For added reliability, restart the Cilium pods:
   ```bash
   (
     kubeconfig="$(tofu -chdir="$INFRA_ROOT/03-talos-configure" output -raw kubeconfig)" || exit 1
     kubectl --kubeconfig <(printf '%s' "$kubeconfig") rollout restart deployment -n kube-system cilium-operator
     kubectl --kubeconfig <(printf '%s' "$kubeconfig") rollout restart daemonset -n kube-system cilium
   )
   ```

### Set External Secrets

**How to obtain these credentials:**
- **Cloudflare tunnel token**: See `networking/cloudflared/README.md` for instructions on generating the token using the Cloudflare API
- **GitHub App private key**: See `ci-cd/renovate/README.md` for instructions on creating the GitHub App and downloading the private key

These environment variables are required. Terraform will fail if they are not set.

### Access ArgoCD

ArgoCD is accessible at `https://argocd.okwilkins.dev`. Login is via Authelia SSO only — the local `admin` account is disabled.

If OIDC is unavailable (e.g. Authelia is down), use [core mode](https://argo-cd.readthedocs.io/en/stable/operator-manual/core/#using) to bypass the ArgoCD API server.
The first command sets your current kubeconfig context's default namespace to `argocd`.

```bash
argocd login --core
argocd app list
argocd app sync <app-name>
```

### Ongoing Operations

**Vault Unsealing**: Run this manually when Vault is sealed, using the required number of distinct keys from encrypted state.
Normal bootstrap and scheduled operations do not initialise or unseal Vault.

```bash
(
  kubeconfig="$(tofu -chdir="$INFRA_ROOT/03-talos-configure" output -raw kubeconfig)" || exit 1
  credentials="$(tofu -chdir="$INFRA_ROOT/06-vault-init" output -json vault_credentials)" || exit 1

  for index in $(jq -er 'range(.unseal_threshold)' <<<"$credentials"); do
    key="$(jq -er --argjson index "$index" '.unseal_keys_b64[$index]' <<<"$credentials")" || exit 1
    kubectl --kubeconfig <(printf '%s' "$kubeconfig") exec -n vault vault-0 -- vault operator unseal "$key" >/dev/null || exit 1
  done
)
```

**Secret Rotation**: Update Vault secrets as needed. ESO will automatically sync changes to Kubernetes.

## Upgrading Talos

Change `talos_version` in `shared/common.auto.tfvars` and run the pipeline:

```bash
task --dir "$INFRA_ROOT" cluster:bootstrap
```

## Extracting the Vault CA Certificate

Vault acts as the cluster's internal Certificate Authority. To trust certificates issued by Vault in your browser, you need to extract the CA certificate:

```bash
(
  credentials="$(tofu -chdir="$INFRA_ROOT/06-vault-init" output -json vault_credentials)" || exit 1
  token="$(jq -er '.root_token' <<<"$credentials")" || exit 1
  kubectl exec -n vault vault-0 -- \
    env VAULT_TOKEN="$token" vault read -field=certificate pki/cert/ca > vault-ca-cert.pem
)
```

`vault-ca-cert.pem` contains the public CA certificate and can be installed in your trust store.
