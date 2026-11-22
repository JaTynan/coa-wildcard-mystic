#!/usr/bin/env python3
"""Pre-build check: do patches/*.patch still fit the core the next build will use?

Repeats, in a minute or two on any machine with git and Python 3, what the build workflow's
"Apply our patches" step does on the Windows runner (.github/workflows/build-worldserver.yml):
for each patches/*.patch in name order, `git apply --check`, then apply, against
Corfirean/azerothcore-wotlk-coa at the commit the manager release pins.
With --modules it also repeats "Apply the official build's module patches": the release's
checksum for each module patch, and whether it applies to the pinned module commit.

It does NOT run the patches/NN-*.ps1 scripts (they need PowerShell; see the sibling skill
wildcard-patch-authoring), and it does not compile anything. A pass here means "the build will
get past these steps", nothing more.

How it stays small: no source tree is checked out. Each repository is fetched blobless at the
one pinned commit, and the patches are applied to a throwaway index (`git apply --cached`), so
git downloads only the files the patches touch. Nothing in this repository is modified.

Usage (from anywhere):
  python3 -I check_patch_files.py                      # newest manager release
  python3 -I check_patch_files.py --release server-0.261119.114
  python3 -I check_patch_files.py --modules            # also the official module patches
  python3 -I check_patch_files.py --core-sha <40 hex>  # skip the release lookup (offline list)
  python3 -I check_patch_files.py --repo /path/to/coa-wildcard-mystic --cache /some/dir

Exit code 0: everything fits. 1: at least one patch does not fit (named in the output).
2: the check itself could not run (network, git, release list).
"""
import argparse
import hashlib
import os
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True

CORE_REPO = "Corfirean/azerothcore-wotlk-coa"
SQUID_REPO = "Zyth45/mod-playerbots"
DUNGEON_REPO = "Zyth45/mod-dungeon-clear"
BUILD_REPO = "Corfirean/coa-server-build"


class CheckError(Exception):
    """The check could not run (exit code 2)."""


def run(args, cwd=None, env=None, check=True):
    result = subprocess.run(args, cwd=cwd, env=env, text=True, capture_output=True)
    if check and result.returncode:
        raise CheckError(f"{' '.join(args)}\n{result.stdout}{result.stderr}".rstrip())
    return result


def find_repo(start):
    """The repository root: the nearest parent holding patches/ and scripts/resolve_release.py."""
    folder = os.path.abspath(start)
    while True:
        if (os.path.isdir(os.path.join(folder, "patches"))
                and os.path.isfile(os.path.join(folder, "scripts", "resolve_release.py"))):
            return folder
        parent = os.path.dirname(folder)
        if parent == folder:
            raise CheckError("Cannot find the repository (a folder with patches/ and scripts/resolve_release.py). "
                             "Pass --repo.")
        folder = parent


def resolve(repo, release):
    """The release's pinned commits, from the repository's own resolver (the one the workflow runs)."""
    env = {k: v for k, v in os.environ.items() if k != "GITHUB_OUTPUT"}
    result = run([sys.executable, "-I", os.path.join(repo, "scripts", "resolve_release.py"), release],
                 env=env, check=False)
    if result.returncode:
        raise CheckError(f"resolve_release.py {release} failed:\n{result.stdout}{result.stderr}".rstrip())
    pins = {}
    for line in result.stdout.splitlines():
        key, sep, value = line.partition("=")
        if sep and key.replace("_", "").isalnum():
            pins[key] = value.strip()
    if "core_sha" not in pins:
        raise CheckError(f"resolve_release.py printed no core_sha:\n{result.stdout}")
    return pins


def pinned_clone(cache, name, repository, sha):
    """A blobless clone holding the one pinned commit; returns its folder. Reused between runs."""
    folder = os.path.join(cache, name)
    if not os.path.isdir(os.path.join(folder, ".git")):
        os.makedirs(folder, exist_ok=True)
        run(["git", "init", "-q", folder])
        run(["git", "-C", folder, "remote", "add", "origin", f"https://github.com/{repository}"])
    run(["git", "-C", folder, "config", "core.autocrlf", "false"])   # as the workflow's first step
    # Our own marker, not `git cat-file -e`: in a partial clone that command would quietly fetch the
    # commit with its whole history instead of answering "not here".
    marker = os.path.join(folder, ".git", f"pinned-{sha}")
    if not os.path.exists(marker):
        print(f"  fetching {repository} at {sha[:12]} (one commit, no file contents yet)...", flush=True)
        run(["git", "-C", folder, "fetch", "-q", "--depth", "1", "--filter=blob:none", "origin", sha])
        # From here on git fetches a file's contents from this remote the moment a patch needs it.
        run(["git", "-C", folder, "config", "remote.origin.promisor", "true"])
        run(["git", "-C", folder, "config", "remote.origin.partialclonefilter", "blob:none"])
        with open(marker, "w", encoding="ascii") as handle:
            handle.write("fetched by check_patch_files.py\n")
    return folder


