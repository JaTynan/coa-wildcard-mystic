# Patch catalogue (as of 2026-11-22, `origin/main` `d3e030f`, release server-0.261119.114)

Read this when you need to know which script owns a file, which helper style a script uses, or what an existing
script depends on, before adding to it or anchoring near it. Regenerate the facts with the commands at the end;
do not trust this table after `patches/` has changed.

## The five `*.patch` files (applied first, inside `core/`, before any module exists)

| File | Size | What it holds | Files |
|---|---|---|---|
| `mystic-enchants-actions.patch` | 302 lines | Declares and calls `AddSC_WcmeEnchantActions` in the CoA script loader; adds the enchant action scripts | `src/server/coa/CoAScriptLoader.cpp`, new `src/server/coa/WcmeEnchantActions.cpp` |
| `mystic-enchants-scripts.patch` | 14,558 lines, 671 KB | One new file: every Mystic Enchant that has its own C++ (`@@ -0,0 +1,14552 @@`) | new `src/server/coa/WcmeEnchantScripts.cpp` |
| `mystic-enchants-spellaffect-sql.patch` | 13 lines | One line: SpellAffect data can also come from the table `wcme_spellaffect_dbc` | `src/server/game/DataStores/DBCStores.cpp` |
| `mystic-enchants-wildcard.patch` | 456 lines | Mystic Enchants allowed on a Wildcard realm (`CoA.MysticEnchants.AllowWildcard`) and the rules around it | `AscensionFreepick.cpp`, `AscensionMysticEnchant.cpp`, `AscensionMysticEnchantRules.cpp/.h`, `conf/coa.conf.dist` (all under `src/server/coa/`) |
| `wildcard-ability-pool.patch` | 135 lines | `Wildcard.AbilityPool` | `src/server/coa/AscensionWildcard.cpp`, `conf/wildcard.conf.dist` |

No two patch files touch the same file. Four of the five were made against an older core and still apply at a line
offset (regenerating them on 2026-11-22 changed only their `@@` line numbers). `WcmeEnchantScripts.cpp` is not
compiled into anything until `64-enchant-scripts-loader.ps1` adds `AddSC_WcmeEnchantScripts()` to the loader, next to
the line `mystic-enchants-actions.patch` added: that is why 64 throws "is mystic-enchants-actions.patch applied?".

## The 56 scripts

"Files it changes" is measured (the pre-flight records which files each script altered). "Needs" is what the
script's own comments and error texts name; removing `40-battlegrounds.ps1` in a scratch copy made exactly the 21
scripts that name it fail, so the column is right for 40. "Settings read" counts distinct
`sConfigMgr->GetOption` names in the inserted C++ (names and defaults: sibling skill wildcard-settings-and-flags).

