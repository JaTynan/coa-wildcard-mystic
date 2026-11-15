-- Third batch of medium legendaries (needs the build with this version of mystic-enchants-scripts.patch).
-- Time Warp (965245): Blink grants Time Distortion and marks your starting point for 3 sec; damaging cast-time spells
-- extend Time Distortion and cut Blink's cooldown; the taught Time Warp (1570042, 006 teaches it) returns you to the mark.
-- Snowblind (990055): teaches Ice Prism; Cone of Cold / Frostbolt spread it, Holy critical strikes shatter it.
-- Mending Tide (965309): Riptide heals put Mending Tides (944823) on one ally; its pulses heal nearby allies.
-- Temporal Shift (977972): teaches Temporal Blast; Temporal Haste charges, the fast Lunar Eclipse and its 45% bonus.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 965245),
('spell_proc', 990055),
('spell_proc', 965309),
('spell_proc', 977972);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (965245, 990055, 965309, 977972);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (965245, 1570042, 990055, 965309, 944823, 977972) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (965245, 990055, 965309, 977972);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(965245, 0, 0, 0, 0, 0, 81920, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(990055, 0, 0, 0, 0, 0, 65552, 1, 2, 0, 0, 0, 0, 100, 0, 0),
(965309, 0, 11, 0, 0, 16, 16384, 2, 2, 0, 0, 0, 0, 100, 0, 0),
(977972, 0, 0, 0, 0, 0, 65536, 0, 3, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(965245, 'spell_wcme_time_warp'),
(1570042, 'spell_wcme_time_warp_return'),
(990055, 'spell_wcme_snowblind'),
(965309, 'spell_wcme_mending_tide'),
(944823, 'spell_wcme_mending_tide_pulse'),
(977972, 'spell_wcme_temporal_shift');
DELETE FROM `wcme_enchant_teach` WHERE `enchant_spell` IN (990055, 977972);
INSERT INTO `wcme_enchant_teach` (`enchant_spell`, `taught_spell`, `comment`) VALUES
(990055, 990056, 'Snowblind: teaches Ice Prism'),
(977972, 930451, 'Temporal Shift: teaches Temporal Blast');
