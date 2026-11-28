# Bot build: Holy Radiance (healer)

Status: draft, 28 Nov 2026. Second written build for the tailored bot roster (`docs/bot-roster-plan.md`). Nothing
here is live. Format and rules as in `plague-caster.md`. The bot module's nearest named build is **Hierophant**
(Greater Heal, Renew, Flash Heal, Penance).

Role: healer. Strongest in 10-player groups and 5-player dungeons. S1 says it falls off in 25-player raids unless the
other healers are coordinated around it, so a 25-player roster wants it as one healer among several, not the core.

## 1. Sources

| # | Source | What it gave | Weight |
|---|---|---|---|
| S1 | Video "Holy Radiance - Healer build guide - Ascension Wildcard s10", Heytrix, 7 Aug 2026, https://www.youtube.com/watch?v=pETu2z7YDBo (transcript read 28 Nov) | Season 10 Wildcard version: how it heals, what to card, talent interactions, stats | Primary |
| S2 | Discord guide: none yet. James's druid list has HoT healers (Seed of Life and others) but no priest-style Renew build | - | Cross-check wanted |
| S3 | Our client spell data (`Spell.dbc`, read 28 Nov) | Exact behaviour and stack limits | Settles what an ability does |

## 2. How the build works

Checked against S3 unless marked.

- **Renew** on as many group members as possible is the base.
- **Holy Radiance** (talent): Greater Heal and Flash Heal also heal **every** ally carrying the caster's Renew (S1: by
  about 30% of the heal). One cast heals the whole group, with no range or bounce limits like Chain Heal.
- **Serendipity** (talent): Renew and Flash Heal each cut the cast time and cost of the next Greater Heal; up to 3
  stacks. **Good Fortune** (talent): spending a full 3-stack gives extra holy crit. S1 found Good Fortune only works with
  Serendipity at full rank.
- **Borrowed Time**: S1 says Renew now grants it (20% spell haste for 5 seconds), and **Words of Healing** stops it being
  used up and adds crit to direct heals. (S3's Borrowed Time names Power Word: Shield: **check in game** that Renew grants
  it on our realm.)
- **Faithful Light** (talent): direct holy heals on the Beacon of Light target extend the Beacon, so it rarely needs
  recasting (S1 calls it close to mandatory).
- **Halo** and **Prayer of Preservation** are the group bursts. S1: Prayer of Preservation first, then Halo, tops up
  everyone. **Light of Life** adds a heal over time to Halo and extends Renew. Two versions of Halo exist; S1 notes that
  in Season 10 both versions share a cooldown, so only one is worth having.
- **Holy Concentration**: a critical Flash Heal or Greater Heal raises spirit for a short time (mana).
- **Avenging Wrath**: 20% more healing when the group is in trouble (S1's most-wanted ability).

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Renew, Greater Heal, Flash Heal, Life Tap (mana) | S1 ("mandatory at level 1") |
| Core talents | Holy Radiance, Serendipity, Good Fortune, Faithful Light (with Beacon of Light), Holy Concentration, Words of Healing | S1 |
| Group heals | Halo (one version), Prayer of Preservation, Circle of Healing | S1 |
| Cooldown | Avenging Wrath | S1 |
| Rolled extras | Fel Armor (S1: gives healing power and is rare), a blink, Light of Life, crit talents, Nimble Mind (haste) | S1 |

S1 skipped a pet: not enough ability or talent space, and group heals waste healing on it.

Stats: crit and spirit (S1 at 35% crit unbuffed), then haste: S1 wants Flash Heal near a 1-second cast.

## 4. The decision list

Top to bottom; the first line that is true wins.

### Out of combat

| # | When | Do | Source |
|---|---|---|---|
| N1 | Fel Armor (or Nimble Mind) is not on me, if rolled | Cast it | S1 |
| N2 | The tank has no Beacon of Light | Beacon of Light on the tank | S1 (Faithful Light keeps it up; choosing the tank: **guess**) |

### In combat

| # | When | Do | Source |
|---|---|---|---|
| H1 | Several group members are hurt **and** Prayer of Preservation is ready | Prayer of Preservation | S1 |
| H2 | Several group members are hurt **and** Halo is ready | Halo | S1 (straight after H1) |
| H3 | A group member is at critical health **and** Avenging Wrath is ready | Avenging Wrath | S1 (when healing is really needed; threshold **guess**) |
| H4 | A group member is at critical health | Flash Heal on them | S1 mentions Flash Heal speed; using it for emergencies: **guess** |
| H5 | A group member in combat does not have my Renew | Renew on them | S1 (the base of the build; also feeds Serendipity and Borrowed Time) |
| H6 | A group member is hurt **and** I have 3 Serendipity stacks | Greater Heal on them | S1 |
| H7 | A group member is hurt | Greater Heal on them | S1 (the main heal; Holy Radiance spreads it) |
| H8 | The tank has no Beacon of Light | Beacon of Light on the tank | S1 |

Deliberate choices:

- **Renew before Greater Heal** unless someone is in danger: every Renew makes every later Greater Heal heal one more
  person.
- **No healer damage.** S1 does not describe dealing damage; the general routine's "healer may attack" stays as it is.

### What the bots need for this one

Beyond the `all::` and `not::` conditions from `plague-caster.md`:

- A condition "a group member in combat lacks my Renew". The bot module has a "cast buff party" action and "party
  member low / medium / critical health" conditions; whether they cover a heal over time per member is **to check** in
  the code.
- "Several group members are hurt": the module has a group-heal setting; the count to use is a **guess** (3 in a
  5-player group).

## 5. Open points

| Point | How to settle it |
|---|---|
| Does Renew grant Borrowed Time on our realm? | In game: cast Renew, look for the haste buff |
| Which Halo version? | S1 had no clear winner; pick one per bot so bots differ |
| A Discord cross-check | James to paste a priest-style healer post if the channel has one |
