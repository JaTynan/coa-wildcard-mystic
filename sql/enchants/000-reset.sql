-- Runs first, every time: a one-off backup of the original table, then removes every row this repo owns
-- (marked WCME: in the comment), so the files after this one put back exactly what the repo holds.
CREATE TABLE IF NOT EXISTS `wcme_backup_spell_linked_spell` AS SELECT * FROM `spell_linked_spell`;
DELETE FROM `spell_linked_spell` WHERE `comment` LIKE 'WCME:%';
