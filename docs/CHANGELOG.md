# Changelog and Decision Log: Dig to the Core! Beach Simulator

This file records what we built, what we changed after playtesting, and **why**. Read it
before changing a system, because most "weird" choices have a reason written down here.
Branch: `claude/pensive-meitner-6jx4u4`.

Related docs: `README.md` (setup), `docs/GDD.md` (original design),
`docs/ARCHITECTURE.md` (code contract), `docs/V2.md` (v2 and v2.1 contract),
`docs/design/Survival.md` and `docs/design/Companions.md`, `docs/UI_STYLE.md`, `docs/MAP.md`,
`marketing/STORE_PAGE.md`.

---

## Unreleased: Spring Vault production candidate (merged, not published, flags off)
Branch `claude/spring-vault-production-candidate`, 10 October 2026, on default `d96ac75`.
**Merged into default on owner instruction** (`01eebba`, no PR: `gh` logged out).
- **Local-only storage, fail-closed:** `CandidateProfile` is resolved by Main before remotes,
  world or services. `StorageGate` is now the only module that touches `DataStoreService`. A
  LocalOnly candidate makes zero acquisitions or requests across saves, both outboxes, purchase
  history and leaderboards, including autosave, removal and shutdown. A candidate marker outside
  Studio, an unpublished place or Expansion1Review refuses to start anything.
  MonetizationService no longer acquires purchase history before checking for an in-memory
  store.
- **AdventureController** starts the runtime with `SpringVaultClient.Start(remotes, nil)` when
  the arena hasn't replicated, so licensed controls work anywhere. No scene is faked.
- **q_pip license (owner decision):** completing Pip's trial grants
  `ToolLicenses.tool_broadwave` once, validated from server trial state. The bible's
  cert_explorer route and the 150-coin q_pip reward are not implemented.
- **Rides:** the 40-stud horizontal ride check let a ride carry a player out of the pocket. It is
  now refused, and rides are despawned on entry.
- **Candidate provisioning:** a project file, an injector with a sha256 manifest, and an
  installer and uninstaller for the authorized Expansion1Review. The full journey was played on
  `470465f` from a fresh save, with earned eligibility. Record: `docs/integration/production-candidate.md`.

## Unreleased: Spring Vault player flow (merged, not published, flags off)
Branch `claude/adventure-player-flow`, 9–10 October 2026, on default `5897990`. It connects the
real journey on the production boot, from hatch to invitation, ability, completion card and
safe return:
- invitation and hatch guide;
- input and screen arbitration around the runtime;
- truthful per-player outcome cards;
- an isolated Expansion1Review harness for the production boot.

Three bugs found in Studio were fixed: the loan auto-equipped by a surface dig, the tutorial
pill over the panel, and the empty stage card.

**Merged into default on owner instruction on 10 October 2026**, without a PR because `gh` was
logged out. Default had moved on to Codex's PR #40 (`f0736bd`). The one conflict was the equip
control:
- Codex's PR #37 makes the runtime defer to our `Dig_Broadwave` GUI, while our arbitration hid
  ours whenever the runtime ran. Together they could leave no control on screen.
- Resolved: production owns equip and stow, and the runtime's button is a review-scene fallback
  only (`production-wiring.md` 4.4).

Not published, and every flag is still false. Evidence and blockers are in
`docs/integration/player-flow.md`.

## Unreleased: Spring Vault production integration (merged, not published, flags off)
**Merged to default (`1c0bd10`) on owner instruction, 9 October 2026. Not published. Every `AdventureFlags` flag is false. The packet is
`docs/integration/README.md`.**
- **Why:** the owner asked Claude to own production integration, rewards, persistence,
  settlement, trophy storage and camp UI. Codex keeps the gameplay runtime. Both PRs stay
  unmerged until they are reviewed together.
- **Wiring applied.** The consolidated `adventure-integration.patch` is now in the tree.
  Main boots TrophyService, AdventureSettlement and AdventureBoot. Remotes gain
  `PlaceCampItem`, `RemoveCampItem` and `AdventureOutcome`. With the flags off, nothing new runs.
- **Entry (`AdventureEntry`):**
  - a surface hatch at (-124, 1024, 76) with a server eligibility check;
  - a return pad in the pocket;
  - lifts to the beach after Leave, a fall, or the kill switch;
  - the runtime's `ReturnFrame` returns players to the same surface point;
  - a dark backdrop and 6 shadowless lights in the pocket;
  - every arena SpawnLocation is destroyed.