| Script | Edit style | Files it changes | Earlier scripts / patches it needs | Settings read | Companions it names |
|---|---|---|---|---|---|
| `10-mod-ollama-chat-fit.ps1` | inline blocks | mod-ollama-chat: mod-ollama-chat_events.cpp, mod-ollama-chat: mod-ollama-chat_handler.cpp, mod-ollama-chat: mod-ollama-chat_quiet.h (new), mod-ollama-chat: mod-ollama-chat_random.cpp, mod-ollama-chat: mod-ollama-chat_world.cpp | - | 2 | - |
| `20-bots.ps1` | inline blocks | mod-playerbots: CoaAiObjectContext.cpp, mod-playerbots: EnemyPlayerValue.cpp, mod-playerbots: InviteToGroupAction.cpp, mod-playerbots: PlayerbotAI.cpp, mod-playerbots: RandomPlayerbotMgr.cpp | - | 5 | - |
| `30-wildcard-rewards.ps1` | inline blocks | AscensionWildcard.cpp, LootHandler.cpp | - | 7 | - |
| `40-battlegrounds.ps1` | inline blocks | AscensionAdventurerCache.cpp, Battleground.cpp | - | 9 | - |
| `45-weekend-bonus.ps1` | Edit-Anchored, inline blocks | AscensionAdventurerCache.cpp, Player.cpp, PlayerQuest.cpp, WeekendBonus.h (new) | 40 | 9 | - |
| `46-play-time-rewards.ps1` | inline blocks | AscensionAdventurerCache.cpp | 40 | 5 | - |
| `47-leaderboards.ps1` | inline blocks | AscensionAdventurerCache.cpp | 40 | 2 | - |
| `48-bonus-stats.ps1` | inline blocks | AscensionAdventurerCache.cpp, AscensionCacheRewards.cpp | 40 | 9 | - |
| `49-prestigious-legendary.ps1` | Edit-Anchored | AscensionMysticEnchant.cpp, AscensionMysticEnchant.h, AscensionPrestigiousCache.cpp | the *.patch files | 1 | - |
| `50-manastorm.ps1` | inline blocks | AscensionManastorm.cpp | - | 1 | - |
| `51-profession-mastery.ps1` | inline blocks | AscensionAdventurerCache.cpp | 40, 48 | 9 | - |
| `52-racials.ps1` | inline blocks | SpellInfoCorrections.cpp | - | - | client-patch/racials.py |
| `53-wildcard-card-messages.ps1` | inline blocks | AscensionWildcard.cpp | - | - | - |
| `54-racial-plainsrunning.ps1` | inline blocks | AscensionAdventurerCache.cpp, Player.h, SpellInfoCorrections.cpp, Unit.cpp | 40 | 1 | sql/enchants/150-*, client-patch/custom_spells.py |
| `55-talent-fixes.ps1` | inline blocks | AscensionAdventurerCache.cpp | 40 | - | sql/enchants/140-* |
| `56-racial-bloodrush.ps1` | inline blocks | AscensionAdventurerCache.cpp | 40 | 1 | sql/enchants/150-*, client-patch/custom_spells.py |
| `57-racial-ambush.ps1` | inline blocks | AscensionAdventurerCache.cpp, Player.h | 40, 54 | 1 | sql/enchants/150-*, client-patch/custom_spells.py |
| `58-racial-voodoo-regeneration.ps1` | inline blocks | AscensionAdventurerCache.cpp, Player.h | 40, 54 | 1 | sql/enchants/150-*, client-patch/custom_spells.py, client-patch/racials.py |
| `59-racial-radiant-presence.ps1` | inline blocks | AscensionAdventurerCache.cpp, Player.h, SpellInfo.cpp | 40 | 1 | sql/enchants/150-*, client-patch/custom_spells.py |
| `60-manaforged-barrier.ps1` | inline blocks | AscensionAdventurerCache.cpp, Player.h, Unit.cpp | 40 | 1 | sql/enchants/150-*, client-patch/custom_spells.py |
| `61-bg-bot-whispers.ps1` | inline blocks | mod-playerbots: PlayerbotSecurity.cpp | - | - | - |
| `62-racial-spellbook.ps1` | inline blocks | AscensionAdventurerCache.cpp | 40 | 1 | sql/enchants/150-*, client-patch/custom_spells.py |
| `63-enchant-target-cooldowns.ps1` | inline blocks | SpellAuras.cpp, SpellAuras.h | - | - | sql/enchants/015-* |
| `64-enchant-scripts-loader.ps1` | inline blocks | CoAScriptLoader.cpp | mystic-enchants-actions.patch, mystic-enchants-scripts.patch | - | - |
| `65-enchant-tuning-auras.ps1` | inline blocks | Unit.cpp | - | - | - |
| `66-enchant-core-hooks.ps1` | Edit-Anchored | spell_mage.cpp | mystic-enchants-scripts.patch | - | sql/enchants/026-*, client-patch/custom_spells.py |
| `67-hoplite-polearm-shield.ps1` | inline blocks | Player.cpp | mystic-enchants-scripts.patch | - | - |
| `68-aspect-of-the-fox-auto-shot.ps1` | inline blocks | Unit.cpp | - | - | - |
| `69-iron-guard-block.ps1` | inline blocks | Unit.cpp | - | - | - |
| `70-mastery-of-the-tide-riptide.ps1` | inline blocks | spell_shaman.cpp | - | - | - |
| `71-jump-multiplier-points.ps1` | inline blocks | SpellInfo.cpp | - | - | - |
| `72-racial-grave-defiance.ps1` | inline blocks | AscensionAdventurerCache.cpp, Player.h, SpellInfoCorrections.cpp | 40 | 1 | sql/enchants/150-*, client-patch/custom_spells.py |
| `73-racial-spellsword.ps1` | inline blocks | AscensionAdventurerCache.cpp, Player.h | 40 | 1 | sql/enchants/150-*, client-patch/custom_spells.py |
| `74-racial-overclock.ps1` | inline blocks | AscensionAdventurerCache.cpp, Player.h | 40 | 1 | sql/enchants/150-*, client-patch/custom_spells.py |
| `75-racial-arcane-hunger.ps1` | inline blocks | AscensionAdventurerCache.cpp, Player.h, SpellInfoCorrections.cpp | 40 | 1 | sql/enchants/150-*, client-patch/custom_spells.py, client-patch/racials.py |
| `76-racial-prospectors-spirit.ps1` | inline blocks | AscensionAdventurerCache.cpp, Player.h | 40 | 1 | sql/enchants/150-*, client-patch/custom_spells.py |
| `77-resting-mana-regen.ps1` | inline blocks | StatSystem.cpp | - | 1 | - |
| `78-worldforged-enchants.ps1` | inline blocks | AscensionMysticEnchant.cpp, Player.h | mystic-enchants-wildcard.patch | 1 | - |
| `79-mystic-enchant-gold-cost.ps1` | inline blocks | AscensionMysticEnchant.cpp | - | 1 | - |
| `80-racial-status-command.ps1` | inline blocks | AscensionAdventurerCache.cpp | 40 | - | - |
| `81-chat-channel-guard.ps1` | inline blocks | Chat.cpp | - | - | - |
| `82-runes-in-currency-tab.ps1` | inline blocks | AscensionAdventurerCache.cpp, Player.h | 40 | - | sql/enchants/160-* |
| `83-stored-pet-of-its-kind.ps1` | Edit-Core | Pet.cpp, Pet.h, Spell.cpp, SpellEffects.cpp | - | - | - |
| `84-treasure-keeper-instant-reward.ps1` | Edit-Core | mod-manastorm-endless: ManastormMgr.cpp, mod-manastorm-endless: ManastormRewards.cpp, mod-manastorm-endless: ManastormRewards.h | - | - | - |
| `85-empty-system-mail-deletes-itself.ps1` | Edit-Core | MailHandler.cpp | - | - | - |
| `86-scrolls-of-fortune-redeem-themselves.ps1` | Edit-Core | AscensionWildcard.cpp, Player.h | - | - | - |
| `87-wildcard-bots-revive-pets.ps1` | Edit-Core | mod-playerbots: CoaAiObjectContext.cpp | 83 | - | - |
| `88-dungeon-finder-refusal-log.ps1` | Edit-Core | LFGMgr.cpp | - | - | - |
| `89-racial-stoneform.ps1` | inline blocks | SpellInfoCorrections.cpp | - | - | client-patch/racials.py |
| `90-dungeon-clear-auto-start.ps1` | Edit-Core | Player.h, mod-dungeon-clear: DungeonClearModule.cpp | - | 1 | - |
| `91-weekly-event-mystic-scrolls.ps1` | Edit-Core | AscensionMysticEnchant.cpp | 45 | - | - |
| `92-bots-hand-in-at-wisdomball.ps1` | Edit-Core | mod-playerbots: QuestAction.cpp | - | - | - |
| `93-group-xp.ps1` | Edit-Core | AscensionAdventurerCache.cpp | 40 | 1 | - |
| `94-dungeon-finder-join-limit.ps1` | Edit-Core | LFGPackets.h | - | - | - |
| `95-dungeons-scale-up.ps1` | Edit-Core | LocalLevelScaling.h, mod-destiny-weaver: destiny_weaver_scaling.cpp | - | - | - |
| `96-bots-ignore-commands.ps1` | Edit-Core | mod-playerbots: CoaLive.cpp, mod-playerbots: WildcardBotCommand.h (new) | - | - | - |

