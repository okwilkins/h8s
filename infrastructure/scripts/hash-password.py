"""Return a password verifier for an OpenTofu external query."""

import base64
import json
import re
import sys

import bcrypt
from argon2.exceptions import HashingError
from argon2.low_level import Type, hash_secret


def argon2id(password: bytes, setting: str) -> str:
    params = re.fullmatch(
        r"\$argon2id\$v=19"
        r"\$m=(?P<memory>\d+),t=(?P<iterations>\d+),p=(?P<threads>\d+)"
        r"\$(?P<salt>[A-Za-z0-9+/]+):(?P<length>\d+)",
        setting,
    )
    if params is None:
        raise ValueError("Invalid Argon2id setting")

    encoded_salt = params["salt"]
    padding = "=" * (-len(encoded_salt) % 4)
    salt = base64.b64decode(encoded_salt + padding, validate=True)

    verifier = hash_secret(
        secret=password,
        salt=salt,
        time_cost=int(params["iterations"]),
        memory_cost=int(params["memory"]),
        parallelism=int(params["threads"]),
        hash_len=int(params["length"]),
        type=Type.ID,
        version=19,
    )
    return verifier.decode("ascii")


def hash_password(password: str, setting: str) -> str:
    password_bytes = password.encode()
    if setting.startswith("$2"):
        verifier = bcrypt.hashpw(password_bytes, setting.encode("ascii"))
        return verifier.decode("ascii")

    return argon2id(password_bytes, setting)


def main() -> None:
    query = json.load(sys.stdin)
    if not isinstance(query, dict):
        raise ValueError("Expected a JSON object")

    password = query.get("password")
    setting = query.get("setting")
    if not isinstance(password, str) or not isinstance(setting, str):
        raise ValueError("Expected a password and hash setting")

    verifier = hash_password(password, setting)
    json.dump({"hash": verifier}, sys.stdout)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OverflowError, HashingError):
        sys.exit("Cannot hash password: invalid query or hash setting.")
