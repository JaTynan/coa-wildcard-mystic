-- Talent companions, batch 6 (the scan's "stock-data" list), part 1: four talents whose companion uses an old
-- Blizzard spell id that Ascension re-used, and only needs to be held. Data only: no build needed, live at the next
-- server start. Safe to run again (000-reset removes WCME: links and all of wcme_spellaffect_dbc). Each read by hand
-- on 25 Nov 2026, with the stock scripts checked for each id. Not tested in game: unverified until a player report
-- or an automated test.
--
-- 1. Sinister Calling, rank 3 (31218): ranks 1 and 2 lengthen Gloomblade (the buff, Rogue flag 0x80000000 in the
--   third mask) by 1 and 2 sec in their own data; rank 3 gave that slot to its capstone, so its +3 sec lives in
--   31232, which nothing applied. Linked to rank 3.
-- 2. Rising Flames (16086, 16544): Fire Nova's +10% / +20% damage lives in 16545 / 16546 (Shaman flags 0x80040000 in
--   the second mask: every Fire Nova damage spell, and Molten Earth, which carries the same flags). Linked per rank.
--   The second effect raises periodic damage only, which Fire Nova does not deal, so nothing doubles.
-- 3. Empowering Frostbolt (31682, 31683, 31684): Frostbolt's cast time cut (0.1 / 0.2 / 0.3 sec) lives in 31695 /
--   31710 / 31711 (Mage flag 0x20). Linked per rank. The core's Hero mage script only gives the after-cast buff
--   (831682); it does not touch the cast time. The scan listed ranks 1 and 3; rank 2 has the same gap.
-- 4. Improved Blood Presence, rank 5 (51375): its capstone lives in two companions, both linked to rank 5.
--   51377: Blood Presence's damage bonus +8 (Death Knight flag 0x800000, every Blood Presence version).
--   51376: +3 to the healing share of Blood Presence, but its data names no spell. The heal comes from 63611 (the
--   stock script casts it in Blood Presence and reads its amount), so it is named as the target here
--   (wcme_spellaffect_dbc 960030-960031; the CoA copy 1163611 too). The new share applies the next time Blood
--   Presence is entered. The stock script also casts 63611 in Frost and Unholy Presence with the talent, so the +3
--   reaches that heal too: a small extra the tooltip does not mention.
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(31218, 31232, 2, 'WCME: Sinister Calling rank 3 applies its Gloomblade duration companion'),
(16086, 16545, 2, 'WCME: Rising Flames rank 1 applies its Fire Nova damage companion'),
(16544, 16546, 2, 'WCME: Rising Flames rank 2 applies its Fire Nova damage companion'),
(31682, 31695, 2, 'WCME: Empowering Frostbolt rank 1 applies its Frostbolt cast time companion'),
(31683, 31710, 2, 'WCME: Empowering Frostbolt rank 2 applies its Frostbolt cast time companion'),
(31684, 31711, 2, 'WCME: Empowering Frostbolt rank 3 applies its Frostbolt cast time companion'),
(51375, 51376, 2, 'WCME: Improved Blood Presence rank 5 applies its capstone healing companion'),
(51375, 51377, 2, 'WCME: Improved Blood Presence rank 5 applies its capstone damage companion');

INSERT INTO `wcme_spellaffect_dbc` (`ID`, `ModifierSpellID`, `AffectedSpellID`) VALUES
(960030, 51376, 63611),
(960031, 51376, 1163611);
