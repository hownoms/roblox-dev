# Licensed Broadwave: runtime contract and equip control

Branch `claude/svi-equip`, 9 October 2026, based on `claude/spring-vault-production-integration`
`3e216f5`. Nothing is pushed, uploaded or published. Every `AdventureFlags` flag still ships
**off**, and nothing in this slice writes a save or grants a license.

This closes the production side of review findings H2, H3 and M2 (`codex-polish-review.md`) and
production-wiring open decisions 3 and 4.

## 1. The runtime contract

While this work was in progress, Codex pushed `a40f1f8` to PR #33
(`codex/spring-vault-validation`). It adds the option this contract needs, under the name
**`ResolveTool`**. We adopted Codex's name and dropped our working name `ResolveOrdinaryTool`, so
the boot code and the runtime agree.

```lua
-- SpringVaultService.Start options (Codex's runtime, PR #33 a40f1f8)
ResolveTool: ((Player) -> Tool?)?   -- the player's equipped, server-issued licensed tool, or nil
```

**What we supply** (`AdventureBoot.Options`, only when `Flags.BroadwaveOrdinary` is on *and*
`BroadwaveDigBridge` + `DigService.DigBroadwave` exist):

```lua
options.OnOrdinaryBroadwave = Bridge.Create({ CanUse = Eligibility.CanUseBroadwave, Dig = dig })
options.ResolveTool = BroadwaveLicense.ResolveTool
```

`BroadwaveLicense.ResolveTool(player)` returns `tools[player]`, the tool this server built for
that player. It returns the tool only while every one of these holds:

- the feature is running;
- the argument is a real `Player`;
- the tool still exists;
- `AdventureEligibility.CanUseBroadwave(player, tool)` passes. That requires:
  - ordinary Broadwave enabled at boot;
  - the tool was issued to this player;
  - `ToolId == "tool_broadwave"`;
  - not `AdventureLoan`;
  - the tool is equipped (parented to the character);
  - the loaded save has a `ToolLicenses.tool_broadwave` record.

In every other case it returns `nil`. It is read-only and never writes a save. Whether q_pip
grants a license is still an open owner decision.

**What the runtime does with it** (a40f1f8, verified end to end below):

- At `ChargeBegin` the runtime takes its own equipped loan first, otherwise the resolved tool. It
  re-checks the exact tool identity, `ToolId` and not-loan, and checks again at release.
- If the tool changes or is unequipped mid-charge, the charge is cancelled.
- A loan charge keeps the original event/trial gating. Passing an adapter no longer widens loan
  charging (M2 fixed).
- Only a non-loan (resolved) tool can fall through to `OnOrdinaryBroadwave`. `BroadwaveDigBridge`
  also refuses `AdventureLoan` outright, and our `CanUse` refuses it a third time.

### Loan vs license rules

| | Adventure loan (`AdventureLoan`) | Licensed tool (`LicensedBroadwave`, issued by `BroadwaveLicense`) |
|---|---|---|
| Who creates it | SpringVaultService, on Join or Pip trial | BroadwaveLicense, from the saved `ToolLicenses.tool_broadwave` record under `BroadwaveOrdinary` |
| Lifetime | the event or trial; destroyed on restore / Destroy | re-issued every respawn; removed when the license record is missing or on `Disable()` |
| Charge accepted | only with event/trial gating (trial patch in range plus `CanTrial`, or an active anchors-stage participant) | anywhere, while `ResolveTool` returns it |
| Event / trial work | yes | yes (see decision below) |
| Ordinary sand (`OnOrdinaryBroadwave`) | **never** (runtime, bridge and `CanUse` all refuse) | yes, through `DigService.DigBroadwave` (shovel-equivalent scoop, 8 s cooldown) |
| Forged copy (same name and attributes, not issued) | not issued, refused | refused by the registry |
| Another player's issued tool | n/a | refused (`issued[tool] ~= player`) |
| Renamed | the name is never evidence | still accepted if issued (the name is never evidence) |

**Decision: a licensed tool may also do event and trial work.** The task proposed routing licensed
charges *only* to ordinary digging. Our first draft patch did that. We now accept Codex's routing
instead, for three reasons:

1. The owner rule, "preserve the distinction between review loans and permanent licenses",
   protects the *permanent capability*: ordinary sand. That stays loan-proof three times over.
