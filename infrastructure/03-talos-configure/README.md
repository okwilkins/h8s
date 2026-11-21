# Talos Configuration

## Upgrades

Check the [Talos support matrix](https://docs.siderolabs.com/talos/latest/getting-started/support-matrix). Change either `talos_version` or `kubernetes_version` in [`shared/common.auto.tfvars`](../shared/common.auto.tfvars), then run `tofu apply` from this directory in the [infrastructure shell](../README.md#configure).

Talos upgrades drain one node at a time and stop on failure. If Longhorn blocks a drain, let it restore healthy replicas before retrying.

## Rootless Buildah Seccomp Profile

Stage `03` installs `buildah.json` on every node at `/var/lib/kubelet/seccomp/profiles/buildah.json`.

[`seccomp-containerd-2.3.7-amd64.json`](seccomp-containerd-2.3.7-amd64.json) is a RuntimeDefault snapshot from an unprivileged Argo container on Talos 1.14.3, containerd 2.3.7 and kernel 6.18.56 (AMD64).
See the [containerd policy](https://github.com/containerd/containerd/blob/v2.3.7/contrib/seccomp/seccomp_default.go).

`main.tf` adds mount/chroot, namespace entry and user/mount/UTS namespace creation allowances while retaining default-deny and the `clone3` ENOSYS fallback.
Refresh the snapshot when upgrading containerd/kernel or changing the builder's architecture/capabilities.

After review and installation, select `type: Localhost` with `localhostProfile: profiles/buildah.json` only on the workflow's build container.
