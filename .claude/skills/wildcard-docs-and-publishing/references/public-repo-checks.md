# Public-repository checks

The repository `JaTynan/coa-wildcard-mystic` is public. This page has the pre-push checklist, the checks as commands,
and what they found on 2026-11-22.

## Pre-push checklist

Run from the repository root, on your branch, before `git push`.

- [ ] `python3 -I .claude/skills/wildcard-docs-and-publishing/scripts/public_repo_check.py` ends with "no FAIL".
      New files must be known to git first (`git add -N <file>`), or the script does not see them.
- [ ] I read the whole diff (`git diff origin/main...HEAD`), not only the summary.
- [ ] No secret, key, token, invite code or password, and no log or config excerpt containing one.
- [ ] No game client file (MPQ, DBC, BLP, models, maps) and no file exported from one
      (the output of `enchants/export_spell_data.py`, `patch-ZZW.MPQ`, extracted Spell.dbc).
- [ ] No tooltip or spell description copied word for word, in docs, SQL comments, CSV notes, commit messages or the
      PR text. Described in my own words instead.
- [ ] No third-party addon code. A new addon is one pinned line in `addon/third-party-addons.txt`, with a comment:
      date, who asked, what was checked.
- [ ] Any file copied from another project keeps its licence note and says where it came from (repository, path,
      commit) and what was changed.
- [ ] No player, account or character names, IP addresses or e-mail addresses.
- [ ] The doc that goes with the change is in the same PR (SKILL.md section 1).
- [ ] Generated files were regenerated, not hand-edited (SKILL.md section 2).
- [ ] The PR title reads well as a line for players, or the description has a `Changelog:` line (SKILL.md section 4).
- [ ] Commit messages follow the house shape and end with the attribution lines the session was given.
- [ ] The change was classified with `wildcard-change-control`. James merges.

## The same checks as one-line commands

All read-only. Each prints nothing when clean, unless noted. Run from the repository root. Tested on 2026-11-22.

```bash
# 1. Game client data or build outputs tracked by git
git ls-files | grep -i -E '\.(mpq|dbc|db2|blp|m2|wmo|adt|wdt|wdl|skin|anim|exe|dll|pdb|dmp|zip|7z|tar|pyc)$'

# 2. Files .gitignore lists that git still tracks
git ls-files -ci --exclude-standard

# 3. Secret files by name
git ls-files | grep -E '(^|/)(signup-settings\.json|signup-state\.json|launcher-secret\.json|\.env)$'

# 4. Strings shaped like real keys (GitHub, private keys, Cloudflare Turnstile, AWS, Slack)
git grep -n -I -E 'github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY|0x4AAAAAA[A-Za-z0-9_-]{10,}|AKIA[0-9A-Z]{16}|xox[bap]-[A-Za-z0-9-]{10,}'

# 5. Addon folders that are not ours
git ls-files addon | cut -d/ -f2 | sort -u | grep -v -E '^(Wildcard|third-party-addons\.txt$)'

# 6. Third-party addon lines without a full 40-character commit
grep -v -E '^\s*(#|$)' addon/third-party-addons.txt | grep -v -E '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+ \| [0-9a-f]{40} \| '

# 7. Spell text carrying the client's format codes ($s1, $d, $12345s2), outside the spells we wrote ourselves
git grep -n -I -E "'[^']{25,}[$][0-9]*[sdtmoax][1-3]?\b" -- . ':!sql/enchants/150-custom-spells.sql' ':!client-patch' | cut -c1-80

# 8. Share links or URLs carrying a token
git grep -n -I -E 'https?://[^ "]*(/share/|[?&](token|key|sig)=)' | cut -c1-120

# 9. Files over 1 MB (prints size and name)
git ls-files -z | xargs -0 ls -l | awk '$5 > 1000000 {print $5, $9}'

# 10. What this branch adds, by file (prints a list; look for anything you did not mean to add)
git diff --stat origin/main...HEAD
```

Check 7 is a hint, not proof either way. On 2026-11-22 it also printed three lines under `enchants/epic-*` for spell
997188: those are our own notes mentioning a formula, a false alarm. Text we wrote for our own spells uses the same codes on purpose
(`client-patch/custom_spells.py`, `sql/enchants/150-custom-spells.sql`), and a copied sentence without codes is not
caught. Nothing replaces reading the diff.

## What the checks found on 2026-11-22 (at `fcfee51`)

Observations for James to weigh. None is an accusation, and none was changed: the rest of the repository was
read-only for this work.

