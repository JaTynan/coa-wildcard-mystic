#!/usr/bin/env python3
"""Wildcard launcher for Linux: keeps the game client current and points it at the server.

The same job as the Windows launcher (WildcardLauncher.ps1), from a terminal, with only Python 3 (no extra packages):

  1. Reads launcher.json from the server's site (https://wildcard.jtlab.cc unless launcher-site.txt says otherwise).
  2. Updates itself if the site has a newer Linux launcher.
  3. First run: downloads the whole client (one archive, from the seedbox), resuming if interrupted, and unpacks it.
  4. Every run: compares the client with the site's manifest and downloads only the files that differ. A file whose
     size and modified time match the manifest is taken as current; others are checked by MD5.
  5. Points the game at the server (realmList in WTF/Config.wtf and realmlist.wtf in each Data/<locale> folder).
  6. Says whether the game server answers, and with --play starts the game with your own command (Wine, Bottles...).

Usage:
  python3 WildcardLauncher.py                 update, then exit
  python3 WildcardLauncher.py --play          update, then start the game
  python3 WildcardLauncher.py --set-play "flatpak run --command=bottles-cli com.usebottles.bottles run -b CoA -e {exe}"
                                              remember how to start the game ({exe} = full path to Ascension.exe)

Everything lives next to this file: the CoAClient folder, launcher-state.json (file checks), launcher-linux.json
(your play command) and launcher.log (every step and error; send it to James if something goes wrong).
"""

import argparse
import hashlib
import json
import os
import re
import shlex
import shutil
import socket
import subprocess
import sys
import tarfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

LAUNCHER_VERSION = 1

HERE = Path(__file__).resolve().parent
CLIENT = HERE / "CoAClient"
STATE_FILE = HERE / "launcher-state.json"
SETTINGS_FILE = HERE / "launcher-linux.json"
LOG_FILE = HERE / "launcher.log"
SITE_FILE = HERE / "launcher-site.txt"
SECRET_FILE = HERE / "launcher-secret.json"
SKIP_NAMES = {"web.config"}
GB = 1024 ** 3


def log(text):
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as handle:
            handle.write(time.strftime("%Y-%m-%d %H:%M:%S  ") + text + "\n")
    except OSError:
        pass


def say(text):
    print("\r\033[K" + text, flush=True)
    log(text)


def progress(text):
    sys.stdout.write("\r\033[K" + text[:max(20, shutil.get_terminal_size((100, 20)).columns - 1)])
    sys.stdout.flush()


def size(n):
    n = float(n or 0)
    if n >= GB:
        return f"{n / GB:.1f} GB"
    if n >= 1024 ** 2:
        return f"{n / 1024 ** 2:.0f} MB"
    return f"{n / 1024:.0f} KB"


def site():
    try:
        return SITE_FILE.read_text(encoding="utf-8").strip().rstrip("/") or "https://wildcard.jtlab.cc"
    except OSError:
        return "https://wildcard.jtlab.cc"


def site_headers():
    headers = {"User-Agent": f"WildcardLauncher-Linux/{LAUNCHER_VERSION}"}
    try:
        secret = json.loads(SECRET_FILE.read_text(encoding="utf-8-sig"))
        if secret.get("id"):
            headers["CF-Access-Client-Id"] = secret["id"]
            headers["CF-Access-Client-Secret"] = secret.get("secret", "")
    except (OSError, ValueError):
        pass
    return headers


def explain(error, url):
    host = re.sub(r"^https?://([^/:]+).*$", r"\1", url)
    if isinstance(error, urllib.error.HTTPError):
        if error.code == 404:
            return f"{host} does not have that file (HTTP 404); tell James"
        if error.code >= 500:
            return f"James's site is down right now (HTTP {error.code}); try again later or tell James"
        return f"{host} refused the request (HTTP {error.code}); tell James"
    reason = getattr(error, "reason", error)
    if isinstance(reason, socket.gaierror):
        return f"cannot find {host} (no internet, or the address is wrong)"
    if isinstance(reason, (socket.timeout, TimeoutError)):
        return f"{host} did not answer in time (slow connection, or James's server is busy)"
    if isinstance(reason, ConnectionRefusedError):
        return f"cannot connect to {host} (no internet, or a firewall is blocking it)"
    return f"{host}: {reason}"


def get_json(url):
    request = urllib.request.Request(url, headers=site_headers())
    try:
        with urllib.request.urlopen(request, timeout=20) as reply:
            return json.loads(reply.read().decode("utf-8-sig"))
    except (urllib.error.URLError, OSError, ValueError) as error:
        raise RuntimeError(explain(error, url)) from error


