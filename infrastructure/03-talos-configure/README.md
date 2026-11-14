# Talos Configuration

## Rootless Buildah Seccomp Profile

Stage `03` installs `buildah.json` on every node at `/var/lib/kubelet/seccomp/profiles/buildah.json`.

[`seccomp-containerd-2.3.7-amd64.json`](seccomp-containerd-2.3.7-amd64.json) is a RuntimeDefault snapshot from an unprivileged Argo container on Talos 1.14.3, containerd 2.3.7 and kernel 6.18.56 (AMD64).
See the [containerd policy](https://github.com/containerd/containerd/blob/v2.3.7/contrib/seccomp/seccomp_default.go).

`main.tf` adds mount/chroot, namespace entry and user/mount/UTS namespace creation allowances while retaining default-deny and the `clone3` ENOSYS fallback.
Refresh the snapshot when upgrading containerd/kernel or changing the builder's architecture/capabilities.

After review and installation, select `type: Localhost` with `localhostProfile: profiles/buildah.json` only on the workflow's build container.
