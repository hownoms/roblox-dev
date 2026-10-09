# Review: Codex `codex/spring-vault-gameplay-polish`

Reviewed 9 October 2026, read-only. I started on Codex's uncommitted working copy (based on
`9cd1ebd`). During the review Codex committed it as `fd5e414` + `d335eab`, which merges default
`a4167d9`. Line numbers below refer to `d335eab`. The only code change between the working copy
and the commit is a touch layout tweak in `SpringVaultClient`. Nothing in Codex's worktree was
modified.

Method:

- Read the diff.
- Overlaid it on default + `docs/trophy-integration.patch` + `production-wiring.patch` in a
  scratch worktree and ran the full suite plus Codex's specs. Everything passes; see
  `production-wiring.md`.
- Added a held-rejoin settlement contract test (`production-wiring.spec -a rejoin`) that drives
  Codex's real `SpringVaultState` into our `AdventureRewards` rules.

None of the findings blocks the default-off merge. **H1–H3 block enabling the feature.**

## Answers to the specific questions

**Does `DigBroadwave` respect the camp pad?** Yes, after the merge.

- `DigBroadwave` goes through the shared `digAt`, which still runs our
  `World.IsProtected(target, radius + voxel)` check first (`DigService.luau:342`). That check uses
  the pad's X/Z footprint at any depth.
- `IsProtectedVolume` alone would **not** cover the pad. It looks only for the `ProtectedGeometry`
  tag or attribute, and the pad deck is tagged `TrophyCampPad`.
- The pad is also 70 studs inland of the dig zone, so the zone clamp refuses first anyway.

No action needed, but keep both checks if either is refactored.

**Is the `Workspace:GetDescendants()` scan a performance problem?** Moderately. See M1.

**Can an adventure loan satisfy the bridge's tool check when `CanUse` is true?** Yes.

- `BroadwaveDigBridge.luau:39` accepts the loan by attribute and name, then defers to `CanUse`.
- That is acceptable only because `CanUse` must prove the license itself. Our
  `AdventureEligibility.CanUseBroadwave` goes further and rejects the loan outright (tested).
- Combined with H2, this means ordinary Broadwave is not usable at all under our wiring until the
  runtime accepts a licensed tool. That is safe, but it is a gap.

**Do the OnStage and OnCompletion contexts still match settlement?** Yes.

- The field names, `BoundaryVersion = 1`, `ContentVersion`, `EventInstanceId`, `Participants`
  (`UserId`, `Points`, `ObjectiveIds`, `Connected`, `Left`, plus `Eligible` and `ActiveSeconds` in
  the final context) and `CompletedStages` are unchanged.
- `adventure-settlement` (153 checks), `adventure-trophy-contract` (24) and `trophy-wired` (24)
  all pass on the merged stack.

**Does a held participant who rejoins end up Eligible, and can rejoining pay a stage twice?**

The contract test checks the following scenario:

1. User 2 is paid for `excavation` while connected.
2. They disconnect and are held. They get **no** `vault_open` stage pay, because the observation
   shows `Connected = false`.
3. They rejoin 30 s later with the result `rejoined`, and their points are preserved. A second
   join is refused.
4. They haul through the gates and are `Eligible = true` at completion, so the final is granted.
5. Our final reconciliation (60 minus stage coins already received) brings their total to 60.

Double stage rewards are not possible:

- `stagesSent` fires each stage once per event (`SpringVaultService.luau:228-247`).
- Stage receipts are keyed `adv:<instance>:<user>:stage:<id>:v1`, so a replay is a `Duplicate`.

An expired hold is refused. No exactly-once defect was found on the rejoin path. Two caveats
(L3, L4) are below.

## Findings

### H1. The review arena's Neutral SpawnLocation would spawn real players inside the adventure (High, production only)

- **Where:** `SpringVaultScene.luau:76-86` creates `AdventureReviewSpawn` (`Neutral = true`,
  `Duration = 0`), on every build and every `resetEvent` rebuild.
- **Problem:** production spawns are also Neutral SpawnLocations (`World/Hub.luau:55`). Roblox
  picks randomly among them.
