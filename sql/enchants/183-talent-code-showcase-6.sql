-- Data half of patch 55's showcase batch 6 (patches/55-talent-fixes.ps1): script bindings. Each script's comment in the
-- patch says what it does and why.
-- Divine Concord's extra Arcane Blast stack or Harnessed Energy charge: on the cleanup 984295 (needs sql 182 too).
-- Glaive Toss with Kunai and Toss and Throw: on every glaive damage spell (two per cast: 954824 954825; ranks 2-7
-- 955263-955268 and 955279-955284; and 2304824 2304825).
-- Toss and Throw against monsters: on every Shuriken Toss (954835, ranks 2-7 955223-955228, 2304835).
-- The pet Hunter's Mark bonus is a hook and needs no binding.
-- Needs the build with this version of patches/55-talent-fixes.ps1; until then the server names the scripts it lacks in
-- its startup log. Safe to run again: 000-reset removes every spell_wcme_ binding.
-- Not tested in game: unverified until a player report or an automated test.
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(984295, 'spell_wcme_divine_concord_bonus'),
(954824, 'spell_wcme_glaive_toss_ninja'), (954825, 'spell_wcme_glaive_toss_ninja'),
(955263, 'spell_wcme_glaive_toss_ninja'), (955264, 'spell_wcme_glaive_toss_ninja'), (955265, 'spell_wcme_glaive_toss_ninja'),
(955266, 'spell_wcme_glaive_toss_ninja'), (955267, 'spell_wcme_glaive_toss_ninja'), (955268, 'spell_wcme_glaive_toss_ninja'),
(955279, 'spell_wcme_glaive_toss_ninja'), (955280, 'spell_wcme_glaive_toss_ninja'), (955281, 'spell_wcme_glaive_toss_ninja'),
(955282, 'spell_wcme_glaive_toss_ninja'), (955283, 'spell_wcme_glaive_toss_ninja'), (955284, 'spell_wcme_glaive_toss_ninja'),
(2304824, 'spell_wcme_glaive_toss_ninja'), (2304825, 'spell_wcme_glaive_toss_ninja'),
(954835, 'spell_wcme_shuriken_toss_monsters'), (955223, 'spell_wcme_shuriken_toss_monsters'),
(955224, 'spell_wcme_shuriken_toss_monsters'), (955225, 'spell_wcme_shuriken_toss_monsters'),
(955226, 'spell_wcme_shuriken_toss_monsters'), (955227, 'spell_wcme_shuriken_toss_monsters'),
(955228, 'spell_wcme_shuriken_toss_monsters'), (2304835, 'spell_wcme_shuriken_toss_monsters');
