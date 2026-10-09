# Spring Vault adventure integration handoff

Prepared 9 October 2026. Adventure branch: `codex/spring-vault-adventure`.
Started from fetched default `afbb8a0` in a separate worktree. Trophy boundary reviewed against
Claude's completed default `d9ad846`. Production boot, existing catalogs, digging, avatars,
save fields and possessions are not changed by this adventure branch.

## Review and scope

Build `adventure.project.json` into `build/SpringVaultAdventureReview.rbxlx`, open locally,
then Play. It loads no production services or DataStores. Mara and Pip have explicit review
prerequisite loans; those are not certifications or owned shovels. Join near Mara, wait five
seconds, Start, then Ready. All three shaped anchors can be cleared with ordinary interactions
(no ability required). Open the latch, choose Left/Right before moving, attach to the ball and
walk down the channel through three gates. Leave is always available; retry is free.

Pip lends Broadwave. Equip the loan, face the marked patch, hold Q / L1 / the 64px touch control
for 0.8 seconds and release. Then scoop the three practice targets. The trial and event work
are server validated. The review does not fake a first-shovel purchase or persist q_pip.

The new modules use existing factory, rate-limiter, module lifecycle and strict Luau conventions.
The adventure has a separate remote namespace (`ReplicatedStorage.SpringVaultAdventure`:
Intent/Snapshot/Effect). No shipped binding or global remote catalog is replaced.
Only whitelisted targets accept work. No Terrain mutation, sand payout, damage, knockback,
physics ownership, dropped possession, avatar replacement or persistent inventory write occurs.

## Authority and presentation

`SpringVaultState` owns membership, readiness, frozen 6-solo/8-crew anchor work, cooldowns,
objective sequence, contribution, late admission locks, duration, abandonment and completion.
`SpringVaultService` validates live player identity/root, target IDs, range, phase, equipped loan,
charge lifetime, release direction, filled work and movement. Ball movement is bounded and
kinematic; only validated moving haulers earn checkpoint credit. Hauling temporarily uses
10/12 WalkSpeed and restores the previous speed on detach/leave/cleanup. The fixed 7.6-stud
contact sphere is noncolliding so it cannot pin or shove another avatar. Decorative panels
remain outside authority. Reset waits three seconds and restores the last validated checkpoint
and its next waypoint without granting a gate. Player fall recovery waits two seconds.

Client effects have 80-stud culling, at most two wave groups and one puff group, 0.35-second
waves and 0.25-second puffs. Charge cancellation/unequip/death clears dots. Reduced motion
uses low waves/four puffs and no decorative squash; particle reduction omits puffs. No camera
shake or audio dependency. Effects never cause progress. Ignoring the invite hides the card;
talking to an NPC can reopen it. Nonparticipants receive no active objective card.

## Small completion boundary

Call `SpringVaultService.Start({Origin, CanEnter, CanTrial, OnStage?, OnCompletion?})` explicitly.
Admission callbacks must use server-owned loaded save/certification evidence; absent callbacks
refuse entry/trials. Review boot is the only place that bypasses prerequisites.

`OnCompletion(context) -> (accepted:boolean, message:string)` receives a deeply frozen context:

- BoundaryVersion=1; ContentVersion=1; EventInstanceId=`serverGUID:sequence`;
  EventId=`event_vault`; LandmarkId=`landmark_spring_vault`; RegionId=`sunshine_shore`.
- Success=true; ordered ObjectiveIds and CompletedStages (`excavation`, `vault_open`, `ball_return`).
- StartedAt/CompletedAt are server-monotonic seconds; CompletedAtUnix is the observed UTC time.
- Participants contain UserId, Points, ActiveSeconds, ObjectiveIds and Eligible.
  Disconnected/departed/absent players are ineligible for the final trophy. Presence alone earns
  zero points. Actual work is shared; a meaningful late helper can qualify.

`OnStage(context)` receives the same attempt/content identifiers, StageId, completed objectives
and cumulative per-user contribution/witness facts once per major stage. It is an observation
boundary, not a grant. The reward owner must derive and persist each stage intent. Callback
failures are isolated; the runtime does not claim or implement durable retries. OnFailure receives a frozen failure snapshot before cleanup; failure snapshots
are retained server-side for review, not persisted progress. A production reward adapter must
prepare durable intents before acknowledging accepted settlement; handoff errors remain visible.

Claude's reviewed `TrophyService.OnCompletion` is the drop-in final callback. Its
`SettleCompletionContext` mapping recognizes these fields and honors Eligible as an additional
veto. It owns trophy/stand receipts and durable pending intents. This branch does not require,
boot, edit or call it in the review scene. The temporary review adapter captures at most 20
contexts in memory, returns false/ReviewOnly and NEVER awards coins, stand, certifications or
trophies. Resolving shows the adventure ending; it does not assert Rewarded or fake persistence.

## Production wiring proposed, deliberately not applied

1. Review `docs/trophy-integration.patch` with this boundary. Wire TrophyService's lifecycle
   and camp remotes only through that separately reviewed integration; no hidden boot edits here.
2. Under server-owned, default-off MiniVault/ToolAbilities flags, explicitly start this runtime
   with a protected pocket 8-12 studs below the beach, outside ordinary dig bounds, and production eligibility callbacks.
   Use authoritative first sale + scanner deposit / cert_rookie evidence; returning players get
   optional catch-up. CanTrial must check q_pip's first ordinary shovel purchase. Do not infer
   story completion from money/depth or write persistent flags in this adventure.
