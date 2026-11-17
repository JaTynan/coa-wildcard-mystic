-- Epic enchants, batch 3 and the held-back epics (needs the build with this version of mystic-enchants-scripts.patch
-- and patches/69-iron-guard-block.ps1; no client patch change).
-- Hooks only (wcme_epic_batch3_spells / wcme_epic_batch3_hooks): Moon's Wrath (1180590), Critical Time (1575124),
-- Unstoppable Force (911167), Pyroclasmic Shadows (1577402), Shooting Stars (81181), Swashbuckler: Shocktrooper (81415),
-- Esoteric Power (1556015), Raising Hell (81096, 281336), Totem Master: Fire (81445, 1581586), Blood Drinker (965389),
-- Sweeping Swings (912326), High Winds (954126), Timed Charge (954636), Fire and Ice (84382), Eclipse Bomber (275014).
-- Core patch 69: Iron Guard (1181340).
-- With rows: Swashbuckler: Flurry of Blows (81221), Matched Blows (81219), Shocktrooper (281944), Controlled Aggression
-- (1181300: no rows since review 2026-11-18, the core's aura link keeps its helpers; the script hook stays),
-- Poison Bomb (979113), Deadly Follow-up (979080 and its ability 979081).
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 979113),
('spell_proc', 979080);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (81221, 81219, 281944, 1181300, 979113, 979080);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (81221, 81219, 281944, 1181300, 979113, 979080, 979081) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (979113, 979080);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(979113, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(979080, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(81221, 'spell_wcme_swashbuckling_bonus'),
(81219, 'spell_wcme_swashbuckling_bonus'),
(281944, 'spell_wcme_swashbuckling_bonus'),
(979080, 'spell_wcme_keep_helper'),
(979080, 'spell_wcme_finisher_combo'),
(979113, 'spell_wcme_finisher_combo'),
(979081, 'spell_wcme_deadly_follow_up');
