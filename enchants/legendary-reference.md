# Legendary Mystic Enchants: reference

Every legendary on the archived Ascension builder (snapshot of 14 June 2026, area-52 realm), matched to the copies in
our client and what our server does with each. The tooltip text itself is Ascension's and is not kept here; a private
copy lives on the game server (`C:\Games\CoA Server\ascension-mystic-enchants.json`). Built from that copy, the
tracker and the November 2026 deep audit; update a row when an enchant is fixed or tested.

170 legendaries on the site, 199 copies in our client (several enchants have more than one version).

**Status** of each copy:
- **fixed, untested**: changed by one of the 015–019 enchant files or the enchant scripts; waiting for in-game testing.
- **looks complete (audit)**: the deep audit found nothing missing; not yet tested in game.
- **broken, needs code**: the deep audit found a mechanic the server has no code for.
- other wording is the deep audit's verdict for that copy.

Numbers in brackets are the SQL files in `sql/enchants/` that touch the copy. ✓ means checked against the builder tooltip.

| Site ID | Enchant | Worldforged | Our copies |
|---|---|---|---|
| 84805 | Abiding Fel Energy |  | 84805: fixed, untested (018) ✓ |
| 991030 | Adorned by Light |  | 991030: part broken (007) |
| 81448 | Aimed Explosive Shot |  | 81448: broken, needs code |
| 84512 | Amal'thazad's Curse |  | 84512: fixed, untested (015) ✓ |
| 977771 | Ambidextrous |  | 977771: fixed, untested (016, 017) ✓<br>1572215: looks complete (audit) |
| 902185 | Apostle of Eredath |  | 902185: broken, needs code (011) |
| 978227 | Arcane Gunslinger |  | 978227: looks complete (audit) (004) |
| 997055 | Arcane Thunder Seer | yes | 997055: fixed, untested (017) |
| 965334 | Assuaging Shadows |  | 965334: broken, needs code<br>1571129: fixed, untested (015) ✓ |
| 978235 | Astral Bomber |  | 978235: broken, needs code |
| 832617 | Astral Storm |  | 832617: broken, needs code (006) |
| 81479 | Astral Tempest |  | 81479: fixed, untested (018) ✓ |
| 81497 | Atonement |  | 81497: looks complete (audit) (003)<br>1567777: looks complete (audit) |
| 84459 | Battle Fervor |  | 84459: looks complete (audit) (004) |
| 81258 | Battlemage |  | 81258: looks complete (audit) (003) |
| 978237 | Beast and Blade |  | 978237: broken, needs code |
| 81251 | Benevolent Crusader |  | 81251: fixed, untested (016, 017) ✓ |
| 965862 | Blademaster |  | 965862: fixed, untested (018) ✓ |
| 965476 | Blessing of the Divines |  | 965476: fixed, untested (018) ✓<br>1571465: looks complete (audit) |
| 977906 | Blood and Guts |  | 977906: broken, needs code (004) |
| 983070 | Blood for the Blood God | yes | 983070: broken, needs code |
| 978219 | Blood Venom |  | 978219: fixed, untested (016) ✓ |
| 965280 | Blooming Growth |  | 965280: fixed, untested (015) ✓ |
| 965305 | Booming Thunder |  | 965305: looks complete (audit)<br>1570759: looks complete (audit) |
| 978724 | Bulwark |  | 978724: looks complete (audit) (006)<br>1590962: looks complete (audit) (006) |
| 990190 | Burning Darkness |  | 990190: fixed, untested (016) ✓ |
| 986008 | Carnage Incarnate |  | 986008: looks complete (audit) (006)<br>1590982: looks complete (audit) (006) |
| 86460 | Cauterizing Flames |  | 86460: broken, needs code |
| 986000 | Champion of Justice |  | 986000: broken, needs code |
| 301000 | Circle of Life | yes | 301000: fixed, untested (015) ✓ |
| 979740 | Compound Power |  | 979740: broken, needs code (003) |
| 965295 | Consecrated Strikes |  | 965295: fixed, untested (017) ✓ |
| 414080 | Consumed by Fire |  | 414080: looks complete (audit) |
| 81407 | Controlled Burn |  | 81407: fixed, untested (016, 017) ✓ |
| 99634 | Corrupted Bear Form |  | 99634: broken, needs code |
| 84529 | Crazy Cultist |  | 84529: fixed, untested (018) ✓<br>1568195: fixed, untested (018) ✓ |
| 977727 | Crimson Champion |  | 977727: looks complete (audit) (006) |
| 86576 | Cryotherapist | yes | 86576: looks complete (audit) (003) |
| 982806 | Curse of Arugal | yes | 982806: fixed, untested (016, 017) ✓ |
| 980056 | Dark Apotheosis | yes | 980056: looks complete (audit) |
| 997115 | Dark Ranger | yes | 997115: broken, needs code |
| 978209 | Dark Surgeon |  | 978209: part broken (003) |
| 983180 | Darkmaster | yes | 983180: broken, needs code |
| 965292 | Deadly Bite |  | 965292: fixed, untested (015, 017, 019) ✓ |
| 965501 | Deathbringer |  | 965501: fixed, untested (015) ✓ |
| 997047 | Defias Gunslinger | yes | 997047: broken, needs code |
| 977864 | Demolisher |  | 977864: broken, needs code (003) |
| 965313 | Demonic Influence |  | 965313: broken, needs code |
| 990130 | Demonic Persistence |  | 990130: broken, needs code |
| 84531 | Deranged Druid |  | 84531: fixed, untested (018) ✓<br>1568216: fixed, untested (018) ✓ |
| 982980 | Disciple of Arugal | yes | 982980: broken, needs code |
| 978234 | Disciple of the Tides |  | 978234: part broken (004) |
| 965421 | Divine Purpose |  | 965421: fixed, untested (015, 017) ✓ |
| 81472 | Dominant Word: Shield |  | 81472: looks complete (audit) (003) |
| 978742 | Double Down |  | 978742: fixed, untested (016) ✓ |
| 954252 | Dragon Warrior |  | 954252: broken, needs code (004) |
| 84533 | Eccentric Elementalist |  | 84533: fixed, untested (018) ✓<br>1568237: fixed, untested (018) ✓ |
| 986234 | Edge of Fury | yes | 986234: broken, needs code |
| 81116 | Eldritch Knight |  | 81116: fixed, untested (016, 017) ✓ |
| 978229 | Elemental Assassin |  | 978229: broken, needs code (004) |
| 978231 | Elemental Destruction |  | 978231: looks complete (audit) (004) |
| 990200 | Elemental Lord |  | 990200: broken, needs code |
| 965311 | Endless Agony |  | 965311: looks complete (audit) (004)<br>1570908: fixed, untested (015) ✓ |
| 953308 | Evoker |  | 953308: fixed, untested (015, 017) ✓ |
| 92438 | Fel Charge |  | 92438: looks complete (audit) (007) |
| 984165 | Fel Corruption | yes | 984165: broken, needs code |
| 84806 | Fel Strike |  | 84806: fixed, untested (018) ✓ |
| 101086 | Felborne |  | 101086: fixed, untested (018) ✓ |
| 965301 | Festering Wound |  | 965301: looks complete (audit)<br>1570737: looks complete (audit) |
| 978208 | Fingers of Death |  | 978208: fixed, untested (016) ✓ |
| 978220 | Fire Watch |  | 978220: part broken (004) |
| 965293 | Flame On! |  | 965293: broken, needs code |
| 984448 | Flashpoint Operative |  | 984448: fixed, untested (015) ✓ |
| 954326 | Forbidden Technique |  | 954326: broken, needs code (006, 007) |
| 954262 | Frost Bomb |  | 954262: fixed, untested (016) ✓<br>1590912: fixed, untested (016) ✓ |
| 965504 | Frost Lich |  | 965504: fixed, untested (015) ✓ |
| 980673 | Frozen Chaos |  | 980673: part broken (003) |
| 977810 | Fury of the Titans |  | 977810: broken, needs code |
| 997124 | Grove Ranger | yes | 997124: broken, needs code |
| 81520 | Growing Light |  | 81520: broken, needs code |
| 81467 | Guardians of the Grove |  | 81467: looks complete (audit) (007)<br>1567585: looks complete (audit) |
| 954077 | Guerilla Trapper |  | 954077: looks complete (audit) |
| 983135 | Gurubashi Berserker | yes | 983135: broken, needs code |
| 965505 | Harbinger of Flame |  | 965505: fixed, untested (015) ✓ |
| 990020 | Harbinger of Pestilence |  | 990020: looks complete (audit) |
| 977700 | Heavyweight |  | 977700: broken, needs code<br>1571904: looks complete (audit) |
| 965858 | Holy Ascension |  | 965858: looks complete (audit)<br>1571664: looks complete (audit) |
| 965473 | Holy Radiance |  | 965473: looks complete (audit)<br>1571400: looks complete (audit) |
| 977921 | Holy Spirit |  | 977921: fixed, untested (016) ✓ |
| 81190 | Holy Supernova |  | 81190: looks complete (audit) (006) |
| 978217 | Hoplite |  | 978217: broken, needs code |
| 979765 | Hot Hands |  | 979765: broken, needs code<br>1575104: broken, needs code |
| 954359 | Hydromancer |  | 954359: looks complete (audit) (003) |
| 965294 | Ice Barrage |  | 965294: looks complete (audit) (003)<br>1570523: looks complete (audit) (003) |
| 977764 | Ice Lash |  | 977764: fixed, untested (016, 017) ✓ |
| 978226 | Knight of the Eclipse |  | 978226: looks complete (audit) (003) |
| 417700 | Lava Sweep |  | 417700: LOOP RISK (007)<br>1590905: looks complete (audit) (008) |
| 984117 | Legacy of the Arcanist | yes | 984117: broken, needs code |
| 997129 | Lei Shen's Legacy | yes | 997129: broken, needs code |
| 954044 | Locust Ranger |  | 954044: broken, needs code |
| 81404 | Low Tide |  | 81404: broken, needs code |
| 978218 | Lucifur |  | 978218: looks complete (audit) |
| 977870 | Mana Fiend |  | 977870: broken, needs code |
| 84752 | Martial Crescendo |  | 84752: fixed, untested (016, 017) ✓ |
| 980046 | Master of Shadows |  | 980046: broken, needs code |
| 965309 | Mending Tide |  | 965309: broken, needs code<br>1570865: looks complete (audit) |
| 978228 | Midnight Flames |  | 978228: looks complete (audit) (004) |
| 965307 | Molten Earth |  | 965307: looks complete (audit) |
| 965283 | Nature's Fervor |  | 965283: fixed, untested (015, 017) ✓<br>1570238: fixed, untested (015) ✓ |
| 979748 | One With The Light |  | 979748: broken, needs code<br>1575034: fixed, untested (015) ✓ |
| 979240 | Oracle of the Eclipse | yes | 979240: broken, needs code |
| 977710 | Overflow |  | 977710: broken, needs code (003)<br>1571951: broken, needs code (003) |
| 81119 | Overheating |  | 81119: broken, needs code |
| 81122 | Overloaded Froststorm |  | 81122: fixed, untested (018) ✓ |
| 956445 | Paratrooper |  | 956445: looks complete (audit) (006) |
| 81399 | Plague Bearer |  | 81399: fixed, untested (016) ✓ |
| 986033 | Prayer of Preservation |  | 986033: broken, needs code |
| 977802 | Predator's Wrath |  | 977802: broken, needs code |
| 977717 | Primordial Fury |  | 977717: fixed, untested (016, 017) ✓ |
| 979796 | Prophet of Wrath |  | 979796: broken, needs code |
| 977713 | Pure Shadow |  | 977713: looks complete (audit) |
| 84508 | Purification By Light |  | 84508: fixed, untested (015) ✓ |
| 977817 | Razor Claws |  | 977817: fixed, untested (016) ✓ |
| 986052 | Relentless |  | 986052: broken, needs code |
| 81298 | Righteous Flames |  | 81298: broken, needs code |
| 965502 | Righteous Zealot |  | 965502: fixed, untested (015) ✓ |
| 965937 | Seed of Life |  | 965937: looks complete (audit) (004)<br>1571863: looks complete (audit) |
| 84515 | Seething Flames |  | 84515: fixed, untested (015) ✓ |
| 982400 | Serpent Form | yes | 982400: broken, needs code |
| 977967 | Shadow Counter |  | 977967: looks complete (audit) (006) |
| 965299 | Shadow Visions |  | 965299: fixed, untested (018) ✓<br>1570700: fixed, untested (018) ✓ |
| 990055 | Snowblind |  | 990055: broken, needs code |
| 81102 | Social Distancing |  | 81102: looks complete (audit) |
| 984200 | Son of Gruul | yes | 984200: broken, needs code |
| 81168 | Soul of The Warden |  | 81168: looks complete (audit) |
| 978233 | Spell Shredder |  | 978233: broken, needs code |
| 965503 | Spell Slinger |  | 965503: fixed, untested (015) ✓ |
| 986162 | Steward of Eternity | yes | 986162: broken, needs code |
| 977991 | Stormborn |  | 977991: broken, needs code |
| 965500 | Stormbringer |  | 965500: fixed, untested (015) ✓ |
| 977928 | Stormhammer |  | 977928: broken, needs code (006) |
| 997127 | Swashbuckler: Bloodsail Captain | yes | 997127: broken, needs code |
| 954424 | Templar of Flame |  | 954424: part broken (003) |
| 977972 | Temporal Shift |  | 977972: broken, needs code |
| 983739 | Thermal Void | yes | 983739: broken, needs code (007) |
| 978236 | Thunder Slam |  | 978236: fixed, untested (016) ✓ |
| 954074 | Tidecaller |  | 954074: fixed, untested (015) ✓ |
| 965245 | Time Warp |  | 965245: broken, needs code (006) |
| 954067 | Titanic Mutilate |  | 954067: fixed, untested (015, 017) ✓ |
| 84750 | Tools of War |  | 84750: fixed, untested (016, 017) ✓ |
| 965282 | Total Eclipse |  | 965282: looks complete (audit) |
| 86438 | Tree of Wrath |  | 86438: broken, needs code (006) |
| 977824 | Twilight Paragon |  | 977824: fixed, untested (016, 017) ✓<br>1572527: looks complete (audit) |
| 84506 | Unbounded Deathbringer |  | 84506: fixed, untested (015) ✓ |
| 84510 | Unbounded Spell Slinger |  | 84510: fixed, untested (015) ✓ |
| 978727 | Unchained |  | 978727: looks complete (audit) (004) |
| 978721 | Undaunted |  | 978721: fixed, untested (016) ✓ |
| 965288 | Unrelenting Wrath |  | 965288: fixed, untested (018) ✓ |
| 997126 | Vampire Lord | yes | 997126: broken, needs code |
| 902122 | Verdant Convergence | yes | 902122: broken, needs code (011) |
| 965442 | Wacky Wizardry |  | 965442: fixed, untested (018) ✓<br>1571306: fixed, untested (018) ✓ |
| 965337 | Warcry |  | 965337: fixed, untested (015) ✓ |
| 997113 | Warden of Demonreach | yes | 997113: broken, needs code |
| 965445 | Whispers of the Old Gods |  | 965445: broken, needs code (004) |
| 978202 | White Walker |  | 978202: broken, needs code |
| 965315 | Wild Felfire |  | 965315: looks complete (audit) |
| 978232 | Wind Rager |  | 978232: looks complete (audit) (003) |
| 81470 | Words of Healing |  | 81470: fixed, untested (016, 017) ✓ |
| 902137 | Zandalari Windreaver | yes | 902137: broken, needs code (011) |
| 84527 | Zany Zealot |  | 84527: fixed, untested (018) ✓<br>1568174: fixed, untested (018) ✓ |

