-- Legendary kits, batch 4 (needs the build with this version of mystic-enchants-scripts.patch and
-- patches/67-hoplite-polearm-shield.ps1; no client patch change).
-- Holy Templar (1554908): Templar's Verdict and Word of Glory taught, the "3 Holy Power" marker kept in step with Holy
-- Power, both abilities spend 3 (gaining Holy Power stays with the core's own proc rows for 1554908).
-- Hoplite (978217): Shield Strike, Thrust and Javelin in place of Shield Slam, Sinister Strike and Heroic Strike,
-- Flurry of Spears taught with Siegebreaker, Phalanx Stance in Battle Stance (needed by those abilities), Phalanx
-- Strike, Shield Strike's Bloodrage cooldown and Spear Mastery, Flurry of Spears per-combo-point damage, Colossus Smash
-- ripping out the Javelin.
-- Lei Shen's Legacy (997129): Storm Smash, Thunder Hide and Voltaic Bite in place of Thunder Clap, Lightning Shield and
-- Stormstrike, Volatile Discharge from Bear abilities, the Chain Lightning discharge into Thunder Hide charges, Thunder
-- Hide only in Bear Form and one charge every 3 sec (92815), Storm Smash's extra threat.
-- Locust Ranger (954044): Locust Shot in place of Steady Shot, Chimera Shot cooldown, Wild Quiver from Chimera Shot and
-- Toxic Surge, Wild Locust Swarm, Toxic Ammo, Deadly Poison doses and Viper Sting's Toxic Surge.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 978217),
('spell_proc', 997129),
('spell_proc', 92815),
('spell_proc', 954044);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (978217, 997129, 954044);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (1554908, 1554911, 1554912, 978217, 978569, 978533, 982250, 901200, 901201,
  997129, 92815, 92806, 954044) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (978217, 997129, 92815, 954044);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(978217, 0, 0, 0, 0, 0, 66576, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(997129, 0, 0, 0, 0, 0, 16, 0, 2, 0, 2, 0, 0, 100, 0, 0),
(92815, 0, 0, 0, 0, 0, 139964, 0, 2, 0, 0, 0, 0, 100, 3000, 3),
(954044, 0, 0, 0, 0, 0, 66816, 0, 3, 0, 2, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(1554908, 'spell_wcme_holy_templar'),
(1554911, 'spell_wcme_holy_power_spender'),
(1554912, 'spell_wcme_holy_power_spender'),
(978217, 'spell_wcme_hoplite'),
(978569, 'spell_wcme_hoplite_ability'),
(978533, 'spell_wcme_hoplite_ability'),
(982250, 'spell_wcme_hoplite_ability'),
(901200, 'spell_wcme_hoplite_ability'),
(901200, 'spell_wcme_flurry_of_spears'),
(901201, 'spell_wcme_flurry_of_spears_strike'),
(997129, 'spell_wcme_lei_shens_legacy'),
(92815, 'spell_wcme_thunder_hide_cast'),
(92806, 'spell_wcme_storm_smash'),
(954044, 'spell_wcme_locust_ranger');
