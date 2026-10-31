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
-- Read by the patched world server's spell_wcme_enchant_action (patch mystic-enchants-actions).
CREATE TABLE IF NOT EXISTS `wcme_enchant_action` (`enchant_spell` INT UNSIGNED NOT NULL, `rule` TINYINT UNSIGNED NOT NULL,
    `spells` TEXT NOT NULL, `school_mask` INT UNSIGNED NOT NULL DEFAULT 0, `target_aura` TEXT NOT NULL, `requires_aura` TEXT NOT NULL,
    `chance` FLOAT NOT NULL DEFAULT 100, `cooldown_ms` INT UNSIGNED NOT NULL DEFAULT 0, `action` VARCHAR(24) NOT NULL,
    `action_spells` TEXT NOT NULL, `amount` INT NOT NULL DEFAULT 0, `comment` VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (`enchant_spell`, `rule`));
DELETE FROM `wcme_enchant_action`;
DELETE FROM `spell_script_names` WHERE `ScriptName` = 'spell_wcme_enchant_action';
DELETE `l` FROM `coa_mystic_enchant_aura_link` `l` JOIN `wcme_owned` `o` ON `o`.`tbl` = 'aura_link' AND `o`.`id` = `l`.`enchant_spell`;
DELETE FROM `wcme_owned`;
