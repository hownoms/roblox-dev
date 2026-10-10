# Spring Vault player flow: connected vertical slice

Branch `claude/adventure-player-flow`, 9–10 October 2026. It starts at default `5897990` (merged
PR #35). **Merged into default on owner instruction on 10 October 2026** (see "Merge record"
below). **Every `AdventureFlags` flag is still `false`.** Nothing was published or uploaded, and
no live save test was run. Codex's runtime, scene and client files are unchanged.

Slice: surface entrance → invitation → equipped ability and adventure controls → completion
result → safe return, all on the real production boot.

## What now works in the game (with the flags on)

1. **Discovery.** An eligible player (loaded save: `cert_rookie`, or veteran sale + deposit
   evidence) gets one invitation per session once the tutorial is finished: the toast "Mara needs
   diggers: the hatch west of the crate yard." plus the guide beam to the hatch.
   - The server rechecks on load and whenever certifications, quests, finds or settings change.
   - Nothing is written to the save.
   - See `adventure-entry.md`, "Invitation".
2. **Entry.** The hatch prompt is checked on the server. An ineligible player gets the truthful
   refusal and stays on the beach; an eligible player arrives next to Mara.
3. **Ability and controls.**
   - The adventure client starts only in the arena or while a Broadwave is in hand.
   - Ordinary digging pauses for two named reasons, `AdventureArena` and `AdventureHauling`, and
     for a Broadwave in hand. They recover on Leave, respawn, scene rebuild and kill switch.
   - Q passes to the charge only when it can actually charge.
   - One equip control: ours (`Dig_Broadwave`). The runtime's fallback stays hidden and inert
     (Codex's PR #37); see "Merge record".
   - Production HUD pieces that overlap the runtime, including the tutorial objective pill, step
     aside in the arena. Toasts move below the panel.
   - Details are in `production-wiring.md` section 4.
4. **Licensed tool.** `ResolveTool` is `BroadwaveLicense.ResolveTool`. It returns only the
   equipped tool this server issued, re-runs `CanUseBroadwave` against the loaded save and flags,
   and the runtime checks again at release.
5. **Return frame.** `ReturnFrame` is `AdventureEntry.SURFACE_RETURN`. Leave, the return pad and
   the end of a run all land there.
6. **Completion.** `AdventureSettlement` settles each player, and the `AdventureOutcome` card shows
   that player's own result:
   - Accepted is shown as saved only once it is durable (written to the save or the outbox).
   - Pending says "not saved yet" or "Rewards waiting", and is never worded as a grant.
   - Refused gives the reason.
   - A stage that granted nothing shows no card.
   - The truth table is in `settlement-outcomes.md`.
7. **Ordinary play afterwards.** Digging works again, and a stowed loan is never auto-equipped
   by a dig. A loan never authorizes ordinary digging, on the server or the client.

## Studio evidence (Expansion1Review, PlaceId 0, real production boot)

- **Setup.**
  - `expansion1-production-review.project.json` sources were injected into the open
    Expansion1Review place with `tools/expansion1/inject-production-review.py`.
  - Codex's review scripts were parked for the run and restored afterwards; only
    Expansion1Review and its child Play DataModels were operated.
  - Saves were in-memory. The review boot's 14 self-checks passed, confirming the real
    `AdventureBoot.Options` with no resolver shim.
- **Real input versus assisted.** The one assisted step was seeding the review prerequisite
  through the `ProductionReviewProbe` "Seed" command, which writes an in-memory `cert_rookie`
  labelled `Review = true`. Everything else was actual Studio input on the client: walking via
  character navigation, E / Z / Q keys and mouse clicks.
  - Character navigation positions the avatar but moves it with the real Humanoid.
  - No `Intent` was fired from a script.

| Step | Observed (candidate) |
|---|---|
| E at the hatch, no prerequisite | Refusal toast; stayed on the beach (`6b5db75`) |
| E at the hatch after the seed | Arrived beside Mara; arrival toast (all runs) |
| E to Pip, Z, hold Q 1.2 s facing the patch | Loan issued and equipped; ChargeBegin → ChargeRelease accepted; "Wave landed" (`6b5db75`) |
| E to Mara, then mouse clicks Join → Start → Ready | Delivered as real `Intent`s (all runs) |
| 18 × E on the anchors, E on the latch | 3 anchors cleared; card "+6 Coins for clearing the vault anchors" (`656f3f9`) |
| E on the ball, walk the left channel | Hauling pause on, WalkSpeed 10; gates 1–3; final card "+48 Coins, trophy, stand, Crew certification" on screen (`656f3f9`, `evidence/player-flow/completion-656f3f9.jpg`) |
| End of run, Leave button, return pad E | Lifted to `SURFACE_RETURN` (-112, 1029, 76); dig pauses cleared; adventure client stopped |
| Clicks on the beach afterwards, loan in the Backpack | Sand +0.2; the loan stayed in the Backpack (`656f3f9`) |

Not established: two clients, physical phone or controller, real streaming, same-account
rejoin, live DataStore persistence, uncoached discovery. The invitation was not seen in Studio,
because the seeded player was still in tutorial step 1; it is covered by mocks only
(`adventure-entry.spec` modes `invite` and `invite-client`).

## Fixed during the Studio review (Claude side)

- **Loan auto-equipped by a surface dig** (`d32be94`). With no shovel Tool in the Backpack (the
  usual case), DigController's fallback equipped the Broadwave loan.
- **Tutorial objective pill over the runtime panel header** (`656f3f9`):
  `ObjectiveBanner.SetSuppressed`, driven by `AdventureHUD`.
- **Empty stage card** (`81deb80`): the 0-coin `ball_return` stage card no longer sits under the
  final card.

## Blockers before any flag is turned on

**Codex (runtime and client):**

1. **B1: review copy contradicts the reward card.** The completion capture (before Codex's
   PRs #36 to #40) shows "Adventure complete. Review only; no permanent rewards." next to
   "ADVENTURE REWARDS SAVED". After the merge, the end-of-run objective reads "Ball rescued · 3/3
   gates. Leave when you are ready." Still contradicting the saved card in
   `settlement-durability.spec` (2 lines):
   - the `objectives` entry "REVIEW ONLY - no coins, certifications or permanent trophies are
     granted." (`SpringVaultService.luau:394`);
   - the client header "SPRING VAULT · Review";
   - the ScreenGui name `SpringVaultAdventureReview`.

   `AdventureBoot` already passes `OutcomeOwner = "External"`.
2. **New: client fallback prompts require line of sight.** When the scene is rebuilt (every run
   after the first in a server), `installPrompt` can run before the server `AdventurePrompt`
   replicates. It then creates `SpringVaultLocalPrompt` with `RequiresLineOfSight = true`.
   - The server prompts have it false.
   - The latch sits behind `landmark_spring_vault_Covered.FrontWall`: a ray from the player hits
     the wall.
   - In the second Studio run, E reached the client (`gameProcessed = false`), but neither the
     latch nor the left-route prompt fired, so the run could not progress.
   - Fix: copy `RequiresLineOfSight` (and the distances) from the server prompt, or set it to
     false on the fallback.
3. **New: contextual buttons reflow under the cursor.** After Ready is accepted, Leave moves
   into Ready's slot, so a quick double-click quits the run. This was observed in Studio.
   Suggestion: keep Leave in a fixed slot, or ignore clicks for about 0.4 s after the row changes.
4. **Still open** (the `ExternalEquip` request is resolved by PR #37):
   - reduced-motion and particle preferences;
   - a panel shown only in the arena;
   - a named panel (`production-wiring.md` 4.7);
   - completion sent only to participants (R2);
   - kill-switch messaging (R3).

**Owner decisions:**

- ~~who grants `ToolLicenses.tool_broadwave`~~: decided, q_pip completion grants it
  (`pip-quest-license.md`);
- permanent first-sale and deposit evidence;
- the kill-switch trigger;
- how far the rewards flag reaches;
- whether hatch entry should also admit players who only qualify for Pip's trial;
- whether to lift crews to the surface at the end of a run;
- whether stage pay should require being present in the arena.

**Joint:** two-client late-helper run, physical devices, streaming, rejoin, and the live
persistence plan in `settlement-durability.md`. Riding inside the pocket is not blocked yet; that
needs a server refusal.

## Tests

The full `tests/run.sh` suite passes, plus Codex's spring-vault, runtime, input, return, scene,
presentation, broadwave-dig and trophy-contract specs. New or extended:

| Spec | Checks |
|---|---|
| production-wiring client | 121 |
| adventure-entry | off 21, invite 54, invite-client 9 |
| settlement-durability | on 209, off 76 |
| adventure-outcome | 123 |
| production-review | 92 |

## Merge record (10 October 2026)

On owner instruction ("push and merge"), `claude/adventure-player-flow` (`ac95438`) was merged
with `--no-ff` into the default branch `claude/pensive-meitner-6jx4u4`, without a PR because `gh`
was logged out. Default had moved on to Codex's PR #40 (`f0736bd`; PRs #36 to #40: Begin, trial
exit and ending reliability, deferral to the production equip HUD, stream-out input and pocket
attendance, input before arena replication, cancelling Broadwave input on death).

**Conflict and resolution.**
- Codex's PR #37 makes `SpringVaultClient` hide and ignore its own equip button whenever
  `PlayerGui.Dig_Broadwave` exists.
- Our arbitration hid `Dig_Broadwave` whenever the runtime ran (`SetRuntimeOwner`). Together the
  two rules could leave no control on screen.
- Merge resolution: `SetRuntimeOwner` is removed, so production always owns equip and stow.
  `RuntimeOwnsControl` only reports a visible fallback.
- `production-wiring.spec -a client` keeps Codex's checks and adds "exactly one control in the
  arena (ours)".

**Checks on the merged tree:**
- full `tests/run.sh`: ALL TESTS PASSED;
- Codex's specs: spring-vault 22, runtime 47, input 293, return 111, scene 81, presentation 53,
  initial-stream 16, broadwave-dig 24, trophy-contract 24;
- `audit-claude-candidate.py HEAD`: exit 0;
- both `rojo` builds succeed.

The Studio journey above ran on `656f3f9`, before Codex's PRs #36 to #40. The merged tree has
not been played in Studio yet.
