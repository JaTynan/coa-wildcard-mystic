# Server roadmap

## Where the server is heading

One character you stick with and keep investing in. The end state:

- **Mystic Enchants mostly working**, fixed or rebuilt ([enchant-restoration.md](enchant-restoration.md)).
- **Level cap 70.** Wildcard keeps rolling abilities and talents up to 70. Outland's content is standard Wrath
  data; the CoA systems tuned for 60 (custom items and vendors, level scaling, PvP power) need checking.
- **Death Knight filled out** with enchants for real builds ([dk-enchant-proposal.md](dk-enchant-proposal.md)).
- **Race kits:** racials reworked so race choice changes how you play, optional per realm.
- **Meaningful profession bonuses:** every profession gives a lasting personal benefit worth levelling it for,
  a slow source of power for a character you keep.

## To do (in order)

1. **Fast build loop: build on the Windows game VM** (after the i9 upgrade, due within two weeks: more cores and
   about 10 GB more memory for the VM). Keep a Windows build tree on the VM and only recompile what changed:
   a one-file change rebuilds in minutes and the result is the live server's own format, so there is no
   GitHub wait and no separate test build. Patch night builds locally instead of downloading; GitHub stays
   as the backup builder. Needs Visual Studio Build Tools, CMake, Boost and the MySQL client (what the GitHub
   workflow installs), about 20 to 30 GB of disk, and builds limited to a few cores or run at quiet times so
   players do not feel them. Fallback if that does not suit: a native build on trundle for the test server.
2. **Client patch check** (first step of the [Death Knight proposal](dk-enchant-proposal.md)): does the CoA
   client load an extra patch file? Another CoA community server ships its own patch files for custom races,
   so it seems possible; their notes warn that the launcher may skip patch files with names it does not know.
   Check which patch names the client folder already has, then whether one of ours loads.
3. **Map the Legendary enchants to Death Knight builds.** On Ascension each build centres on one Legendary.
   Candidates to check first: White Walker (two-handed Frost and blade), Vampire Lord (Shadow damage over time
   into healing), Unbounded Deathbringer (not yet checked). White Walker and Vampire Lord are on the broken list.
4. **A full Death Knight set.** Death Knight has no enchants tagged for it (Warrior has 121 on this realm).
   Aim for about 120, Warrior's rarity split, half pure Death Knight and half hybrid. Start from the nine pure
   ones drafted in the proposal, plus two themes:
    - **Plaguebearer:** Death Knight diseases with Warlock damage over time (Corruption, Curse of Agony) and
      Shadow damage generally.
    - **Necromancer:** undead pets (Ghoul, Gargoyle, Army of the Dead) with Warlock demons.
5. **Damage-type transforms** (for example Frost Strike dealing Shadow damage). These need C++: one general
   hook ("this ability deals this school while the enchant is active") so each enchant is a table row. The
   broken pet "Companion" enchants (Fire, Frost, Arcane, Nature, Shadow pet attacks) would use it too.
6. **Race kits: a full racial rework, based on WoW Forever's (optional).** Replace each race's racials with a
   kit that changes how you play, not stat reskins. Aimed at Wildcard, where a random start leaves little sense
   of identity: race becomes the fixed part of a character. A config switch, set per realm through the
   settings kit, so other realms keep the stock racials. Design first, one kit per playable race (WoW Forever's
   kits as the starting point, including the ones for races it does not have), then one build. Pieces:
    - Passive bonuses (for example Tauren Endurance: health plus a second stat) from a `race -> spell` table,
      with the stock racials removed while the switch is on. Reuse client-known spells where possible, so the
      spellbook shows a proper tooltip.
    - Gathering bonuses (for example Tauren Cultivation: bonus herbs): one C++ hook on gathering loot, driven by
      a `race, skill, chance` table.
    - Movement that builds while you keep moving (Tauren Plainsrunning): one C++ hook adding a stacking speed
      aura while moving out of combat.
    - Active abilities that change (WoW Forever reworks some, such as Gnome Eureka!): reuse or adapt
      client-known spells; brand-new ones need the client patch from item 2.
7. **Level cap 70.** First check the Wildcard roll budget (CharacterAdvancementEssence.dbc): if its rows stop at
   level 60, add a small server change that keeps granting rolls to 70. Then raise `MaxPlayerLevel` through the
   settings kit and test a character from 60 to 70: rolls, spell ranks, prestige at the new cap, Outland quests
   and dungeons, CoA items and vendors.
8. **Profession bonuses.** Wrath already has some (Mining: Toughness, Skinning: Master of Anatomy, Herbalism:
   Lifeblood, crafting perks such as Jewelcrafting gems). Design a bonus for every profession that matters for a
   long-kept character, scaling with skill, and that sits well with the race kits. Same building blocks as the
   race kits: a `profession, skill level -> spell` table applied at login, plus gathering and crafting hooks.
