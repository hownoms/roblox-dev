# Gameplay and presentation review — 9 October 2026

Started from fetched default `9cd1ebd`, merged PR #31, in separate worktree/branch
`codex/spring-vault-gameplay-polish`. Only Expansion1Review and its child local test
server/clients were used. DigTheBeach was untouched. No assets uploaded, no game published.
Review returned to Edit with default viewport. Rewards/camp remain Claude's ownership.

## Automated evidence

- 22 progression/movement tests pass, including held rejoin after admission lock, expired
  holds, preserved work/cooldowns, 100 state lifecycles, sparse replicated movement,
  idle attachment, invalid/teleport movement and bounded movement banks.
- 23 real-DigService mock integration checks pass: ordinary-equivalent scoop, shared
  cooldown/reach/hardness/zone/capacity validation, server license veto, protected tagged
  and attribute geometry/model descendants, unchanged protected voxels and rejected-attempt
  retry. Existing possessions/coins and unrelated save data are preserved.
- 24 real-completion-context-to-TrophyService mock checks and 259 trophy checks pass.
- Baseline server smoke: 2,199 live-mode / 2,166 Studio-mode checks pass. Client smoke:
  1,464 checks pass. Utility 8 checks and persistence acquisition boot live/Studio pass.
  These use the headless API-aware mock, not live DataStores or real devices.
- Mapped strict analysis of modified adventure/review files and DigService/bridge passes.
  Changed Luau formatting and diff-whitespace checks pass. Dedicated and production Rojo
  builds pass. Whole-checkout formatting still has pre-existing Windows line-ending
  differences; this is not a blanket whole-repository formatting claim.

## Assisted actual local multiplayer observations

Used StudioTestService local server with two separate networked client DataModels, Players
`Player1` (-1) and `Player2` (-2). Both had actual NetworkClients. Client code sent requests
through Intent RemoteEvent; the review-only trace recorded OnServerEvent delivery. Server
teleports positioned avatars near objectives; Humanoid MoveTo drove hauling. This verifies
local network replication and server acceptance, not human discovery, pacing or real accounts.

- Twenty instant requests delivered from a client produced only one anchor work unit.
- Starter cleared the first anchor; late helper joined/Ready during Active. Solo-frozen
  anchor requirement remained 6. Starter/helper cleared the remaining anchors separately.
- First run exposed a replication bug: ball movement was counted only on Heartbeats with
  position updates, so the cargo lagged and detached movers. Fixed with bounded validated
  forward-distance banks consumed over Heartbeats. Idle attachment supplies no movement.
- Repeated full two-client route after the fix validated gates 1, 2, 3 and completed.
  Starter earned 40.015 points/81.728 active seconds; late helper 24.985 points/41.781
  seconds. Both Eligible=true. Temporary review adapter granted no permanent rewards.
- Repeated reset requests over 3.5 seconds recovered the ball to its validated start
  checkpoint, preserving work/points, detaching cargo and restoring both speeds to 16.
  This occurred before gate 1; prior PR31 evidence separately covered a gate-1 checkpoint.
- Completion cleanup returned Dormant, removed the ball and loans, and restored speed16.
- Actual LeaveTest disconnected Player2. AddPlayers created Player3 (-3), a new identity;
  this is not evidence of same-account rejoin. A second attempt had Player3 contribute one
  anchor unit then disconnect: server retained Work1/Required8, marked Connected=false,
  Present=false, Attached=false, and kept the other client active.
- Basic temporary R6 dummy Broadwave equip created RightGrip; existing R15 player avatar
  was retained. Dummy/tool removed. This is not custom-avatar moving two-hand contact QA.

Raw observations: `GAMEPLAY_POLISH_TRACE.json`. The probe can address an actual UserId and
record network requests without impersonating synthetic players or granting rewards.

## Presentation and Studio emulator observations

- Ball retains7.6-stud query/contact sphere; colored caps are native local primitives with
  wider cream gutters and no extra polar spheres. Saved Studio closeup:
  `studio-ball-local-gutters.png`. Inter-panel overlap is reduced; primitive intersection
  edges remain visibly faceted in closeups. This is improved review geometry, not a claim
  of smooth authored spherical sectors or final marketing art.
- Actual UI clicks set Motion:low and Puffs:off. Injected wave/bounce groups left no
  transient groups after0.6 seconds. Low-motion waves no longer translate; switching
  motion restores squash. Scene replacement/destruction clears charge/effects/prompts.
  Gate feedback is independent of puff settings. No camera shake or audio was added.
- Samsung Galaxy A06 landscape emulator produced a705×338 viewport. Review card was
 330×256 with330-pixel scroll canvas; buttons remained98×48. Scrolling74 pixels made
  Reset ball accessible. Emulated touch controls overlapped the left-side card, so final
  layout centers the card between movement/jump zones on touch devices. Final centered
  placement was observed at(187.5,12), with48-pixel buttons; screenshot saved as
  `studio-touch-scroll-card.png`. Physical touch comfort remains unverified. Scrolling replaces
  proportional shrink so small viewports retain48-pixel interaction targets.
- Keyboard/controller/touch bindings are present; actual gameplay actions in the
  multiplayer run were assisted client requests. No physical controller or phone was
  available. Injected Q short hold delivered ChargeBegin/Release without trial progress.
  A later0.866-second injected Q hold also delivered both requests but did not validate
  the trial patch in that assisted setup; accepted keyboard trial aiming remains open.
  Injected ButtonL1 returned tool success but produced no network charge requests, so
  controller operation is explicitly unverified. Do not count injected keys, simulator
  layout or source review as hardware QA.

## Joint integration and outstanding acceptance gates

Production explicitly supplies BroadwaveDigBridge with a server license callback and
DigService.DigBroadwave. Review omits it and loads no production services/saves. One release
can accept target work or one ordinary scoop, never both. Actual licensed tool equip,
production prerequisites/flags/input arbitration and protected region placement remain
shared integration changes documented in INTEGRATION.md, not applied in boot/catalogs.

Claude owns durable stage/final rewards, reconciliation, cert_crew, trophy storage and
one camp pad/display UI. Live cross-server settlement, shutdown recovery and truthful
individual results remain his integration gates. Same-account network rejoin, actual
controller/phone interaction, custom avatar strike contact, streaming, populated performance,
100 full runtime activity cleanup cycles and uncoached newcomer pacing remain open.

Keep the PR unmerged until gameplay and Claude's production changes are reviewed together.

## Latest-default combination

Before delivery, default advanced to`a4167d9` with Claude's settlement bridge and camp pad.
Merged that default into this review branch; DigService combined without conflict and retains
Claude's World.IsProtected footprint refusal as well as the Broadwave carve-volume guard.
No reward/camp code was authored or changed by Codex in that merge.

Combined checks:23 Broadwave,24 trophy-contract,153 adventure-settlement and312 trophy
checks pass; refreshed server smoke2212 live/2179 Studio and production/review builds pass.
Full-source analysis retains only the two existing deprecated API warnings.
The optional`trophy-wired.spec` was invoked
and refused execution because its production integration patch is deliberately unapplied.
That is an outstanding joint boot-wiring gate, not a passing wired-production test.