- **Licensed Broadwave:**
  - `ResolveTool` accepts only a server-issued, equipped, licensed tool, and the loan never digs
    ordinary sand.
  - New `BroadwaveEquip` control (button, Z, gamepad R1), because production hides the Backpack.
- **Settlement:**
  - a save whose lock is missing or stale no longer overwrites a newer save;
  - the outbox keeps intents written by a newer server version;
  - the broadcast completion text is neutral;
  - watchers get their real refusal reason;
  - retries happen within the session;
  - a final outbox write follows a failed leave save.
- **Camp:**
  - the display follows the real deck when it is rebuilt;
  - turning trophies off clears the pad and the queue;
  - a placement that can't be built never holds the pad;
  - prompts are rate-limited;
  - a player who has left is never reassigned the pad.
- **Evidence:** the full suite passes on the headless mock, and Codex's
  `audit-claude-candidate.py` passes. Not evidence of: live cross-server play, shutdown,
  Studio lighting, or devices.

## Unreleased: surface map art overhaul (merged, not published)
**Not published. Built by five parallel agents to `docs/MAP_ART_DIRECTION.md`, then reviewed in Studio Play via the Studio MCP (spawn, hub, boardwalk, coast, carnival, lighthouse, headlands, Golden Hour). Record: `docs/MAP_OVERHAUL_2026-10-08.md`.**
- **Why:** the owner said the map felt copy-pasted, empty, minimal and unexciting. Root cause #1: `Util.Prop` never passed a variant, so all 64 palms, 16 umbrellas, 4 towers and 6 stalls were the same model. Palms were 11 studs tall next to a 5-stud avatar, lamps never lit, and the terrain stopped at a hard edge.
- **Skyline (`Vistas`, `Headlands`, `Skyline`, `Terrain`, `Lighting`):** terrain headlands close both ends of the beach, with a west sea arch and sea stacks. A 67-stud lighthouse on the east point has a spinning beam, a night lantern and a keeper's cottage. The ocean now extends to the horizon, with five islands, a smoking volcano and hills behind the dunes. Gulls, two horizon sailboats and a banner plane fly overhead. Clouds and a new tropical lighting pass (Golden Hour retuned). Headlands are duplicated as Persistent part blobs, because terrain past the 320-stud streaming radius never reaches the client.
- **Boardwalk and pier (`Boardwalk`, `Promenade`, `PromenadeKit`, `PierCarnival`):** a varied plank deck with trim and railing. 27 vintage lamps in three styles at an irregular rhythm, glowing at night. String lights and bunting over the hub stretch, a "SUNNY SANDS BEACH" welcome arch, carts, signposts, benches, planters and showers. A wider pier with viewing bulges leads to a carnival deck (x -40..40, z -178..-230) with a 48-stud Ferris wheel in line with the spawn view, a carousel, a ticket booth and a strength tester. The title is now a marquee sign.
- **Hub (`Hub`, `HubKit`, `HubShops`, `HubAttractions`, `HubPlaza`):** every station is a distinct building:
  - Sand Exchange with a spinning coin (Sell)
  - Digger's Hardware (Shovels)
  - Surf & Pack Outfitters (Backpacks)
  - a tiki bar (Beach Shop)
  - a hatchery with a giant cracked egg (Eggs)
  - a crane construction yard (Crates)
  - a column temple with a portal ring (Rebirth)
  - a Hall of Fame (leaderboards)
  - a three-tier dolphin fountain
  - a tiled sun-mosaic plaza
  Tags, prompts, positions and pinned names are unchanged.
- **Beach (`Decor`, `Util`, `Props`, `PropsBeach`):** the variant fix. Palms are now 18-34 studs in three classes. Umbrellas come in 3 styles and 8 colourways, towers in 5 colours, and stalls in 4 kinds. 21 new prop builders. Instead of even rows the coast is a sequence of scenes: Tide Pool Point, Kite Field, Rowboat Landing, Picnic & Castles, two umbrella villages with a buoy swim zone, Surf School, Snorkel Cove and Bonfire Cove. Inland there are cabana rows, a volleyball court, a sandcastle contest, beach games, a sun deck, palm groves with hammocks and dune fences. A pulsing foam line runs along the water.
- **Motion (`AmbientController`, client):** one RenderStepped loop with BulkMoveTo animates CollectionService tags (Spin, FerrisWheel, Bob, Sway, Drift, Orbit, Pulse, NightLight). It culls by distance, respects Reduced Motion and low quality, and never moves collidable parts.
- **Budgets (smoke test):** 9,712 surface parts (was 4,819; cap 10,500), 34 lights (cap 40), 14 emitters (cap 24). A new check ensures no scenery stands over the dig strip.
- **Studio pass fixes:** cliffs, arch and sea stacks use grey Rock instead of cream Limestone, which looked blotchy. Sea stacks are now one tapered pillar each; before, they read as stacked snowballs. The far ocean beyond streaming range sits at the water line, removing a dark seam. Bunting was removed from across the spawn view (boardwalk twin lamps and hub gateway), where it blocked the default camera's view of the Ferris wheel.
- **Still open:** motion (wheel, boats, gulls) was not observed frame by frame; a mobile frame-time check is still needed before publishing.

