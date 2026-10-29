# CloudNative PG

CloudNativePG is an open-source operator designed to manage PostgreSQL workloads on any supported Kubernetes cluster. It supports deployment in private, public, hybrid, and multi-cloud environments, thanks to its distributed topology feature.

This part of the repo also houses definitions for each server and tables.

## Restore a Database

1. Keep `cloudnative-pg-resources` and the affected application's Argo sync paused.
2. Create its `Cluster` with `cnpg.io/reconciliationLoop: disabled` already set in `metadata.annotations`.
3. [Restore its Longhorn volume and PV/PVC](../longhorn/README.md#restore-a-backup) using the original namespace and claim name. Wait for the PVC to be **Bound**.
4. Edit the restored PVC before enabling CNPG:

   | Metadata | Value |
   |---|---|
   | Label `cnpg.io/cluster` | Original Cluster name |
   | Label `cnpg.io/instanceName` | Original instance name, matching the data PVC |
   | Label `cnpg.io/pvcRole` | `PG_DATA` |
   | Labels `cnpg.io/instanceRole` and `role` | `primary` |
   | Annotation `cnpg.io/nodeSerial` | Original instance serial, such as `"1"` |
   | Annotation `cnpg.io/pvcStatus` | `ready` |

   Replace old `ownerReferences` with a controller reference to the **new** Cluster UID:

   ```yaml
   ownerReferences:
     - apiVersion: postgresql.cnpg.io/v1
       kind: Cluster
       name: CLUSTER
       uid: NEW_CLUSTER_UID
       controller: true
   ```

   Get that UID with `kubectl -n NAMESPACE get cluster CLUSTER -o jsonpath='{.metadata.uid}'`.
5. Select the restored instance as primary, then enable reconciliation:

   ```bash
   kubectl -n NAMESPACE patch cluster CLUSTER --subresource=status --type=merge -p '{"status":{"targetPrimary":"INSTANCE"}}'
   kubectl -n NAMESPACE annotate cluster CLUSTER cnpg.io/reconciliationLoop-
   ```

Wait for the Cluster to become **Ready**, check the application data, then resume Argo sync.
This single-instance recovery was tested with CNPG 1.30.1 by recreating the Cluster and PVC and checking that the original data and PostgreSQL system identifier survived.