def get_file(url, target, label, use_site_headers=True):
    """Downloads to target (via target.part, resuming it), with a progress line."""
    target = Path(target)
    part = target.with_name(target.name + ".part")
    target.parent.mkdir(parents=True, exist_ok=True)
    have = part.stat().st_size if part.exists() else 0
    headers = site_headers() if use_site_headers else {"User-Agent": f"WildcardLauncher-Linux/{LAUNCHER_VERSION}"}
    if have:
        headers["Range"] = f"bytes={have}-"
        log(f"Resuming {label} at {size(have)}")
    request = urllib.request.Request(url, headers=headers)
    try:
        reply = urllib.request.urlopen(request, timeout=30)
    except (urllib.error.URLError, OSError) as error:
        log(f"Download failed: {url} ({error})")
        raise RuntimeError(explain(error, url)) from error
    with reply:
        if have and reply.status != 206:
            have = 0  # the server ignored the resume request: start again
        total = have + int(reply.headers.get("Content-Length") or 0)
        started, last, done = time.time(), 0.0, have
        with open(part, "ab" if have else "wb") as out:
            while True:
                chunk = reply.read(1024 * 1024)
                if not chunk:
                    break
                out.write(chunk)
                done += len(chunk)
                now = time.time()
                if now - last > 0.25:
                    last = now
                    speed = (done - have) / max(1.0, now - started)
                    left = (total - done) / speed if speed and total else 0
                    eta = f", about {int(left // 60)} min left" if left > 90 else ""
                    progress(f"{label}: {size(done)} of {size(total)} ({size(speed)}/s{eta})")
    os.replace(part, target)


def md5(path, done, total):
    digest = hashlib.md5()
    with open(path, "rb") as handle:
        while True:
            block = handle.read(4 * 1024 * 1024)
            if not block:
                break
            digest.update(block)
            done[0] += len(block)
            progress(f"Checking your game files: {size(done[0])} of {size(total)} ({path.name})")
    return digest.hexdigest()


def local_path(relative):
    return CLIENT.joinpath(*relative.replace("\\", "/").split("/"))


def read_state():
    try:
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def save_state(state):
    temporary = STATE_FILE.with_suffix(".tmp")
    temporary.write_text(json.dumps(state), encoding="utf-8")
    os.replace(temporary, STATE_FILE)


def local_hash(state, relative, expected, done, total):
    path = local_path(relative)
    if not path.is_file():
        return None
    info = path.stat()
    stamp = f"{info.st_size}|{info.st_mtime_ns}"
    known = state.get(relative)
    if known and known.get("stamp") == stamp:
        return known.get("md5")
    if expected.get("mtime") and info.st_size == int(expected["size"]) and int(info.st_mtime) == int(expected["mtime"]):
        state[relative] = {"stamp": stamp, "md5": expected["md5"]}
        return expected["md5"]
    value = md5(path, done, total)
    state[relative] = {"stamp": stamp, "md5": value}
    return value


def update_self(info):
    newest = int(info.get("linuxLauncherVersion") or 0)
    if newest <= LAUNCHER_VERSION:
        return
    say(f"Updating the launcher to version {newest}...")
    me = Path(__file__).resolve()
    get_file(f"{site()}/WildcardLauncher.py", me.with_name("WildcardLauncher.py.new"), "Launcher")
    os.replace(me.with_name("WildcardLauncher.py.new"), me)
    os.execv(sys.executable, [sys.executable, str(me)] + sys.argv[1:])


def install_client(info):
    if (CLIENT / "Ascension.exe").exists():
        return
    archive = HERE / "CoAClient.tar"
    need = int(info.get("clientArchiveBytes") or 0) * 2 + 5 * GB
    free = shutil.disk_usage(HERE).free
    if not archive.exists() and free < need:
        raise RuntimeError(f"The first install needs about {size(need)} free here (the download plus the unpacked "
                           f"game); there is {size(free)}.")
    if not archive.exists():
        say(f"Downloading the game ({size(info.get('clientArchiveBytes'))}) from the seedbox. If it stops, run the "
            "launcher again and it carries on.")
        get_file(info["clientArchiveUrl"], archive, "Downloading the game", use_site_headers=False)
        print()
    say("Unpacking the game (a few minutes)...")
    with tarfile.open(archive) as tar:
        members = tar.getmembers()
        for index, member in enumerate(members, 1):
            if index % 25 == 0:
                progress(f"Unpacking: {index} of {len(members)} files")
            if hasattr(tarfile, "data_filter"):
                tar.extract(member, HERE, filter="data")
            else:
                tar.extract(member, HERE)
    print()
    archive.unlink()
    say("Unpacked the game.")


