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
  python3 WildcardLauncher.py --add-to-steam  add the game to Steam with Proton (close Steam first); --play then
                                              starts it through Steam (also makes the shortcut below)
  python3 WildcardLauncher.py --add-shortcut  add a Wildcard shortcut to the app menu and desktop that updates the
                                              game and starts it in one click
  python3 WildcardLauncher.py --set-play "flatpak run --command=bottles-cli com.usebottles.bottles run -b CoA -e {exe}"
                                              remember how to start the game ({exe} = full path to Ascension.exe)

Everything lives next to this file: the CoAClient folder, launcher-state.json (file checks), launcher-linux.json
(your play command) and launcher.log (every step and error; send it to James if something goes wrong).
"""

import argparse
import zlib
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

LAUNCHER_VERSION = 3

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


# ---------------------------------------------------------------- Steam (Proton)
STEAM_NAME = "Wildcard"
STEAM_PROTON = "proton_experimental"


def steam_roots():
    """Steam installs on this machine: (path, is_flatpak), native first."""
    home = Path.home()
    found = []
    for path, flatpak in ((home / ".steam" / "steam", False), (home / ".local" / "share" / "Steam", False),
                          (home / ".var" / "app" / "com.valvesoftware.Steam" / ".local" / "share" / "Steam", True),
                          (home / ".var" / "app" / "com.valvesoftware.Steam" / "data" / "Steam", True)):
        try:
            real = path.resolve()
        except OSError:
            continue
        if (real / "userdata").is_dir() and real not in [r for r, _ in found]:
            found.append((real, flatpak))
    return found


def steam_running():
    for proc in Path("/proc").iterdir():
        if proc.name.isdigit():
            try:
                if (proc / "comm").read_text().strip() in ("steam", "steamwebhelper"):
                    return True
            except OSError:
                continue
    return False


# Steam's binary VDF (shortcuts.vdf): maps are lists of [key, value] to keep the order Steam wrote them in.
def vdf_binary_load(data):
    position = 0

    def text():
        nonlocal position
        end = data.index(b"\0", position)
        value = data[position:end].decode("utf-8", "replace")
        position = end + 1
        return value

    def mapping():
        nonlocal position
        items = []
        while True:
            kind = data[position]
            position += 1
            if kind == 0x08:
                return items
            key = text()
            if kind == 0x00:
                items.append([key, mapping()])
            elif kind == 0x01:
                items.append([key, text()])
            elif kind == 0x02:
                items.append([key, int.from_bytes(data[position:position + 4], "little", signed=True)])
                position += 4
            elif kind in (0x03, 0x07):
                width = 4 if kind == 0x03 else 8
                items.append([key, ("raw", kind, data[position:position + width])])
                position += width
            else:
                raise ValueError(f"unknown VDF field type {kind}")

    return mapping()


def vdf_binary_dump(items):
    out = bytearray()
    for key, value in items:
        name = key.encode("utf-8") + b"\0"
        if isinstance(value, list):
            out += b"\x00" + name + vdf_binary_dump(value)
        elif isinstance(value, tuple):
            out += bytes([value[1]]) + name + value[2]
        elif isinstance(value, int):
            out += b"\x02" + name + int(value).to_bytes(4, "little", signed=True)
        else:
            out += b"\x01" + name + str(value).encode("utf-8") + b"\0"
    return bytes(out + b"\x08")


# Steam's text VDF (config.vdf).
def vdf_text_load(text):
    tokens = re.findall(r'("(?:[^"\\]|\\.)*")|([{}])|//[^\n]*', text)

    def unescape(value):
        return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), value)

    stream = iter([(unescape(q[1:-1]), "") if q else ("", b) for q, b in tokens if q or b])

    def mapping():
        items = []
        for value, brace in stream:
            if brace == "}":
                return items
            key = value
            nxt_value, nxt_brace = next(stream)
            items.append([key, mapping() if nxt_brace == "{" else nxt_value])
        return items

    return mapping()


def vdf_text_dump(items, depth=0):
    def escape(value):
        return value.replace("\\", "\\\\").replace('"', '\\"')

    out = []
    pad = "\t" * depth
    for key, value in items:
        if isinstance(value, list):
            out.append(f'{pad}"{escape(key)}"\n{pad}{{\n{vdf_text_dump(value, depth + 1)}{pad}}}\n')
        else:
            out.append(f'{pad}"{escape(key)}"\t\t"{escape(value)}"\n')
    return "".join(out)


def vdf_child(items, key, create=True):
    for pair in items:
        if pair[0].lower() == key.lower() and isinstance(pair[1], list):
            return pair[1]
    if not create:
        return None
    child = []
    items.append([key, child])
    return child


def backup(path):
    """Keeps Steam's original: the first backup is never overwritten by later runs."""
    copy = path.with_name(path.name + ".wildcard-backup")
    if path.exists() and not copy.exists():
        shutil.copy2(path, copy)


