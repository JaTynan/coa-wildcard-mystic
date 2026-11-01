#!/usr/bin/env python3
"""Look up the exact source commits of one CF-Server-Manager server release.

Usage: resolve_release.py <release tag | latest>

The build repository (changelog/history.json) and the manager (src/data/server-history.json) list every
server release, with the exact commit of each part. Building from those commits gives
the same program the manager installed, plus our patch.

Writes the commits to $GITHUB_OUTPUT (when set) and prints them.
"""
import json
import os
import sys
import urllib.request

# The build repository's list is updated first; the manager's copy can lag a release behind.
HISTORIES = ("https://raw.githubusercontent.com/Corfirean/coa-server-build/main/changelog/history.json",
             "https://raw.githubusercontent.com/Corfirean/coa-server-manager/master/src/data/server-history.json")
NEEDED = {
    "core": "Corfirean/azerothcore-wotlk-coa",
    "bots": "Corfirean/mod-coa-playerbots",
    "scaling": "Corfirean/mod-coa-content-scaling",
    "squid": "Zyth45/mod-playerbots",
}


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    wanted = sys.argv[1].strip()
    by_tag = {}
    for url in HISTORIES:
        try:
            with urllib.request.urlopen(url, timeout=60) as response:
                history = json.load(response)
        except (OSError, ValueError) as error:
            print(f"Could not read {url}: {error}")
            continue
        for r in history.get("releases", []):
            if r.get("tag", "").startswith("server-") and "components" in r:
                by_tag.setdefault(r["tag"], r)
    releases = sorted(by_tag.values(), key=lambda r: (r.get("date", ""), r["tag"]))
    if not releases:
        sys.exit("No release list could be read.")
    if wanted in ("", "latest"):
        release = releases[-1]
    else:
        matches = [r for r in releases if r["tag"] == wanted]
        if not matches:
            known = ", ".join(r["tag"] for r in releases[-5:])
            sys.exit(f"Release {wanted} is not in the manager's list. Recent ones: {known}")
        release = matches[0]

    outputs = {"tag": release["tag"]}
    for name, repository in NEEDED.items():
        part = release["components"].get(name)
        if not part or not part.get("sha"):
            sys.exit(f"Release {release['tag']} lists no {name} commit.")
        if part.get("repository") != repository:
            sys.exit(f"Release {release['tag']}: {name} comes from {part.get('repository')}, "
                     f"expected {repository}. The build recipe needs checking.")
        outputs[f"{name}_sha"] = part["sha"]
    outputs["squid_tag"] = release["components"]["squid"].get("ref", "")

    for key, value in outputs.items():
        print(f"{key}={value}")
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as handle:
            for key, value in outputs.items():
                handle.write(f"{key}={value}\n")


if __name__ == "__main__":
    main()