## v17: second-minute fixes, published 8 October 2026
**Live as Roblox place version 17 (source `375625c`; 157/157 published scripts verified identical). Details: `docs/PLAYTEST_2026-10-08_PM.md`.**
- **Why:** a fresh no-pass playtest found four second-minute stalls: the detector pointed sideways at a find directly below, its arrows were hard to see, a full bag left the camera facing the sea (about 75 s to reach Sell), and the first bucket could sell for less than the 30-coin Garden Trowel the tutorial asked for.
- **Detector:** the server ping adds a coarse `Overhead` flag (horizontal offset at most max(3, |dy| x 0.5)). The client then says **DIG DOWN HERE!**, hides the compass dot and stands the world arrow up pointing down. The world arrow is larger, dark-outlined and at hip height, because the bottom action row covered it at the feet. The DOWN/UP pill is raised clear of the radar dot.
- **Selling (onboarding only):** when a tutorial selling moment starts and the stand is more than 60 degrees off view, the camera turns once (0.7 s, instant with Reduced Motion). Retest: full bag to sold in under 4 s of walking.
- **First upgrade:** while the next coin shovel is unaffordable, the shop step reads "Dig & sell more for the Garden Trowel! (22/30)", or "Bucket full! Sell it..." when the bag is full. It guides back to sand or Sell; numbered tutorial progress is unchanged.
- **Store page:** new icon and three illustrated thumbnails from `marketing/publish-kit-2026-10-08/` (Roblox moderation not confirmed).
- **Verified live before the change:** v15 scripts matched source, and a real save, leave and rejoin on a new server preserved coins, bag, shovel, finds and tutorial.
- **Tests:** `tutorial-short-coins` scenario, overhead and camera-yaw checks, and the ping field whitelist now allows the boolean `Overhead`.
- **Still open:** audio listening and uploads, live engine-mute check, real multi-account multiplayer and profiling, launch media from real gameplay, and access/Max Players (unchanged: Limited, 50).

## v1: first playable (initial build)
**Built by parallel agents (design, server, client/UI, map, models, marketing, QA).**
- **Toolchain:**
  - A Rojo project with all code in `--!strict` Luau.
  - `tools/check.sh` runs StyLua, the luau-lsp strict typecheck against the Roblox API, and the Rojo build.
  - Headless tests (`tests/run.sh`) run the real server and client code against a strict mock of the Roblox API.
- **Design:** 15 layers from Dry Sand to The Core, 14 shovels, 13 backpacks, pets and eggs, 51 treasures, rebirths, daily streak, quests, codes, Index, High Tide and Golden Hour events, 8 game passes and 9 dev products (ids are placeholders).
- **Server:**
  - Session-locked DataStore saves.
  - Server-authoritative digging, selling, shops, pets, rebirth, receipts, rewards, events, leaderboards and badges.
- **Client:** dig controls for mouse, touch and gamepad, HUD, every panel, hatch animation, tutorial.
- **Map:** built procedurally; 12 plots, hub, boardwalk, pier.
- **Models:** every model is built from parts (no mesh assets).
- **Marketing:** icon, 4 thumbnails, badges, store page.

## v1 playtest fixes (first Studio session)

| Problem seen in Studio | Cause | Fix |
|---|---|---|
| Clicking sand did nothing | Terrain uses 4-stud voxels, and a 2-stud `FillBall` barely changed them | Carve voxel-aligned cubes |
| Digs still ignored ("no solid terrain") | The visible smooth-terrain surface is about 2 studs **above** the voxel grid, so the click point sat in the empty voxel | The server re-raycasts from the player and steps into the surface along the normal |
| Sell pad did nothing | The thin pad was buried under the visible surface | Raise the pad, and the server checks players standing over it (no reliance on `Touched`) |
| Every popup appeared twice and eggs hatched twice | A duplicate `Client` folder was left in the saved place | Remove the duplicate; `shared` guards in both Main scripts now refuse to start a second copy |
| Backpack number hidden | Roblox's tool hotbar covered it | Hide the default Backpack CoreGui (the shovel auto-equips) |
| Plot looked unchanged after digging | The dig removed only the partial surface voxel | Dig one voxel deeper and clear the voxel above |