3. Start the client module through existing controller/UI arbitration, suppress normal digging
   during dialogue/hauling and resolve actual Q/L1/E conflicts. Review controls are not a blanket
   replacement for production HUD. Read reduced-motion/particle preferences from Settings.
4. Ordinary Broadwave carving needs a reviewed RegionContext/DigService extension: authoritative
   filled voxels, bounds, protected geometry, hardness, capacity and ordinary-equivalent yield.
   This slice supports normalized event/practice targets only and never writes Terrain directly.
5. Reward owner supplies durable fixed coin/stage settlement and cert_crew. Intro base is 60
   coins; stage amounts are 10% each capped30%, reconciled final base; no paid/pet/prestige boost.
   q_pip's once-only150 and permanent Broadwave license are separate quest grants, not implied by
   the review loan. Do not add tool_broadwave to the legacy shovel ownership catalog implicitly.
6. Camp owner places a protected pad and exposes a small display action/preview. Production
   display requires the stand; first eligible trophy settlement grants stand+trophy together.
   No-pad behavior remains truthful. No camp UI or 16-pad map change is included here.
7. Append a distinct adventure analytics funnel; preserve existing onboarding step numbers.
   Confirm admission/watchdog/kill-switch safe return, streaming and populated performance before
   enablement. No upload, publication, access change or live save test is authorized here.

Trophy code owns/prunes only `trophy:` RewardReceipts keys. New coin reward code must own a
separate namespace and never prune unrelated or active intents. A grant already accepted must
survive shutdown/another server; same-server-only recovery is not release-ready.

## Claude's next work (after the completed trophy slice)

Build the durable adventure reward bridge: consume OnStage + frozen completion context, grant
fixed stage/final coins and cert_crew exactly once, reconcile stage receipts, preserve existing
inventory and entitlements, and show per-player accepted/refused/pending results. Reuse the
completed TrophyService.OnCompletion for stand+trophy; do not duplicate its grants. Add one
protected camp display pad through the reviewed production wiring, then verify a two-client late
helper run, retry/leave/disconnect and real cross-server save recovery. Coordinate shared boot,
remote and UI edits in one integration PR. Treasure/legacy trophies, broad furniture, full camp
UI and sixteen pads remain later scope.

## Evidence and gates

## Gameplay and presentation continuation (9 October 2026)

Branch `codex/spring-vault-gameplay-polish` starts at merged PR #31 (`9cd1ebd`).
Reward persistence, settlement, trophy storage, camp UI and their shared boot wiring remain
Claude's ownership. No boot file or configuration catalog is edited by this continuation.

Ordinary Broadwave now has an explicit server adapter. In the jointly reviewed production
integration, construct `BroadwaveDigBridge.Create({CanUse = authoritativeLicenseCheck,
Dig = DigService.DigBroadwave})` and supply it as `OnOrdinaryBroadwave` to `Service.Start`.
`CanUse` must read loaded server-owned permanent license/prerequisite and enablement evidence;
an adventure loan or client tool name never establishes ownership. The runtime supplies the
server-observed charge duration and character-facing frame. The callback is attempted only
when no event/practice target accepted work, so one release cannot award both work and sand.
Review boot deliberately supplies no ordinary adapter and loads no production saves/services.

`DigBroadwave` performs one ordinary shovel-equivalent scoop using equipped shovel stats and
the existing DigService cooldown, zone, reach, hardness, filled terrain, capacity, yield and
bookkeeping. It checks the full actual carve bounds before mutation, including the upper
surface voxel/dent sphere, against tagged or attribute-marked protected geometry and model
descendants. Its conservative intersection test can refuse scoops near protected corners.
It does not multiply sand across the visual corridor or add a new ownership/save ID.
Production equip and input arbitration still require the joint integration, not a hidden boot
change in this PR. The new callback does not implement rewards or settlement.

Returning held participants can rejoin within 90 seconds after admission locks, preserving
contribution and cooldowns without automatic cargo attachment. Repeated ball reset requests
cannot postpone recovery; reset releases speed overrides and cargo. Leave remains available
while absent/dead. Speed restoration targets the original Humanoid; respawn renews the loan.

Ball presentation uses local primitive caps separated by wider cream gutters; the contact
sphere remains 7.6 studs. Client reduced-motion waves stay stationary, and switching to low
motion immediately restores squash. Scene replacement clears transient effects and charges.
Gate confirmation is independent of particle settings. Review controls scale for short viewports.

New evidence and remaining device/multiplayer limits are recorded in
`verification/GAMEPLAY_POLISH.md` and `verification/GAMEPLAY_POLISH_TRACE.json`.
Latest default`a4167d9` (Claude's settlement bridge and protected camp pad) was incorporated
into this branch before delivery. Its World.IsProtected footprint guard remains in DigService
alongside the Broadwave-specific volume guard. Joint mock settlement/contract checks pass;
production boot patch, actual callback injection and live durability remain integration gates.

See `verification/VALIDATION.md`, `STUDIO_TRACE.json`, and the saved before/after ball captures.
Automated and assisted Studio checks do not establish real phone/controller use, real multiplayer,
live durability, uncoached onboarding, audio audition or full populated performance. Those remain
release gates. Ordinary digging and existing save tests pass independently. Nothing is published.
