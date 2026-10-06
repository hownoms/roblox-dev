# Discovery: buried finds, detector, excavation (v3 vertical slice)

**Status:** vertical slice, built for playtesting. The museum, co-op and events come after the
owner has played it.
**Why:** DIG, Dig it! and Mining Simulator 2 all peaked and then collapsed. DIG peaked highest
because *discovery* was the star, not sand. Sand stays the steady background income. Finds
become the main event: **the thirty-second story** is *beep, beep-beep, dig, something's there,
tap-tap-tap, it rises out of the ground, GIANT GOLDEN!*

Code: `Config/Discovery.luau` (numbers), `Util/Finds.luau` (pure maths shared by server and
client), `Services/DiscoveryService.luau` (server), `Controllers/DiscoveryController.luau`, and
UI modules `UI/DetectorHUD.luau`, `UI/ExcavationGame.luau`, `UI/FindReveal.luau`,
`UI/Panels/IndexPanel.luau`.

## The loop

1. **Scan.** Tap the big **Scan** button (bottom row, left of Surface), or press T or gamepad L2 (F places shade, Y focuses the menu).
   For 6 s the detector beeps, faster as you get closer. The button turns into a radar: a dot
   orbits it pointing at the find, the outline glows in the signal colour, the caption reads
   HOT! / Warm / Cool / Faint, and a pill says DOWN or UP. A neon arrow also appears at your feet.
2. **Dig.** Any of your own digs (shovel or Auto Dig) whose carved box comes within **3 studs**
   of a buried deposit uncovers it. You own that excavation; other players see the find but
   can't take it.
3. **Excavate** (about 4 s). "DIG IT OUT!" Three rings shrink onto a circle; tap (or press
   Space / E / A / R2) when each ring meets the circle. Every hit nudges the find up out of the
   sand. Misses never lose the item, they only lower its quality.
4. **Reveal.** The find rises out of the ground with a dust burst. How big the moment feels
   depends on its tier (below). The find goes into your backpack (`Finds`) and the Index ticks
   off its variants. It sells with your sand.

Popcorn: when no deposit is uncovered, a dig has a tiny **ambient** chance (layer
`TreasureChance` × luck × **0.1**, about 0.4% per dig in Dry Sand) to drop a plain Common straight
into the backpack, with a float text and no minigame.

FTUE: a brand-new player's **6th dig** always uncovers a Common find right where they're digging,
so the first find lands within about 10 s of starting to dig.

**Companion digs never find anything.** Pets, the ride-on excavator, /stress bots, and any
`Silent` dig don't uncover deposits, roll ambient finds or pop up UI. Finds come only from
your own shovel and Auto Dig.

## Deposits (server data, no parts)

| Knob | Value | Notes |
|---|---|---|
| Chunk | 32 × 16 × 32 studs (X × depth × Z) | spatial hash key; seeded lazily the first time a dig, scan or test looks at it |
| Depth | ≥ 3 studs below the surface | the visible surface sits ~2 studs above the voxel grid |
| Spacing | ≥ 5 studs apart within a chunk | |
| Spot | random, in a column not already dug below it | uses BeachService's dug-cell grid |
| Cap | 16 per chunk, 4,000 per server | least recently touched chunks are evicted first |
| Respawn | 1 deposit per 90 s for a chunk below its target | |
| Evict | 300 s untouched with nobody within 24 studs | re-seeded fresh later; the tide has refilled it anyway |
| Contents | rolled at seeding from the layer's LootTable at base weights; 1/400 chance of a Relic | so the detector can hint at the tier |
| Variant | rolled when uncovered, with the **owner's luck** | luck counts: true odds are shown in the Index |

**Density** (deposits per chunk by layer; a fraction is the chance of one more):

| Layer | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| per chunk | 10 | 10 | 9 | 10 | 10 | 3 | 2.7 | 2.5 | 2.2 | 0.8 | 0.7 | 0.6 | 0.55 | 0.25 | 0.2 |

