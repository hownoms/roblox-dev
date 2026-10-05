# Game Design Document — Dig to the Core! Beach Simulator

> **v2 update:** plots were replaced by one shared beach, and heat/shade/snacks and digger companions were added. See `docs/V2.md`, `docs/design/Survival.md` and `docs/design/Diggers.md`; where they differ, those docs win.


Owner: Game design. The binding technical contract is `docs/ARCHITECTURE.md`; all numbers here
live in `src/shared/Config/*` (Config is the source of truth if the two ever disagree).

---

## 1. Title, pitch, audience

**Title:** **Dig to the Core! Beach Simulator** (32 chars). In-game logo / short name: **Dig to the Core**.
- Keeps the search keywords **Dig**, **Beach**, **Simulator**; "to the Core" is the hook and a
  built-in goal kids can repeat to friends ("I reached the Core!").
- Alternates if the name is taken / for A/B: "Beach Dig Simulator: Dig to the Core", "Dig the Beach Simulator".
- Description first line: *"Dig a giant hole at the beach! Find pirate treasure, dinosaur bones,
  crystals... and the CORE! Code: SANDY"*

**Elevator pitch:** You get your own patch of beach and a plastic shovel. Tap to dig, fill your
bucket, sell the sand, buy a better shovel, dig deeper. Every few metres the hole changes: shell
beds, a pirate cove, a buried shipwreck, dinosaur fossils, glowing crystal caves, an underground ice
age, the lost city of Sandlantis, lava, an alien hive — and at 1,000 m, the golden Core. Collect
treasures and pets on the way, rebirth to go faster, and race the server to the bottom.

**What's at the bottom of the hole?** The *Core* — the golden heart of the planet where the very
first beach ball was made (the Mythic "Beach Ball of Creation" treasure). Every layer drops a
lore crumb: a message in a bottle signed "A.D." ("Dig deeper. The Core is real."), pirate maps
with an X that points *down*, a buried city whose people "dug down and never came back", aliens
who crashed here looking for the Core too. Post-launch updates go *past* the Core.

**Audience:** Roblox players 9–15, mobile first (~70% phone/tablet), short sessions (10–25 min),
play with friends. Secondary: idle/simulator fans 13–17 who grind leaderboards.
Readability rules: big chunky buttons (≥ 48 px), numbers with K/M/B/T suffixes, 1–6 word
labels, icons over text, no reading required to understand the loop.

**Art direction:** bright low-poly cartoon. Saturated sand/ocean/coral palette (Config.Theme),
thick dark text strokes, FredokaOne titles. Every layer has a signature terrain colour and
ambient tint (`LayerDef.AmbientColor`) so a screenshot instantly shows "how deep" you are.

---

## 2. Core loop & timing targets

```
DIG (tap/hold) -> sand fills BACKPACK -> SELL at stand (or Sell Anywhere) -> COINS
   -> buy SHOVEL (power = new layer, speed, radius, x sand) / BACKPACK (capacity) / EGGS (pets)
   -> DIG DEEPER (new layer: more sand per dig + new treasures)  -> ... -> REBIRTH (x mult, tokens)
```

| Moment | Target | How it is hit |
|---|---|---|
| First dig | < 15 s | Spawn on own plot side, arrow + "Tap the sand!" |
| First sell | < 60 s | Bucket = 20 sand, toy shovel 1 sand/dig, 0.5 s cooldown -> 10 s of digging, ~15 s walk |
| First upgrade | < 2 min | Garden Trowel 30 coins (2nd sell), Sand Pail 50 coins |
| First egg | < 5 min | Beach Egg 100 coins (~3–4 min); tutorial step points at it |
| First new layer | ~1 min | Wet Sand at 20 m (toy shovel can dig it) |
| First rebirth | 45–60 min | Rebirth 1 costs 4M; simulated ~56 min of real play |
| Reach the Core | ~10–15 h | Core Breaker needs 10 rebirths |

Session rhythm: a sell trip every 30–60 s, a purchase every 2–5 min early / 5–10 min mid,
a new layer every ~5 min for the first 45 min. Something "pops" (treasure, rare reveal, layer
banner) at least every 20 s early on.