2. Event and trial work earns the same with either tool. The trial grants nothing permanent, and
   event rewards go through settlement, not the tool. A licensed player gains nothing extra.
3. Forcing licensed players to swap to the loan inside the arena would only add friction.

## 2. Equip control (`src/client/UI/BroadwaveEquip.luau`)

Production hides the Backpack CoreGui, so this control is the only way to equip a Broadwave.

**When it exists:**

- `AdventureController` starts it only after the server's `SpringVaultAdventure` remotes exist
  and `SpringVaultClient` has started. With the flags off, nothing is required, built or bound.
- Even when started, the GUI is not built and no key is bound until the local Backpack or
  character holds a Broadwave tool:
  - the loan (`AdventureLoan`);
  - or a licensed tool (`LicensedBroadwave` or `ToolId == "tool_broadwave"`).
- When the last one goes (loan returned, license removed, kill switch, respawn), the button hides
  and the binding is removed.
- It watches the Backpack and the character. A new Backpack after a respawn is picked up, and
  containers from an earlier life are dropped.

**Behaviour:**

- **Label:** "Broadwave (loan)" (caption `Broadwave` / `(loan)` on two lines, readable at 120 px)
  vs "Broadwave" for the licensed tool.
- **Colour:** Ocean when stowed, Palm when in hand. The tool also appears in the avatar's hand.
- **Which tool it acts on:** the equipped Broadwave first. With both tools and none equipped, it
  picks the loan inside the arena (event and Pip trial) and the licensed tool everywhere else.
  The 0.25 s `AdventureController` tick refreshes this.
- **Equip:** `Humanoid:EquipTool(tool)` runs locally. It replicates for the player's own tools,
  and **no remote is fired** (tested).
- **Put away:** re-equips the shovel (the Backpack `ShovelId` tool) with `EquipTool`. With no
  shovel present it calls `UnequipTools`.
- **Debounce:** presses within 0.2 s count as one toggle.
- **Digging with a Broadwave in hand (decided):** `DigController.TryDigAt` pauses ordinary digging
  and hides the dig cursor. A pointer dig shows the toast "Broadwave in hand. Put it away to dig
  with your shovel." (rate-limited to once per 4 s). Auto-dig pauses silently.
  - Why: before this change a click dug *invisibly* with the stowed shovel's stats while the
    Broadwave was held, because the server doesn't check the equipped tool. Swapping tools on
    every touch would fight camera drags on phones, which start a dig on `InputBegan`.
- `ShopService.GiveShovelTool` does not steal the hand. It re-equips only if the shovel was in the
  hand or was never auto-equipped. Respawn equips the shovel and re-issues the licensed tool into
  the Backpack, stowed.

### Input per device and conflict audit

| Device | Equip / put away | Broadwave charge (runtime, unchanged) |
|---|---|---|
| Keyboard | **Z** | Q (hold / release). Passed by `DigSurface` only while a Broadwave is equipped |
| Gamepad | **ButtonR1** | L1 (hold / release) |
| Touch | the on-screen button (120 x 86 design px, an 80 px face, at least `MinTouchSize` 74) | the runtime's 64 px CAS button, shown only while a Broadwave is equipped |
| Mouse | click the button | — |

Keys already taken in the client:

- **Keyboard:** Q surface, G shop, P pets, F place shade, 1/2/3 survival slots, R/B/Backspace/Return
  while placing, V ride, T scan, E prompts / excavation, Space excavation, WASD/arrows riding.
  **Z** is free and sits next to Q.
- **Gamepad:** R2 dig, X surface, Y menu, B close panels, A excavation, L1 charge (and placement
  rotate at High priority), L2 scan, DPadUp ride, Thumbstick2.
  - **R1** is free. Roblox uses it only to cycle the hotbar, which production disables.
  - The DPad was avoided because GUI selection navigates with it.
- The binding never includes Q or L1 (tested), and `DigSurface` is untouched.

### Placement (`UI/Layout` "Broadwave" region)

The button takes the first free slot from this list:

1. above the bottom bar, right of centre;
2. right of the Scan button's DOWN/UP pill;
3. above Ride;
4. left of the bottom bar;
5. above that;
6. left of the Scan pill.

A slot counts as free only if it misses every HUD region, the Scan pill and the phone thumbstick
and jump zones. `client.spec` checks all 12 design sizes:

