#!/usr/bin/env python3
"""Mystic Enchant cards we add (or switch on) for Wildcard: one list, written to the three places that need it.

  - the server: the wcme_mystic_enchant rows the patched world server adds to its enchant list at start-up
    (patches/mystic-enchants-wildcard.patch, LoadExtraCards), and a scroll item for each new card, copied from one of
    the client's own scrolls of the same quality. `python3 custom_cards.py` prints sql/enchants/184-custom-cards.sql.
  - the client: the same cards in its MysticEnchant.dbc and the scrolls in its Item.dbc, or the enchant window and the
    bags can't show them. racials_off_gcd.py --cards adds them to patch-ZZW.MPQ (client_dbcs below).
  - the WildcardEnchants addon: its list of offered enchants (`python3 custom_cards.py --addon` prints the lines for
    addon/WildcardEnchants/EnchantData.lua).

A card's effect is its spell, an aura the player has while the card is in a slot. Most of these spells are
Ascension talents that never had a card; what makes each one work is in its own SQL or C++ (the card's note says
where). Add a card here only once its effect is done: a card offered in rolls that does nothing is worse than none.
"""
import struct
import sys

LIVE = 0x1                 # realm flags: the Wildcard realm offers the cards its live flag is on for
WILDCARD = 1 << (10 - 1)   # class mask: the Wildcard (Hero) class
EPIC, LEGENDARY = 4, 5
QUALITY_NAMES = {EPIC: 'RE_QUALITY_EPIC', LEGENDARY: 'RE_QUALITY_LEGENDARY'}
# A Wildcard card of each quality whose client row and scroll the new ones copy (the client's MysticEnchant.dbc IDs,
# and their scroll items): everything but the id, spell and scroll is the same as theirs.
TEMPLATE_CARD = {EPIC: 91, LEGENDARY: 545}
TEMPLATE_SCROLL = {EPIC: 1175751, LEGENDARY: 1175930}
# Those scrolls' Item.dbc rows (class, subclass, sound, material, display, inventory type, sheath), for the server's
# item_dbc table: the server's own Item.dbc lacks the new scrolls, like the client's before the client patch.
TEMPLATE_ITEM_ROW = {EPIC: (0, 6, -1, 8, 24653, 0, 0), LEGENDARY: (0, 6, -1, 8, 137561, 0, 0)}

# id (the client's MysticEnchant.dbc ID), spell, scroll item, quality, class mask, name, where its effect is.
# IDs and items from 9990001 are free in the client's MysticEnchant.dbc (highest 1725429) and Item.dbc (highest 9200851).
CARDS = [
    # An Ascension card that the client has but offers on no realm, and only to Warriors: offered to Wildcard.
    (1235411, 1571194, 403833, EPIC, 0x1 | WILDCARD, 'Echoing Warcry', 'sql/enchants/185-custom-card-effects-1.sql'),
    (9990001, 275043, 9990001, EPIC, WILDCARD, 'Assault and Battery', 'sql/enchants/185-custom-card-effects-1.sql'),
    (9990002, 1576284, 9990002, EPIC, WILDCARD, 'Corrupted Maelstrom Weapon', 'sql/enchants/185-custom-card-effects-1.sql'),
    (9990003, 277850, 9990003, EPIC, WILDCARD, 'Arcanesworn', 'patches/55-talent-fixes.ps1, sql/enchants/186-custom-card-effects-2.sql'),
    (9990004, 275462, 9990004, EPIC, WILDCARD, 'Arcane Divinity', 'patches/55-talent-fixes.ps1, sql/enchants/186-custom-card-effects-2.sql'),
    (9990005, 277880, 9990005, LEGENDARY, WILDCARD, 'Arcane Crusade', 'patches/55-talent-fixes.ps1, sql/enchants/186-custom-card-effects-2.sql'),
]
WEIGHT = 100.0
EXISTING_ITEMS = {403833}  # scrolls the client and the server already have; no copy is made


def new_scrolls():
    return [(card_id, spell, item, quality, name) for card_id, spell, item, quality, _, name, _ in CARDS
            if item not in EXISTING_ITEMS]


