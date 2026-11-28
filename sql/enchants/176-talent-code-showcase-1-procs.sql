-- Showcase talents, batch 1, second half: the proc rows held back from file 175 until a build with patch 55's
-- "Showcase talents, batch 1" is installed. Merge only after that build is live: without it, Raging Onslaught's
-- proc would cast Rage! again (resetting its charges, so the player loses one), and Kunai stacks would never be
-- used up. Safe to run again: 000-reset removes owned spell_proc rows. Not tested in game.
--
-- 1. Raging Onslaught 275920: its proc on the cast phase of Raging Blow (melee ability), at the talent's own 20%
--    (Chance 0 takes the spell's own). The script spell_wcme_raging_onslaught adds a Rage! charge.
-- 2. Master of Kunai's buff 277476: each Shuriken Toss hit puts a Kunai stack (277477) on the target, through the
--    buff's own trigger (family Rogue, class flag 0x40000000 in the third word: Shuriken Toss, and Shadow Dagger,
--    which shares the flag). The script on Deadly Throw uses the stacks up.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 275920),
('spell_proc', 277476);
DELETE FROM `spell_proc` WHERE `SpellId` IN (275920, 277476);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(275920, 0, 0, 0, 0, 0, 16, 7, 1, 0, 0, 0, 0, 0, 0, 0),
(277476, 0, 8, 0, 0, 1073741824, 256, 1, 2, 0, 0, 0, 0, 0, 0, 0);
