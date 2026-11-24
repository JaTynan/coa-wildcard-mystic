-- Talent companions, batch 4 (code), part 3: two companions on Ascension's aura 354 (deal a share of the
-- triggering damage as another spell), which the core runs only for its own list of spells. The scripts are in
-- patches/55-talent-fixes.ps1 ("Percent-of-damage companions"); this file gives them their proc rules and
-- bindings. Needs the build with that patch; without it the bindings name scripts that do not exist yet (the
-- server logs an error for each and carries on) and nothing changes. Safe to run again (000-reset removes WCME:
-- links, owned spell_proc rows, ability companions and spell_wcme_ bindings). Read by hand on 24 Nov 2026. Not
-- tested in game: unverified until a player report or an automated test.
--
-- 1. Harbinger of Plague (talent 276427). Casting Wrath gives Harbinger of Plague (276430 on Haunt, 276432 on
--   diseases, +15% each, stacking to 5); while it is up, Haunt also hits up to 10 enemies near its target for 30% of
--   its damage (Harbinger's Bile, 276435). Neither half works today: the talent's two effects have no proc flags and
--   no rule (Wrath never gives the buff), and the companion 276433 is not applied.
--   - The talent's rule: on casting Wrath (druid class flag, every rank), both effects fire together.
--   - The companion is linked to the talent, with a rule for Haunt's hits (its class flag). The script checks the
--     buff and casts the bile; the bile's own script spares Haunt's target.
-- 2. Reave (280990-280997, the Hero version of the Bloodmage ability). Each hit adds Shadow damage for each
--   condition met: 100% of the hit when you are behind the enemy, 100% when it is bleeding, 125% when it is below
--   35% health. Its passive (280998) is held while the player knows any rank (patch 55's ability companions); a rule
--   for Reave's hits and the script do the rest. The Bloodmage class's own Reave (800490) is already scripted by the
--   core and is not touched.
-- The bonus spells keep their own data: Harbinger's Bile has no spell power coefficient, and Reave's three bonus
-- spells have 0.35 (as in Ascension's data, and as the core's Bloodmage Reave uses them).
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(276427, 276433, 2, 'WCME: Harbinger of Plague applies its Haunt splash companion');

INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES ('spell_proc', 276427), ('spell_proc', 276433), ('spell_proc', 280998);
DELETE FROM `spell_proc` WHERE `SpellId` IN (276427, 276433, 280998);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(276427, 0, 7, 1, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(276433, 0, 5, 0, 262144, 0, 65536, 1, 2, 0, 0, 0, 0, 100, 0, 0),
(280998, 0, 0, 0, 0, 0, 16, 1, 2, 0, 0, 0, 0, 100, 0, 0);

INSERT INTO `wcme_spell_companion` (`ability_spell`, `passive_spell`, `flags`, `comment`) VALUES
(280990, 280998, 0, 'Reave rank 1: its condition bonuses'),
(280991, 280998, 0, 'Reave rank 2: its condition bonuses'),
(280992, 280998, 0, 'Reave rank 3: its condition bonuses'),
(280993, 280998, 0, 'Reave rank 4: its condition bonuses'),
(280994, 280998, 0, 'Reave rank 5: its condition bonuses'),
(280995, 280998, 0, 'Reave rank 6: its condition bonuses'),
(280996, 280998, 0, 'Reave rank 7: its condition bonuses'),
(280997, 280998, 0, 'Reave rank 8: its condition bonuses');

INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(276433, 'spell_wcme_harbinger_of_plague'),
(276435, 'spell_wcme_harbinger_bile'),
(280998, 'spell_wcme_reave_passive');
