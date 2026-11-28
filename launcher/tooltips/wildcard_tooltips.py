"""Spell tooltips for the website, worked out from the server's DBC files the way the game client shows them.

Reads Spell.dbc and the small tables a tooltip refers to (durations, ranges, radii, icons, description variables)
straight from the server's Data\\dbc folder, and fills in a spell's description: its own numbers ($s1, $d, $u ...),
other spells' numbers ($12345s1), sums (${...}), conditions ($?s123[...][...]), description variables ($<name>), and
Ascension's own markers (@req, @ext, @s, @unlockby, @wflocation).

There is no character, so:
  - a level is the realm's level cap (LEVEL below);
  - a stat (spell power, attack power ...) is written out, e.g. "120 (+30% of spell power)";
  - a condition on a spell or aura the character might have takes the "does not have it" branch.
A number this cannot work out is shown as "?" and counted, so the build can report how many there were.

Standard library only: it runs on the game server's own Python.
"""
import re
import struct
from pathlib import Path

LEVEL = 60  # Wildcard's level cap (MaxPlayerLevel in server-settings.txt)

# Spell.dbc columns (3.3.5 layout, 234 columns)
C_ATTR, C_DURATION, C_PROC_CHANCE, C_PROC_CHARGES, C_MAX_LEVEL, C_BASE_LEVEL, C_SPELL_LEVEL = 4, 40, 35, 36, 37, 38, 39
C_RANGE, C_STACK = 46, 49
C_EFFECT, C_DIE, C_PPL, C_BASE, C_RADIUS, C_AURA, C_AMPLITUDE, C_MULTIPLE = 71, 74, 77, 80, 92, 95, 98, 101
C_CHAIN, C_MISC, C_TRIGGER, C_COMBO = 104, 110, 116, 119
C_ICON, C_NAME, C_RANK, C_DESC, C_TOOLTIP, C_MAX_TARGETS, C_MAX_TARGET_LEVEL = 133, 136, 153, 170, 187, 212, 207
C_DMG_MULT, C_VARIABLES = 216, 232
FLOATS = {C_MULTIPLE, C_MULTIPLE + 1, C_MULTIPLE + 2, C_COMBO, C_COMBO + 1, C_COMBO + 2,
          C_DMG_MULT, C_DMG_MULT + 1, C_DMG_MULT + 2}
SIGNED = set(range(C_BASE, C_BASE + 3)) | set(range(C_DIE, C_DIE + 3))

STATS = {
    "SP": "spell power", "sp": "spell power", "SPH": "Holy spell power", "SPFI": "Fire spell power",
    "SPN": "Nature spell power", "SPFR": "Frost spell power", "SPS": "Shadow spell power", "SPA": "Arcane spell power",
    "sph": "Holy spell power", "spfi": "Fire spell power", "spn": "Nature spell power", "spfr": "Frost spell power",
    "sps": "Shadow spell power", "spa": "Arcane spell power",
    "AP": "attack power", "ap": "attack power", "RAP": "ranged attack power", "rap": "ranged attack power",
    "BH": "healing power", "bh": "healing power", "AR": "armor", "ar": "armor",
    "MWS": "weapon speed", "mws": "weapon speed", "MWB": "weapon damage", "mwb": "weapon damage",
    "MW": "weapon damage", "mw": "weapon damage", "HND": "hands", "hnd": "hands",
    "STR": "Strength", "AGI": "Agility", "STA": "Stamina", "INT": "Intellect", "SPI": "Spirit",
    "str": "Strength", "agi": "Agility", "sta": "Stamina", "int": "Intellect", "spi": "Spirit",
    "MHP": "maximum health", "mhp": "maximum health", "MPS": "maximum mana", "mps": "maximum mana",
}
NUMBER_STATS = {"PL": LEVEL, "pl": LEVEL, "cp": 5, "CP": 5}
STAT_NAMES = sorted(list(STATS) + list(NUMBER_STATS), key=len, reverse=True)
STAT_RE = re.compile(r"\$\d*(" + "|".join(STAT_NAMES) + r")(?![a-zA-Z])")  # some carry a spell id: $983983AP
BARE_STAT_RE = re.compile(r"(" + "|".join(STAT_NAMES) + r")(?![a-zA-Z])")
TOKEN_RE = re.compile(r"\$(\d*)(ppl|[a-zA-Z])(\d?)")


