-- Talent companions, batch 5 (probable list), part 1: four talents and abilities whose hidden companion only needs
-- to be held, linked or given its proc rule. Data only: no build needed, live at the next server start. Safe to run
-- again (000-reset removes WCME: links, owned spell_proc rows and owned aura links). Each read by hand on 25 Nov 2026.
-- Not tested in game: these stay unverified until a player report or an automated test.
--
-- 1. Rapid Killing (34948, 34949): the tooltip's Rapid Fire cooldown cut lives in a companion per rank (984492:
--   -90 sec, 984493: -180 sec, class flag 0x20 = every Rapid Fire version). Nothing applied them; now linked to the
--   talent ranks. The kill buff part already worked. The CoA copies of the talent (1134948, 1134949) carry their own,
--   smaller cut and are left alone: the Wildcard talent uses the stock ranks, and the client tooltip names the companion.
-- 2. Holy Focus, rank 5 (15011): its capstone (Holy damage crits have a 50% chance to give +5% magic damage for 8 sec,
--   at most once every 8 sec) lives in companion 815013, which fires 815014. Linked to rank 5 only, with its proc rule
--   (Holy, spell damage done, on a crit, 50%, 8 sec cooldown; the companion's data has no trigger of its own).
-- 3. Temple Guardian (283744): +5% block chance (283747) while Inner Fire is on you. Through the core's aura link
--   table: the talent is the holder, every player Inner Fire version (priest class flags) is watched, so the block
--   bonus comes and goes with Inner Fire and never sticks without it.
-- 4. Twisted Mind (284448, and the CoA copy 1587342): the form's tooltip promises 5% less healing and absorbs done
--   (978705 and the CoA copy 1587343). Nothing applied them; now linked to the form, so they last exactly as long.
--
-- Checked and left alone (no change needed):
-- - Freedom by Death (283360): its companion 283362 repeats the talent's own Shadow Word: Death cooldown cut, which
--   the talent already applies; linking it would double the cut. The rest of the talent is the Epic enchant script.
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(34948, 984492, 2, 'WCME: Rapid Killing rank 1 applies its Rapid Fire cooldown companion'),
(34949, 984493, 2, 'WCME: Rapid Killing rank 2 applies its Rapid Fire cooldown companion'),
(15011, 815013, 2, 'WCME: Holy Focus rank 5 applies its capstone companion (Divine Light)'),
(284448, 978705, 2, 'WCME: Twisted Mind applies its healing and absorb penalty'),
(1587342, 1587343, 2, 'WCME: Twisted Mind (CoA copy) applies its healing and absorb penalty');

INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES ('spell_proc', 815013);
DELETE FROM `spell_proc` WHERE `SpellId` IN (815013);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(815013, 2, 0, 0, 0, 0, 65536, 1, 2, 2, 0, 0, 0, 50, 8000, 0);

INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES ('aura_link', 283744);
DELETE FROM `coa_mystic_enchant_aura_link` WHERE `enchant_spell` IN (283744);
INSERT INTO `coa_mystic_enchant_aura_link` (`enchant_spell`, `aura`, `grant_spell`, `comment`) VALUES
(283744, '588 602 1006 7128 10951 10952 25431 48040 48168 143075 370426 801447 1100588 1100602 1101006 1107128 1110951 1110952 1125431 1148040 1148168 1401088 1401506 1411451 10001006', 283747, 'WCME: Temple Guardian: Inner Fire also grants 5% block chance');