- **Failure:** with the runtime started, about 1 in 4 joins and respawns land in the arena pocket,
  under the map, away from the hub.
- **Mitigation in this branch:** `AdventureBoot` disables every SpawnLocation under the scene,
  including rebuilds. This is tested.
- **Fix:** add a scene option (for example `Options.ReviewSpawn = false`) so production never
  creates the spawn.

### H2. The runtime accepts only its own loan, so ordinary Broadwave with a licensed tool is impossible (High, integration)

- **Where:** `usableAbility` (`SpringVaultService.luau:174-203`) requires
  `tools[player]`, the runtime-created loan, to be in the character. The `ChargeRelease` check
  (`:444`) also requires `began.Tool == tools[player]`.
- **Failure:** a licensed player who holds a real `ToolId = tool_broadwave` tool can never start a
  charge. The only way to reach `OnOrdinaryBroadwave` is to hold the adventure loan. That makes
  the loan a de facto ordinary tool for licensed players, and pushes `CanUse` to be the only guard.
- **Fix:** let the charge accept a server-issued licensed tool. One option is
  `Options.ResolveTool(player) -> Tool?`, which `AdventureBoot` would supply from
  `BroadwaveLicense`. Then route loan releases to event and trial targets only, and licensed-tool
  releases to the ordinary adapter.

### H3. Production hides the Backpack, so the loan (and any Broadwave tool) cannot be equipped (High, integration)

- **Where:** `src/client/Main.client.luau:24` calls
  `SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)`. The shovel is auto-equipped by
  `ShopService`.
- **Failure:** the runtime requires the tool to be equipped (`usableAbility`), but production
  players have no hotbar and no number-key equip. Pip's trial cannot be completed. Anchors can
  still be cleared with the Excavate prompts.
- **Fix:** add a client equip toggle, for example a HUD button that calls
  `Humanoid:EquipTool(tool)` locally, which replicates for the player's own tools. Another option
  is to auto-equip on the first charge press. This is presentation work; owner to assign.

### M1. `IsProtectedVolume` scans the whole Workspace on every candidate release (Medium, performance)

- **Where:** `DigService.luau:457`, `for _, instance in Workspace:GetDescendants()` with a
  `GetAttribute` call per instance. The `GetTagged` loop is at `:444`.
- **Scale:** after a full `World.Build` the Workspace holds 13,201 instances (10,509 BaseParts),
  measured in the mock.
- **When it runs:** only after every other `digAt` check passes, so at most once per accepted
  release, behind an 8 s per-player cooldown. It runs on the remote handler, on the main thread.
- **Cost:** estimated at a few milliseconds per call on a server. That is a visible hitch with
  several Broadwave users, and it grows with the map. In the mock it measured about 15 ms, which
  is not representative of the engine.
- **Fix:**
  - Rely on the tag (the scene already tags every part).
  - Or cache attribute-marked roots once, using `DescendantAdded` plus `AttributeChanged`.
  - Or query `Workspace:GetPartBoundsInBox(center, size, params)` and check the tag or attribute
    on the hits and their ancestors.

### M2. Passing `OnOrdinaryBroadwave` silently widens charge gating (Medium)

- **Where:** `SpringVaultService.luau:184-186` makes `usableAbility` return true for any loan
  holder whenever the adapter exists. This bypasses the Ready, stage, `CanTrial` re-check and
  trial-patch proximity checks. `ChargeBegin` (`:421`) also skips the membership check.
- **Failure:**
  - Any loan holder can loop Begin/Cancel anywhere on the map, up to the 12/s rate limit. Each
    iteration broadcasts `Charge`/`CancelCharge` effects to every client.
  - Charges are no longer cancelled when the player walks away from the trial patch.
  - Event state stays safe, because `hitAnchor` still requires a Ready, present participant.
- **Mitigation in this branch:** the adapter is passed only when `BroadwaveOrdinary` is on.
- **Fix:** keep the original gating for event and trial use, and allow ordinary charges only for
  a licensed tool (see H2).

### M3. After Pip's trial, the loan stays for the whole session and the client sinks Q (Medium, input)