class Unknown(Exception):
    pass


class DBC:
    def __init__(self, path):
        self.data = Path(path).read_bytes()
        self.count, self.fields, self.size, _ = struct.unpack_from("<4I", self.data, 4)
        self.strings = 20 + self.count * self.size

    def rows(self):
        for i in range(self.count):
            yield struct.unpack_from(f"<{self.fields}I", self.data, 20 + i * self.size)

    def text(self, offset):
        if not offset:
            return ""
        start = self.strings + offset
        return self.data[start:self.data.index(b"\0", start)].decode("utf-8", "replace")


class Spell:
    __slots__ = ("id", "row", "spells")

    def __init__(self, spell_id, row, spells):
        self.id, self.row, self.spells = spell_id, row, spells

    def col(self, index):
        value = self.row[index]
        if index in FLOATS:
            return struct.unpack("<f", struct.pack("<I", value))[0]
        if index in SIGNED and value >= 1 << 31:
            return value - (1 << 32)
        return value

    @property
    def name(self):
        return self.spells.dbc.text(self.row[C_NAME])

    @property
    def rank(self):
        return self.spells.dbc.text(self.row[C_RANK])

    @property
    def description(self):
        return self.spells.dbc.text(self.row[C_DESC])

    @property
    def aura_text(self):
        return self.spells.dbc.text(self.row[C_TOOLTIP])

    @property
    def icon(self):
        path = self.spells.icons.get(self.row[C_ICON], "")
        return path.replace("/", "\\").rsplit("\\", 1)[-1].lower() if path else ""

    @property
    def icon_path(self):
        return self.spells.icons.get(self.row[C_ICON], "")


class Spells:
    def __init__(self, dbc_folder):
        folder = Path(dbc_folder)
        self.dbc = DBC(folder / "Spell.dbc")
        self.index = {}
        data, size = self.dbc.data, self.dbc.size
        for i in range(self.dbc.count):
            self.index[struct.unpack_from("<I", data, 20 + i * size)[0]] = 20 + i * size
        self._cache = {}
        self.durations = {r[0]: struct.unpack("<i", struct.pack("<I", r[1]))[0] for r in DBC(folder / "SpellDuration.dbc").rows()}
        ranges = DBC(folder / "SpellRange.dbc")
        self.ranges = {r[0]: struct.unpack("<f", struct.pack("<I", r[3]))[0] for r in ranges.rows()}
        self.radii = {r[0]: struct.unpack("<f", struct.pack("<I", r[1]))[0] for r in DBC(folder / "SpellRadius.dbc").rows()}
        icons = DBC(folder / "SpellIcon.dbc")
        self.icons = {r[0]: icons.text(r[1]) for r in icons.rows()}
        variables = DBC(folder / "SpellDescriptionVariables.dbc")
        self.variables = {r[0]: _parse_variables(variables.text(r[1])) for r in variables.rows()}

    def get(self, spell_id):
        if spell_id not in self._cache:
            at = self.index.get(spell_id)
            self._cache[spell_id] = Spell(spell_id, struct.unpack_from(f"<{self.dbc.fields}I", self.dbc.data, at), self) \
                if at is not None else None
        return self._cache[spell_id]


def _parse_variables(text):
    found = {}
    for line in re.split(r"[\r\n]+", text):
        match = re.match(r"\s*\$(\w+)\s*=\s*(.*\S)", line)
        if match:
            found[match.group(1)] = match.group(2)
    return found


# ---- numbers with stats in them ---------------------------------------------------------------------------------

