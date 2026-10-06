# Rebirth, perks and offline earnings (v2.2)

Owner: Rebirth & Economy agent. The numbers live in `src/shared/Config/Rebirths.luau` and
`src/shared/Config/RebirthPerks.luau`. If this file and Config disagree, Config is right.

## Goals (from the owner's research)
- **A rebirth must feel like a step up, not a reset.** The panel shows how much faster the next
  run will be, and every rebirth pays tokens for a new permanent choice (a perk).
- **Being away should create anticipation.** Digging pets keep earning while you are offline,
  capped, and a welcome-back popup shows what they dug.
- **Chores get automated by progression, not only by Robux.** Sell Anywhere, a starting shovel
  and a kept backpack are earned with tokens. The Sell Anywhere pass stays as an early shortcut.

## Rebirth cost and tokens
| Rebirth | Cost (old) | Cost (v2.2) | Tokens (old) | Tokens (v2.2) | Multiplier after |
|---|---|---|---|---|---|
| 1 | 4M | **500K** | 1 | **2** | x1.5 |
| 2 | 13M | **2.8M** | 1 | **2** | x2.0 |
| 3 | 44M | **15M** | 1 | **3** | x2.5 |
| 4 | 140M | **85M** | 2 | **3** | x3.0 |
| 5 | 470M | 470M | 2 | **4** | x3.5 |
| 6+ | x3.3 each | x3.3 each (same) | 1 + n/3 | 2 + n/2 | +0.5 each |

`Cost(n) = 500K x g^n` for the first 4 rebirths, with `g ≈ 5.55` picked so that rebirth 5 lands
exactly on the old `4M x 3.3^n` curve. Everything after that is unchanged, so the Core Breaker
(10 rebirths) still needs about the same late-game grind.

### Simulation (`tools/sim/economy.luau`)
Run it with `python3 tests/tools/bundle.py && luau tools/sim/economy.luau` (add `-a verbose` for
every purchase). It loads the real Config through the test mock and plays a "cheapest useful
upgrade first" player with the GDD's assumptions: a 14 s sell trip, +25% from treasures, 3 hatches of
each new egg, and 0.6 efficiency. It is stricter than the GDD spreadsheet because it simulates every
dig and every trip, and the old config's first rebirth comes out at 73 min instead of 56. The
"GDD scale" column multiplies by 56/73 so the result can be compared with the GDD's targets.

| Scenario | R1 | R2 | R3 | R4 | R5 |
|---|---|---|---|---|---|
| Before: 4M x 3.3^n, no perks (GDD scale) | 56 | +37 | +44 | +36 | +41 |
| After, no perks bought (GDD scale) | **35** | +30 | +28 | +39 | +41 |
| After, typical perk plan (GDD scale) | **35** | +25 | +24 | +9 | +8 |
| Before, with the Sell Anywhere pass (reference) | 17 | +10 | +12 | +10 | +11 |

- The first new layer is unchanged: Wet Sand at about 0.2 min, Shell Bed (the first layer you need
  a purchase for) at about 1.6 min, and Pirate Cove at about 8.5 min. All of these are under the
  3-minute target where it applies.
- **Finding:** in this model Sell Anywhere is about a 3x speed-up in the mid game, because sell
  trips dominate once pets multiply sand per dig. That's why the perk costs 5 tokens and arrives
  around rebirth 3, and why the "with perks" line speeds up after it. Pass owners already
  played at that speed before v2.2. If rebirth 4+ feels too fast in playtests, raise the
  Sell Anywhere perk to 6–7 tokens first.

## Perks (`Config/RebirthPerks.luau`, `PlayerData.RebirthPerks = { [id] = level }`, never reset)
| Perk | Levels and token costs | Effect per level | Applied in |
|---|---|---|---|
| Sell Anywhere | 1 level: 5 | Sell from anywhere, the same as the pass | `EconomyService.CanSellAnywhere`, HUD `State.CanSellAnywhere` |
| Head Start | 1 / 2 / 3 / 5 / 8 | Start each run with Lifeguard / Pirate / Bone Claw / Steel Pickaxe / Crystal Spade plus 500 / 5K / 25K / 100K / 400K coins | `RebirthService` (on rebirth, plus shovel ownership on load and on purchase) |
| Golden Touch | 1 / 2 / 3 / 4 / 5 | +10% coins per level when selling, and on offline earnings | `Stats.GetCoinFactors` |
| Keep Backpack | 1 / 3 / 6 | Keep your backpack on rebirth, up to Treasure Sack / Wheelbarrow / any | `RebirthService` |
| Deep Pockets | 1 / 1 / 2 / 3 / 4 | +10% backpack capacity per level | `Stats.GetCapacity` |
| Lucky Digger | 1 / 2 / 2 / 3 / 4 | +10% treasure chance per level. Egg odds are not affected, so the shown odds stay true | `Stats.GetTreasureChance` |
| Long Nap | 1 / 2 / 3 / 4 | +1 h offline cap and +10% offline efficiency per level (up to 6 h at 80%) | `OfflineService` |
| Pet Den | 3 / 6 | +1 pet slot per level (maximum 2) | `Stats.GetPetSlots`, `State.GetPetSlots` |

