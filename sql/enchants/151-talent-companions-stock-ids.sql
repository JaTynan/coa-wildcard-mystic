-- Talent companions, batch 6 (the scan's "stock-data" list), part 1: four talents whose companion uses an old
-- Blizzard spell id that Ascension re-used, and only needs to be held. Data only: no build needed, live at the next
-- server start. Safe to run again (000-reset removes WCME: links). Each read by hand
-- on 25 Nov 2026, with the stock scripts checked for each id. Not tested in game: unverified until a player report
-- or an automated test.
--
-- 1. Sinister Calling, rank 3 (31218): ranks 1 and 2 lengthen Gloomblade (the buff, Rogue flag 0x80000000 in the
--   third mask) by 1 and 2 sec in their own data; rank 3 gave that slot to its capstone, so its +3 sec lives in
--   31232, which nothing applied. Linked to rank 3.
-- 2. Rising Flames (16086, 16544): Fire Nova's +10% / +20% damage lives in 16545 / 16546 (Shaman flags 0x80040000 in
--   the second mask: every Fire Nova damage spell, and Molten Earth, whose tooltip says it uses Fire Nova modifiers).
--   Linked per rank. The second effect raises periodic damage (Molten Earth's); the core applies the damage and the
--   periodic modifier to different damage, never both, so nothing doubles.
-- 3. Empowering Frostbolt (31682, 31683, 31684): Frostbolt's cast time cut (0.1 / 0.2 / 0.3 sec) lives in 31695 /
--   31710 / 31711 (Mage flag 0x20; also Water Bolt and other spells Ascension marks as using Frostbolt modifiers).
--   Linked per rank. The core's Hero mage script only gives the after-cast buff
--   (831682); it does not touch the cast time. The scan listed ranks 1 and 3; rank 2 has the same gap.
-- 4. Improved Blood Presence, rank 5 (51375): its capstone lives in two companions, both linked to rank 5.
--   51377: Blood Presence's damage bonus +8 (Death Knight flag 0x800000, every Blood Presence version).
--   51376: +3 to the heal share of 63611, the heal the stock script casts. The server's own SpellAffect.dbc already
--   names 63611 as its target (row 918522), so only the link was missing. Both take effect at once: the core
--   recalculates permanent self-auras when a modifier comes or goes.
--   Side effect from Ascension's own data, worth knowing: the stock script also casts 63611 in Frost and Unholy
--   Presence with the talent (the tooltip's 2% there), and the +3 reaches it too, so that share becomes 5%.
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(31218, 31232, 2, 'WCME: Sinister Calling rank 3 applies its Gloomblade duration companion'),
(16086, 16545, 2, 'WCME: Rising Flames rank 1 applies its Fire Nova damage companion'),
(16544, 16546, 2, 'WCME: Rising Flames rank 2 applies its Fire Nova damage companion'),
(31682, 31695, 2, 'WCME: Empowering Frostbolt rank 1 applies its Frostbolt cast time companion'),
(31683, 31710, 2, 'WCME: Empowering Frostbolt rank 2 applies its Frostbolt cast time companion'),
(31684, 31711, 2, 'WCME: Empowering Frostbolt rank 3 applies its Frostbolt cast time companion'),
(51375, 51376, 2, 'WCME: Improved Blood Presence rank 5 applies its capstone healing companion'),
(51375, 51377, 2, 'WCME: Improved Blood Presence rank 5 applies its capstone damage companion');
