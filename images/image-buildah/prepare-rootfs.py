"""
Build-only rootfs assembly using the builder's Nix and coreutils.

Derived from here:
https://github.com/podman-container-tools/image_build/blob/78f87b85f3d52c35afa12777e9a76f17d441f7fd/buildah/Containerfile
"""

import argparse
import os
import re
import shutil
import subprocess
from pathlib import Path
from textwrap import dedent


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

        # Copy & modify the system-wide defaults: use fuse-overlay storage.
        "containers/storage.conf": """
            [storage]
            driver = "overlay"
            [storage.options.overlay]
            mount_program = "/usr/local/bin/fuse-overlayfs"
            mountopt = "nodev,fsync=0"
        """,

        "passwd": (
            "root:x:0:0:root:/root:/bin/sh\n"
            f"{user}:x:{uid}:{gid}:{user} container user:"
            f"/home/{user}:/bin/sh\n"
        ),
        "group": f"root:x:0:\n{user}:x:{gid}:\n",

        "subuid": subordinate_ids(user, uid),
        "subgid": subordinate_ids(user, gid),
    }

    for name, content in files.items():
        path = rootfs / "etc" / name
        path.write_text(dedent(content).lstrip("\n"), encoding="utf-8")
        path.chmod(0o644)


def prune_locale_data(store: Path) -> None:
    for package in store.iterdir():
        share = package / "share"

        # Absolute store symlinks still point into the builder's original store.
        if package.is_symlink() or share.is_symlink() or not share.is_dir():
            continue

        for name in ("locale", "i18n"):
            path = share / name

            if path.is_symlink():
                path.unlink()
            elif path.is_dir():
                shutil.rmtree(path)


def prepare_rootfs(rootfs: Path, user: str, uid: int, gid: int) -> None:
    tools = Path("result").resolve(strict=True)
    os.umask(0o022)
    rootfs.mkdir(parents=True)  # Refuse to overwrite an existing rootfs.

    directories = (
        "bin",
        "etc/containers",
        "etc/ssl/certs",
        "nix/store",
        "opt",
        "tmp",
        "usr/local/bin",
        "var/tmp",

        f"home/{user}/.local/share/containers",
        f"run/user/{uid}",
    )

    for directory in directories:
        (rootfs / directory).mkdir(parents=True, exist_ok=True)

    for directory in ("tmp", "var/tmp"):
        (rootfs / directory).chmod(0o1777)

    home = rootfs / "home" / user
    runtime = rootfs / "run/user" / str(uid)

    runtime.chmod(0o700)
    for path in (home, *home.rglob("*"), runtime):
        os.chown(path, uid, gid, follow_symlinks=False)

    closure: list[str] = subprocess.check_output(
        ["nix-store", "--query", "--requisites", str(tools)],
        text=True,
    ).splitlines()

    subprocess.run(
        ["cp", "-a", "--", *closure, str(rootfs / "nix/store")],
        check=True,
    )

    # Remove copied translations and locale sources, keeping lib/locale intact.
    prune_locale_data(rootfs / "nix/store")

    links: dict[str, str | Path] = {
        "opt/tools": tools,
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

    certificate = rootfs / "etc/ssl/certs/ca-certificates.crt"
    shutil.copy2("/etc/ssl/certs/ca-certificates.crt", certificate)
    certificate.chmod(0o644)

    write_configuration(rootfs, user, uid, gid)


def main() -> None:
    parser = argparse.ArgumentParser()

    parser.add_argument("destination", type=Path)
    parser.add_argument("build_user")
    parser.add_argument("build_uid", type=int)
    parser.add_argument("build_gid", type=int)

    args = parser.parse_args()

    if os.geteuid() != 0:
        parser.error("run as root in the image's builder stage")

    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.-]*[$]?", args.build_user):
        parser.error("build_user must be a valid account name")

    for identifier in (args.build_uid, args.build_gid):
        if not 1 <= identifier <= 65535:
            parser.error("build UID and GID must be between 1 and 65535")

    prepare_rootfs(
        args.destination.absolute(),
        args.build_user,
        args.build_uid,
        args.build_gid,
    )


if __name__ == "__main__":
    main()
