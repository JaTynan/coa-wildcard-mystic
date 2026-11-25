-- Talent companions, batch 6 (the scan's "stock-data" list), part 2: three talents whose companion also needs code
-- (patch 55, its "part 7" section). Needs the build with that section: until then the links apply the companions,
-- which do nothing on their own, and the binding names a script the server does not have yet (it logs an error and
-- carries on). Safe to run again (000-reset removes WCME: links and spell_wcme_ bindings). Each read by hand on
-- 25 Nov 2026, with the stock scripts checked for each id. Not tested in game: unverified until a player report or
-- an automated test.
--
-- 1. Improved Kick (13754, 13867): a Kick that interrupts gives 20 / 40 energy. The amount sits in a companion per
--   rank (13869, 13870), which nothing applied, and the core has no proc result for "interrupted"; the patch uses
--   the core's successful-interrupt hook and reads the amount from the companion. The silence part already works
--   (the stock proc rule for Improved Kick).
-- 2. Fanaticism (31879, 31880, 31881): Crusader Strike, Seals and Judgements deal 7 / 14 / 20% more to a target
--   carrying your own Execution Sentence. The amount sits in a companion per rank (31891, 31894, 31895) whose data
--   is a modifier with no target, so the patch applies it (spell damage and the seals' damage over time). The
--   scan listed rank 1; ranks 2 and 3 have the same gap.
-- 3. Fiery Payback (64353, 64357), two companions per rank, neither applied before:
--   - 64350 / 64349: melee and ranged attacks against you have a 5 / 10% chance to disarm the attacker (64346).
--     Their own data carries the trigger and the chance.
--   - 44440 / 44441: below 35% health, 10 / 20% less damage taken, and Pyroblast casts faster but has a longer
--     cooldown. Their data asks for the "below 35% health" state; the core switches them on and off with it, but a
--     linked aura would start switched on at full health, so the patch starts it switched off when the state is
--     missing, as the core does for a learned spell.
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(13754, 13869, 2, 'WCME: Improved Kick rank 1 holds its interrupt energy amount'),
(13867, 13870, 2, 'WCME: Improved Kick rank 2 holds its interrupt energy amount'),
(31879, 31891, 2, 'WCME: Fanaticism rank 1 holds its Execution Sentence damage amount'),
(31880, 31894, 2, 'WCME: Fanaticism rank 2 holds its Execution Sentence damage amount'),
(31881, 31895, 2, 'WCME: Fanaticism rank 3 holds its Execution Sentence damage amount'),
(64353, 64350, 2, 'WCME: Fiery Payback rank 1 applies its disarm chance'),
(64353, 44440, 2, 'WCME: Fiery Payback rank 1 applies its below-35% health passive'),
(64357, 64349, 2, 'WCME: Fiery Payback rank 2 applies its disarm chance'),
(64357, 44441, 2, 'WCME: Fiery Payback rank 2 applies its below-35% health passive');

INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(44440, 'spell_wcme_health_state_passive'),
(44441, 'spell_wcme_health_state_passive');
