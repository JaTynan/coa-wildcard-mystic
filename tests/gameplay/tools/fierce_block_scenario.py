"""Writes tests/gameplay/scenarios/wcme-fierce-block-multiplier.json (1,600 strikes are too many to keep by hand).

Run from the repository root: python3 tests/gameplay/tools/fierce_block_scenario.py
"""
import json
from pathlib import Path

LOC = {"map": 0, "x": -9617.06, "y": -288.949, "z": 57.3053, "o": 0}
W = {"action": "wait", "label": "Let login settle", "ms": 5000}
OUT = Path(__file__).resolve().parents[1] / "scenarios" / "wcme-fierce-block-multiplier.json"


def A(**k): return {"action": "assert", **k}
def S(**k): return {"action": "snapshot", **k}


def write(fn, d):
    with open(OUT, 'w') as f:
        json.dump(d, f, indent=2)
        f.write('\n')


shield = [{"action": "learn", "label": "Block", "actor": "pal", "spell": 107},
          {"action": "learn", "label": "Shield proficiency", "actor": "pal", "spell": 9116},
          {"action": "add_item", "actor": "pal", "item": 2362},
          {"action": "equip", "label": "Shield in the off hand", "actor": "pal", "item": 2362, "slot": 16},
          {"action": "wait", "ms": 1000}]

# 7. Fierce Block (statistical)
N=800
def phase(tag):
    st=[S(actor="pal",metric="spell_damage_count",spell=2180275,caster="dummy",target="pal",blocked=True,save_as=f"{tag}_blocked"),
        S(actor="pal",metric="spell_damage_count",spell=2180275,caster="dummy",target="pal",save_as=f"{tag}_hits")]
    for i in range(N):
        st.append({"action":"cast","actor":"dummy","spell":2180275,"target":"pal"})
        if i%50==49: st.append({"action":"set_health","actor":"pal","value":1000000})
    st.append({"action":"wait","ms":2000})
    return st
steps=[W]+[dict(s,actor="pal") if s.get("actor")=="pal" else s for s in shield]+[
  {"action":"set_combat_avoidance","actor":"pal","dodge":0,"parry":0},
  {"action":"set_health","actor":"pal","maximum":1000000,"value":1000000},
  {"action":"set_aura","label":"Fixture: +25% block chance (Sword and Board)","actor":"pal","spell":2153442,"stacks":1},
  {"action":"wait","ms":1000},
  A(label="SETUP: block chance in the middle range, so 1.6 times is measurable",actor="pal",metric="block_chance",min=20,max=45)]
steps+=phase("plain")
steps+=[A(label="SETUP: enough strikes landed",actor="pal",metric="spell_damage_count",spell=2180275,caster="dummy",target="pal",relative_to="plain_hits",min=700),
  S(actor="pal",metric="spell_damage_count",spell=2180275,caster="dummy",target="pal",blocked=True,relative_to="plain_blocked",save_as="plain"),
  A(label="SETUP: blocks happen without Righteous Fury",actor="pal",metric="spell_damage_count",spell=2180275,caster="dummy",target="pal",blocked=True,relative_to="plain_blocked",min=100),
  {"action":"learn","actor":"pal","spell":25780},
  {"action":"cast","actor":"pal","spell":25780,"target":"pal"},
  A(label="SETUP: Righteous Fury applies Fierce Block",actor="pal",metric="aura",spell=986051,equals=1,within_ms=2000),
  S(actor="pal",metric="spell_damage_count",spell=2180275,caster="dummy",target="pal",blocked=True,save_as="fury_start")]
steps+=phase("fury")
steps+=[A(label="SETUP: enough strikes landed",actor="pal",metric="spell_damage_count",spell=2180275,caster="dummy",target="pal",relative_to="fury_hits",min=700),
  A(label="Fierce Blows blocked about 1.6 times as often (not 1.0, not the +60 points' ~3)",actor="pal",metric="spell_damage_count",spell=2180275,caster="dummy",target="pal",blocked=True,relative_to="fury_start",ratio_to="plain",min=1.35,max=1.9)]
write('wcme-fierce-block-multiplier.json',{"schema":1,
 "name":"Righteous Fury's Fierce Block: Fierce Blows are blocked 1.6 times as often (PRs #275, #279)",
 "contract":f"With Righteous Fury (25780, linked companion 986051: 6000) and a shield, the chance to block a Fierce Blow is multiplied by 1.6 (James, 25 Nov 2026). A dummy casts Tank Dummy Fierce Blow (2180275, one of the 44 Fierce Blow ids) at the paladin {N} times without and {N} times with Righteous Fury; block chance is raised to about 30% by a fixture aura so the change is measurable. Expected ratio of blocked strikes 1.6; the bounds 1.35-1.9 hold for {N} strikes each at about 3 standard deviations, and exclude both no effect (1.0) and the old flat +60 points (about 3).",
 "timeout_ms":600000,"location":LOC,"players":[{"id":"pal","race":1,"class":2,"level":80,"allow_regeneration":False}],
 "creatures":[{"id":"dummy","owner":"pal","entry":36,"level":80,"health":1000000,"distance":3,"spell_hit_bonus":100}],
 "steps":steps})
