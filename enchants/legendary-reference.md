# Legendary Mystic Enchants: reference

Every legendary on the archived Ascension builder (snapshot of 14 June 2026, area-52 realm), matched to the copies in
our client and what our server does with each. The tooltip text itself is Ascension's and is not kept here; a private
copy lives on the game server (`C:\Games\CoA Server\ascension-mystic-enchants.json`). Built from that copy, the
tracker and the November 2026 deep audit; update a row when an enchant is fixed or tested.

170 legendaries on the site, 199 copies in our client (several enchants have more than one version).

**Status** of each copy (refreshed by `scripts/legendary_history.py`; pull requests in brackets):
- **changed, awaiting in-game test**: fixed in the pull requests shown; nobody has reported testing it yet.
- **tested (see test notes)** or **changed after its last test, retest needed**: a result is recorded in
  `enchants/test-checklist.csv` or the tracker.
- **works from its data** / **handled by the core**: checked; nothing needed changing.
- **unchanged: working (audit)**: the audit found nothing missing; never changed and not yet tested in game.
- **left as is (decision)**: deliberately not changed.

The full history of each copy (commits, pull requests, builds, the date it went live, tests, assumptions and sources)
is in `enchants/legendary-history.csv` and `enchants/legendary-notes.md`.


| Site ID | Enchant | Worldforged | Our copies |
|---|---|---|---|
| 84805 | Abiding Fel Energy |  | 84805: changed, awaiting in-game test (#167) |
| 991030 | Adorned by Light |  | 991030: works (checked in #171) (#26) |
| 81448 | Aimed Explosive Shot |  | 81448: changed, awaiting in-game test (through its shot 81449, #171) |
| 84512 | Amal'thazad's Curse |  | 84512: changed, awaiting in-game test (#164) |
| 977771 | Ambidextrous |  | 977771: changed, awaiting in-game test (#165 #166)<br>1572215: unchanged: working (audit) |
| 902185 | Apostle of Eredath |  | 902185: changed, awaiting in-game test (#31 #175) |
| 978227 | Arcane Gunslinger |  | 978227: changed, awaiting in-game test (#23) |
| 997055 | Arcane Thunder Seer | yes | 997055: changed, awaiting in-game test (#166) |
| 965334 | Assuaging Shadows |  | 965334: changed, awaiting in-game test (#175)<br>1571129: changed, awaiting in-game test (#164) |
| 978235 | Astral Bomber |  | 978235: changed, awaiting in-game test (#175) |
| 832617 | Astral Storm |  | 832617: changed after its last test (2026-11-03), retest needed (#26 #175) |
| 81479 | Astral Tempest |  | 81479: changed, awaiting in-game test (#167) |
| 81497 | Atonement |  | 81497: changed, awaiting in-game test (#20)<br>1567777: unchanged: working (audit) |
| 84459 | Battle Fervor |  | 84459: changed, awaiting in-game test (#23) |
| 81258 | Battlemage |  | 81258: changed, awaiting in-game test (#20) |
| 978237 | Beast and Blade |  | 978237: changed, awaiting in-game test (#173) |
| 81251 | Benevolent Crusader |  | 81251: changed, awaiting in-game test (#165 #166) |
| 965862 | Blademaster |  | 965862: changed, awaiting in-game test (#167) |
| 965476 | Blessing of the Divines |  | 965476: changed, awaiting in-game test (#167)<br>1571465: unchanged: working (audit) |
| 977906 | Blood and Guts |  | 977906: changed, awaiting in-game test (#23 #175) |
| 983070 | Blood for the Blood God | yes | 983070: changed, awaiting in-game test (#173) |
| 978219 | Blood Venom |  | 978219: changed, awaiting in-game test (#165) |
| 965280 | Blooming Growth |  | 965280: changed, awaiting in-game test (#164) |
| 965305 | Booming Thunder |  | 965305: changed, awaiting in-game test (core patch 71)<br>1570759: unchanged: working (audit) |
| 978724 | Bulwark |  | 978724: changed, awaiting in-game test (#26)<br>1590962: changed, awaiting in-game test (#26) |
| 990190 | Burning Darkness |  | 990190: changed, awaiting in-game test (#165) |
| 986008 | Carnage Incarnate |  | 986008: changed, awaiting in-game test (#26)<br>1590982: changed, awaiting in-game test (#26) |
| 86460 | Cauterizing Flames |  | 86460: changed, awaiting in-game test (#175) |
| 986000 | Champion of Justice |  | 986000: changed, awaiting in-game test (#175) |
| 301000 | Circle of Life | yes | 301000: changed on an unmerged branch (#23 #164) |
| 979740 | Compound Power |  | 979740: changed on an unmerged branch (#20 #171) |
| 965295 | Consecrated Strikes |  | 965295: changed, awaiting in-game test (#166) |
| 414080 | Consumed by Fire |  | 414080: unchanged: working (audit) |
| 81407 | Controlled Burn |  | 81407: changed, awaiting in-game test (#165 #166) |
| 99634 | Corrupted Bear Form |  | 99634: changed, awaiting in-game test (#175) |
| 84529 | Crazy Cultist |  | 84529: changed, awaiting in-game test (#167)<br>1568195: changed, awaiting in-game test (#167) |
| 977727 | Crimson Champion |  | 977727: tested (see test notes) (#26) |
| 86576 | Cryotherapist | yes | 86576: changed, awaiting in-game test (#20) |
| 982806 | Curse of Arugal | yes | 982806: changed, awaiting in-game test (#165 #166 #169) |
| 980056 | Dark Apotheosis | yes | 980056: unchanged: working (audit) |
| 997115 | Dark Ranger | yes | 997115: changed, awaiting in-game test (#175) |
| 978209 | Dark Surgeon |  | 978209: changed, awaiting in-game test (#20 #175) |
| 983180 | Darkmaster | yes | 983180: changed, awaiting in-game test (#175) |
| 965292 | Deadly Bite |  | 965292: changed, awaiting in-game test (#23 #164 #166 #169) |
| 965501 | Deathbringer |  | 965501: changed, awaiting in-game test (#164) |
| 997047 | Defias Gunslinger | yes | 997047: changed, awaiting in-game test (#175) |
| 977864 | Demolisher |  | 977864: changed, awaiting in-game test (#20 #175) |
| 965313 | Demonic Influence |  | 965313: handled (PvE by its data, PvP part by patch 65) |
| 990130 | Demonic Persistence |  | 990130: changed, awaiting in-game test (#173 #177) |
| 84531 | Deranged Druid |  | 84531: changed, awaiting in-game test (#167)<br>1568216: changed, awaiting in-game test (#167) |
| 982980 | Disciple of Arugal | yes | 982980: changed, awaiting in-game test (#175) |
| 978234 | Disciple of the Tides |  | 978234: changed, awaiting in-game test (#23 #175) |
| 965421 | Divine Purpose |  | 965421: changed, awaiting in-game test (#164 #166) |
| 81472 | Dominant Word: Shield |  | 81472: changed, awaiting in-game test (#20) |
| 978742 | Double Down |  | 978742: changed, awaiting in-game test (#165) |
| 954252 | Dragon Warrior |  | 954252: changed, awaiting in-game test (#23 #175) |
| 84533 | Eccentric Elementalist |  | 84533: changed, awaiting in-game test (#167)<br>1568237: changed, awaiting in-game test (#167) |
| 986234 | Edge of Fury | yes | 986234: changed, awaiting in-game test (#175) |
| 81116 | Eldritch Knight |  | 81116: changed, awaiting in-game test (#165 #166) |
| 978229 | Elemental Assassin |  | 978229: changed on an unmerged branch (#23 #171 #177) |
| 978231 | Elemental Destruction |  | 978231: changed, awaiting in-game test (#23) |
| 990200 | Elemental Lord |  | 990200: changed, awaiting in-game test (#173) |
| 965311 | Endless Agony |  | 965311: changed, awaiting in-game test (#23)<br>1570908: changed, awaiting in-game test (#164) |
| 953308 | Evoker |  | 953308: changed, awaiting in-game test (#20 #164 #166) |
| 92438 | Fel Charge |  | 92438: changed, awaiting in-game test (#26) |
| 984165 | Fel Corruption | yes | 984165: changed, awaiting in-game test (#175) |
| 84806 | Fel Strike |  | 84806: changed, awaiting in-game test (#26 #167) |
| 101086 | Felborne |  | 101086: changed, awaiting in-game test (#167) |
| 965301 | Festering Wound |  | 965301: unchanged: working (audit)<br>1570737: unchanged: working (audit) |
| 978208 | Fingers of Death |  | 978208: changed, awaiting in-game test (#165) |
| 978220 | Fire Watch |  | 978220: changed on an unmerged branch (#23 #171) |
| 965293 | Flame On! |  | 965293: changed, awaiting in-game test (#171) |
| 984448 | Flashpoint Operative |  | 984448: changed, awaiting in-game test (#164) |
| 954326 | Forbidden Technique |  | 954326: changed, awaiting in-game test (#26 #175) |
| 954262 | Frost Bomb |  | 954262: changed, awaiting in-game test (#26 #165)<br>1590912: changed, awaiting in-game test (#26 #165) |
| 965504 | Frost Lich |  | 965504: changed, awaiting in-game test (#164) |
| 980673 | Frozen Chaos |  | 980673: changed on an unmerged branch (#20 #171) |
| 977810 | Fury of the Titans |  | 977810: changed, awaiting in-game test (#175) |
| 997124 | Grove Ranger | yes | 997124: changed, awaiting in-game test (#175) |
| 81520 | Growing Light |  | 81520: changed, awaiting in-game test (#175) |
| 81467 | Guardians of the Grove |  | 81467: changed, awaiting in-game test (#26)<br>1567585: handled by the core (checked 2026-11-16) (#177) |
| 954077 | Guerilla Trapper |  | 954077: unchanged: working (audit) |
| 983135 | Gurubashi Berserker | yes | 983135: changed, awaiting in-game test (#173) |
| 965505 | Harbinger of Flame |  | 965505: changed, awaiting in-game test (#164) |
| 990020 | Harbinger of Pestilence |  | 990020: changed, awaiting in-game test (#177) |
| 977700 | Heavyweight |  | 977700: changed, awaiting in-game test (#172)<br>1571904: unchanged: working (audit) |
| 965858 | Holy Ascension |  | 965858: unchanged: working (audit)<br>1571664: unchanged: working (audit) |
| 965473 | Holy Radiance |  | 965473: unchanged: working (audit)<br>1571400: unchanged: working (audit) |
| 977921 | Holy Spirit |  | 977921: changed, awaiting in-game test (#165) |
| 81190 | Holy Supernova |  | 81190: changed, awaiting in-game test (#26) |
| 978217 | Hoplite |  | 978217: changed, awaiting in-game test (#175) |
| 979765 | Hot Hands |  | 979765: changed, awaiting in-game test (#174 #177)<br>1575104: changed, awaiting in-game test (#174 #177) |
| 954359 | Hydromancer |  | 954359: changed, awaiting in-game test (#20) |
| 965294 | Ice Barrage |  | 965294: changed, awaiting in-game test (#20)<br>1570523: changed, awaiting in-game test (#20) |
| 977764 | Ice Lash |  | 977764: changed, awaiting in-game test (#165 #166) |
| 978226 | Knight of the Eclipse |  | 978226: changed, awaiting in-game test (#20) |
| 417700 | Lava Sweep |  | 417700: changed, awaiting in-game test (#26 #175)<br>1590905: changed, awaiting in-game test (#26) |
| 984117 | Legacy of the Arcanist | yes | 984117: changed, awaiting in-game test (#175) |
| 997129 | Lei Shen's Legacy | yes | 997129: changed, awaiting in-game test (#175) |
| 954044 | Locust Ranger |  | 954044: changed, awaiting in-game test (#175 #177) |
| 81404 | Low Tide |  | 81404: changed, awaiting in-game test (#172) |
| 978218 | Lucifur |  | 978218: unchanged: working (audit) |
| 977870 | Mana Fiend |  | 977870: changed, awaiting in-game test (#175) |
| 84752 | Martial Crescendo |  | 84752: changed, awaiting in-game test (#165 #166) |
| 980046 | Master of Shadows |  | 980046: changed, awaiting in-game test (#173) |
| 965309 | Mending Tide |  | 965309: changed, awaiting in-game test (#174)<br>1570865: unchanged: working (audit) |
| 978228 | Midnight Flames |  | 978228: changed, awaiting in-game test (#23) |
| 965307 | Molten Earth |  | 965307: unchanged: working (audit) |
| 965283 | Nature's Fervor |  | 965283: changed, awaiting in-game test (#164 #166)<br>1570238: changed, awaiting in-game test (#20 #164) |
| 979748 | One With The Light |  | 979748: changed, awaiting in-game test (#171)<br>1575034: changed, awaiting in-game test (#164 #171) |
| 979240 | Oracle of the Eclipse | yes | 979240: changed, awaiting in-game test (#175) |
| 977710 | Overflow |  | 977710: changed on an unmerged branch (#20 #175)<br>1571951: changed on an unmerged branch (#20 #175) |
| 81119 | Overheating |  | 81119: changed, awaiting in-game test (#171) |
| 81122 | Overloaded Froststorm |  | 81122: changed, awaiting in-game test (#167) |
| 956445 | Paratrooper |  | 956445: changed, awaiting in-game test (#26) |
| 81399 | Plague Bearer |  | 81399: changed, awaiting in-game test (#165) |
| 986033 | Prayer of Preservation |  | 986033: changed, awaiting in-game test (#175) |
| 977802 | Predator's Wrath |  | 977802: changed, awaiting in-game test (#174) |
| 977717 | Primordial Fury |  | 977717: changed, awaiting in-game test (#165 #166) |
| 979796 | Prophet of Wrath |  | 979796: changed, awaiting in-game test (#171) |
| 977713 | Pure Shadow |  | 977713: unchanged: working (audit) |
| 84508 | Purification By Light |  | 84508: changed, awaiting in-game test (#164) |
| 977817 | Razor Claws |  | 977817: changed, awaiting in-game test (#165) |
| 986052 | Relentless |  | 986052: changed, awaiting in-game test (#173) |
| 81298 | Righteous Flames |  | 81298: changed, awaiting in-game test (#175) |
| 965502 | Righteous Zealot |  | 965502: changed, awaiting in-game test (#164) |
| 965937 | Seed of Life |  | 965937: changed, awaiting in-game test (#23)<br>1571863: unchanged: working (audit) |
| 84515 | Seething Flames |  | 84515: changed, awaiting in-game test (#164) |
| 982400 | Serpent Form | yes | 982400: changed, awaiting in-game test (#175) |
| 977967 | Shadow Counter |  | 977967: changed, awaiting in-game test (#26) |
| 965299 | Shadow Visions |  | 965299: changed, awaiting in-game test (#167)<br>1570700: changed on an unmerged branch (#18 #167) |
| 990055 | Snowblind |  | 990055: changed, awaiting in-game test (#174) |
| 81102 | Social Distancing |  | 81102: changed, awaiting in-game test (#177) |
| 984200 | Son of Gruul | yes | 984200: changed, awaiting in-game test (#175) |
| 81168 | Soul of The Warden |  | 81168: unchanged: working (audit) |
| 978233 | Spell Shredder |  | 978233: changed, awaiting in-game test (#173) |
| 965503 | Spell Slinger |  | 965503: changed, awaiting in-game test (#23 #164) |
| 986162 | Steward of Eternity | yes | 986162: changed, awaiting in-game test (#175) |
| 977991 | Stormborn |  | 977991: changed, awaiting in-game test (#171) |
| 965500 | Stormbringer |  | 965500: changed, awaiting in-game test (#164) |
| 977928 | Stormhammer |  | 977928: works (checked in #171) (#26) |
| 997127 | Swashbuckler: Bloodsail Captain | yes | 997127: changed, awaiting in-game test (#175) |
| 954424 | Templar of Flame |  | 954424: changed, awaiting in-game test (#20 #172) |
| 977972 | Temporal Shift |  | 977972: changed, awaiting in-game test (#174) |
| 983739 | Thermal Void | yes | 983739: changed, awaiting in-game test (#26 #171) |
| 978236 | Thunder Slam |  | 978236: changed, awaiting in-game test (#165) |
| 954074 | Tidecaller |  | 954074: changed, awaiting in-game test (#164) |
| 965245 | Time Warp |  | 965245: changed, awaiting in-game test (#26 #174) |
| 954067 | Titanic Mutilate |  | 954067: changed, awaiting in-game test (#164 #166) |
| 84750 | Tools of War |  | 84750: changed, awaiting in-game test (#165 #166) |
| 965282 | Total Eclipse |  | 965282: unchanged: working (audit) |
| 86438 | Tree of Wrath |  | 86438: changed, awaiting in-game test (#26 #175) |
| 977824 | Twilight Paragon |  | 977824: changed, awaiting in-game test (#165 #166)<br>1572527: unchanged: working (audit) |
| 84506 | Unbounded Deathbringer |  | 84506: changed, awaiting in-game test (#164) |
| 84510 | Unbounded Spell Slinger |  | 84510: changed, awaiting in-game test (#23 #164) |
| 978727 | Unchained |  | 978727: changed, awaiting in-game test (#23) |
| 978721 | Undaunted |  | 978721: changed, awaiting in-game test (#165) |
| 965288 | Unrelenting Wrath |  | 965288: changed, awaiting in-game test (#167) |
| 997126 | Vampire Lord | yes | 997126: changed, awaiting in-game test (#175) |
| 902122 | Verdant Convergence | yes | 902122: changed, awaiting in-game test (#31 #175) |
| 965442 | Wacky Wizardry |  | 965442: changed, awaiting in-game test (#167)<br>1571306: changed, awaiting in-game test (#167) |
| 965337 | Warcry |  | 965337: changed, awaiting in-game test (#26 #164) |
| 997113 | Warden of Demonreach | yes | 997113: changed, awaiting in-game test (#175) |
| 965445 | Whispers of the Old Gods |  | 965445: changed, awaiting in-game test (#23 #169) |
| 978202 | White Walker |  | 978202: changed, awaiting in-game test (#175) |
| 965315 | Wild Felfire |  | 965315: unchanged: working (audit) |
| 978232 | Wind Rager |  | 978232: changed, awaiting in-game test (#20) |
| 81470 | Words of Healing |  | 81470: changed, awaiting in-game test (#165 #166) |
| 902137 | Zandalari Windreaver | yes | 902137: changed, awaiting in-game test (#31 #175) |
| 84527 | Zany Zealot |  | 84527: changed, awaiting in-game test (#167)<br>1568174: changed, awaiting in-game test (#167) |

## Legendaries in our client that the site does not list

106 copies. Older or removed Ascension enchants, so there is no tooltip to check them against; their own spell
text in our client is the only record.

| Our ID | Enchant | Status |
|---|---|---|
| 1134967 | Affliction Mastery | unchanged: working (audit) |
| 1398218 | Air Ascendance | unchanged: working (audit) |
| 1134962 | Arcane Mastery | unchanged: working (audit) |
| 1398224 | Arcane Orb | unchanged: working (audit) |
| 1100170 | Arcane Reverberation | changed, awaiting in-game test (#175) |
| 1582341 | Armor of Faith | changed, awaiting in-game test (#20) |
| 1134995 | Arms Mastery | unchanged: working (audit) |
| 1143164 | Aspect of the Fox | changed, awaiting in-game test (#177) |
| 1134972 | Assassination Mastery | unchanged: working (audit) |
| 1134979 | Balance Mastery | unchanged: working (audit) |
| 1180019 | Bane of Havoc | changed, awaiting in-game test (#174) |
| 1398205 | Barbed Shot | unchanged: working (audit) |
| 1579308 | Barrage Overload | unchanged: working (audit) |
| 1134987 | Beast Mastery | unchanged: working (audit) |
| 1181400 | Blazing Flame | changed, awaiting in-game test (#171) |
| 1570395 | Blood Tracker: Deadly Bite | changed, awaiting in-game test (#164) |
| 1398215 | Bloodbath | changed, awaiting in-game test (#26 #175) |
| 1180500 | Cataclysmic Burst | unchanged: working (audit) |
| 1181330 | Celestial Power | unchanged: working (audit) |
| 1589486 | Chasin' the Rush | unchanged: working (audit) |
| 1398174 | Chosen of Elune | changed, awaiting in-game test (#26) |
| 1186362 | Colossus Smash | changed, awaiting in-game test (#26) |
| 1134973 | Combat Mastery | unchanged: working (audit) |
| 1573649 | Cremation | tested (see test notes) (#26) |
| 1572131 | Crimson Defense | changed, awaiting in-game test (#172) |
| 1398214 | Crimson Hunger | unchanged: working (audit) |
| 1570995 | Demonic Reoccurence | changed, awaiting in-game test (#18 #177) |
| 1134965 | Demonology Mastery | changed, awaiting in-game test (#171) |
| 1134964 | Destruction Mastery | unchanged: working (audit) |
| 1134969 | Discipline Mastery | works from its data (checked in #171 and again 2026-11-16) (#177) |
| 1398178 | Divine Star | unchanged: working (audit) |
| 1590910 | Dragon Roar | changed, awaiting in-game test (#26 #175) |
| 1134980 | Earthen Guardian Mastery | unchanged: working (audit) |
| 1186386 | Efflorescence | unchanged: working (audit) |
| 1134981 | Elemental Mastery | unchanged: working (audit) |
| 1584825 | Enduring Aegis | unchanged: working (audit) |
| 1134983 | Enhancement Mastery | unchanged: working (audit) |
| 1398164 | Enslave Demon | changed, awaiting in-game test (#26) |
| 1398216 | Execution Sentence | unchanged: working (audit) |
| 1568152 | Explosive Charge | handled by the core (checked 2026-11-18) (#177) |
| 1584001 | Expunge | unchanged: working (audit) |
| 1154364 | Feeding the Abyss | changed, awaiting in-game test (#175) |
| 1180240 | Feral Frenzy | changed, awaiting in-game test (#26) |
| 1134976 | Feral Mastery | unchanged: working (audit) |
| 1134960 | Fire Mastery | unchanged: working (audit) |
| 1398169 | Flame Ascendance | changed, awaiting in-game test (#177) |
| 1591051 | Flare Strike | changed, awaiting in-game test (#26) |
| 1586133 | Flow of Life | unchanged: working (audit) |
| 1134961 | Frost Mastery | changed, awaiting in-game test (#171) |
| 1398171 | Frozen Orb | unchanged: working (audit) |
| 1134994 | Fury Mastery | works from its data (checked 2026-11-16) (#177) |
| 1181280 | Fury Unleashed | unchanged: working (audit) |
| 1277670 | Gift of Light | changed, awaiting in-game test (#175) |
| 1180850 | Gladiator Stance | unchanged: working (audit) |
| 1180300 | Glimmer of Light | changed, awaiting in-game test (#18) |
| 1134977 | Guardian Mastery | unchanged: working (audit) |
| 1180100 | Guardian of Ancient Kings | unchanged: working (audit) |
| 1398211 | Halo | unchanged: working (audit) |
| 1591108 | Hammerstorm | unchanged: working (audit) |
| 1398206 | Hand of Gul'dan | works from its data (checked 2026-11-16) (#177) |
| 1398222 | Healing Rain | changed, awaiting in-game test (#26) |
| 1134968 | Holy Mastery | unchanged: working (audit) |
| 1134990 | Holy Mastery | unchanged: working (audit) |
| 1554908 | Holy Templar | changed, awaiting in-game test (#175) |
| 1569697 | Hydromancer: Water Bolt | changed, awaiting in-game test (#26 #171) |
| 1180220 | Incarnation: King of the Jungle | unchanged: working (audit) |
| 1398180 | Ironfur | unchanged: working (audit) |
| 1591097 | Kingsbane | unchanged: working (audit) |
| 1591146 | Light of the Guardian | changed, awaiting in-game test (#26) |
| 1134985 | Marksmanship Mastery | unchanged: working (audit) |
| 1398172 | Meteor | unchanged: working (audit) |
| 1180440 | Nether Portal | changed, awaiting in-game test (#175) |
| 1133070 | Powershot | unchanged: working (audit) |
| 1572260 | Predator's Wrath: Wrathful Strikes | handled by the core (checked 2026-11-16) (#177) |
| 1134989 | Protection Mastery | unchanged: working (audit) |
| 1134996 | Protection Mastery | unchanged: working (audit) |
| 1398220 | Raging Blow | tested (see test notes) (#26) |
| 1143179 | Ravager | unchanged: working (audit) |
| 1134978 | Restoration Mastery | unchanged: working (audit) |
| 1134982 | Restoration Mastery | unchanged: working (audit) |
| 1134991 | Retribution Mastery | unchanged: working (audit) |
| 1398179 | Roll the Bones | unchanged: working (audit) |
| 1180009 | Rune of Power | unchanged: working (audit) |
| 1587050 | Rush of Blood | changed, awaiting in-game test (#165 #166) |
| 1180002 | Shadow Blades | changed, awaiting in-game test (#26 #171) |
| 1572059 | Shadow Crash | changed, awaiting in-game test (#26) |
| 1134970 | Shadow Mastery | unchanged: working (audit) |
| 1585038 | Sinister Flurry | changed, awaiting in-game test (#23) |
| 1180480 | Soul Erosion | changed on an unmerged branch (#171) |
| 1398159 | Soul Harvest | changed, awaiting in-game test (#175) |
| 1591060 | Spirit of the Forest | changed, awaiting in-game test (#26) |
| 1180059 | Stampede | unchanged: working (audit) |
| 1590930 | Storm Bolt | unchanged: working (audit) |
| 1181360 | Stormbound Instinct | changed, awaiting in-game test (#175) |
| 1134974 | Subtlety Mastery | unchanged: working (audit) |
| 1591061 | Sunfire | unchanged: working (audit) |
| 1134986 | Survival Mastery | unchanged: working (audit) |
| 1398163 | Tame Dragonkin | tested (see test notes) (#26) |
| 1398162 | Tether Elemental | tested (see test notes) (#26) |
| 1591076 | Touch of the Magi | changed, awaiting in-game test (#26 #174) |
| 1583831 | Transcendental Embrace | changed, awaiting in-game test (core patch 71) (#164) |
| 1180460 | Twist of Faith | unchanged: working (audit) |
| 1398184 | Void Eruption | changed, awaiting in-game test (#175) |
| 1571327 | Void Herald: Whispers of the Old Gods | unchanged: working (audit) |
| 1760200 | Wind Lash | changed, awaiting in-game test (#175) |
| 1544910 | Wraithweaver: Shadow Orbs | changed on an unmerged branch (#175) |

Copy totals (all 305): changed, awaiting in-game test: 199, unchanged: working: 81, changed on an unmerged branch: 10, tested: 5, works from its data: 3, handled by the core: 3, works: 2, changed after its last test: 1, handled: 1.
