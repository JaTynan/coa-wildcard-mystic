# Server performance notes

What has been measured on the VM (8 vCPUs of the i9-9900K host, 18 GB), and what to try next when the world
gets slow. World speed in the manager is the measure: the "95% under" figure matters most (under about 50 ms is
smooth; 100 ms and up feels laggy), and ticks per second only means something with bots awake (an idle server
spins at about 250).

## Measured (7 Nov 2026)

| Setup | Ticks/s | Average | 95% under | Peak | VM memory |
| --- | --- | --- | --- | --- | --- |
| 1,000 bots, 1 map thread | 33 | 30 ms | 61 ms | 489 ms | ~10 GB |
| 1,000 bots, 4 map threads | 50 | 20 ms | 39 ms | 58 ms | ~10 GB |
| 1,500 bots, 4 map threads | 26 | 38 ms | 66 ms | 301 ms | 8.9 GB |

Settled on 1,250. Memory is not the limit; one busy thread per map is (most bots are on Eastern Kingdoms and
Kalimdor), so more vCPUs or map threads add little. The Proxmox host showed no CPU, memory or IO pressure.

## Levers for later (not changed yet)

- `AiPlayerbot.BotActiveAlone` (now 15): share of bots awake away from real players. Dropping it to about 5 lets
  far zones sleep while the zones players are in stay fully alive. Wanted design: zones with players fully active,
  the rest of the world mostly asleep.
- `AiPlayerbot.BotActiveAloneForceWhenInZone` (on, keep): every bot in a player's zone stays awake. Together with
  "gather where players are" this is the biggest cost, and the reason to keep it is that it makes zones lively.
- Sleeping bots still cost a basic update every tick, so the total bot count still matters.
- Worst case to keep in mind: players spread over many zones, each zone full of awake bots (10 zones x 200 bots
  would be about 2,000 awake), which this CPU cannot carry. SmartScale (on) puts far bots to sleep first when the
  tick time rises past 50 ms, and is fully paused at 200 ms.
