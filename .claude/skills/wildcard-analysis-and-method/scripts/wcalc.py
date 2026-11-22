#!/usr/bin/env python3
"""Small calculators for the analysis recipes in wildcard-analysis-and-method.

Python 3 standard library only. Reads nothing from the server; every number is an input you give it.
Run:  python3 -I wcalc.py <command> --help

Commands
  proc      procs per minute and buff uptime from chance, trigger rate, internal cooldown, duration
  jump      chain-spell jump multipliers: flat modifier added to the multiplier vs counted as points
  ticks     ticks per second <-> milliseconds per tick, and whether the world loop is saturated
  amdahl    how much of a tick did NOT speed up when threads were added
  spike     what a rare long tick does to the mean and which percentile can see it
  mojibake  growth of a UTF-8 file re-read as Windows-1252 and re-written as UTF-8 on every write
  overflow  does a byte total fit a signed 32-bit integer
  drops     expected card drops by quality from a per-mille chance and quality weights
  rate      expected value per hour from seconds per action and value per action
"""
import argparse
import math
import sys

sys.dont_write_bytecode = True

# Windows-1252 as Windows PowerShell's Get-Content decodes it: bytes 0x80-0x9F are typographic characters,
# five of them undefined and kept as their own code (same table as server-settings/Apply-ServerSettings.ps1).
CP1252_HIGH = [0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039,
               0x0152, 0x8D, 0x017D, 0x8F, 0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
               0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178]


def read_as_1252(data: bytes) -> str:
    return ''.join(chr(CP1252_HIGH[b - 0x80]) if 0x80 <= b <= 0x9F else chr(b) for b in data)


def cmd_proc(a):
    if not 0 < a.chance <= 1:
        sys.exit('--chance is a fraction: 0.35 for 35%')
    per_sec = a.triggers_per_min / 60.0
    mu = a.chance * per_sec                      # proc attempts that succeed, per second, with no cooldown
    if mu <= 0:
        sys.exit('no triggers, no procs')
    cycle = a.icd + 1.0 / mu                     # mean time from one proc to the next
    print(f'Triggers: {a.triggers_per_min:g} per minute, chance {a.chance:.0%}, internal cooldown {a.icd:g} s')
    print(f'  no cooldown, 100% chance (a "runaway"): {a.triggers_per_min:g} procs per minute')
    print(f'  with this chance, no cooldown:          {mu * 60:.1f} procs per minute')
    print(f'  with this chance and cooldown:          {60 / cycle:.1f} procs per minute '
          f'(one every {cycle:.1f} s on average)')
    if a.icd > 0:
        print(f'  ceiling set by the cooldown alone:      {60 / a.icd:.1f} procs per minute')
    if a.duration > 0:
        d = a.duration
        up = d if d <= a.icd else a.icd + (1 - math.exp(-mu * (d - a.icd))) / mu
        print(f'  uptime of a {d:g} s buff that each proc refreshes: {min(1.0, up / cycle):.0%}')
        if a.stacks > 1:
            print(f'  time to {a.stacks} stacks if none fall off: about {a.stacks * cycle:.0f} s')
    print('Model: triggers arrive at random at the stated average rate. Evenly spaced triggers give slightly')
    print('different figures; treat the result as an estimate to compare with a count taken in game.')


def cmd_jump(a):
    print(f'Base multiplier per jump {a.base:g}; modifier "loses {a.flat:g}% less per jump"; {a.jumps} jumps')
    wrong = a.base + a.flat
    right = (a.base * 100.0 + a.flat) / 100.0
    print(f'  added straight onto the multiplier: {a.base:g} + {a.flat:g} = {wrong:g} per jump')
    print(f'  counted as percentage points:       ({a.base:g} x 100 + {a.flat:g}) / 100 = {right:g} per jump')
    print('  hit   unmodified   straight-on   as points   (first hit = 1)')
    for n in range(a.jumps + 1):
        print(f'  {n + 1:>3}   {a.base ** n:>10.3f}   {wrong ** n:>11.1f}   {right ** n:>9.3f}')


