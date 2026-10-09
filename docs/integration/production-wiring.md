# Adventure production wiring (for joint review)

Branch `claude/production-wiring`, 9 October 2026, based on default `a4167d9`. Nothing is pushed,
uploaded or published. Every feature flag ships **off**. With the flags off, production behaves
exactly as before. The only visible change is that Q (keyboard) still returns you to the surface
but now goes through a priority-ranked binding (see "Input arbitration").

## What is in this branch

| File | Owner | Role |
|---|---|---|
| `src/server/Services/AdventureFlags.luau` | Claude | Server-only flags, all `false` |
| `src/server/Services/AdventureEligibility.luau` | Claude | Pure rules plus `CanEnter`, `CanTrial`, `CanUseBroadwave` |
| `src/server/Services/BroadwaveLicense.luau` | Claude | Issues licensed (non-loan) Broadwave tools; default-off |
| `src/server/Services/AdventureBoot.luau` | Claude | Starts SpringVaultService under the flags; has the kill switch |
| `src/client/Controllers/InputArbiter.luau` | Claude | Named dig pauses; checks whether a Broadwave tool is equipped |
| `src/client/Controllers/AdventureController.luau` | Claude | Runs `SpringVaultClient` only when the server's remotes exist, and only while in the arena or with a Broadwave in hand (section 4) |
| `src/client/UI/AdventureHUD.luau` | Claude | Added in `claude/apf-arbitration`: hides or moves colliding production HUD pieces while in the arena (4.5) |
| `tests/production-wiring.spec.luau` | Claude | 4 scenarios: `off`, `on`, `rejoin`, `client` |
| `docs/integration/production-wiring.patch` | shared | Edits to shared files (below) |
| `docs/integration/codex-polish-review.md` | Claude | Review of Codex's gameplay-polish branch |

`production-wiring.patch` changes 5 shared files: about 40 added lines.

- `src/server/Main.server.luau`: requires `AdventureBoot` and adds it to `ordered` after
  `AdventureSettlement`.
- `src/client/Main.client.luau`: starts `AdventureController` last.
- `src/client/Controllers/DigController.luau`: respects `InputArbiter.DigBlocked()` and prefers
  the shovel tool when it auto-equips.
- `src/client/Controllers/InputController.luau`: Q/ButtonX "DigSurface" is bound at
  Medium+1 priority and passes Q to the Broadwave charge only while a Broadwave tool is equipped.
- `tests/run.sh`: registers `trophy-wired.spec` and the four `production-wiring` scenarios.

Apply order: `git apply docs/trophy-integration.patch`, then
`git apply docs/integration/production-wiring.patch`. Both applied cleanly in two places:

- default `a4167d9`;
- Codex's committed `codex/spring-vault-gameplay-polish` HEAD `d335eab`. It was still uncommitted
  when this work started, and that working copy was verified first.

## 1. Flags (server-owned, default off)

The flags live in `AdventureFlags`, in ServerScriptService. Clients can neither see nor change
them. `AdventureBoot.Start` reads them once at boot.

| Flag | On | Off |
|---|---|---|
| `SpringVault` | Starts `SpringVaultService` (arena, remotes, loans) with the callbacks below | Nothing is required or built. `ReplicatedStorage.SpringVaultAdventure` never exists, so the client adapter stays idle |
| `AdventureRewards` | `OnStage`/`OnCompletion` use `AdventureSettlement`'s durable bridge, and settlement is enabled | Only matters when `SpringVault` is on. Settlement is disabled and completion is refused: "Rewards are not enabled on this server" |
| `BroadwaveOrdinary` | `OnOrdinaryBroadwave = BroadwaveDigBridge.Create{...}`, licensed tools are issued, and `CanUseBroadwave` is enabled | The ordinary adapter is not passed at all, so the runtime keeps its event/trial-only Broadwave gating (see review M2) |

There are two kill switches:

