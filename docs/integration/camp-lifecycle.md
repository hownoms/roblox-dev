# Camp display lifecycle and ownership audit

Branch `claude/svi-camp`, based on `claude/spring-vault-production-integration` (3e216f5). That
base already has the consolidated adventure patch applied: Main boots TrophyService, including
`ConnectRemotes` and `ConnectCampPrompts`, and Main.client boots CampDisplayController. Every
AdventureFlag is still off. This is an adversarial pass over the camp pad display only: its
lifecycle, who can change it, and how the layout is saved. Nothing was pushed, published, or
run in Studio.

Scope. Only camp display, pad, placement, prompt and status code changed. Grant, pending,
outbox and drain code in TrophyService was not touched (another audit owns it), and neither
was Codex's runtime.

## Findings

Severity is the impact in the shipped single-pad map if the case happens.

| # | Severity | Where | Failure | Fix | Test |
|---|---|---|---|---|---|
| 1 | High | `TrophyCampDisplay` pad bookkeeping, keyed by index into the sorted tag list | When the deck is destroyed, the owner's camp model stays floating where the deck was. `GetCampPad` and `GetCampPadOwner(1)` still name the old owner, and status stays `Displayed`. On a rebuild, the new deck reads free (`OwnerUserId` 0, sign "Free pad") while index 1 is still held, and the camp is not moved onto it. Adding a tagged pad that sorts earlier shifts every index, so ownership points at the wrong deck. | `Display.Reconcile(gone)` re-keys camps by pad part and tears down camps whose part is no longer a pad. `TrophyService` listens for the pad tag being added or removed (`onPadsChanged`, wired in `Init`). Displaced owners go to the front of the line, then `handOver` runs. `Display.Show` keeps a previous index only if it still points at the same part. | trophy "pad deck destroyed and rebuilt on the server"; trophy-wired, through Main's World (destroy `Map.Hub.TrophyCampPad1`, rebuild with `CampPad.Build`) |
| 2 | Medium | `CampPad.buildPad` sign label | The deck is tagged before the sign's `OwnerName` listener exists. A waiting camp can claim the new deck at that moment, so the sign said "Free pad" under someone's camp. | The listener also reads the current owner once when it connects. | same steps ("rebuilt deck shows its owner") |
| 3 | Medium | `TrophyService.ConnectCampPrompts` | A deck that loses the tag but stays in the world kept both prompts, which then acted on a part that is no longer a pad. Calling `ConnectCampPrompts` twice also connected the tag signal twice. | A `detach` on tag removal destroys both prompts and drops them from `campPrompts`. Signals connect once (`promptsConnected`). Re-tagging or rebuilding gives exactly one fresh pair. | trophy "untag / re-tag"; trophy-wired "rebuilt deck: exactly two prompts" |
| 4 | Medium | `SetEnabled`, `applyDisplay` | `SetEnabled(false)` hid the card and prompts, but camps stayed on the pad and the sign kept the owner's name. Joining or hand-over while off still claimed the pad. | When off, `applyDisplay` never holds or waits for a pad. `SetEnabled(false)` takes every camp down and clears the wait list, and records holders first, then the line. `SetEnabled(true)` re-shows in that order, then everyone else. Repeat calls do nothing. Layouts are never touched. | trophy "SetEnabled(false) takes camps down; true restores them in order"; trophy-wired "kill switch through the live wiring" |
| 5 | Medium | `campStatus`, `applyDisplay` | A placement the server cannot build claimed and held the pad with nothing on it, while the card said "Your trophy is on display". That covers an owned id known only to a newer server, and a trophy no longer in `TrophyRecords` at runtime. It also blocked the player's real trophy, because status was `Displayed`, not `Ready`. | `shownLayout(data)` keeps only placements whose trophy is owned and displayable. Status, pad claims and the build all use it. The saved layout keeps the hidden placements. | trophy "unknown or no-longer-owned trophies never show or hold the pad" |
| 6 | Low | prompt `Triggered` handlers | No server-side limit. A scripted `fireproximityprompt` loop rebuilt the camp and wrote the save on every trigger: 20 triggers in a frame meant 20 camp changes. | `promptLimiter` (RateLimiter: burst 2, refill 2 per second, per player, removed on leave). A real hold takes at least 0.5 s, so normal use never hits it. | trophy "spammed prompt acted at most twice" |
| 7 | Low (defensive) | `applyDisplay` | A refresh that lands after `OnPlayerRemoving` re-claimed the pad for a player who was leaving, and the pad leaked until the server restarted. Examples: a late grant through `AfterGrantApplied`, or a settlement refresh while the save is still being released. Under the current Main order the window is closed, because the reverse-order removal runs before DataService releases in the same frame. Any yield in that chain would reopen it. | A weak `departed` set is filled in `OnPlayerRemoving`. `applyDisplay` hides, and never shows, for departed or parentless players. | trophy "a late refresh after leave never claims a pad" |
| 8 | Low | `CampDisplayController` | The server's `Enabled = true` write from `SetEnabled(true)` can replicate after the status attribute that already re-rendered. Both prompts then showed until the next status change. | The client re-renders when a prompt's `Enabled` property changes. Writing the same value fires nothing, so there is no loop. | client "replicated server Enabled write re-hidden locally" |