def cmd_ticks(a):
    if a.per_sec is not None and a.avg_ms is not None:
        busy = a.per_sec * a.avg_ms
        print(f'{a.per_sec:g} ticks/s x {a.avg_ms:g} ms = {busy:.0f} ms of work in each second')
        if busy >= 950:
            print('  about 1,000: the loop is saturated (each tick starts as the last one ends), so ticks/s is')
            print('  just 1000 / average ms and carries no extra information.')
        else:
            print(f'  under 1,000: the loop is idle about {100 - busy / 10:.0f}% of the time.')
    elif a.per_sec is not None:
        print(f'{a.per_sec:g} ticks/s -> {1000 / a.per_sec:.1f} ms per tick if the loop is saturated')
    elif a.avg_ms is not None:
        print(f'{a.avg_ms:g} ms per tick -> at most {1000 / a.avg_ms:.1f} ticks/s')
    else:
        sys.exit('give --per-sec, --avg-ms or both')
    if a.bots and a.avg_ms:
        print(f'  {a.avg_ms:g} ms / {a.bots} bots = {a.avg_ms * 1000 / a.bots:.1f} microseconds per bot per tick '
              '(all bots, asleep or awake, lumped together)')


def cmd_amdahl(a):
    speedup = a.before / a.after
    if a.threads <= 1 or speedup <= 1:
        sys.exit('needs more than one thread and a real speed-up')
    serial = (1 / speedup - 1 / a.threads) / (1 - 1 / a.threads)
    print(f'{a.before:g} ms -> {a.after:g} ms on {a.threads} threads: {speedup:.2f}x faster (a perfect split '
          f'would be {a.threads}x)')
    print(f'  share of the tick that did not speed up: {serial:.0%}')
    print(f'  best possible with unlimited threads:    {a.before * serial:.1f} ms '
          f'({1 / serial:.1f}x faster than one thread)')


def cmd_spike(a):
    normal = (60000.0 - a.per_min * a.spike_ms) / a.median
    if normal <= 0:
        sys.exit('the spikes alone fill the minute')
    total = normal + a.per_min
    mean = 60000.0 / total
    share = a.per_min / total
    print(f'Typical tick {a.median:g} ms, {a.per_min:g} tick(s) of {a.spike_ms:g} ms per minute')
    print(f'  ticks per minute: about {total:.0f}; long ones are {share:.3%} of them (1 in {total / a.per_min:.0f})')
    print(f'  mean tick: {mean:.1f} ms (typical {a.median:g} ms): the average moves {mean - a.median:.1f} ms')
    for p in (95, 99, 99.9, 99.99):
        sees = share > (100 - p) / 100
        print(f'  {p:g}th percentile {"shows" if sees else "does NOT show"} the long ticks')
    print(f'  a player feels each one as a {a.spike_ms / 1000:g} s freeze, {a.per_min:g} time(s) a minute.')
    print('Count ticks over a threshold and keep the worst tick; averages and the 95% figure hide these.')


def cmd_mojibake(a):
    if a.text is not None:
        data = a.text.encode('utf-8')
        print(f'start: {len(data)} bytes  {a.text!r}')
        for n in range(1, a.writes + 1):
            before = len(data)
            data = read_as_1252(data).encode('utf-8')
            print(f'write {n:>2}: {len(data):>10,} bytes  (x{len(data) / before:.2f})')
        return
    if not (a.start_kb and a.end_kb):
        sys.exit('give --text "..." to simulate, or --start-kb and --end-kb with --writes to solve')
    grown = (a.end_kb - a.start_kb) * 1024.0
    print(f'{a.start_kb:g} KB -> {a.end_kb:g} KB in {a.writes} writes: {a.end_kb / a.start_kb:.0f}x overall')
    print('ASCII bytes never change; each non-ASCII byte becomes 2 or 3 bytes on every write.')
    print('  growth per write   non-ASCII bytes at the start that explain it')
    for g in (2.0, 2.25, 2.5, 3.0):
        print(f'  x{g:<17g} {grown / (g ** a.writes - 1):>12,.2f}')
    print(f'At x2 the last write alone added about {grown / 2 / 1024 / 1024:.0f} MB: the file doubles each time')
    print('once the garbled part outweighs the rest, so size against write number is a straight line on a')
    print('log scale. Constant growth per write (a line appended each time) would not look like that.')


def cmd_overflow(a):
    total = int(a.gb * 1024 ** 3)
    limit = 2 ** 31 - 1
    print(f'{a.gb:g} GB = {total:,} bytes; a signed 32-bit integer holds up to {limit:,} (just under 2 GB)')
    print(f'  {"DOES NOT FIT" if total > limit else "fits"}: {total / limit:.1f}x the limit')
    print('Any byte count, millisecond count or product that can pass 2,147,483,647 needs 64-bit or double maths.')