def sync_client():
    say(f"Checking for updates from {site()}...")
    manifest = get_json(f"{site()}/manifest.json")
    files = [entry for entry in manifest.get("files", [])
             if entry["path"].replace("\\", "/").split("/")[-1].lower() not in SKIP_NAMES]
    log(f"Manifest: {len(files)} files, generated {manifest.get('generated')}")
    state = read_state()
    total = sum(int(entry["size"]) for entry in files)
    done = [0]
    stale = []
    started = time.time()
    for index, entry in enumerate(files, 1):
        before = done[0]
        if local_hash(state, entry["path"], entry, done, total) != entry["md5"]:
            stale.append(entry)
        if done[0] == before:
            done[0] += int(entry["size"])
        progress(f"Checking your game files: {size(done[0])} of {size(total)} ({index} of {len(files)} files)")
        if index % 20 == 0:
            save_state(state)
    save_state(state)
    print()
    log(f"Checked {len(files)} files in {time.time() - started:.0f} s; {len(stale)} need downloading "
        f"({size(sum(int(e['size']) for e in stale))})")

    failed = []
    for count, entry in enumerate(stale, 1):
        relative = entry["path"].replace("\\", "/")
        target = local_path(relative)
        url = f"{site()}/client/" + "/".join(urllib.parse.quote(part) for part in relative.split("/"))
        log(f"Downloading {relative} ({size(entry['size'])})")
        try:
            get_file(url, target, f"Updating {target.name} ({count} of {len(stale)})")
        except RuntimeError as error:
            log(f"Could not download {relative}: {error}")
            failed.append(relative)
            continue
        if entry.get("mtime"):
            os.utime(target, (int(entry["mtime"]), int(entry["mtime"])))
        local_hash(state, entry["path"], entry, [0], 0)
        save_state(state)
    if stale:
        print()
    for gone in manifest.get("remove", []) or []:
        path = local_path(gone)
        if path.is_file():
            path.unlink()
            log(f"Removed {gone}")
        state.pop(gone, None)
    save_state(state)
    if failed:
        raise RuntimeError(f"{len(failed)} file(s) could not be downloaded, first {failed[0]}: see launcher.log; "
                           "tell James")
    return len(stale)


def set_realm(realm):
    wtf = CLIENT / "WTF"
    wtf.mkdir(parents=True, exist_ok=True)
    config = wtf / "Config.wtf"
    lines = []
    if config.exists():
        lines = [line for line in config.read_text(encoding="utf-8", errors="replace").splitlines()
                 if not re.match(r"(?i)^\s*SET\s+realmList\s", line)]
    lines.append(f'SET realmList "{realm}"')
    config.write_text("\r\n".join(lines) + "\r\n", encoding="ascii", errors="replace")
    data = CLIENT / "Data"
    locales = [folder for folder in data.iterdir() if folder.is_dir() and re.fullmatch(r"[a-z]{2}[A-Z]{2}", folder.name)] \
        if data.is_dir() else []
    if not locales:
        locales = [data / "enUS"]
        locales[0].mkdir(parents=True, exist_ok=True)
    for folder in locales:
        (folder / "realmlist.wtf").write_text(f"set realmlist {realm}\r\n", encoding="ascii")
    log(f"Game points at {realm}")


def check_server(realm):
    try:
        with socket.create_connection((realm, 3724), timeout=5):
            say(f"Game server: online ({realm})")
            return True
    except OSError as error:
        say(f"Game server: not answering ({realm}: {error}). It may be restarting; try again in a few minutes.")
        return False


def settings():
    try:
        return json.loads(SETTINGS_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def play():
    command = settings().get("play")
    exe = CLIENT / "Ascension.exe"
    if not command:
        if shutil.which("wine"):
            command = "wine {exe}"
        else:
            say("No play command set and Wine is not installed. Set one, for example:\n"
                f"  python3 {Path(__file__).name} --set-play \"flatpak run --command=bottles-cli "
                "com.usebottles.bottles run -b YOUR-BOTTLE -e {exe}\"")
            return 1
    parts = [part.replace("{exe}", str(exe)) for part in shlex.split(command)]
    say("Starting the game: " + " ".join(shlex.quote(part) for part in parts))
    subprocess.Popen(parts, cwd=str(CLIENT), start_new_session=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return 0


def main():
    parser = argparse.ArgumentParser(description="Wildcard launcher for Linux")
    parser.add_argument("--play", action="store_true", help="start the game after updating")
    parser.add_argument("--set-play", metavar="COMMAND",
                        help='remember how to start the game; {exe} becomes the path to Ascension.exe')
    options = parser.parse_args()

    if options.set_play:
        saved = settings()
        saved["play"] = options.set_play
        SETTINGS_FILE.write_text(json.dumps(saved, indent=2), encoding="utf-8")
        say(f"Saved. --play will run: {options.set_play}")
        return 0

    log(f"---- Linux launcher {LAUNCHER_VERSION} started in {HERE}")
    info = None
    status = 0
    try:
        say(f"Contacting {site()}...")
        info = get_json(f"{site()}/launcher.json")
        update_self(info)
        install_client(info)
        changed = sync_client()
        say(f"Up to date ({changed} file(s) updated). Have fun!" if changed else "Up to date. Have fun!")
    except RuntimeError as error:
        print()
        say(f"Could not finish updating: {error}")
        status = 1
    except KeyboardInterrupt:
        print()
        say("Stopped. Run the launcher again to carry on where it left off.")
        return 130
    realm = (info or {}).get("realm") or "wow.jtlab.cc"
    if (CLIENT / "Ascension.exe").exists():
        try:
            set_realm(realm)
        except OSError as error:
            say(f"Could not set the server address: {error}")
    check_server(realm)
    if options.play:
        if not (CLIENT / "Ascension.exe").exists():
            say("The game is not installed yet, so it cannot start.")
            return 1
        return play()
    return status


if __name__ == "__main__":
    sys.exit(main())
