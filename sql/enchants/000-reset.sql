-- Runs first, every time: one-off backups of the original tables, then removes every row this repo owns
-- (spell_linked_spell rows marked WCME:, and spell_dbc / spell_proc rows listed in wcme_owned), so the files
-- after this one put back exactly what the repo holds.
CREATE TABLE IF NOT EXISTS `wcme_backup_spell_linked_spell` AS SELECT * FROM `spell_linked_spell`;
CREATE TABLE IF NOT EXISTS `wcme_backup_spell_proc` AS SELECT * FROM `spell_proc`;
CREATE TABLE IF NOT EXISTS `wcme_owned` (`tbl` VARCHAR(32) NOT NULL, `id` INT NOT NULL, PRIMARY KEY (`tbl`, `id`));
DELETE FROM `spell_linked_spell` WHERE `comment` LIKE 'WCME:%';
DELETE `s` FROM `spell_dbc` `s` JOIN `wcme_owned` `o` ON `o`.`tbl` = 'spell_dbc' AND `o`.`id` = `s`.`ID`;
DELETE `p` FROM `spell_proc` `p` JOIN `wcme_owned` `o` ON `o`.`tbl` = 'spell_proc' AND `o`.`id` = `p`.`SpellId`;
-- Tables read by the patched world server (from the build with the teach/override change); this repo owns
-- them outright, so they are emptied and refilled by the files after this one.
CREATE TABLE IF NOT EXISTS `wcme_enchant_teach` (`enchant_spell` INT UNSIGNED NOT NULL, `taught_spell` INT UNSIGNED NOT NULL,
    `comment` VARCHAR(255) NOT NULL DEFAULT '', PRIMARY KEY (`enchant_spell`));
CREATE TABLE IF NOT EXISTS `wcme_enchant_override` (`enchant_spell` INT UNSIGNED NOT NULL, `roll` TINYINT UNSIGNED NOT NULL,
    `comment` VARCHAR(255) NOT NULL DEFAULT '', PRIMARY KEY (`enchant_spell`));
DELETE FROM `wcme_enchant_teach`;
DELETE FROM `wcme_enchant_override`;
-- Read by the patched world server (patch 63-enchant-target-cooldowns): spells whose procs have a cooldown per target
-- plus a short shared one, instead of their spell_proc cooldown. Servers without the patch ignore it.
CREATE TABLE IF NOT EXISTS `wcme_proc_target_cooldown` (`spell_id` INT UNSIGNED NOT NULL, `target_cooldown_ms` INT UNSIGNED NOT NULL,
    `shared_cooldown_ms` INT UNSIGNED NOT NULL DEFAULT 100, `comment` VARCHAR(255) NOT NULL DEFAULT '', PRIMARY KEY (`spell_id`));
DELETE FROM `wcme_proc_target_cooldown`;
-- Read by the patched world server's spell_wcme_enchant_action (patch mystic-enchants-actions).
CREATE TABLE IF NOT EXISTS `wcme_enchant_action` (`enchant_spell` INT UNSIGNED NOT NULL, `rule` TINYINT UNSIGNED NOT NULL,
    `spells` TEXT NOT NULL, `school_mask` INT UNSIGNED NOT NULL DEFAULT 0, `target_aura` TEXT NOT NULL, `requires_aura` TEXT NOT NULL,
    `chance` FLOAT NOT NULL DEFAULT 100, `cooldown_ms` INT UNSIGNED NOT NULL DEFAULT 0, `action` VARCHAR(24) NOT NULL,
    `action_spells` TEXT NOT NULL, `amount` INT NOT NULL DEFAULT 0, `comment` VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (`enchant_spell`, `rule`));
DELETE FROM `wcme_enchant_action`;
-- Read by the patched world server's ability companions (patch 55, wcme_spell_companions): while a player knows
-- ability_spell they have the aura passive_spell. flags 1 = only with no weapon in the off hand.
CREATE TABLE IF NOT EXISTS `wcme_spell_companion` (`ability_spell` INT UNSIGNED NOT NULL, `passive_spell` INT UNSIGNED NOT NULL,
    `flags` INT UNSIGNED NOT NULL DEFAULT 0, `comment` VARCHAR(255) NOT NULL DEFAULT '', PRIMARY KEY (`ability_spell`, `passive_spell`));
DELETE FROM `wcme_spell_companion`;
DELETE FROM `spell_script_names` WHERE `ScriptName` LIKE 'spell\_wcme\_%';
DELETE `l` FROM `coa_mystic_enchant_aura_link` `l` JOIN `wcme_owned` `o` ON `o`.`tbl` = 'aura_link' AND `o`.`id` = `l`.`enchant_spell`;
-- Extra rules we add to the core's own Mystic Enchant rule table (file 170): marked by a comment starting WCME:.
DELETE FROM `coa_mystic_enchant_proc` WHERE `comment` LIKE 'WCME:%';
-- Bindings to the core's own scripts that we add (files 173 and 178), listed in wcme_owned as core_script.
DELETE `s` FROM `spell_script_names` `s` JOIN `wcme_owned` `o` ON `o`.`tbl` = 'core_script' AND `s`.`ScriptName` IN ('spell_ascension_mystic_enchant_proc', 'spell_mage_living_bomb') AND `o`.`id` = `s`.`spell_id`;
-- Spell power and attack power coefficients we add (file 178), listed in wcme_owned as spell_bonus_data.
DELETE `b` FROM `spell_bonus_data` `b` JOIN `wcme_owned` `o` ON `o`.`tbl` = 'spell_bonus_data' AND `o`.`id` = `b`.`entry`;
-- Extra SpellAffect rows (modifier -> named target spell), loaded into the server's SpellAffect data by the build
-- with patch mystic-enchants-spellaffect-sql. A row here REPLACES the SpellAffect.dbc row with the same ID,
-- and the client data already uses some IDs from 900000 up (901388-901397, scattered ones between 912000 and 938443, 975170-975176,
-- 999997-999999; checked 23 Nov 2026). Free blocks in use: 900000-908890 less 901388-901397 (file 011), 950000-950017
-- (012), 951000-951009 (011). Take new IDs from 950018-975169 and check them against SpellAffect.dbc first.
CREATE TABLE IF NOT EXISTS `wcme_spellaffect_dbc` (`ID` INT UNSIGNED NOT NULL, `ModifierSpellID` INT UNSIGNED NOT NULL,
    `AffectedSpellID` INT UNSIGNED NOT NULL, PRIMARY KEY (`ID`));
DELETE FROM `wcme_spellaffect_dbc`;
DELETE FROM `wcme_owned`;
