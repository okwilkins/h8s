"""Shared build-only rootfs assembly using Nix and coreutils."""

import argparse
import os
import re
import shutil
import subprocess
from pathlib import Path


def parse_arguments() -> argparse.Namespace:
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

    args.destination = args.destination.absolute()
    return args


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


def prepare_base_rootfs(
    rootfs: Path, user: str, uid: int, gid: int, *, shell: str
) -> Path:
    tools = Path("result").resolve(strict=True)
    os.umask(0o022)
    rootfs.mkdir(parents=True)  # Refuse to overwrite an existing rootfs.

    for directory in (
        "etc/ssl/certs",
        "nix/store",
        "opt",
        "tmp",
        "usr/local/bin",
        f"home/{user}",
    ):
        (rootfs / directory).mkdir(parents=True, exist_ok=True)

    (rootfs / "tmp").chmod(0o1777)
    os.chown(rootfs / "home" / user, uid, gid)

    closure: list[str] = subprocess.check_output(
        ["nix-store", "--query", "--requisites", str(tools)],
        text=True,
    ).splitlines()
    subprocess.run(
        ["cp", "-a", "--", *closure, str(rootfs / "nix/store")],
        check=True,
    )
    prune_locale_data(rootfs / "nix/store")
    (rootfs / "opt/tools").symlink_to(tools)

    certificate = rootfs / "etc/ssl/certs/ca-certificates.crt"
    shutil.copy2("/etc/ssl/certs/ca-certificates.crt", certificate)
    certificate.chmod(0o644)

    files = {
        "passwd": (
            f"root:x:0:0:root:/root:{shell}\n"
            f"{user}:x:{uid}:{gid}:{user} container user:/home/{user}:{shell}\n"
        ),
        "group": f"root:x:0:\n{user}:x:{gid}:\n",
    }
    for name, content in files.items():
        path = rootfs / "etc" / name
        path.write_text(content, encoding="utf-8")
        path.chmod(0o644)

    return tools
