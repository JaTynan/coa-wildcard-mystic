-- Runs first, every time: one-off backups of the original tables, then removes every row this repo owns
-- (spell_linked_spell rows marked WCME:, and spell_dbc / spell_proc rows listed in wcme_owned), so the files
-- after this one put back exactly what the repo holds.
CREATE TABLE IF NOT EXISTS `wcme_backup_spell_linked_spell` AS SELECT * FROM `spell_linked_spell`;
CREATE TABLE IF NOT EXISTS `wcme_backup_spell_proc` AS SELECT * FROM `spell_proc`;
CREATE TABLE IF NOT EXISTS `wcme_owned` (`tbl` VARCHAR(32) NOT NULL, `id` INT NOT NULL, PRIMARY KEY (`tbl`, `id`));
DELETE FROM `spell_linked_spell` WHERE `comment` LIKE 'WCME:%';
DELETE `s` FROM `spell_dbc` `s` JOIN `wcme_owned` `o` ON `o`.`tbl` = 'spell_dbc' AND `o`.`id` = `s`.`ID`;
DELETE `p` FROM `spell_proc` `p` JOIN `wcme_owned` `o` ON `o`.`tbl` = 'spell_proc' AND `o`.`id` = `p`.`SpellId`;
DELETE FROM `wcme_owned`;
