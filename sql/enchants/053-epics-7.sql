-- Epic enchants, batch 7 (needs the build with this version of mystic-enchants-scripts.patch; no client patch change).
-- Hooks only (wcme_epic_batch67_spells / wcme_epic_batch67_hooks): Searing Flames (1180640), Ol' Bloodsurge (983600),
-- Photosynthesis (287852), Lingering Death (81506), Vampirism (277003). Shadow Funnel (1180900) was
-- dropped in review 2026-11-18: the core already does it.
-- Taught spells (wcme_enchant_teach): Unbounded Mind Flay (81370 -> 81371), Unbounded Drain Mana (81362 -> 81383),
-- You're a Solid Crate (982476 -> 982477), Shadow Word: Gore (983020 -> 983021, its bleed bonus in the hooks), Downpour
-- (983523 -> 983524, Torrential Riptide in the hooks), Party Recuperation (983475 -> 983478).
-- With rows: Party Recuperation (983475: finisher proc, 10% per combo point), Twisted Mind (979779: Fel Armor shows as
-- Twisted Mind), "Stealth" (982477, You're a Solid Crate: its stealth and slow helpers, crate removed after),
-- Energy Surge (1180750: energy while a monster is Gouged), Aegis Overdrive (299160: dodge, parry or
-- block with Mana Shield up).
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 983475), ('spell_proc', 299160);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (983475, 979779, 1180750, 299160);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (983475, 979779, 1180750, 299160, 982477) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (983475, 299160);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(983475, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(299160, 0, 0, 0, 0, 0, 40, 0, 2, 112, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(983475, 'spell_wcme_finisher_combo'),
(979779, 'spell_wcme_twisted_mind'),
(1180750, 'spell_wcme_energy_surge'),
(299160, 'spell_wcme_aegis_overdrive'),
(982477, 'spell_wcme_solid_crate');
DELETE FROM `wcme_enchant_teach` WHERE `enchant_spell` IN (81370, 81362, 982476, 983020, 983523, 983475);
INSERT INTO `wcme_enchant_teach` (`enchant_spell`, `taught_spell`, `comment`) VALUES
(81370, 81371, 'Unbounded Mind Flay teaches Mind Flay (Unbounded Mind Flay)'),
(81362, 81383, 'Unbounded Drain Mana teaches Drain Mana (Unbounded Drain Mana)'),
(982476, 982477, 'You''re a Solid Crate teaches "Stealth" (the crate)'),
(983020, 983021, 'Shadow Word: Gore teaches Shadow Word: Gore'),
(983523, 983524, 'Downpour teaches Downpour'),
(983475, 983478, 'Party Recuperation teaches Party Recuperate');
