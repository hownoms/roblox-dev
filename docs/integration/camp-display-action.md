# Camp display action and preview (handoff)

Branch `claude/camp-display-action`, based on `a4167d9`. This adds one small action for the one
protected camp pad (`Workspace.Map.Hub.TrophyCampPad1`): put your Spring Vault trophy on display,
or put it away, with a local preview first. It is not a camp editor. Full camp UI, furniture and the
16 pads are still later scope. Nothing was pushed, uploaded or published.

## Player-facing flow

1. The player walks up to the camp pad. A small "TROPHY CAMP" card floats above the deck and shows
   their status (see the table below). Only the local player sees it.
2. If they can display a trophy, a **Display trophy** prompt appears (hold E, 0.5 s; tap on
   touch; ButtonX on gamepad). While that prompt is on screen and the pad is free or already
   theirs, a see-through, non-colliding ghost of Mara's stand and the ball replica sits on the
   exact cell the server will use: the plaza-side centre cell (5,5), facing the plaza.
3. Holding the prompt makes the server place the trophy through `TrophyService.PlaceTrophy`. The
   player gets a toast with the real result: "Trophy on display!", a place in line, or no pad.
4. Once something is saved, a **Put trophy away** prompt (hold 0.75 s) replaces it. It removes
   the newest placement. The trophy and stand stay owned, and the pad passes to the next player
   in line.

## Behavior per state

The server publishes the status as read-only Player attributes `CampStatus` and `CampQueue`.

| `CampStatus` | When | Card text | Prompt shown | Ghost |
|---|---|---|---|---|
| *(missing)* | data not loaded | hidden | none | no |
| `Off` | `TrophyService.SetEnabled(false)` (camps also come off the pad, see `camp-lifecycle.md`) | hidden | none (also disabled on the server) | no |
| `NoTrophy` | no displayable trophy | "Finish the Spring Vault to earn a trophy." | none | no |
| `NoStand` | trophy, no stand (or a saved layout without the stand) | "You need Mara's trophy stand first." | none | no |
| `Ready`, pad free or yours | may display, layout empty | "Your Spring Vault trophy can go here." | Display trophy | yes |
| `Ready`, pad held by someone else | same | "Mo's camp is up. Display yours and you'll be next in line." | "Save & join line" | no |
| `Displayed` | your camp is on the pad | "Your trophy is on display." | Put trophy away | no |
| `Queued` | layout saved, pad busy | "Camp pad busy. Your display is saved; you're #N in line." | Put trophy away | no |
| `NoPad` | layout saved, pad count 0 | "Saved to your camp, but this server has no camp pad, so nothing is shown." | (no deck to hang it on) | no |

The server sends the same wording as a toast when an action is refused or completes. The
`PlaceCampItem` remote path now also tells the player honestly whether the placement is shown,
queued, or not shown because there is no pad.

## Authority and safety

- **Prompts.** Both prompts are server-owned. Each is created by
  `TrophyService.ConnectCampPrompts(net)` on every part tagged `TrophyCampPad`, including parts
  that appear later. A prompt's `Triggered` handler acts only on the triggering player's own save,
  through `DisplayAction` and `RemoveAction`.
  - Those actions call the existing `PlaceTrophy` and `RemovePlacement`, so the stand rule, the
    grid validation, pad ownership, the FIFO wait list and the hand-over all apply unchanged.
  - The client sends nothing. The client spec checks that no remote is fired.
- **Client-side prompt state.** The client hides the prompt that does not apply by setting
  `Enabled` locally. This is presentation only: if the client is stale, the server still refuses
  with the honest reason.
- **Preview.** The preview is purely local and uses the same math as the display:
  `CampAction.FirstFreeCell` and `CampAction.CellCFrame`, which equals
  `TrophyCampDisplay.PlacementCFrame` (tested). It never creates server state.
- **Other players.** Another player's actions never change someone else's camp. This is tested
  with three players: queueing, putting away while queued, putting away as the owner, and
  leaving.
