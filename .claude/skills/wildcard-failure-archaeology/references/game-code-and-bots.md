# Chronicle: game-code fixes outside the enchants (bots, items, battlegrounds, chat)

Server-code and bot-behaviour failures that are not about Mystic Enchants or performance. Most are short. They
are grouped as **fix series** (the same thing fixed more than once) because the second and third fix are the
part worth remembering. Facts come from commit messages, as of 2026-11-22. Nothing was re-tested in game.

Reading aid:

- **Hook:** a point where the core calls our code (for example "a player used an item").
- **SQUID:** SQUID's Playerbots, the random bots. **Random bot:** a bot nobody commands.
- **Wisdomball, Case of Fortune, Scroll of Fortune, Manastorm:** CoA and Wildcard items and modes; what matters
  here is how each is opened or handed in.

---

## G-01 · 2026-11-20 · The world server stopped on a channel message with no channel name

- **Symptom:** "The world server stopped on it on 20 November."
- **Root cause:** "`ChatHandler::BuildChatPacket` asserted when a CHAT_MSG_CHANNEL message had no channel name;
  SQUID's bots can build one when they answer, in the chat type they heard, a command that came from a channel."
- **Evidence:** `3a50d87` (reached `main` with PR #199); `patches/81-chat-channel-guard.ps1`.
- **Tried and rejected:** none recorded.
- **Status:** fixed: "the message goes out with an empty channel name and the sender is logged."
- **Lesson:** this is the only server stop recorded in the repository with a named cause. An assert in the core
  stops the whole world; bots reach code paths players never do.

## G-02 · "The handler never ran": three items opened by a path the fix did not watch

| Date | Item | First fix | Why it never ran | Second fix | Evidence |
|---|---|---|---|---|---|
| 10 to 12 Nov | Case of Fortune (empty cases piled up) | wait for the case's spell, then remove one case | "a case opens as a loot container, so it never ran" | "the loot release removes one case and mails any scroll not taken" | `6c4bba6` (PR #115), then `6ccb7b4` (PR #120) |
| 10 Nov | Manastorm caches (open into bags) | replace the cache's `OnUse` | "the caches have the has-loot flag, so a right-click sends CMSG_OPEN_ITEM and opens a loot window instead; OnUse never ran" | a `ServerScript` catches `CMSG_OPEN_ITEM` | `d1f987c` (PR #113), then `1bfcce9` (PR #114) |
| 21 Nov | Dungeon quests at the Wondrous Wisdomball (bots never handed in) | none before | "The ball ends quests by its own script, not the quest giver tables, so a bot's quest menu on it was empty" | patch 92 hands in through `AscensionWisdomball::TurnInQuests` | `6733e5d`, PR #216 |

- **Lesson:** before hooking an item, find out how the client opens it: item use, loot container
  (`CMSG_OPEN_ITEM`) or a script of its own. A hook on the wrong path compiles, loads and does nothing.

## G-03 · 2026-11-08 to 14 · Battleground resurrection, three fixes

| Date | Symptom | Root cause | Evidence |
|---|---|---|---|
| 8 Nov | Ghosts standing at their spirit guide were not raised | a ghost "dropped out of the revive queue"; also "the wave walks a copy of the queue so a removal mid-wave cannot skip the next ghost" | `0bc4d94`, PR #90 |
| 12 Nov | A permanent "Waiting to Resurrect" aura | "Bots revive themselves and talk to the spirit guide again, so they keep the aura forever (the wave only clears the queue)" | `28a7345`, PR #127 |
| 14 Nov | Spirit guides acting on players already alive | fix title: "skip anyone already alive" (no body) | `6805acd`, PR #145 |

- **Status:** fixed three times; no test recorded.
- **Lesson:** each fix exposed the next case. Bots do things in battlegrounds that players do not (revive
  themselves, then talk to the guide again).

## G-04 · 2026-11-14 to 21 · Battleground bots whispering back, two fixes

| Date | Symptom | Root cause | Evidence |
|---|---|---|---|
| 14 Nov | Random bots whisper "I have a master already", over and over | "every whisper a player or an addon sent one of them (SquidBots Lite polls its bots) got that reply" | `549f50a`, PR #159; patch 61 |
| 21 Nov | A canned fallback line whispered back "every 30 seconds" | the addon's commands ("co ?", "wcr", "talents spec list") went to every "... Bot" in the party; "SQUID's live chat took each command for small talk" | `13a03d3`, PR #228; patch 96 |

- **Lesson:** the first fix silenced one reply and left the cause (an addon polling bots it does not command);
  a different reply appeared.

## G-05 · 2026-11-21 · Dungeon Finder did nothing for "Random Classic Dungeon"

- **Symptom:** "Find a Group did nothing."
- **Root cause:** the client sends "every dungeon of the type (52-126 in the logs); the core's limit of 50
  dropped the request".
- **Evidence:** `a392da9`, PR #226; patch 94. Found with the refusal log added the same day (`33bda95`, PR #206,
  patch 88), which was written "to find why James's group of alts as bots is refused Ragefire Chasm while he
  alone is not".
- **Status:** the 50-dungeon limit is fixed. The repository does not say whether that was also the cause of the
  Ragefire Chasm refusal: **open** (see SKILL.md, open questions).
- **Lesson:** a silent refusal was only diagnosable after logging the reason. Log first.

## G-06 · 2026-11-20 · Pet-returning spells brought back the wrong pet

- **Symptom:** "after a prestige from a hunter pet to demons, Summon Demon brought back the boar". Then, after
  the first fix: "Revive Undead brought back the imp after the boar was abandoned."
- **Root cause:** these spells "load a stored pet without naming a creature, and the core took the current pet
  whatever it was"; the Revive family "loads 'any stored pet' just like Summon Demon".
- **Evidence:** `b11e39a` then `2bd03ba`, PR #202; patch 83.
- **Status:** fixed in two steps; "a stored pet is only ever loaded ..., never recreated as a new one".
- **Lesson:** Wildcard characters can hold pets of several kinds, which no stock class can. Code written for one
  class's pet must be checked for the others.

## G-07 · Smaller ones

| Date | Symptom | Root cause | Evidence | Status |
|---|---|---|---|---|
| 12 Nov | World PvP kill XP far below intent ("2.15% instead of 6% a kill") | it "called GiveXP without the OnPlayerGiveXP hook, so Rate.XP.Global and prestige would not have applied" | `59e6bcf`, PR #118 | fixed |
| 13 Nov | Bot group leaders | SQUID's nearby grouping: "the leader now checks the target's part rather than its own, and never invites real players" | `5976987`, PR #132 | fixed in patch 20 |
| 20 Nov | Killing the Manastorm Treasure Keeper "seemed to give nothing" | the reward "only arrived in the completion mail" | `b75337f`, PR #203 | changed |
| 20 Nov | Mailbox full of empty system letters; hundreds of Scroll of Fortune stacks to click | nothing deleted or redeemed them | `56e304f`, `7232b63`, PR #205 | changed |
| 21 Nov | Wildcard bots never revived their pets | "SQUID's bots only revived pets in the Hunter routine" | `33bda95`, PR #206; patch 87 | fixed |
| 21 Nov | Auction House listed Outland and Northrend goods on a level 60 realm | "The required-level limit (60) misses items with no required level" | `ee4ab40`, PR #222 | fixed by a computed never-list |
| 22 Nov | "the shield and stance bug of 22 Nov" (Wildcard Heroes are class 10; "class tables and spec lookups often have no row for them") | named only in `docs/agents/context/patches.md:25` | no commit, issue or fix found in the repository | **unknown - ask James** |
