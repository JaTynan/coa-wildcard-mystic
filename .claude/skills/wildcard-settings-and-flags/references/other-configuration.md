# Configuration that is not in server-settings.txt

Read this when a value you are looking for is not a line of `server-settings/server-settings.txt`: it says where
that kind of configuration lives and which skill owns it. As of 2026-11-22.

| Where | What | Owner skill |
|---|---|---|
| `launcher/launcher-settings.json` | Friends' launcher: site address, realm address (`wow.jtlab.cc`), client archive size (the address is in `launcher-local.json` on the VM since PR #242), files to remove | wildcard-client-and-web |
| `signup-settings.json` (VM only, next to the patch-night scripts, never in GitHub) | **Secrets**: Turnstile keys, invite codes, GitHub token for the bug-report relay; also sign-up limits. Hard stop 4. | wildcard-client-and-web |
| `ollama-chat/mod_ollama_chat.conf.dist` | Template of the AI chat module's config, copied to the VM at every start; its values are overridden by the `OllamaChat.*` lines of the settings file | this skill for the values; azerothcore-coa-reference for the module |
| `sql/enchants/090-mysql-tuning.sql`, `095-slow-query-log.sql` | MySQL server settings (buffer pool, slow query log), applied as SQL at every start | wildcard-run-and-operate, wildcard-diagnostics-and-tooling |
| `patch-night/Register-PatchNight.ps1` parameters | Day, times and countdown of the scheduled tasks | wildcard-run-and-operate |
| `vm/Install-WildcardServer.ps1` | Sets `CoA.MysticEnchants.AllowWildcard = 1` in `coa.conf` itself when it installs a build (lines 88-103); the settings file has the same line and "the last word" | wildcard-run-and-operate |
| `signup/WildcardStatus.py` | Reads the live config files to show rates and events on the website, and reads `Leaderboards.HiddenCharacters`, which no server code reads | wildcard-client-and-web |
| The build's pinned commits | `scripts/resolve_release.py`, the workflow | wildcard-build-and-env |
