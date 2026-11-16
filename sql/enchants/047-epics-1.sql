-- Epic enchants, batch 1: low-effort fixes (needs the build with this version of mystic-enchants-scripts.patch; no
-- client patch change). Most of these are hooks in wcme_epic_batch1_hooks and need no rows here:
-- Flash of Adrenaline (84453, 282309), Blinding Dispersion (283428, 954634), Do The Stance Dance (81216), Spectre
-- (81186), Pestilent Opportunist (81188), Down For The Count (81263, 281649), Duck Hunting (81110), Freedom by Death
-- (954128, 283360), Group Think (81453, 282009, 1581626), Elemental Torrent (1180420).
-- With rows: Dancer in the Dark (81521, 282118: Shadow Dance recovers twice as fast in Stealth), Soul Restoration
-- (84381, 282213, 1181290: heals shorten Weakened Soul), Swift Shadows (272814: Shadowstep reset from a Shadow Marked
-- target).
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 84381),
('spell_proc', 282213),
('spell_proc', 1181290),
('spell_proc', 272814);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (81521, 282118, 84381, 282213, 1181290, 272814);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (81521, 282118, 84381, 282213, 1181290, 272814) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (84381, 282213, 1181290, 272814);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(84381, 0, 0, 0, 0, 0, 16384, 2, 2, 0, 0, 0, 0, 100, 0, 0),
(282213, 0, 0, 0, 0, 0, 16384, 2, 2, 0, 0, 0, 0, 100, 0, 0),
(1181290, 0, 0, 0, 0, 0, 16384, 2, 2, 0, 0, 0, 0, 100, 0, 0),
(272814, 0, 0, 0, 0, 0, 272, 1, 2, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(81521, 'spell_wcme_dancer_in_the_dark'),
(282118, 'spell_wcme_dancer_in_the_dark'),
(84381, 'spell_wcme_soul_restoration'),
(282213, 'spell_wcme_soul_restoration'),
(1181290, 'spell_wcme_soul_restoration'),
(272814, 'spell_wcme_swift_shadows');
