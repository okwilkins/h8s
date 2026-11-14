"""Assemble the signer rootfs from the Nix runtime closure."""

import shutil
from pathlib import Path
from textwrap import dedent

from rootfs import parse_arguments, prepare_base_rootfs


def prepare_rootfs(rootfs: Path, user: str, uid: int, gid: int) -> None:
    prepare_base_rootfs(rootfs, user, uid, gid, shell="/sbin/nologin")
    (rootfs / "home" / user).chmod(0o700)

    library_path = Path("/usr/local/libexec/cosign")
    library = rootfs / library_path.relative_to("/")
    library.mkdir(parents=True)

    for name in ("cosign_common.py", "sign-and-verify.py", "attest-sbom.py"):
        target = library / name
        shutil.copy2(name, target)
        target.chmod(0o444)

    for command in ("sign-and-verify", "attest-sbom"):
        entrypoint = rootfs / "usr/local/bin" / command
        entrypoint.write_text(dedent(f"""\
            #!/opt/tools/bin/python3 -I
            import runpy
            import sys

            sys.path.insert(0, "{library_path}")
            runpy.run_path("{library_path}/{command}.py", run_name="__main__")
        """), encoding="utf-8")
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
