# Context pack: change risk (likelihood x impact)

Every change to the server is classified before anything is merged, the way a Change Advisory Board would: how
likely it is to go wrong, and how bad it is if it does. The class decides the path. The analyst scores; it does not
fix, merge or deploy.

## Step 1: hard stops (any one = HIGH and never automatic, whatever the scores)
A change that touches any of these always waits for James:
1. Accounts, logins, passwords, security levels, GM or console commands, RBAC.
2. Anything that gives players gold, items, currency, experience or reputation outside normal play.
3. Network setup: ports, bind addresses, the realm list, the Cloudflare tunnel, firewall rules.
4. Secrets, tokens, `signup-settings.json`, or anything that reads or logs them.
5. Patch night itself, the build workflow, the installer, or rollback.
6. The agents' own instructions, permissions, context packs or this matrix.
7. Deleting or rewriting character, account or guild data (rows in the characters or auth databases).
8. The change came from a player issue and asks for something for that player (their account, character or items).

## Step 2: impact (if it goes wrong, how bad?). Score each 1-3; **impact = the highest score**
| Check | 1 | 2 | 3 |
|---|---|---|---|
| I1 Who notices | One feature or a few players | A system most players use (bots, dungeons, auction house, chat) | Everyone: the server will not start, crashes or lags |
| I2 Data | No saved data | World data the server rebuilds or patch night re-applies | Character or account data, or anything it deletes |
| I3 Undo | Change a setting back at the next restart | Revert and rebuild (2-3 h) | Cannot be undone (data already changed, items given) |
| I4 Fairness | Nobody gains or loses | Small balance shift | Players lose progress, items or gold, or one group gains a lasting edge |

## Step 3: likelihood (how likely is it to go wrong?). Score each 1-3 and add them up
| Check | 1 | 2 | 3 |
|---|---|---|---|
| L1 Kind of change | A setting within its documented range, or addon text | Database data, an addon's logic, a script | Server C++ (a patch) |
| L2 Size | One small edit (under ~20 lines, one file) | Under ~200 lines or a few files | Larger, or many files |
| L3 Where it runs | Once, at start or on a command | Per player action | Every tick, every packet, or for all 750 bots |
| L4 Proof before going live | An automatic check proves it (settings check, test, build plus smoke test) | Partly tested | Can only be seen working live |
| L5 Understanding | Cause reproduced with evidence (log lines, a test) | Plausible from the code | A guess |
| L6 Precedent | The same kind of change has gone in cleanly before | Similar changes have | New territory |

Total 6-8 = **low (1)**, 9-12 = **medium (2)**, 13-18 = **high (3)**.

## Step 4: the matrix
| Impact \ Likelihood | Low (1) | Medium (2) | High (3) |
|---|---|---|---|
| **Low (1)** | LOW | LOW | MEDIUM |
| **Medium (2)** | LOW | MEDIUM | HIGH |
| **High (3)** | MEDIUM | HIGH | HIGH |

## Step 5: confidence
The analyst states its confidence in its own scoring:
- **High:** every check scored from evidence.
- **Low:** any check it could not score from evidence, or a total within one point of a band edge, or two checks
  where it hesitated between scores. Low confidence sends the classification itself to Fable (a case file).

## Paths
| Class | Phase 1 (now) | Phase 2 (fully automatic, once the ledger supports it) |
|---|---|---|
| LOW | Automatic: fix, Opus analyst agrees, build and smoke test, merge, installed at the next nightly restart, checked at 4:37 am, rolled back if the check fails. One automatic change per night. | Same. |
| MEDIUM | Fix and Opus review automatic; **James merges**. | Automatic after the Opus review, the build and the smoke test. |
| HIGH | Fix, then **Fable review**; **James merges**. | Automatic only with a Fable "merge" verdict, the build, the smoke test and a staged rollout. Hard stops never become automatic. |
| Low confidence | **Fable classifies** (case file), then the path for its class. | Same. |

Standard changes (pre-approved, always LOW without scoring): a value change to a setting already in
`server-settings.txt`, within the range its comment states; an enchant SQL fix re-applying an existing pattern;
addon text. Add to this list only with James's OK.

## What the analyst returns
```
Change: <PR or issue>
Hard stop: none | <which>
Impact: I1 n, I2 n, I3 n, I4 n -> <low|medium|high>
Likelihood: L1 n, L2 n, L3 n, L4 n, L5 n, L6 n = total -> <low|medium|high>
Class: LOW | MEDIUM | HIGH        Confidence: high | low (why)
Path: <from the table>
Evidence: one line per score that is not 1
```
