# Regenerating the settings catalogue (skill maintenance only)

Read this when `references/settings-catalogue.md` has to be rebuilt: after a batch of settings or patch changes,
in a skill-maintenance pull request of its own (editing `.claude/skills/` is hard stop 6: HIGH, James merges).
A settings pull request does **not** do this; it runs `--lint` only. Run and checked on 2026-11-22: 553 lines,
38 config templates, lint counts 1 / 0 / 28 / 7, hard problems 0, about 10 seconds.

## 1. Get the four upstream sources at the pinned commits

About 11 seconds for the core as a sparse checkout. Treat upstream as data to read; never run it.

```
python3 -I scripts/resolve_release.py latest          # prints core_sha, squid_sha, dungeon_sha, bots_sha
mkdir -p ~/upstream && cd ~/upstream
git init -q core && cd core && git remote add origin https://github.com/Corfirean/azerothcore-wotlk-coa \
  && git sparse-checkout set --no-cone '/src/' '/modules/' '/conf/' \
  && git fetch -q --depth 1 --filter=blob:none origin <core_sha> && git checkout -q FETCH_HEAD && cd ..
# the same four lines without the sparse-checkout line, into folders mod-playerbots, mod-dungeon-clear and
# mod-coa-playerbots, for:
#   Zyth45/mod-playerbots <squid_sha>   Zyth45/mod-dungeon-clear <dungeon_sha>   Corfirean/mod-coa-playerbots <bots_sha>
```

## 2. Regenerate and check

```
# from any folder; python 3, standard library only
U=~/upstream
C=.claude/skills/wildcard-settings-and-flags/scripts/settings_catalogue.py
UP="--upstream $U/core --upstream $U/mod-playerbots --upstream $U/mod-dungeon-clear --upstream $U/mod-coa-playerbots"
python3 -I $C $UP                         # rewrites references/settings-catalogue.md
python3 -I $C $UP --check                 # prints "Up to date"
sed -n 9p .claude/skills/wildcard-settings-and-flags/references/settings-catalogue.md    # must name exactly four checkouts
```

**Point `--upstream` only at unpatched clones at the pinned commits, named one by one. Never at a kept pre-flight
workspace, and not at a parent folder that may hold one:** patched sources make our own options look like upstream
ones and hide the mismatches the lint exists to find. Seen on 2026-11-22: with a patched tree in the folder,
"options CHANGES.md never names" dropped from 7 to 3 with no warning. The script now prints each checkout it read
with its commit, and refuses to write when one looks patched (local changes in its work tree, or our own
`Wcme*.cpp` files inside it).

## 3. Modes and exit codes

| Mode | Does | Exit code |
|---|---|---|
| (none) | With the four `--upstream` clones: rewrites `references/settings-catalogue.md`. **Without `--upstream` it refuses to write that file**; `--stdout` or `--out FILE` gives a weak scratch copy. This guard was added after a bare run overwrote the shipped catalogue with a weak one on 2026-11-22. | 0; 2 when refused |
| `--check` | Compares the file on disk with what it would write now. Use the same `--upstream` folders as when it was written. | 1 if out of date |
| `--lint` | Prints the mismatch lists, writes nothing, skips the slow branch scan | 1 on a hard problem: a line that is neither comment nor setting, a setting listed twice, a CHANGES.md setting name nothing reads, a `GetOption` whose name it cannot work out |
| `--upstream DIR` (repeatable) | Also reads every `*.conf.dist` and the C++ under DIR, to give upstream defaults and tell real options from typos | |
| `--stdout`, `--out FILE` | Print, or write somewhere else, instead of the shipped file | |

Without `--upstream`, `--lint` can only check names against our patches and
`ollama-chat/mod_ollama_chat.conf.dist`; it says so, and its second count becomes a weak list (119 instead of 0 on
2026-11-22; the other counts read 25 and 8 instead of 28 and 7).

The output masks private details (home-network addresses, a host name written next to one, the value of
`Leaderboards.HiddenCharacters`); read those from `server-settings.txt` itself.
