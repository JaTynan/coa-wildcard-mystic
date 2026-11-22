#!/usr/bin/env python3
"""Re-derive the facts this skill states about the repository, so they can be checked after any change.

Usage (from anywhere; read-only, Python 3 standard library only):
    python3 -I repo_facts.py [--repo <checkout>] [--core <pinned core clone>] [section ...]

Sections (default: all):
    tables   every wcme_* database table our SQL or patches create, where, and who reads it
    hooks    every AzerothCore script hook our patches override, per patch file
    confs    the config files server-settings.txt writes to, with a count of settings each
    bots     every place a patch tells a bot from a real player, by guard used
    options  how many config options the patches read with sConfigMgr->GetOption<T>

With --core pointing at a checkout of the pinned CoA core, "hooks" also says which ScriptDefines header
declares each hook, and flags any hook the core does not declare (a method of the patched class, or a typo).
"""
import argparse
import collections
import os
import re
import sys

sys.dont_write_bytecode = True

HOOK = re.compile(r"\b(?:void|bool|uint32|int32|float)\s+((?:On|Can|Modify)[A-Z]\w+)\s*\(")
CREATE = re.compile(r"CREATE\s+(TEMPORARY\s+)?TABLE(?:\s+IF\s+NOT\s+EXISTS)?\s+[`\w.$]*?`?(wcme_\w+)`?", re.I)
USE = re.compile(r"\b(?:FROM|INTO|UPDATE|JOIN)\s+(?:`?\$?\w+`?\.)?`?(wcme_\w+)`?", re.I)
GUARDS = ("GetSession()->IsBot()", "session->IsBot()", "IsRealPlayer(", "GET_PLAYERBOT_AI(", "IsWildcardHeroBot(",
          "HasGameClientMaster(")


def read(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        return handle.read()


def files(root, *folders):
    for folder in folders:
        base = os.path.join(root, folder)
        for directory, _, names in os.walk(base):
            for name in sorted(names):
                if name.endswith((".sql", ".ps1", ".patch", ".py", ".cmd")):
                    yield os.path.join(directory, name)


def tables(repo, _core):
    created, used = collections.defaultdict(list), collections.defaultdict(set)
    for path in files(repo, "sql", "patches", "patch-night", "signup"):
        rel = os.path.relpath(path, repo)
        for number, line in enumerate(read(path).splitlines(), 1):
            for match in CREATE.finditer(line):
                kind = "TEMPORARY " if match.group(1) else ""
                created[match.group(2)].append(f"{kind}{rel}:{number}")
            for match in USE.finditer(line):
                used[match.group(1)].add(rel)
            if rel.startswith("patches"):  # a table handed to the core by name, e.g. LOAD_DBC(..., "wcme_spellaffect_dbc")
                for name in re.findall(r"\"(wcme_\w+_dbc)\"", line):
                    used[name].add(rel)
    print(f"wcme_* tables created: {len(created)}")
    for name in sorted(created):
        readers = sorted(p for p in used[name] if p.startswith("patches"))
        print(f"  {name}")
        print(f"      created: {', '.join(created[name])}")
        print(f"      C++ readers (patches): {', '.join(readers) or '-'}")
        print(f"      SQL files touching it: {sum(1 for p in used[name] if p.startswith('sql'))}")
    orphans = sorted(set(used) - set(created))
    if orphans:
        print("Used but never created here (check spelling):", ", ".join(orphans))


def declared_hooks(core):
    found = {}
    base = os.path.join(core, "src", "server", "game", "Scripting", "ScriptDefines")
    if not os.path.isdir(base):
        sys.exit(f"--core: no {base}")
    for name in sorted(os.listdir(base)):
        if name.endswith(".h"):
            for match in re.finditer(r"virtual\s+[\w:<>*& ]+?\s+(\w+)\s*\(", read(os.path.join(base, name))):
                found.setdefault(match.group(1), name)
    return found


def hooks(repo, core):
    declared = declared_hooks(core) if core else None
    per_file, everything = {}, collections.Counter()
    for path in files(repo, "patches"):
        names = sorted(set(HOOK.findall(read(path))))
        if names:
            per_file[os.path.basename(path)] = names
            everything.update(names)
    for name, names in per_file.items():
        print(f"  {name}: {' '.join(names)}")
    print(f"Distinct hook-shaped methods: {len(everything)}; patch files using any: {len(per_file)}")
    if declared is not None:
        print("Declared by the core in:")
        for hook in sorted(everything):
            print(f"  {hook:36} {declared.get(hook, 'NOT A CORE HOOK (method of a patched class, or a typo)')}")


def confs(repo, _core):
    counts = collections.Counter()
    path = os.path.join(repo, "server-settings", "server-settings.txt")
    for line in read(path).splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "|" in line:
            counts[line.split("|", 1)[0].strip()] += 1
    for name, count in sorted(counts.items()):
        print(f"  {count:4}  {name}")
    print(f"Total settings lines: {sum(counts.values())}")


def bots(repo, _core):
    for guard in GUARDS:
        hits = []
        for path in files(repo, "patches"):
            count = read(path).count(guard)
            if count:
                hits.append(f"{os.path.basename(path)} x{count}")
        print(f"  {guard:28} {', '.join(hits) or '-'}")


def options(repo, _core):
    kinds, names = collections.Counter(), set()
    for path in files(repo, "patches"):
        for kind, name in re.findall(r"GetOption<([\w:]+)>\(\s*\"([^\"]+)\"", read(path)):
            kinds[kind] += 1
            names.add(name)
    print(f"  distinct option names read by patches: {len(names)}")
    for kind, count in kinds.most_common():
        print(f"  GetOption<{kind}>: {count} call sites")


SECTIONS = {"tables": tables, "hooks": hooks, "confs": confs, "bots": bots, "options": options}


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--repo", default=os.path.abspath(os.path.join(here, "..", "..", "..", "..")))
    parser.add_argument("--core", help="checkout of the pinned Corfirean/azerothcore-wotlk-coa commit")
    parser.add_argument("sections", nargs="*", choices=[*SECTIONS, []], default=[])
    args = parser.parse_args()
    if not os.path.isdir(os.path.join(args.repo, "patches")):
        sys.exit(f"{args.repo} does not look like the coa-wildcard-mystic checkout (no patches folder)")
    for name in args.sections or list(SECTIONS):
        print(f"== {name}")
        SECTIONS[name](args.repo, args.core)
        print()


if __name__ == "__main__":
    main()