class Lin:
    """A number plus stat terms: 120 + 0.3 x spell power."""
    __slots__ = ("c", "terms")

    def __init__(self, c=0.0, terms=None):
        self.c, self.terms = float(c), dict(terms or {})

    @property
    def plain(self):
        return not any(self.terms.values())

    def __add__(self, other):
        terms = dict(self.terms)
        for k, v in other.terms.items():
            terms[k] = terms.get(k, 0) + v
        return Lin(self.c + other.c, terms)

    def __neg__(self):
        return Lin(-self.c, {k: -v for k, v in self.terms.items()})

    def __sub__(self, other):
        return self + (-other)

    def scale(self, factor):
        return Lin(self.c * factor, {k: v * factor for k, v in self.terms.items()})

    def __mul__(self, other):
        if other.plain:
            return self.scale(other.c)
        if self.plain:
            return other.scale(self.c)
        raise Unknown("stat times stat")

    def __truediv__(self, other):
        if not other.plain:
            raise Unknown("divide by a stat")
        if other.c == 0:
            raise Unknown("divide by zero")
        return self.scale(1 / other.c)

    def number(self):
        if not self.plain:
            raise Unknown("needs a plain number")
        return self.c


def fmt_number(value, decimals=None):
    if decimals is None:
        if abs(value - round(value)) < 0.005:
            return str(int(round(value)))
        text = f"{value:.2f}".rstrip("0").rstrip(".")
        return text
    return f"{value:.{decimals}f}"


def fmt_lin(value, decimals=0, absolute=True):
    c = abs(value.c) if absolute and value.plain else value.c
    parts = []
    for stat, coef in value.terms.items():
        if coef:
            pct = coef * 100
            parts.append(f"{fmt_number(abs(pct) if absolute else pct)}% of {STATS.get(stat, stat)}")
    if not parts:
        return fmt_number(round(c, decimals) if decimals else round(c), decimals or None) if decimals \
            else str(int(round(c)))
    if abs(c) < 0.5 and not decimals:
        return " + ".join(parts)
    lead = fmt_number(round(c, decimals), decimals or None) if decimals else str(int(round(c)))
    return f"{lead} (+{' + '.join(parts)})"


def fmt_seconds(ms):
    if ms < 0:
        return "until cancelled"
    seconds = ms / 1000
    if seconds < 60:
        return f"{fmt_number(seconds)} sec"
    if seconds < 3600:
        return f"{fmt_number(seconds / 60)} min"
    if seconds < 86400:
        return f"{fmt_number(seconds / 3600)} hrs"
    return f"{fmt_number(seconds / 86400)} days"


# ---- one spell's values --------------------------------------------------------------------------------------------

def effect_min(spell, index):
    base, die = spell.col(C_BASE + index), spell.col(C_DIE + index)
    return base + (1 if die else 0) if die >= 0 else base + 1


def effect_max(spell, index):
    base, die = spell.col(C_BASE + index), spell.col(C_DIE + index)
    return base + die if die > 1 else effect_min(spell, index)


def per_level(spell, index):
    rppl = struct.unpack("<f", struct.pack("<I", spell.row[C_PPL + index]))[0]
    return rppl * LEVEL


def level_bonus(spell, index):
    """What the effect gains from the caster's level, as the server works it out (SpellEffectInfo::CalcValue)."""
    rppl = struct.unpack("<f", struct.pack("<I", spell.row[C_PPL + index]))[0]
    if not rppl:
        return 0
    level = LEVEL
    if spell.row[C_MAX_LEVEL] and level > spell.row[C_MAX_LEVEL]:
        level = spell.row[C_MAX_LEVEL]
    elif level < spell.row[C_BASE_LEVEL]:
        level = spell.row[C_BASE_LEVEL]
    return int((level - spell.row[C_SPELL_LEVEL]) * rppl)


def duration_ms(spell):
    return spell.spells.durations.get(spell.row[C_DURATION], 0)