Also added: Studio-only dev chat commands (`/coins /max /dig /rebirths /wipe /surface`, later
`/tide /pet`).

> **Lesson recorded:** smooth terrain's visible surface sits about 2 studs above layout or voxel
> heights. Anything placed "on the ground" must raycast for the real surface. This bit us four
> times: digs, the sell pad, egg pedestals, and the fountain and towels.

## v2: owner redesign after playtest 2
**Owner decisions:**
- **Map:** no plots. The whole beach is diggable along a longer coastline, and all digging happens on the water side.
- **Tide refill:** holes refill after about 4 minutes idle. High Tide lifts players out of holes first, then smooths the beach.
- **Heat:** a soft slowdown: Sunburnt means slower digging, never damage. It comes with shade players can place, a water fountain and snacks.
- **Diggers:** digger companions, at first a separate Garage system.
- **Max players:** 16.
- **Smaller beginner digs.**

**Polish from feedback:**
- Glow was painful to look at, so lighting is softer and neon is clamped.
- The shovel looked like "a stick out of the arm", so it gets a diagonal grip.
- Tiny icons, so items are framed to fill their viewports.
- The "backpack full" message appeared twice, so duplicates were removed.

## v2 playtest fixes
- **Tiny text and icons:** the real cause was that **emoji inside `TextScaled` labels shrink the whole label** (emoji have tall line metrics). Labels containing emoji now get an explicit, fitted `TextSize`.
- **Egg labels and pedestals sunk into the sand:** raised to the visible surface. The fountain and props now raycast for the ground.
- **`rbxasset://sounds/swoosh.wav` "not approved":** replaced with other built-in sounds.
- **Starter dig:** a hand-spade dent (rounded `FillBall`) instead of a full voxel. A true 2×2×2 dig is impossible on 4-stud terrain.

## v2.1: companions merge, shovel feel, ride-on, UI restyle
**Owner decisions:**
- Diggers become **pets** from **Construction Crates**. Some creature pets dig too, and the Garage is removed.
- A **rideable Mythic excavator** drops from the top crate at 0.5%.
- Existing digger saves are converted to pets.
- The starter tool is a **Hand Spade**, full shovels are held **two-handed**, and the dig is an **upward scoop**.
- The UI restyle follows the owner's reference screenshots (chunky outlined toy style in a beach palette), and icons are picture icons from a generated atlas.

**What was built:**
- **Shovels:** Hand Spade and Garden Trowel are one-handed, and the rest are full-size.
  - `ShovelPoseController` poses both arms with client-side IK for every player.
  - The scoop animation tosses a sand clump, and the `Scoop` remote shows other players' scoops.
- **Companions:**
  - 12 vehicle pets and 7 digging creatures, plus 4 crates in a crate yard.
  - `PetDigService`: each pet digs its own spot on a 6–12 stud ring around the owner, never underneath them.
  - The `PetDug` remote, and a save migration from Diggers to pets (`DATA_VERSION` 2).
- **Ride:** `RideService` and `RideController`.
  - A constraint-driven vehicle with network ownership given to the rider.
  - Server-validated: anti-teleport with 3 strikes.
  - Digs ahead of itself (minimum 12-stud cube), and the ridden pet stops pet-digging.
- **UI:**
  - Components: `AtlasIcon` (atlas image with emoji fallback), toy buttons, navy panels with colour header bars.
  - Layout: currency counters top-right with round Daily and Settings buttons, a 2-column menu, and a `Layout` module tested at 12 screen sizes.
  - Panels and popups: upgrade-row shops, daily reward cards, the unified `Reveal` popup, and the objective banner.
- **Icons:** 64-icon atlas `assets/icons/atlas.png`. **The owner must upload it and paste the image id** into `src/shared/Config/IconAtlas.luau` (`ASSET_ID`).

## v2.2: research-driven (in progress)
Based on the owner's research on top Roblox simulators and tycoons. The plan:
- **Batch A, compliance and fundamentals:**
  - True modified odds whenever luck is active.
  - `PolicyService` gating of paid random items.
  - Remove the Cooler Pack, since it was paid relief from heat friction we created.
  - Show menu items only once they're relevant.
  - Server and weekly leaderboards.
  - A detailed analytics funnel.