- **Publish-time:** set the flag to false and publish. New servers boot without the feature.
- **In-server:** `AdventureBoot.Disable()`. It does the following:
  - destroys the runtime, which restores loans, return positions and walk speeds, and removes the
    arena and remotes;
  - disables settlement;
  - turns ordinary Broadwave off;
  - removes licensed tools.

  Accepted grants stay owned. Outbox drains continue, and saved licenses are never touched.
  Nothing calls `Disable()` yet. Wiring it to an admin command or a MessagingService broadcast is
  an open decision.

With `SpringVault` off, `AdventureSettlement` keeps its existing default (enabled), so the
existing `trophy-wired.spec` direct-API checks still pass. No production code calls it without the
runtime.

## 2. Eligibility (server-owned loaded-save evidence)

`nil` or a save that is not loaded is always `false`. Nothing here writes to the save.

**`CanEnter`**
- `Certifications.cert_rookie` is a table (written only by server reward code), or
- veteran catch-up: **both** of these, written by the server:
  - **Sale:** a `SellTimes` quest state with `Progress >= 1` or `Claimed`. `RewardsService` adds
    this on every `Sold`.
  - **Excavated deposit:** a `FindVariants` key whose variant is not `Normal` or `None`. Ambient
    finds record only `Normal`/`None`, so any other variant comes from an excavated deposit.
- Coins, MaxDepth, Rebirths, TotalSandDug, the client-writable `Settings.Tutorial` and owned
  shovels are never used.