Each listed check fails on the original source and passes with the fix. I ran the trophy spec
with the original `src/` swapped back in and the departed-guard step removed, so later steps do
not cascade from finding 7. Result: 16 failures, covering findings 1 to 6. The departed step
fails on its own, and so do 5 trophy-wired checks and the client check.

### Observations, not changed

- `World.IsProtected` uses the static `Layout.CAMP_PADS`, not the live tagged decks. The
  shipped deck sits exactly there. A deck rebuilt somewhere else, or a second tagged deck, would
  not be protected from digging until `Layout` lists it. `World/init.luau` is shared code, so
  this is not changed here.
- A camp does not follow a deck that moves without being re-tagged. Only add, remove and
  re-tag are handled.
- On load, `Rules.Migrate` keeps up to `MAX_PLACEMENTS` (32) valid placements, even though new
  placements are capped at `TROPHY_SLOTS` (3). Only a hand-edited save could exceed 3, since
  only one displayable trophy exists.
- `CampStatus` and `CampQueue` are public Player attributes. This is an existing decision, and
  they hold nothing sensitive.
- The server does not re-check the prompt's `MaxActivationDistance`. Each prompt action only
  ever edits the triggering player's own save, so a remote trigger gains nothing.

## Lifecycle states

| Event | Server | Client |
|---|---|---|
| Player added, save not loaded | No `CampStatus` attribute. `DisplayAction` and `PlaceTrophy` return `NotLoaded`. No pad claimed. | Card and prompts hidden. No ghost. |
| Load succeeds | `PlayerLoaded` → `refreshDisplay`: shows the camp if the player has a stand (or Studio preview), at least one shown placement, and a free pad. Otherwise queued, `NoPad`, `NoStand` or `Ready`. Status published. | Renders from the status. |
| Load fails (kick) | No session, no status, nothing claimed. The stored layout is untouched. | Nothing shown. |
| Death or respawn | No effect. Nothing listens to characters. | Card has `ResetOnSpawn = false`. Ghost is parented to Workspace. |
| Leave | `departed` is set. Wait-list and limiter entries are dropped. Camp model destroyed, pad freed, `handOver` runs, and everyone's status is republished. A later refresh never re-claims. | n/a |
| Rejoin, same server | New Player object. Load waits for the previous release, then follows the Load row. The pad is not taken back from a current holder; the rejoiner queues. | Fresh. |
| Rejoin, another server | Pads are not saved. The layout loads and follows the Load row. | Fresh. |
| `SetEnabled(false)` | Status `Off` for everyone. Prompts disabled. Every camp taken down. Wait list cleared and remembered (holders, then the line). Nothing claims while off. | Card, prompts and ghost hidden. |
| `SetEnabled(true)` | Prompts enabled. Remembered order re-shown first, then everyone else. Status republished. | The prompt that does not apply is re-hidden locally on the `Enabled` change. |
| `SetReviewPreview(true)` | Studio only: `RunService:IsStudio()` is checked, and a live server warns and returns false. Shows layouts without a stand. Grants nothing. | — |
| Review layout loaded in production | `NoStand`. Hidden. Saved layout kept. | "You need Mara's trophy stand first." |
| Deck destroyed | Owner's camp torn down. No stale index. Status `NoPad`, or `Queued` if other pads exist. Owner moved to the front of the line. | `Tagged` cleanup destroys the card and ghost. |
| Deck rebuilt or re-tagged | Exactly one prompt pair attached. Front of the line (the displaced owner) shown. Sign and attributes follow. | New entry. Prompts hooked when they arrive. |
| Deck untagged but kept | Prompts destroyed. Camp torn down. Deck shows free. | Entry cleaned up. |
| Deck streams out or in (client) | n/a (server-owned) | Card and ghost destroyed on stream-out. Rebuilt on stream-in. No duplicate entries. |
| Trophy missing from records, or unknown id | Never shown, never holds a pad. Saved placement kept. Status follows the remaining shown placements. | Card follows the status. |
| Server shutdown | DataService `BindToClose` saves the layout with the rest of the save. Pads are not persisted. | n/a |