def token_value(spell, code, index, scaled=True):
    """The value of $<code><index> for one spell, as a Lin. scaled: add what the effect gains from the caster's
    level. A sum that adds the level part itself ($ppl1, an Ascension token) wants the bare value."""
    i = max(0, index - 1) if index else 0
    if i > 2:
        raise Unknown("effect index")
    if code in ("s", "m"):
        return Lin(effect_min(spell, i) + (level_bonus(spell, i) if scaled else 0))
    if code in ("M", "S"):
        return Lin(effect_max(spell, i) + (level_bonus(spell, i) if scaled else 0))
    if code == "ppl":
        return Lin(per_level(spell, i))
    if code in ("d", "D"):
        return Lin(duration_ms(spell) / 1000)
    if code in ("u", "U"):
        return Lin(max(1, spell.row[C_STACK]))
    if code in ("h", "H"):
        return Lin(spell.row[C_PROC_CHANCE])
    if code in ("n", "N"):
        return Lin(spell.row[C_PROC_CHARGES])
    if code in ("i", "I"):
        return Lin(spell.row[C_MAX_TARGETS])
    if code in ("x", "X"):
        return Lin(spell.row[C_CHAIN + i])
    if code in ("a", "A"):
        return Lin(spell.spells.radii.get(spell.row[C_RADIUS + i], 0))
    if code in ("r", "R"):
        return Lin(spell.spells.ranges.get(spell.row[C_RANGE], 0))
    if code in ("t", "T"):
        return Lin(spell.row[C_AMPLITUDE + i] / 1000)
    if code in ("o", "O"):
        amplitude = spell.row[C_AMPLITUDE + i]
        ticks = duration_ms(spell) // amplitude if amplitude and duration_ms(spell) > 0 else 0
        if not ticks:
            raise Unknown("no ticks")
        return Lin(effect_min(spell, i) * ticks)
    if code in ("b", "B"):
        return Lin(spell.col(C_COMBO + i))
    if code in ("e", "E"):
        return Lin(spell.col(C_MULTIPLE + i))
    if code in ("f", "F"):
        return Lin(spell.col(C_DMG_MULT + i))
    if code in ("q", "Q"):
        return Lin(spell.col(C_MISC + i))
    if code in ("v", "V"):
        return Lin(spell.row[C_MAX_TARGET_LEVEL])
    raise Unknown(f"${code}")


def token_text(spell, code, index):
    """How $<code><index> reads in running text."""
    i = max(0, index - 1) if index else 0
    if code in ("d", "D"):
        return fmt_seconds(duration_ms(spell))
    if code in ("s",) and i <= 2:
        bonus = level_bonus(spell, i)
        low, high = abs(effect_min(spell, i) + bonus), abs(effect_max(spell, i) + bonus)
        return str(low) if low == high else f"{min(low, high)} to {max(low, high)}"
    value = token_value(spell, code, index)
    if code in ("t", "T", "e", "E", "b", "B", "a", "A", "r", "R"):
        return fmt_number(abs(value.c))
    return fmt_lin(value)


# ---- the description language --------------------------------------------------------------------------------------

