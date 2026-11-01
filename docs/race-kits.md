# Race kits: the new baseline

Every race gets **two active abilities and two passives**, each tied to the race's identity.

**The rules:**
- An **active** must ask for a decision: when to use it, what to spend, what you give up. No "press for more
  damage on cooldown". It answers a situation (a stun, a fear, a pull, low health) or trades one thing for another.
- A **passive** must change how you play: your rotation, your route, how you gear, how you use a profession, or a
  strategy no other race has. No flat stat bonus you never notice.
- The models are Gnome **Expansive Mind** (a little more energy really changes a rogue's rotation) and Night Elf
  **Shadowmeld** (opens strategies nobody else can do alone).
- Several passives lean on professions and long-term play, to fit a server where you keep one character.

WoW Forever's rework was the starting point; most of it was rejected under these rules. Optional and per realm
(see [roadmap.md](roadmap.md), item 6). Numbers are first guesses for testing.

Build notes: *existing* = a spell the client already has; *reworked* = an existing spell with new server
numbers, tooltip text from the addon; *hook* = a small piece of C++; *new* = a new active (reused spell, or the
client patch from roadmap item 2).

## Alliance

**Human**: adaptable, connected

| | Racial | What it does | The decision or change | Built as |
| --- | --- | --- | --- | --- |
| Active | Will to Survive | Breaks a stun. The next stun on you within 30 sec lasts 50% longer. | Break this stun, or save it for a worse one? | existing, reworked |
| Active | Adaptive Focus | Choose Offence (+5% damage), Defence (+5% armor and healing taken) or Utility (+10% speed, faster out-of-combat regen). Switching has a 30 sec cooldown. | Read the fight and commit. | new |
| Passive | Jack of All Trades | Humans can learn a third primary profession. | A different crafting and gathering plan. | hook |
| Passive | Diplomacy | Reputation gains +10%, vendor prices -5%. | Faction grinds and gold plans shift. | existing (classic Diplomacy), reworked |

**Dwarf**: stubborn, miners, brewers

| | Racial | What it does | The decision or change | Built as |
| --- | --- | --- | --- | --- |
| Active | Stoneform | For up to 8 sec: immune to bleeds, poisons and diseases, 30% less physical damage taken, but 50% slower. Can be cancelled. | Survive in place, or keep moving? | existing, reworked |
| Active | Dig In | For 10 sec you cannot be knocked back, pulled or displaced, and generate 20% more threat, but you cannot move. | Hold a ledge or a doorway at the cost of mobility. | new |
| Passive | Miner's Instinct | Mining nodes always show (alongside any other tracking) and have a chance to yield an extra gem. | Route through ore while doing anything else. | hook |
| Passive | Stout | Being drunk grants +2/4/6% Stamina and fear resistance instead of only penalties. | Drink before a fight, on purpose. | hook |

**Night Elf**: the shadows of the forest

| | Racial | What it does | The decision or change | Built as |
| --- | --- | --- | --- | --- |
| Active | Shadowmeld | Stealth while standing still. | Unchanged: strategies nobody else has. | existing |
| Active | Wisp Form | For 6 sec: 50% faster, immune to damage, but cannot attack or cast. | An escape or a reposition, at the cost of 6 sec of output. | new |
| Passive | Silent Step | Out of combat, you can walk at half speed without breaking Shadowmeld. | Shadowmeld becomes a way to move, not only to hide. | hook |
| Passive | Wisp Spirit | +75% speed while dead. | Corpse runs barely matter; take riskier pulls. | existing |

**Gnome**: resourceful tinkerers

| | Racial | What it does | The decision or change | Built as |
| --- | --- | --- | --- | --- |
| Active | Escape Artist | Escape roots and snares. | Unchanged: answer a root. | existing |
| Active | Overclock | Your next 3 abilities cost 30% less, then your resource regenerates 50% slower for 10 sec. | Burst now, pay later. | new |
| Passive | Expansive Mind | +5% maximum Mana, Rage or Energy. | Unchanged: rotations bend around it. | existing |
| Passive | Gadgeteer | Engineering devices never misfire, and engineering item cooldowns are 25% shorter. | Engineering becomes a real combat kit. | hook |

**Draenei**: exiles who crossed the stars

| | Racial | What it does | The decision or change | Built as |
| --- | --- | --- | --- | --- |
| Active | Gift of the Naaru | Heals the target over 15 sec. | Self or an ally? | existing |
| Active | Shifting Crystal | Place a crystal for 15 sec; allies next to it take 10% less damage. | Where to stand, and who gets to stand there. | new |
| Passive | Crystalline Affinity | Socketed gems give 10% more stats. | Sockets and socket bonuses become a real gearing choice. | hook |
| Passive | Astral Anchor | Bind your Hearthstone to two inns; it asks which one. | Plan travel around two homes. | hook |

## Horde

**Orc**: fury and endurance

| | Racial | What it does | The decision or change | Built as |
| --- | --- | --- | --- | --- |
| Active | Blood Fury | +15% attack and spell power for 15 sec, but healing received is halved. | Pick a moment when you will not need heals. | existing, reworked |
| Active | Shatter Curse | Removes curses, then 5% less magic damage taken for 8 sec. | Answer a curse at the right time. | new |
| Passive | Command | Pets deal 5% more damage and move 10% faster. | Pet builds get an edge. | existing, reworked |
| Passive | Unbroken | When a stun ends, your next ability within 4 sec costs nothing. | Plan a punish after every stun. | hook |

**Undead**: they do not breathe, they do not tire

| | Racial | What it does | The decision or change | Built as |
| --- | --- | --- | --- | --- |
| Active | Will of the Forsaken | Breaks charm, fear and sleep. | Unchanged: answer a fear. | existing |
| Active | Cannibalize | Eat a humanoid or undead corpse: restore health and mana over 10 sec; interrupted by damage. | Rest on a corpse, or keep moving? | existing |
| Passive | Unbreathing | No breath limit underwater. | Underwater routes, fishing and escapes others cannot use. | existing (Underwater Breathing), reworked |
| Passive | Dead Man's Hunger | Finishing a Cannibalize grants Fed: 5% of damage dealt heals you for 60 sec. | Ties the active to fights: eat, then pull. | hook |

**Tauren**: plains runners and herbalists

| | Racial | What it does | The decision or change | Built as |
| --- | --- | --- | --- | --- |
| Active | War Stomp | Stuns nearby enemies for 2 sec. | When to stop a pack. | existing |
| Active | Stampede | Charge 15 yards, knocking enemies aside. Spends your Plainsrunning stacks: more stacks, a longer stun and more damage. | Keep the speed, or cash it in? | new |
| Passive | Plainsrunning | Every 5 sec of running adds 2% speed, up to 60%; stopping or taking damage loses it. | Route and pace around keeping speed up. | hook |
| Passive | Cultivation | A chance at a duplicate herb when gathering, and some herbs can be gathered without Herbalism. | Herbs as a side income for any Tauren. | hook |

**Troll**: regeneration and voodoo

| | Racial | What it does | The decision or change | Built as |
| --- | --- | --- | --- | --- |
| Active | Berserking | 10% to 30% faster attacks and casts for 10 sec; the lower your health, the bigger it is. | Risk going low for a bigger burst. | existing, reworked |
| Active | Regenerative Trance | Channel for up to 10 sec to regenerate 50% of your health; damage breaks it. | Find a safe moment, or lose it. | new |
| Passive | Regeneration | 10% of your health regeneration continues in combat. | Long fights favour you. | existing, reworked |
| Passive | Headhunter | Each beast you kill gives +5% damage to beasts for 5 min, up to 25%. | Chain beast pulls on purpose. | hook |

**Blood Elf**: magic addicts

| | Racial | What it does | The decision or change | Built as |
| --- | --- | --- | --- | --- |
| Active | Mana Tap | Drain an enemy's mana into a charge, up to 3. | Build charges before a fight. | existing |
| Active | Arcane Torrent | Silence nearby enemies and restore resource; each Mana Tap charge spent makes it stronger. | Spend charges now, or hold them? | existing, reworked |
| Passive | Magic Hunger | Each Mana Tap charge gives +2% resource regeneration; charges fade over time. | Keep charges up as part of your rotation. | hook |
| Passive | Sunwell Attunement | Enchantments you apply to your own gear are 10% stronger. | Enchanting pays off for yourself. | hook |

## What it needs

- A `race -> spell` table applied at login, and removal of the stock racials while the switch is on.
- Hooks: about 15 of the passives (most are small), sharing a few building blocks: gathering bonuses, buffs on
  an event (the enchant action handler can do several), profession rules and the Hearthstone.
- New actives: Adaptive Focus, Dig In, Wisp Form, Overclock, Shifting Crystal, Shatter Curse, Stampede and
  Regenerative Trance. A reused spell for each for now, a proper one once the client patch works.
- Tooltip text for reworked spells through the WildcardEnchants addon.
