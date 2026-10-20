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
| Codes | **No** | Turning on `1KLIKES` etc. needs a republish |
| Anything seasonal or limited-time | **Missing** | Nothing changes from month to month |
| Endgame after Rebirth 10 | **Thin** | More rebirths only add +0.5 each; perks max out |
| Live switches / kill switches | **Missing** | A broken feature means opening Studio and republishing |

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

Endgame, in the same release — C1–C3 built 20 Oct on `claude/endgame-b88fb4` (not merged, not
published). Numbers in `src/shared/Config/Endgame.luau`; each has a pause switch in
[LIVE_CONFIG.md](LIVE_CONFIG.md); tests in `tests/endgame.spec.luau`.
- [x] C1. Rebirth milestones at 12, 15, 16, 17, 18, granted once (`PlayerData.Milestones`), also to
  players already past them on their next join: 12 title "Reborn Veteran", 15 pet Reborn Phoenix
  (Mythic, x16, exclusive), 16 shovel skin "Starforged" (recolours any shovel, on/off in the Rebirth
  panel's new Milestones tab), 17 title "Eternal Digger", 18 pet Eternal Wyrm (Mythic, x20,
  exclusive). Titles replace the layer title on the nameplate. Switch: `pause_milestones`.
  The plan said 20 / 25 / 30, but on the x3.3-per-rebirth cost curve those were out of reach, so the
  owner lowered them to 16 / 17 / 18 and made rebirths past 12 cheaper (20 Oct): rebirths 1–12 cost
  exactly what they did (live players unaffected), rebirths 13–16 grow x1.5 instead of x3.3
  (3.0T, 4.5T, 6.8T, 10T), and from rebirth 17 the x3.3 growth resumes (34T, 110T, ...).
  Economy sim (typical perk plan, real-time estimate), hours of play to reach each rebirth:
  12 ~4.9 h, 13 ~6.4 h, 14 ~8.3 h, 15 ~11.1 h, 16 ~14.9 h, 17 ~26.9 h, 18 ~63.6 h
  (before: 15 ~46 h, 16 ~136 h, 18 ~1,280 h). Rebirth costs are never saved (always computed from
  `PlayerData.Rebirths`), so no save migration was needed.
- [x] C2. Rainbow pets: 5 Golden copies of a pet fuse into 1 Rainbow (FusePets on a Golden pet; same
  rules as Golden: equipped copies are used last and the result stays equipped if one was).
  Rainbow: sand bonus x2.25 (Golden x1.5), digs 1.5x as often (Golden 1.25x), multi-hue sparkling
  look, "RAINBOW" tag. Rainbow can't fuse again. Switch: `pause_fusing` (pauses both fusions).
- [x] C3. Index mastery: a layer whose 3 treasures are all found in all 7 variants (4 sizes + Golden /
  Fossilized / Crystal, i.e. every Index pill lit) is recorded once (`PlayerData.IndexMastered`) and
  gives +3% sand forever (max +45%), on top of the old +2% "layer complete" bonus. The Index shows
  "Mastery n/21" per layer and a ★ on mastered tabs. At luck 1 the rarest pill (Crystal on the
  ~5% treasure) is about 1 in 1,300 finds, so this is a long chase. Switch: `pause_index_rewards`.
  Badge "Index Master" is in Config/Badges with `Id = 0` (TODO, see C4).
- [ ] C4. Badges 11–15 created and wired, plus "Index Master" (needs the owner on a free-quota day).

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
