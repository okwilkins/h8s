#!/opt/tools/bin/python3 -I

"""Sign and verify an image digest with Cosign."""

import argparse
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import BinaryIO


def run_cosign(
    arguments: list[str],
    environment: dict[str, str],
    stdin: BinaryIO | None = None,
) -> None:
    retries = int(environment.get("SCAN_RETRIES", "60"))
    delay = int(environment.get("SCAN_RETRY_DELAY", "5"))
    if retries < 0 or delay < 0:
        raise ValueError("SCAN_RETRIES and SCAN_RETRY_DELAY must not be negative")

    for attempt in range(retries + 1):
        result = subprocess.run(
            ["cosign", *arguments],
            stdin=stdin,
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if result.returncode == 0:
            print(result.stdout, end="", flush=True)
            print(result.stderr, end="", file=sys.stderr, flush=True)
            return

        output = result.stdout + result.stderr
        pending = "PROJECTPOLICYVIOLATION" in output and any(
            f'vulnerability scan is in "{state}" status' in output
            for state in ("Pending", "Running")
        )
        if not pending or attempt == retries:
            print(output, end="", file=sys.stderr, flush=True)
            if pending:
                print("Timed out waiting for Harbor vulnerability scans.", file=sys.stderr)
            raise subprocess.CalledProcessError(result.returncode, result.args)

        print(
            f"Waiting for Harbor vulnerability scans ({attempt + 1}/{retries})...",
            file=sys.stderr,
            flush=True,
        )
        time.sleep(delay)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image_reference")
    args = parser.parse_args()

    try:
        registry = os.environ.get("REGISTRY", "")
        if not registry:
            raise ValueError("REGISTRY must be set")
        image_pattern = re.escape(registry) + r"/[a-z0-9][a-z0-9._/-]*@sha256:[0-9a-f]{64}"
        if not re.fullmatch(image_pattern, args.image_reference):
            raise ValueError(f"image_reference must match {registry}/<repository>@sha256:<digest>")
        if "COSIGN_PASSWORD" not in os.environ:
            raise ValueError("COSIGN_PASSWORD must be set")

        credentials = Path(os.environ.get("HARBOR_CREDENTIALS", "/var/run/secrets/harbor"))
        keys = Path(os.environ.get("COSIGN_KEYS", "/var/run/secrets/cosign"))
        os.umask(0o077)

        with tempfile.TemporaryDirectory(prefix="cosign-", dir="/tmp") as directory:
            workdir = Path(directory)
            environment = dict(os.environ, HOME=directory, DOCKER_CONFIG=directory)
            username = (credentials / "username").read_text(encoding="utf-8").strip()
            with (credentials / "password").open("rb") as password:
                run_cosign(
                    ["login", "--username", username, "--password-stdin", registry],
                    environment,
                    stdin=password,
                )

            private_key = keys / "cosign.key"
            if private_key.read_bytes().startswith(b"-----BEGIN EC PRIVATE KEY-----"):
                run_cosign(
                    [
                        "import-key-pair", "--key", str(private_key),
                        "--output-key-prefix", str(workdir / "key"),
                    ],
                    environment,
                )
                private_key = workdir / "key.key"

            run_cosign(
                ["sign", "--yes", "--key", str(private_key), args.image_reference],
                environment,
            )
            run_cosign(
                ["verify", "--key", str(keys / "cosign.pub"), args.image_reference],
                environment,
            )
    except subprocess.CalledProcessError as error:
        print(error, file=sys.stderr)
        return max(1, error.returncode)
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
