"""Publish and verify Syft/SPDX attestations for an image digest."""

import argparse
import base64
import json
from pathlib import Path

from cosign_common import SigningContext, run_action, run_cosign


def verified_predicate(output: str, expected: object) -> bool:
    decoder = json.JSONDecoder()
    remaining = output.strip()

    while remaining:
        envelope, offset = decoder.raw_decode(remaining)
        statement = (
            json.loads(base64.b64decode(envelope["payload"], validate=True))
            if "payload" in envelope else envelope
        )
        if statement.get("predicate") == expected:
            return True
        remaining = remaining[offset:].lstrip()

    return False


def attest_sboms(image_reference: str, directory: Path, context: SigningContext) -> None:
    native = json.loads((directory / "sbom.syft.json").read_text(encoding="utf-8"))
    digest = image_reference.split("@", 1)[1]
    if native.get("source", {}).get("metadata", {}).get("manifestDigest") != digest:
        raise ValueError("the Syft SBOM must describe the requested image digest")

    documents = (
        (directory / "sbom.spdx.json", "spdxjson"),
        (directory / "sbom.syft.json", "https://anchore.com/syft"),
    )
    for path, predicate_type in documents:
        expected = json.loads(path.read_text(encoding="utf-8"))
        run_cosign(
            [
                "attest", "--yes", "--key", str(context.private_key),
                "--type", predicate_type, "--predicate", str(path), image_reference,
            ],
            context.environment,
            quiet=True,
        )
        verified = run_cosign(
            [
                "verify-attestation", "--key", str(context.public_key),
                "--type", predicate_type, "--check-claims=true", image_reference,
            ],
            context.environment,
            quiet=True,
        )
        if not verified_predicate(verified, expected):
            raise ValueError(f"no verified attestation contains the generated {path.name}")
        print(f"Published and verified {path.name} for {image_reference}", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image_reference")
    parser.add_argument("sbom_directory", type=Path)
    args = parser.parse_args()

    return run_action(
        args.image_reference,
        lambda context: attest_sboms(args.image_reference, args.sbom_directory, context),
    )


if __name__ == "__main__":
    raise SystemExit(main())
