-- Lava Sweep (417700): teaches Lava Sweep while you know Lava Lash, Flametongue bonus, Eruption and the Pyroblast
-- payoff; Flame Shock's Doomhammer's Fury moves from its action row (007) into the script (needs the build with this
-- version of mystic-enchants-scripts.patch). Doomhammer's Fury's own proc (015) is unchanged.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 417700);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` = 417700;
DELETE FROM `spell_script_names` WHERE `spell_id` = 417700 AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` = 417700;
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(417700, 0, 0, 0, 0, 0, 65552, 0, 3, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(417700, 'spell_wcme_lava_sweep');
