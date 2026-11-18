-- Legendaries flagged "core handler" and "visual only" (needs the build with this version of
-- mystic-enchants-scripts.patch).
-- Wraithweaver: Shadow Orbs (1544910): the orbs are the core's own rule (review 2026-11-18: our proc row here was at 100%,
-- so the core gave an orb on every tick; the core's row is put back below). The Shadowy Apparition from a Mind Blast
-- with 3 orbs is a hook in the scripts (wcme_shadow_orbs_mind_blast), so it needs no row.
-- Dragon Roar (1590910): teaches its own Dragon Roar (1569444, 006 no longer teaches twin 271895), which finishes
-- Whirlwind's cooldown. Its visual is the spell's own.
-- Dragon Warrior (954252): its own design instead of twin 271907 (004 no longer overrides or links it): Draconic Slam,
-- Dragon Fury stacks with their own visual, and the Dragon Roar stun only at 3 stacks.
-- Wind Lash (1760200): the Windfury bonus on its strikes.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 954252),
('spell_proc', 1760200);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (1544910, 954252, 1760200, 1590910);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (1544910, 954252, 954251, 1760200, 1569444) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (1544910, 954252, 1760200);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(954252, 0, 0, 0, 0, 0, 16, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(1760200, 0, 0, 0, 0, 0, 16, 1, 2, 0, 2, 0, 0, 100, 0, 0);
-- The core's own proc row for Wraithweaver: Shadow Orbs, exactly as it ships (not owned, so the reset leaves it).
REPLACE INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(1544910, 0, 0, 0, 0, 0, 0x55550, 0, 0x3, 0x0, 0x2, 0, 0, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(1569444, 'spell_wcme_dragon_roar_whirlwind'),
(954252, 'spell_wcme_dragon_warrior'),
(954251, 'spell_wcme_dragon_roar_stun'),
(1760200, 'spell_wcme_wind_lash');
DELETE FROM `wcme_enchant_teach` WHERE `enchant_spell` = 1590910;
INSERT INTO `wcme_enchant_teach` (`enchant_spell`, `taught_spell`, `comment`) VALUES
(1590910, 1569444, 'Dragon Roar: teaches its own Dragon Roar');