- **First rebirth (2 tokens):** two level-1 perks, for example Head Start and Golden Touch, or a
  Rebirth Egg saved for at rebirth 2. Tokens are shared with the Rebirth Egg (3 tokens) on purpose,
  so each rebirth comes with a real choice.
- **Pet slots:** the maximum is now 3 base + 2 (ExtraPets) + 1 (AutoDig) + 2 (Pet Den) = 8.
- **Remote:** `BuyRebirthPerk(perkId)` is rate-limited. The server validates the id, the level cap
  and the tokens, then logs an Analytics sink with the SKU `Perk:<id>:<level>`.

## Rebirth panel (`UI/Panels/RebirthPanel.luau`)
The panel has two tabs.

**Rebirth tab:**
- Multiplier now ➜ after, plus the tokens you will gain.
- A progress bar toward the cost.
- A **recovery preview**: "With x1.5 you'll reach Crystal Caverns about 1.5× faster!" It shows the
  multiplier ratio, because income scales with it and capacity grows with it, so trips stay the
  same length. It names your deepest layer.
- A line saying what your perks start the next run with.
- Resets / You keep cards, Rebirth (tap twice to confirm), and Skip (Robux).

**Perks tab:**
- Your token count.
- One `UpgradeRow` per perk: the current level ➜ the next level, a token price button (green
  when affordable, grey when not, MAX when maxed), and an `LV n/max` tag.
- The HUD Rebirth button shows "!" when you can rebirth or can afford a perk level.
- Open with `Panel.Open("Rebirth", { Tab = "Perks" })`.

## Offline earnings (`Services/OfflineService.luau`, `UI/OfflinePopup.luau`)
- **Stamp:** `PlayerData.LastOnline` holds the server's `os.time()`. It is stamped every 15 s,
  on leave (before DataService's final save) and on BindToClose. The client never sends a time.
- **Formula on join:**
  `away = now - LastOnline`
  `seconds = min(away, cap)`, where `cap = (2 + Long Nap hours) h`
  `rate = Σ over equipped digging pets of layer.SandValue × (sandMult / shovelFactor) × Dig.SandMultiplier / Dig.Interval`
  `sand = rate × efficiency × seconds`, where `efficiency = 40% + Long Nap`
  `coins = floor(sand × SELL_RATE × Golden Touch)`
  - The rate is DigService's own pet-dig formula. For Golden pets, the dig interval is divided by
    GOLDEN_DIG_SPEED.
  - The layer is the deepest one the pet can dig that you have already reached.
  - `sandMult` is the permanent part of the multiplier stack (shovel, rebirth, pets, passes,
    Premium, group, Index). Boosts, events and friends are left out.
  - Coins go straight to the wallet, never to the backpack. There is no Robux doubler.
- **Guards:**
  - Ignored when `LastOnline` is 0.
  - Ignored when you were away less than 5 min.
  - Ignored when the gap is negative (clock skew), or longer than 365 days.
  - Ignored when `LastOnline` is older than `FirstJoin`.
  - The cap is applied in all other cases.
  - LastOnline is re-stamped on join, so rejoining at once pays nothing.
- **Popup:** coins are granted 3 s after load, once pass ownership has settled. The client then
  gets `OfflineEarnings({ Seconds, Away, Sand, Coins, CapSeconds, Capped, PetId })`, and the Reveal
  popup shows "WELCOME BACK!" with the best digging pet, the time away, the sand dug and the coins.
  Collecting sends coins flying into the counter. If the cap was hit, a LIMIT row points at
  Long Nap. Players with no digging pet get a hint toast instead.

| Example | Pets | Away | Coins |
|---|---|---|---|
| Fresh player, Toy Truck, reached Shipwreck | toy_truck (Pirate Cove sand) | 1 h | ~17K (rate 11.8 sand/s × 40% × 3600) |
| Same | same | 10 h | ~34K (capped at 2 h) |
| Long Nap 2 + Golden Touch 1 | same | 10 h | ~112K (4 h × 60% × 1.1) |

## Studio checks (headless tests cannot judge feel)
- Rebirth panel on a phone (about 800×360): both tabs fit, the recovery line is readable, and the
  perk rows scroll.
- Buy Head Start mid-run: the shovel tool swaps immediately. Rebirth with Keep Backpack: the
  worn backpack stays.
- Leave with a digging pet equipped, then rejoin more than 5 min later (or edit LastOnline in
  the DataStore): the popup appears about 3 s after spawn, and the coins counter jumps once.
- With the Sell Anywhere perk and no pass: the HUD Sell button reads "Sell", not "Sell R$", and it
  sells from inside the hole.