- no overlap with any region, the Scan pill, the thumbstick or the jump zone;
- the region stays on screen.

It also checks 7 real viewports (705x338 Galaxy A06, 800x360, 844x390, 915x412, 932x430, 1024x768,
1180x820). The button must clear:

- the runtime's charge button at PR #33's formula (viewport.X - 88, max(76, viewport.Y/2 - 66),
  64 px);
- Roblox's jump button (small: (X-95, Y-90) 70 px; large: (X-170, Y-210) 120 px);
- the jump position measured on the A06, (610, 190);
- Ride;
- the SurvivalHUD.

## 3. Test evidence

All runs used the headless mock with the in-memory DataStore, on Windows with luau 0.640.

### Applied tree: this commit, runtime as in `3e216f5` (no ResolveTool)

| Spec | Result |
|---|---|
| util | 8 |
| smoke (live) | 2,212 |
| smoke (Studio) | 2,179 |
| trophy | 400 |
| adventure-settlement | 275 |
| adventure-outcome | 23 |
| trophy-wired | 35 |
| production-wiring `off` | 36 |
| production-wiring `on` | 39 (was 38; adds the resolver-wired check) |
| production-wiring `rejoin` | 13 |
| production-wiring `client` | 59 (was 20; +39 equip-control checks) |
| **broadwave-license (new)** | **38, then prints `SKIPPED (runtime lacks ResolveTool — see request)` for the end-to-end part** |
| persistence-boot (live and Studio) | pass |
| broadwave-dig | 23 |
| spring-vault | 22 tests |
| adventure-trophy-contract | 24 |
| client | 1,675 (was 1,500; +175 layout checks) |
| 7 tutorial scenarios | 14 + 13 + 12 + 10 + 10 + 14 + 16 |
| `rojo build default.project.json` | succeeds |

### With the proposed runtime patch (not applied)

Tree: this commit plus `docs/integration/requests/runtime-licensed-broadwave.patch`, i.e. the
server half of Codex's a40f1f8 plus the `Service.Contract` marker.

