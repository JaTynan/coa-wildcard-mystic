-- Data half of patch 55's showcase batch 3 (patches/55-talent-fixes.ps1): binds its scripts and gives Time Bomb the
-- proc row its script reads. Each script's comment in the patch says what it does and why.
-- Blooming Growth 272214: critical Regrowth spreads its heal over time, 10% weaker, to 3 nearby party members.
-- Gul'dan's Chosen 277151: while it lasts, Backdraft and Molten Core are not used up (bound to every version of their
-- buffs: Backdraft 54274 54276 54277 and CoA copies; Molten Core 47383 71162 71165 and CoA copies).
-- Shadow Shot (all 8 ranks, 276811 and 276828-276834): also applies your highest known Corruption.
-- Time Bomb 284591: stores 50% of your Arcane damage to the target and deals it around the target when it runs out;
-- its proc row lets the bomb see Arcane damage taken (melee, ranged, spells and periodic, triggered spells included).
-- Arcane Barrage (every version): damage takes 8 sec off Time Bomb's cooldown, once per cast.
-- Needs the build with this version of patches/55-talent-fixes.ps1. Before that build these rows do nothing: the server
-- names the scripts it lacks in its startup log, and Time Bomb's proc fires into a placeholder.
-- Safe to run again: 000-reset removes every spell_wcme_ binding and the owned spell_proc row.
-- Not tested in game: unverified until a player report or an automated test.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 284591);
DELETE FROM `spell_proc` WHERE `SpellId` IN (284591);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(284591, 64, 0, 0, 0, 0, 664232, 1, 2, 0, 2, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(272214, 'spell_wcme_blooming_growth'),
(54274, 'spell_wcme_guldans_chosen_keep'), (54276, 'spell_wcme_guldans_chosen_keep'), (54277, 'spell_wcme_guldans_chosen_keep'),
(1154274, 'spell_wcme_guldans_chosen_keep'), (1154276, 'spell_wcme_guldans_chosen_keep'), (1154277, 'spell_wcme_guldans_chosen_keep'),
(1254274, 'spell_wcme_guldans_chosen_keep'), (1254276, 'spell_wcme_guldans_chosen_keep'), (1254277, 'spell_wcme_guldans_chosen_keep'),
(47383, 'spell_wcme_guldans_chosen_keep'), (71162, 'spell_wcme_guldans_chosen_keep'), (71165, 'spell_wcme_guldans_chosen_keep'),
(1147383, 'spell_wcme_guldans_chosen_keep'), (1171162, 'spell_wcme_guldans_chosen_keep'), (1171165, 'spell_wcme_guldans_chosen_keep'),
(1247383, 'spell_wcme_guldans_chosen_keep'), (1271162, 'spell_wcme_guldans_chosen_keep'), (1271165, 'spell_wcme_guldans_chosen_keep'),
(276811, 'spell_wcme_shadow_shot'), (276828, 'spell_wcme_shadow_shot'), (276829, 'spell_wcme_shadow_shot'),
(276830, 'spell_wcme_shadow_shot'), (276831, 'spell_wcme_shadow_shot'), (276832, 'spell_wcme_shadow_shot'),
(276833, 'spell_wcme_shadow_shot'), (276834, 'spell_wcme_shadow_shot'),
(284591, 'spell_wcme_time_bomb'),
(44425, 'spell_wcme_time_bomb_barrage'), (44495, 'spell_wcme_time_bomb_barrage'), (44496, 'spell_wcme_time_bomb_barrage'),
(44780, 'spell_wcme_time_bomb_barrage'), (44781, 'spell_wcme_time_bomb_barrage'), (965472, 'spell_wcme_time_bomb_barrage'),
(992894, 'spell_wcme_time_bomb_barrage'), (992956, 'spell_wcme_time_bomb_barrage'), (1144425, 'spell_wcme_time_bomb_barrage'),
(1144780, 'spell_wcme_time_bomb_barrage'), (1144781, 'spell_wcme_time_bomb_barrage'), (1244425, 'spell_wcme_time_bomb_barrage'),
(1513425, 'spell_wcme_time_bomb_barrage');