class Renderer:
    def __init__(self, spells):
        self.spells = spells
        self.unknown = 0
        self.unknown_kinds = {}

    def _miss(self, why):
        self.unknown += 1
        key = str(why)[:40]
        self.unknown_kinds[key] = self.unknown_kinds.get(key, 0) + 1
        return "?"

    def _spell(self, spell_id, default):
        if not spell_id:
            return default
        found = self.spells.get(int(spell_id))
        if found is None:
            raise Unknown(f"spell {spell_id} missing")
        return found

    def _variable(self, spell, name, depth):
        for candidate in (spell, self._root):
            table = self.spells.variables.get(candidate.row[C_VARIABLES]) if candidate else None
            if table and name in table:
                return self.expand(table[name], spell, depth + 1, inner=True)
        # Some spells use a variable without naming the set it is in (scalingbp); take the one set that defines it.
        owners = [table for table in self.spells.variables.values() if name in table]
        if len(owners) == 1:
            return self.expand(owners[0][name], spell, depth + 1, inner=True)
        raise Unknown(f"variable {name}")

    # Conditions: we know nothing about the character, so every "has spell/aura X" is false.
    def _condition(self, text):
        expr = text.strip()
        if expr.startswith("(") and expr.endswith(")"):
            expr = expr[1:-1]
        result = None
        op = None
        for part in re.findall(r"[&|]|!?\(?[a-zA-Z]*\d+\)?|!?\w+", expr):
            if part in "&|":
                op = part
                continue
            value = part.startswith("!")
            result = value if result is None else (result and value if op == "&" else result or value)
        return bool(result)

    def _conditional(self, text, at, spell, depth):
        """text[at:] starts with '$?'. Returns (chosen text, end position)."""
        pos = at + 2
        chosen = None
        while True:
            match = re.compile(r"(\([^\]\[]*?\)|!?[a-zA-Z]+\d+)").match(text, pos)
            if not match:
                raise Unknown("condition")
            cond = self._condition(match.group(1))
            pos = match.end()
            branch, pos = _bracket(text, pos)
            if chosen is None and cond:
                chosen = branch
            if pos < len(text) and text[pos] == "?":
                pos += 1
                continue
            if pos < len(text) and text[pos] == "[":
                other, pos = _bracket(text, pos)
                if chosen is None:
                    chosen = other
            return chosen or "", pos

    def _evaluate(self, expr, spell, depth):
        """Evaluate ${expr} to a Lin."""
        tokens = []
        pos = 0
        scaled = "ppl" not in expr
        while pos < len(expr):
            ch = expr[pos]
            if ch.isspace():
                pos += 1
                continue
            if ch == "$":
                if expr.startswith("$?", pos):
                    chosen, pos = self._conditional(expr, pos, spell, depth)
                    tokens.append(("v", self._evaluate(chosen, spell, depth + 1)))
                    continue
                if expr.startswith("$<", pos):
                    end = expr.index(">", pos)
                    value = self._variable(spell, expr[pos + 2:end], depth)
                    tokens.append(("v", self._to_lin(value, spell, depth)))
                    pos = end + 1
                    continue
                func = re.compile(r"\$(abs|max|min|gt|lt|ge|le|eq|floor|ceil|round|cond|clamp)\(").match(expr, pos)
                if func:
                    tokens.append(("f", func.group(1)))
                    pos = func.end() - 1
                    continue
                stat = STAT_RE.match(expr, pos)
                if stat:
                    name = stat.group(1)
                    tokens.append(("v", Lin(NUMBER_STATS[name]) if name in NUMBER_STATS else Lin(0, {name: 1})))
                    pos = stat.end()
                    continue
                token = TOKEN_RE.match(expr, pos)
                if token:
                    source = self._spell(token.group(1), spell)
                    tokens.append(("v", token_value(source, token.group(2), int(token.group(3) or 0), scaled)))
                    pos = token.end()
                    continue
                number = re.compile(r"\$(\d+)(?![a-zA-Z\d])").match(expr, pos)
                if number:  # "$10000" is a typo for 10000
                    tokens.append(("v", Lin(float(number.group(1)))))
                    pos = number.end()
                    continue
                raise Unknown("token in sum")
            bare = BARE_STAT_RE.match(expr, pos)
            if bare and (pos == 0 or not expr[pos - 1].isalnum()):
                name = bare.group(1)  # a stat written without its $
                tokens.append(("v", Lin(NUMBER_STATS[name]) if name in NUMBER_STATS else Lin(0, {name: 1})))
                pos = bare.end()
                continue
            number = re.compile(r"\d+\.?\d*|\.\d+").match(expr, pos)
            if number:
                tokens.append(("v", Lin(float(number.group()))))
                pos = number.end()
                continue
            if ch in "+-*/(),<>=!":
                tokens.append(("o", ch))
                pos += 1
                continue
            raise Unknown(f"character {ch!r} in sum")
        for attempt in (tokens, _balanced(tokens)):
            parser = _Parser(attempt)
            try:
                value = parser.expr()
            except Unknown:
                continue
            if parser.pos == len(attempt):
                return value
        raise Unknown("sum syntax")

    def _to_lin(self, text, spell, depth):
        text = text.strip()
        try:
            return Lin(float(text))
        except ValueError:
            pass
        match = re.fullmatch(r"(-?[\d.]+) \(\+([\d.]+)% of (.+)\)", text)
        if match:
            stat = next((k for k, v in STATS.items() if v == match.group(3)), None)
            if stat:
                return Lin(float(match.group(1)), {stat: float(match.group(2)) / 100})
        raise Unknown("variable is not a number")

    def expand(self, text, spell, depth=0, inner=False):
        """Fill in every $ token. Returns plain text (colour codes and note markers kept)."""
        if depth > 16:
            raise Unknown("too deep")
        out = []
        pos = 0
        last_number = None
        while True:
            at = text.find("$", pos)
            if at < 0:
                out.append(text[pos:])
                break
            out.append(text[pos:at])
            try:
                piece, pos, number = self._token(text, at, spell, depth, last_number)
            except Unknown as why:
                piece, pos, number = self._miss(why), _skip_token(text, at), None
            except (ValueError, IndexError, ZeroDivisionError, OverflowError) as why:
                piece, pos, number = self._miss(type(why).__name__), _skip_token(text, at), None
            if number is not None:
                last_number = number
            out.append(piece)
        return "".join(out)

    def _token(self, text, at, spell, depth, last_number):
        nxt = text[at + 1:at + 2]
        if nxt == "{":
            end = _matching(text, at + 1, "{", "}")
            value = self._evaluate(text[at + 2:end], spell, depth)
            pos = end + 1
            decimals = 0
            places = re.compile(r"\.(\d)").match(text, pos)
            if places:
                decimals = int(places.group(1))
                pos = places.end()
            shown = fmt_lin(value, decimals)
            return shown, pos, value.c if value.plain else None
        if nxt == "<":
            end = text.index(">", at)
            shown = self._variable(spell, text[at + 2:end], depth)
            return shown, end + 1, _last_number(shown)
        if nxt == "?":
            chosen, pos = self._conditional(text, at, spell, depth)
            return self.expand(chosen, spell, depth + 1), pos, None
        if nxt in ("/", "*"):
            match = re.compile(r"\$([/*])([\d.]+);").match(text, at)
            if not match:
                raise Unknown("scaled token")
            token = TOKEN_RE.match("$" + text[match.end():])
            if not token:
                raise Unknown("scaled token")
            source = self._spell(token.group(1), spell)
            value = token_value(source, token.group(2), int(token.group(3) or 0))
            if token.group(2) in ("d", "D"):
                value = Lin(duration_ms(source))
            factor = float(match.group(2))
            value = value / Lin(factor) if match.group(1) == "/" else value.scale(factor)
            shown = fmt_number(abs(value.number()))
            return shown, match.end() + token.end() - 1, value.c
        if nxt in ("l", "L", "g", "G"):
            match = re.compile(r"\$[lLgG]([^:;]*):([^;]*);").match(text, at)
            if match:
                if nxt in "gG":
                    return match.group(1), match.end(), None
                singular = last_number is not None and abs(abs(last_number) - 1) < 1e-9
                return (match.group(1) if singular else match.group(2)), match.end(), None
        stat = STAT_RE.match(text, at)
        if stat:
            name = stat.group(1)
            if name in NUMBER_STATS:
                return str(NUMBER_STATS[name]), stat.end(), NUMBER_STATS[name]
            return STATS[name], stat.end(), None
        token = TOKEN_RE.match(text, at)
        if token:
            source = self._spell(token.group(1), spell)
            code, index = token.group(2), int(token.group(3) or 0)
            shown = token_text(source, code, index)
            return shown, token.end(), _last_number(shown)
        if nxt == "$":
            return "$", at + 2, None
        raise Unknown("token")

    # ---- whole tooltips -------------------------------------------------------------------------------------------

    def tooltip(self, spell, depth=0):
        """A tooltip as data the page can show with textContent: name, icon, requirement names, lines of segments,
        notes, where-to-find text and embedded sub-tooltips."""
        self._root = spell if depth == 0 else self._root
        text = spell.description
        result = {"id": spell.id, "name": spell.name, "icon": spell.icon}
        req, unlock, subs, where = [], [], [], []

        def named(spell_id):
            other = self.spells.get(int(spell_id))
            return other.name if other else f"spell {spell_id}"

        def take(pattern, sink, make):
            nonlocal text

            def keep(match):
                sink.append(make(match))
                return ""
            text = re.sub(pattern, keep, text)

        take(r"@req:(\d+)(?::req)?@", req, lambda m: named(m.group(1)))
        take(r"@unlockby:(\d+)(?::unlockby)?@", unlock, lambda m: named(m.group(1)))
        take(r"@wflocation:(.*?)@", where, lambda m: m.group(1).strip())
        take(r"@s:(\d+):(-?\d+)@", subs, lambda m: int(m.group(1)))
        text = re.sub(r"@ext:(.*?):ext@", lambda m: "\x01" + m.group(1) + "\x02", text, flags=re.S)
        text = re.sub(r"@\w+:[^@]*@", "", text)
        try:
            filled = self.expand(text, spell)
        except Unknown as why:
            filled = self._miss(why)
        result["lines"] = _segments(filled)
        if req:
            result["req"] = req
        if unlock:
            result["unlock"] = unlock
        if where:
            result["where"] = " ".join(where)
        if subs and depth < 1:
            shown = []
            for sub_id in subs:
                sub = self.spells.get(sub_id)
                if sub and sub.id != spell.id:
                    tip = self.tooltip(sub, depth + 1)
                    if tip["lines"] or tip.get("subs"):
                        shown.append(tip)
            if shown:
                result["subs"] = shown
        return result


