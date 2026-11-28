-- Heavyweight 273378 (talent and Epic enchant; Titan's Grip Crush build), with patch 55's showcase batch 5.
-- The core's rule gives a stack of Heavyweight (273379) for each Slam, Overpower or Execute, but the stack buff was a
-- placeholder. The owned copy gives each stack 3% slower swings (its own value, now the melee haste aura) and 4% more
-- Physical damage. The 4% is an assumption: the tooltip names a second value that its data lacks, and the older
-- version of this buff (977701), with the same text and the same 3% slowdown, gives 4%. Up to 6 stacks, 10 sec.
-- With the build: Overpower and Execute give 2 stacks, Heroic Strike removes them (James, 28 Nov; auto attacks do
-- not), reaching 6 stacks gives Ready to Strike (273381), and Thunder Clap with it casts the aftershock (273384).
-- Ready to Strike's proc row gives it one charge, used by the next Mortal Strike (its damage and crit modifiers name
-- Mortal Strike's class flag); Thunder Clap uses it up in the script.
-- The stack buff's effects work without the build; the rest needs the build with this version of
-- patches/55-talent-fixes.ps1 (the server names the script it lacks in its startup log until then).
-- Safe to run again: 000-reset removes the owned spell_dbc and spell_proc rows and every spell_wcme_ binding.
-- Not tested in game: unverified until a player report or an automated test.
CREATE TEMPORARY TABLE `wcme_new_spell` (`id` INT NOT NULL PRIMARY KEY);
INSERT INTO `wcme_new_spell` VALUES (273379);
DELETE FROM `wcme_new_spell` WHERE `id` IN (SELECT `ID` FROM `spell_dbc`);
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) SELECT 'spell_dbc', `id` FROM `wcme_new_spell`;
DROP TEMPORARY TABLE `wcme_new_spell`;
INSERT IGNORE INTO `spell_dbc` VALUES
(273379, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 100, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0.0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 0, 0.0, 0.0, 0.0, -4, 3, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 138, 79, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5277, 0, 0, 'Heavyweight', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 1.0, 0, 0);

INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 273381);
DELETE FROM `spell_proc` WHERE `SpellId` IN (273381);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(273381, 0, 4, 33554432, 0, 0, 16, 0, 1, 0, 8, 0, 0, 0, 0, 1);

INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(273379, 'spell_wcme_heavyweight_stacks');
