# Agents: who does what, and where Fable is spent

Fable usage is limited, so it is kept for judgement: deciding what to do and checking what was done. Cheaper models
do the volume in between. Three rules keep it cheap:

1. **Fable never gathers its own context.** A cheaper agent (or James, or the main session) writes a case file from
   `case-file-template.md`: the evidence, the question, the options. Fable answers that one case in a fresh session.
2. **Every Fable answer becomes a precedent.** The ruling is written back into the case file and, when it is a rule
   others can apply, into the matching context pack, so the same question is never paid for twice.
3. **Every Fable call gets a line in `fable-ledger.md`**: what it was for and whether it changed the outcome.

## Roles

| Area | Agent | Model | Job | Status |
|---|---|---|---|---|
| Running | `patch-night-checker` | Haiku | After each patch night: log, settings report, server warnings, downtime. Reports only what is new or wrong. | Stage 1 |
| Reviewing | `patch-reviewer` | Fable | Independent review of any PR that changes `patches/`, from the diff and the description only. | Stage 1 |
| Running | log and crash triage | Haiku | Group Errors.log and crash reports by cause; write a case file for a new one. | Stage 2 |
| Running | crash and lag investigator | Fable | Root cause from a case file. | Stage 2 |
| Updating | patch porter | Sonnet, then Fable | Re-anchor patches after a CoA core update; Fable takes the ones where core logic changed. | Stage 2 |
| Balancing | weekly data pack | Haiku or a script | Levelling speed, gold and auction prices, dungeon runs, battlegrounds, ability and enchant use. | Stage 3 |
| Balancing | balance review | Fable | Monthly: a short ranked list of changes with the evidence for each, for James to accept or reject. | Stage 3 |
| Abilities | ability pass | Sonnet | The ability review in batches by type, applying the conflict rule. | Stage 3 |
| Abilities | ability arbiter | Fable | Flagged outliers and contradictions only; rulings go into a rulebook. | Stage 3 |

Security-adjacent work (login and auth code, packet logging, network setup) goes to Opus, not Fable: Fable has
extra safety measures there and may refuse or water the work down.

## Budget

A starting split of Fable usage: 40% patch review, 30% balance, 20% diagnosis, 10% reserve. Move it after a month
according to the ledger.

## Where things are

- `.claude/agents/*.md` the agents themselves (model, tools, instructions).
- `docs/agents/context/` one-page context packs. An agent reads its pack first instead of exploring the repository.
- `docs/agents/case-file-template.md` the form every Fable case uses; filled-in cases go in `docs/agents/cases/`.
- `docs/agents/fable-ledger.md` the ledger.

Never in a case file, a context pack or the ledger: secrets, Ascension client data, or verbatim client tooltip text
(describe what a tooltip says in your own words). This repository is public.
