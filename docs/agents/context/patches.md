# Context pack: server patches

Read this instead of exploring.

## How a patch works
- `patches/NN-name.ps1` scripts (and a few `*.patch` files) are applied in name order at build time, on a clean copy
  of CoA's code for one release, by the workflow step "Apply our patch scripts". They are never applied twice.
- A script edits source with `Edit-Core $file $anchor $replacement $what`: the anchor text must be found **exactly
  once** or the build stops with "SQUID changed" / "CoA changed". That failure is intended: it is how a core update
  that moved the code announces itself.
- New files (headers) are written whole with `Set-Content`. Line endings are normalised to LF.
- Every patch has a row in `CHANGES.md`, and any setting it reads is listed in `server-settings/server-settings.txt`
  with a comment saying which build it needs.
- Sources patched: the CoA core (AzerothCore 3.3.5 based), SQUID's `mod-playerbots`, `mod-dungeon-clear`,
  `mod-ollama-chat`. Settings are read with `sConfigMgr->GetOption<T>("Name", default)`.

## What goes wrong most often
1. **Anchor too loose or too tight:** matches twice after a core update, or includes text an update is likely to
   touch. Good anchors are short, unique and structural.
2. **Order:** a later script's anchor depends on text an earlier script inserted or removed.
3. **A setting read on a hot path** (every tick, every packet) without caching.
4. **Bots:** code written for players runs for 750 bots too. Check `IsPlayerBot`-style guards, master/alt handling,
   and anything that whispers, mails or grants rewards.
5. **Wildcard Heroes are class 10**, not one of the CoA classes 12-32: class tables and spec lookups often have no
   row for them (the shield and stance bug of 22 Nov).
6. **Null and lifetime:** `GetMap()`, `GetGroup()`, `GetSession()`, pets and targets can be null or gone a tick later;
   pointers kept across a teleport or a logout.
7. **Database:** a query per call instead of prepared and batched; a table the auction bot or the world also writes.
8. **Client/server split:** the client has its own copy of some rules (enchants, tooltips); a server-only change can
   leave the two disagreeing.

## Rules for anything in this repository
- Public repository: no secrets, no Ascension client data (MPQ, DBC, BLP), no verbatim client tooltip text, no
  third-party addon code (pinned downloads only).
- `for-083` and `main` are never merged into each other.
- James merges PRs. Builds take 2 to 3 hours; a failed anchor costs a whole build, so test the script against the
  pinned sources before pushing.
