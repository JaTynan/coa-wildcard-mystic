"""Friends' sign-up page for the Wildcard server: https://join.jtlab.cc (Cloudflare tunnel to this VM, port 8089).
Also serves GET /api/status, the live status and realm settings the homepage (wildcard.jtlab.cc) shows.

A friend enters an account name, a password and the invite code, and passes Cloudflare's human check (Turnstile).
The account is then created through the server manager's own one-account command (create-account-once), the same
way the manager's Create account button does it.

Limits, counted over the last 24 hours: accounts per internet address, accounts in total, and failed attempts
(wrong invite code or failed human check) per address, after which that address is turned away for the day.

Settings and secrets live in signup-settings.json next to the patch-night scripts, never in GitHub:
  turnstileSiteKey, turnstileSecret   from Cloudflare (Turnstile, add a widget for join.jtlab.cc)
  inviteCodes                         one or more codes to hand to friends
  perAddressPerDay, perDay, failuresPerAddressPerDay   optional, defaults 3, 20, 10
Run by the "Wildcard Sign-up" scheduled task (Register-WildcardSignup.cmd); standard library only.
"""

import argparse
import hmac
import html
import json
import re
import subprocess
import sys
import threading
import time
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

# The manager's Python may be the embeddable kind, which does not add the script's folder to the import path.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import WildcardStatus  # noqa: E402

DAY = 24 * 60 * 60
NAME = re.compile(r"[A-Za-z0-9]{3,16}")
PASSWORD = re.compile(r"[A-Za-z0-9]{6,16}")
VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"

here = Path(__file__).resolve().parent
patch_night = here.parent
settings_file = patch_night / "signup-settings.json"
state_file = patch_night / "signup-state.json"
log_file = patch_night / "signup.log"
lock = threading.Lock()


def log(message):
    line = time.strftime("%Y-%m-%d %H:%M:%S ") + message
    with open(log_file, "a", encoding="utf-8") as handle:
        handle.write(line + "\n")


def settings():
    try:
        data = json.loads(settings_file.read_text(encoding="utf-8-sig"))
    except (OSError, ValueError):
        return None
    codes = [str(code).strip() for code in data.get("inviteCodes", []) if str(code).strip()]
    if not data.get("turnstileSiteKey") or not data.get("turnstileSecret") or not codes:
        return None
    if any(code.upper().startswith("CHANGE") for code in codes):
        return None
    data["inviteCodes"] = codes
    return data


