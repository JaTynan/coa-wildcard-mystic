-- Talent companions, batch 4 (code), part 4: six talents whose hidden companion did its work in Ascension's own
-- server code. The scripts are in patches/55-talent-fixes.ps1 ("Talent companion scripts"); this file holds each
-- companion and gives the scripts their proc rules and bindings. Needs the build with that patch: without it the
-- bindings name scripts that do not exist yet (the server logs an error for each and carries on). Safe to run again
-- (000-reset removes WCME: links, owned spell_proc rows, ability companions and spell_wcme_ bindings). Read by hand on
-- 25 Nov 2026. Not tested in game: unverified until a player report or an automated test.
--
-- 1. Beacon of Virtue (277680, an ability): beacons the target and up to 4 injured allies near it for 10 sec; while
--   the beacons last, each hit of your Holy heals with a cast time also heals them for 25% (277681), in a group or
--   not; the caster remembers what it beaconed last. The companion (277684) is held
--   while you know the ability, and fires on your heals (Holy school, heal, on hit; the script checks the cast time).
-- 2. Holy Concentration (34753, 34859, 34860): Flash Heal, Greater Heal, Binding Heal and Circle of Healing have a
--   33/66/100% chance (the companion ranks 966083-966085, linked to the talent ranks) to extend your Renew on you and
--   your party or raid by 3 sec, capped at +50% of Renew's duration per application (James's rule for extensions;
--   the tooltip's cap is missing from the client data). The rule fires once per cast. Its class flags: Flash Heal and
--   Greater Heal (first mask), Binding Heal (second), Circle of Healing (third, 0x4000000; the companion's own data
--   names Empowered Renew there instead, which is triggered and could never fire it).
-- 3. Pack Leader (277566): the talent's own Feral Spirit buff already works (the core's rules); its companion (277750)
--   now cuts the Spirit Wolves' Spirit Hunt healing to 30%, as the tooltip says, since Pack Leader adds wolves.
-- 4. Flare Strike (283151-283155, the Hero's Flare): the rain of arrows when it expires already works (the core); the
--   companion (283150, held while you know any rank) now gives it 100% more damage against the target of your
--   Hunter's Mark.
-- 5. Bloodletting (283986): Rupture deals 25% more to targets with your Rend, and its companion (283987, linked) makes
--   Rend deal 30% more to targets with your Rupture. The same code serves the Mystic Enchant Garrote (982178: Garrote
--   5% more against targets with your Rend), which uses the same class script.
-- 6. Corrupted Bear Form (271403): the core gives it the -20% Physical penalty in Bear Form and fires Corrupted Paw
--   (271411) on each melee hit, but the Paw dealt a flat 2 Shadow, and the penalty was only synced on the stock forms
--   (5487, 9634): the CoA Bear Form and Dire Bear Form (1105487, 1109634) now get the core's form script too. Ours makes it 25% of the hit as dealt (after
--   armour and the penalty), so the total equals a plain bear: Shadow ignores armour, so a share taken after armour
--   keeps it in line with Ascension's elemental weapon attacks, which keep Physical in their school for that reason.
--   The Paw no longer adds spell power or the caster's damage bonuses on top. James asked for scaling on 25 Nov 2026;
--   25% is the neutral choice.
-- Not here: Tidecaller's Boon (271813) already works through the Epic enchant scripts (Healing Wave, its stacks).
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(34753, 966083, 2, 'WCME: Holy Concentration rank 1 applies its Renew extension companion'),
(34859, 966084, 2, 'WCME: Holy Concentration rank 2 applies its Renew extension companion'),
(34860, 966085, 2, 'WCME: Holy Concentration rank 3 applies its Renew extension companion'),
(277566, 277750, 2, 'WCME: Pack Leader applies its Spirit Wolf healing companion'),
(283986, 283987, 2, 'WCME: Bloodletting applies its Rend companion');

INSERT INTO `wcme_spell_companion` (`ability_spell`, `passive_spell`, `flags`, `comment`) VALUES
(277680, 277684, 0, 'Beacon of Virtue: its beacon heals'),
(283151, 283150, 0, 'Flare Strike rank 1: rain +100% on your Hunter''s Mark target'),
(283152, 283150, 0, 'Flare Strike rank 2: rain +100% on your Hunter''s Mark target'),
(283153, 283150, 0, 'Flare Strike rank 3: rain +100% on your Hunter''s Mark target'),
(283154, 283150, 0, 'Flare Strike rank 4: rain +100% on your Hunter''s Mark target'),
(283155, 283150, 0, 'Flare Strike rank 5: rain +100% on your Hunter''s Mark target');

INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES ('spell_proc', 277684), ('spell_proc', 966083), ('spell_proc', 966084), ('spell_proc', 966085);
DELETE FROM `spell_proc` WHERE `SpellId` IN (277684, 966083, 966084, 966085);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(277684, 2, 0, 0, 0, 0, 16384, 2, 2, 0, 0, 0, 0, 100, 0, 0),
(966083, 0, 6, 6144, 4, 67108864, 87312, 0, 1, 0, 0, 0, 0, 33, 0, 0),
(966084, 0, 6, 6144, 4, 67108864, 87312, 0, 1, 0, 0, 0, 0, 66, 0, 0),
(966085, 0, 6, 6144, 4, 67108864, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0);

INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(277680, 'spell_wcme_beacon_of_virtue'),
(277684, 'spell_wcme_beacon_of_virtue_heals'),
(966083, 'spell_wcme_holy_concentration_renew'),
(966084, 'spell_wcme_holy_concentration_renew'),
(966085, 'spell_wcme_holy_concentration_renew'),
(271403, 'spell_wcme_corrupted_bear_paw'),
(271411, 'spell_wcme_corrupted_paw');

-- The core's own Corrupted Bear form script, on the CoA bear forms as well. 000-reset does not clear core script names,
-- so the insert skips rows already there (safe to run again).
INSERT IGNORE INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(1105487, 'aura_ascension_wildcard_corrupted_bear_form'),
(1109634, 'aura_ascension_wildcard_corrupted_bear_form');
