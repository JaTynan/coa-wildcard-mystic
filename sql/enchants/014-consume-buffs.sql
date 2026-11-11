-- Batch 14 (11 Nov): enchant buffs that say "your next X" but were never used up, because CoA's data gives
-- them no charge. Each gets one charge, dropped when the buff actually changes a spell
-- (AttributesMask 8 = PROC_ATTR_REQ_SPELLMOD), so only the spell it speeds up or strengthens uses it.
-- Empowered Light (enchant 275361): its buff 275362 cut the cast time of every Holy Fire for 8 seconds,
-- instead of only the next one. Found in game: the buff showed charges 0 and stayed after Holy Fire.
INSERT INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 275362);
DELETE FROM `spell_proc` WHERE `SpellId` IN (275362);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(275362, 0, 0, 0, 0, 0, 65536, 7, 1, 0, 8, 0, 0, 100, 0, 1);
