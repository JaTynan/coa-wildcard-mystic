-- Two second-stage procs in the bot showcase builds that never fired (docs/bot-builds/showcase-audit.md). In each,
-- the core's own rule (coa_mystic_enchant_proc) already gives the buff, but the buff's own proc has no trigger
-- conditions in its spell data (proc flags 0), so its last step never happened. Data only: no build. Not tested in
-- game: unverified until a player report or an automated test.
--
-- 1. Good Fortune 284012 (priest talent, Holy Radiance build). With three Serendipity stacks, casting Greater Heal or
--    Prayer of Healing makes the core cast 284013 (and 284014). Each is only a carrier whose proc should give the real
--    buff, Good Fortune 284015 (+12% Holy critical strike chance for 12 sec). Now a cast link (spell_linked_spell
--    type 0, as the core runs it at the end of every cast, triggered or not): casting 284013 also casts 284015. Only
--    284013 is linked, so the buff comes once when the core fires both carriers.
-- 2. Shot Weaving 274591 (Arcane Gunslinger build). Casting Arcane Missiles while Missile Barrage is up makes the
--    core give the 2.5-sec buff 274592; its proc should fire Gunslinger's Barrage 274600 (a ranged shot) with each
--    missile. Now an action-table rule (recipe R6) on 274592: each Arcane Missiles hit (the missile spells are
--    triggered by the channel, hence AttributesMask 2) casts 274600 at the target. The buff has no charges, so
--    nothing is used up by the extra proc.
--
-- Safe to run again: 000-reset removes WCME: links, owned spell_proc rows, spell_wcme_ bindings and empties
-- wcme_enchant_action.
DELETE FROM `spell_linked_spell` WHERE `spell_trigger` = 284013 AND `spell_effect` = 284015 AND `comment` LIKE 'WCME:%';
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(284013, 284015, 0, 'WCME: Good Fortune: its carrier 284013 casts the real buff 284015');
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 274592);
DELETE FROM `spell_proc` WHERE `SpellId` IN (274592);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(274592, 0, 0, 0, 0, 0, 65536, 1, 2, 0, 2, 0, 0, 0, 0, 0);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (274592);
INSERT INTO `wcme_enchant_action` (`enchant_spell`, `rule`, `spells`, `school_mask`, `target_aura`, `requires_aura`, `chance`, `cooldown_ms`, `action`, `action_spells`, `amount`, `comment`) VALUES
(274592, 0, '7269 7270 8418 8419 10273 10274 15736 15791 22273 25346 27076 29956 31743 33462 33553 33833 33989 34447 35034 38264 38700 38703 39414 42844 42845 58531 61593 85255 254208 340100 350134 351044 607268 954312 993035 1107268 1107269 1107270 1108418 1108419 1110273 1110274 1115736 1115791 1122273 1125346 1127076 1129956 1131743 1133462 1133553 1133833 1133989 1134447 1135034 1138264 1138700 1138703 1139414 1142844 1142845 2102038 2110506 2125302 2125303 2125304 2125305 2126542 2126543 2126544 2126545 2131209 2131210 2131211 2131212 2135005 2135006 2135007 2135008 2149684 12000017 12000018 12000019 12000020 12000021 12000022 12000023 12000024 12000025 12000026 12000039 12000040 12000041 12000042 12000043 12000044 12000045 12000046 12000047 12000048 12000061 12000062 12000063 12000064 12000065 12000066 12000067 12000068 12000069 12000070 12000083 12000084 12000085 12000086 12000087 12000088 12000089 12000090 12000091 12000092 12000105 12000106 12000107 12000108 12000109 12000110 12000111 12000112 12000113 12000114', 0, '', '', 100, 0, 'cast_target', '274600', 0, 'Shot Weaving: each Arcane Missile also fires a ranged shot');
DELETE FROM `spell_script_names` WHERE `spell_id` IN (274592) AND `ScriptName` = 'spell_wcme_enchant_action';
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(274592, 'spell_wcme_enchant_action');