- **Studio review.** `SetReviewPreview(true)` (Studio only) shows `Ready` without a stand, and the
  action displays the trophy. Turning it off returns the player to `NoStand` and hides the camp.
  No stand is granted, and the reviewed layout stays saved (existing behavior).

## Files

| File | Change |
|---|---|
| `src/shared/Trophies/CampAction.luau` | New. Pure shared module: status names, attribute and prompt names, `NextTrophy`, `FirstFreeCell`, `Request`, `CellCFrame`, `Text`, `ResultText`. |
| `src/server/Services/TrophyService.luau` | Status computation and publishing (`GetCampStatus`, attributes refreshed on every camp, grant, enable, preview and leave change), `DisplayAction`, `RemoveAction`, `ConnectCampPrompts`, prompts follow `SetEnabled`, honest result toast on `PlaceCampItem`. |
| `src/client/Controllers/CampDisplayController.luau` | New. Card, local prompt visibility, ghost preview. Streaming-safe through `Util/Tagged`. |
| `tests/trophy.spec.luau` | +85 checks in "camp display action". |
| `tests/client.spec.luau` | +36 checks in "trophy camp action". |
| `docs/integration/camp-display-action.patch` | Shared-file wiring, not applied (see below). |

## Shared-file wiring: `docs/integration/camp-display-action.patch`

Apply it **after** `docs/trophy-integration.patch`. Its server hunk sits next to that patch's
`ConnectRemotes` line, so it does not apply on its own.

- `src/client/Main.client.luau`: require and `start("CampDisplay", CampDisplayController.Init)`.
- `src/server/Main.server.luau`: `run("TrophyService", "ConnectCampPrompts", TrophyService.ConnectCampPrompts, Net)`.
- `tests/trophy-wired.spec.luau`: 7 checks covering the prompts Main hangs on the authored deck,
  display and put away through the real `Net` toast. They live in the patch because they need the
  wiring.

No new remotes are added.

## Evidence

Both patches were applied in a scratch copy (trophy patch, then this one, with `git apply --check`
first). Tests run there:

- util 8
- smoke 2212 (2179 in Studio mode)
- trophy 399
- adventure-settlement 153
- persistence-boot live and Studio passed
- client 1500, plus all 7 tutorial scenarios
- trophy-wired 31
- adventure-trophy-contract 24
- spring-vault 16

Unpatched worktree: the same numbers, with trophy at 397 and trophy-wired not run. `luau-lsp`
strict analysis is clean apart from two existing deprecation notes in RewardsService. StyLua is
clean on the changed files.

## Not verified

- **No Studio play test or screenshot.** Not verified: ghost transparency and readability, card
  size and position (11×2.8 studs, 7 studs above the deck), prompt placement, and how two prompts
  on one part behave if the client controller is missing.
- **No real multiplayer or phone/controller check.** Queue positions and the hand-over are
  covered by mock tests only.
- **Prompt override.** The client hides prompts by setting `Enabled` locally on a server-owned
  prompt. If the server changes `Enabled` (only `SetEnabled` does), the client now re-renders
  on that property change, so the local choice wins again (fixed in `camp-lifecycle.md`). Not
  checked in a live client.

## Decisions and risks to review

- **One trophy at a time.** `Ready` requires an empty layout. With several trophies, a player who
  has one on display would not be offered a second through this action. That is fine for the
  one-trophy slice; the full camp UI replaces it later.
- **Put away removes the newest placement**, not a chosen one.
- **Status is visible to everyone.** `CampStatus` and `CampQueue` are Player attributes, so every
  client can read them. They hold nothing sensitive.
- **No pad means no in-world entry point.** With pad count 0 there is no deck to hang the prompt
  on. The honest NoPad result is reached through `DisplayAction`, the `PlaceCampItem` remote toast
  and the `CampStatus` attribute, and it is tested at the service level. In the shipped map one
  pad always exists.
- **Activation range.** `MaxActivationDistance` is 18 and line of sight is not required, so the
  prompt works from anywhere on the 24×24 deck.
