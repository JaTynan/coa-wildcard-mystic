"""Shared helpers for the Wildcard diagnostics scripts. Python 3.8+, standard library only.

Not a script: imported by the others, which add their own folder to sys.path first so it also works
under `python -I` (isolated mode, the way this repository runs its Python tools).
"""
import codecs
import re
from datetime import datetime
from pathlib import Path

TESTED_REAL = ("Tested on 2026-11-22 against the real {what} copied from the server that day (one day of data) and "
               "against the SYNTHETIC samples. Check the output by eye when a log's format changes.")
TESTED_SYNTHETIC = ("Tested on synthetic data matching the writer's format on 2026-11-22 (the real {what} was not "
                    "available); the first run on the real file should be checked by eye.")


def safe_stdout():
    """A Windows console in an ANSI code page cannot print every character a log may hold; print '?'
    for those instead of stopping with UnicodeEncodeError."""
    import sys
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(errors="replace")
        except (AttributeError, ValueError):
            pass


def read_lines(path):
    """Yield the lines of a text file whatever Windows wrote it as (UTF-8, UTF-8 with BOM, UTF-16,
    or an ANSI code page). Undecodable bytes become U+FFFD instead of stopping the run."""
    path = Path(path)
    with open(path, "rb") as handle:
        head = handle.read(4)
    if head.startswith(codecs.BOM_UTF16_LE) or head.startswith(codecs.BOM_UTF16_BE):
        encoding = "utf-16"
    elif head.startswith(codecs.BOM_UTF8):
        encoding = "utf-8-sig"
    else:
        encoding = "utf-8"
    with open(path, "r", encoding=encoding, errors="replace", newline=None) as handle:
        for line in handle:
            yield line.rstrip("\r\n")


def percentile(values, p):
    """Percentile with linear interpolation between neighbours (the same rule the world server uses
    in UpdateTime::GetPercentile). `values` need not be sorted. Returns None for an empty list."""
    if not values:
        return None
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    index = (p / 100.0) * (len(ordered) - 1)
    low = int(index)
    high = min(low + 1, len(ordered) - 1)
    return ordered[low] + (ordered[high] - ordered[low]) * (index - low)


def mean(values):
    return sum(values) / len(values) if values else None


def fmt(value, digits=0, unit=""):
    if value is None:
        return "-"
    return f"{value:.{digits}f}{unit}"


def table(headers, rows, right=None):
    """Plain fixed-width text table. `right` is a set of column indexes to right-align
    (default: every column except the first)."""
    rows = [[str(c) for c in row] for row in rows]
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(cell))
    if right is None:
        right = set(range(1, len(headers)))

    def line(cells):
        parts = [cells[i].rjust(widths[i]) if i in right else cells[i].ljust(widths[i]) for i in range(len(cells))]
        return "  ".join(parts).rstrip()

    out = [line(headers), line(["-" * w for w in widths])]
    out += [line(row) for row in rows]
    return "\n".join(out)


_WHEN = re.compile(r"^(\d{4})-(\d\d)-(\d\d)(?:[ T_](\d\d):(\d\d)(?::(\d\d))?)?$")


def parse_when(text):
    """'2026-11-21', '2026-11-21 17:30' or '2026-11-21T17:30:00' -> datetime (no time zone: the same
    clock the log was written with). Raises ValueError with a readable message."""
    match = _WHEN.match(text.strip())
    if not match:
        raise ValueError(f"cannot read the time '{text}': use YYYY-MM-DD or 'YYYY-MM-DD HH:MM'")
    year, month, day, hour, minute, second = (int(g) if g else 0 for g in match.groups())
    return datetime(year, month, day, hour, minute, second)


def when_arg(text):
    """argparse type wrapper around parse_when."""
    import argparse
    try:
        return parse_when(text)
    except ValueError as error:
        raise argparse.ArgumentTypeError(str(error))