## Shared anchors (why so many scripts can edit one file)

- **`src/server/coa/AscensionAdventurerCache.cpp` (22 scripts).** `40-battlegrounds.ps1` turns this file into the
  home of our script classes: it adds `#include "PlayerScript.h"` and registers `new world_pvp_kill_xp();` inside
  `AddSC_AscensionAdventurerCache()`. Later scripts insert their class in front of
  `void AddSC_AscensionAdventurerCache()\n{\n` and their registration after `    new world_pvp_kill_xp();\n`. Both
  anchors survive every insertion, so the next script finds them again.
- **`src/server/game/Entities/Player/Player.h` (14 scripts).** Per-player state (timers, stacks) is added as public
  members straight after `public:\n    explicit Player(WorldSession* session);\n`. Members are named `Wcme...`.
- **`src/server/game/Spells/SpellInfoCorrections.cpp` (5 scripts)**: each inserts an `ApplySpellFix` block after the
  first lines of `SpellMgr::LoadSpellInfoCorrections()`.

Because these anchors survive their own edit, running a script a second time would insert its code a second time
without any error (a copy of `52-racials.ps1` under another name ran "OK" twice in a scratch test on 2026-11-22).
The build and the pre-flight always start from freshly checked out sources for this reason.

## New files written by scripts