## Legendaries in our client that the site does not list

106 copies. Older or removed Ascension enchants, so there is no tooltip to check them against; their own spell
text in our client is the only record.

| Our ID | Enchant | Status |
|---|---|---|
| 1134967 | Affliction Mastery | looks complete (audit) |
| 1398218 | Air Ascendance | looks complete (audit) |
| 1134962 | Arcane Mastery | looks complete (audit) |
| 1398224 | Arcane Orb | looks complete (audit) |
| 1100170 | Arcane Reverberation | broken, needs code |
| 1582341 | Armor of Faith | looks complete (audit) (003) |
| 1134995 | Arms Mastery | looks complete (audit) |
| 1143164 | Aspect of the Fox | broken, needs code |
| 1134972 | Assassination Mastery | looks complete (audit) |
| 1134979 | Balance Mastery | looks complete (audit) |
| 1180019 | Bane of Havoc | broken, needs code |
| 1398205 | Barbed Shot | looks complete (audit) |
| 1579308 | Barrage Overload | looks complete (audit) |
| 1134987 | Beast Mastery | looks complete (audit) |
| 1181400 | Blazing Flame | part broken |
| 1570395 | Blood Tracker: Deadly Bite | fixed, untested (015) ✓ |
| 1398215 | Bloodbath | broken, needs code (008) |
| 1180500 | Cataclysmic Burst | looks complete (audit) |
| 1181330 | Celestial Power | looks complete (audit) |
| 1589486 | Chasin' the Rush | looks complete (audit) |
| 1398174 | Chosen of Elune | looks complete (audit) (006) |
| 1186362 | Colossus Smash | looks complete (audit) (007) |
| 1134973 | Combat Mastery | looks complete (audit) |
| 1573649 | Cremation | looks complete (audit) (006) |
| 1572131 | Crimson Defense | broken, needs code |
| 1398214 | Crimson Hunger | looks complete (audit) |
| 1570995 | Demonic Reoccurence | looks complete (audit) (001) |
| 1134965 | Demonology Mastery | broken, needs code |
| 1134964 | Destruction Mastery | looks complete (audit) |
| 1134969 | Discipline Mastery | broken, needs code |
| 1398178 | Divine Star | looks complete (audit) |
| 1590910 | Dragon Roar | broken, needs code (006) |
| 1134980 | Earthen Guardian Mastery | looks complete (audit) |
| 1186386 | Efflorescence | looks complete (audit) |
| 1134981 | Elemental Mastery | looks complete (audit) |
| 1584825 | Enduring Aegis | looks complete (audit) |
| 1134983 | Enhancement Mastery | looks complete (audit) |
| 1398164 | Enslave Demon | looks complete (audit) (008) |
| 1398216 | Execution Sentence | looks complete (audit) |
| 1568152 | Explosive Charge | looks complete (audit) |
| 1584001 | Expunge | looks complete (audit) |
| 1154364 | Feeding the Abyss | broken, needs code |
| 1180240 | Feral Frenzy | looks complete (audit) (008) |
| 1134976 | Feral Mastery | looks complete (audit) |
| 1134960 | Fire Mastery | looks complete (audit) |
| 1398169 | Flame Ascendance | looks complete (audit) |
| 1591051 | Flare Strike | looks complete (audit) (006) |
| 1586133 | Flow of Life | looks complete (audit) |
| 1134961 | Frost Mastery | broken, needs code |
| 1398171 | Frozen Orb | looks complete (audit) |
| 1134994 | Fury Mastery | looks complete (audit) |
| 1181280 | Fury Unleashed | looks complete (audit) |
| 1277670 | Gift of Light | broken, needs code |
| 1180850 | Gladiator Stance | looks complete (audit) |
| 1180300 | Glimmer of Light | looks complete (audit) (001) |
| 1134977 | Guardian Mastery | looks complete (audit) |
| 1180100 | Guardian of Ancient Kings | looks complete (audit) |
| 1398211 | Halo | looks complete (audit) |
| 1591108 | Hammerstorm | looks complete (audit) |
| 1398206 | Hand of Gul'dan | looks complete (audit) |
| 1398222 | Healing Rain | looks complete (audit) (008) |
| 1134968 | Holy Mastery | looks complete (audit) |
| 1134990 | Holy Mastery | looks complete (audit) |
| 1554908 | Holy Templar | broken, needs code |
| 1569697 | Hydromancer: Water Bolt | broken, needs code (008) |
| 1180220 | Incarnation: King of the Jungle | part broken |
| 1398180 | Ironfur | looks complete (audit) |
| 1591097 | Kingsbane | looks complete (audit) |
| 1591146 | Light of the Guardian | looks complete (audit) (006) |
| 1134985 | Marksmanship Mastery | looks complete (audit) |
| 1398172 | Meteor | looks complete (audit) |
| 1180440 | Nether Portal | broken, needs code |
| 1133070 | Powershot | looks complete (audit) |
| 1572260 | Predator's Wrath: Wrathful Strikes | looks complete (audit) |
| 1134989 | Protection Mastery | looks complete (audit) |
| 1134996 | Protection Mastery | looks complete (audit) |
| 1398220 | Raging Blow | looks complete (audit) (008) |
| 1143179 | Ravager | looks complete (audit) |
| 1134978 | Restoration Mastery | looks complete (audit) |
| 1134982 | Restoration Mastery | looks complete (audit) |
| 1134991 | Retribution Mastery | looks complete (audit) |
| 1398179 | Roll the Bones | looks complete (audit) |
| 1180009 | Rune of Power | looks complete (audit) |
| 1587050 | Rush of Blood | fixed, untested (016, 017) ✓ |
| 1180002 | Shadow Blades | part broken (006) |
| 1572059 | Shadow Crash | looks complete (audit) (006) |
| 1134970 | Shadow Mastery | looks complete (audit) |
| 1585038 | Sinister Flurry | looks complete (audit) (004) |
| 1180480 | Soul Erosion | part broken |
| 1398159 | Soul Harvest | broken, needs code |
| 1591060 | Spirit of the Forest | looks complete (audit) (006) |
| 1180059 | Stampede | looks complete (audit) |
| 1590930 | Storm Bolt | looks complete (audit) |
| 1181360 | Stormbound Instinct | broken, needs code |
| 1134974 | Subtlety Mastery | looks complete (audit) |
| 1591061 | Sunfire | looks complete (audit) |
| 1134986 | Survival Mastery | looks complete (audit) |
| 1398163 | Tame Dragonkin | looks complete (audit) (008) |
| 1398162 | Tether Elemental | looks complete (audit) (008) |
| 1591076 | Touch of the Magi | broken, needs code |
| 1583831 | Transcendental Embrace | fixed, untested (015) ✓ |
| 1180460 | Twist of Faith | looks complete (audit) |
| 1398184 | Void Eruption | broken, needs code |
| 1571327 | Void Herald: Whispers of the Old Gods | broken, needs code |
| 1760200 | Wind Lash | broken, needs code |
| 1544910 | Wraithweaver: Shadow Orbs | broken, needs code |

Copy totals (all 305): looks complete (audit): 132, broken, needs code: 90, fixed, untested: 72, part broken: 10, LOOP RISK: 1.
