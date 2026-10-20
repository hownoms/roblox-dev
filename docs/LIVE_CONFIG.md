# Live switches (no republish)

You can change these from the Creator Hub while the game is live. Servers that are already running
pick up a change within about a minute. Code: `src/server/Services/LiveConfig.luau`.

**If you set nothing, the game runs exactly as published.** A value the game can't use is ignored
and the published behaviour stays. The server logs the reason in the Developer Console (F9 → Server)
as `[LiveConfig] ignored ...`.

## How to change one

1. Creator Hub → **Dig to the Core!** → **Configs** → **Create config** (or click an existing key to edit it).
2. Type the **key** exactly as in the table below, pick the **type** shown, enter the value, then **Next**.
3. Skip targeting. Click **Publish now**.
4. To undo: **Configs → History → Restore** on the old value, then publish again. Deleting the key also
   puts the game back to normal.

**Already created (20 Oct 2026):** `pause_hatching`, `pause_autodig` and `pause_leaderboards` exist,
set to `False`. To pause something, click the key, change it to `True`, then **Publish now** and confirm the dialog.
The string keys aren't created yet, because Roblox won't save a blank value. Create them the first time you use one.

Times are always **UTC**. 8 pm US Eastern on a Friday in winter is `Sat 01:00 UTC`.

## The switches

| Key | Type | Example | What it does |
|---|---|---|---|
| `announcement` | string | `Double luck all weekend!` | Gold banner for everyone. It shows once when you publish, and to each player about 12 s after they join. Max 140 characters. Delete the key to stop it |
| `codes_on` | string | `1KLIKES` | Turns on shipped codes that are off. Comma list |
| `codes_off` | string | `RELEASE` | Turns off shipped codes. Comma list. Wins over `codes_on` |
| `extra_codes` | JSON | see below | New codes without a republish (max 20) |
| `bonus_event` | string | `HighTide`, `GoldenHour`, `FestLuck`, `WinterBeach`… | Runs that event on every server until `bonus_event_ends`. A calendar drop id runs the whole drop (egg, finds, decorations) out of season |
| `bonus_event_ends` | string | `2026-11-02 04:00` | End of the bonus (UTC), at most 7 days ahead |
| `events_off` | string | `HighTide` | Those events stop running. Use this if one is broken or being abused. Also takes a calendar drop id (`WinterBeach` stops its egg, finds, decorations, advent and events), `WeekendFest` or `MonthlyMythic`. See [CALENDAR.md](CALENDAR.md) |
| `pause_hatching` | boolean | `true` | Egg hatching refuses with "paused for a moment". Purchases still grant |
| `pause_autodig` | boolean | `true` | The Auto Dig pass stops digging until you set it back to `false` |
| `pause_leaderboards` | boolean | `true` | Stops all leaderboard DataStore traffic (boards show this server only) |
| `pause_fusing` | boolean | `true` | Pet fusion (5 → Golden and 5 Golden → Rainbow) refuses with "paused for a moment". Pets already fused stay |
| `pause_milestones` | boolean | `true` | Rebirth milestone rewards (rebirth 12 / 15 / 16 / 17 / 18) are held back. Nothing is lost: players get them when they rejoin or rebirth after you set it back to `false` (online players get them within about a minute) |
| `pause_index_rewards` | boolean | `true` | No new Index mastery is recorded. Players keep the +3% bonuses they already have; new ones are recorded once you set it back to `false` |

Shipped codes today: `RELEASE`, `SANDY` (on), `DIGDEEP` (group only, off), `1KLIKES` (off), and the
calendar codes `HARVEST`, `SNOWDAY`, `HAPPY2027`, `LANTERN`, `LUCKYDIG`, `SPRING`. Each works only
during its drop's dates ([CALENDAR.md](CALENDAR.md)). `codes_off` turns one off, but `codes_on`
can't make one work outside its dates. Use `extra_codes` for that.

### `extra_codes`

```json
{
  "HALLOWEEN": { "reward": "luck_boost", "expires": "2026-11-02" },
  "THANKYOU":  { "reward": "coins" }
}
```

- Code names use 2–20 letters or digits. Players can type them in any case.
- `expires` is optional. A bare date means the end of that day (UTC); `"2026-11-02 18:00"` also works.
- Each player can redeem each code once, forever, even if you delete it and add it again later.
- Rewards come from a fixed menu, so a typo can't give away something huge:

| `reward` | Gives |
|---|---|
| `sand_boost` | Sand Boost, 15 min |
| `luck_boost` | Luck Boost, 15 min |
| `coin_boost` | Coin Boost, 15 min |
| `coins` | About 5 min of the player's own income (`ScaledCoins` 300) |
| `big_coins` | About 10 min of income (`ScaledCoins` 600) |
| `beach_egg` | One free Beach Egg hatch |

## Common jobs

- **A calendar drop is broken:** set `events_off` to its id (e.g. `WinterBeach`). Its egg leaves the
  shop, its finds and decorations stop and the beach goes back to normal within a minute.
- **Run a drop again for a weekend:** `bonus_event` = `HarvestDig`, `bonus_event_ends` = Monday 04:00 UTC.
- **Run a weekend event:** set `bonus_event` to `HighTide` and `bonus_event_ends` to Monday 04:00 UTC,
  then set `announcement` to `High Tide all weekend!`.
- **The game hits 1,000 likes:** set `codes_on` to `1KLIKES` and put the code in the `announcement`.
- **Something is broken:** pause it (`pause_*` or `events_off`), then tell Claude. Fix it, republish, unpause.

## Testing in Studio

Configs you've changed but not published yet are visible in Studio Play sessions only, not to live
players. Open them with **File → Open Configs**, Play, and check the console.