def _balanced(tokens):
    """Several tooltips have a stray or missing bracket; the game shows them anyway. Drop a ) with nothing to close
    and close what is left open at the end."""
    out, level = [], 0
    for token in tokens:
        if token == ("o", "("):
            level += 1
        elif token == ("o", ")"):
            if not level:
                continue
            level -= 1
        out.append(token)
    return out + [("o", ")")] * level


def _bracket(text, pos):
    if pos >= len(text) or text[pos] != "[":
        raise Unknown("condition branch")
    end = _matching(text, pos, "[", "]")
    return text[pos + 1:end], end + 1


def _matching(text, pos, opener, closer):
    level = 0
    for i in range(pos, len(text)):
        if text[i] == opener:
            level += 1
        elif text[i] == closer:
            level -= 1
            if level == 0:
                return i
    raise Unknown(f"no closing {closer}")


def _skip_token(text, at):
    if text[at + 1:at + 2] == "{":
        try:
            return _matching(text, at + 1, "{", "}") + 1
        except Unknown:
            return at + 1
    match = re.compile(r"\$[/*][\d.]+;\d*[a-zA-Z]+\d?|\$\d*[a-zA-Z]+\d?|\$<\w+>").match(text, at)
    return match.end() if match else at + 1


def _last_number(shown):
    numbers = re.findall(r"-?\d+(?:\.\d+)?", shown)
    return float(numbers[-1]) if numbers else None


