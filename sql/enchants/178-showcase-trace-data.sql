-- Showcase talents traced on 28 Nov: four fixed with data only (no build). Each part says what was wrong and what
-- changes. Sources: our spell data (Spell.dbc), the core's rule table and scripts, and each spell's own tooltip.
--
-- Master of Shadows 275491 (Shadow Melee build). Crits with Sinister Strike, Gloomblade or Ambush give Apprentice of
-- Shadows (275494, 3 stacks); Rupture or Eviscerate at 3 stacks use them up for Master of Shadows (275495, more Shadow
-- damage) plus 10% Shadow crit (275502). The core's rule used the stacks but cast the talent's second trigger, 275497,
-- an internal helper spell, instead of 275495. And 275494's own proc gave 275495 on any Rupture or Eviscerate, at
-- any stack count. Now 275491's second trigger is 275495 (so both the core's rule and our rule for the other version,
-- file 170, cast it), 275494 has no proc of its own, and 275502 comes with 275495.
--
-- Stormborn 274078 (Enhancement). The core's rule needs Elemental Mastery or Shamanistic Rage active but names only
-- the stock buffs 16166 and 30823, so it never fired with the CoA versions. Rule 200 repeats it with every version of
-- both buffs. Its cone (274080) had no spell power or attack power scaling; the tooltip gives half of each.
-- Note: the core's list holds both CoA Stormstrike hits (1132175, 1132176) but only the stock main-hand hit (32175),
-- so with the CoA Stormstrike the cone may fire twice. Left as the core has it; check in the test.
--
-- Frost Bomb 271936 and ranks 2-8 271966-271972 (Cryomancer). The bomb never went off. The core's Living Bomb script
-- (spell_mage_living_bomb) does what the tooltip says: when the aura ends or is dispelled, the mage casts the spell
-- whose id is the aura's second effect value. Each rank's second effect (a placeholder) now holds that rank's own
-- explosion, the spell its first effect already names (271949, 271959-271965), and the script is bound to all 8.
-- The explosions had no spell power or attack power scaling; the tooltip gives 42.85% and 27.8%.
-- Assumption: the tooltip's damage number comes from the wave spell each explosion also casts on the bomb's target
-- (271950, 271952-271958), not from the explosion's own area damage, which is similar. The scaling is put on the area
-- explosion, as the tooltip says the damage hits nearby enemies; the target also takes the wave. Check in the test.
--
-- Hunting Frenzy 1180821 (Beast Master; buff from enchant 1180820 after Kill Command or a kill). The buff gives the
-- pet's next 2 special abilities +100% crit and no Focus cost. Its spell data has proc flags, so the core made a
-- proc entry for it, and an aura with a proc entry never loses spell-modifier charges on use. The 2 charges were
-- never used: 15 sec of free, critting pet abilities. Without the proc flags each pet ability uses one charge.
-- (The +10% pet damage against Hunter's Mark, 1180820's second effect, already works: the core reads that kind of aura
-- from a pet's owner.)
--
-- Plague Swarm 276431 and ranks 2-8 (Plague Caster). The disease had no spell power or attack power scaling; the
-- tooltip gives 7.5% and 4.88% per tick.
--
-- Data only: no build. Needs file 170's reset line for the WCME: rule, and the two reset lines this change adds to
-- 000-reset (owned spell_bonus_data rows, and the Living Bomb binding as an owned core script).
-- Safe to run again: 000-reset removes everything here first. Not tested in game: unverified until a player report or
-- an automated test.

-- Spell data: Master of Shadows' trigger, Apprentice and Hunting Frenzy without proc flags, Frost Bomb's explosion id.
CREATE TEMPORARY TABLE `wcme_new_spell` (`id` INT NOT NULL PRIMARY KEY);
INSERT INTO `wcme_new_spell` VALUES (275491), (275494), (1180821), (271936), (271966), (271967), (271968), (271969),
(271970), (271971), (271972);
DELETE FROM `wcme_new_spell` WHERE `id` IN (SELECT `ID` FROM `spell_dbc`);
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) SELECT 'spell_dbc', `id` FROM `wcme_new_spell`;
DROP TEMPORARY TABLE `wcme_new_spell`;
INSERT IGNORE INTO `spell_dbc` VALUES
(275491, 0, 0, 0, 2147484112, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 100, 0, 0, 0, 0, 21, 0, 0, 0, 0, 0, 1, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 1, 0.0, 0.0, 0.0, -1, -1, -1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 42, 42, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 275494, 275495, 0, 0.0, 0.0, 0.0, 2, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 26950, 0, 0, 'Master of Shadows', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0),
(275494, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 100, 0, 0, 0, 0, 31, 0, 0, 0, 0, 0, 1, 0.0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 0, 0.0, 0.0, 0.0, -1, -1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 4, 42, 174, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 32, 0, 0, 1, 0, 275495, 0, 0.0, 0.0, 0.0, 0, 0, 0, 1179648, 0, 0, 0, 0, 0, 0, 0, 2206, 0, 0, 'Apprentice of Shadows', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0),
(1180821, 0, 0, 0, 327696, 0, 0, 0, 0, 134217728, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 100, 2, 0, 1, 1, 8, 0, 0, 0, 0, 0, 13, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 6, 1, 1, 1, 0.0, 0.0, 0.0, 99, -1, -101, 0, 0, 0, 1, 5, 1, 0, 0, 0, 0, 0, 0, 107, 4, 108, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 7, 0, 14, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 268435456, 0, 0, 0, 0, 0, 268435456, 0, 0, 0, 2253, 0, 0, 'Hunting Frenzy', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 0, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0),
(271936, 3827, 1, 0, 67174400, 136, 0, 67108992, 0, 0, 33554432, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16, 14000, 14000, 15, 0, 0, 0, 101, 0, 18, 10, 10, 31, 0, 0, 0, 0, 0, 4, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 1, 0.0, 0.0, 0.0, -1, 271948, -1, 0, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0, 0, 4, 4, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 271949, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 123481, 0, 24984, 0, 50, 'Frost Bomb', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 'Rank 1', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 20, 133, 1500, 0, 3, 0, 0, 1073741824, 0, 1, 1, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0),
(271966, 3827, 1, 0, 67174400, 136, 0, 67108992, 0, 0, 33554432, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16, 14000, 14000, 15, 0, 0, 0, 101, 0, 28, 20, 20, 31, 0, 0, 0, 0, 0, 4, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 1, 0.0, 0.0, 0.0, -1, 271958, -1, 0, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0, 0, 4, 4, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 271959, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 123481, 0, 24984, 0, 50, 'Frost Bomb', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 'Rank 2', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 20, 133, 1500, 0, 3, 0, 0, 1073741824, 0, 1, 1, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0),
(271967, 3827, 1, 0, 67174400, 136, 0, 67108992, 0, 0, 33554432, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16, 14000, 14000, 15, 0, 0, 0, 101, 0, 38, 30, 30, 31, 0, 0, 0, 0, 0, 4, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 1, 0.0, 0.0, 0.0, -1, 271959, -1, 0, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0, 0, 4, 4, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 271960, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 123481, 0, 24984, 0, 50, 'Frost Bomb', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 'Rank 3', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 20, 133, 1500, 0, 3, 0, 0, 1073741824, 0, 1, 1, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0),
(271968, 3827, 1, 0, 67174400, 136, 0, 67108992, 0, 0, 33554432, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16, 14000, 14000, 15, 0, 0, 0, 101, 0, 48, 40, 40, 31, 0, 0, 0, 0, 0, 4, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 1, 0.0, 0.0, 0.0, -1, 271960, -1, 0, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0, 0, 4, 4, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 271961, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 123481, 0, 24984, 0, 50, 'Frost Bomb', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 'Rank 4', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 20, 133, 1500, 0, 3, 0, 0, 1073741824, 0, 1, 1, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0),
(271969, 3827, 1, 0, 67174400, 136, 0, 67108992, 0, 0, 33554432, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16, 14000, 14000, 15, 0, 0, 0, 101, 0, 58, 50, 50, 31, 0, 0, 0, 0, 0, 4, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 1, 0.0, 0.0, 0.0, -1, 271961, -1, 0, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0, 0, 4, 4, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 271962, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 123481, 0, 24984, 0, 50, 'Frost Bomb', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 'Rank 5', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 20, 133, 1500, 0, 3, 0, 0, 1073741824, 0, 1, 1, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0),
(271970, 3827, 1, 0, 67174400, 136, 0, 67108992, 0, 0, 33554432, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16, 14000, 14000, 15, 0, 0, 0, 101, 0, 68, 60, 60, 31, 0, 0, 0, 0, 0, 4, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 1, 0.0, 0.0, 0.0, -1, 271962, -1, 0, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0, 0, 4, 4, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 271963, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 123481, 0, 24984, 0, 50, 'Frost Bomb', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 'Rank 6', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 20, 133, 1500, 0, 3, 0, 0, 1073741824, 0, 1, 1, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0),
(271971, 3827, 1, 0, 67174400, 136, 0, 67108992, 0, 0, 33554432, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16, 14000, 14000, 15, 0, 0, 0, 101, 0, 78, 70, 70, 31, 0, 0, 0, 0, 0, 4, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 1, 0.0, 0.0, 0.0, -1, 271963, -1, 0, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0, 0, 4, 4, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 271964, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 123481, 0, 24984, 0, 50, 'Frost Bomb', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 'Rank 7', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 20, 133, 1500, 0, 3, 0, 0, 1073741824, 0, 1, 1, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0),
(271972, 3827, 1, 0, 67174400, 136, 0, 67108992, 0, 0, 33554432, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16, 14000, 14000, 15, 0, 0, 0, 101, 0, 0, 80, 80, 31, 0, 0, 0, 0, 0, 4, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 1, 0.0, 0.0, 0.0, -1, 271964, -1, 0, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0, 0, 4, 4, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 271965, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 123481, 0, 24984, 0, 50, 'Frost Bomb', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 'Rank 8', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 20, 133, 1500, 0, 3, 0, 0, 1073741824, 0, 1, 1, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0);