- **Batch B, retention:**
  - Pets keep digging while you're offline, capped.
  - A rebirth token perk shop, with a recovery preview and a faster first rebirth.
  - Overhead titles and rebirth stars, a worn backpack, and rare-find announcements.
  - Hatch pity and duplicate fusion.
  - Free Sell Anywhere through a rebirth perk.

**As built, Status & Social (v2.2 B6 / A8 / social):**
- **Nameplates** are client-rendered (`Controllers/StatusController`) for every player from Player
  attributes set by `StatusService` (`TitleLayer`, `RebirthCount`, `BackpackFill`) plus `VIP` /
  `Premium`. Why client-side: no server GUI traffic, and each viewer can switch them off
  (Settings → "Nameplates", key `ShowNameplates`). Titles per deepest layer ever reached live in
  `Config/Titles.luau` (Sandcastle Rookie … Core Breaker). MaxDistance 60, not AlwaysOnTop.
- **Worn backpack:** `StatusService` welds `Models.Backpack(id)` to UpperTorso/Torso (massless,
  no collide/query/touch) on equip and every respawn; the client scales the `SandFill` part.
- **Rare-find banners:** Notify kind `Announce` is routed (`Toasts.SetRoute`) to
  `UI/Announcements`: one gold top banner at a time with a rarity pill, queued and capped.
- **Leaderboards** cycle ALL TIME / THIS WEEK / THIS SERVER every 10 s. Weekly stores are keyed by
  ISO week (`Leaderboard_Sand_W2026_41`, `Leaderboard_Depth_W2026_41`), written on the existing
  60 s cadence with backoff and a request-budget check. The coins board sign now reads "TOP DIGGERS".
- **Server dig goal** (`ServerGoalService`): everyone's dug sand fills one bar; when full,
  Golden Hour starts early on that server (`EventService.StartEarly`) and is announced.
  "Friends +X%" chip and the Invite button (Settings) make the friend bonus visible; invites give
  no reward because they can't be verified.

## v2.3: platform (streaming, load testing, monetization cleanup)
**Owner decisions** (from research on competing digging games and on Roblox policy):
- **Streaming on.** Every client system has to work when parts stream in late, stream out, and come back as new instances.
- **A `/stress` load test** so the owner can profile a 16-digger server with the MicroProfiler on a real Android phone.
- **No paid randomness or paid luck.** Robux never buys a random outcome or a probability modifier directly.
- **Prices raised** toward the competitor band (comparable passes sell for 175–750 R$).

**Streaming** (`docs/PERFORMANCE.md` has the details):
- **Workspace settings:**
  - `StreamingEnabled`, MinRadius 64 and TargetRadius 320.
  - `MinimumRadiusPause`, because of 1000-stud teleports out of holes.
  - `StreamOutBehavior = Opportunistic`.
- **New `Services/StreamingService`:**
  - Publishes every station's position to `ReplicatedStorage.WorldAnchors.<Tag>` (`Count`, `P1..Pn`). These attributes always replicate.
  - Makes every station's Model `Atomic`.
- **Rides and shades** are `PersistentPerPlayer` for their owner.
- **Client:**
  - New `Util/Tagged` (Watch / WatchPrompts / Nearest), which also cleans up on InstanceRemoved, and new `Util/Anchors`.
  - World prompts, Survival prompts and crate-yard prompts use `Tagged`.
  - Guide beams resolve a tag target every frame and fall back to the anchor. The beam from the bottom of a hole to the sell stand now works.
  - Nameplates re-attach to a streamed-in Head every 0.5 s.
- **Tests:**
  - `Mock.StreamOut` / `Mock.StreamIn` simulate streaming, and the mock now fires `InstanceRemoved`.
  - New client "streaming" section.

**/stress** (Studio only, `DevCommands`):
- Spawns N (default 15) `StressBot_i` dummies. Each has the top shovel and 3 top digging pets, and digs through the real `DigService.DigAt` at the shovel's cooldown.
- Prints digs/s, terrain edits/s, heartbeat avg/max, memory and send kbps every 10 s.
- `/stress stop` removes the bots and refills the holes.

**Monetization:**

