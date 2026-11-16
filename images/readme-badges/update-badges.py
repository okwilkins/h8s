#!/opt/tools/bin/python3 -I

"""Keep README version badges in sync through a GitHub PR."""

import base64
import json
import os
import re
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

REPOSITORY = os.environ["GITHUB_REPOSITORY"]
BRANCH = os.environ["GITHUB_BRANCH"]
TOKEN_FILE = Path(os.environ["GITHUB_TOKEN_FILE"])
SOURCES = json.loads(os.environ["BADGE_SOURCES"])


def api(path, data=None, method=None):
    """Call the GitHub API and return its JSON response."""
    request = Request(
        f"https://api.github.com/repos/{REPOSITORY}/{path}",
        data=None if data is None else json.dumps(data).encode(),
        method=method,
        headers={
            "Authorization": f"Bearer {TOKEN_FILE.read_text().strip()}",
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "readme-badges",
        },
    )

    with urlopen(request, timeout=30) as response:
        return json.load(response)


def read(path, ref):
    """Read a repository file and its blob SHA at a Git ref."""
    file = api(f"contents/{path}?{urlencode({'ref': ref})}")
    return base64.b64decode(file["content"]).decode(), file["sha"]


def extract(pattern, text):
    """Extract exactly one version from a source file."""
    matches = re.findall(pattern, text, re.MULTILINE)
    if len(matches) != 1:
        raise ValueError(f"Expected one match for {pattern!r}")
    return matches[0]


def main():
    """Update the version badges and open or update their PR."""
    # Keep all writes off main.
    if not BRANCH or BRANCH == "main":
        raise ValueError("GITHUB_BRANCH must name a separate automation branch")

    if not isinstance(SOURCES, dict) or not SOURCES:
        raise ValueError("BADGE_SOURCES must contain a non-empty JSON object")

    # Read the declared versions from one snapshot of main.
    base = api("git/ref/heads/main")["object"]["sha"]
    versions = {}
    for label, source in SOURCES.items():
        text, _ = read(source["path"], base)
        version = extract(source["pattern"], text)
        versions[label] = source.get("value", version)

    # Replace the badge versions without changing their styling.
    original, _ = read("README.md", base)
    updated = original
    for label, version in versions.items():
        pattern = rf'(https://img\.shields\.io/badge/{re.escape(label)}-)[^-?\s)]+' + r'(-[0-9A-Fa-f]{6}\?)'
        updated, count = re.subn(pattern, lambda m: m[1] + version + m[2], updated)
        if count != 1:
            raise ValueError(f"Expected one {label} badge")

    # Find the existing PR and close it if main already has the right badges.
    owner = REPOSITORY.split("/")[0]
    pulls = api("pulls?" + urlencode({"state": "open", "head": f"{owner}:{BRANCH}", "base": "main"}))
    if updated == original:
        if pulls:
            api(f"pulls/{pulls[0]['number']}", {"state": "closed"}, "PATCH")

        print("README badges already match main.")
        return

    # Create the automation branch if it does not exist.
    try:
        api(f"git/ref/heads/{BRANCH}")
    except HTTPError as error:
        if error.code != 404:
            raise

        api("git/refs", {"ref": f"refs/heads/{BRANCH}", "sha": base})

    # Commit the README only if the automation branch needs an update.
    current, sha = read("README.md", BRANCH)
    if updated != current:
        if api("git/ref/heads/main")["object"]["sha"] != base:
            raise RuntimeError("main changed. Resubmit the workflow.")

        api("contents/README.md", {
            "message": "docs: update README version badges",
            "content": base64.b64encode(updated.encode()).decode(),
            "sha": sha,
            "branch": BRANCH,
        }, "PUT")

    # Reuse the existing PR or open a new one.
    if not pulls:
        pulls = [api(
            "pulls",
            {
                "title": "docs: update README version badges",
                "head": BRANCH,
                "base": "main",
                "body": "Update version badges from the configuration on main.",
            }
        )]

    print(pulls[0]["html_url"])


if __name__ == "__main__":
    main()
