-- What the first three custom Mystic Enchant cards do (the cards themselves: file 184, client-patch/custom_cards.py).
-- All three are Ascension talents (Echoing Warcry already had a card nobody could roll) whose effect is in the spell
-- data but never fired here. Data only, but the cards need the build with LoadExtraCards (mystic-enchants-wildcard.patch)
-- to be offered; the effects below also work on anyone given the aura with .aura.
-- Sources: our spell data (Spell.dbc) and each spell's own tooltip. Not tested in game: unverified until tested.
--
-- Echoing Warcry 1571194 (Epic). Warrior shouts generate 10 rage, and Physical melee abilities on an enemy carrying
-- your Battle Fatigue (272848) cut 5 sec off Warcry, at most once every 2 sec. The spell's first effect (the Warcry cut)
-- had no proc rule and its "10 rage" was only text, so nothing happened. Now the action table does both: rule 1 casts
-- Ascension's own helper Echoing Warcry Rage (272856, 10 rage) on any shout; rule 2 cuts every Warcry (272851, 1571219,
-- 8006673) by 5 sec. Its second effect (shouts cost no rage) already worked and stays.
-- Assumptions: the tooltip's 2 sec against players is not done (the table can't tell a player target); 5 sec always.
-- Battle Fatigue comes from other enchants (Warcry and the like), so without one of those only the rage part works.
--
-- Assault and Battery 275043 (Epic). Thunder Clap, Execute and Shield Slam grant Assault and Battery (275044): the next
-- Lightning Bolt or Chain Lightning is instant, and Lightning Bolt deals 100% more. The talent had no proc rule (so it
-- never fired), and the buff's damage part used an Ascension modifier this core does not have (38). Now a proc rule
-- names the three abilities by their warrior class flags (Thunder Clap 0x80, Execute 0x20000000, Shield Slam 0x200 in
-- the second set), and the damage part is an ordinary damage modifier. The 25% against players is left out.
--
-- Corrupted Maelstrom Weapon 1576284 (Epic). Melee abilities grant a stack of Corrupted Maelstrom Weapon (1576264, up
-- to 3, 15 sec); the next Chaos Bolt, Chaos Burn, Chaos Meteor or Pure Chaos Bolt uses it for 50% more direct damage
-- per stack, and Pure Chaos Bolt also casts 34% faster per stack. Before: auto attacks also gave stacks, any spell of
-- yours used the buff up, and the buff's modifiers named no spell (Ascension listed only Chaos Meteor, and its damage
-- modifier was one this core does not have). Now only melee abilities give stacks; only a hit by one of the four uses
-- it; the damage part is an ordinary damage modifier on all four (their shared warlock flag, 0x20000 in the second set);
-- the cast time part names Pure Chaos Bolt's 13 versions (wcme_spellaffect_dbc 960100-960112). The 10% against players
-- is left out.
-- Assumption: at 3 stacks Pure Chaos Bolt casts instantly (3 x 34%), as Maelstrom Weapon does at full stacks.
--
-- Safe to run again: 000-reset removes everything here first.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES ('spell_dbc', 275044), ('spell_dbc', 1576264),
    ('spell_proc', 1571194), ('spell_proc', 275043), ('spell_proc', 1576284), ('spell_proc', 1576264);
