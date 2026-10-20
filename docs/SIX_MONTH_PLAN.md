# Six-month autopilot plan: Dig to the Core!

**Goal (owner, 19 Oct 2026):** a game that can run for about six months with little or no hands-on
work. Players still find something new each month, nothing breaks, saves stay safe, and it keeps
earning. **Owner of this plan:** Claude. It comes after [GO_LIVE_PLAN.md](GO_LIVE_PLAN.md): going
public is still step one.

## What "good for six months" means

1. **Stable:** no republish needed to keep it working. Errors stay low and saves are never lost.
2. **Fresh:** something new appears at least every 2–4 weeks: an egg, an event, a code or a
   decoration. All of it ships ahead of time in one build and switches on by date.
3. **Deep enough:** a dedicated player keeps having goals for weeks, not one weekend.
4. **Steerable without code:** the owner can turn things on and off, fix a broken event or add a
   code from the Creator Hub in a few minutes, without Studio.
5. **Earning:** passes and products keep working, and limited-time content gives a fair reason to spend.

## What already runs on its own

| System | Hands-off? | Note |
|---|---|---|
| High Tide (every 20 min) and Golden Hour (every 45 min) | Yes | Computed from the clock, so every server agrees |
| Daily quests (reset 00:00 UTC), 7-day daily rewards | Yes | Same quests every day |
| Weekly leaderboards | Yes | A new key each ISO week, so they reset by themselves |
| Server goal → Golden Hour, friend bonus | Yes | |
| Save safety: session lock, migrations, BindToClose, receipt replay | Yes | Real-DataStore check is still a Phase 2 item |
| Codes | Yes (B) | Live switches since 19 Oct; calendar codes switch on by date (C) |
| Anything seasonal or limited-time | Built (C), not published | Content calendar Nov–Apr, weekend fests, monthly mythics ([CALENDAR.md](CALENDAR.md)) |
| Endgame after Rebirth 10 | **Thin** | More rebirths only add +0.5 each; perks max out |
| Live switches / kill switches | Yes (B) | [LIVE_CONFIG.md](LIVE_CONFIG.md): codes, events, pauses, banner from the Creator Hub |

**How long the content lasts** (`tools/sim/economy.luau`, real config, typical perk plan): Rebirth 5
at about 2.2 h of play. Rebirth costs then grow ×3.3 each, so the Core Breaker at Rebirth 10 takes
roughly 6–10 h in total (estimate, the sim stops at 5). A daily player finishes everything that
matters in 1–3 weeks. That, more than bugs, is what would kill a hands-off game.

## The plan

### A. Go public (in progress, GO_LIVE_PLAN Phases 2–3)

Owner's playtest (phone + PC, a newcomer, one real purchase), fix blockers, switch to Public.
**Nothing below should delay this.** Real players are the only way to know what to tune.

### B. Live controls (Claude) — built 19 Oct on `claude/live-config`, owner guide [LIVE_CONFIG.md](LIVE_CONFIG.md)

Use Roblox **Experience configs** (`ConfigService`). The owner edits values in the Creator Hub and
live servers pick them up in about a minute, with no republish
([docs](https://create.roblox.com/docs/production/configs)).

- [x] B1. A `LiveConfig` server module: reads configs once at boot and on change, falls back to
  the shipped defaults if the service fails, and validates every value (wrong type → default).
- [x] B2. Switches: codes on/off, up to 20 extra codes (reward from a fixed menu), events off, a bonus
  event up to 7 days, pauses for hatching / Auto Dig / leaderboards, an announcement banner.
  Left out on purpose: event multipliers (the client shares that math, so a change would need
  client wiring), an excavation pause and a product pause (a paused purchase risks a lost grant).
  Seasonal on/off arrives with C.
- [x] B3. A one-page owner guide: "to add a code, do this" with screenshots.
- [x] B4. Tests for the fallback and the clamps; the inert-expansion checks stay green.

### C. Content calendar, shipped once (about 2–3 weeks, Claude, after ~2 weeks of live data)

**Calendar built 20 Oct 2026** on `claude/content-calendar-9a732a` (not merged, not published). The
owner guide is [CALENDAR.md](CALENDAR.md). All drops below are in, driven by `Config/Calendar.luau`
and overridable through `events_off` / `bonus_event` / `codes_off` (no new switch). Numbers are first
guesses: retune egg price, pet power and find chances once ~2 weeks of live data are in. Changes from
the table: hatch-speed weekend → Hatch Fest (1.5× egg luck), clover material → Four-Leaf Clover find,
New Year has no egg of its own. The endgame items C1–C4 are a separate branch.

Everything is built into one "autopilot" release and turns on by date (UTC), with B's switches as
an override. Each drop: a limited egg (4 procedural pets, the rare one never comes back), a themed
event modifier, a code, and a small beach decoration swap.

| Window | Drop |
|---|---|
| 26 Nov – 6 Dec | Harvest Dig: cornucopia egg, 1.5× sand weekends |
| 12 Dec – 4 Jan | Winter Beach: snow on the boardwalk, gift egg, daily advent find, "Frozen Tide" event |
| 31 Dec – 3 Jan | New Year: fireworks at midnight UTC, 2× luck |
| 6 – 20 Feb | Lunar New Year + Valentine's: lantern egg, heart treasures |
| 12 – 22 Mar | Lucky Dig (St Patrick's): clover variant material, 2× Golden/Crystal odds |
| 26 Mar – 12 Apr | Spring Hatch: pastel egg, egg-hunt finds hidden in layers 1–5 |
| Every weekend | Rotating Weekend Dig Fest (sand / luck / coin / hatch speed, picked by week number) |
| Every 4 weeks | A "monthly mythic" in the dig-zone loot table, so returning players have a new chase |

Endgame, in the same release:
- C1. Rebirth milestones at 12, 15, 20, 25, 30 with a title, a pet or a shovel skin each.
- C2. Rainbow pets: fuse 5 Golden into 1 Rainbow (one more tier above Golden).
- C3. Index rewards: finishing a layer's treasure set (with variants) gives a permanent small bonus and a badge.
- C4. Badges 11–15 created and wired (needs the owner on a free-quota day).

**Spring Vault** stays out of C unless it passes its own gates first. If it does, it goes in behind a
config switch as the "month 3" surprise. It is never switched on by date alone.

### D. Hands-off running (owner, ~15 min a month)

- A monthly scheduled check (Claude, optional): the owner pastes the Analytics numbers (D1, D7,
  session length, errors, revenue) and Claude lists anything worth a config change.
- Rules: no republish unless something is broken; a broken thing is turned off with a switch first,
  and fixed later.
- Rollback note in STATUS stays current.

## Honest limits

- Roblox recommends games with good D1/D7 retention and session time. A game that never updates
  usually loses traffic slowly. The calendar helps, but it isn't the same as a real update.
- Without sponsored ads or a community (group / Discord), new players depend on the algorithm.
  Ads are optional; they cost Robux and are worth testing only once D1 looks healthy.
- Six months of content can't be tuned before launch. That is why C waits for about two weeks of live data.

## Owner decisions

1. Order: **go public now, then B and C** (recommended), or build B and C before going public.
2. Is the calendar above the right set of holidays for the audience?
3. Create a Roblox group for codes and announcements? (Optional; turns on `DIGDEEP`.)