class _Parser:
    """+ - * / ( ) and function calls over Lin values."""

    def __init__(self, tokens):
        self.tokens, self.pos = tokens, 0

    def peek(self):
        return self.tokens[self.pos] if self.pos < len(self.tokens) else (None, None)

    def take(self, kind, value=None):
        token = self.peek()
        if token[0] != kind or (value is not None and token[1] != value):
            raise Unknown("sum syntax")
        self.pos += 1
        return token[1]

    def expr(self):
        value = self.term()
        while self.peek() in (("o", "+"), ("o", "-")):
            op = self.take("o")
            other = self.term()
            value = value + other if op == "+" else value - other
        return value

    def term(self):
        value = self.unary()
        while self.peek() in (("o", "*"), ("o", "/")):
            op = self.take("o")
            other = self.unary()
            value = value * other if op == "*" else value / other
        return value

    def unary(self):
        if self.peek() == ("o", "-"):
            self.take("o")
            return -self.unary()
        if self.peek() == ("o", "+"):
            self.take("o")
            return self.unary()
        return self.atom()

    def atom(self):
        kind, value = self.peek()
        if kind == "v":
            self.pos += 1
            return value
        if kind == "o" and value == "(":
            self.take("o", "(")
            inner = self.expr()
            self.take("o", ")")
            return inner
        if kind == "f":
            self.pos += 1
            self.take("o", "(")
            args = [self.expr()]
            while self.peek() == ("o", ","):
                self.take("o", ",")
                args.append(self.expr())
            self.take("o", ")")
            return _call(value, args)
        raise Unknown("sum syntax")


