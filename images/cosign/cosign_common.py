"""Shared Cosign authentication, key handling and bounded retries."""

import os
import re
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import BinaryIO, Callable


@dataclass(frozen=True)
class SigningContext:
    environment: dict[str, str]
    private_key: Path
    public_key: Path


def run_cosign(
    arguments: list[str],
    environment: dict[str, str],
    stdin: BinaryIO | None = None,
    *,
    quiet: bool = False,
) -> str:
    retries = int(environment.get("SCAN_RETRIES", "60"))
    delay = int(environment.get("SCAN_RETRY_DELAY", "5"))
    if retries < 0 or delay < 0:
        raise ValueError("SCAN_RETRIES and SCAN_RETRY_DELAY must not be negative")

    attempt = 0
    while True:
        result = subprocess.run(
            ["cosign", *arguments],
            stdin=stdin,
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if result.returncode == 0:
            if not quiet:
                print(result.stdout, end="", flush=True)
            print(result.stderr, end="", file=sys.stderr, flush=True)
            return result.stdout

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

        attempt += 1
        print(
            f"Waiting for Harbor vulnerability scans ({attempt}/{retries})...",
            file=sys.stderr,
            flush=True,
        )
        time.sleep(delay)


def run_action(image_reference: str, action: Callable[[SigningContext], None]) -> int:
    try:
        registry = os.environ.get("REGISTRY", "")
        if not registry:
            raise ValueError("REGISTRY must be set")
        image_pattern = re.escape(registry) + r"/[a-z0-9][a-z0-9._/-]*@sha256:[0-9a-f]{64}"
        if not re.fullmatch(image_pattern, image_reference):
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

            action(SigningContext(environment, private_key, keys / "cosign.pub"))
    except subprocess.CalledProcessError as error:
        print(error, file=sys.stderr)
        return max(1, error.returncode)
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1

    return 0