DELETE FROM `spell_dbc` WHERE `ID` IN (275044, 1576264);
INSERT INTO `spell_dbc` VALUES
(275044, 0, 0, 0, 0, 0, 1073741824, 67109376, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 100, 1, 0, 0, 0, 31, 0, 0, 0, 0, 0, 13, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 0, 0.0, 0.0, 0.0, -101, 99, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 108, 108, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 3, 0, 0, 1, 4, 0, 1, 4, 0, 0, 0, 27341, 0, 0, 'Assault and Battery', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 0, 0, 0, 0, 11, 0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 1.0, 0.0, 0.0, 0, 0),
(1576264, 0, 1, 0, 0, 0, 0, 67108864, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 46917, 0, 1, 0, 0, 0, 0, 0, 81920, 100, 1, 0, 0, 0, 8, 0, 0, 0, 0, 0, 1, 0.0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 0, 0.0, 0.0, 0.0, 49, -35, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 108, 108, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 131072, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4819, 0, 0, 'Corrupted Maelstrom Weapon', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 0, 0, 0, 0, 5, 0, 0, 0, 0, 1, 0, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0);
DELETE FROM `spell_proc` WHERE `SpellId` IN (1571194, 275043, 1576284, 1576264);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`,
    `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`,
    `Chance`, `Cooldown`, `Charges`) VALUES
-- Echoing Warcry: melee-class abilities and class-less ones (Execute, the shouts), when cast; the rules pick.
(1571194, 0, 0, 0, 0, 0, 5136, 7, 1, 0, 0, 0, 0, 100, 0, 0),
-- Assault and Battery: a hit by Thunder Clap, Execute or Shield Slam (their damage classes: ranged, none, melee).
(275043, 0, 4, 536871040, 512, 0, 69904, 1, 2, 0, 0, 0, 0, 100, 0, 0),
-- Corrupted Maelstrom Weapon: a hit by a melee-class ability (not an auto attack).
(1576284, 0, 0, 0, 0, 0, 16, 1, 2, 0, 0, 0, 0, 100, 0, 0),
-- its buff: used up by a hit with one of the four warlock spells.
(1576264, 0, 5, 0, 131072, 0, 65536, 1, 2, 0, 0, 0, 0, 100, 0, 0);
DELETE FROM `spell_script_names` WHERE `spell_id` = 1571194 AND `ScriptName` = 'spell_wcme_enchant_action';
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES (1571194, 'spell_wcme_enchant_action');
INSERT INTO `wcme_enchant_action` (`enchant_spell`, `rule`, `spells`, `school_mask`, `target_aura`, `requires_aura`, `chance`,
    `cooldown_ms`, `action`, `action_spells`, `amount`, `comment`) VALUES
(1571194, 1, '469 1160 1161 2048 5242 5246 6190 6192 6673 11549 11550 11551 11554 11555 11556 13730 16244 18328 19134 19778 20511 25202 25203 25289 27578 27579 29544 29584 33789 38945 38946 45517 47436 47437 47439 47440 59613 61044 61578 62102 65930 69565 84277 102929 102930 155799 161203 340006 340076 365104 383150 388554 992971 1100469 1101160 1101161 1102048 1105242 1105246 1106190 1106192 1106673 1111549 1111550 1111551 1111554 1111555 1111556 1113730 1116244 1118328 1119134 1119778 1120511 1123511 1125202 1125203 1125289 1127578 1127579 1129544 1129584 1133789 1138945 1138946 1145517 1147436 1147437 1147439 1147440 1159613 1161044 1161578 1162102 1165930 1169565 1405742 1405746 1406692 1407173 6072022 10013730', 0, '', '', 100, 0, 'cast_self', '272856', 0, 'Echoing Warcry: a shout generates 10 rage'),
(1571194, 2, '', 1, '272848', '', 100, 2000, 'reduce_cooldown', '272851 1571219 8006673', 5000,
    'Echoing Warcry: a Physical ability on a Battle Fatigued enemy cuts 5 sec off Warcry');
INSERT INTO `wcme_spellaffect_dbc` (`ID`, `ModifierSpellID`, `AffectedSpellID`) VALUES
(960100, 1576264, 272774),
(960101, 1576264, 272777),
(960102, 1576264, 272778),
(960103, 1576264, 272779),
(960104, 1576264, 300601),
(960105, 1576264, 944811),
(960106, 1576264, 944812),
(960107, 1576264, 944813),
(960108, 1576264, 944814),
(960109, 1576264, 1571080),
(960110, 1576264, 1571082),
(960111, 1576264, 1571083),
(960112, 1576264, 1571084);