| Spec | Result |
|---|---|
| **broadwave-license** | **62, end-to-end part included** |
| production-wiring | `off` 36, `on` 39, `rejoin` 13, `client` 59 |
| broadwave-dig | 24 (Codex's updated spec in the patch) |
| everything else | identical to the applied tree (smoke 2,212 / 2,179, trophy 400, settlement 275, outcome 23, trophy-wired 35, client 1,675, tutorials as above, spring-vault 22, trophy-contract 24, persistence pass) |

### With Codex's full a40f1f8 adventure runtime overlaid (not applied)

This run overlaid server, client, shared `BeachBallVisual` and Codex's specs, with no marker.

| Spec | Result |
|---|---|
| broadwave-license | 61 (detected by probe; prints "NOTE: … no Service.Contract marker") |
| production-wiring | `client` 59 with PR #33's new `SpringVaultClient` (our control is compatible); `on` 39; `off` 36; `rejoin` 13 |
| spring-vault-input | 191 |
| spring-vault-runtime | 38 |
| broadwave-dig | 24 |

The `on` scenario's spawn check now accepts "no spawn at all": PR #33 adds `ReviewSpawn`, which
defaults to false. It still requires zero *enabled* arena spawns.

### End-to-end checks in `broadwave-license`

- A licensed charge on sand scoops through `DigBroadwave`, starts the cooldown, and scoops again
  after it ends.
- The loan on sand: the charge is refused and no sand is paid.
- Unequipping mid-charge cancels the charge and pays nothing. Switching licensed to loan mid-charge
  does the same.
- The licensed tool can clear the trial patch, which pays no sand.
- An unlicensed trial player's loan clears the trial patch but cannot charge on sand.
- A forged copy, another player's issued tool, and a tool whose license record has gone are all
  refused.
- Kill switch: the resolver returns nil, the tool is removed, and the saved license is untouched.

### Mutation checks

- Dropping the `CanUseBroadwave` recheck from `ResolveTool` fails 8 checks.
- Dropping the shovel re-equip from the toggle fails 2 client checks.

### Static checks

- StyLua is clean on every changed file except `tests/client.spec.luau`, which was already
  unformatted at base and was not reformatted.
- `luau-lsp analyze` (sourcemap from rojo) is clean on the changed sources.

## 4. Still to verify on devices and in Studio (not done)

- A real phone, especially a Galaxy A06-class 705x338 screen:
  - the button's position next to the real jump button and the runtime's charge button;
  - safe-area insets (the mock ignores them);
  - readability of the two-line caption at UI scale 0.6.
- Gamepad R1 and keyboard Z on a real client, including with chat focused (CAS should not fire).
- `Humanoid:EquipTool` replication from the client for both tools. In particular, that the server
  sees the tool parented to the character before the charge's `ChargeBegin` arrives.
- Respawn timing: `BroadwaveLicense` re-issues on a deferred resume after `CharacterAdded`, and the
  control picks the tool up from the new Backpack's `ChildAdded`.
- Two equip buttons are visible with PR #33's client (request 1 below).
- Populated performance and streaming of the pocket are unchanged by this slice and still not
  verified.

## 5. Requests to Codex

1. **One equip control.** a40f1f8's `SpringVaultClient` adds its own `BroadwaveEquip` TextButton
   ("Equip Broadwave", 176x48, top-centre at y 76, or inside the card). In production it would
   appear alongside ours.
   - Its position overlaps the top-centre objective banner and toast column.
   - It doesn't label loan vs license.
   - Its `UnequipTools` leaves no shovel in hand.

   Proposed: `Client.Start(remotes, scene, options)` with `options.ExternalEquip = true`, which
   skips building the button. `AdventureController.begin` would pass it. Keep the button for the
   review place.
2. **Capability marker (optional).** Add
   `Service.Contract = table.freeze({ ResolveTool = 1 })` next to `local Service = {}` in
   `SpringVaultService.luau`. With it, `broadwave-license.spec` *fails* instead of skipping if the
   runtime stops accepting licensed charges. Without it the spec falls back to a behavioural
   probe. The marker is the only non-Codex line in the patch.
3. **Merge order.** `docs/integration/requests/runtime-licensed-broadwave.patch` applies cleanly to
   this tree (`git apply --check`). It contains exactly the server half of a40f1f8:
   - `SpringVaultService` `ResolveTool`;
   - `BroadwaveDigBridge` loan refusal;
   - `SpringVaultScene` `ReviewSpawn`;
   - the matching `broadwave-dig.spec` hunk;
   - plus request 2.

   It is provided only for an integration tree that wants licensed support before PR #33 lands.
   Merging PR #33 supersedes it. Do not apply both.
4. **Small nit in a40f1f8.** `SpringVaultScene.Build` has the `if reviewSpawn == true then` block
   (and its comment) nested twice. It is harmless; please collapse it.
5. **L1 (unchanged in a40f1f8).** When a licensed tool's anchor or trial release misses, the
   ordinary refusal message ("Equip Broadwave with an unlocked ordinary digging license." / "Face
   ordinary beach sand…") replaces the event hint inside the arena. Suggested: in `ChargeRelease`,
   use `ordinaryReason` only when the player is outside the arena box (the same test as
   `setPresence`).
6. **M2 residue (accepted, for awareness).** A licensed tool passes `usableAbility` anywhere, so a
   licensed player can Begin/Cancel anywhere within the 12/s limiter. Each cycle broadcasts
   `Charge`/`CancelCharge` to all clients. Consider sending the `Charge` effect only to clients
   near the player.

## Files

- `src/server/Services/BroadwaveLicense.luau`: `ResolveTool`, plus header notes.
- `src/server/Services/AdventureBoot.luau`: `Options` only: `options.ResolveTool`.
- `src/client/UI/BroadwaveEquip.luau`: new.
- `src/client/UI/Layout.luau`: `Broadwave` region.
- `src/client/Controllers/AdventureController.luau`: starts and refreshes the control.
- `src/client/Controllers/InputArbiter.luau`: `LicensedBroadwave` counts; `IsBroadwaveLoan`.
- `src/client/Controllers/DigController.luau`: pauses digging with a Broadwave in hand.
- `tests/broadwave-license.spec.luau`: new, registered in `tests/run.sh`.
- `tests/production-wiring.spec.luau`: `client` equip checks, resolver check, spawn check.
- `tests/client.spec.luau`: Layout checks.
- `docs/integration/requests/runtime-licensed-broadwave.patch`: unapplied.