**Digging rules (server):** click/tap on terrain in your own plot within `REACH` (20 studs) ->
`FillBall(radius)`; requires `shovel.Power >= layer.Hardness` (else "Too hard! Get a better
shovel" + bonk sound + shop arrow). Sand per dig =
`layer.SandValue x shovel.SandMultiplier x RebirthMultiplier x PetMultiplier x passes/boosts/events`.
Each successful dig rolls `layer.TreasureChance x Luck` (cap 50%) on the layer loot table.
Getting out: the always-visible "Surface" button (ReturnToSurface).

---

## 3. Layers (Config.Layers) — 1,000 m to the Core

1 stud = 1 m in the UI. Each layer has a unique terrain material (colour overrides are global
per material). Shovel N+1 has exactly the Power of layer N+2's Hardness: **depth == progress**.

| # | Layer | Depth (m) | Material | Hardness | Sand/dig | Flavor |
|---|---|---|---|---|---|---|
| 1 | Dry Sand | 0–20 | Sand | 1 | 1 | Stuff tourists dropped |
| 2 | Wet Sand | 20–45 | Sandstone | 2 | 2 | Message in a bottle: "The Core is real" |
| 3 | Shell Bed | 45–75 | Salt (pink) | 4 | 4 | A million years of shells, glowing pearls |
| 4 | Tidal Clay | 75–110 | Mud | 8 | 8 | Swallowed fishing boats |
| 5 | Pirate Cove | 110–150 | Ground | 15 | 15 | Captain Sandbeard's loot |
| 6 | Sunken Shipwreck | 150–200 | WoodPlanks | 25 | 30 | A ship that sank into sand |
| 7 | Fossil Bed | 200–260 | Limestone | 45 | 60 | Dinosaurs! |
| 8 | Bedrock | 260–330 | Rock | 80 | 120 | Geodes |
| 9 | Crystal Caverns | 330–410 | Glacier (purple) | 140 | 250 | Glowing caves |
| 10 | Frozen Abyss | 410–495 | Ice | 250 | 550 | Underground ice age, mammoths |
| 11 | Ancient Ruins | 495–585 | Brick | 450 | 1,200 | Lost city of Sandlantis |
| 12 | Magma Chamber | 585–680 | CrackedLava | 800 | 2,800 | Lava rivers, dragon eggs |
| 13 | Obsidian Depths | 680–780 | Basalt | 1,400 | 6,500 | Black glass, strange footprints |
| 14 | Alien Hive | 780–885 | Slate (green) | 2,500 | 16,000 | Crashed UFO hive |
| 15 | The Core | 885–1000 | Pavement (gold) | 4,500 | 40,000 | Heart of the planet |

Layer thickness grows 20 -> 115 m so later layers are longer journeys; sand value grows ~2–2.5x
per layer so each new layer is a felt jump ("my income doubled!"). 51 treasures, 3–4 per
layer (Common / Uncommon / Rare, plus an Epic/Legendary/Mythic jackpot in most layers).

---

## 4. Progression & economy

**Equipment ladders.** 14 shovels (Cooldown 0.5 -> 0.12 s, Radius 2 -> 6 studs, x1 -> x75 sand),
13 backpacks (20 -> 400M capacity). Prices grow ~4–5x per tier, income per tier ~2–3x, so each
item takes a bit longer than the last (anticipation) while new layers keep the reward visible.
Shovels 10–14 and backpacks 10–13 require rebirths, so rebirthing is the only road to the Core.

**Pets** (43, Common -> Mythic): additive bonus, `1 + Σ(m - 1)` over 3 equipped pets (+2 with
pass). Example: three 1.5x pets = 2.5x. Additive keeps the late game sane and makes every
extra pet slot feel valuable. Egg unlocks are gated on depth (Tide Pool @ Shell Bed, Pirate @
Pirate Cove, Fossil @ Fossil Bed, Crystal @ Crystal Caverns, Magma @ Magma Chamber, Cosmic @
Alien Hive). Rebirth Egg costs Rebirth Tokens. Golden Egg is Robux only (Epic+ guaranteed, but its
best pet ≈ a mid-game Crystal Legendary — strong early, outgrown later).

**Rebirth:** cost `4M x 3.3^n` (4M, 13M, 44M, 140M, 470M, 1.6B ...), +0.5x permanent multiplier
each (sand *and* backpack capacity), tokens `1 + floor(n/3)`. Resets coins, sand, shovels,
backpacks, unsold treasures. Keeps pets, index, rebirth stats, MaxDepth record, quests, boosts.
Your plot is refilled ("the tide washes it away") and you start at the surface — but with
x1.5 everything the first 20 minutes fly by, which feels great.

**Rewards that scale:** quests, daily rewards, codes and coin products use `ScaledCoins` =
"seconds of income" x `RewardScale` of the player's deepest layer (≈ coins/sec a typical player
makes there). A 5-minute coin pack is worth 5 minutes at every stage of the game.