def load_state():
    try:
        state = json.loads(state_file.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        state = {}
    cutoff = time.time() - DAY
    return {key: [entry for entry in state.get(key, []) if entry.get("t", 0) > cutoff]
            for key in ("created", "failed")}


def save_state(state):
    temporary = state_file.with_suffix(".tmp")
    temporary.write_text(json.dumps(state), encoding="utf-8")
    temporary.replace(state_file)


def count(entries, address=None):
    return sum(1 for entry in entries if address is None or entry.get("ip") == address)


def human(secret, token, address):
    if not token:
        return False
    body = urllib.parse.urlencode({"secret": secret, "response": token, "remoteip": address}).encode()
    try:
        with urllib.request.urlopen(VERIFY_URL, body, timeout=10) as reply:
            return bool(json.load(reply).get("success"))
    except (OSError, ValueError) as error:
        log(f"Turnstile check failed to run: {error}")
        return False


def create_account(options, name, password):
    """Returns (created, message) from the manager's create-account-once."""
    command = [options.python, "-B", str(options.bridge), str(options.manage), "create-account-once"]
    request = json.dumps({"username": name, "password": password}) + "\n"
    try:
        result = subprocess.run(command, input=request, capture_output=True, text=True, timeout=60,
                                cwd=str(options.server), creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    except (OSError, subprocess.TimeoutExpired) as error:
        log(f"create-account-once did not run: {error}")
        return False, "The server did not answer. Try again in a few minutes."
    output = (result.stdout or "").strip()
    try:
        messages = json.loads(output.splitlines()[-1])["messages"]
    except (ValueError, KeyError, IndexError):
        messages = []
    text = " ".join(str(message) for message in messages)
    if result.returncode or not messages:
        detail = (result.stderr or output).strip().splitlines()
        log(f"create-account-once failed for {name}: {detail[-1] if detail else result.returncode}")
        if "Start this repack" in (result.stderr or ""):
            return False, "The server is restarting. Try again in a few minutes."
        return False, "Something went wrong creating the account. Ask James."
    if "created" in text.lower():
        return True, "Account created."
    if "exist" in text.lower():
        return False, "That account name is taken. Pick another."
    log(f"create-account-once for {name} answered: {text}")
    return False, "The server said: " + text


def join(options, form, address):
    config = settings()
    if not config:
        return 503, "Sign-up is not open yet. Ask James."
    name = str(form.get("name", "")).strip()
    password = str(form.get("password", ""))
    invite = str(form.get("invite", "")).strip()
    token = str(form.get("token", ""))
    if not NAME.fullmatch(name):
        return 400, "The account name must be 3 to 16 letters or digits."
    if not PASSWORD.fullmatch(password):
        return 400, "The password must be 6 to 16 letters or digits (the game allows no other characters)."
    if password.lower() == name.lower():
        return 400, "The password must not be the account name."

    per_address = int(config.get("perAddressPerDay", 3))
    per_day = int(config.get("perDay", 20))
    failures = int(config.get("failuresPerAddressPerDay", 10))
    with lock:
        state = load_state()
        if count(state["failed"], address) >= failures:
            return 429, "Too many failed attempts from your connection today. Try again tomorrow or ask James."
        if count(state["created"], address) >= per_address or count(state["created"]) >= per_day:
            return 429, "The account limit for today has been reached. Try again tomorrow or ask James."

        def fail(status, message):
            state["failed"].append({"ip": address, "t": time.time()})
            save_state(state)
            log(f"Refused {name} from {address}: {message}")
            return status, message

        if not human(config["turnstileSecret"], token, address):
            return fail(403, "The human check did not pass. Tick it again and retry.")
        if not any(hmac.compare_digest(invite.upper().encode(), code.upper().encode()) for code in config["inviteCodes"]):
            return fail(403, "That invite code is not right.")
        created, message = create_account(options, name, password)
        if created:
            state["created"].append({"ip": address, "t": time.time()})
            save_state(state)
            log(f"Created account {name.upper()} for {address}")
            return 200, f"Account {name.upper()} created. Log in with it in the game."
        return 409 if "taken" in message else 502, message


PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Wildcard sign-up</title>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<link rel="stylesheet" href="/style.css">
<style>
  /* Sign-up page only */
  #join { max-width: 560px; }
  #result { min-height: 1.5em; margin: 16px 0 0; }
</style>
</head>
<body>
<main>
  <nav class="top"><a href="https://wildcard.jtlab.cc/">Home</a><a href="https://wildcard.jtlab.cc/how-to-play.html">How to play</a><a href="/" aria-current="page">Create an account</a></nav>
  <h1>Create an account</h1>
  <p class="tag">Make your game account. You need the invite code James gave you.</p>
  <form id="join" class="panel" autocomplete="off">
    <label for="name">Account name</label>
    <p class="hint">3 to 16 letters or digits. This is what you log in with, not your character's name.</p>
    <input id="name" name="name" maxlength="16" pattern="[A-Za-z0-9]{3,16}" required>
    <label for="password">Password</label>
    <p class="hint">6 to 16 letters or digits; the game allows no other characters.</p>
    <input id="password" name="password" type="password" maxlength="16" pattern="[A-Za-z0-9]{6,16}" required>
    <label for="again">Password again</label>
    <input id="again" type="password" maxlength="16" required>
    <label for="invite">Invite code</label>
    <input id="invite" name="invite" required>
    <div class="cf-turnstile" data-sitekey="__SITEKEY__" data-theme="dark"></div>
    <button id="submit" class="button" type="submit" style="margin-top:16px">Create account</button>
    <p id="result" role="status"></p>
  </form>
  <p class="note" style="margin-top:20px">Then get the game, and see the server's status and rates, on the
    <a href="https://wildcard.jtlab.cc/">home page</a>. New to Wildcard? Read <a href="https://wildcard.jtlab.cc/how-to-play.html">How to play</a>.</p>
</main>
<script>
const form = document.getElementById("join"), result = document.getElementById("result"), submit = document.getElementById("submit");
function show(text, good) { result.textContent = text; result.className = good ? "good" : "bad"; }
form.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (form.password.value !== document.getElementById("again").value) { show("The two passwords are different."); return; }
  const token = (form.querySelector("[name=cf-turnstile-response]") || {}).value || "";
  if (!token) { show("Tick the human check first."); return; }
  submit.disabled = true; show("Creating your account...", true);
  try {
    const reply = await fetch("/api/join", { method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: form.name.value, password: form.password.value, invite: form.invite.value, token }) });
    const data = await reply.json();
    show(data.message, reply.ok);
    if (reply.ok) { form.reset(); }
  } catch (error) { show("Could not reach the server. Try again in a minute."); }
  submit.disabled = false;
  if (window.turnstile) { turnstile.reset(); }
});
</script>
</body>
</html>
"""


def handler_for(options):
    class Handler(BaseHTTPRequestHandler):
        server_version = "WildcardSignup"
        sys_version = ""

        def address(self):
            return self.headers.get("CF-Connecting-IP") or self.client_address[0]

        def send(self, status, body, kind, public=False):
            data = body.encode("utf-8")
            self.send_response(status)
            if public:
                self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Content-Type", kind)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "no-referrer")
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            if self.path.split("?")[0] == "/api/status":
                try:
                    body = json.dumps(WildcardStatus.status(options))
                    self.send(200, body, "application/json", public=True)
                except Exception as error:  # the homepage shows "status unavailable"; the log says why
                    log(f"Status failed: {error!r}")
                    self.send(500, json.dumps({"message": "Status unavailable"}), "application/json", public=True)
                return
            if self.path.split("?")[0] == "/style.css":
                # The site's shared stylesheet, from the launcher folder patch night keeps next to these scripts.
                try:
                    css = (patch_night / "launcher" / "site" / "style.css").read_text(encoding="utf-8-sig")
                    self.send(200, css, "text/css; charset=utf-8")
                except OSError:
                    self.send_response(302)
                    self.send_header("Location", "https://wildcard.jtlab.cc/style.css")
                    self.end_headers()
                return
            if self.path.split("?")[0] not in ("/", "/index.html"):
                self.send(404, "Not found", "text/plain; charset=utf-8")
                return
            config = settings()
            if not config:
                self.send(503, "<p style='font-family:sans-serif'>Sign-up is not open yet. Ask James.</p>",
                          "text/html; charset=utf-8")
                return
            self.send(200, PAGE.replace("__SITEKEY__", html.escape(config["turnstileSiteKey"], quote=True)),
                      "text/html; charset=utf-8")

        def do_POST(self):
            if self.path != "/api/join":
                self.send(404, json.dumps({"message": "Not found"}), "application/json")
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
                form = json.loads(self.rfile.read(min(length, 4096)) or b"{}") if 0 < length <= 4096 else {}
                if not isinstance(form, dict):
                    form = {}
            except ValueError:
                form = {}
            status, message = join(options, form, self.address())
            self.send(status, json.dumps({"message": message}), "application/json")

        def log_message(self, format, *args):
            pass

    return Handler


def main():
    parser = argparse.ArgumentParser(description="Wildcard sign-up page")
    parser.add_argument("--server", default=r"C:\Games\CoA Server")
    parser.add_argument("--port", type=int, default=8089)
    options = parser.parse_args()
    options.server = Path(options.server)
    options.python = str(options.server / "Runtime" / "python" / "python.exe")
    options.manage = options.server / "Scripts" / "manage.py"
    options.bridge = patch_night / "launcher_bridge.py"
    log(f"Sign-up page listening on port {options.port}" + ("" if settings() else " (not open: fill in signup-settings.json)"))
    ThreadingHTTPServer(("0.0.0.0", options.port), handler_for(options)).serve_forever()


if __name__ == "__main__":
    main()
