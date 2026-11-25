-- Single-Minded Fury (988256), the Ascension talent, and Righteous Fury's Fierce Block. Needs the build with patch
-- 55's "part 8" and "part 9" sections: without it the bindings name scripts the server does not have (it logs an
-- error for each and carries on) and nothing else changes. Safe to run again (000-reset removes WCME: links, owned
-- spell_proc rows and spell_wcme_ bindings). Read by hand on
-- 25 Nov 2026. Not tested in game: unverified until a player report or an automated test.
--
-- The talent did nothing: its effects are a half-second weapon check, a placeholder and a modifier type this core
-- does not have, all run by Ascension's own code. The core scripts only its own copy (1988256, a different design:
-- Slam hits with both weapons and all damage +5%). What the tooltip says, and the patch now does:
-- - While a one-handed weapon that is not a dagger is in each hand, the talent keeps 988258 on (the core's own copy
--   does the same with its companion). Off when the weapons change, or the talent goes.
-- - Mortal Strike, Overpower and Slam then deal 5% less damage (988258's amount) and are followed by an off-hand
--   attack: Ascension made an off-hand twin of each of them and of each elemental version (named "<ability>
--   (Off-hand)", e.g. 1003049 Mortal Strike, 1003050 Overpower, 1003052 Slam), and the follow-up casts the twin of
--   the ability that hit. The talent's class flags (Warrior 0x2200004) pick the abilities; only those with a twin are
--   followed up or penalised, 22 in all. Abilities that already trigger their own twin in their data (Hateful
--   Strike, Loa's Assault, Overwhelm: they strike with both weapons by themselves) are left out.
-- Proc rule for 988258: those class flags, melee spell damage done, on a hit, triggered spells allowed (stock Slam's
-- damage, 50783, is cast by Slam's script).
-- Righteous Fury (25780): its buff text promises a 60% higher chance to block Fierce Blow (975011, the CoA strike
-- creatures use on their target). That lives in a companion (986051, 6000 = 60.00%) nothing applied; now linked. The
-- core has no hook for a spell's block chance, so patch 55 part 9 adds one to Unit::isSpellBlocked; the bonus counts
-- only with a shield (no block chance, no bonus). The CoA copy of Righteous Fury (1125780) promises nothing of the
-- kind and is left alone. Without the build the link does nothing.
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(25780, 986051, 2, 'WCME: Righteous Fury applies its Fierce Block chance');

INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES ('spell_proc', 988258);
DELETE FROM `spell_proc` WHERE `SpellId` IN (988258);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(988258, 0, 4, 35651588, 0, 0, 16, 1, 2, 0, 2, 0, 0, 100, 0, 0);

INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(988256, 'spell_wcme_single_minded_fury'),
(988258, 'spell_wcme_single_minded_fury_follow_up');
