-- Gurubashi Berserker's Onslaught and Elemental Lord's Elemental Air (needs the build with this version of
-- mystic-enchants-scripts.patch). Colossus Smash grants Onslaught (984415: 3 charges, Execute at any target health);
-- like Sudden Death (52437) a charge goes as each Execute finishes. Elemental Lord puts Elemental Air's watcher (990208)
-- on your tethered elemental: its critical strikes, melee or abilities, give you Elemental Air.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 984415),
('spell_proc', 990208);
DELETE FROM `spell_script_names` WHERE `spell_id` = 990208 AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (984415, 990208);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(984415, 1, 4, 536870912, 0, 0, 16, 0, 4, 0, 0, 0, 0, 0, 0, 0),
(990208, 0, 0, 0, 0, 0, 65556, 1, 2, 2, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(990208, 'spell_wcme_elemental_air_watch');
