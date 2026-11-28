"""Writes launcher/site/builds.json, the example builds on the website's Build planner: the Wildcard builds our bots
aim for. Each Wildcard bot is given one build of its fighting style (tank, healer, melee, ranged or caster) and rolls
towards it (WildcardBuildFor in SQUID's mod-playerbots, src/Ai/Class/Coa/CoaWildcardPicks.cpp).

The builds live in that C++ file, which is not in this repository and not on the VM, so this is run by hand from the
repository root after the pinned SQUID release changes, with a checked-out copy, for example a pre-flight workspace:

  python3 -I scripts/bot_builds.py /tmp/wcN/core/modules/mod-playerbots/src/Ai/Class/Coa/CoaWildcardPicks.cpp

Only names and Character Advancement entry ids are copied: "core" are the entries a build is made of (weight 4),
"support" the ones that feed it (2 or 3). Entries a build avoids (below 0) are left out.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'launcher' / 'site' / 'builds.json'
ROLES = {'Tank': 'Tank', 'Heal': 'Healer', 'Melee': 'Melee', 'Ranged': 'Ranged', 'Caster': 'Caster'}


def parse(text):
    enum = re.search(r'enum BuildId : uint8\s*\{(.*?)\};', text, re.S).group(1)
    ids = [name for name in re.findall(r'\b(BUILD_[A-Z0-9_]+)\b', enum) if name != 'BUILD_COUNT']
    table = re.search(r'constexpr Build BUILDS\[BUILD_COUNT\] = \{(.*?)\n\};', text, re.S).group(1)
    builds = [{'name': name, 'role': ROLES[role], 'core': [], 'support': []}
              for name, role in re.findall(r'\{\s*"([^"]+)",\s*WildcardArchetype::(\w+)\s*\}', table)]
    if len(builds) != len(ids):
        raise SystemExit(f'{len(ids)} build ids but {len(builds)} builds: the file changed shape')
    by_id = dict(zip(ids, builds))
    picks = re.search(r'constexpr BuildPick BUILD_PICKS\[\] = \{(.*?)\n\};', text, re.S).group(1)
    for build_id, entry, weight in re.findall(r'\{\s*(BUILD_[A-Z0-9_]+),\s*(\d+),\s*(-?\d+)\s*\}', picks):
        weight = int(weight)
        if weight >= 4:
            by_id[build_id]['core'].append(int(entry))
        elif weight > 0:
            by_id[build_id]['support'].append(int(entry))
    return builds


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    source = Path(sys.argv[1])
    builds = parse(source.read_text(encoding='utf-8'))
    OUT.write_text(json.dumps({'source': 'SQUID mod-playerbots, CoaWildcardPicks.cpp', 'builds': builds},
                              indent=1, ensure_ascii=False) + '\n', encoding='utf-8')
    print(f'{len(builds)} builds written to {OUT.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
