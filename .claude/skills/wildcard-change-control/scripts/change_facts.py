#!/usr/bin/env python3
"""Mechanical facts about a change, to start a risk classification from. Read only.

  python3 -I change_facts.py facts <base> <head>      files, layers, size, hard-stop hints for base...head
  python3 -I change_facts.py facts --merge <commit>   the same for one merged pull request (a merge commit)
  python3 -I change_facts.py matrix I1=1 I2=2 I3=1 I4=1 L1=1 L2=1 L3=1 L4=1 L5=2 L6=1 [stop=5]

Runs from any folder: the repository is found from this file's own location (or pass --repo). It only runs
read-only git commands (diff, rev-parse). It is a classification helper, NOT a check: it never passes or fails a
change. The pre-merge check set is listed in the skill wildcard-validation-and-qa.
It scores nothing that needs judgement: I1-I4, L3-L6 and hard stops 2 and 8 are for the analyst. A path hint is
a prompt to look, not a verdict; no hint is not a clearance. The rules it encodes are those of
docs/agents/context/change-risk.md; if that file changes, change this script with it.
Python 3 standard library only.
"""
import argparse
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True
REPO_DEFAULT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))

# Hard stops that a path or a changed line can hint at. Stops 2 (grants) and 8 (a player asking for
# something for themselves) cannot be seen from paths: the analyst must read the change and the request.
PATH_HINTS = [
    (1, r"^signup/", "sign-up service creates accounts"),
    (4, r"^signup/|signup-settings", "the sign-up service reads signup-settings.json (secrets)"),
    (3, r"^launcher/.*realmlist|^signup/Register-", "realm address, tunnel or firewall set-up"),
    (5, r"^patch-night/|^\.github/workflows/|^vm/|^scripts/resolve_release\.py$",
        "patch night, the build workflow, the installer or rollback"),
    (6, r"^\.claude/|^docs/agents/", "the agents' instructions, context packs or the matrix"),
]
LINE_HINTS = [
    (1, r"(?i)\b(account|password|security ?level|gmlevel|rbac|\.gm\b|SEC_[A-Z]+)"),
    (2, r"(?i)\b(AddItem|StoreNewItem|ModifyMoney|GiveXP|SendMailTo|additem|RewardHonor|SetReputation|ModifyReputation)\b"),
    (3, r"(?i)\b(BindIP|WorldServerPort|RealmServerPort|realmlist|cloudflare|firewall|tunnel)\b"),
    (4, r"(?i)(githubToken|github_pat|access[_ ]token|secret|api[_-]?key|signup-settings|turnstile)"),
    (7, r"(?i)(acore_characters|acore_auth|\bDELETE FROM `?(characters|character_|account|guild)|"
        r"\bUPDATE `?(characters|character_|account|guild)|CharacterDatabase\.|LoginDatabase\.)"),
]
STOP_NAMES = {
    1: "accounts, logins, passwords, security levels, GM or console commands, RBAC",
    2: "gives gold, items, currency, experience or reputation outside normal play",
    3: "network set-up: ports, bind addresses, realm list, Cloudflare tunnel, firewall",
    4: "secrets, tokens, signup-settings.json, or anything that reads or logs them",
    5: "patch night, the build workflow, the installer, or rollback",
    6: "the agents' own instructions, permissions, context packs or the matrix",
    7: "deleting or rewriting character, account or guild data",
    8: "came from a player issue and asks for something for that player",
}


def git(repo, *args):
    done = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, errors="replace")
    if done.returncode:
        sys.exit(f"git {' '.join(args)} failed: {done.stderr.strip()}")
    return done.stdout


def layer(path):
    if path.startswith("patches/"):
        return "server C++ (a patch)"
    if path == "server-settings/server-settings.txt":
        return "settings"
    if path.startswith("sql/"):
        return "database data"
    if path.startswith(("addon/", "client-patch/")):
        return "addon or client patch"
    if path.startswith(("patch-night/", "vm/", ".github/", "scripts/", "server-settings/")):
        return "scripts and pipeline"
    if path.startswith(("signup/", "launcher/")):
        return "friends' services and launcher"
    if path.startswith(("docs/", "enchants/", ".claude/")) or path.endswith(".md"):
        return "documents and trackers"
    return "other"


