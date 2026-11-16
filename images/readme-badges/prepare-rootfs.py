"""Assemble the badge updater rootfs from the Nix runtime closure."""

import shutil
from pathlib import Path

from rootfs import parse_arguments, prepare_base_rootfs


def prepare_rootfs(rootfs: Path, user: str, uid: int, gid: int) -> None:
    prepare_base_rootfs(rootfs, user, uid, gid, shell="/sbin/nologin")
    (rootfs / "home" / user).chmod(0o700)

    entrypoint = rootfs / "usr/local/bin/update-badges"
    shutil.copy2("update-badges.py", entrypoint)
    entrypoint.chmod(0o555)


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
