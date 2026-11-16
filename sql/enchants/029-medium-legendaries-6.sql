-- Medium legendaries, batch 6 (needs the build with this version of mystic-enchants-scripts.patch).
-- Growing Light (81520): Holy Light and Flash of Light on your Beacon target radiate, extend the Beacon and build
-- Growing Light, which strengthens Beacon heals.
-- Soul Harvest (1436395, from 1398159): duration from your afflicted enemies, and the bonus for your pet.
-- Void Eruption (2110122, from 1398184): Shadow Word: Pain on up to 10 nearby enemies.
-- Bloodbath (2304814, from 1398215): melee abilities apply its bleed and slow.
-- Demolisher (977864): its own design instead of twin 273786 (003 no longer links them).
-- Blood and Guts (977906): Mutilating Disembowel, Disembowel consumed by Execute, Remorseless only if known.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 81520),
('spell_proc', 2304814),
('spell_proc', 977864),
('spell_proc', 977906);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (81520, 977864, 977906);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (81520, 1436395, 2110122, 2304814, 977864, 977906) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (81520, 2304814, 977864, 977906);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(81520, 0, 0, 0, 0, 0, 16384, 0, 2, 0, 2, 0, 0, 100, 0, 0),
(2304814, 0, 0, 0, 0, 0, 16, 0, 2, 0, 0, 0, 0, 100, 0, 0),
(977864, 0, 0, 0, 0, 0, 20, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(977906, 0, 0, 0, 0, 0, 16, 0, 2, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(81520, 'spell_wcme_growing_light'),
(1436395, 'spell_wcme_soul_harvest'),
(2110122, 'spell_wcme_void_eruption'),
(2304814, 'spell_wcme_bloodbath'),
(977864, 'spell_wcme_demolisher'),
(977906, 'spell_wcme_blood_and_guts');