| Item | Before | After |
|---|---|---|
| VIP | 249 R$; +25% sand, **+25% luck** | 349 R$; +25% sand, **+10% sell coins** (`CoinMultiplier`), 2 shades. The description no longer promises a chat tag or lounge that were never built |
| 2x Sand | 299 | 399 |
| Sell Anywhere | 149 | 249 |
| Auto Dig | 199 | 299 |
| Lucky Shovel (x2 luck) | 149 | **removed** (paid probability modifier) |
| Turbo Shovel (+25% dig speed) | – | **new**, 249 |
| Triple Hatch | 99 | 249 |
| +2 Pet Slots | 199 | 349 |
| Mega Backpack | 129 | 299 |
| Coins S/M/L/XL | 25/99/299/799 | 49/149/399/999 |
| 2x Sand (15 min) | 35 | 49 |
| 2x Luck (15 min) | 35 | **removed** |
| Golden Egg / 3 Golden Eggs | 79 / 199 R$ | **removed**; the Golden Egg now costs **10 Rebirth Tokens** (same pets and odds) |
| Skip Rebirth | 199 | 199 |

- **Config rules at require time:** no pass may have `LuckMultiplier`, no product may grant an egg or a Luck boost, and no egg may cost Robux.
- **Free luck stays:** Luck events, the Lucky Digger perk, and 2x Luck from quests, daily rewards and codes.
- **Prices in the store:** the store and the Skip button show the live Creator Hub price (`PurchaseController.GetPrice`, via `GetProductInfo`) and fall back to the config price.
- **Owner:** turn on Roblox Managed Pricing for developer products after launch.
- **Why Turbo Shovel:** it fills the Lucky pass slot with a deterministic perk.
- **Why VIP gets +10% sell coins:** it is a visible, non-random replacement for the luck. VIP already had the extra shade slot.

## v3-slice: Discovery (buried finds, detector, excavation)
**Owner direction (research on DIG / Dig it! / Mining Simulator 2):** discovery, not sand, made
DIG peak highest. Treasures stop being a dice roll on every dig and become the main event; sand
stays the steady background income. This is a **vertical slice to playtest** before the museum,
co-op and events are built on it. Full design, numbers and odds tables: `docs/design/Discovery.md`.

**What was built:**
- **Buried deposits.** `DiscoveryService` keeps hidden deposits as pure server data in a chunk
  hash over the dig zone (32 × 16 × 32 studs, seeded lazily, capped per chunk and per server,
  regrown and evicted over time). Each deposit holds a treasure from its layer's loot table, or
  a rare **Relic**. A dig whose carve comes within 3 studs of a deposit uncovers it. The digger
  owns the excavation; everyone else sees it. Only your own shovel and Auto Dig digs find things:
  pets, the ride-on, /stress bots and any `Silent` dig never do.
- **No more per-dig treasure roll** (DigService). It fires `ServerSignals.Carved` instead. A tiny
  ambient chance of a Common remains as popcorn, and the FTUE's guaranteed first treasure is now
  a guaranteed first *find* on dig 6.
- **Detector.** The free **Scan** button (bottom row; F / gamepad Y) pings for 6 s. The radar
  button shows distance band, direction, DOWN/UP and signal colour (white / gold / purple), with
  a beep that speeds up and an arrow at your feet. The server only ever sends coarse bands,
  never positions.
- **Excavation minigame.** Three timed taps on shrinking rings set the quality (Damaged / Good /
  Pristine = ×0.6 / ×1 / ×1.5). Misses never lose the item. The server grades the timings,
  caps impossibly fast answers at Good and times out to Damaged.
- **Variants:** size (Tiny / Normal / Large / Giant) and material (None / Golden / Fossilized /
  Crystal), rolled at uncover with the owner's luck. The true odds are shown in the Index.
  Value = base × size × material × quality.
- **Rarity you feel.** There are 5 presentation tiers (Pop / Beam / Card / Server / Spectacle).
  Mythic and Relic get a server-wide announcement plus a sky beam on a streaming-persistent
  model. New rarity **Relic** (Order 7) with two items: A.D.'s Sun Compass and Heart of the Tide.
- **Collection.** `PlayerData.Finds` holds unsold finds by variant and `PlayerData.FindVariants`
  holds the Index checkmarks. Index cards show variant pills, and the header shows the odds line.
  `DATA_VERSION` 3 migrates unsold `Treasures` into `Finds`.
- **Analytics:** funnel steps 19–21 (FirstFind, FirstRareFind, FirstPerfectExcavation) and
  custom event `Find`.

**Decisions and why:**
- **Variants are rolled at uncover, the treasure at seeding.** The detector has to hint the tier
  before you dig, and rolling the variant late lets the uncovering player's luck apply with
  true, displayable odds.
- **Quality is checked loosely.** It only scales value (at most +50% from cheating), so the
  server re-grades the reported timings and rate-limits rather than trying to verify taps.
- **Density was calibrated in the headless test**, not guessed: about one find per 33–45 s
  standing still with the starter spade. Deeper layers scale by 1 ÷ shovel sweep so big shovels
  don't chain finds.

