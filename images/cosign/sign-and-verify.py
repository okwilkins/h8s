"""Sign and verify an image digest with Cosign."""

import argparse

from cosign_common import SigningContext, run_action, run_cosign


def sign_and_verify(image_reference: str, context: SigningContext) -> None:
    run_cosign(
        ["sign", "--yes", "--key", str(context.private_key), image_reference],
        context.environment,
    )
    run_cosign(
        ["verify", "--key", str(context.public_key), image_reference],
        context.environment,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image_reference")
    args = parser.parse_args()

    return run_action(
        args.image_reference,
        lambda context: sign_and_verify(args.image_reference, context),
    )


if __name__ == "__main__":
    raise SystemExit(main())
