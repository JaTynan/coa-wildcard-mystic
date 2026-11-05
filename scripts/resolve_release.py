#!/usr/bin/env python3
"""Look up the exact source commits of one CF-Server-Manager server release.

Usage: resolve_release.py <release tag | latest>

The manager lists every server release it installs, with the exact commit of
each part, in src/data/server-history.json. Building from those commits gives
the same program the manager installed, plus our patch.

Writes the commits to $GITHUB_OUTPUT (when set) and prints them.
"""
import json
import os
import sys
import urllib.request

HISTORY = ("https://raw.githubusercontent.com/Corfirean/coa-server-manager/"
           "master/src/data/server-history.json")
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
    with urllib.request.urlopen(HISTORY, timeout=60) as response:
        history = json.load(response)

    releases = [r for r in history["releases"]
                if r.get("tag", "").startswith("server-") and "components" in r]
    if wanted in ("", "latest"):
        release = max(releases, key=lambda r: r.get("date", ""))
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