## Playtest fixes (v2.2 Studio session)
Found playing v2.2; merged on top of v2.3/v3 and the visual polish pass. The visual polish
pass also raised the towel fabric to stop it flickering against the sand (a separate issue).

| Problem seen in Studio | Cause | Fix |
|---|---|---|
| Clicking the crate yard showed eggs first, which was confusing | Crates and eggs shared one list in the Eggs panel | The panel has **Eggs / Crates** tabs. The crate yard opens the Crates tab ("Construction Crates", crates only); the menu opens the Eggs tab |
| Hand spade scoop looked like digging *down* | At rest the arm was held out in front (default tool hold), so each scoop first dropped the arm | The spade arm now hangs at the side (IK-posed like the two-handed hold); the scoop swings forward into the sand and lifts up, without a raised wind-up |
| Fountain, beach towels and other props still sunk into the sand | Their ground raycast runs in the same frame the terrain is written and can miss it, falling back to grid height | `Util.TerrainY`: a miss falls back to grid + 2 (the visible surface), the same offset that fixed egg pedestals |
| Occasional red error "Parent property of UITextSizeConstraint is locked" | A label refit (deferred signal) ran after the label was destroyed and tried to re-parent its locked constraint | Refits stop once the label is destroyed, and the re-parent is guarded |

## Playtest fixes, round 2

| Problem seen in Studio | Cause | Fix |
|---|---|---|
| Spade still held out in front | The pose controller skipped **R6** avatars (blocky, one-piece arms), so they kept the default tool hold | R6 + hand tools: the arm swings about the shoulder using the same pose keys, and the RightGrip weld's C1 is re-aimed locally so the spade points forward/down from a lowered arm (restored on release). R6 + full shovels keep the plain grip |
| Spawn pads ("towels") in the sand | The boardwalk deck and pier were built at grid + 1, under the visible sand (grid + 2) | `Layout.DECK_TOP` = grid + 3; the promenade and pier are built from it; `Ride.DeckTop` follows |
| Rebirth shrine partly in the ground | Hub stations were built at grid height | Rebirth shrine, shops, sell stand, beach shop and leaderboards stand on `Util.TerrainY` (the visible sand); the sell pad offset drops back from 2.2 to 0.2 |
| (regression) Boardwalk stalls floating | Round 1's prop lift also applied to props standing on the deck | `Util.Prop(..., onPart = true)` for deck/pier props |
| Spade still in the default hold on the owner's **R15** avatar | Studio's new diagnostics said every joint was missing: Roblox's **Avatar Joint Upgrade** (`StarterPlayer.AvatarJointUpgrade`) builds characters with `AnimationConstraint` joints, not `Motor6D`s | The pose controller wraps both joint types as one `Joint` (constraint C0/C1 = Attachment0/1.CFrame, same Transform rule), finds joints by name or by the two parts they connect, re-resolves when any joint is replaced, and prints `[ShovelPose] <name>: posing ...` or what is missing in Studio |

