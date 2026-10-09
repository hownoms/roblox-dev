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
| `src/client/Controllers/AdventureController.luau` | Claude | Starts `SpringVaultClient` only when the server's remotes exist |
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

Conflicts found by searching the client:

| Input | Existing owner | Adventure use | Resolution |
|---|---|---|---|
| Q | `InputController` "DigSurface" (`BindAction`, Q + ButtonX) | `SpringVaultClient` "SpringVaultBroadwave" (`BindAction`, Q + L1; sinks whenever `joined or loanAvailable`) | DigSurface is now bound at `Medium.Value + 1`, so it sees Q first. It passes Q only while a Broadwave tool (loan or licensed) is equipped. Without the fix, a player who did Pip's trial keeps the loan all session, and Q would stop surfacing (review M3). ButtonX always surfaces |
| L1 | `PlacementController` "SurvivalPlaceRotate" (High priority, only while placing) | Broadwave charge | Placement wins while placing; no change |
| E | ProximityPrompt default; `ExcavationGame` raw `InputBegan` during the minigame | Adventure prompts (`KeyboardKeyCode = E`) | The prompts live only in the pocket arena and excavations only happen in the dig zone, so they never overlap; no change |
| Touch | `DigController` digs on touch `InputBegan` (`processed == false` only) | CAS touch button (64px) | CAS buttons are GUI, so the dig handler sees `processed = true`. `AdventureController` shows the button only while a Broadwave tool is equipped (the runtime binds it for everyone) |
| LMB / R2 / touch dig while hauling or in dialogue | `DigController` | — | `InputArbiter.Suppress("AdventureHauling", snapshot.hauling)` and `Suppress("AdventureArena", standing on the arena floor)`. Every adventure dialogue (Mara, Pip) and objective is in the arena. Reasons are named and independent, unlike the `DigController.Enabled` save/restore pattern that Placement and Ride share |
| Auto-equip on dig | `DigController.ensureToolEquipped` equipped the *first* Backpack tool | Loan/licensed tool in the Backpack | Now prefers the tool carrying `ShovelId` |

The server already refuses digs in the arena (`OutOfZone`), so the client pause only removes
misleading cursor hints.

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
4. **Equip control.** The production client hides the Backpack, so loan and licensed tools can't
   be equipped (review H3). A HUD toggle or an auto-equip on charge is needed. It belongs to
   Codex or the UI owner.
5. **License key and grant owner.** `ToolLicenses.tool_broadwave` (bible ch.04) or something
   else? Which quest service writes it (q_pip at cert_explorer)?
6. **Kill-switch trigger.** Should `AdventureBoot.Disable()` be wired to an admin command or a
   cross-server message?
7. **Rewards with `SpringVault` off.** Should `AdventureRewards = false` also disable
   `AdventureSettlement` globally? That would need `trophy-wired.spec` to enable it explicitly.
