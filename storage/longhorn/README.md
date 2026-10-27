# Longhorn

Longhorn is a distributed block storage system for Kubernetes. Longhorn is cloud-native storage built using Kubernetes and container primitives.

![alt](https://longhorn.io/img/diagrams/architecture/how-longhorn-works.svg)

## Encrypted Backups to B2

Store these in `h8s-secrets/secrets.yaml` using SOPS:

- `TF_VAR_longhorn_backup_access_key_id`
- `TF_VAR_longhorn_backup_secret_access_key`
- `TF_VAR_longhorn_encryption_key`

**IMPORTANT**: Keep the encryption key in a password manager too!

For `h8s-longhorn-backups`, select B2's **Keep only the last version of the file**, without expiry for active objects.
Longhorn manages the lifecycle of data, not B2.

From the repository root:

```bash
nix develop .#infra --command "$SHELL"
tofu -chdir="$INFRA_ROOT/05-argocd" apply
```

Commit and push for Argo CD to deploy the configuration.
Use `longhorn-encrypted` for encrypted volumes and backups.

## Restore a Backup

When the original volume, PV and PVC are gone, configure the B2 backup target and restore the original encryption key.
Keep the application's Argo sync paused until its restored PVC is bound.

1. Port-forward the Longhorn UI.
2. Open **Backup and Restore → Backups**, select the **Completed** backup you want and click **Restore**.
3. Keep the pre-filled volume name, `v1`, `ReadWriteOnce` and `2 Mi` defaults. Set **Number of Replicas** to `2` (or what ever number of replicas is current), tick **Encrypted**, then click **OK** and wait for the restore to finish.
4. Open the restored volume and choose **Create PV/PVC**:

   | Field | Value |
   |---|---|
   | PV Name | Keep the pre-filled name |
   | Secret Namespace | `longhorn-system` |
   | Secret Name | `longhorn-crypto` |
   | Storage Class Name | `longhorn-encrypted` |
   | File System | `Ext4` |
   | Create PVC / Use Previous PVC | Leave both ticked |
   | PVC Name / Namespace | Check the pre-filled values match the application |

   These names and checkboxes are filled in automatically from the backup. Click **OK** to create the PV and PVC.
4. Confirm the PVC is **Bound** to the restored PV, resume the application's Argo sync and check its data.
