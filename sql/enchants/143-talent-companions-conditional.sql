-- Talent companions, batch 3: bonuses that apply only under a condition (scan: enchants/talent-companions.csv).
-- Same pattern as 141 and 142, but a plain link would make these permanent, so they use the core's own aura links
-- instead (coa_mystic_enchant_aura_link, recipe R7): while the character has the talent AND the watched aura, the
-- core grants the companion, and takes it away when either goes. Data only: no build. Needs a server start.
-- Safe to run again: 000-reset removes the aura links registered in wcme_owned. Each pair read by hand on
-- 24 Nov 2026. Not tested in game: James's testing policy, so these stay unverified until a player report or an
-- automated test.
--
--   Divinity (3 ranks): while on Path of Strength (84864, the Wildcard stat path, a passive aura), healing taken
--     +4 / 8 / 12% and healing power +20 / 40 / 60% of Stamina (636460-636462). The tooltip requires Path of
--     Strength. The healing-taken bonus already does not stack with similar ones (the core takes the largest
--     positive healing-taken bonus), as the tooltip says. The Stamina part names stat 127 first and Stamina second;
--     the core falls back to the second value, so it reads Stamina.
--   Glyph of Trueshot Aura: +10% critical strike chance on Aimed Shot (1119510). The tooltip says "while you have
--     Trueshot Aura learned"; the closest the data can express is while Trueshot Aura is on (19506 and its two
--     learnable versions). Trueshot Aura stays up until cancelled, so in practice the two are the same. The glyph's
--     own effect is a class-script override (56842) that this core does not implement, so nothing doubles.
--
-- Already done elsewhere: Swashbuckler: Flurry of Blows (melee haste while Swashbuckling) is an aura link in
-- 007-enchant-actions.sql. Held back: Corrupted Bear Form. Its Shadow-damage proc has no trigger rules, so the talent
-- does nothing today; linking only its 20% physical-damage penalty would make it worse. It needs the proc as well,
-- whose damage cannot be read from the data (later batch, with code).
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES ('aura_link', 63646), ('aura_link', 63647), ('aura_link', 63648), ('aura_link', 118478);
DELETE FROM `coa_mystic_enchant_aura_link` WHERE `enchant_spell` IN (63646, 63647, 63648, 118478);
INSERT INTO `coa_mystic_enchant_aura_link` (`enchant_spell`, `aura`, `grant_spell`, `comment`) VALUES
(63646, '84864', 636460, 'WCME: Divinity rank 1: healing bonuses while on Path of Strength'),
(63647, '84864', 636461, 'WCME: Divinity rank 2: healing bonuses while on Path of Strength'),
(63648, '84864', 636462, 'WCME: Divinity rank 3: healing bonuses while on Path of Strength'),
(118478, '19506 1119506 1219506', 1119510, 'WCME: Glyph of Trueshot Aura: Aimed Shot critical strike chance while Trueshot Aura is on');
