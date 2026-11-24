#!/usr/bin/env python3
"""Which published builds contain a commit, and what the build history looks like.

Every successful build publishes a release tagged wcme-<manager release>-build<run number>, and the
tag points at the commit of this repository the build used (the workflow passes --target github.sha).
So git alone answers "is my merged fix in a build yet?" - no GitHub API needed.

Reads tags only; changes nothing. Fetch tags first if your clone is old (git fetch --tags).

Usage:
  python3 -I which_build.py                 # table of all builds, oldest first, and a count per release
  python3 -I which_build.py <commit>        # builds that contain <commit> (a hash, branch or PR merge commit)
  python3 -I which_build.py --repo /path/to/coa-wildcard-mystic <commit>

Exit code 0: printed. 1: <commit> is in no published build. 2: could not run.
"""
import argparse
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True
REPO_DEFAULT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))

TAG = re.compile(r"^wcme-(server-[0-9.]+)-build(\d+)$")


def git(repo, *args, check=True):
    result = subprocess.run(["git", "-C", repo, *args], text=True, capture_output=True)
    if check and result.returncode:
        sys.stderr.write(f"git {' '.join(args)} failed:\n{result.stderr}")
        sys.exit(2)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("commit", nargs="?", help="commit to look for (default: just list the builds)")
    parser.add_argument("--repo", default=REPO_DEFAULT, help="the coa-wildcard-mystic checkout (default: the repository this script sits in)")
    args = parser.parse_args()

    lines = git(args.repo, "for-each-ref", "refs/tags/wcme-*",
                "--format=%(refname:short)\t%(objectname)\t%(*objectname)\t%(committerdate:short)\t%(*committerdate:short)"
                ).stdout.splitlines()
    builds = []
    for line in lines:
        name, sha, peeled, date, peeled_date = line.split("\t")
        match = TAG.match(name)
        if match:
            builds.append({"run": int(match.group(2)), "release": match.group(1), "tag": name,
                           "sha": peeled or sha, "date": peeled_date or date})
    if not builds:
        sys.stderr.write("No wcme-* tags in this clone. Run: git fetch --tags\n")
        return 2
    builds.sort(key=lambda b: b["run"])

    if args.commit:
        wanted = git(args.repo, "rev-parse", "--verify", "--quiet", f"{args.commit}^{{commit}}", check=False).stdout.strip()
        if not wanted:
            sys.stderr.write(f"{args.commit} is not a commit in this clone.\n")
            return 2
        holding = [b for b in builds
                   if git(args.repo, "merge-base", "--is-ancestor", wanted, b["sha"], check=False).returncode == 0]
        if not holding:
            print(f"{wanted[:7]} is in no published build yet (newest build: {builds[-1]['tag']}).")
            print("Since PR #241 the daily workflow builds a merged patch change the same evening (scheduled runs start")
            print("about 8:30-11 pm Sydney; a build takes about 3.5 h). Over a day old means a missed or failed build.")
            return 1
        print(f"{wanted[:7]} is in {len(holding)} build(s); the first was {holding[0]['tag']}.")
        for b in holding:
            print(f"  {b['tag']}  (repository commit {b['sha'][:7]}, committed {b['date']})")
        return 0

    highest = builds[-1]["run"]
    print("run  manager release      repository commit  commit date   tag")
    for b in builds:
        print(f"{b['run']:>3}  {b['release']:<19}  {b['sha'][:7]}            {b['date']}    {b['tag']}")
    print()
    print("Builds published per manager release:")
    counts = {}
    for b in builds:
        counts.setdefault(b["release"], []).append(b["run"])
    for release, runs in counts.items():
        print(f"  {release:<19} {len(runs):>2}  (runs {', '.join(map(str, runs))})")
    missing = sorted(set(range(1, highest + 1)) - {b["run"] for b in builds})
    print()
    print(f"{len(builds)} builds published out of {highest} workflow runs. Run numbers with no release ({len(missing)}): "
          f"{', '.join(map(str, missing))}.")
    print("A run with no release either failed, was cancelled, or was a run that found nothing to build")
    print("(the daily schedule does that whenever patches/ did not change). Tags cannot tell these apart; the Actions run list can.")
    print("The date column is the date of the repository commit that was built, not the time the build ran.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
