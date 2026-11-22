# The `*.patch` files: what they are and how to regenerate one

Read this when one of the five `patches/*.patch` files has to change (most often
`mystic-enchants-scripts.patch`, when an enchant script is added or edited), or when the pre-flight says a
patch's `@@` count is stale. Checked on 2026-11-22.

Five ordinary `git diff` files against the core (`references/patch-catalogue.md` lists them). No two touch the
same file. `mystic-enchants-scripts.patch` (671 KB) is a single new file, `src/server/coa/WcmeEnchantScripts.cpp`;
the repository keeps that file only as this patch. `64-enchant-scripts-loader.ps1` then registers
`AddSC_WcmeEnchantScripts()`, and each script in it is bound to its spell by SQL (`017-enchant-scripts.sql`
onward).

Regenerate, do not hand-edit (round trip verified on 2026-11-22: byte-identical for the scripts patch, and only
`@@` line numbers differ for the other four):

```bash
python3 -I .claude/skills/wildcard-patch-authoring/scripts/preflight.py latest --no-scripts --keep --workspace /tmp/wcp
cd /tmp/wcp/core                       # the core with only the five *.patch files applied
$EDITOR src/server/coa/WcmeEnchantScripts.cpp
git add -N src/server/coa/WcmeEnchantScripts.cpp      # a new file is invisible to git diff until this
git diff -- src/server/coa/WcmeEnchantScripts.cpp > <repo>/patches/mystic-enchants-scripts.patch
```

For another patch, list exactly its own files after `--` (`grep '^diff --git' patches/<name>.patch`), with
`git add -N` for any new file. Then run the full pre-flight.

Why not by hand: the header `@@ -0,0 +1,14552 @@` states the line count. Add a line and leave the count, and
`git apply --check` and `git apply` both succeed and silently drop the file's last line (tested on 2026-11-22,
git 2.43). The pre-flight fails such a patch ("its @@ count is stale"); the build would not have until the
compiler reached the end of the file.
