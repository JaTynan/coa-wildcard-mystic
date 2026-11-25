-- Spider Bomb Factory (289200), an Ascension Tinker build in the Wildcard pool. Needs the build with patch 55's
-- "part 10" section: without it the copied creatures carry script names the server does not have (it logs an error
-- and they stand idle) and the binding names a missing script. Safe to run again: the copies and their models are
-- deleted and made again here; 000-reset removes the owned spell_proc row and the spell_wcme_ binding. Read by hand
-- on 25 Nov 2026, with the live world data read for the two CoA creatures. Not tested in game: unverified until a
-- player report or an automated test.
--
-- What it should do (the tooltip): build a factory in front of you for 20 sec; meanwhile damaging spells and
-- abilities send 2 Spider Bombs from it, which run to your target and detonate for Fire damage, at most once every
-- 4 sec. What it did: nothing. The spell summons creature 289203, which our world data did not have, and the bombs
-- were Ascension's own code. The core's Tinker class has a working factory (467073) and Spider Bomb (226012), but
-- their script drops anyone who is not a Tinker, so they cannot be used as they are. Copies with scripts of their own:
-- - 289203 copies the CoA factory, script npc_wcme_spider_bomb_factory: stands still, and while it stands the
--   builder holds 289201, which brings the damaging hits to the patch (proc rule below: melee, ranged and magic
--   spell damage done, on a hit, not from triggered spells, once every 4 sec).
-- - 289204 copies the CoA Spider Bomb, script npc_wcme_spider_bomb: two per trigger, they run to the target and
--   detonate with the CoA Spider Bomb Explosion (801982), the player counting as its caster for the damage.
-- The copies are made by selecting the CoA rows into a temporary table, so every column carries over whatever this
-- database's creature_template holds. 289203 and 289204 were free (read from the live data, 25 Nov 2026).
DELETE FROM `creature_template` WHERE `entry` IN (289203, 289204);
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (289203, 289204);

DROP TEMPORARY TABLE IF EXISTS `wcme_tmp_creature_template`;
CREATE TEMPORARY TABLE `wcme_tmp_creature_template` SELECT * FROM `creature_template` WHERE `entry` IN (467073, 226012);
UPDATE `wcme_tmp_creature_template`
    SET `ScriptName` = IF(`entry` = 467073, 'npc_wcme_spider_bomb_factory', 'npc_wcme_spider_bomb'),
        `entry` = IF(`entry` = 467073, 289203, 289204);
INSERT INTO `creature_template` SELECT * FROM `wcme_tmp_creature_template`;
DROP TEMPORARY TABLE `wcme_tmp_creature_template`;

DROP TEMPORARY TABLE IF EXISTS `wcme_tmp_creature_template_model`;
CREATE TEMPORARY TABLE `wcme_tmp_creature_template_model` SELECT * FROM `creature_template_model` WHERE `CreatureID` IN (467073, 226012);
UPDATE `wcme_tmp_creature_template_model` SET `CreatureID` = IF(`CreatureID` = 467073, 289203, 289204);
INSERT INTO `creature_template_model` SELECT * FROM `wcme_tmp_creature_template_model`;
DROP TEMPORARY TABLE `wcme_tmp_creature_template_model`;

INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES ('spell_proc', 289201);
DELETE FROM `spell_proc` WHERE `SpellId` IN (289201);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(289201, 0, 0, 0, 0, 0, 65808, 1, 2, 0, 0, 0, 0, 100, 4000, 0);

INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(289201, 'spell_wcme_spider_bomb_factory_bombs');
