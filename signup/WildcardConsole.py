"""The sign-up service's console window as a status board for troubleshooting (22 Nov).

The "Wildcard Sign-up" task runs the sign-up page in a console window that used to stay blank. It now starts
minimised and, every 30 seconds, shows what helps when something is wrong: whether the world, login and database
servers answer on their ports, players and uptime, the installed build, the realm addresses players connect to,
this machine's addresses, the last patch night and the settings check, and the newest sign-up log lines.

Clicking into a console window starts a text selection that pauses whatever writes to it ("Select" in the title);
that selection mode is switched off for this window. Standard library only.
"""

import ctypes
import json
import os
import socket
import sys
import time
from pathlib import Path

import WildcardStatus

REFRESH_SECONDS = 30


def prepare_window():
    """Minimise this console, switch off click-to-select, allow colours, and name it. Windows only; else nothing."""
    if sys.platform != "win32":
        return
    try:
        kernel = ctypes.windll.kernel32
        window = kernel.GetConsoleWindow()
        if not window:
            return
        kernel.SetConsoleTitleW("Wildcard server status (sign-up service - closing this stops join.jtlab.cc)")
        ctypes.windll.user32.ShowWindow(window, 6)  # SW_MINIMIZE
        mode = ctypes.c_uint32()
        stdin = kernel.GetStdHandle(-10)
        if kernel.GetConsoleMode(stdin, ctypes.byref(mode)):
            # ENABLE_EXTENDED_FLAGS on, ENABLE_QUICK_EDIT_MODE off
            kernel.SetConsoleMode(stdin, (mode.value | 0x0080) & ~0x0040)
        stdout = kernel.GetStdHandle(-11)
        if kernel.GetConsoleMode(stdout, ctypes.byref(mode)):
            kernel.SetConsoleMode(stdout, mode.value | 0x0004)  # ENABLE_VIRTUAL_TERMINAL_PROCESSING
    except Exception:
        pass


def _ports(server):
    try:
        return json.loads((server / "Settings" / "repack.json").read_text(encoding="utf-8-sig"))
    except (OSError, ValueError):
        return {}


def _addresses():
    names = set()
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            if not info[4][0].startswith("127."):
                names.add(info[4][0])
    except OSError:
        pass
    return ", ".join(sorted(names)) or "unknown"


def _core(server):
    """The core revision of this start, from the first line of Server.log."""
    try:
        with open(server / "Core" / "Logs" / "Server.log", encoding="utf-8", errors="replace") as handle:
            first = handle.readline()
    except OSError:
        return None
    parts = first.split()
    return parts[2].rstrip("+") if len(parts) > 2 and first.startswith("AzerothCore rev.") else None


def _realms(server):
    rows = WildcardStatus._sql(server, "SELECT id, name, address, localAddress, port, flag FROM acore_auth.realmlist ORDER BY id;")
    return rows or []


def _tail(path, count):
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return []
    return lines[-count:]


def _first_line(path):
    try:
        return path.read_text(encoding="utf-8-sig", errors="replace").strip().splitlines()[0]
    except (OSError, IndexError):
        return None


def board(options, signup_port, open_for_signups):
    server = Path(options.server)
    patch_night = Path(options.bridge).parent
    ports = _ports(server)
    world_port = int(ports.get("worldPort", 8085))
    auth_port = int(ports.get("authPort", 3724))
    mysql_port = int(ports.get("mysqlPort", 3306))
    world = WildcardStatus._answers(world_port)
    login = WildcardStatus._answers(auth_port)
    database = WildcardStatus._answers(mysql_port)
    console = WildcardStatus._console_info(options) if world else {}
    build = WildcardStatus._build(server / "Core")

    def state(up):
        return "\x1b[32mup\x1b[0m  " if up else "\x1b[31mDOWN\x1b[0m"

    lines = [f"\x1b[1mWildcard server status\x1b[0m   {time.strftime('%a %d %b %H:%M:%S')}   (refreshes every {REFRESH_SECONDS} s)", ""]
    detail = ""
    if world:
        bits = []
        if console.get("players") is not None:
            bits.append(f"players {console['players']}")
        if console.get("characters") is not None:
            bits.append(f"in world {console['characters']} (bots included)")
        if console.get("uptime"):
            bits.append(f"up {console['uptime']}")
        detail = ", ".join(bits) or "console not answering yet"
    lines += [
        "Servers",
        f"  World server   {state(world)}  port {world_port:<5}  {detail}",
        f"  Login server   {state(login)}  port {auth_port}",
        f"  Database       {state(database)}  port {mysql_port}",
        f"  Sign-up page   {state(True)}  port {signup_port:<5}  {'open' if open_for_signups else 'NOT OPEN: fill in signup-settings.json'}",
        "",
        "Version",
        f"  Patched build  {build.get('tag') or 'none recorded (official server?)'}",
        f"  Running core   {_core(server) or 'unknown (no Server.log yet)'}",
        "",
        "Addresses",
        f"  This machine   {_addresses()}",
    ]
    for row in _realms(server) if database else []:
        if len(row) >= 6:
            offline = row[5].isdigit() and int(row[5]) & 2  # REALM_FLAG_OFFLINE: the login server lists it as offline
            lines.append(f"  Realm {row[0]:<3}     {row[1]}: {row[2]}:{row[4]} (local {row[3]})" + ("  \x1b[31mmarked offline\x1b[0m" if offline else ""))
    report = patch_night.parent / "server-settings" / "settings-report.txt"
    checked = [line.strip() for line in _tail(report, 400) if line.startswith(("Known to the server", "Unknown,", "Values it could not use", "Settings it uses"))]
    lines += ["", "Patch night", f"  Last run       {_first_line(patch_night / 'last-run.txt') or 'never'}"]
    downtime = [line.split("] ", 1)[-1] for line in _tail(patch_night / "patch-night.log", 300) if "Downtime:" in line]
    if downtime:
        lines.append(f"  Last downtime  {downtime[-1].replace('Downtime: ', '')}")
    lines += [f"  Settings       {line}" for line in checked[:4]]
    lines += ["", "Sign-up log (newest)"] + [f"  {line[:150]}" for line in _tail(patch_night / "signup.log", 6)]
    return lines


def run(options, signup_port, is_open):
    """Redraws the board until the service stops. Never raises: the sign-up page must keep running."""
    prepare_window()
    while True:
        try:
            text = "\n".join(board(options, signup_port, is_open()))
            sys.stdout.write("\x1b[2J\x1b[H" + text + "\n")
            sys.stdout.flush()
        except Exception as error:  # a status board must never take the sign-up page down
            try:
                sys.stdout.write(f"\nStatus board error: {error!r}\n")
                sys.stdout.flush()
            except Exception:
                pass
        time.sleep(REFRESH_SECONDS)