**Collection bonus:** completing every treasure of a layer in the Index gives +2% sand (max +30%).

### Economy sanity check (first life, no passes)

Simulated with a "cheapest useful upgrade first" player, 14 s sell-trip overhead, +25% income
from treasures, pet hatches as unlocked, divided by 0.6 efficiency for real play (spreadsheet-style sim using
numbers from Config). Times are cumulative minutes since joining.

| Purchase | Price | Real time | Deepest layer after | Income after |
|---|---|---|---|---|
| Garden Trowel | 30 | 0.6 min | Shell Bed | ~1/s |
| Sand Pail | 50 | 1.4 | Shell Bed | ~2/s |
| Metal Spade | 150 | 2.4 | Tidal Clay | ~3/s |
| Beach Egg x1 | 100 | ~3–4 | — | +5–10% |
| Beach Bag | 300 | 4.0 | Tidal Clay | ~7/s |
| Lifeguard Shovel | 600 | 5.3 | Pirate Cove | ~10/s |
| Cooler | 1,500 | 8.4 | Pirate Cove | ~25/s |
| Pirate Shovel | 2,500 | 9.9 | Shipwreck | ~30/s |
| Treasure Sack | 7,000 | 13.0 | Shipwreck | ~80/s |
| Bone Claw | 9,000 | 14.5 | Fossil Bed | ~110/s |
| Tide Pool Eggs | 2,500 ea | ~16 | — | pets ~1.75x |
| Pirate Barrel | 30K | 20.5 | Fossil Bed | ~280/s |
| Steel Pickaxe | 35K | 22.0 | Bedrock | ~400/s |
| Mine Cart | 130K | 26.5 | Bedrock | ~900/s |
| Crystal Spade | 140K | 28.5 | Crystal Caverns | ~1.2K/s |
| Pirate Eggs | 40K ea | ~31 | — | pets ~2.2x |
| Frostbite Pick | 600K | 37.8 | Frozen Abyss | ~2K/s |
| Wheelbarrow | 600K | 43.2 | Frozen Abyss | ~4K/s |
| **Rebirth 1** | **4M** | **~56** | — | x1.5 |

Rebirth pacing (same model): R2 ~43 min later, R3–R5 ~35–40 min each, R6–R8 ~40–50 min, R9+
1–2 h each; Core Breaker (10 rebirths) ≈ 9–11 h of idealised play, realistically 12–20 h —
two to three weeks for a 45-min/day player. Beyond R11 the cost curve (x3.3) outruns income on
purpose: that is the wall each content update pushes back.

Tuning knobs, in order of preference: `Rebirths.BaseCost / CostGrowth`, shovel/backpack `Price`,
`Layer.SandValue`. Do not change `Hardness`/`Power` pairs without keeping the 1:1 ladder.

---

## 5. Retention systems

