# Copied from CF-Server-Manager (Corfirean/coa-server-manager),
# crates/coa-core/src/launcher_bridge.py, licensed under the GNU AGPL v3.0.
# The manager runs Scripts\manage.py through this bridge; patch night runs it the same way. One Wildcard
# addition, marked below: a start keeps worldserver.conf on the active realm's databases.
# Usage: python -B launcher_bridge.py <path to Scripts\manage.py> <verb>

import json
import re
import runpy
import sys
import time
from pathlib import Path

script = sys.argv[1]
sys.path.insert(0, str(Path(script).resolve().parent))
sys.argv = sys.argv[1:]
launcher = runpy.run_path(script, run_name="coa_manager_launcher")
original_wait = launcher["wait_ready"]
world_deadline = None


def wait_ready(name, port, seconds=180):
    global world_deadline
    if name == "mysql":
        seconds = max(seconds, 300)
    elif name == "world":
        # Both game and console listeners belong to one startup, including on old repacks.
        # Ordinary CoA worlds can load slowly too; this must not depend on SQUID.
        if world_deadline is None:
            world_deadline = time.monotonic() + max(seconds, 1500)
        seconds = max(0, world_deadline - time.monotonic())
    return original_wait(name, port, seconds)


launcher["start_mysql"].__globals__["wait_ready"] = wait_ready

# Wildcard addition (not in the manager's bridge): from server 0.261119.114, Scripts\manage.py writes the default
# acore_world and acore_characters into worldserver.conf whatever realm is active; the manager app puts the active
# realm's databases back itself, so patch night must too, or a start from here opens the wrong realm's characters.
REALM_DATABASES = {"wildcard": ("acore_world_wildcard", "acore_characters_wildcard")}
server_root = Path(script).resolve().parents[1]


def point_at_active_realm():
    try:
        active = json.loads((server_root / "Settings" / "realm-profile.json").read_text(encoding="utf-8")).get("active")
    except (OSError, ValueError, AttributeError):
        return
    names = REALM_DATABASES.get(active)
    # Only when the realm's databases exist (a fresh install has none until the manager creates them).
    if not names or not all((server_root / "mysql" / "data" / name).is_dir() for name in names):
        return
    conf = server_root / "Core" / "configs" / "worldserver.conf"
    if not conf.exists():
        return
    text = conf.read_text(encoding="utf-8")
    fixed = text
    for key, name in zip(("WorldDatabaseInfo", "CharacterDatabaseInfo"), names):
        fixed = re.sub(r'(?m)^(\s*' + key + r'\s*=\s*"[^"\n]*;)[A-Za-z0-9_]+(")',
                       lambda match: match.group(1) + name + match.group(2), fixed)
    if fixed != text:
        conf.write_text(fixed, encoding="utf-8", newline="\n")
        print("Pointed worldserver.conf at the " + active + " realm's databases: " + ", ".join(names) + ".")


prepare_globals = launcher["main"].__globals__
if "prepare" in prepare_globals:
    original_prepare = prepare_globals["prepare"]

    def prepare(config):
        original_prepare(config)
        point_at_active_realm()

    prepare_globals["prepare"] = prepare
if sys.argv[1] == "stop-all":
    shutdown = launcher["stop_all"].__globals__
    if "ra" in shutdown:
        original_ra = shutdown["ra"]

        class UnsafeShutdown(Exception):
            pass

        def shutdown_command(command, config):
            try:
                return original_ra(command, config)
            except (OSError, RuntimeError):
                if not command.startswith("server shutdown "):
                    raise
                world = shutdown["process"]("world")
                if not world:
                    return "Worldserver has already stopped."
                expected = Path(script).resolve().parents[1] / "Core" / "worldserver.exe"
                if Path(world.get("exe", "")) != expected or not shutdown["same_process"](world):
                    raise UnsafeShutdown("World process ownership could not be verified; the database was left running.")
                try:
                    shutdown["terminate"](world)
                except (OSError, RuntimeError) as error:
                    raise UnsafeShutdown("Worldserver could not be stopped safely; its database was left running.") from error
                if not shutdown["wait_stopped"](world, 90):
                    raise UnsafeShutdown("Worldserver is still stopping; its database was left running.")
                return "Stopped this server's recorded world process without its unavailable console."

        shutdown["ra"] = shutdown_command
    config = launcher["settings"]()
    with launcher["control_lock"]():
        launcher["stop_all"](config)
else:
    launcher["main"]()