- **Layer 1 is calibrated by the smoke test.** Standing still with the Hand Spade (90 digs over
  45 s, in 8 fresh spots), the test measured 8–11 finds per 6 minutes across seeds, about one
  find per **33–45 s**. The detector exists to beat that by walking to the signal.
- **Deeper layers scale by 1 ÷ sweep** of the layer's typical shovel, where sweep =
  (edge + 5)² × edge ÷ cooldown and edge is the carved cube. Finds per *second* stay about the
  same, while finds per *stud* get rarer as shovels get huge.
- **One excavation at a time.** Even a 16-stud cube can't chain finds faster than one per
  minigame.

## Detector (server-authoritative, coarse only)

- **Range:** 24 studs, upgradeable later via `DETECTOR_RANGE`.
- **Timing:** a scan lasts 6 s and can start again 8 s after the previous start. During a scan
  the server sends `DetectorPing` every 0.5 s.
- **What a ping contains:**
  - `Band`: 1 = < 6 studs, 2 = < 12, 3 = < 18, 4 = < 24, 0 = nothing
  - `Sector`: 8 compass sectors
  - `Vertical`: Down / Level / Up (±4 studs)
  - `Signal`:
    - **White:** Common, Uncommon
    - **Gold:** Rare, Epic, Legendary
    - **Purple:** Mythic, Relic
  - `Remaining`
- **What never leaves the server:** positions, the item, and the deposit list. A test checks
  that a ping has exactly these 5 fields and no `Vector3`.
- **Cost:** each ping touches at most a few dozen chunks, checking ≤ 16 deposits each. Nothing
  runs when nobody is scanning.

## Excavation and quality

- **Rings:** 3 rings of 0.9 s each, 0.25 s apart, after a 0.45 s "ready" lead.
- **Grades:** Perfect if within ±0.09 s (2 points), Good if within ±0.22 s (1 point), otherwise
  Miss.

| Quality | Points | Value |
|---|---|---|
| Damaged | 0–1 | ×0.6 |
| Good | 2–4 | ×1 |
| Pristine | 5–6 (e.g. 2 Perfect + 1 Good) | ×1.5 |

