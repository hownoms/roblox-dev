# Onboarding: progressive menu disclosure (v2.2, A7)

**Goal:** a new player should never see ten systems before earning their first coin. Each HUD
menu button appears at the moment it becomes useful. Once a button has appeared, it never
disappears again.

**Code:**
- `src/client/UI/MenuGate.luau` holds the rules. They are pure functions, which the tests call directly.
- `src/client/UI/HUD.luau` (the "Menu gating" section) applies them. It sets visibility, re-flows
  the grid, plays the pop-in, shows the "NEW!" tag and toasts, and handles Track events.

**Tests:** the "menu gating" section in `tests/client.spec.luau`.

## Unlock rules

A button is visible when **its rule holds now**, **or it was unlocked before** (persisted), **or
the player is returning**.

| Button | Appears when (any of) | Why |
|---|---|---|
| **Shop** | first sell (`FTUE_FirstSell`) · tutorial reached the "shop" step (4 steps done) · owns a 2nd shovel | You have coins and a reason to spend them |
| **Eggs** | tutorial reached the "egg" step (5 done) · owns 3 shovels (2 upgrades) · owns a pet | Pets come after the core dig/sell/upgrade loop |
| **Pets** | owns at least 1 pet | Nothing to manage before that |
| **Beach** (shade + snacks) | Heat attribute ≥ 50 (first "getting hot" moment) · PlayTime ≥ 4 min · owns a shade | The heat meter only matters after the 3-min heat grace |
| **Index** | first treasure found (`data.Index` not empty) | The FTUE guarantees a treasure on dig 8 |
| **Quests** | owns a 2nd shovel (first shovel bought) · `FTUE_FirstShovel` · any quest claimed | Goals once the loop is understood |
| **Rebirth** | Coins ≥ 60% of the next rebirth cost · Rebirths > 0 | A tease shortly before it is possible |
| **Store** (Robux) | PlayTime ≥ 8 min | Never monetise before the player is hooked |
| **Daily** (top-right) | PlayTime ≥ 1 min · has claimed a daily before | Not during the first minute |
| *Settings* | always | |

**Returning players** (`PlayTime > 20 min` or `Rebirths > 0`) see every button. If they never had a
`MenuSeen` setting, everything is marked seen, so they get no NEW tags.

All the thresholds are constants at the top of `MenuGate.luau` (`BEACH_HEAT`, `BEACH_PLAYTIME`,
`STORE_PLAYTIME`, `DAILY_PLAYTIME`, `REBIRTH_FRACTION`, `RETURNING_PLAYTIME`, `TUTORIAL_SHOP`,
`TUTORIAL_EGGS`). PlayTime is the server's total play time, which `RewardsService` adds to once a
minute.

## Persistence
- **`Settings.MenuUnlocked`:** a comma list in canonical order, written with `SetSetting`. It is
  at most 53 characters, and the limit is 64. It makes transient triggers stick: heat cools down,
  coins get spent, a rebirth resets shovels, and the button stays anyway.
- **`Settings.MenuSeen`:** a comma list of buttons whose panel has been opened. The "NEW!" tag
  shows while a button is unlocked but not yet seen. Opening the panel by any route (HUD button,
  world prompt, tutorial) marks it seen.
- **Key budget:** `SettingsService` no longer counts the server's `FTUE_` / `Server_` keys toward
  the 40-key client budget. Without that change, the 18 funnel flags could have blocked new client
  keys.

## What the player sees on an unlock
1. The button pops in (`Style.PopIn`) and a sound plays.
2. A gold pulsing **NEW!** tag appears on its top-left corner.
3. A toast appears under the objective banner, e.g. "Shop unlocked! Buy a better shovel". When
   several buttons unlock at once, one combined toast appears instead.
4. `Track("menu_unlocked", name)` is logged as the custom event `MenuUnlocked`.

Unlocks that the first evaluation after joining finds were earned in an earlier session appear
quietly, without the pop or the toast. They still get the NEW tag if their panel was never
opened.

## Layout
- The menu no longer uses a `UIGridLayout`. HUD places the **visible** buttons at
  `MenuGate.CellPosition(k)`: 2 columns, in MENU order, with no gaps. Buttons that were already
  visible slide to their new cell. The `Menu` region in `UI/Layout.luau` is unchanged.
- Tests check that every count from 1 to 8 fits inside the Menu region without overlaps at all 12
  layout sizes.
- The Daily button simply hides. Settings keeps its slot at the right end of the round-button pair.

## Guide arrows never point at a hidden button
- `HUD.Flash(name)` (used by the tutorial and by "Too hard!") re-evaluates the rules first and does
  nothing if the button is still locked. The tutorial's "shop" and "egg" steps unlock Shop and Eggs
  themselves, so their flashes always land on a visible button.
- On gamepad, ButtonY focuses `HUD.FirstMenuButton()` (the first *visible* button) instead of Shop.
- The world guide beams point at world objects (stands and eggs), which are always present.

## Replaying it
Use `/wipe` and rejoin (Studio). The menu starts empty and fills in as you play.