| System | Design | Config |
|---|---|---|
| Daily reward | 7-day streak, claim every 20 h, streak breaks after 48 h; Day 7 = exclusive **Sunny Seal** pet + 30-min 2x Coins. Repeats weekly. Premium x1.5 coins. | `DailyRewards.luau` |
| Daily quests | 7 dailies (dig 100/1000, sell 10, find 10 treasures, find a Rare+, hatch 5, play 20 min) with scaled coins + boosts | `Quests.luau` |
| Milestones | Reach Pirate Cove / Fossil Bed / Crystal Caverns / The Core, first rebirth | `Quests.luau` |
| Codes | RELEASE (exclusive Launch Party Crab), SANDY, DIGDEEP (group), 1KLIKES (enable at 1K likes) | `Codes.luau` |
| Index / collection | 51 treasures + 43 pets with silhouettes for undiscovered; per-layer completion = +2% sand | `Treasures.luau`, `INDEX_LAYER_BONUS` |
| Leaderboards | In-world boards: Most Coins, Deepest Dig (global, refresh 60 s); in-server leaderstats Depth & Rebirths | `LEADERBOARD_*` |
| Events | **High Tide** every 20 min for 3 min (2x Luck), **Golden Hour** every 45 min for 5 min (2x Coins). Deterministic from `os.time()` so all servers agree; countdown banner in HUD | `Events.luau` |
| Group / like rewards | Join group -> +10% sand forever (checked live), group-only code DIGDEEP; like-milestone codes. (Likes/favourites can't be detected, so use codes.) | `GROUP_ID`, `Codes.luau` |
| Friends | +5% sand per friend in server (max +20%) | `FRIEND_BONUS_*` |
| Server announcements | Legendary/Mythic finds and hatches toast to the whole server | `RarityDef.Announce` |

---

## 6. Social features
- One shared beach: you *see* other players' holes get deeper — healthy envy (v2, see docs/V2.md).
- Server-wide toasts for Legendary/Mythic ("Mia found a RAINBOW DIAMOND!").
- Friend bonus, pets follow players (show off), leaderboards in the plaza, VIP lounge visible
  from the boardwalk.
- Chat tags: [VIP], [PREMIUM], rebirth count prefix.
- Private servers (cheap, see checklist) for friend groups / YouTubers.

---

## 7. Monetization (fair: passes = comfort/speed, never the only way)

**Game passes** (suggested Robux):

| Key | Name | Price | Effect |
|---|---|---|---|
| VIP | VIP | 249 | +25% sand, +25% luck, chat tag, VIP lounge |
| DoubleSand | 2x Sand | 299 | x2 sand forever |
| SellAnywhere | Sell Anywhere | 149 | Sell button works anywhere |
| AutoDig | Auto Dig | 199 | Toggle auto-dig straight down |
| Lucky | Lucky Shovel | 149 | x2 luck (treasure + egg) |
| TripleHatch | Triple Hatch | 99 | Hatch 3 eggs at once |
| ExtraPets | +2 Pet Slots | 199 | Equip 5 pets instead of 3 |
| MegaBackpack | Mega Backpack | 129 | x2 backpack capacity |

**Developer products:** coin packs 25 / 99 / 299 / 799 R$ (5 min / 25 min / 2 h / 6 h of income,
scaled to deepest layer), 2x Sand 15 min (35), 2x Luck 15 min (35), Skip Rebirth (199),
Golden Egg (79) / 3 Golden Eggs (199).

**Premium:** +10% sand, x1.5 daily-reward coins, [PREMIUM] tag. Premium Payouts reward
engagement time, so the real Premium strategy is retention (dailies, events, long-tail rebirths).

Rules: every Robux item has a free equivalent path (boosts from quests/daily/codes, pets from
eggs, capacity from backpacks). Show the first purchase prompt only after the player has felt
the need (e.g. Sell Anywhere offer on the 5th sell trip from depth > 100 m; Mega Backpack offer
when a backpack fills in < 10 digs). Never interrupt the first 5 minutes with a prompt.
Expected revenue mix: 2x Sand + VIP + Sell Anywhere ≈ 60% of pass revenue; Golden Egg & coin packs
drive products.

---

## 8. Onboarding / FTUE (`Config.TUTORIAL_STEPS`)
1. **go_plot** — spawn beside your plot; glowing arrow/beam to your plot, "Follow the arrow to YOUR dig spot!"
2. **first_dig** — pulsing hand icon on the sand, "Tap the sand to DIG!"; first dig: big sand
   burst particles, +1 popup, crunch sound.
3. **fill_up** — bucket meter pulses; "Keep digging until your bucket is full!" (≈20 digs).
   A guaranteed Common treasure on the 8th dig of the first session (juice moment).
4. **sell** — "Bucket full!" arrow + beam to Sell stand; coin rain on sell.
5. **shop** — arrow to Shovel shop, Garden Trowel highlighted ("Dig deeper!").
6. **egg** — at 100 coins, arrow to Egg shop; hatch animation; auto-equip the pet.
Then the tutorial hides; contextual hints remain ("Too hard! Get a Metal Spade" with shop arrow,
"Backpack full — sell!", "New layer: Pirate Cove!" banner with flavor text).
Analytics funnel steps: joined, first dig, first sell, first shovel, first egg, first rebirth.

---

## 9. Success metrics (launch targets)

| Metric | Target | Good |
|---|---|---|
| FTUE: first sell rate | > 90% of new players | 95% |
| D1 retention | 15% | 20%+ |
| D7 retention | 4% | 7%+ |
| Avg session length | 12 min | 18 min+ |
| Payer conversion (D7) | 1.5% | 3%+ |
| ARPDAU | 0.5 R$ | 1.5 R$+ |
| Like ratio | 80% | 88%+ |
| Qualified play-through rate (ads) | > 40% |  |
Watch the funnel in Creator Hub Analytics: any step with > 15% drop-off is the next fix.

---

## 10. Post-launch roadmap (4 updates, every ~2 weeks)
1. **Update 1 — "Tide Pool Pets" (week 2):** pet fusing (5 same -> Golden version x1.5),
   pet index rewards, 2 new codes, bug/balance pass from analytics.
2. **Update 2 — "Below the Core" (week 4):** 3 new layers past the Core (Hollow Earth, Dino
   Kingdom, Crystal Moon), 2 shovels, 2 backpacks, Hollow Earth egg; raises the rebirth wall.
3. **Update 3 — "Summer Festival" (week 6):** limited-time event currency (Beach Tickets from
   digs), event pass/shop with exclusive pets and a cosmetic shovel trail; sandcastle contest
   plot decorations.
4. **Update 4 — "Trading & Clans" (week 8–10):** pet trading (with value safeguards), dig
   crews (shared depth leaderboard), weekly global "Deepest Crew" race, Super Rebirths.

---

## 11. Roblox launch checklist

**Experience settings (Creator Hub -> Configure):**
- Name: *Dig to the Core! Beach Simulator*; Genre: **Simulation**; subgenre Incremental Simulator.
- Description: first 2 lines = hook + current code; then features bullets; then update log.
- Server size: **max 16 players** (one shared dig beach, v2). Server fill: "Roblox optimised" (leave 1–2 slots for friends).
- Devices: Phone, Tablet, Computer, Console (gamepad: R2 = dig, X = surface). VR off.
- **Maturity & Compliance Questionnaire:** answer honestly — no violence/blood, no romance, no
  gambling *for real money*. Note: random-item purchases with Robux (Golden Egg) must be
  disclosed truthfully in the questionnaire and show odds in the egg UI (we show odds for every
  egg). Expected label: **Minimal**.
- Private servers: **enabled, 50–100 R$/month** (cheap = more friend groups, YouTubers).
- Allow copying off; API services on (DataStores); third-party sales off; HTTP off.
- Social links: Roblox group (required for group bonus), Discord (13+ only; mention in game only
  per Roblox policy), YouTube/X.
- Create all passes/products, paste ids into `Config/Monetization.luau`, set `GROUP_ID`.

**Icon & thumbnails:**
- Icon 512x512: one character + giant shovel at the edge of a deep, glowing hole, big bold
  "DIG!" text, sky-blue/sand palette, readable at 64 px. Make 3 variants and A/B them
  (Creator Hub Thumbnail/Icon experiments) — keep the one with best CTR.
- Thumbnails 1920x1080 (up to 10): (1) cross-section of the hole showing all layers to the Core,
  (2) pets parade, (3) pirate chest reveal, (4) lava/crystal layers, (5) leaderboard/"16 players".
  Bright, few words, no fake UI or misleading content.
- 30 s video thumbnail of dig -> sell -> new layer reveal.

**Sponsored ads / Creator Hub tips:**
- Launch on a Friday afternoon US time (kids' weekend). Start sponsored ads at a small daily
  budget (e.g. 1–2K R$/day) for 3 days to collect CTR/retention data; scale only if D1 > 15% and
  playtime > 10 min. Turn on "Optimise for engagement".
- Watch Analytics: Engagement (session time, D1/D7), Monetization (ARPPU, conversion), Funnel
  (onboarding events). Iterate on icon first, then FTUE.
- Publish an update tag in the description and use the "Updates" social link; update weekly
  early on (the algorithm favours retention and active development).

**Testing before launch:**
- Studio: 1-player and 4-player local server test (Test -> Clients and Servers), plus an
  emulated phone (iPhone SE size) for every UI screen; confirm buttons ≥ 48 px, nothing under
  the jump button or top bar.
- Data: join, earn, leave, rejoin (save/load), kick during save, two servers same account
  (session lock), BindToClose on shutdown, Studio without API access (in-memory fallback).
- Exploits: spam Dig remote, dig outside own plot, dig beyond reach, buy with insufficient coins,
  negative/NaN args, redeem code twice, purchase receipt replay (idempotent).
- Economy: run a 1-hour playtest with a fresh account and record times vs. the table in §4.
- Performance: 16 players digging at 0.12 s cooldown on a mid-range phone (target 30+ FPS,
  server heartbeat 60).
- Soft-launch privately to a friend group, then public.
