-- Core rule versions: build talents whose trigger rule in the core lists only one version of the trigger ability.
-- On this realm most abilities exist twice (the stock spell and its CoA copy, for example Shadow Bolt 686 and
-- 1100686) and a character can learn either, so for a player with the other version the talent never fired
-- (enchants/core-rule-version-gaps.csv). Each row below is a copy of the core's own rule in coa_mystic_enchant_proc
-- (same enchant, effect, event, chance, cooldown and conditions) with a rule number of 200 and up, listing only the
-- versions the core's rule left out: every rank of the other copy (each stock id's CoA twin, 1100000 higher, and
-- the reverse), not only the first rank the gaps file names. The core's rows are not touched, so nothing can fire twice.
-- Talents: Heavyweight 273378, Demolisher 273786, Arcane Gunslinger 274586, Shot Weaving 274591, Master of Shadows
-- 275491, Harbinger of Plague 276427, Gul'dan's Chosen 277150, Toss and Throw 277455, Master of Kunai 277475,
-- Glimmer of Light 277692, Arcane Motes 281905, Good Fortune 284012, Sword and Thunder 284435, Shield Finesse 285548,
-- Synergetic Light 285818, Blades of Blood 285895, Shadow Infusion 285942, Hunting Frenzy 1180820, Enduring Aegis
-- 1584825. These are the parts of the bot showcase builds (docs/bot-builds/showcase-audit.md, section 2b); the other
-- rows of the gaps file are left for later batches.
-- Data only: the core's rule engine (spell_ascension_mystic_enchant_proc) reads the table at start-up; no build.
-- Each talent already has the core's spell_proc row and script binding. Safe to run again: 000-reset removes every
-- row of this table whose comment starts with WCME:. Not tested in game: unverified until a player report or an
-- automated test.
DELETE FROM `coa_mystic_enchant_proc` WHERE `comment` LIKE 'WCME:%' AND `enchant_spell` IN (273378, 273786, 274586, 274591, 275491, 276427, 277150, 277455, 277475, 277692, 281905, 284012, 284435, 285548, 285818, 285895, 285942, 1180820, 1584825);
INSERT INTO `coa_mystic_enchant_proc` (`enchant_spell`, `effect`, `rule`, `event`, `school_mask`, `spells`, `chance`, `cooldown_ms`, `requires_aura`, `target_aura`, `conditions`, `consume_aura`, `trigger_spells`, `amount_pct`, `chance_per_combo`, `comment`) VALUES
(273378, 0, 200, 'cast', 0, '1101464 1101465 1101466 1105308 1107384 1108820 1111604 1111605 1120658 1120660 1120661 1120662 1125234 1125236 1125241 1125242 1147470 1147471', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Heavyweight: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(273786, 1, 200, 'cast', 0, '1112294 1121551 1121552 1121553 1125248 1130330 1147485 1147486', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Demolisher: the other learnable version of its trigger ability (core rule 1/0 lists only one)'),
(274586, 0, 200, 'cast', 0, '1103044 1114281 1114282 1114283 1114284 1114285 1114286 1114287 1127019 1149044 1149045', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Arcane Gunslinger: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(274591, 0, 200, 'cast', 0, '1105143 1105144 1105145 1108416 1108417 1110211 1110212 1125345 1127075 1138699 1138704 1142843 1142846', 100, 0, '44401', '', '', '', '', 0, 0, 'WCME: Shot Weaving: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(275491, 1, 200, 'cast', 0, '1101943 1102098 1106760 1106761 1106762 1108623 1108624 1108639 1108640 1111273 1111274 1111275 1111299 1111300 1126865 1126867 1131016 1148667 1148668 1148671 1148672', 100, 0, '', '', 'stacks:275494>=3', '275494', '', 0, 0, 'WCME: Master of Shadows: the other learnable version of its trigger ability (core rule 1/0 lists only one)'),
(276427, 0, 200, 'cast', 0, '1105176 1105177 1105178 1105179 1105180 1106780 1108905 1109912 1126984 1126985 1148459 1148461', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Harbinger of Plague: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(276427, 1, 200, 'cast', 0, '1105176 1105177 1105178 1105179 1105180 1106780 1108905 1109912 1126984 1126985 1148459 1148461', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Harbinger of Plague: the other learnable version of its trigger ability (core rule 1/0 lists only one)'),
(277150, 0, 200, 'cast', 0, '1100686 1100695 1100705 1101088 1101106 1106353 1107641 1111659 1111660 1111661 1117924 1125307 1127209 1129722 1130545 1132231 1147808 1147809 1147824 1147825 1147837 1147838 1150796 1159170 1159171 1159172', 100, 0, '', '', 'stacks:277151=0', '', '', 0, 0, 'WCME: Gul''dan''s Chosen: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(277455, 0, 200, 'cast', 0, '1126679 1148673 1148674', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Toss and Throw: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(277475, 0, 200, 'cast', 0, '1113750', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Master of Kunai: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(277692, 0, 200, 'cast', 0, '1119750 1119939 1119940 1119941 1119942 1119943 1127137 1148784 1148785', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Glimmer of Light: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(281905, 1, 200, 'cast', 0, '1105143 1105144 1105145 1108416 1108417 1110211 1110212 1125345 1127075 1138699 1138704 1142843 1142846 1144425 1144780 1144781', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Arcane Motes: the other learnable version of its trigger ability (core rule 1/0 lists only one)'),
(284012, 0, 200, 'cast', 0, '1100596 1100996 1102060 1110960 1110961 1110963 1110964 1110965 1125210 1125213 1125308 1125314 1125316 1148062 1148063 1148072', 100, 0, '', '', 'stacks:63734>=3', '', '', 0, 0, 'WCME: Good Fortune: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(284012, 1, 200, 'cast', 0, '1100596 1100996 1102060 1110960 1110961 1110963 1110964 1110965 1125210 1125213 1125308 1125314 1125316 1148062 1148063 1148072', 100, 0, '', '', 'stacks:63734>=3', '', '', 0, 0, 'WCME: Good Fortune: the other learnable version of its trigger ability (core rule 1/0 lists only one)'),
(284435, 0, 200, 'cast', 0, '1106572 1106574 1107379 1111600 1111601 1120243 1125269 1125288 1130016 1130022 1130357 1147497 1147498 1157823', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Sword and Thunder: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(285548, 0, 200, 'cast', 0, '1102565', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Shield Finesse: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(285818, 0, 200, 'cast', 0, '1100635 1100639 1100647 1101026 1101042 1103472 1110328 1110329 1119750 1119939 1119940 1119941 1119942 1119943 1125292 1127135 1127136 1127137 1148781 1148782 1148784 1148785', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Synergetic Light: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(285895, 0, 200, 'cast', 0, '1100100 1106178 1111578 1186361', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Blades of Blood: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(285895, 1, 200, 'cast', 0, '1100100 1106178 1111578 1186361', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Blades of Blood: the other learnable version of its trigger ability (core rule 1/0 lists only one)'),
(285942, 0, 200, 'cast', 0, '1105938 1143265 1149936 1149937 1149938', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Shadow Infusion: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(1180820, 0, 200, 'cast', 0, '34026', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Hunting Frenzy: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(1584825, 0, 200, 'cast', 0, '23922 23923 23924 23925 25258 30356 47487 47488', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Enduring Aegis: the other learnable version of its trigger ability (core rule 0/0 lists only one)');