def add_to_steam():
    exe = CLIENT / "Ascension.exe"
    if not exe.exists():
        say("Install the game first (run the launcher once without options), then add it to Steam.")
        return 1
    roots = steam_roots()
    if not roots:
        say("Steam was not found in your home folder. Add the game by hand: see How to play on the website.")
        return 1
    if steam_running():
        say("Close Steam first (Steam menu, Exit), then run this again: Steam overwrites its settings when it exits.")
        return 1
    root, flatpak = roots[0]
    exe_field, start_field = f'"{exe}"', f'"{CLIENT}"'
    appid = zlib.crc32((exe_field + STEAM_NAME).encode("utf-8")) | 0x80000000
    signed = appid - (1 << 32)

    users = [user for user in (root / "userdata").iterdir() if user.is_dir() and user.name.isdigit() and user.name != "0"]
    if not users:
        say("Steam has no signed-in user yet. Start Steam, sign in, exit it, then run this again.")
        return 1
    for user in users:
        path = user / "config" / "shortcuts.vdf"
        path.parent.mkdir(parents=True, exist_ok=True)
        top = vdf_binary_load(path.read_bytes()) if path.exists() and path.stat().st_size else [["shortcuts", []]]
        shortcuts = vdf_child(top, "shortcuts")
        entry = next((item[1] for item in shortcuts if isinstance(item[1], list) and any(
            k.lower() == "appname" and v == STEAM_NAME for k, v in item[1])), None)
        fields = [["appid", signed], ["AppName", STEAM_NAME], ["Exe", exe_field], ["StartDir", start_field],
                  ["icon", ""], ["ShortcutPath", ""], ["LaunchOptions", ""], ["IsHidden", 0],
                  ["AllowDesktopConfig", 1], ["AllowOverlay", 1], ["OpenVR", 0], ["Devkit", 0],
                  ["DevkitGameID", ""], ["DevkitOverrideAppID", 0], ["LastPlayTime", 0], ["FlatpakAppID", ""],
                  ["tags", []]]
        if entry is None:
            shortcuts.append([str(len(shortcuts)), fields])
        else:
            keep = {k.lower(): v for k, v in entry}
            entry[:] = [[k, keep.get(k.lower(), v) if k in ("LastPlayTime", "tags", "icon") else v] for k, v in fields]
        backup(path)
        path.write_bytes(b"\x00shortcuts\x00" + vdf_binary_dump(shortcuts) + b"\x08")
        log(f"Steam shortcut written to {path} (appid {appid})")

    config = root / "config" / "config.vdf"
    if config.exists():
        tree = vdf_text_load(config.read_text(encoding="utf-8", errors="replace"))
        store = vdf_child(tree, "InstallConfigStore")
        steam = vdf_child(vdf_child(vdf_child(store, "Software"), "Valve"), "Steam")
        mapping = vdf_child(steam, "CompatToolMapping")
        mapping[:] = [pair for pair in mapping if pair[0] != str(appid)]
        mapping.append([str(appid), [["name", STEAM_PROTON], ["config", ""], ["priority", "250"]]])
        backup(config)
        config.write_text(vdf_text_dump(tree), encoding="utf-8")
        log(f"Proton ({STEAM_PROTON}) set for appid {appid} in {config}")
        proton_note = f"set to {STEAM_PROTON.replace('_', ' ').title()}"
    else:
        proton_note = "not set (no config.vdf yet): pick Proton in the game's Properties, Compatibility"

    gameid = (appid << 32) | 0x02000000
    prefix = "flatpak run com.valvesoftware.Steam" if flatpak else "steam"
    saved = settings()
    saved["play"] = f"{prefix} steam://rungameid/{gameid}"
    SETTINGS_FILE.write_text(json.dumps(saved, indent=2), encoding="utf-8")
    say(f"Added {STEAM_NAME} to Steam ({'Flatpak' if flatpak else 'native'}), Proton {proton_note}.")
    say(f"--play now updates the game and starts it through Steam. Backups: *.wildcard-backup next to Steam's files.")
    return 0


