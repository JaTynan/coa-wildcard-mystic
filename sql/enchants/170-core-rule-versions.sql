-- Core rule versions: build talents whose trigger rule in the core lists only one version of the trigger ability.
-- On this realm most abilities exist twice (the stock spell and its CoA copy, for example Shadow Bolt 686 and
-- 1100686) and a character can learn either, so for a player with the other version the talent never fired
-- (enchants/core-rule-version-gaps.csv). Each row below is a copy of the core's own rule in coa_mystic_enchant_proc
-- (same enchant, effect, event, chance, cooldown and conditions) with a rule number of 200 and up, listing only the
-- versions the core's rule left out. The core's rows are not touched, so nothing can fire twice.
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
(273378, 0, 200, 'cast', 0, '1101464 1105308 1107384', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Heavyweight: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(273786, 1, 200, 'cast', 0, '1112294', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Demolisher: the other learnable version of its trigger ability (core rule 1/0 lists only one)'),
(274586, 0, 200, 'cast', 0, '1103044', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Arcane Gunslinger: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(274591, 0, 200, 'cast', 0, '1105143', 100, 0, '44401', '', '', '', '', 0, 0, 'WCME: Shot Weaving: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(275491, 1, 200, 'cast', 0, '1101943 1102098', 100, 0, '', '', 'stacks:275494>=3', '275494', '', 0, 0, 'WCME: Master of Shadows: the other learnable version of its trigger ability (core rule 1/0 lists only one)'),
(276427, 0, 200, 'cast', 0, '1105176', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Harbinger of Plague: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(276427, 1, 200, 'cast', 0, '1105176', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Harbinger of Plague: the other learnable version of its trigger ability (core rule 1/0 lists only one)'),
(277150, 0, 200, 'cast', 0, '1100686 1106353 1129722 1150796', 100, 0, '', '', 'stacks:277151=0', '', '', 0, 0, 'WCME: Gul''dan''s Chosen: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(277455, 0, 200, 'cast', 0, '1126679', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Toss and Throw: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(277475, 0, 200, 'cast', 0, '1113750', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Master of Kunai: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(277692, 0, 200, 'cast', 0, '1119750', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Glimmer of Light: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(281905, 1, 200, 'cast', 0, '1105143 1144425', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Arcane Motes: the other learnable version of its trigger ability (core rule 1/0 lists only one)'),
(284012, 0, 200, 'cast', 0, '1100596 1102060', 100, 0, '', '', 'stacks:63734>=3', '', '', 0, 0, 'WCME: Good Fortune: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(284012, 1, 200, 'cast', 0, '1100596 1102060', 100, 0, '', '', 'stacks:63734>=3', '', '', 0, 0, 'WCME: Good Fortune: the other learnable version of its trigger ability (core rule 1/0 lists only one)'),
(284435, 0, 200, 'cast', 0, '1106572 1120243', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Sword and Thunder: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(285548, 0, 200, 'cast', 0, '1102565', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Shield Finesse: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(285818, 0, 200, 'cast', 0, '1100635 1119750', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Synergetic Light: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(285895, 0, 200, 'cast', 0, '1100100 1186361', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Blades of Blood: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(285895, 1, 200, 'cast', 0, '1100100 1186361', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Blades of Blood: the other learnable version of its trigger ability (core rule 1/0 lists only one)'),
(285942, 0, 200, 'cast', 0, '1105938 1143265', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Shadow Infusion: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(1180820, 0, 200, 'cast', 0, '34026', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Hunting Frenzy: the other learnable version of its trigger ability (core rule 0/0 lists only one)'),
(1584825, 0, 200, 'cast', 0, '23922', 100, 0, '', '', '', '', '', 0, 0, 'WCME: Enduring Aegis: the other learnable version of its trigger ability (core rule 0/0 lists only one)');