**`CanTrial`** (q_pip's prerequisite): `OwnedShovels` contains a known shovel with `Price > 0`.
Purchases go through `ShopService.Buy`, and the rebirth Head Start perk also writes one. The
starter shovel never counts.

**`CanUseBroadwave(player, tool)`** requires all of the following:

- ordinary Broadwave was enabled by boot (the flag);
- `tool` was issued by `BroadwaveLicense` to this player on this server (weak registry);
- `tool` is equipped;
- `ToolId == "tool_broadwave"`;
- not `AdventureLoan`;
- the loaded save has a `ToolLicenses.tool_broadwave` table.

The key name comes from bible ch.04's DataVersion 4 list (`ToolLicenses{}`). Nothing in this
slice writes it. An adventure loan, a renamed tool, or a tool carrying the right attribute that
this server did not issue never passes. Each of these cases is tested.

**What the save cannot prove today.** There is no permanent first-sale record. Quest progress
can reset: a ClaimQuest on a new day recreates the state with `Progress = 0`. The save also does
not separate a scanner-located deposit from one uncovered by digging. So catch-up evidence can
miss real veterans (a false negative). It cannot admit someone without real sale and deposit
history. See open decision 1.

## 3. Licensed Broadwave equip

`BroadwaveLicense` (active only under `BroadwaveOrdinary`) builds a `Tool` named `Broadwave` from
`Kit.Broadwave()`, with:

- `ToolId = "tool_broadwave"` and `LicensedBroadwave = true`, set on the server;
- `CanBeDropped = false`.

It puts the tool in the Backpack:

- on load and on every respawn;
- removes it if the license record is missing or the feature stops.

It is not a shovel, so `Config.Shovels`, `OwnedShovels` and `ShopService` are untouched. The tool
has no `ShovelId`, so the shovel refresh ignores it. The future quest grant should write
`ToolLicenses.tool_broadwave` and then call `BroadwaveLicense.Sync(player)`.

Known gaps:

- **Licensed tool can't drive the runtime.** SpringVaultService's charge input only accepts its
  own loan (`tools[player]`, review H2). Until the runtime recognises the licensed tool, ordinary
  Broadwave can only be exercised by calling the bridge directly. The `on` scenario does this and
  scoops real sand through `DigService.DigBroadwave`.
- **No way to equip it.** The production client hides the Backpack CoreGui, so players cannot
  equip any extra tool: neither this one nor the loan (review H3).

## 4. Input arbitration

Revised on branch `claude/apf-arbitration` (9 October 2026, from default `5897990`, which contains
Codex's PR #35). Audited against the current `SpringVaultClient`: the smaller arrival panel,
contextual Start / Ready / route / haul controls, the Options panel, its own "Equip Broadwave"
button and the 48 px touch controls. No Codex file was edited. Codex's GUI is only read
(names and absolute rects), never changed.

### 4.1 When the runtime client runs

`AdventureController` (Claude) starts and stops `SpringVaultClient.Start(remotes, scene)`:

- **Flag off:** `ReplicatedStorage.SpringVaultAdventure` never exists. Nothing binds, builds or
  yields. There is one `ChildAdded` listener and that is all.
- **Flag on:** the client runs only while it is needed:
  - while the player stands in the arena (`ProtectedArenaFloor` box, rotation-aware);
  - or while a Broadwave (loan or licensed) is in hand, anywhere, so the Q / L1 / touch charge
    works on the sand.
- **Stopping:** it stops (`handle.Destroy()`) `STOP_GRACE` (2 s) after neither condition holds.
  It stops at once when the remotes folder leaves `ReplicatedStorage` (kill switch).
- **Rebuilt folder:** a later folder (new boot) is picked up again.
- **Scene rebuild:** the runtime rebinds the new scene itself. The controller reads the scene
  live on every tick.

The result:

- The adventure panel never appears on the beach for everyone. Before this, it was visible at the
  top centre from boot for every player as soon as the flag was on.
- A stowed loan outside the arena binds nothing.
- `InputArbiter.ChargeAvailable()` tells the truth.

### 4.2 Conflict table (every binding, both sides)

Adventure bindings come from the current `SpringVaultClient`:

- CAS `SpringVaultBroadwave`: `BindAction` at default priority, Q + ButtonL1 + a 64 px touch button
  at (vw-88, max(76, vh/2-66));
- prompts with `KeyboardKeyCode = E` (the runtime's own or the server's), only the nearest relevant
  one enabled;
- panel TextButtons: Join, Ignore, Leave, Start, Ready, Guide ball, Left / Right route, Options,
  Motion, Puffs, Reset ball;
- the "BroadwaveEquip" TextButton.

| Input | Production owner | Adventure use | Resolution |
|---|---|---|---|
| Q | `InputController` "DigSurface" (Q + ButtonX, `Medium + 1`) | Broadwave charge (default priority) | DigSurface sees Q first. It passes Q only when `InputArbiter.QToCharge()`: a Broadwave is in hand **and** the charge action is bound. Otherwise Q surfaces, including after the kill switch with a tool still in hand and when the runtime failed to start. ButtonX always surfaces |
| L1 | `PlacementController` "SurvivalPlaceRotate" (R + L1, High, only while placing) | Broadwave charge | Placement wins while placing. Otherwise the charge gets L1 |
| Z, ButtonR1 | `BroadwaveEquip` (bound only while a target tool exists) | none | Ours only. They stay bound even while the runtime's button is the visible control, because keys are not a second visible control. Never Q or L1 (tested) |
| E | ProximityPrompt default: `WorldPromptController`, `CampDisplayController`, the AdventureEntry hatch and return pad. `ExcavationGame` raw `InputBegan` (Space / E / A / R2) during the minigame | Adventure prompts in the scene (Talk, Leave, OpenVault, routes, PushBall, ResetBall, Excavate) | Spatially disjoint. Adventure prompts live in the pocket, and only one is enabled at a time. The hatch is on the surface, outside the dig strip. An excavation can only start from a dig, and digs are paused in the arena |
| LMB / touch / R2 dig | `DigController` (`InputBegan` with `processed == false`) | Panel buttons, equip button, CAS touch button and prompt touch UI (all GUI, so `processed = true`) | The arena and hauling reasons below, plus the live Broadwave-in-hand check. The dig cursor is hidden while any of them holds. The server refuses digs in the arena anyway (`OutOfZone`) |
| LMB / MB2 / R2 / touch while riding, V / DPadUp ride | `RideController` (saves and restores `DigController.Enabled`) | none | No key overlap. The Ride buttons hide in the arena when they overlap the panel (4.5). Riding inside the pocket is not prevented (open item) |
| F, 1 / 2 / 3, R / B / Backspace / Return / R2 while placing | `SurvivalController`, `PlacementController` | none | No overlap |
| T / ButtonL2 scan | `DiscoveryController` raw `InputBegan` | none | No overlap |
| G, P, ButtonY menu, ButtonB close (High) | `InputController`, `Panel` | none | No overlap. Panels (DisplayOrder 5) draw above the runtime GUI (DisplayOrder 0) |
| Gamepad GUI selection (ButtonY, DPad) | HUD menu | The runtime's TextButtons are selectable | Unchanged. Selection moves only when the player opens it |
| Touch thumbstick / jump zones | Roblox | Charge button (64 px), equip 176 x 48 bottom right, or inside the panel when it is up | Our Broadwave region avoids both (client.spec). Production HUD pieces that overlap them hide in the arena (4.5) |

### 4.3 Digging pause: named reasons and their release

| Condition | How | Released by |
|---|---|---|
| Standing in the arena: Mara / Pip dialogue and prompts, anchors, latch, routes. Mara and Pip stand at (±20, 15) inside the 100 x 140 floor with a 10-stud talk range | `InputArbiter.Suppress("AdventureArena", inArena())`, recomputed every 0.25 s and on every character change, snapshot, scene removal and remotes change | Leaving the box (Leave lift, return pad, fall lift, Q surface), respawn, scene removed, remotes removed |
| Hauling the ball | `Suppress("AdventureHauling", snapshot.hauling and inArena())`. The latched snapshot flag is dropped when not in the arena, on `CharacterRemoving`, on scene removal and on remotes removal | A detaching snapshot, any of the arena releases, respawn while hauling (tested), a late "hauling" snapshot on the beach (ignored, tested), scene rebuild (not carried over, tested), kill switch (tested) |
| Broadwave in hand (loan or licensed, charging or not) | Live `InputArbiter.BroadwaveEquipped()` in `DigController.TryDigAt` and the cursor. It is derived from the character, so it cannot get stuck | Putting it away (ours: re-equips the shovel), respawn, the tool removed |

- **Loan carried out of the arena:** ordinary digs are refused client-side. No dig request is
  sent, no TooFar or zone hint is shown, and the cursor is hidden (tested). The only feedback is
  "Broadwave in hand. Put it away to dig with your shovel." The runtime keeps running while the
  loan is in hand, so its button can put it away. Our control never offers a *stowed* loan
  outside the arena. The server already refuses loans for ordinary sand three times over.
- **Kill switch:** the folder's `AncestryChanged` detaches. It disconnects the snapshot, destroys
  the runtime client and releases every reason. `ChargeAvailable` becomes false, so Q surfaces
  again, and the HUD is restored (tested).

### 4.4 One visible equip control

**Rule.** Whenever the runtime client is running, its own "BroadwaveEquip" button is the equip /
stow control and ours hides. `BroadwaveEquip.RuntimeOwnsControl()` is true in two cases:

- `AdventureController` reports a running handle;
- a read-only lookup finds `PlayerGui.SpringVaultAdventureReview…BroadwaveEquip` effectively
  visible (itself, every ancestor, and the ScreenGui enabled).

When the runtime is not running, ours is the control, and it only offers:

- a licensed tool;
- a loan that is already in hand (to put it away).

| Situation | Visible control |
|---|---|
| Beach, no Broadwave, or only a stowed loan | none (a stowed loan has no use on the sand) |
| Beach, licensed tool stowed | ours ("Broadwave", Layout region) |
| Beach, licensed tool or loan in hand | the runtime's ("Stow Broadwave"). The runtime starts in the same frame as the equip, so the charge is bound |
| Arena, any Broadwave | the runtime's (ours hidden; Z / R1 still work) |
| Runtime failed to start, or kill switch | ours, if a target exists |

Tested: exactly one control in every row above.

**Known cost until Codex adds `ExternalEquip`:**

- With a licensed tool on the beach, the control moves from our region to the runtime's
  bottom-right button while the tool is in hand.
- The runtime's stow calls `UnequipTools`, which leaves the hand empty. `DigController` re-equips
  the shovel on the next dig.

**Request to Codex (the clean fix):** `Client.Start(remotes, scene, options)` with
`options.ExternalEquip = true`. It should skip creating the "BroadwaveEquip" TextButton, its
RenderStepped visibility and placement block, and its extra row inside the touch panel, while
keeping `equipped()` for the charge. `AdventureController` would pass `{ ExternalEquip = true }`.
`UI/BroadwaveEquip` is then the only control everywhere:

- it labels the loan and the licensed tool;
- it re-equips the shovel;
- it never offers a loan outside the arena.

At that point `RuntimeOwnsControl` can be deleted. The review place keeps the runtime's button.

### 4.5 Screen layout in the arena (`UI/AdventureHUD`)

Runtime elements, in real px with the same top-bar inset as production:

- **Panel:** top centre, `min(330, vw-24)` wide, 192 px tall on arrival and about 246 px once
  joined. On touch with the equip row inside it, about 300 px. It scrolls on short screens.
- **Aim hint:** `0.7 vw` x 48 at y 12, while charging, when the panel is hidden.
- **Equip:** 176 x 48 at the bottom right.
- **Charge button:** 64 px.

The table below overlaps these with `UI/Layout` regions at the shared `Root` scale. It was computed
by porting `Layout.Compute`.

| Viewport | Panel overlaps | Equip / charge overlap |
|---|---|---|
| 705x338 phone | TopRight, Banner, Timers, Toasts; joined: also Bottom, Ride | equip (panel hidden): Survival, Ride; charge: Depth, Survival |
| 844x390 phone | TopRight, Banner, Timers, Toasts; joined: also Bottom, Ride | equip: Survival, Social; charge: Depth, Survival |
| 932x430 phone | TopRight, Banner, Timers, Toasts; touch equip row: also Bottom | equip: Survival, Social; charge: Depth, Survival |
| 1024x768 tablet | TopRight, Banner, Timers, Toasts | charge: Survival |
| 1280x662 / 1366x705 desktop | TopRight, Banner, Timers, Toasts | equip: Social |
| 1920x1022 desktop | Depth, Banner, Timers, Toasts, Social | none |

Resolution: every 0.25 s, only while in the arena, using the live absolute rects. It is restored on
leaving, respawn and kill switch.

- **Depth meter:** always hidden. A depth reading inside the pocket under the sand is misleading.
- **Timers, TopRight, Social, Bottom (`Dig_HUD`) and the `SurvivalHUD` holder:** hidden only while
  they overlap a visible runtime element. Their owners never toggle these frames' `Visible`, so
  restoring is exact.
- **Ride buttons:** `RideButton` toggles its own `Visible`, so the whole `Dig_Ride` ScreenGui is
  disabled instead, and the owner's later changes survive (tested).
- **Toasts:** never hidden. `Toasts.SetClearance(top)` moves the column below the panel. Fewer
  stack at once if the column would reach the bottom bar.
- **Not touched:** the menu, panels and popups, and every Codex element.
- **Accepted:** the objective banner is tutorial-only, and the tutorial is complete before
  `CanEnter`. The aim hint briefly crosses the menu while charging; it is a non-interactive label.
- **Cost:** on most screens TopRight (coins, Daily, Settings) hides in the arena because the
  panel's right edge reaches it. Leaving the arena brings it back.

### 4.6 Reduced motion and particles

**Production side.** `Settings.ReducedMotion` (SettingsPanel) is read everywhere through
`State.GetSetting`, and `LowGraphics` serves as the particle / effects preference (UIEffects).

**Runtime side.** `SpringVaultClient` has no API for these. `Start(remotes, scene)` takes no
options, the handle exposes only `Destroy`, and `reducedMotion` / `reducedParticles` are local
upvalues flipped by its own Options buttons. Driving those buttons would mean mutating Codex's
GUI, so nothing is wired.

**Request to Codex:**

- `options.ReducedMotion` / `options.ReducedParticles` (initial values);
- `handle.SetPreferences({ ReducedMotion = bool, ReducedParticles = bool })` for live changes.

Production would pass `ReducedMotion = Settings.ReducedMotion` and
`ReducedParticles = Settings.LowGraphics or Settings.ReducedMotion`, and re-send on `State`
changes. The Options buttons can stay as per-session overrides.

### 4.7 Requests to Codex (`SpringVaultClient`)

1. **`options.ExternalEquip`** (4.4). This resolves open gate 2.
2. **Preferences** (4.6): `options.ReducedMotion` / `ReducedParticles` and
   `handle.SetPreferences`.
3. **Panel outside the arena.** The panel is `Visible` from `Start` for everyone. With our
   lifetime rule it only shows in the arena, *except* while a licensed Broadwave is in hand on the
   beach, where Join / Ignore appear at the top centre. Please start it hidden unless the player
   is in the arena, has talked to Mara / Pip, or has joined (or accept `options.PanelInArenaOnly`).
4. **Name the panel** (e.g. `"Panel"`). `AdventureHUD` currently finds it read-only as the
   ScreenGui's `ScrollingFrame` child.
5. **Optional `handle.State()`** (`charging`, `hauling`, `panelVisible`). Arbitration could then
   read the runtime directly instead of inferring from snapshots and the character.

### 4.8 Evidence

`production-wiring.spec -a client`: 116 checks (was 59). They cover:

- flag off: nothing binds;
- no panel on the beach;
- arena and hauling reasons on and off, through Leave, a lift while hauling, respawn while
  hauling, a late snapshot, scene rebuild, kill switch and a rebuilt folder;
- Q: surfaces without a Broadwave and with a Broadwave but no charge; passes only when both hold;
- the one-control rule in every situation above;
- a loan outside the arena: no dig request;
- the HUD hide / restore and Ride whole-gui rules; the toast clearance.

Mutations caught:

| Mutation | Checks failed |
|---|---|
| No hauling reset outside the arena | 2 |
| The old Q rule | 2 |
| No one-control rule | 6 |
| Stowed loan offered on the beach | 4 |
| No kill-switch detach | 4 |
| Runtime always on | 13 |

Gating hauling on the arena overlaps with the reset (redundant guard, by design).

Not verified: real devices, safe-area insets, Studio play of the panel against the real HUD, and
the absolute-rect equivalence between the runtime's ScreenGui and production's.

## 5. Boot wiring and the arena pocket

`AdventureBoot.Start` (Start phase, after every Init) calls:

```lua
SpringVaultService.Start({
	Origin = AdventureBoot.POCKET_ORIGIN,            -- (-200, 970, 106)
	CanEnter = AdventureEligibility.CanEnter,
	CanTrial = AdventureEligibility.CanTrial,
	OnStage = AdventureSettlement.OnStage,           -- AdventureRewards on
	OnCompletion = AdventureSettlement.OnCompletion, -- AdventureRewards on (else a truthful refusal)
	OnOrdinaryBroadwave = BroadwaveDigBridge.Create({ -- BroadwaveOrdinary on only
		CanUse = AdventureEligibility.CanUseBroadwave,
		Dig = DigService.DigBroadwave,
	}),
})
```

It requires the adventure modules lazily, so with the flags off nothing extra loads. Codex's
`BroadwaveDigBridge` and `DigBroadwave` are looked up at runtime: when they are absent it warns
and runs without ordinary Broadwave.

**Pocket.** The INTEGRATION.md suggestion of "8-12 studs below the beach" does not fit the
geometry:

- The arena is 100 x 140 studs and about 13 tall.
- The land slab is only 16 studs thick.
- The inland band between the dig strip (terrain at Z <= 0) and the north boundary wall (Z 130,
  spanning Y 994..1114) is only 130 studs deep.

The arena therefore sits in the empty void under the slab: X -250..-150, Y 968..981, Z 0..140,
about 54 studs below the surface. It needs no terrain writes. `PocketIsSafe` refuses any origin
whose box touches the dig zone or a protected footprint. The spec confirms there are no map parts
and no terrain voxels inside the box after a real `World.Build`.

**Spawn guard.** `AdventureBoot` disables every `SpawnLocation` under the scene, including
scenes rebuilt after each run (review H1).

## Verification

All runs used the headless mock with the in-memory DataStore, on Windows with luau 0.640.

**Stack A:** default `a4167d9` + trophy patch + Codex `d335eab` + this branch + this patch.

| Spec | Result |
|---|---|
| util | 8 |
| smoke (live) | 2,212 |
| smoke (Studio) | 2,179 |
| trophy | 314 |
| adventure-settlement | 153 |
| persistence-boot (live and Studio) | pass |
| client | 1,464 |
| 7 tutorial scenarios | 14 + 13 + 12 + 10 + 10 + 14 + 16 |
| trophy-wired | 24 |
| production-wiring `off` | 36 |
| production-wiring `on` | 38 |
| production-wiring `rejoin` | 13 |
| production-wiring `client` | 20 |
| spring-vault | 22 tests |
| broadwave-dig | 23 |
| adventure-trophy-contract | 24 |
| `rojo build default.project.json` | succeeds |

The same suite also passed earlier against Codex's then-uncommitted working copy. The only
difference since is a touch layout tweak to the client card.

**Stack B:** default + trophy patch + this branch + this patch, without Codex. Everything passes;
`on` and `rejoin` print SKIPPED.

**Static checks:** StyLua is clean on every new and changed file. Strict `luau-lsp analyze`
reports nothing on the new files or the patched shared files.

**Mutation checks:**

- Making `CanEnter` accept anyone fails 5 checks.
- Keeping the scene spawn enabled fails the spawn check.
- Removing only the `AdventureLoan` veto is not detected by the spec, because the issued-tool
  registry also rejects the loan. The two guards overlap on purpose.

**Not verified:** Studio play, real clients or devices, real DataStores, streaming of the pocket,
lighting under the slab, and populated performance.

## Open decisions for the owner

1. **Sale evidence.** Add a server-only, permanent first-sale record (and a deposit-located record)
   before enabling, or accept the lossy quest-based catch-up? Recommendation: a server-written
   `ExpansionTutorial.FirstSaleAt` set by `EconomyService`. It is a persistent write, so it was
   left out of this slice.
2. **Getting into the pocket.** There is no way in. Mara and Pip live inside the arena, which
   players cannot reach. This needs a surface Mara/Pip plus a server teleport into the pocket and
   back. It belongs to Codex (presentation). Lighting under the slab needs a Studio look.
3. **Runtime support for the licensed tool.** Should `SpringVaultService` accept a server-issued
   licensed Broadwave for ordinary charges (review H2)? Until it does, `BroadwaveOrdinary` must
   stay off.
4. **Equip control.** Resolved by `UI/BroadwaveEquip` (licensed-broadwave.md), and reduced to one
   visible control by the rule in 4.4. The clean fix is Codex's `ExternalEquip` (4.7).
5. **License key and grant owner.** `ToolLicenses.tool_broadwave` (bible ch.04) or something
   else? Which quest service writes it (q_pip at cert_explorer)?
6. **Kill-switch trigger.** Should `AdventureBoot.Disable()` be wired to an admin command or a
   cross-server message?
7. **Rewards with `SpringVault` off.** Should `AdventureRewards = false` also disable
   `AdventureSettlement` globally? That would need `trophy-wired.spec` to enable it explicitly.
