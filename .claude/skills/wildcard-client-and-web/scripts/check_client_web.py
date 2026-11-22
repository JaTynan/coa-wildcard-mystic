#!/usr/bin/env python3
"""Static pre-merge check of the friends-facing files (launcher, site, sign-up, addons, client patch).

Reads the repository only: no network, no VM, nothing written. Python 3 standard library only.

Usage:
  python3 check_client_web.py                 check the repository this skill sits in
  python3 check_client_web.py --repo <path>   check another checkout

Exit code 0 when there is no FAIL line, 1 otherwise. WARN lines are for a person to read.
What it cannot do: run PowerShell (the .ps1 files are only read as text), talk to the VM, or prove an addon works
in the game.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True  # importing client-patch/custom_spells.py must not leave __pycache__ in the repo

results = {"ok": 0, "warn": 0, "fail": 0}


def say(level, text):
    results[level] += 1
    print(f"{level.upper():4}  {text}")


def read(path):
    return path.read_text(encoding="utf-8-sig", errors="replace")


def tracked(repo):
    try:
        out = subprocess.run(["git", "-C", str(repo), "ls-files"], capture_output=True, text=True, timeout=60)
        if out.returncode == 0 and out.stdout.strip():
            return [line for line in out.stdout.splitlines() if line]
    except (OSError, subprocess.SubprocessError):
        pass
    return [str(p.relative_to(repo)).replace("\\", "/") for p in repo.rglob("*")
            if p.is_file() and ".git/" not in str(p.relative_to(repo)).replace("\\", "/") + "/"]


def check_launcher(repo):
    ps1, py = repo / "launcher" / "WildcardLauncher.ps1", repo / "launcher" / "WildcardLauncher.py"
    # The exact patterns Publish-WildcardSite.ps1 uses to read the two version numbers.
    win = re.findall(r"(?m)^\$LauncherVersion = (\d+)", read(ps1))
    lin = re.findall(r"(?m)^LAUNCHER_VERSION = (\d+)", read(py))
    if len(win) == 1 and len(lin) == 1:
        say("ok", f"launcher versions readable by the publish script: Windows {win[0]}, Linux {lin[0]}")
    else:
        say("fail", f"publish cannot read a launcher version (Windows matches {win}, Linux matches {lin}); "
                    "the line must start at column 0 exactly as '$LauncherVersion = N' / 'LAUNCHER_VERSION = N'")
    try:
        settings = json.loads(read(repo / "launcher" / "launcher-settings.json"))
    except ValueError as error:
        say("fail", f"launcher-settings.json is not valid JSON: {error}")
        return
    missing = [key for key in ("site", "realm", "clientArchiveUrl", "clientArchiveBytes", "remove") if key not in settings]
    if missing:
        say("fail", f"launcher-settings.json lacks {', '.join(missing)}")
    else:
        say("ok", "launcher-settings.json has site, realm, clientArchiveUrl, clientArchiveBytes, remove")
    realm = str(settings.get("realm", ""))
    if not re.fullmatch(r"[A-Za-z0-9.\-]+", realm):
        say("fail", f"launcher-settings.json realm '{realm}' is not a plain host name")
    if not isinstance(settings.get("clientArchiveBytes"), int) or settings.get("clientArchiveBytes", 0) <= 0:
        say("fail", "clientArchiveBytes must be a whole number of bytes (the launcher's free-space check uses it)")
    if not isinstance(settings.get("remove"), list):
        say("fail", "remove must be a list of client-relative paths (may be empty)")
    # The fallback address each launcher uses when launcher.json cannot be read.
    fallbacks = set(re.findall(r"else \{ '([A-Za-z0-9.\-]+)' \}", read(ps1).split("$realm = if", 1)[-1][:200]))
    fallbacks |= set(re.findall(r'\.get\("realm"\) or "([A-Za-z0-9.\-]+)"', read(py)))
    if fallbacks == {realm}:
        say("ok", f"both launchers fall back to the same realm as launcher-settings.json ({realm})")
    else:
        say("warn", f"launcher fallback realm(s) {sorted(fallbacks)} differ from launcher-settings.json ({realm})")
    server_settings = repo / "server-settings" / "server-settings.txt"
    if server_settings.exists():
        found = re.findall(r"(?m)^\s*realmlist\s*\|\s*address\s*=\s*(\S+)\s*$", read(server_settings))
        if found and found[-1] == realm:
            say("ok", f"server-settings 'realmlist | address' matches the launcher realm ({realm})")
        elif found:
            say("warn", f"server-settings 'realmlist | address' is {found[-1]} but the launcher sends friends to {realm}")
        else:
            say("warn", "no 'realmlist | address' line in server-settings.txt (patch night then uses the manager's address)")


def check_python(repo):
    bad = 0
    files = sorted((repo / "launcher").glob("*.py")) + sorted((repo / "signup").glob("*.py")) + \
        sorted((repo / "client-patch").glob("*.py"))
    for path in files:
        try:
            compile(read(path), str(path), "exec")
        except SyntaxError as error:
            bad += 1
            say("fail", f"{path.relative_to(repo)} does not compile: {error}")
    if not bad:
        say("ok", f"{len(files)} Python files under launcher/, signup/ and client-patch/ compile")


def check_powershell_text(repo):
    for path in sorted((repo / "launcher").glob("*.ps1")) + sorted((repo / "signup").glob("*.ps1")):
        raw = path.read_bytes()
        if raw.startswith(b"\xef\xbb\xbf"):
            continue
        odd = sorted({b for b in raw if b > 127})
        if odd:
            say("warn", f"{path.relative_to(repo)} has non-ASCII bytes and no UTF-8 BOM; Windows PowerShell 5.1 "
                        "may misread them (heuristic, not an observed failure)")
    say("ok", "PowerShell files were read as text only (this check cannot parse or run them)")


def check_site(repo):
    site = repo / "launcher" / "site"
    js = read(site / "site.js")
    block = js.split("const PAGES = [", 1)[-1].split("];", 1)[0]
    pages = re.findall(r'\["([a-z\-]+)",\s*"([^"]+)",\s*"([^"]+)"\]', block)
    if not pages:
        say("fail", "could not read the PAGES list in launcher/site/site.js")
        return
    problems = 0
    for page_id, href, _ in pages:
        name = "index.html" if href == "./" else href
        path = site / name
        if not path.exists():
            problems += 1
            say("fail", f"site.js lists {href} but launcher/site/{name} does not exist")
            continue
        text = read(path)
        if f'data-page="{page_id}"' not in text:
            problems += 1
            say("fail", f"launcher/site/{name} lacks <body data-page=\"{page_id}\"> (the menu will not mark it)")
        if 'src="site.js"' not in text:
            problems += 1
            say("fail", f"launcher/site/{name} does not load site.js (no header, footer or status)")
    listed = {("index.html" if href == "./" else href) for _, href, _ in pages}
    for path in sorted(site.glob("*.html")):
        if path.name not in listed:
            say("warn", f"launcher/site/{path.name} is not in site.js PAGES (published, but not in the menu)")
    if not problems:
        say("ok", f"{len(pages)} site pages in site.js PAGES exist, name themselves and load site.js")
    signup = read(repo / "signup" / "WildcardSignup.py")
    for _, href, _ in pages:
        if href != "./" and href not in signup:
            say("warn", f"the sign-up page's own menu (PAGE in signup/WildcardSignup.py) has no link to {href}")


def check_addons(repo):
    addon_root = repo / "addon"
    for folder in sorted(p for p in addon_root.iterdir() if p.is_dir()):
        toc = folder / f"{folder.name}.toc"
        if not toc.exists():
            say("fail", f"addon/{folder.name} has no {folder.name}.toc (the client will not list it)")
            continue
        lines = read(toc).splitlines()
        meta = dict(re.match(r"##\s*([^:]+):\s*(.*)$", line).groups() for line in lines if line.startswith("##") and ":" in line)
        files = [line.strip() for line in lines if line.strip() and not line.startswith("#")]
        missing = [name for name in files if not (folder / name).exists()]
        unlisted = [p.name for p in sorted(folder.glob("*.lua")) if p.name not in files]
        if meta.get("Interface") != "30300":
            say("fail", f"addon/{folder.name}: Interface is {meta.get('Interface')!r}, the 3.3.5 client wants 30300")
        if missing:
            say("fail", f"addon/{folder.name}: the .toc lists {', '.join(missing)}, not in the folder")
        if unlisted:
            say("warn", f"addon/{folder.name}: {', '.join(unlisted)} is in the folder but not in the .toc (never loaded)")
        lua_versions = set()
        for lua in folder.glob("*.lua"):
            head = "\n".join(read(lua).splitlines()[:40]) if lua.stat().st_size < 400000 else ""
            lua_versions |= set(re.findall(r"(?i)\bversion\s*=\s*[\"']([0-9.]+)[\"']", head))
        note = ""
        if lua_versions and lua_versions != {meta.get("Version")}:
            say("fail", f"addon/{folder.name}: Lua says version {sorted(lua_versions)}, the .toc says {meta.get('Version')}")
        elif not lua_versions:
            note = " (declared in the .toc only; no version constant in the Lua)"
        if not missing and meta.get("Interface") == "30300":
            say("ok", f"addon/{folder.name}: version {meta.get('Version')}{note}, {len(files)} file(s) listed and present")
    pins = addon_root / "third-party-addons.txt"
    if pins.exists():
        good = bad = 0
        for line in read(pins).splitlines():
            if re.match(r"^\s*(#|$)", line):
                continue
            parts = [part.strip() for part in line.split("|")]
            # The same test PatchNight.ps1 (FetchRepo) applies before it installs a line.
            if len(parts) < 3 or not re.fullmatch(r"[0-9a-f]{40}", parts[1]) or not re.fullmatch(r"[\w.\-]+/[\w.\-]+", parts[0]):
                bad += 1
                say("fail", f"third-party-addons.txt line would be skipped by patch night: {line[:80]}")
            else:
                good += 1
        if not bad:
            say("ok", f"third-party-addons.txt: {good} addon source(s), each pinned to a full 40-character commit")


def check_custom_spells(repo):
    target = repo / "sql" / "enchants" / "150-custom-spells.sql"
    sys.path.insert(0, str(repo / "client-patch"))
    try:
        import custom_spells
    except Exception as error:  # noqa: BLE001 - report whatever stops the import
        say("fail", f"client-patch/custom_spells.py cannot be imported: {error!r}")
        return
    finally:
        sys.path.pop(0)
    generated = custom_spells.sql()
    committed = target.read_text(encoding="utf-8", errors="replace").replace("\r\n", "\n") if target.exists() else None
    if committed is None:
        say("fail", "sql/enchants/150-custom-spells.sql is missing")
    elif generated == committed:
        say("ok", f"sql/enchants/150-custom-spells.sql matches client-patch/custom_spells.py ({len(custom_spells.SPELLS)} spells, "
                  f"ids {min(custom_spells.SPELLS)}-{max(custom_spells.SPELLS)})")
    else:
        say("fail", "sql/enchants/150-custom-spells.sql differs from what custom_spells.py prints: regenerate it "
                    "(python3 client-patch/custom_spells.py > sql/enchants/150-custom-spells.sql), never edit it by hand")


SECRETS = [
    ("GitHub fine-grained token", re.compile(r"github_pat_[A-Za-z0-9_]{20,}")),
    ("GitHub classic token", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}")),
    ("Cloudflare Turnstile secret", re.compile(r"\b0x4[A-Za-z0-9_\-]{30,}")),
    ("Cloudflare Access client secret header value", re.compile(r"CF-Access-Client-Secret['\"]?\s*[:=]\s*['\"][A-Za-z0-9]{20,}")),
]
CLIENT_DATA = (".mpq", ".dbc", ".blp", ".m2", ".wmo", ".adt")
SECRET_FILES = ("signup-settings.json", "signup-state.json", "launcher-secret.json")


def check_public_repo_rules(repo):
    files = tracked(repo)
    found = False
    for name in files:
        lower = name.lower()
        if lower.endswith(CLIENT_DATA):
            found = True
            say("fail", f"client data file is tracked: {name} (the client's own data is never published)")
        if lower.rsplit("/", 1)[-1] in SECRET_FILES:
            found = True
            say("fail", f"a secrets or state file is tracked: {name}")
        if "__pycache__/" in name:
            say("warn", f"compiled Python is tracked although .gitignore lists __pycache__/: {name}")
        if lower.endswith((".png", ".jpg", ".pyc", ".zip", ".mpq")):
            continue
        path = repo / name
        try:
            if path.stat().st_size > 2_000_000:
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for label, pattern in SECRETS:
            if pattern.search(text):
                found = True
                say("fail", f"{label} pattern in {name} (value not printed)")
    if not found:
        say("ok", f"no client data files, secrets files or token patterns among {len(files)} tracked files")
    settings = repo / "launcher" / "launcher-settings.json"
    if settings.exists() and "/share/" in read(settings):
        say("warn", "launcher-settings.json carries the first-install share link in a public repository (it is also "
                    "served in launcher.json by design; see the skill's 'Known weak points')")


def main():
    parser = argparse.ArgumentParser(description="Static check of the Wildcard friends-facing files")
    parser.add_argument("--repo", default=str(Path(__file__).resolve().parents[4]),
                        help="repository root (default: the checkout this script sits in)")
    repo = Path(parser.parse_args().repo).resolve()
    if not (repo / "launcher" / "WildcardLauncher.ps1").exists():
        print(f"FAIL  {repo} is not the coa-wildcard-mystic repository (no launcher/WildcardLauncher.ps1)")
        return 1
    print(f"Checking {repo}")
    for check in (check_launcher, check_python, check_powershell_text, check_site, check_addons, check_custom_spells,
                  check_public_repo_rules):
        try:
            check(repo)
        except Exception as error:  # noqa: BLE001 - one broken check must not hide the others
            say("fail", f"{check.__name__} stopped: {error!r}")
    print(f"\n{results['ok']} ok, {results['warn']} warning(s), {results['fail']} failure(s)")
    return 1 if results["fail"] else 0


if __name__ == "__main__":
    sys.exit(main())