| # | Observation | Where | Why it may matter | Possible action (James decides) |
|---|---|---|---|---|
| 1 | Three compiled Python cache files are tracked although `.gitignore` lists `__pycache__/` | `launcher/__pycache__/WildcardLauncher.cpython-313.pyc`, `signup/__pycache__/WildcardSignup.cpython-313.pyc`, `signup/__pycache__/WildcardStatus.cpython-313.pyc` | Harmless clutter: compiled copies of scripts already in the repository. `.gitignore` only stops new files; these were added in commits of 7 and 8 Nov 2026 | `git rm --cached` the three files in a small PR with `Changelog: skip` |
| 2 | Spell description text with the client's format codes sits in a few `spell_dbc` rows | `sql/enchants/012-placeholder-modifiers.sql` line 13; `sql/enchants/013-action-fixes.sql` lines 11, 12 and 25 | These rows may carry description text taken from the client's spell data (file 012's header says the copied spell's "name and tooltip stay as they are"). Whether that text is the client's own or was written for the fix was not established. The stated rule is no verbatim client tooltip text | Check the four rows; if the text is the client's, blank the description fields (the client shows its own copy) or reword them |
| 3 | A public, never-expiring share link to the full client archive | a share link in `launcher/launcher-settings.json` | The repository holds no client files, but it publishes a link to them. `launcher/README.md` already notes the site is not behind a login and describes an optional access token | Known and documented; James's decision. Do not add more such links |
| 4 | No licence file for the repository itself | repository root | Parts are copies under AGPL-3.0 (`patch-night/launcher_bridge.py`, `ollama-chat/`), and new C++ files in the patches carry AzerothCore's AGPL header. Without a licence file, outsiders are not told what they may do with the rest | James's decision; not legal advice |
| 5 | The source path named in the bridge's header is no longer in the manager's repository | `patch-night/launcher_bridge.py` line 2 names `crates/coa-core/src/launcher_bridge.py`; no file of that name exists at `Corfirean/coa-server-manager` commit `10cfdcf` (its default branch on 2026-11-22) | The provenance note cannot be followed today because it names no commit. The copy dates from 30 Oct 2026 (`git log --diff-filter=A -- patch-night/launcher_bridge.py`) | Add the manager commit the file was copied from, if it can be found in their history |
| 6 | Private network addresses appear in docs and settings | private-range addresses in `launcher/README.md`, `signup/README.md`, `server-settings.txt` and two setup scripts (find them with check 6's command; not repeated here) | Private-range addresses cannot be reached from outside, so this is low concern; listed so nobody is surprised | None needed |
| 7 | Screenshots and images are tracked | `launcher/site/images/*.png, *.jpg` (how-to-play screenshots, two of them of the game: `linux-7-login.jpg`, `starting-abilities.jpg`); `launcher/site/steam/*.png` | The Steam art is drawn by our own script, which says "original art: no game assets" (`launcher/steam-art/make_steam_art.py`, fonts from Google Fonts under OFL). The two game screenshots show the game's own screens; the images were not opened and inspected here | None proposed; noted for completeness |
| 8 | Data derived from client tables is in the repository by design | `addon/WildcardEnchants/EnchantData.lua` ("Generated from MysticEnchant.dbc": spell id, quality, class mask); `sql/enchants/009` and `011` (rebuilt spells: ids, names, numbers, **and one description sentence per rebuilt spell, about 860 and 335, written from the archived builder description**); `enchants/tracker.csv` (ids, names) | The line the project draws in practice: ids, names and numbers are kept; client files are not. Description text is **not settled**: whether the sentences in `009` and `011` count as verbatim tooltip text is an OPEN question for James (`wildcard-architecture-contract` V7). Do not add more until he rules; check 7 cannot see them (it looks for format codes, and these sentences have none). Stated here so a newcomer does not "fix" it or widen it | None; keep to that line |
| 9 | No secrets found | whole tree | Checks 3 and 4 printed nothing. The only matches for secret-like words are placeholders (`PASTE-SECRET-KEY`, `CHANGE-ME`, `github_pat_...` in `signup/README.md`) | None |
| 10 | No game client files and no third-party addon code found | whole tree | Checks 1 and 5 found no client data; all 11 pin lines have full commits | None |

Not checked: the full git history (only the current tree), pull request and issue text, release zips, and the live
website. A secret removed from the tree can still sit in history; to search history for one pattern:

```bash
git log origin/main -p -S'github_pat_' --format='%h %ad %s' --date=short | grep -E '^[0-9a-f]{7,} |^\+.*github_pat_' | head
```

(Run on 2026-11-22: the only hits were the `github_pat_...` placeholder in `signup/README.md`.)
