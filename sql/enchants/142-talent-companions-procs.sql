-- Talent companions, batch 2: companions that fire on an event (scan: enchants/talent-companions.csv).
-- Same pattern as batch 1 (141-talent-companions.sql): each talent rank applies its hidden companion with an aura
-- link. These companions also need to fire, and Ascension kept their trigger rules in its own database, so each
-- gets a spell_proc row here. Where the companion fires an Ascension-only effect (cooldown cuts use effect types
-- 165 and 197, which this core does not have), or must fire for exact spells only, the action table does the work
-- instead (spell_wcme_enchant_action, in every build since build6; recipe R6). On a match the script stops the
-- companion's own effect, and without one nothing fires, so the Ascension-only effect never runs.
-- Data only: no build. Needs a server start. Safe to run again (000-reset removes WCME: links, owned spell_proc and
-- spell_dbc rows, every action rule and every spell_wcme_ binding). Each pair read by hand on 24 Nov 2026.
-- Not tested in game: James's testing policy, so these stay unverified until a player report or an automated test.
--
-- Every spell_proc row below sets Chance 100: a row with 0 falls back to the spell's own chance, which would roll
-- twice with the action rule (Deflection rank 1 would be 33% of 33%).
--
-- What each does (chances and amounts from the tooltips; the data agrees):
--   Impact (3 ranks): casting Meteor has 33 / 66 / 100% to make the next Fire Blast stun (64343, the core's own Impact
--     buff). On cast, because Meteor 760040 summons the meteor and its damage comes from another spell.
--   Missile Barrage (3 ranks): Fire or Frost direct damage has 7 / 14 / 20%, and Align 14 / 28 / 40%, to grant Missile
--     Barrage (44401, the core's own buff). Arcane spells keep the core's own Missile Barrage rule. Align is a Druid
--     spell, listed by id so no other Druid spell sets it off.
--   Deflection (3 ranks): using Riposte has 33 / 66 / 100% to take 3 sec off Ghostly Strike.
--   Stalker of the Frozen Wastes: ranged Hunter abilities have 40% to take 8 sec off Frozen Orb.
--   Fatal Vanguard: +35% critical strike chance and damage on Execute (the companion), and a critical Execute takes
--     2 sec off Concussion Blow. The talent only exists in Defensive Stance (its own stance requirement), so both do too,
--     matching the companion's name ("for def stance").
--   Blurred Blade: while the finishing move's buff is up, a parry strikes back at once (277046, 150% weapon damage) and
--     damage taken is 4% lower. The buff itself needs a one-handed weapon.
--   Endless Agony: Curse of Agony builds up 25% more and benefits from haste (plain modifiers; the talent's own proc
--     that applies Endless Agony is already in 015-runaway-procs.sql).
--   Talonshrike: Raptor Strike, Counterattack and Mongoose Bite deal 30% more. The companion's modifier uses type 38,
--     outside the core's range (the core ignores it), so our copy uses plain damage (type 0). Its cooldown cut on Fury
--     of the Eagle is already in 007-enchant-actions.sql.

INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(11103, 12359, 2, 'WCME: Impact rank 1 applies its Meteor companion'),
(12357, 812355, 2, 'WCME: Impact rank 2 applies its Meteor companion'),
(12358, 812356, 2, 'WCME: Impact rank 3 applies its Meteor companion'),
(44404, 854480, 2, 'WCME: Missile Barrage rank 1 applies its Fire and Frost companion'),
(44404, 854492, 2, 'WCME: Missile Barrage rank 1 applies its Align companion'),
(54486, 854481, 2, 'WCME: Missile Barrage rank 2 applies its Fire and Frost companion'),
(54486, 854493, 2, 'WCME: Missile Barrage rank 2 applies its Align companion'),
(54488, 854482, 2, 'WCME: Missile Barrage rank 3 applies its Fire and Frost companion'),
(54488, 854494, 2, 'WCME: Missile Barrage rank 3 applies its Align companion'),
(13713, 965835, 2, 'WCME: Deflection rank 1 applies its Riposte companion'),
(13853, 965836, 2, 'WCME: Deflection rank 2 applies its Riposte companion'),
(13854, 965837, 2, 'WCME: Deflection rank 3 applies its Riposte companion'),
(277490, 277489, 2, 'WCME: Stalker of the Frozen Wastes applies its ranged-ability companion'),
(277020, 277043, 2, 'WCME: Blurred Blade (while active) applies its parry follow-up and damage-taken companion'),
(272691, 272699, 2, 'WCME: Endless Agony applies its Curse of Agony build-up and haste companion'),
(277990, 277991, 2, 'WCME: Fatal Vanguard applies its Execute critical strike companion'),
(277790, 277791, 2, 'WCME: Talonshrike applies its Raptor Strike, Counterattack and Mongoose Bite damage companion');

-- Cast rules (the rows with phase 1, "on cast"): proc flags 87312, every "spell done" kind, as in 016 and 020.
-- (Fixed 24 Nov after review on #263: these first had 104720, which holds the helpful-spell TAKEN bits instead of
-- DONE, so a helpful trigger such as Align or a Meteor summon never fired the rule.)
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES ('spell_proc', 12359), ('spell_proc', 812355), ('spell_proc', 812356), ('spell_proc', 854480), ('spell_proc', 854481), ('spell_proc', 854482), ('spell_proc', 854492), ('spell_proc', 854493), ('spell_proc', 854494), ('spell_proc', 965835), ('spell_proc', 965836), ('spell_proc', 965837), ('spell_proc', 277489), ('spell_proc', 277990), ('spell_proc', 277043), ('spell_dbc', 277791);
DELETE FROM `spell_proc` WHERE `SpellId` IN (12359, 812355, 812356, 854480, 854481, 854482, 854492, 854493, 854494, 965835, 965836, 965837, 277489, 277990, 277043);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(12359, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(812355, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(812356, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(854480, 0, 0, 0, 0, 0, 69904, 1, 2, 0, 0, 0, 0, 100, 0, 0),
(854481, 0, 0, 0, 0, 0, 69904, 1, 2, 0, 0, 0, 0, 100, 0, 0),
(854482, 0, 0, 0, 0, 0, 69904, 1, 2, 0, 0, 0, 0, 100, 0, 0),
(854492, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(854493, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(854494, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(965835, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(965836, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(965837, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(277489, 0, 9, 0, 0, 0, 256, 1, 2, 0, 0, 0, 0, 100, 0, 0),
(277990, 0, 0, 0, 0, 0, 16, 1, 2, 2, 0, 0, 0, 100, 0, 0),
(277043, 0, 0, 0, 0, 0, 40, 0, 2, 32, 0, 0, 0, 100, 0, 0);

INSERT INTO `wcme_enchant_action` (`enchant_spell`, `rule`, `spells`, `school_mask`, `target_aura`, `requires_aura`, `chance`, `cooldown_ms`, `action`, `action_spells`, `amount`, `comment`) VALUES
(12359, 0, '101466 101469 500135 760040 760042 760156 760157 760158 760159 760160 760161 760168 760169 760170 760171 760172 760173 993009 993012 1760040 1760042 1760157 1760158 1760159 1760160 1760161 1760168 1760169 1760170 1760171 1760172 1760173 2110040 2110042 2110156 2110157 2110158 2110159 2110160 2110161 2110168 2110169 2110170 2110171 2110172 2110173', 0, '', '', 33, 0, 'cast_self', '64343', 0, 'Impact rank 1: casting Meteor has a 33% chance to make the next Fire Blast stun'),
(812355, 0, '101466 101469 500135 760040 760042 760156 760157 760158 760159 760160 760161 760168 760169 760170 760171 760172 760173 993009 993012 1760040 1760042 1760157 1760158 1760159 1760160 1760161 1760168 1760169 1760170 1760171 1760172 1760173 2110040 2110042 2110156 2110157 2110158 2110159 2110160 2110161 2110168 2110169 2110170 2110171 2110172 2110173', 0, '', '', 66, 0, 'cast_self', '64343', 0, 'Impact rank 2: casting Meteor has a 66% chance to make the next Fire Blast stun'),
(812356, 0, '101466 101469 500135 760040 760042 760156 760157 760158 760159 760160 760161 760168 760169 760170 760171 760172 760173 993009 993012 1760040 1760042 1760157 1760158 1760159 1760160 1760161 1760168 1760169 1760170 1760171 1760172 1760173 2110040 2110042 2110156 2110157 2110158 2110159 2110160 2110161 2110168 2110169 2110170 2110171 2110172 2110173', 0, '', '', 100, 0, 'cast_self', '64343', 0, 'Impact rank 3: casting Meteor has a 100% chance to make the next Fire Blast stun'),
(854480, 0, '', 20, '', '', 7, 0, 'cast_self', '44401', 0, 'Missile Barrage rank 1: Fire or Frost direct damage has a 7% chance to grant Missile Barrage'),
(854481, 0, '', 20, '', '', 14, 0, 'cast_self', '44401', 0, 'Missile Barrage rank 2: Fire or Frost direct damage has a 14% chance to grant Missile Barrage'),
(854482, 0, '', 20, '', '', 20, 0, 'cast_self', '44401', 0, 'Missile Barrage rank 3: Fire or Frost direct damage has a 20% chance to grant Missile Barrage'),
(854492, 0, '276343 986160 986163 1122343 1576837', 0, '', '', 14, 0, 'cast_self', '44401', 0, 'Missile Barrage rank 1: Align has a 14% chance to grant Missile Barrage'),
(854493, 0, '276343 986160 986163 1122343 1576837', 0, '', '', 28, 0, 'cast_self', '44401', 0, 'Missile Barrage rank 2: Align has a 28% chance to grant Missile Barrage'),
(854494, 0, '276343 986160 986163 1122343 1576837', 0, '', '', 40, 0, 'cast_self', '44401', 0, 'Missile Barrage rank 3: Align has a 40% chance to grant Missile Barrage'),
(965835, 0, '14251 34097 34099 41392 41393 1114251 1134097 1134099 1141392 1141393 1214251 1398240 1464251', 0, '', '', 33, 0, 'reduce_cooldown', '14278 865819 965819 980664 982165 1114278 1214278 1398241 1464278', 3000, 'Deflection rank 1: Riposte has a 33% chance to take 3 sec off Ghostly Strike'),
(965836, 0, '14251 34097 34099 41392 41393 1114251 1134097 1134099 1141392 1141393 1214251 1398240 1464251', 0, '', '', 66, 0, 'reduce_cooldown', '14278 865819 965819 980664 982165 1114278 1214278 1398241 1464278', 3000, 'Deflection rank 2: Riposte has a 66% chance to take 3 sec off Ghostly Strike'),
(965837, 0, '14251 34097 34099 41392 41393 1114251 1134097 1134099 1141392 1141393 1214251 1398240 1464251', 0, '', '', 100, 0, 'reduce_cooldown', '14278 865819 965819 980664 982165 1114278 1214278 1398241 1464278', 3000, 'Deflection rank 3: Riposte has a 100% chance to take 3 sec off Ghostly Strike'),
(277489, 0, '', 0, '', '', 40, 0, 'reduce_cooldown', '355511 760014 760016 760019 760020 760021 760022 760023 760024 760025 760026 760027 760028 760029 760030 760031 760032 2110014 2110016 2110019 2110020 2110021 2110022 2110023 2110024 2110025 2110026 2110027 2110028 2110029 2110030 2110031 2110032', 8000, 'Stalker of the Frozen Wastes: ranged Hunter abilities have a 40% chance to take 8 sec off Frozen Orb'),
(277990, 0, '5308 5309 20647 20658 20660 20661 20662 25234 25236 26651 47470 47471 982156 1105308 1120647 1120658 1120660 1120661 1120662 1125234 1125236 1147470 1147471', 0, '', '', 100, 0, 'reduce_cooldown', '12809 22427 32588 52719 340039 982176 1112809 1122427 1132588 1152719 1212809 273955', 2000, 'Fatal Vanguard: a critical Execute takes 2 sec off Concussion Blow (and Stormhammer, which shares its class flag)');

INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(12359, 'spell_wcme_enchant_action'),
(812355, 'spell_wcme_enchant_action'),
(812356, 'spell_wcme_enchant_action'),
(854480, 'spell_wcme_enchant_action'),
(854481, 'spell_wcme_enchant_action'),
(854482, 'spell_wcme_enchant_action'),
(854492, 'spell_wcme_enchant_action'),
(854493, 'spell_wcme_enchant_action'),
(854494, 'spell_wcme_enchant_action'),
(965835, 'spell_wcme_enchant_action'),
(965836, 'spell_wcme_enchant_action'),
(965837, 'spell_wcme_enchant_action'),
(277489, 'spell_wcme_enchant_action'),
(277990, 'spell_wcme_enchant_action');

DELETE FROM `spell_dbc` WHERE `ID` IN (277791);
INSERT INTO `spell_dbc` VALUES
(277791, 0, 0, 0, 448, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0.0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 1378, 0, 6, 6, 0, 1, 1, 1, 0.0, 0.0, 0.0, 29, -1, -1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 108, 42, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 277795, 0, 0.0, 0.0, 0.0, 2, 524288, 65536, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 'Talonshrike', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 0, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0);

-- Held back from this batch (later batches, by type):
--   Needs code: Battle Fatigue (extends a debuff's duration: effect 173), Beacon of Virtue (heal copying), Divine Reset
--   (a Divine Storm reset that must come with its damage buff in one roll), Flare Strike and Tidecaller's Boon
--   (class-script overrides no code implements), Holy Concentration (extends Renew), Pack Leader (cuts Spirit Wolf
--   healing).
--   Outlier: One With The Light (its companion fires 275371, which is not in the game data at all; linking it would
--   log an error every second).
--   Active ability (batch 5): Jagged Reinforcement (a shield enchant, no aura to link from).
