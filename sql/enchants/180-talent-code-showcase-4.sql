-- Data half of patch 55's showcase batch 4 (patches/55-talent-fixes.ps1): Preservation 276273 (Prayer of Preservation
-- build). Prayer of Preservation's heals give injured allies Preservation (276259, 10 sec); your heals crit them 20%
-- more often, and your next direct heal on one uses it up: 3 other allies near it are healed (276258), it gets Shield
-- of Preservation (276257, less area damage for 3 sec) and Prayer of Preservation's cooldown drops by 3 sec.
-- Spell data (an owned spell_dbc copy, description text blanked):
--   276259: its first effect, a placeholder, becomes the core's "crit chance for this caster" aura (308) at its own
--   20%; a second effect, a placeholder on the same ally, is added for the script's proc to run on (the core runs proc
--   scripts only on effects that can proc, and 308 is not one).
--   276258, the extra heal, keeps its own spell data (12 to 35, plus 3.094 per level, plus 20.1% of bonus healing);
--   James, 28 Nov 2026: go with the spell data. Its tooltip is changed to match in the client patch (spell_texts.py).
-- 276259's proc row: heals it takes (direct only, no ticks), one charge; the script checks they are yours.
-- Needs the build with this version of patches/55-talent-fixes.ps1. Before it nothing gives 276259, so these rows do
-- nothing; the server names the scripts it lacks in its startup log.
-- Safe to run again: 000-reset removes the owned spell_dbc and spell_proc rows and every spell_wcme_ binding.
-- Not tested in game: unverified until a player report or an automated test.
CREATE TEMPORARY TABLE `wcme_new_spell` (`id` INT NOT NULL PRIMARY KEY);
INSERT INTO `wcme_new_spell` VALUES (276259);
DELETE FROM `wcme_new_spell` WHERE `id` IN (SELECT `ID` FROM `spell_dbc`);
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) SELECT 'spell_dbc', `id` FROM `wcme_new_spell`;
DROP TEMPORARY TABLE `wcme_new_spell`;
INSERT IGNORE INTO `spell_dbc` VALUES
(276259, 0, 0, 0, 0, 32, 0, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 100, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 13, 0.0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 1, 0.0, 0.0, 0.0, 19, -21, -1, 0, 0, 0, 21, 21, 0, 0, 0, 0, 0, 0, 0, 308, 4, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 126, 0, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 512, 0, 0, 0, 0, 0, 0, 0, 5690, 0, 0, 'Preservation', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0);

INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 276259);
DELETE FROM `spell_proc` WHERE `SpellId` IN (276259);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(276259, 0, 0, 0, 0, 0, 34816, 2, 2, 0, 0, 0, 0, 100, 0, 1);

INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(276261, 'spell_wcme_preservation_grant'), (276262, 'spell_wcme_preservation_grant'), (276263, 'spell_wcme_preservation_grant'),
(276264, 'spell_wcme_preservation_grant'), (276265, 'spell_wcme_preservation_grant'), (276266, 'spell_wcme_preservation_grant'),
(276267, 'spell_wcme_preservation_grant'),
(888581, 'spell_wcme_preservation_grant'), (888582, 'spell_wcme_preservation_grant'), (888583, 'spell_wcme_preservation_grant'),
(888584, 'spell_wcme_preservation_grant'), (888585, 'spell_wcme_preservation_grant'), (888586, 'spell_wcme_preservation_grant'),
(888587, 'spell_wcme_preservation_grant'),
(1576676, 'spell_wcme_preservation_grant'), (1576677, 'spell_wcme_preservation_grant'), (1576678, 'spell_wcme_preservation_grant'),
(1576679, 'spell_wcme_preservation_grant'), (1576680, 'spell_wcme_preservation_grant'), (1576681, 'spell_wcme_preservation_grant'),
(1576682, 'spell_wcme_preservation_grant'),
(276259, 'spell_wcme_preservation');
