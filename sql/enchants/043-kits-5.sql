-- Legendary kits, batch 5 (needs the build with this version of mystic-enchants-scripts.patch; no client patch change).
-- Mana Fiend (977870): +30% Intellect, Arcane damage turns the next auto attack into Manacharged Strike, Delirium (+10%
-- of Intellect as Arcane spell power per stack, no stack limit, no Arcane mana cost, no mana gain, growing drain),
-- Recovery below 20% mana returns the drained mana, Mana Fiend's Mind Focus taught.
-- Serpent Form (982400): Serpent Form, Serpent Strike, Puncture, Serpent Venom and Venomous Fury in place of the Cat Form
-- abilities (by level rank), the serpent model, Poisonous Strikes on auto attacks, Serpent Strike's poison buff, combo
-- point scaling for Serpent Venom and Venomous Fury.
-- Son of Gruul (984200): Hateful Strike, Ground Slam and Upheaval (by level rank), Hate charges, Seething Growth,
-- Petrification, Petrified and Shatter (with Lava Flows).
-- Steward of Eternity (986162): Align, Time-bind and Synchronize, energy drain, Temporal Distortion, Eternity, Time-bind
-- absorbing part of each hit and healing it back as Time-bound, Synchronize healing only Aligned or Time-bound targets and holding Align.
-- Swashbuckler: Bloodsail Captain (997127): Hammer the Gap, Panache and Blurred Blade (by level rank), En Garde! from
-- Mocking Blow, Captain's Resolve while Swashbuckling in Defensive Stance, Panache shortening Stagger, Blurred Blade's
-- counter-attack on dodge or parry (92802, once every 0.5 sec).
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 977870),
('spell_proc', 982400),
('spell_proc', 984200),
('spell_proc', 986162),
('spell_proc', 997127),
('spell_proc', 92802);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (977870, 982400, 984200, 986162, 997127);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (977876, 92787, 92788, 92789, 92790, 92791, 92792, 92793, 92794, 92795, 92796, 92797, 92798, 92799, 92800, 92802, 302055, 302056, 302057, 977870, 977873, 982400, 982401, 984200, 984213, 984226, 984649, 984650, 984651, 984652, 984653, 984654, 984655, 986162, 986163, 986164, 986165, 986168, 990218, 997127, 997746, 997747, 997748, 997749, 997750, 997751, 997752, 997753, 997754, 997756, 997757, 997758, 997759, 997760, 997761, 997762, 997763, 997764) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (977870, 982400, 984200, 986162, 997127, 92802);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(977870, 0, 0, 0, 0, 0, 65552, 0, 2, 0, 0, 0, 0, 100, 0, 0),
(982400, 0, 0, 0, 0, 0, 20, 0, 2, 0, 0, 0, 0, 100, 0, 0),
(984200, 0, 0, 0, 0, 0, 16, 0, 2, 0, 2, 0, 0, 100, 0, 0),
(986162, 0, 0, 0, 0, 0, 17408, 0, 2, 0, 0, 0, 0, 100, 0, 0),
(997127, 0, 0, 0, 0, 0, 16, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(92802, 0, 0, 0, 0, 0, 40, 0, 2, 48, 0, 0, 0, 100, 500, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(977870, 'spell_wcme_mana_fiend'),
(977873, 'spell_wcme_delirium_cost'),
(977876, 'spell_wcme_delirium'),
(990218, 'spell_wcme_mind_focus'),
(982400, 'spell_wcme_serpent_form'),
(982401, 'spell_wcme_serpent_shape'),
(997746, 'spell_wcme_serpent_venom'),
(997747, 'spell_wcme_serpent_venom'),
(997748, 'spell_wcme_serpent_venom'),
(997749, 'spell_wcme_serpent_venom'),
(997750, 'spell_wcme_serpent_venom'),
(997751, 'spell_wcme_serpent_venom'),
(997752, 'spell_wcme_serpent_venom'),
(997753, 'spell_wcme_serpent_venom'),
(997754, 'spell_wcme_serpent_venom'),
(997763, 'spell_wcme_serpent_venom'),
(997756, 'spell_wcme_venomous_fury'),
(997757, 'spell_wcme_venomous_fury'),
(997758, 'spell_wcme_venomous_fury'),
(997760, 'spell_wcme_venomous_fury'),
(997759, 'spell_wcme_venomous_fury'),
(997761, 'spell_wcme_venomous_fury'),
(997762, 'spell_wcme_venomous_fury'),
(302055, 'spell_wcme_venomous_fury'),
(302056, 'spell_wcme_venomous_fury'),
(302057, 'spell_wcme_venomous_fury'),
(997764, 'spell_wcme_venomous_fury'),
(984200, 'spell_wcme_son_of_gruul'),
(984226, 'spell_wcme_hateful_strike'),
(984649, 'spell_wcme_hateful_strike'),
(984650, 'spell_wcme_hateful_strike'),
(984651, 'spell_wcme_hateful_strike'),
(984652, 'spell_wcme_hateful_strike'),
(984653, 'spell_wcme_hateful_strike'),
(984654, 'spell_wcme_hateful_strike'),
(984655, 'spell_wcme_hateful_strike'),
(984213, 'spell_wcme_shatter'),
(986162, 'spell_wcme_steward_of_eternity'),
(986163, 'spell_wcme_steward_spell'),
(986164, 'spell_wcme_steward_spell'),
(986165, 'spell_wcme_steward_spell'),
(986164, 'spell_wcme_time_bind'),
(986168, 'spell_wcme_synchronize_heal'),
(997127, 'spell_wcme_swashbuckler'),
(92789, 'spell_wcme_panache'),
(92790, 'spell_wcme_panache'),
(92791, 'spell_wcme_panache'),
(92792, 'spell_wcme_panache'),
(92793, 'spell_wcme_panache'),
(92794, 'spell_wcme_panache'),
(92795, 'spell_wcme_panache'),
(92796, 'spell_wcme_panache'),
(92797, 'spell_wcme_panache'),
(92798, 'spell_wcme_panache'),
(92799, 'spell_wcme_panache'),
(92800, 'spell_wcme_panache'),
(92787, 'spell_wcme_blurred_blade'),
(92788, 'spell_wcme_blurred_blade'),
(92787, 'spell_wcme_blurred_blade_cast'),
(92788, 'spell_wcme_blurred_blade_cast'),
(92802, 'spell_wcme_blurred_blade_counter');
