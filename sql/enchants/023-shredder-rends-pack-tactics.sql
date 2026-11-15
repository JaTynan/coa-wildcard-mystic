-- Spell Shredder's Elemental Rends and Beast and Blade's pet side (needs the build with this version of
-- mystic-enchants-scripts.patch). Rend applies the Frost, Fire and Nature Elemental Rend (978693/978694/978695) for each
-- active Shredder; their ticks add 10% of spell power and attack power. Pack Tactics (979038, on the pet) makes the
-- pet's special attacks give its owner 10 energy.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 979038);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (978693, 978694, 978695, 979038) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` = 979038;
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(979038, 0, 0, 0, 0, 0, 65552, 1, 2, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(978693, 'spell_wcme_elemental_rend'),
(978694, 'spell_wcme_elemental_rend'),
(978695, 'spell_wcme_elemental_rend'),
(979038, 'spell_wcme_pack_tactics');
