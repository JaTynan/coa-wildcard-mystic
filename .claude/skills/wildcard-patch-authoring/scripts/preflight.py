#!/usr/bin/env python3
"""Pre-flight for patches/: prove every *.patch and NN-*.ps1 applies to the pinned sources, in minutes,
before a 2-3 hour build is spent finding out.

It lays out a scratch workspace the way .github/workflows/build-worldserver.yml does (job "build", from
"Core at the release commit" to "Apply our patch scripts") and runs the same commands in the same order:

  1. python3 -I scripts/resolve_release.py <release>            the release's exact commits
  2. core/ at core_sha
  3. every patches/*.patch, in name order, inside core/         git apply --check, then git apply
  4. core/modules/mod-playerbots at squid_sha, core/modules/mod-dungeon-clear at dungeon_sha,
     _build/ (sparse: patches) at build_sha
  5. the official build's two module patches, checksum checked  git -C <module> apply --check, then apply
  6. core/modules/mod-ollama-chat at the commit pinned in the workflow file
  7. every patches/*.ps1, in name order, from the workspace root, with pwsh
  8. report: OK / FAIL per patch and script with the thrown message, the files each script touched,
     a cheap text check of the C++ that was touched, git diff --stat for core and each module.

Not mirrored: the _bots and _scaling checkouts (CoA bots, Content Scaling). The workflow copies them into core/modules
AFTER the scripts have run, and no script reads them; a script that names them gets a warning here.

Nothing is compiled and no upstream code is run: sources are cloned, patched and read. The repository is
never written to: patches are COPIED into <workspace>/_mine/patches first, as the workflow's "_mine" checkout.

This script is the authority for "the patches apply". The fast *.patch-only check is check_patch_files.py (skill
wildcard-build-and-env); the full pre-merge check set is listed in the skill wildcard-validation-and-qa.
Runs from any folder. Exit code 0 = PASS, 1 = FAIL, 2 = could not run.

Usage:
  preflight.py [release]            release tag such as server-0.261119.114, or "latest" (the default)
    --repo DIR         this repository (default: found from this file's place in it)
    --patches DIR      use this copy of patches/ instead of <repo>/patches (for experiments)
    --stop-after NN    run the scripts up to and including NN-*.ps1, then stop (you cannot skip earlier ones:
                       later scripts build on text earlier ones insert)
    --no-scripts       stop before the scripts: with --keep, a core with only the *.patch files applied, which
                       is what you need to regenerate a *.patch file
    --fail-fast        stop at the first failing script, as the build does (default: run them all, so one
                       run lists every script that needs work; later failures may be knock-on)
    --keep             keep the workspace afterwards (to read the patched sources)
    --workspace DIR    put the workspace here (must not exist or be empty, must be outside the repository)
    --cache DIR        where fetched commits are kept between runs (default ~/.cache/wildcard-preflight)
    --no-cache         fetch everything fresh
    --pwsh PATH        the PowerShell 7 program (default: $PREFLIGHT_PWSH, then "pwsh" on PATH)
    --no-lint          skip the C++ text check
    --json FILE        also write the results as JSON (outside the repository)

Exit code: 0 everything applied and the text check found no error; 1 a patch or script failed, or the text
check found an error; 2 the pre-flight itself could not run (no pwsh, no network, bad arguments).

Needs: Python 3.8+, git, PowerShell 7 (pwsh). Windows PowerShell 5.1 is not a substitute: the build uses pwsh.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.dont_write_bytecode = True

WORKFLOW = ".github/workflows/build-worldserver.yml"

# The steps of job "build" this script mirrors, by name, in order. If the workflow's list differs, the
# pre-flight says so: somebody changed how sources are prepared and this script must be re-read against it.
MIRRORED_STEPS = [
    "Keep line endings as they are in the repositories",
    "This repository (patches, addon, install scripts)",
    "Core at the release commit",
    "Apply our patches",
    "CoA bots module",
    "Content Scaling module",
    "SQUID's Playerbots",
    "Dungeon Clear module (in the official build since the release lists it)",
    "The official build's module patches (its repository at the release's commit)",
    "Apply the official build's module patches (SQUID's auction house bot off, as the manager's build does)",
    "AI chat for bots (mod-ollama-chat, pinned; off until its config enables it)",
    "Apply our patch scripts (patches/*.ps1, in name order; see CHANGES.md)",
]
STEP_AFTER = "Place the modules where the core expects them (as the manager's build does)"

REPOS = {
    "core": "Corfirean/azerothcore-wotlk-coa",
    "bots": "Corfirean/mod-coa-playerbots",
    "scaling": "Corfirean/mod-coa-content-scaling",
    "squid": "Zyth45/mod-playerbots",
    "dungeon": "Zyth45/mod-dungeon-clear",
    "build": "Corfirean/coa-server-build",
    "ollama": "DustinHendrickson/mod-ollama-chat",
}

# Checked out as on the windows-latest runner: the workflow sets core.autocrlf=false, and Git for Windows'
# native line ending is CRLF (it matters only for files an upstream marks "text" without "eol=lf").
# Hooks never run, symbolic links are written as plain files (as on Windows), nothing is downloaded by LFS.
GIT_CHECKOUT_CONFIG = ["-c", "core.autocrlf=false", "-c", "core.eol=crlf", "-c", "core.symlinks=false",
                       "-c", "core.hooksPath=/dev/null", "-c", "advice.detachedHead=false"]

SCRIPT_NAME = re.compile(r"^(\d\d)-[a-z0-9]+(?:-[a-z0-9]+)*\.ps1$")

DRIVER = r'''
# Written by preflight.py. The loop is the workflow step "Apply our patch scripts", with a report per script.
param([string]$StopAfter = '', [switch]$FailFast)
$ErrorActionPreference = 'Stop'
function Get-State {
    $state = @{}
    foreach ($repo in @('core', 'core/modules/mod-playerbots', 'core/modules/mod-dungeon-clear', 'core/modules/mod-ollama-chat')) {
        if (-not (Test-Path "$repo/.git")) { continue }
        foreach ($line in @(git -C $repo diff --numstat)) { if ($line) { $p = $line -split "`t"; $state["$repo/$($p[2])"] = "+$($p[0]) -$($p[1])" } }
        foreach ($line in @(git -C $repo ls-files --others --exclude-standard)) { if ($line) { $state["$repo/$line"] = 'new file' } }
    }
    $global:LASTEXITCODE = 0
    return $state
}
$scripts = @(Get-ChildItem _mine/patches -Filter *.ps1 | Sort-Object Name)
Write-Host "@@ORDER $(($scripts | ForEach-Object Name) -join '|')"
foreach ($script in $scripts) {
    $tokens = $null; $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$errors)
    foreach ($e in $errors) { Write-Host "@@PARSE $($script.Name)`t$($e.Extent.StartLineNumber)`t$($e.Message -replace '\s+', ' ')" }
}
$before = Get-State
$failed = $false
foreach ($script in $scripts) {
    Write-Host "@@BEGIN $($script.Name)"
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $ok = $true
    try {
        & $script.FullName
        if (-not $?) { throw "$($script.Name) failed." }
    } catch {
        $ok = $false; $failed = $true
        $at = if ($_.InvocationInfo -and $_.InvocationInfo.ScriptName) { "$(Split-Path $_.InvocationInfo.ScriptName -Leaf):$($_.InvocationInfo.ScriptLineNumber)" } else { '' }
        Write-Host "@@FAIL $($script.Name)`t$at`t$(($_.Exception.Message) -replace '\s+', ' ')"
    }
    $after = Get-State
    foreach ($key in $after.Keys) { if ($before[$key] -ne $after[$key]) { Write-Host "@@TOUCH $($script.Name)`t$key`t$($after[$key])" } }
    $before = $after
    if ($ok) { Write-Host "@@OK $($script.Name)" }
    Write-Host "@@END $($script.Name)`t$([int]$watch.Elapsed.TotalMilliseconds)"
    if ($FailFast -and -not $ok) { break }
    if ($StopAfter -and $script.Name.StartsWith("$StopAfter-")) { Write-Host "@@STOPPED $($script.Name)"; break }
}
exit 0
'''


class Setup(Exception):
    """The pre-flight could not run (exit code 2)."""


def run(cmd, cwd=None, check=True, env=None):
    result = subprocess.run([str(c) for c in cmd], cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, encoding="utf-8", errors="replace")
    if check and result.returncode:
        raise Setup(f"{' '.join(str(c) for c in cmd)}\n  exited {result.returncode}:\n{indent(result.stdout)}")
    return result


def indent(text, by="    "):
    return "\n".join(by + line for line in text.rstrip().splitlines())


def say(text=""):
    print(text, flush=True)


def git_env():
    env = dict(os.environ)
    env["GIT_LFS_SKIP_SMUDGE"] = "1"
    env["GIT_TERMINAL_PROMPT"] = "0"
    return env


def obtain(repository, sha, dest, cache, sparse=None):
    """Check out one commit of a GitHub repository into dest (depth 1), through the cache when there is one."""
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise Setup(f"{repository}: '{sha}' is not a full commit id")
    url = f"https://github.com/{repository}"
    source, ref = url, sha
    if cache:
        store = cache / (repository.replace("/", "__") + ".git")
        if not store.exists():
            run(["git", "init", "--quiet", "--bare", store])
        if run(["git", "-C", store, "cat-file", "-e", f"{sha}^{{commit}}"], check=False).returncode:
            run(["git", "-C", store, "fetch", "--quiet", "--depth", "1", url, sha], env=git_env())
            run(["git", "-C", store, "update-ref", f"refs/preflight/{sha}", sha])
        source, ref = store.resolve().as_uri(), f"refs/preflight/{sha}"
    dest.mkdir(parents=True, exist_ok=True)
    run(["git", "init", "--quiet", dest])
    run(["git", "-C", dest, "-c", "protocol.file.allow=always", "fetch", "--quiet", "--depth", "1", source, ref],
        env=git_env())
    if sparse:
        run(["git", "-C", dest, "sparse-checkout", "set", sparse])
    run(["git", "-C", dest] + GIT_CHECKOUT_CONFIG + ["checkout", "--quiet", "--detach", "FETCH_HEAD"], env=git_env())
    head = run(["git", "-C", dest, "rev-parse", "HEAD"]).stdout.strip()
    if head != sha:
        raise Setup(f"{repository}: checked out {head}, wanted {sha}")


def read_workflow(repo):
    """The pinned mod-ollama-chat commit, and whether the workflow still has the steps this script mirrors."""
    path = repo / WORKFLOW
    text = path.read_text(encoding="utf-8")
    pin = re.search(r"repository:\s*DustinHendrickson/mod-ollama-chat\s*\n\s*ref:\s*([0-9a-f]{40})", text)
    if not pin:
        raise Setup(f"{WORKFLOW}: the pinned mod-ollama-chat commit was not found. Re-read the workflow.")
    build = text[text.index("\n  build:"):]
    names = re.findall(r"^      - name: (.+?)\s*$", build, flags=re.M)
    upto = names[:names.index(STEP_AFTER)] if STEP_AFTER in names else names
    return pin.group(1), (None if upto == MIRRORED_STEPS else upto)


def resolve(repo, release):
    env = {k: v for k, v in os.environ.items() if k != "GITHUB_OUTPUT"}
    result = run([sys.executable, "-I", repo / "scripts/resolve_release.py", release], check=False, env=env)
    if result.returncode:
        raise Setup(f"resolve_release.py {release} failed:\n{indent(result.stdout)}")
    out = dict(line.split("=", 1) for line in result.stdout.splitlines() if re.match(r"^[a-z0-9_]+=", line))
    for key in ("tag", "core_sha", "squid_sha"):
        if not out.get(key):
            raise Setup(f"resolve_release.py printed no {key}:\n{indent(result.stdout)}")
    return out


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


HUNK = re.compile(r"^@@ -\d+(?:,(\d+))? \+\d+(?:,(\d+))? @@")


def stale_hunk_counts(path):
    """Lines of a *.patch file that git apply would silently drop: diff lines that follow a finished hunk.

    A hunk header says how many lines it holds (@@ -0,0 +1,14552 @@). Add a line by hand without raising the count and
    git apply still exits 0, takes the counted lines and ignores the rest (checked on 2026-11-22 with git 2.43).
    """
    lines = path.read_text(encoding="utf-8", errors="replace").split("\n")
    found, i = [], 0
    while i < len(lines):
        header = HUNK.match(lines[i])
        i += 1
        if not header:
            continue
        old = int(header.group(1)) if header.group(1) is not None else 1
        new = int(header.group(2)) if header.group(2) is not None else 1
        while i < len(lines) and (old > 0 or new > 0):
            first = lines[i][:1]
            if first == "+":
                new -= 1
            elif first == "-":
                old -= 1
            elif first == "\\":
                pass
            else:
                old -= 1
                new -= 1
            i += 1
        extra = i
        while extra < len(lines) and lines[extra][:1] in ("+", "-", " ") and not lines[extra].startswith(("--- ", "+++ ")):
            extra += 1
        if extra > i:
            found.append(f"{extra - i} line(s) from line {i + 1} follow a hunk that is already full: its @@ count is "
                         "stale, and git apply would drop them without an error")
            i = extra
    return found


# ------------------------------------------------------------------ the C++ text check (heuristic, not a compiler)

# Names <windows.h> defines as macros. Using one as an identifier compiles on Linux and fails in the Windows
# build (16 November: an enumerator named SYNCHRONIZE, commit a4048e7).
WINDOWS_MACROS = {"SYNCHRONIZE", "DELETE", "ERROR", "NO_ERROR", "IGNORE", "ABSOLUTE", "RELATIVE", "OPTIONAL",
                  "INFINITE", "STRICT", "INTERFACE", "TRANSPARENT", "OPAQUE", "DIFFERENCE", "DOMAIN", "CALLBACK",
                  "PASCAL", "NEAR", "FAR", "IN", "OUT", "VOID", "CONST", "TRUE", "FALSE", "BOOLEAN", "MAX_PATH",
                  "WAIT_TIMEOUT", "WAIT_FAILED", "STATUS_PENDING", "GENERIC_READ", "GENERIC_WRITE", "READ_CONTROL",
                  "ERROR_SUCCESS", "INVALID_HANDLE_VALUE", "SEVERITY_ERROR", "PURE", "THIS", "SMALL", "HELP_QUIT"}
DECLARES_MACRO = re.compile(r"^\s*(?:(?:static\s+|inline\s+)*constexpr\s+[\w:<>]+\s+|(?:static\s+)?const\s+[\w:<>]+\s+)?"
                            r"([A-Z][A-Z0-9_]*)\s*(?:=[^=].*)?[,;]?\s*(?://.*)?$")
INCLUDE = re.compile(r'^\s*#\s*include\s*(<[^>\n]*>|"[^"\n]*")(.*)$')
CPP_SUFFIXES = (".cpp", ".h", ".hpp", ".cc", ".inl")


def strip_code(text):
    """Blank out comments, string and character literals so braces inside them are not counted."""
    out, i, n = [], 0, len(text)
    while i < n:
        two = text[i:i + 2]
        if two == "//":
            j = text.find("\n", i)
            i = n if j < 0 else j
        elif two == "/*":
            j = text.find("*/", i + 2)
            end = n if j < 0 else j + 2
            out.append("\n" * text.count("\n", i, end))
            i = end
        elif text[i] == '"' and text[i - 1:i] == "R" and (m := re.match(r'"([^()\\ \n]{0,16})\(', text[i:])):
            j = text.find(")" + m.group(1) + '"', i)
            end = n if j < 0 else j + len(m.group(1)) + 2
            out.append("\n" * text.count("\n", i, end))
            i = end
        elif text[i] in "\"'":
            if text[i] == "'" and i and (text[i - 1].isalnum()) and text[i + 1:i + 2].isalnum():
                out.append(" ")          # a digit separator, as in 1'000
                i += 1
                continue
            quote, j = text[i], i + 1
            while j < n and text[j] != quote and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            i = min(j + 1, n)
            out.append(" ")
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def balance(text):
    code = strip_code(text)
    return {pair: code.count(pair[0]) - code.count(pair[1]) for pair in ("{}", "()", "[]")}


def lint_file(label, new_text, old_text, added_lines):
    """Returns (errors, warnings) for one touched C++ file."""
    errors, warnings = [], []
    for number, line in enumerate(new_text.split("\n"), 1):
        found = INCLUDE.match(line.rstrip("\r"))
        if found:
            rest = found.group(2).strip()
            if rest and not rest.startswith(("//", "/*")):
                errors.append(f"{label}:{number}: text after an #include on the same line: '{rest[:60]}' "
                              "(inserted text without a final line break runs into the next line; MSVC then "
                              "ignores it: C4067, 21 November, commit e0cc2f5)")
    new_balance = balance(new_text)
    old_balance = balance(old_text) if old_text is not None else {pair: 0 for pair in new_balance}
    for pair, value in new_balance.items():
        if value != old_balance[pair]:
            what = "the new file has" if old_text is None else "the patches changed the file's balance of"
            errors.append(f"{label}: {what} unmatched '{pair[0]}' / '{pair[1]}' "
                          f"(was {old_balance[pair]:+d}, now {value:+d} more opened than closed)")
    crlf = new_text.count("\r\n")
    lone = new_text.count("\n") - crlf
    if crlf and lone:
        warnings.append(f"{label}: mixed line endings ({crlf} CRLF lines, {lone} LF lines): the script that "
                        "edited it did not normalise to LF")
    if old_text and old_text.endswith("\n") and not new_text.endswith("\n"):
        warnings.append(f"{label}: the patches removed the line break at the end of the file")
    for line in added_lines:
        code = strip_code(line)
        found = DECLARES_MACRO.match(code)
        if found and found.group(1) in WINDOWS_MACROS:
            warnings.append(f"{label}: '{found.group(1)}' looks declared as a name, and <windows.h> defines it as "
                            f"a macro: rename it (line: {line.strip()[:80]})")
    return errors, warnings


def lint(workspace, repos):
    errors, warnings, checked = [], [], 0
    for rel in repos:
        root = workspace / rel
        if not (root / ".git").exists():
            continue
        changed = run(["git", "-C", root, "diff", "--name-only"]).stdout.split("\n")
        new = run(["git", "-C", root, "ls-files", "--others", "--exclude-standard"]).stdout.split("\n")
        for name, is_new in [(n, False) for n in changed if n] + [(n, True) for n in new if n]:
            if not name.endswith(CPP_SUFFIXES):
                continue
            path = root / name
            if not path.is_file():
                continue
            checked += 1
            new_text = path.read_bytes().decode("utf-8", errors="replace")
            old_text, added = None, [l for l in new_text.split("\n")]
            if not is_new:
                shown = subprocess.run(["git", "-C", str(root), "show", f"HEAD:{name}"], stdout=subprocess.PIPE)
                old_text = shown.stdout.decode("utf-8", errors="replace")
                diff = run(["git", "-C", root, "diff", "-U0", "--", name]).stdout
                added = [l[1:] for l in diff.split("\n") if l.startswith("+") and not l.startswith("+++")]
            e, w = lint_file(f"{rel}/{name}", new_text, old_text, added)
            errors += e
            warnings += w
    return errors, warnings, checked


# ------------------------------------------------------------------ main

def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0], add_help=True,
                                     formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__)
    parser.add_argument("release", nargs="?", default="latest")
    parser.add_argument("--repo")
    parser.add_argument("--patches")
    parser.add_argument("--stop-after", metavar="NN")
    parser.add_argument("--fail-fast", action="store_true")
    parser.add_argument("--no-scripts", action="store_true")
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--workspace")
    parser.add_argument("--cache")
    parser.add_argument("--no-cache", action="store_true")
    parser.add_argument("--pwsh")
    parser.add_argument("--no-lint", action="store_true")
    parser.add_argument("--json")
    parser.add_argument("--only", help=argparse.SUPPRESS)
    args = parser.parse_args()
    started = time.time()

    if args.only:
        raise Setup("--only is not offered: a script cannot be run without the ones before it (later scripts "
                    "anchor on text earlier ones insert). Use --stop-after NN.")
    if args.stop_after and not re.fullmatch(r"\d\d", args.stop_after):
        raise Setup("--stop-after takes the two digits a script name starts with, for example --stop-after 55")

    repo = Path(args.repo).resolve() if args.repo else Path(__file__).resolve().parents[4]
    if not (repo / WORKFLOW).is_file() or not (repo / "scripts/resolve_release.py").is_file():
        raise Setup(f"{repo} is not the repository (no {WORKFLOW}). Pass --repo.")
    patches = Path(args.patches).resolve() if args.patches else repo / "patches"
    if not patches.is_dir():
        raise Setup(f"{patches} is not a folder")

    def outside_repo(path, what):
        path = Path(path).resolve()
        if path == repo or repo in path.parents:
            raise Setup(f"{what} {path} is inside the repository. Put it somewhere else.")
        return path

    pwsh = args.pwsh or os.environ.get("PREFLIGHT_PWSH") or shutil.which("pwsh")
    if not pwsh or not (shutil.which(pwsh) or Path(pwsh).is_file()):
        raise Setup("PowerShell 7 (pwsh) was not found. Install it, or pass --pwsh PATH or set PREFLIGHT_PWSH. "
                    "Windows PowerShell 5.1 (powershell.exe) is not a substitute.")
    version = run([pwsh, "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "$PSVersionTable.PSVersion.ToString()"])
    version = version.stdout.strip().splitlines()[-1] if version.stdout.strip() else "?"
    if not version.startswith("7."):
        raise Setup(f"{pwsh} is PowerShell {version}; the build runs the scripts with PowerShell 7 (pwsh).")

    cache = None
    if not args.no_cache:
        cache = outside_repo(args.cache or Path.home() / ".cache" / "wildcard-preflight", "The cache")
        cache.mkdir(parents=True, exist_ok=True)
    if args.json:
        outside_repo(args.json, "The JSON file")

    patch_files = sorted(p for p in patches.glob("*.patch"))
    script_files = sorted(p for p in patches.glob("*.ps1"))
    problems = []
    seen = {}
    for script in script_files:
        named = SCRIPT_NAME.match(script.name)
        if not named:
            problems.append(f"{script.name}: not named NN-lower-case-words.ps1; its place in the order is not certain")
        elif named.group(1) in seen:
            problems.append(f"{script.name} and {seen[named.group(1)]} share the number {named.group(1)}; "
                            "their order then depends on the rest of the name")
        else:
            seen[named.group(1)] = script.name
        if re.search(rb"['\"/\\](_bots|_scaling)[/\\]", script.read_bytes()):
            problems.append(f"{script.name}: names _bots/ or _scaling/ (the CoA bots and Content Scaling checkouts); "
                            "this pre-flight does not check those out, so the script cannot be proven here")
        if b"\r" in script.read_bytes():
            problems.append(f"{script.name}: has CR line endings; the repository keeps patches with LF")
    if args.stop_after and args.stop_after not in seen:
        raise Setup(f"--stop-after {args.stop_after}: no script starts with {args.stop_after}-")

    say(f"Pre-flight for {patches}")
    ollama_sha, workflow_steps = read_workflow(repo)
    if workflow_steps is not None:
        say("WARNING: the workflow's source steps are not the ones this script mirrors. It may no longer prepare the")
        say("         sources as the build does. Re-read .github/workflows/build-worldserver.yml against preflight.py.")
        say("         Workflow now: " + " | ".join(workflow_steps))
    lock = resolve(repo, args.release)
    say(f"Release {lock['tag']}: core {lock['core_sha'][:12]}, SQUID {lock['squid_sha'][:12]} ({lock.get('squid_tag', '')}), "
        f"Dungeon Clear {lock.get('dungeon_sha', '')[:12] or 'not in this release'}, "
        f"mod-ollama-chat {ollama_sha[:12]} (pinned in the workflow)")
    say(f"PowerShell {version} ({pwsh}); {len(patch_files)} *.patch, {len(script_files)} *.ps1")

    if args.workspace:
        workspace = outside_repo(args.workspace, "The workspace")
        if workspace.exists() and any(workspace.iterdir()):
            raise Setup(f"{workspace} is not empty. Scripts are applied once to clean sources; use a fresh folder.")
        workspace.mkdir(parents=True, exist_ok=True)
    else:
        workspace = outside_repo(tempfile.mkdtemp(prefix="wildcard-preflight-"), "The workspace")
    say(f"Workspace {workspace}" + (" (kept)" if args.keep else ""))

    results = {"release": lock["tag"], "lock": lock, "ollama_sha": ollama_sha, "patches_dir": str(patches),
               "patch_files": [], "module_patches": [], "scripts": [], "parse_errors": [], "naming": problems,
               "lint": None}
    failed = False
    try:
        # "This repository": a copy of patches/, where the workflow has its _mine checkout.
        shutil.copytree(patches, workspace / "_mine" / "patches")

        step = time.time()
        obtain(REPOS["core"], lock["core_sha"], workspace / "core", cache)
        say(f"\n== Core at the release commit ({time.time() - step:.0f} s)")

        say("== Apply our patches (inside core/, before any module is checked out)")
        for patch in sorted((workspace / "_mine" / "patches").glob("*.patch"), key=lambda p: p.name):
            entry = {"name": patch.name, "ok": True, "message": ""}
            check = run(["git", "apply", "--check", "--whitespace=nowarn", patch], cwd=workspace / "core", check=False)
            stale = stale_hunk_counts(patch)
            if stale:
                entry.update(ok=False, message=f"{patch.name}: " + "; ".join(stale))
            elif check.returncode:
                entry.update(ok=False, message=f"{patch.name} no longer fits release {lock['tag']}. The patch needs "
                                               f"refreshing for this core.\n{indent(check.stdout)}")
            else:
                done = run(["git", "apply", "--whitespace=nowarn", patch], cwd=workspace / "core", check=False)
                if done.returncode:
                    entry.update(ok=False, message=f"Applying {patch.name} failed.\n{indent(done.stdout)}")
            say(f"  {'OK  ' if entry['ok'] else 'FAIL'}  {patch.name}" + ("" if entry["ok"] else "\n" + indent(entry["message"], "        ")))
            results["patch_files"].append(entry)
            failed = failed or not entry["ok"]
        if failed:
            say("  (the build stops here; the scripts are still tried below so one run shows everything)")

        step = time.time()
        modules = [("core/modules/mod-playerbots", "squid", lock["squid_sha"])]
        if lock.get("dungeon_sha"):
            modules.append(("core/modules/mod-dungeon-clear", "dungeon", lock["dungeon_sha"]))
        for rel, key, sha in modules:
            obtain(REPOS[key], sha, workspace / rel, cache)
        if lock.get("build_sha"):
            obtain(REPOS["build"], lock["build_sha"], workspace / "_build", cache, sparse="patches")
        say(f"== SQUID's Playerbots, Dungeon Clear, the official build's module patches ({time.time() - step:.0f} s)")

        if lock.get("build_sha"):
            say("== Apply the official build's module patches (checksums as the release lists them)")
            for rel, key in (("core/modules/mod-playerbots", "squid"), ("core/modules/mod-dungeon-clear", "dungeon")):
                name = lock.get(f"{key}_patch")
                if not name:
                    continue
                if not (workspace / rel).is_dir():
                    raise Setup(f"{name} is listed but {rel} was not checked out.")
                file = (workspace / "_build" / name).resolve()
                if workspace / "_build" not in file.parents or not file.is_file():
                    raise Setup(f"{name} is not a file in the build repository's checkout.")
                digest = sha256(file)
                if digest != lock.get(f"{key}_patch_sha256"):
                    raise Setup(f"{name} checksum {digest} differs from the release's {lock.get(f'{key}_patch_sha256')}.")
                if run(["git", "-C", workspace / rel, "apply", "--check", file], check=False).returncode:
                    raise Setup(f"{name} does not apply to {rel}.")
                run(["git", "-C", workspace / rel, "apply", file])
                # The build's patch is part of the sources we patch: commit it locally so that the report below
                # shows only what OUR scripts change in the module.
                run(["git", "-C", workspace / rel, "-c", "core.autocrlf=false", "add", "-A"])
                run(["git", "-C", workspace / rel, "-c", "user.name=preflight", "-c", "user.email=preflight@localhost",
                     "-c", "core.autocrlf=false", "-c", "core.hooksPath=/dev/null", "commit", "--quiet",
                     "--no-verify", "-m", f"official build patch {name}"])
                say(f"  OK    {name} -> {rel}")
                results["module_patches"].append({"name": name, "dir": rel, "sha256": digest})

        step = time.time()
        obtain(REPOS["ollama"], ollama_sha, workspace / "core/modules/mod-ollama-chat", cache)
        say(f"== AI chat for bots, mod-ollama-chat ({time.time() - step:.0f} s)")

        scripts_seconds = 0.0
        if args.no_scripts:
            say("== Apply our patch scripts: SKIPPED (--no-scripts): the workspace holds the core with the *.patch files only")
        else:
            say("== Apply our patch scripts (patches/*.ps1, in name order, from the workspace root)")
            for problem in problems:
                say(f"  WARNING  {problem}")
            driver = workspace / "_preflight"
            driver.mkdir()
            (driver / "driver.ps1").write_text(DRIVER, encoding="utf-8")
            cmd = [pwsh, "-NoLogo", "-NoProfile", "-NonInteractive", "-File", str(driver / "driver.ps1")]
            if args.stop_after:
                cmd += ["-StopAfter", args.stop_after]
            if args.fail_fast:
                cmd += ["-FailFast"]
            env = git_env()
            env["GIT_CONFIG_COUNT"] = "1"
            env["GIT_CONFIG_KEY_0"] = "core.autocrlf"
            env["GIT_CONFIG_VALUE_0"] = "false"
            step = time.time()
            process = subprocess.Popen(cmd, cwd=workspace, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, encoding="utf-8", errors="replace")
            current, order, stray = None, [], []
            for raw in process.stdout:
                line = raw.rstrip("\n")
                if line.startswith("@@ORDER "):
                    order = line[8:].split("|")
                elif line.startswith("@@PARSE "):
                    name, at, message = line[8:].split("\t", 2)
                    say(f"  FAIL  {name}: PowerShell syntax error at line {at}: {message}")
                    results["parse_errors"].append({"name": name, "line": at, "message": message})
                    failed = True
                elif line.startswith("@@BEGIN "):
                    current = {"name": line[8:], "ok": False, "message": "", "at": "", "touched": [], "ms": 0, "output": []}
                elif line.startswith("@@FAIL ") and current:
                    _, at, message = line[7:].split("\t", 2)
                    current.update(message=message if len(message) <= 500 else message[:500] + " ...", at=at)
                elif line.startswith("@@TOUCH ") and current:
                    _, path, change = line[8:].split("\t", 2)
                    current["touched"].append(f"{path} ({change})")
                elif line.startswith("@@OK ") and current:
                    current["ok"] = True
                elif line.startswith("@@END ") and current:
                    current["ms"] = int(line.split("\t")[1])
                    first_failure = not current["ok"] and not any(not s["ok"] for s in results["scripts"])
                    if current["ok"]:
                        note = "" if current["touched"] else "   WARNING: changed no file"
                        say(f"  OK    {current['name']}  ({len(current['touched'])} file(s), {current['ms'] / 1000:.1f} s){note}")
                    else:
                        failed = True
                        say(f"  FAIL  {current['name']}  at {current['at'] or '?'}")
                        say(f"        {current['message']}")
                        if current["touched"]:
                            say("        (it had already changed: " + "; ".join(current["touched"]) + ")")
                        if not first_failure:
                            say("        (an earlier script failed too: this may be a knock-on, fix the first failure first)")
                    results["scripts"].append(current)
                    current = None
                elif line.startswith("@@STOPPED "):
                    say(f"  -- stopped after {line[10:]} (--stop-after)")
                elif current is not None:
                    current["output"].append(line)
                elif line.strip():
                    stray.append(line)
            code = process.wait()
            if current is not None:
                current["message"] = "PowerShell ended while this script ran:\n" + "\n".join(current["output"][-15:])
                results["scripts"].append(current)
                failed = True
                say(f"  FAIL  {current['name']}\n{indent(current['message'], '        ')}")
            if code or (not results["scripts"] and script_files):
                raise Setup(f"the PowerShell driver exited {code}:\n{indent(chr(10).join(stray[-20:]))}")
            expected = [p.name for p in script_files]
            if order != expected:
                say("  WARNING  PowerShell's name order differs from plain alphabetical order: " + ", ".join(order))
            results["order"] = order
            scripts_seconds = time.time() - step

        repos = ["core", "core/modules/mod-playerbots", "core/modules/mod-dungeon-clear", "core/modules/mod-ollama-chat"]
        lint_errors, lint_warnings, lint_checked = [], [], 0
        if not args.no_lint:
            lint_errors, lint_warnings, lint_checked = lint(workspace, repos)
            say(f"\n== C++ text check of the {lint_checked} touched source files (a heuristic, NOT a compiler: it finds "
                "unbalanced\n   brackets, text glued to an #include line, mixed line endings, Windows macro names)")
            for line in lint_errors:
                say(f"  ERROR    {line}")
            for line in lint_warnings:
                say(f"  WARNING  {line}")
            if not lint_errors and not lint_warnings:
                say("  nothing found")
            results["lint"] = {"checked": lint_checked, "errors": lint_errors, "warnings": lint_warnings}

        say("\n== What changed (git diff --stat; our scripts and patches only)")
        for rel in repos:
            if not (workspace / rel / ".git").exists():
                continue
            stat = run(["git", "-C", workspace / rel, "diff", "--stat", "--stat-width=110"]).stdout.rstrip()
            new = [n for n in run(["git", "-C", workspace / rel, "ls-files", "--others", "--exclude-standard"]).stdout.split("\n") if n]
            if not stat and not new:
                continue
            say(f"-- {rel}")
            if stat:
                say(indent(stat, " "))
            for name in new:
                say(f"  new file: {name}")

        ran = results["scripts"]
        bad_patches = [p["name"] for p in results["patch_files"] if not p["ok"]]
        bad_scripts = [s["name"] for s in ran if not s["ok"]]
        idle = [s["name"] for s in ran if s["ok"] and not s["touched"]]
        say("\n== Summary")
        say(f"  release        {lock['tag']} (core {lock['core_sha'][:12]})")
        say(f"  *.patch        {len(results['patch_files']) - len(bad_patches)} of {len(results['patch_files'])} applied"
            + (f"; FAILED: {', '.join(bad_patches)}" if bad_patches else ""))
        say("  *.ps1          not run (--no-scripts)" if args.no_scripts else
            f"  *.ps1          {len(ran) - len(bad_scripts)} of {len(ran)} run applied"
            + (f" ({len(script_files) - len(ran)} not run)" if len(ran) < len(script_files) else "")
            + (f"; FAILED: {', '.join(bad_scripts)}" if bad_scripts else "")
            + f"; {scripts_seconds:.0f} s")
        if results["parse_errors"]:
            say(f"  syntax         {len(results['parse_errors'])} PowerShell syntax error(s) in: "
                + ", ".join(sorted({e['name'] for e in results['parse_errors']})))
        if not args.no_scripts:
            say("  applied once   each script ran exactly once, in the build's order, on freshly checked out sources")
        if idle:
            say(f"  no effect      {', '.join(idle)} reported success but changed no file: check its anchors")
        if not args.no_lint:
            say(f"  text check     {len(lint_errors)} error(s), {len(lint_warnings)} warning(s) in {lint_checked} files")
        failed = failed or bool(lint_errors)
        results["ok"] = not failed
        results["seconds"] = round(time.time() - started, 1)
        say(f"  wall time      {time.time() - started:.0f} s")
        if args.no_scripts:
            passed = "PASS: every *.patch file applies to this release. Scripts NOT run (--no-scripts)."
        elif len(ran) < len(script_files):
            passed = (f"PASS: every *.patch file and the {len(ran)} script(s) that ran apply to this release. "
                      f"{len(script_files) - len(ran)} script(s) NOT run.")
        else:
            passed = "PASS: every patch and script applies to this release."
        say("  RESULT         " + (passed + " NOT proven: that it compiles, links, starts or behaves." if not failed else
                                   "FAIL: a build of this would fail (or build something wrong). Fix and run again."))
        if args.json:
            for script in results["scripts"]:
                script.pop("output", None)
            Path(args.json).write_text(json.dumps(results, indent=1), encoding="utf-8")
    finally:
        if args.keep:
            say(f"\nWorkspace kept: {workspace}")
        else:
            shutil.rmtree(workspace, ignore_errors=True)
    return 1 if failed else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Setup as error:
        print(f"\nPRE-FLIGHT COULD NOT RUN: {error}", file=sys.stderr)
        sys.exit(2)
    except KeyboardInterrupt:
        sys.exit(2)