def sql():
    out = ["-- Mystic Enchant cards we add or switch on for Wildcard (client-patch/custom_cards.py writes this file; the",
           "-- client patch carries the same cards and scrolls). Needs the build with LoadExtraCards in",
           "-- patches/mystic-enchants-wildcard.patch; a server without it ignores wcme_mystic_enchant. Safe to run again:",
           "-- 000-reset empties wcme_mystic_enchant and removes the scroll items listed in wcme_owned first.",
           "INSERT INTO `wcme_mystic_enchant` (`id`, `spell`, `item`, `weight`, `quality`, `required_level`, `realms`, "
           "`class_mask`, `comment`) VALUES"]
    out.append(",\n".join(f"({card_id}, {spell}, {item}, {WEIGHT}, {quality}, 0, {LIVE}, {mask}, "
                          f"'{name.replace(chr(39), chr(39) * 2)}: {note}')"
                          for card_id, spell, item, quality, mask, name, note in CARDS) + ";")
    scrolls = new_scrolls()
    if scrolls:
        out.append("-- Each new card's scroll: a copy of a Wildcard scroll of the same quality, renamed. INSERT IGNORE leaves an")
        out.append("-- item that already has the number alone (the card then rolls as that item: check the number is free).")
        out.append("INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES " +
                   ", ".join(f"('item_template', {item}), ('item_dbc', {item})" for _, _, item, _, _ in scrolls) + ";")
        out.append("INSERT IGNORE INTO `item_dbc` (`ID`, `ClassID`, `SubclassID`, `Sound_Override_Subclassid`, `Material`, "
                   "`DisplayInfoID`, `InventoryType`, `SheatheType`) VALUES " +
                   ", ".join(f"({item}, " + ", ".join(map(str, TEMPLATE_ITEM_ROW[quality])) + ")"
                             for _, _, item, quality, _ in scrolls) + ";")
        for _, _, item, quality, name in scrolls:
            safe = name.replace("'", "''")
            out.append("DROP TEMPORARY TABLE IF EXISTS `wcme_card_scroll`;")
            out.append(f"CREATE TEMPORARY TABLE `wcme_card_scroll` AS SELECT * FROM `item_template` WHERE `entry` = "
                       f"{TEMPLATE_SCROLL[quality]};")
            out.append(f"UPDATE `wcme_card_scroll` SET `entry` = {item}, `name` = CONCAT(SUBSTRING_INDEX(`name`, ': ', 1), "
                       f"': {safe}');")
            out.append("INSERT IGNORE INTO `item_template` SELECT * FROM `wcme_card_scroll`;")
        out.append("DROP TEMPORARY TABLE IF EXISTS `wcme_card_scroll`;")
    return "\n".join(out) + "\n"


def addon_lines():
    return [f"\t{{{spell},{quality},0,{mask}}},  -- {name} (custom_cards.py)"
            for _, spell, _, quality, mask, name, _ in CARDS]


def _table(data):
    _, count, fields, size, strsize = struct.unpack_from('<4s4I', data, 0)
    rows = [list(struct.unpack_from(f'<{fields}I', data, 20 + i * size)) for i in range(count)]
    return rows, fields, data[20 + count * size:20 + count * size + strsize]


def _pack(rows, fields, strings):
    return (struct.pack('<4s4I', b'WDBC', len(rows), fields, fields * 4, len(strings)) +
            b''.join(struct.pack(f'<{fields}I', *row) for row in rows) + strings)


def client_dbcs(mystic_enchant, item):
    """The client's MysticEnchant.dbc and Item.dbc (bytes) with our cards and scrolls in them. The cards only use
    strings the file already has (the quality names, NONE), so its string block is kept as it is."""
    rows, fields, strings = _table(mystic_enchant)
    by_id = {row[0]: row for row in rows}
    by_spell = {row[1]: row for row in rows}

    def offset(text):
        at = strings.find(text.encode() + b'\0')
        while at > 0 and strings[at - 1] != 0:  # must start a string, not end one
            at = strings.find(text.encode() + b'\0', at + 1)
        if at < 0:
            raise SystemExit(f'MysticEnchant.dbc has no string {text}')
        return at

    for card_id, spell, scroll, quality, mask, name, _ in CARDS:
        row = by_spell.get(spell)
        if row is None:
            row = list(by_id[TEMPLATE_CARD[quality]])
            rows.append(row)
            by_spell[spell] = row
        row[0], row[1], row[2], row[6], row[7] = card_id, spell, struct.unpack('<I', struct.pack('<f', WEIGHT))[0], scroll, 0
        row[3] = offset(QUALITY_NAMES[quality])
        row[5] = 0
        for realm in range(5):
            row[8 + realm] = (LIVE >> realm) & 1
        row[13], row[14] = mask & 0xFFFFFFFF, mask >> 32
    mystic = _pack(rows, fields, strings)

    items, item_fields, item_strings = _table(item)
    by_item = {row[0]: row for row in items}
    for _, _, scroll, quality, _ in new_scrolls():
        if scroll not in by_item:
            copy = list(by_item[TEMPLATE_SCROLL[quality]])
            copy[0] = scroll
            items.append(copy)
            by_item[scroll] = copy
    items.sort(key=lambda r: r[0])
    return mystic, _pack(items, item_fields, item_strings)


if __name__ == '__main__':
    if '--addon' in sys.argv:
        print("\n".join(addon_lines()))
    else:
        print(sql(), end='')