## Ownership protections checklist

| Protection | Evidence |
|---|---|
| `PlaceCampItem` only edits the caller's own layout. A string id up to 64 characters is required. X and Z must be integer cells from 0 to 11, and rotation must be 0, 90, 180 or 270. NaN, ±inf, 2^40, -1, 1.5, strings, tables, nil, an empty or 65-character id, and unknown ids are all refused. | trophy-wired forged-args loop (15 shapes): nothing saved, the other player's layout and pad unchanged. trophy "bounds and request validation" |
| `RemoveCampItem` only searches the caller's own placements. Another player's placement id, NaN, inf, -1, 0, 1.5, "1", {1} and 2^53 are all refused. | trophy-wired forged-args loop. trophy "a second player cannot claim or alter the occupied pad" |
| Both remotes are rate limited (Net, 4 per second per player) and need a loaded save. | trophy-wired "remote spam limited" (40 requests, at most 8 changes) |
| A prompt acts only on the triggering player's save. | trophy "Fae's put-away never touches Lu's camp", "other players' actions never change someone else's camp" |
| Two triggers in the same frame for a free pad: the first claims it, the second is queued #1, and neither changes the other's layout. | trophy "the first trigger claims the pad" |
| Prompt spam is limited (burst 2, refill 2 per second). | trophy "spammed prompt acted at most twice" |
| An owner who leaves mid-action, then a stale trigger, gets no pad, no toast and no error. | trophy "a departed player's trigger claims nothing" |
| A pad is never taken from its holder. Hand-over is FIFO among loaded players who are still eligible. | trophy "authored camp pad" and "camp display action" sections |
| Display models are built on the server under `Workspace.TrophyCamps`. Every part is anchored, with `CanCollide` and `CanTouch` off. Clients cannot move or destroy them for anyone else, because client writes do not replicate. | trophy "display models: anchored, non-colliding", "replica part is display-only" |
| Digging is blocked under the pad at any depth, including Broadwave. `DigBroadwave` goes through `digAt`, whose `World.IsProtected` X/Z check runs before the protected-volume branch. | trophy "pad footprint protected at any depth"; trophy-wired "Broadwave dig reaching a pad footprint refused", "ordinary shovel dig there refused too", "same Broadwave dig succeeds without the pad"; smoke "dig at the camp pad refused" |
| The ghost preview is local only. It never fires a remote, and it is cleaned up on prompt hide, prompt removal, stream-out, and status changes. | client "the camp action sends nothing from the client", "removed prompt takes the preview with it", "walking away removes the preview", "stream-out cleans up card and preview" |
| The layout is saved through DataService, only for the owner, with limits enforced: 3 trophy slots, 32 placements, a 12×12 grid, 4 rotations, one display per trophy, and ids never reused. | trophy "camp placement" section |
| A corrupt saved layout is sanitized on load. Trophies, stand and other data (Coins) are kept, `NextId` is repaired, unknown fields are dropped, and the result is saved back. | trophy "corrupt layout sanitized to the one valid placement", "sanitized layout saved, rest intact" |
| A layout saved during Studio review does not show on a live server. | trophy "Studio review layout cannot show on a live server" |

