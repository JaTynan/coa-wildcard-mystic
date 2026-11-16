-- The known gaps in legendaries fixed before (needs the build with this version of mystic-enchants-scripts.patch and
-- patches/68-aspect-of-the-fox-auto-shot.ps1; no client patch change).
-- Demonic Persistence (990130): its Wild Imps carry the pet aura 990131; their critical strikes take 1 sec off Hand of
-- Gul'dan and restore 3% of your demon's mana, once a second.
-- Elemental Assassin (978229): Shocks grant the Elemental Blade of their element (978644 / 978646 / 978648), each with
-- its Backstab-from-any-side helper; Backstab and Stormstrike bonuses, the all-three burst, Reverberation +40 and
-- Booming Echoes +10 are in the scripts.
-- Demonic Reoccurence (1570995): Metamorphosis no longer lowers critical hit chance taken or stun / snare duration.
-- Temporal Shift's Stored Time (9990018) only shortens Temporal Blast now (it also hit Arcane Blast, which shares the
-- flag); Hot Hands' Hot Streak Pyroblast +35% against monsters; Aspect of the Fox's Auto Shot while moving (patch 68).
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 990131);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (990131, 978644, 978646, 978648, 1570995) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` = 990131;
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(990131, 0, 0, 0, 0, 0, 65812, 1, 2, 2, 0, 0, 0, 100, 1000, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(990131, 'spell_wcme_demonic_persistence_imp'),
(978644, 'spell_wcme_elemental_blade'),
(978646, 'spell_wcme_elemental_blade'),
(978648, 'spell_wcme_elemental_blade'),
(1570995, 'spell_wcme_demonic_reoccurence');