| File | Written by |
|---|---|
| `core/modules/mod-ollama-chat/src/mod-ollama-chat_quiet.h` | `10-mod-ollama-chat-fit.ps1` |
| `core/src/server/game/Miscellaneous/WeekendBonus.h` | `45-weekend-bonus.ps1` (91 checks it exists) |
| `core/modules/mod-playerbots/src/Ai/Coa/Social/WildcardBotCommand.h` | `96-bots-ignore-commands.ps1` |

All three are headers placed in a folder the build already compiles and includes, so nothing in CMake changes.
No script adds a `.cpp` file; the only new `.cpp` files come from the `*.patch` files, in `src/server/coa/`.

## Error texts by helper

| Where | Text thrown | Count (grep, 2026-11-22) |
|---|---|---|
| `Edit-Core` in 83-86, 88, 90-95 | `Core changed: <what> was not found exactly once in <file>` | 11 scripts |
| `Edit-Core` in 96 | `SQUID changed: <what> was not found exactly once in <file>` | 1 |
| `Edit-Core` in 87 | `SQUID's bots changed: <what> was not found exactly once in <file>` | 1 |
| `Edit-Anchored` in 45, 49 | `Core changed: <what> was not found in <file>` | 2 |
| `Edit-Anchored` in 66 (takes a list of pairs) | `<file> anchor not found exactly once: <anchor>` | 1 |
| inline checks, 10-82 | `Core changed: ...`, `CoA changed: ...`, `SQUID changed: ...`, `mod-ollama-chat changed: ...`, `Core changed (or 40-battlegrounds.ps1 did not run): ...` | most of the 122 `throw` lines |

## Regenerate

```bash
cd <repo>
ls patches/*.ps1 | wc -l; ls patches/*.patch | wc -l
grep -n "^function " patches/*.ps1                                  # helper definitions
grep -A3 "^function Edit-Core" patches/*.ps1 | grep -o 'throw "[^:]*' | sort | uniq -c
grep -n "Set-Content [\"'][^ ]*\.h" patches/*.ps1                    # new headers
grep -c "^diff --git" patches/*.patch
python3 -I .claude/skills/wildcard-patch-authoring/scripts/preflight.py latest --json /tmp/preflight.json
python3 -c "import json;[print(s['name'], s['touched']) for s in json.load(open('/tmp/preflight.json'))['scripts']]"
```