## Files and functions changed

- `src/server/Services/TrophyCampDisplay.luau`: `padList(gone?)`, `Display.Show` (same-part
  check), new `Display.Reconcile`.
- `src/server/Services/TrophyService.luau`, camp code only:
  - new `shownLayout`;
  - `applyDisplay` (departed, disabled and shown-layout rules);
  - `campStatus` (shown layout);
  - `SetEnabled` (takedown and ordered restore);
  - `ConnectCampPrompts` (rate limit, `detach`, connect once);
  - new `onPadsChanged`, wired in `Init`;
  - `OnPlayerRemoving` (departed, limiter, resume order);
  - new locals `promptLimiter`, `departed`, `resumeOrder` and `promptsConnected`.
- `src/server/World/CampPad.luau`: `buildPad` sign reads the current owner.
- `src/client/Controllers/CampDisplayController.luau`: `watchDeck` hook re-renders on a
  prompt's `Enabled` change.
- Tests:
  - `tests/trophy.spec.luau`: new section "camp lifecycle and ownership protections" (+76 checks).
  - `tests/trophy-wired.spec.luau`: forged remotes, remote spam, pad rebuild and kill switch through Main, Broadwave protection, shutdown save (+25 checks).
  - `tests/client.spec.luau`: Enabled race and prompt removal with the ghost up (+4 checks).
- Docs: this file. Also `SetEnabled` wording in `docs/TROPHY_INTEGRATION.md` and
  `camp-display-action.md`, and the handoff table in `README.md`.

## Evidence (headless mock, 9 Oct 2026)

| Spec | Before | After |
|---|---|---|
| trophy | 400 | 476 |
| trophy-wired | 35 | 60 |
| client | 1500 | 1504 (plus 7 tutorial scenarios unchanged) |
| adventure-settlement | 275 | 275 |
| smoke (live / Studio) | 2212 / 2179 | 2212 / 2179 |
| production-wiring off / on / rejoin / client | 36 / 38 / 13 / 20 | same |
| adventure-outcome, util, persistence-boot (live and Studio) | 23, 8, pass | same |
| adventure-trophy-contract, spring-vault, broadwave-dig (Codex) | 24, 22, 23 | same |

StyLua is clean on every changed source file and on the two trophy specs. `tests/client.spec.luau`
has one StyLua difference that was already there before this branch (the `ExcavationStart` call
near line 3535). It was left alone. Strict `luau-lsp analyze` is clean on the four changed
source files.

## Needs a Studio or multi-client check later

- Destroy and rebuild the deck in a live server. Check that the camp reappears on the new deck,
  the sign shows the owner, and each client sees exactly one prompt pair.
- Kill switch in a live session: camps disappear and come back in order, and each client's
  prompts settle on the right one after the `Enabled` replication (finding 8).
- Two real clients holding the display prompt at the same moment. Also an exploit-style
  `fireproximityprompt` loop against the rate limit.
- A player leaving while their camp is up, with someone queued: the hand-over toast, the card
  and the sign on the other client.
- StreamingEnabled with the pad at the edge of the radius: the card and ghost go and come back
  with no duplicate prompt hooks.
- Visual checks still open from `camp-display-action.md`: ghost transparency, card size and
  placement, prompt placement.