-- Master of Shadows: the 10% Shadow crit comes and goes with the buff.
DELETE FROM `spell_linked_spell` WHERE `spell_trigger` = 275495 AND `spell_effect` = 275502 AND `type` = 2;
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(275495, 275502, 2, 'WCME: Master of Shadows also gives its Shadow crit part');

-- Stormborn: the core's rule again, with every version of Elemental Mastery and Shamanistic Rage.
DELETE FROM `coa_mystic_enchant_proc` WHERE `enchant_spell` IN (274078) AND `comment` LIKE 'WCME:%';
INSERT INTO `coa_mystic_enchant_proc` (`enchant_spell`, `effect`, `rule`, `event`, `school_mask`, `spells`, `chance`, `cooldown_ms`, `requires_aura`, `target_aura`, `conditions`, `consume_aura`, `trigger_spells`, `amount_pct`, `chance_per_combo`, `comment`) VALUES
(274078, 0, 200, 'damage', 0, '17364 17373 17374 17375 17376 17377 17378 17379 32175 32539 32540 32541 32542 32543 32544 32545 254097 254098 254754 255923 277110 355290 901604 901605 965436 965695 997755 1117364 1132175 1132176 1217364 1232175 1232176 1578592 1578593 1578594', 100, 0, '16166 64701 1116166 1164701 1216166 1264701 30823 1130823 1230823', '', '', '', '', 0, 0, 'WCME: Stormborn: every version of Elemental Mastery and Shamanistic Rage (core rule 0/0 names the stock buffs only)');

