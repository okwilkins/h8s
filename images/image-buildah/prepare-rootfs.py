"""
Build-only rootfs assembly using the builder's Nix and coreutils.

Derived from here:
https://github.com/podman-container-tools/image_build/blob/78f87b85f3d52c35afa12777e9a76f17d441f7fd/buildah/Containerfile
"""

import os
import shutil
from pathlib import Path
from textwrap import dedent

from rootfs import parse_arguments, prepare_base_rootfs


def subordinate_ids(user: str, identifier: int) -> str:
    entries = ["root:1:65535"]

    if identifier > 1:
        entries.append(f"{user}:1:{identifier - 1}")
    if identifier < 65535:
        entries.append(f"{user}:{identifier + 1}:{65535 - identifier}")

    return "\n".join(entries) + "\n"


def write_configuration(rootfs: Path, user: str, uid: int, gid: int) -> None:
    files: dict[str, str] = {
        "containers/containers.conf": (
            '[engine]\ncgroup_manager = "cgroupfs"\n'
        ),
        "containers/registries.conf": (
            'unqualified-search-registries = ["docker.io"]\n'
        ),
        "containers/policy.json": (
            '{"default":[{"type":"insecureAcceptAnything"}]}\n'
        ),

        # VFS avoids FUSE device access in build pods.
        "containers/storage.conf": f"""
            [storage]
            driver = "vfs"
            graphroot = "/home/{user}/.local/share/containers/storage"
            rootless_storage_path = "/home/{user}/.local/share/containers/storage"
            runroot = "/run/user/{uid}/containers"
        """,

        "subuid": subordinate_ids(user, uid),
        "subgid": subordinate_ids(user, gid),
    }

    for name, content in files.items():
        path = rootfs / "etc" / name
        path.write_text(dedent(content).lstrip("\n"), encoding="utf-8")
        path.chmod(0o644)


def prepare_rootfs(rootfs: Path, user: str, uid: int, gid: int) -> None:
    tools = prepare_base_rootfs(rootfs, user, uid, gid, shell="/bin/sh")

    directories = (
        "bin",
        "etc/containers",
        "var/tmp",

        f"home/{user}/.local/share/containers",
        f"run/user/{uid}",
    )

    for directory in directories:
        (rootfs / directory).mkdir(parents=True, exist_ok=True)

    (rootfs / "var/tmp").chmod(0o1777)

    home = rootfs / "home" / user
    runtime = rootfs / "run/user" / str(uid)

    runtime.chmod(0o700)
    for path in (home, *home.rglob("*"), runtime):
        os.chown(path, uid, gid, follow_symlinks=False)

    links: dict[str, str | Path] = {
        "bin/sh": "/opt/tools/bin/sh",
        "usr/local/bin/fuse-overlayfs": "/opt/tools/bin/fuse-overlayfs",
    }

    for name, target in links.items():
        (rootfs / name).symlink_to(target)

    # Mapping helpers need real copies outside the store for file capabilities.
    for name in ("newuidmap", "newgidmap"):
        path = rootfs / "usr/local/bin" / name
        shutil.copy2((tools / "bin" / name).resolve(strict=True), path)
        path.chmod(0o755)

    write_configuration(rootfs, user, uid, gid)


def main() -> None:
    args = parse_arguments()

    prepare_rootfs(
        args.destination,
        args.build_user,
        args.build_uid,
        args.build_gid,
    )


if __name__ == "__main__":
    main()