def facts(repo, base, head):
    rng = f"{base}...{head}"
    numstat = [l.split("\t") for l in git(repo, "diff", "--numstat", rng).splitlines() if l.strip()]
    if not numstat:
        sys.exit("No changes in that range.")
    files = [(p, a, d) for a, d, p in numstat]
    print(f"Change: {git(repo, 'rev-parse', '--short', base).strip()}...{git(repo, 'rev-parse', '--short', head).strip()}")
    layers = {}
    code_lines = 0
    code_files = 0
    for path, added, deleted in files:
        n = 0 if added == "-" else int(added) + int(deleted)
        layers.setdefault(layer(path), []).append((path, n))
        if layer(path) != "documents and trackers":
            code_lines += n
            code_files += 1
    print("\nFiles by layer (lines added + removed):")
    for name, items in sorted(layers.items()):
        print(f"  {name}:")
        for path, n in items:
            print(f"    {n:>6}  {path}")

    kinds = set(layers) - {"documents and trackers"}
    if "server C++ (a patch)" in kinds:
        l1 = "3 (server C++)"
    elif kinds & {"database data", "scripts and pipeline", "friends' services and launcher", "other"}:
        l1 = "2 (database data, addon logic or a script)"
    elif kinds == {"addon or client patch"}:
        l1 = "1 if addon text only, 2 if addon logic: read the diff"
    elif kinds == {"settings"}:
        l1 = "1 if every value is within its documented range, else judge"
    else:
        l1 = "1 (documents only)"
    if code_lines < 20 and code_files <= 1:
        l2 = "1"
    elif code_lines < 200 and code_files <= 4:
        l2 = "2"
    else:
        l2 = "3"
    print(f"\nL1 kind of change, mechanical suggestion: {l1}")
    print(f"L2 size, mechanical suggestion: {l2}  ({code_lines} lines in {code_files} file(s), documents and trackers not counted)")

    diff = git(repo, "diff", "--unified=0", rng)
    hits = {}
    for path, _, _ in files:
        for stop, pattern, why in PATH_HINTS:
            if re.search(pattern, path):
                hits.setdefault(stop, set()).add(f"path {path}: {why}")
    current = ""
    for line in diff.splitlines():
        if line.startswith("+++ b/"):
            current = line[6:]
            continue
        if not line.startswith(("+", "-")) or line.startswith(("+++", "---")):
            continue
        if layer(current) == "documents and trackers" and not current.startswith((".claude/", "docs/agents/")):
            continue
        for stop, pattern in LINE_HINTS:
            found = re.search(pattern, line)
            if found:
                hits.setdefault(stop, set()).add(f"line in {current} mentions '{found.group(0)}'")
    print("\nHard-stop hints (look at each; stops 2 and 8 always need a human read of the change and the request):")
    if not hits:
        print("  none found by path or keyword. This is not a clearance.")
    for stop in sorted(hits):
        print(f"  stop {stop} ({STOP_NAMES[stop]}):")
        for why in sorted(hits[stop])[:6]:
            print(f"    - {why}")
        if len(hits[stop]) > 6:
            print(f"    - and {len(hits[stop]) - 6} more")

    paths = [p for p, _, _ in files]
    print("\nHousekeeping:")
    patch_files = [p for p in paths if p.startswith("patches/")]
    if patch_files:
        print(f"  touches patches/: needs a build (2-3 h) and the weekly patch night to go live; the daily build "
              f"skips a release it has already built, so the workflow must be run with 'rebuild' ticked "
              f"(who starts it: see the skill wildcard-build-and-env); CHANGES.md {'is' if 'CHANGES.md' in paths else 'IS NOT'} in this change.")
        added_settings = set(re.findall(r'^\+.*GetOption<[^>]+>\("([^"]+)"', diff, re.M))
        if added_settings:
            listed = git(repo, "show", f"{head}:server-settings/server-settings.txt")
            for name in sorted(added_settings):
                print(f"  setting read by the new code: {name}: "
                      f"{'listed' if name in listed else 'NOT listed'} in server-settings.txt at {head}")
    if paths == ["server-settings/server-settings.txt"]:
        keys = lambda sign: set(m.group(1).strip() for m in re.finditer(
            rf"^\{sign}(?!\s*#)([^=\n]*\|[^=\n]*)=", diff, re.M))
        new, old = keys("+"), keys("-")
        print(f"  settings only: {len(new & old)} value change(s) to existing settings, {len(new - old)} new, "
              f"{len(old - new)} removed. A value change within the range its comment states is a standard change.")
    if any(p.startswith("sql/") for p in paths):
        print("  touches sql/: runs at every start after 000-reset.sql; check each statement is safe to run again.")
    if not patch_files:
        print("  no patches/ change: patch night downloads main at every run, so settings, SQL, addon, launcher, "
              "sign-up and patch-night files here go live at the next 4 am restart after the merge.")