def cmd_drops(a):
    weights = [float(w) for w in a.weights.split(',')]
    names = ['common', 'uncommon', 'rare', 'epic', 'legendary'][:len(weights)]
    names += [f'quality {i}' for i in range(len(names), len(weights))]
    total = sum(weights)
    chance = a.per_mille / 1000.0
    cards = a.kills * chance
    print(f'{a.per_mille:g} per mille = {chance:.1%} per kill; {a.kills:g} kills -> {cards:g} cards expected')
    for name, w in zip(names, weights):
        share = w / total
        per = cards * share
        print(f'  {name:<10} weight {w:>4g} = {share:>5.1%}  -> {per:>6.2f} cards, one per '
              f'{1 / (chance * share):>7,.0f} kills')
    print('Weights of a quality with no droppable card are left out of the total by the patch, so check the')
    print('card list before trusting the shares. A weight list of the wrong length falls back to an even pick.')


def cmd_rate(a):
    per_hour = 3600.0 / a.seconds_per_action
    print(f'{a.seconds_per_action:g} s per action -> {per_hour:.0f} actions an hour')
    print(f'  x {a.value_per_action:g} {a.unit} each = {per_hour * a.value_per_action:.1f} {a.unit} an hour')
    if a.success < 1:
        print(f'  at {a.success:.0%} success: {per_hour * a.value_per_action * a.success:.1f} {a.unit} an hour')


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    s = p.add_subparsers(dest='cmd', required=True)

    q = s.add_parser('proc', help='proc rate and uptime')
    q.add_argument('--chance', type=float, required=True, help='fraction, 0.33 for 33%%')
    q.add_argument('--triggers-per-min', type=float, required=True, help='qualifying hits or casts per minute')
    q.add_argument('--icd', type=float, default=0.0, help='internal cooldown in seconds')
    q.add_argument('--duration', type=float, default=0.0, help='buff duration in seconds (0 = skip uptime)')
    q.add_argument('--stacks', type=int, default=1)
    q.set_defaults(fn=cmd_proc)

    q = s.add_parser('jump', help='chain jump multiplier')
    q.add_argument('--base', type=float, default=0.8)
    q.add_argument('--flat', type=float, default=20.0)
    q.add_argument('--jumps', type=int, default=3)
    q.set_defaults(fn=cmd_jump)

    q = s.add_parser('ticks', help='ticks/s and ms')
    q.add_argument('--per-sec', type=float)
    q.add_argument('--avg-ms', type=float)
    q.add_argument('--bots', type=int)
    q.set_defaults(fn=cmd_ticks)

    q = s.add_parser('amdahl', help='unsped-up share of a tick')
    q.add_argument('--before', type=float, required=True, help='ms per tick on one thread')
    q.add_argument('--after', type=float, required=True, help='ms per tick on N threads')
    q.add_argument('--threads', type=int, required=True)
    q.set_defaults(fn=cmd_amdahl)

    q = s.add_parser('spike', help='rare long ticks against the mean and percentiles')
    q.add_argument('--median', type=float, required=True, help='typical tick in ms')
    q.add_argument('--spike-ms', type=float, required=True)
    q.add_argument('--per-min', type=float, default=1.0)
    q.set_defaults(fn=cmd_spike)

    q = s.add_parser('mojibake', help='encoding growth')
    q.add_argument('--text', help='simulate on this text')
    q.add_argument('--start-kb', type=float)
    q.add_argument('--end-kb', type=float)
    q.add_argument('--writes', type=int, default=16)
    q.set_defaults(fn=cmd_mojibake)

    q = s.add_parser('overflow', help='32-bit fit')
    q.add_argument('--gb', type=float, required=True)
    q.set_defaults(fn=cmd_overflow)

    q = s.add_parser('drops', help='card drops by quality')
    q.add_argument('--per-mille', type=float, default=30)
    q.add_argument('--weights', default='50,28,14,6,2')
    q.add_argument('--kills', type=float, default=1000)
    q.set_defaults(fn=cmd_drops)

    q = s.add_parser('rate', help='value per hour')
    q.add_argument('--seconds-per-action', type=float, required=True)
    q.add_argument('--value-per-action', type=float, required=True)
    q.add_argument('--unit', default='units')
    q.add_argument('--success', type=float, default=1.0, help='fraction of actions that pay')
    q.set_defaults(fn=cmd_rate)

    a = p.parse_args()
    a.fn(a)


if __name__ == '__main__':
    main()