def apply_in_order(clone, sha, patches, label):
    """Workflow order: check then apply each patch, on a throwaway index. Returns the failures."""
    failures = []
    with tempfile.TemporaryDirectory() as scratch:
        env = dict(os.environ, GIT_INDEX_FILE=os.path.join(scratch, "index"))
        run(["git", "-C", clone, "read-tree", sha], env=env)
        for patch in patches:
            name = os.path.basename(patch)
            check = run(["git", "-C", clone, "apply", "--cached", "--check", "--whitespace=nowarn", patch],
                        env=env, check=False)
            if check.returncode:
                failures.append(name)
                print(f"  FAIL  {name} does not fit {label}")
                for line in check.stderr.strip().splitlines():
                    print(f"        {line}")
                continue   # the workflow stops here; going on shows every patch that needs work
            run(["git", "-C", clone, "apply", "--cached", "--whitespace=nowarn", patch], env=env)
            touched = run(["git", "-C", clone, "apply", "--numstat", patch]).stdout.strip().splitlines()
            print(f"  ok    {name} ({len(touched)} file{'s' if len(touched) != 1 else ''})")
    return failures


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def check_module_patches(cache, pins):
    """The workflow step "Apply the official build's module patches": checksum, then fit."""
    failures = []
    if not pins.get("build_sha"):
        print("Official module patches: this release lists none; the workflow skips the step.")
        return failures
    build = pinned_clone(cache, "coa-server-build", BUILD_REPO, pins["build_sha"])
    for key, name, repository in (("squid", "mod-playerbots", SQUID_REPO), ("dungeon", "mod-dungeon-clear", DUNGEON_REPO)):
        patch_path, want = pins.get(f"{key}_patch"), pins.get(f"{key}_patch_sha256")
        if not patch_path:
            continue
        module_sha = pins.get(f"{key}_sha")
        if not module_sha:
            print(f"  FAIL  {patch_path} is listed but the release pins no {name} commit")
            failures.append(patch_path)
            continue
        print(f"Official module patch {patch_path} -> {repository} {module_sha[:12]}")
        with tempfile.TemporaryDirectory() as scratch:
            local = os.path.join(scratch, os.path.basename(patch_path))
            blob = subprocess.run(["git", "-C", build, "cat-file", "blob", f"{pins['build_sha']}:{patch_path}"],
                                  capture_output=True)
            if blob.returncode:
                raise CheckError(f"Cannot read {patch_path} from {BUILD_REPO} {pins['build_sha'][:12]}:\n"
                                 f"{blob.stderr.decode(errors='replace')}")
            with open(local, "wb") as handle:
                handle.write(blob.stdout)
            got = sha256(local)
            if got != want:
                print(f"  FAIL  checksum {got} differs from the release's {want}")
                failures.append(patch_path)
                continue
            print("  ok    checksum matches the release list")
            module = pinned_clone(cache, name, repository, module_sha)
            # The workflow applies module patches without --whitespace=nowarn; warnings do not fail it.
            failures += apply_in_order(module, module_sha, [local], f"{repository} {module_sha[:12]}")
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--release", default="latest", help='manager release tag, or "latest" (default)')
    parser.add_argument("--core-sha", help="check against this core commit instead of looking a release up")
    parser.add_argument("--repo", help="path of the coa-wildcard-mystic checkout (default: found from this script or the current folder)")
    parser.add_argument("--patches", help="folder with the *.patch files (default: <repo>/patches)")
    parser.add_argument("--cache", default=os.path.join(os.path.expanduser("~"), ".cache", "wildcard-build-check"),
                        help="where the small pinned clones are kept (default: ~/.cache/wildcard-build-check)")
    parser.add_argument("--modules", action="store_true", help="also check the official build's module patches")
    args = parser.parse_args()

    try:
        if args.repo:
            repo = find_repo(args.repo)
        else:
            try:
                repo = find_repo(os.path.dirname(os.path.abspath(__file__)))
            except CheckError:
                repo = find_repo(os.getcwd())
        folder = os.path.abspath(args.patches) if args.patches else os.path.join(repo, "patches")
        patches = sorted((os.path.join(folder, f) for f in os.listdir(folder) if f.endswith(".patch")),
                         key=lambda p: os.path.basename(p).lower())   # name order, as Sort-Object Name
        if args.core_sha:
            if len(args.core_sha) != 40 or any(c not in "0123456789abcdef" for c in args.core_sha):
                raise CheckError("--core-sha needs the full 40-character lowercase commit id.")
            if args.modules:
                raise CheckError("--modules needs the release list; use --release instead of --core-sha.")
            pins = {"tag": "(given commit)", "core_sha": args.core_sha}
        else:
            pins = resolve(repo, args.release)
        print(f"Repository: {repo}")
        print(f"Release:    {pins['tag']}")
        print(f"Core:       {CORE_REPO} {pins['core_sha']}")
        print(f"Patches:    {len(patches)} *.patch file(s) in {folder}")
        os.makedirs(args.cache, exist_ok=True)

        core = pinned_clone(args.cache, "core", CORE_REPO, pins["core_sha"])
        failures = apply_in_order(core, pins["core_sha"], patches, f"release {pins['tag']}")
        if args.modules:
            failures += check_module_patches(args.cache, pins)
    except CheckError as error:
        print(f"CHECK COULD NOT RUN: {error}", file=sys.stderr)
        return 2

    print()
    if failures:
        print(f"RESULT: {len(failures)} patch(es) do not fit: {', '.join(failures)}.")
        print("The build would stop at the first of these. A patch listed after another failed one may only be")
        print("failing because the earlier one was not applied: fix them in order and run this again.")
        return 1
    scope = "*.patch files and the official module patches" if args.modules else "*.patch files"
    print(f"RESULT: all {scope} fit. Not checked here: the patches/*.ps1 scripts, compiling, linking, start-up.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