**Anti-cheat (and why it's loose on purpose):**
- The client reports per-ring timing errors. The server grades them itself and only counts the
  first 3; junk counts as misses.
- An answer that arrives under 1.6 s after the start is capped at Good.
- Only the owner's current excavation id is accepted, and the remote is rate-limited
  (4 per second).
- With no answer, the server resolves the excavation after 9 s as Damaged. If the player
  leaves, it resolves at once. **The find is never lost.**
- Quality changes value only. The best a cheater gets is ×1.5 instead of ×1 on a find they
  would have got anyway: about +50%, which is not worth guarding harder.

## Variants (free gameplay, odds still shown in the Index)

| Size | Odds | Value | Model | Lucky? |
|---|---|---|---|---|
| Tiny | 20% | ×0.5 | ×0.6 | no |
| Normal | 62% | ×1 | ×1 | no |
| Large | 14% | ×2 | ×1.5 | yes |
| Giant | 4% | ×5 | ×2.4 | yes |

| Material | Odds | Value | Look | Lucky? |
|---|---|---|---|---|
| None | 88% | ×1 | as designed | no |
| Golden | 7% | ×3 | gold metal + sparkles | yes |
| Fossilized | 3.5% | ×5 | slate stone | yes |
| Crystal | 1.5% | ×10 | tinted glass + sparkles | yes |

- **Luck** (passes, boosts, events, the Lucky Digger perk via `Stats.GetLuck`) multiplies the
  weight of every "Lucky" variant. `Finds.VariantOdds(group, luck)` is the single function that
  both rolls and displays odds. The Index shows the result with *your* current luck, e.g.
  "Giant 6.8% (luck ×2)".
- **Expected multiplier:** size ×1.2 and material ×1.415, so about ×1.7 before quality.
- **Value of a find** = base × size × material × quality (rounded down, minimum 1). The base is
  `SellValue`; a Relic's base is `ScaledValue` seconds of income at the player's deepest layer.

## Rarity you feel (`Finds.Tier`)

| Tier | Who | World (everyone, `DiscoveryController`) | Owner (`FindReveal`) |
|---|---|---|---|
| Pop | Common / Uncommon | rise + dust | float text "Bottle Cap! +8"; compact card only the first time or for a new variant |
| Beam | Rare, **or any Giant / material variant** | + coloured light beam (18 studs) | + distinct sting, compact card |
| Card | Epic / Legendary | + beam | full Reveal card (rarity, size, material, quality, value) + camera moment (shake + FOV punch) |
| Server | Mythic | + 400-stud sky beam, model kept 12 s, `ModelStreamingMode.Persistent` so everyone sees it | + flash + confetti; server-wide gold announcement |
| Spectacle | **Relic** (new, above Mythic) | as Server | as Server, bigger camera moment |

**Relics** (rarity "Relic", Order 7) appear in no loot table. Any deposit has a 1/400 chance of
holding one, provided its `Layer` ≤ the deposit's layer:
- A.D.'s Sun Compass (Layer 1, worth 1,800 s of income)
- Heart of the Tide (Layer 3, worth 2,400 s of income)

In the Index they appear in their layer's tab but don't count towards layer completion.

## Data (DATA_VERSION 3)

- `PlayerData.Finds`: `"treasureId|Size|Material|Quality" -> count`. These are unsold finds:
  sold with sand, reset on rebirth (`Rebirths.Resets`).
- `PlayerData.FindVariants`: `"treasureId/VariantId" -> true`. This is the Index variant
  checkmarks; never reset.
- `PlayerData.Index` keeps recording the base item, as before.
- `PlayerData.Treasures` is legacy. The v2 to v3 migration turns each unsold treasure into a
  plain find (Normal, None, Good, worth exactly the old `SellValue`) and ticks Normal + None for
  everything already in the Index.

## Network

| Remote | Direction | Payload |
|---|---|---|
| `Scan` | C→S | () rate 3/s, cooldown 8 s |
| `Excavate` | C→S | (id ≤ 16 chars, errors {number}) rate 4/s |
| `DetectorPing` | S→owner | `Types.DetectorPing` |
| `ExcavationStart` | S→owner | `Types.ExcavationInfo` |
| `FindRevealed` | S→owner | `Types.FindInfo` |

**World models:**
- Tagged `DiscoveryFind`, with attributes FindId, TreasureId, Rarity, Size, Material, OwnerId,
  Stage (Excavating → Revealed), Rise, Tier and Quality.
- They exist only from uncover until 5 s after the reveal (12 s for Server and Spectacle).
- Clients watch the tag with `Util/Tagged` (handles present, stream-in and stream-out). A model
  that streams in already revealed is shown risen, without replaying the animation.
- The owner's reveal never depends on the model: `FindRevealed` carries everything.

## Analytics

- **Onboarding funnel steps** (appended): 19 FirstFind, 20 FirstRareFind (Rare+),
  21 FirstPerfectExcavation.
- **Custom event `Find`:** F01 = rarity, F02 = "Size/Material", F03 = quality.

## Economy note (tuning knob)

- **Before:** finds came from per-dig rolls, which the GDD sim counted as about +25% income.
- **Now:** finds are rarer (~1 per 40 s instead of ~1 per 12 s in Dry Sand) but each is worth
  ~×1.7 on average (×1.9 with quality). The find share of early income falls to roughly 13%,
  and sand carries the rest, as intended.
- **If first-rebirth pacing slips in playtests,** raise `DENSITY` (more finds) rather than
  `SellValue` (the Index value labels would drift).

## Not in the slice (next)

- Museum display and "keep" toggles: today every find sells at the stand.
- Co-op excavation and shared finds.
- Detector upgrades: range, scan length.
- Event-only variants.
- A per-variant best-quality record.