def _call(name, args):
    if name == "abs" and len(args) == 1:
        return Lin(abs(args[0].c)) if args[0].plain else args[0]
    numbers = [a.number() for a in args]
    if name == "max":
        return Lin(max(numbers))
    if name == "min":
        return Lin(min(numbers))
    if name == "floor":
        import math
        return Lin(math.floor(numbers[0]))
    if name == "ceil":
        import math
        return Lin(math.ceil(numbers[0]))
    if name == "round":
        return Lin(round(numbers[0]))
    if name in ("gt", "lt", "ge", "le", "eq") and len(numbers) == 2:
        a, b = numbers
        return Lin(float({"gt": a > b, "lt": a < b, "ge": a >= b, "le": a <= b, "eq": a == b}[name]))
    if name == "cond" and len(numbers) == 3:
        return Lin(numbers[1] if numbers[0] else numbers[2])
    if name == "clamp" and len(numbers) == 3:
        return Lin(min(max(numbers[0], numbers[1]), numbers[2]))
    raise Unknown(f"function {name}")


def _segments(text):
    """Split filled text into lines of [text, style] segments. Style is "" (normal), "note" (an Ascension @ext
    note) or a colour like "ffd100". Blank lines are kept single; texture codes are dropped."""
    text = text.replace("\r\n", "\n").replace("\r", "\n").replace("|n", "\n")
    text = re.sub(r"\|T[^|]*\|t", "", text)
    text = re.sub(r"\|H[^|]*\|h(.*?)\|h", r"\1", text)
    lines, current, colour, note = [], [], "", False
    pos = 0
    pattern = re.compile(r"\|c([0-9a-fA-F]{8})|\|r|\x01|\x02|\n")
    buffer = []

    def flush():
        if buffer:
            piece = "".join(buffer)
            style = "note" if note else colour
            if current and current[-1][1] == style:
                current[-1][0] += piece
            else:
                current.append([piece, style])
            buffer.clear()

    for match in pattern.finditer(text):
        buffer.append(text[pos:match.start()])
        pos = match.end()
        token = match.group(0)
        if token == "\n":
            flush()
            lines.append(current)
            current = []
            continue
        flush()
        if token.startswith("|c"):
            colour = match.group(1)[2:].lower()
        elif token == "|r":
            colour = ""
        elif token == "\x01":
            note = True
        elif token == "\x02":
            note = False
    buffer.append(text[pos:])
    flush()
    lines.append(current)
    cleaned = []
    for line in lines:
        line = [[t.replace("\t", " "), s] for t, s in line if t]
        while line and not line[0][0].strip():
            line.pop(0)
        if line:
            line[0][0] = line[0][0].lstrip()
            line[-1][0] = line[-1][0].rstrip()
            line = [seg for seg in line if seg[0]]
        if line:
            cleaned.append(line)
        elif cleaned and cleaned[-1]:
            cleaned.append([])
    while cleaned and not cleaned[-1]:
        cleaned.pop()
    return cleaned