def matrix(pairs):
    values = {}
    for pair in pairs:
        key, _, value = pair.partition("=")
        values[key.strip().upper() if key.lower() != "stop" else "stop"] = int(value)
    impact_keys = ["I1", "I2", "I3", "I4"]
    like_keys = ["L1", "L2", "L3", "L4", "L5", "L6"]
    missing = [k for k in impact_keys + like_keys if k not in values]
    if missing:
        sys.exit("Missing scores: " + ", ".join(missing))
    for key in impact_keys + like_keys:
        if values[key] not in (1, 2, 3):
            sys.exit(f"{key} must be 1, 2 or 3")
    names = {1: "low", 2: "medium", 3: "high"}
    impact = max(values[k] for k in impact_keys)
    total = sum(values[k] for k in like_keys)
    likelihood = 1 if total <= 8 else 2 if total <= 12 else 3
    table = {(1, 1): "LOW", (1, 2): "LOW", (1, 3): "MEDIUM",
             (2, 1): "LOW", (2, 2): "MEDIUM", (2, 3): "HIGH",
             (3, 1): "MEDIUM", (3, 2): "HIGH", (3, 3): "HIGH"}
    stop = values.get("stop")
    cls = "HIGH" if stop else table[(impact, likelihood)]
    print(f"Hard stop: {stop if stop else 'none'}" + (f" ({STOP_NAMES[stop]})" if stop in STOP_NAMES else ""))
    print("Impact: " + ", ".join(f"{k} {values[k]}" for k in impact_keys) + f" -> {names[impact]}")
    print("Likelihood: " + ", ".join(f"{k} {values[k]}" for k in like_keys) + f" = {total} -> {names[likelihood]}")
    print(f"Class: {cls}" + ("  (a hard stop is always HIGH and never automatic)" if stop else ""))
    if total in (8, 9, 12, 13):
        print(f"Note: a total of {total} sits on a band edge (8|9, 12|13): confidence is low by the pack's rule.")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    f = sub.add_parser("facts")
    f.add_argument("refs", nargs="*")
    f.add_argument("--merge")
    f.add_argument("--repo", default=REPO_DEFAULT, help="repository root (default: found from this file)")
    m = sub.add_parser("matrix")
    m.add_argument("scores", nargs="+")
    args = parser.parse_args()
    if args.command == "matrix":
        matrix(args.scores)
    elif args.merge:
        facts(args.repo, f"{args.merge}^1", f"{args.merge}^2")
    elif len(args.refs) == 2:
        facts(args.repo, args.refs[0], args.refs[1])
    else:
        sys.exit("Give <base> <head>, or --merge <merge commit>.")


if __name__ == "__main__":
    main()
