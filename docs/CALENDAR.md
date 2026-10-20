# Content calendar (runs by itself)

Everything below is already in the game. Each drop switches on and off by date (UTC), so every
server agrees and you don't need to republish anything. To stop, move or rerun a drop, use the
live switches in [LIVE_CONFIG.md](LIVE_CONFIG.md). Code: `src/shared/Config/Calendar.luau`
(dates, finds, advent gifts), `Events.luau`, `Eggs.luau`, `Pets.luau`, `Treasures.luau`, `Codes.luau`;
world side in `src/server/Services/CalendarService.luau`. Plan: [SIX_MONTH_PLAN.md](SIX_MONTH_PLAN.md) part C.

Dates are UTC. A drop starts at 00:00 on its first day and ends at 00:00 the day after its last day.
For US Eastern time in winter, subtract 5 hours, so Winter Beach starts at 7 pm on Friday 11 Dec.

## The calendar

| Dates (UTC) | Drop | Limited egg (15K coins) | Event | Code | Limited finds | Beach |
|---|---|---|---|---|---|---|
| 26 Nov – 6 Dec | **Harvest Dig** | Cornucopia Egg | Harvest Weekend: 1.5× Sand on Sat/Sun | `HARVEST` | Golden Acorn, Prize Pumpkin | Autumn bunting, pumpkins, egg stand |
| 12 Dec – 4 Jan | **Winter Beach** | Gift Egg | Frozen Tide: 2× Sand for 4 min at :05 and :35 past every hour | `SNOWDAY` | Snow Globe, Frozen Ornament | Snow on the boardwalk, snowmen, egg stand |
| 31 Dec – 3 Jan | **New Year** (inside Winter Beach) | (the Gift Egg keeps going) | 2× Luck all four days; Fireworks: 2× Coins from 00:00 to 00:15 UTC each night | `HAPPY2027` | (none) | Gold/purple bunting, fireworks over the sea at midnight |
| 6 – 20 Feb | **Lanterns & Hearts** (Lunar New Year and Valentine's) | Lantern Egg | Lantern Night: 2× Coins for 5 min at :25 and :55 | `LANTERN` | Candy Heart, Ruby Heart, Golden Lantern | Red/gold bunting, glowing lanterns |
| 12 – 22 Mar | **Lucky Dig** | Clover Egg | 2× odds of Golden, Crystal and Fossilized finds, all 11 days | `LUCKYDIG` | Four-Leaf Clover, Pot of Gold | Green/gold bunting |
| 26 Mar – 12 Apr | **Spring Hatch** | Pastel Egg | 1.5× egg luck, all 18 days | `SPRING` | Painted Egg, Jeweled Egg (layers 1–5 only: an egg hunt) | Pastel bunting, giant painted eggs |
| Every weekend | **Weekend Dig Fest** | | One of Sand Fest, Luck Fest, Coin Fest or Hatch Fest (1.5× each), in turn by week number. Sat 00:00 – Mon 00:00 UTC | | | |
| Every 4 weeks | **Monthly mythic** | | | | One limited Mythic find anywhere in the dig zone, a new one every 28 days from Mon 2 Nov | |

**Each limited egg** has four pets: Common (62%), Rare (28%), Epic (9.2%) and a **Legendary (0.8%)
that never comes back** after the drop. Luck boosts and events raise the odds, and the egg panel
always shows the real odds. The egg appears in the egg panel with a LIMITED tag, and on a pop-up
stand between the west spawn and the Shovel hut, but only during its drop.

**Each code** gives one free hatch of that drop's egg plus a 15-minute boost. `HAPPY2027` gives
about 10 minutes of income plus 1 Rebirth Token instead. Codes work only during their drop, from
00:00 on the first day to 23:59:59 on the last.

**Advent (Winter Beach):** the first time a player digs each day (UTC), they dig up a present.
Gifts rotate between coins, a 10-minute Luck/Sand/Coin boost and a free Gift Egg. On 25 Dec they get
3 Gift Eggs plus a Rebirth Token, and on 1 Jan a Rebirth Token plus about 10 minutes of income.

**Monthly mythics:** Harvest Moon Orb (from 2 Nov), Frostfire Crown (30 Nov), Starfall Shard (28 Dec),
Dragon Pearl (25 Jan), Emerald Tablet (22 Feb), Sunstone Egg (22 Mar), Abyssal Anchor (19 Apr),
Comet Gem (17 May). After that the list starts again. Each one shows up in about 1 in 500 new buried
finds. That's a little rarer than a Relic, and the find is worth about 25 minutes of the player's income.

**Limited finds** are worth seconds of the player's own income, so they matter at every depth.
They don't count towards a layer's Index total, so they never block the layer bonus or badges.

The HUD banner shows every running drop and event with a countdown (days and hours for drops). Each
drop and each event is announced to everyone the moment it starts.

## Overriding it (Creator Hub → Configs, no republish)

| You want to… | Set |
|---|---|
| Stop a whole drop (egg off sale, finds, decorations, advent, its events) | `events_off` = the drop id: `HarvestDig`, `WinterBeach`, `NewYear`, `LunarLove`, `LuckyDig`, `SpringHatch` |
| Stop just one event | `events_off` = `HarvestWeekend`, `FrozenTide`, `Fireworks`, `LanternNight`, or a fest (`FestSand`…) |
| Stop the weekend rotation / the monthly mythic | `events_off` = `WeekendFest` / `MonthlyMythic` |
| Turn a drop's code off | `codes_off` = `SNOWDAY` (etc.) |
| Run a drop early, late or again (egg, finds, decor), up to 7 days | `bonus_event` = the drop id, `bonus_event_ends` = `YYYY-MM-DD HH:MM` |
| Give an extra weekend boost | `bonus_event` = `FestLuck` (or any event id) |

Combine them with commas, e.g. `events_off` = `FrozenTide,MonthlyMythic`. A bonus drop does not
bring back its code or its dated modifiers. For a code, use `extra_codes`. Bringing back an egg
with `bonus_event` also brings back its "never returns" pet, so that's your call.

## What to retune once live numbers are in

The plan wanted about two weeks of live data before setting numbers. All of these are plain values
in config:

- **Egg price** (15,000 coins) and **weights** in `Config/Eggs.luau`. Pet power is in
  `Config/Pets.luau`: 1.3 / 1.6 / 2.0 / 3.0. That's strong for new players and a collectible for veterans.
- **Find chances** per drop (`Calendar.luau`, `Finds[].Chance` = share of new buried finds) and the
  mythic's `Chance` (1/500).
- **Event strength**: `Multiplier` in `Config/Events.luau`.
- **Dates**: `Starts`/`Ends` in `Calendar.luau`. Each drop's event, egg and code follow its dates,
  and the game refuses to start if they disagree.

## Left out or changed from the plan

- **Hatch speed** weekend → **Hatch Fest (1.5× egg luck)**. Hatching is already instant, so a speed
  bonus would do nothing.
- **Clover variant material** → a **Four-Leaf Clover** limited find. A new material would have changed
  the odds of every find and the save format. Lucky Dig's 2× applies to all three rare materials
  (Golden, Crystal, Fossilized), not just Golden and Crystal.
- **New Year** has no egg of its own: it runs inside Winter Beach, so the Gift Egg covers it.
- **Limited finds have no Index page yet.** They are saved in the player's Index, but the book still
  only shows layer sets. A "Limited" tab is a small follow-up.
- The pop-up egg stand sits at `Layout.SEASON_STAND` = (-58, 1024, 26), on clear sand by the
  crate yard. Checked in a Studio Play session on 20 Oct 2026 with Winter Beach forced on. The first
  spot (-20, 19) overlapped plaza props.