# ---------------------------------------------------------------- App menu and desktop shortcut
def desktop_quote(text):
    """Quote one argument for a .desktop Exec line (freedesktop spec)."""
    escaped = text.replace("\\", "\\\\").replace('"', '\\"').replace("`", "\\`").replace("$", "\\$")
    return '"' + escaped.replace("%", "%%") + '"'


def desktop_folder():
    try:
        found = subprocess.run(["xdg-user-dir", "DESKTOP"], capture_output=True, text=True, timeout=5).stdout.strip()
        if found and Path(found).is_dir() and Path(found) != Path.home():
            return Path(found)
    except (OSError, subprocess.SubprocessError):
        pass
    fallback = Path.home() / "Desktop"
    return fallback if fallback.is_dir() else None


def add_shortcut():
    me = Path(__file__).resolve()
    command = " ".join(desktop_quote(part) for part in [sys.executable, str(me), "--play", "--from-shortcut"])
    entry = "\n".join([
        "[Desktop Entry]",
        "Type=Application",
        "Name=Wildcard",
        "Comment=Update Wildcard and start it",
        f"Exec={command}",
        f"Path={HERE}",
        "Icon=applications-games",
        "Terminal=true",
        "Categories=Game;",
        "",
    ])
    menu = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share") / "applications"
    menu.mkdir(parents=True, exist_ok=True)
    places = [menu / "wildcard.desktop"]
    desktop = desktop_folder()
    if desktop:
        places.append(desktop / "wildcard.desktop")
    for place in places:
        place.write_text(entry, encoding="utf-8")
        place.chmod(0o755)
        log(f"Shortcut written: {place}")
    if desktop and shutil.which("gio"):
        # GNOME only runs desktop icons it trusts; this is what "Allow Launching" does.
        subprocess.run(["gio", "set", str(places[-1]), "metadata::trusted", "true"],
                       capture_output=True, timeout=5)
    where = "your app menu" + (" and desktop" if desktop else "")
    say(f"Added a Wildcard shortcut to {where}. It updates the game, then starts it.")
    if desktop:
        say("If the desktop icon won't open, right-click it and choose Allow Launching.")
    return 0


def main():
    parser = argparse.ArgumentParser(description="Wildcard launcher for Linux")
    parser.add_argument("--play", action="store_true", help="start the game after updating")
    parser.add_argument("--add-to-steam", action="store_true",
                        help="add the game to Steam with Proton (Steam must be closed) and make --play use it")
    parser.add_argument("--set-play", metavar="COMMAND",
                        help='remember how to start the game; {exe} becomes the path to Ascension.exe')
    parser.add_argument("--add-shortcut", action="store_true",
                        help="add a Wildcard shortcut to the app menu and desktop (update, then play)")
    parser.add_argument("--from-shortcut", action="store_true", help=argparse.SUPPRESS)
    options = parser.parse_args()

    if options.add_shortcut:
        return add_shortcut()

    if options.from_shortcut:
        # The shortcut's terminal closes when we finish: keep it open long enough to read, and on a problem until
        # the player presses Enter.
        status = run(options)
        try:
            if status:
                input("\nSomething went wrong (see above, or launcher.log). Press Enter to close.")
            else:
                time.sleep(4)
        except (EOFError, KeyboardInterrupt):
            pass
        return status
    return run(options)


def run(options):

    if options.add_to_steam:
        log(f"---- Linux launcher {LAUNCHER_VERSION}: add to Steam")
        status = add_to_steam()
        if status == 0:
            try:
                add_shortcut()
            except OSError as error:
                say(f"Could not add the app menu shortcut: {error}")
        return status

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