-- Frost Bomb: the core's Living Bomb script on every rank.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('core_script', 271936), ('core_script', 271966), ('core_script', 271967), ('core_script', 271968),
('core_script', 271969), ('core_script', 271970), ('core_script', 271971), ('core_script', 271972);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (271936, 271966, 271967, 271968, 271969, 271970, 271971, 271972)
    AND `ScriptName` = 'spell_mage_living_bomb';
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(271936, 'spell_mage_living_bomb'), (271966, 'spell_mage_living_bomb'), (271967, 'spell_mage_living_bomb'),
(271968, 'spell_mage_living_bomb'), (271969, 'spell_mage_living_bomb'), (271970, 'spell_mage_living_bomb'),
(271971, 'spell_mage_living_bomb'), (271972, 'spell_mage_living_bomb');

-- Spell power and attack power scaling from the tooltips, only where the core has no row of its own.
CREATE TEMPORARY TABLE `wcme_new_bonus` (`entry` INT UNSIGNED NOT NULL PRIMARY KEY, `direct_bonus` FLOAT NOT NULL,
    `dot_bonus` FLOAT NOT NULL, `ap_bonus` FLOAT NOT NULL, `ap_dot_bonus` FLOAT NOT NULL, `comments` VARCHAR(255));
INSERT INTO `wcme_new_bonus` VALUES
(274080, 0.5, 0, 0.5, 0, 'WCME: Stormborn cone'),
(271949, 0.4285, 0, 0.278, 0, 'WCME: Frost Bomb explosion rank 1'),
(271959, 0.4285, 0, 0.278, 0, 'WCME: Frost Bomb explosion rank 2'),
(271960, 0.4285, 0, 0.278, 0, 'WCME: Frost Bomb explosion rank 3'),
(271961, 0.4285, 0, 0.278, 0, 'WCME: Frost Bomb explosion rank 4'),
(271962, 0.4285, 0, 0.278, 0, 'WCME: Frost Bomb explosion rank 5'),
(271963, 0.4285, 0, 0.278, 0, 'WCME: Frost Bomb explosion rank 6'),
(271964, 0.4285, 0, 0.278, 0, 'WCME: Frost Bomb explosion rank 7'),
(271965, 0.4285, 0, 0.278, 0, 'WCME: Frost Bomb explosion rank 8'),
(276431, 0, 0.075, 0, 0.0488, 'WCME: Plague Swarm rank 1'),
(276448, 0, 0.075, 0, 0.0488, 'WCME: Plague Swarm rank 2'),
(276449, 0, 0.075, 0, 0.0488, 'WCME: Plague Swarm rank 3'),
(276443, 0, 0.075, 0, 0.0488, 'WCME: Plague Swarm rank 4'),
(276444, 0, 0.075, 0, 0.0488, 'WCME: Plague Swarm rank 5'),
(276445, 0, 0.075, 0, 0.0488, 'WCME: Plague Swarm rank 6'),
(276446, 0, 0.075, 0, 0.0488, 'WCME: Plague Swarm rank 7'),
(276447, 0, 0.075, 0, 0.0488, 'WCME: Plague Swarm rank 8');
DELETE FROM `wcme_new_bonus` WHERE `entry` IN (SELECT `entry` FROM `spell_bonus_data`);
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) SELECT 'spell_bonus_data', `entry` FROM `wcme_new_bonus`;
INSERT IGNORE INTO `spell_bonus_data` SELECT * FROM `wcme_new_bonus`;
DROP TEMPORARY TABLE `wcme_new_bonus`;