- **Where:** `trial[player]` is cleared only on `PlayerRemoving` (`:656`), and Heartbeat re-loans
  every frame (`:670`). The client sinks Q/L1 whenever
  `snapshot.joined or snapshot.loanAvailable` (`SpringVaultClient.luau:234`), even when the tool
  is not equipped.
- **Failure:** in production, Q ("Return to surface") stops working for the rest of the session
  once the player has done the trial. The server rejects the charge because the loan is not
  equipped, so the key does nothing.
- **Mitigation in this branch:** `InputController` binds DigSurface at a higher priority and
  passes Q only while a Broadwave tool is equipped (tested).
- **Fix:**
  - Gate the client action on an equipped Broadwave tool, or bind and unbind on
    `Equipped`/`Unequipped`.
  - End the trial loan once the trial completes or the player leaves Pip's area.

### L1. A misleading message after a failed event release (Low, UX)

- **Where:** `SpringVaultService.luau:499-516`.
- **Failure:** when an anchor release misses (cooldown or aim), the ordinary adapter is tried
  next. Its refusal ("Equip Broadwave with an unlocked ordinary digging license.") replaces the
  event hint.
- **Fix:** show the ordinary reason only when the player is outside the arena, or when no event
  or trial target was in range.

### L2. The Broadwave touch button shows for every mobile player (Low, presentation)

- **Where:** `SpringVaultClient.luau:249` binds with `createTouchButton = true` for everyone.
- **Mitigation in this branch:** `AdventureController` hides the button unless a Broadwave tool
  is equipped.
- **Fix:** bind only while the tool is equipped. Also check the overlap with RideButton and the
  survival HUD at (1, -160, 1, -170).

### L3. A rejoin sets `Present`/`PresenceSince` before presence is sampled (Low)

- **Where:** `SpringVaultState.luau:181-188`.
- **Failure:** a rejoiner standing outside the arena counts as present until the next Heartbeat
  `setPresence`. That adds at most one frame of `ActiveSeconds` and briefly clears `EmptySince`.
  No reward impact was found.
- **Fix:** leave `Present = false` and let `setPresence` set it.

### L4. Points for stages missed while held are reconciled only at the final (Low, for awareness)

- **When:** a held participant is `Connected = false` at a stage observation and gets no stage
  coins for that stage (correct, owner rule).
- **Effect:** if the run then fails, they keep only the stages they were connected for.
- **Rejoin scope:** rejoining works only if Roblox places the player back on the *same* server
  within 90 s. Cross-server returns start fresh. This matches the owner's "disconnected players
  ineligible" decision. No action needed unless the owner wants a stage catch-up.

### L5. A stage observation does not require presence in the arena (Low, question for owner)

- **Where:** `observations()` (`:204-227`) and `AdventureRewards.StageDecisions`.
- **Effect:** a connected participant with points who has wandered out of the arena is still paid
  stage coins. This behaviour was unchanged by this branch. Decide whether the stage rule should
  also require `Present`.

## Checked and fine

- **`HaulMovementBudget`:** banks are bounded at 4 studs per player. Teleports and backward
  movement are rejected. Consumption is capped by the crew/solo speed times dt. Banks reset on
  gate, latch and reset.
- **`ResetBall`:** repeated requests cannot postpone recovery (`ballResetAt or now + 3`). Reset
  releases speed and cargo for everyone.
- **`walkSpeeds`:** now records the Humanoid, so restoring after a respawn does not write to a
  new character.
- **Leave:** it is now available while absent or dead, and `restore` still runs.
- **`DigBroadwave`:**
  - it is one shovel-equivalent scoop, using `ShovelOptions("Shovel")`;
  - it shares the shovel cooldown and keeps every refusal reason;
  - the protected-volume check happens before any mutation.

  `broadwave-dig.spec` covers this (23 checks).
- **Bridge:**
  - charge bounds 0.8..10 s;
  - the frame must match the root (±0.1 stud, facing dot ≥ 0.999);
  - a terrain-only raycast from a server-chosen aim point;
  - a separate 8 s cooldown;
  - no client positions.
