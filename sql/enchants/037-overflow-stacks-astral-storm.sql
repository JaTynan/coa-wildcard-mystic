-- Overflow (enchant 1571951): its stacks (1571954) are spent by the next Healing Touch for Living Seed and extra ally
-- heals. Astral Storm (832617): only Astral Storm hits proc (mana from monsters, the Astral Realm against a player with
-- your Unrelenting Storm) instead of every damaging spell. Needs the build with this version of
-- mystic-enchants-scripts.patch.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 1571954),
('spell_proc', 832617);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (1571954, 832617) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (1571954, 832617);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(1571954, 0, 0, 0, 0, 0, 16384, 2, 2, 0, 0, 0, 0, 100, 0, 0),
(832617, 0, 0, 0, 0, 0, 65536, 1, 2, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(1571954, 'spell_wcme_overflow_stacks'),
(832617, 'spell_wcme_astral_storm');