**Confirmed in Studio by the owner (after #5):** the hand spade rests at the side and the full
shovel is held two-handed on an Avatar Joint Upgrade R15 avatar (`[ShovelPose] ...: posing
one-handed (R15)`); the deck, spawn pads, rebirth shrine and other hub stations sit on the sand;
the sell pad still sells; Eggs / Crates tabs work.
**Not yet playtested:** offline pet earnings, rebirth perks, the Legendary banner, Scan and the
excavation minigame, Reduced Motion, the server dig goal with several players, streaming at the
far ends of the beach, the R6 spade pose.

## Store & badges go live (2026-10-08)
First publish to Roblox, plus the second badge wave and art for every store item.

- **Published** as a private experience: **Dig to the Core! Beach Simulator**, experience id
  `10769863381` (owner account xxLoyalAcExx). Gen AI data sharing is off. Max Players is not set
  yet (README §2 asks for 16).
- **Badges, wave 2 (code + art):** Mythic Luck (any Mythic or Relic in the Index), Collector (every
  non-Relic treasure of one layer), Lost Civilization (Ancient Ruins, 495 m), Beach Regular
  (7-day daily streak), Core Breaker (10 rebirths). New `BadgeKind`s `FindRarity`,
  `CompleteLayer` and `DailyStreak`; `BadgeAwardService` now also re-checks on `Index` and
  `DailyStreak` changes. "Completed layer" excludes Relics, matching the Index panel's count.
- **Store icons:** `marketing/store/` has a 512x512 icon for each of the 8 passes and
  6 dev products. They come from `tools/marketing/generate.py store` and use the new emblems in
  `art.py` (sand pile, bolt, backpack, book, column, calendar, hourglass, gear, fast-forward).
- **Live ids in config:** badges 1–5 (`Config/Badges.luau`), all 8 passes and all 6 dev products
  (`Config/Monetization.luau`). Passes and products are on sale at the README §2 prices,
  Managed Pricing off.
- **Playtest access (done):** RazorWolf4 is a collaborator with **Playtest** permission only
  (Studio → Manage Collaborators; it defaults to Edit, so change it). The owner completed the
  maturity questionnaire, and the audience is **Limited → Playtesters** with Friends unticked (it
  defaults on and would admit all of the owner's friends). Limited would not save until the
  maturity label existed. Game link: https://www.roblox.com/games/135511260983800 (start place
  `135511260983800`). Saves from this test share the experience's DataStore with the future
  public game; see `docs/LIMITED_PLAYTEST.md` before launch.
- **Republished from the merged branch** (PR #21, merge `1f56b30`), so the live place includes the
  Codex PRs #15–#20 as well as this work.
- **Still to do:** badges 6–15 (Creator Hub allows 5 free badge creations per experience per GMT
  day, then 100 R$ each), dev product icons in Creator Hub, Max Players = 16, and going public
  after playtests.

| Problem | Cause | Fix |
|---|---|---|
| Badge name became `01_welcome.png` | Creator Hub's badge form fills Name with the image file name a moment after the upload, overwriting typed text | Type the name and description again after the upload, and check before clicking Create |
| "Place '0' currently has an active Team Create Session" on publish | Publishing over a place is blocked while any Studio window has it open in Team Create, and the session lingers a minute or two after the window closes | Close every Studio window on the published place, wait about 2 minutes, then Retry |
| Headless tests assume an unconfigured store ("no prompt for id 0") | Config now holds the live ids | `smoke.spec` and `client.spec` zero every pass, product and badge id before boot; tests that need ids still set their own test ids |
| (playtest) Pet egg labels sat on the sand, next to the wrong eggs | The `EggInfo` billboards were parented to the pedestal, a cylinder rotated 90° about Z; that rotation turned their "+Y" `StudsOffsetWorldSpace` sideways, so labels sat at pedestal-centre height beside the arc. (PR #23 only made them `AlwaysOnTop`, which drew the misplaced labels over everything.) | Each billboard is adorned to an `EggInfoAnchor` attachment placed straight above its pedestal; `AlwaysOnTop` is off again; alternate labels at +8 / +10.6 so neighbours don't overlap. Verified in Studio Play from the sign, the playtest viewpoint |
| Regenerating badges rewrote badges 01–10 | A newer Pillow re-encodes PNGs byte-differently | Only commit art that actually changed; restore the rest with `git checkout` |

---

## Standing rules (learned the hard way)
1. **Ground placement:** raycast for the visible terrain surface. Never place things at grid height. Use `Util.TerrainY` (or `Layout.VISIBLE_SURFACE_OFFSET`); decks use `Layout.DECK_TOP`.
2. **Untrusted clicks:** never trust a client position to be inside solid terrain; resolve it on the server.
3. **Emoji in text:** never put emoji in `TextScaled` labels; use `AtlasIcon` or `Style.Icon`.
4. **Sounds:** only built-ins we've verified load, plus owned audio.
5. **Paid randomness:** show true odds including every active modifier, and check `PolicyService`. Since v2.3, never sell a random outcome or luck for Robux directly; `Config` asserts it.
6. **Studio check:** every gameplay change needs a playtest. Headless tests catch logic errors, not feel or visuals.
   Studio prints `[ShovelPose]` status lines; when something silently doesn't happen in Studio, add a
   diagnostic like that before guessing again.
7. **Agent edits:** agents edit only the files they own, plus small additive edits to shared files.
8. **Finds come from deposits** (v3): don't add per-dig treasure rolls back. New find sources go
   through `DiscoveryService` so ownership, odds (`Finds.VariantOdds`) and the Index stay consistent.
9. **Streaming (v2.3):** never assume a Workspace part exists on the client. Use `Util/Tagged` for tags and `Util/Anchors` or Workspace attributes for far positions. Never call `WaitForChild` on Workspace content without a timeout. Test with `Mock.StreamOut` / `StreamIn`.
10. **Avatar joints:** characters may use `AnimationConstraint` joints (Avatar Joint Upgrade) instead of
   `Motor6D`s. Never assume `Motor6D`; go through the `Joint` adapter in `ShovelPoseController`.
