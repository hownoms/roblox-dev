# Runtime input and completion ownership handoff

## Current continuation: accessibility and actual merged runtime (10 October 2026)

Branch `codex/spring-vault-accessibility` starts from fetched default `b4e1b14`.
This section supersedes earlier open preference/layout and two-client runtime findings;
the historical contracts below remain reference material. No other chat was messaged.

SpringVaultClient now consumes production `Controllers.State` settings on creation and
on `Changed("Settings")`: ReducedMotion disables decorative movement and puffs;
LowGraphics disables puffs. Active effects are retired immediately and panels restored.
Standalone review still works without State; optional initial preferences and the handle's
SetPreferences support explicit callers. Arena Options remain session overrides; the next
production settings change reapplies saved preferences. No controller/boot files changed.

The arena ScreenGui uses layer 3, above GuideEdge's 2 and below production panels/popups
5/8. Leave/End trial is pinned to the header during scrolling, with reserved header width
and a 48px target. Other controls retain their stable cells. Actual simulated landscape
609x337 and 749x388 layouts were inspected; hauling Leave at 609x337 succeeded after
scrolling and restored the same Garden Trowel object, speed 16, and removed the loan.
At the extreme 225x179 viewport, End trial remained 55x48 and visible, but the first
injected click did not cancel; cancellation succeeded after resetting the viewport. Do not
claim that extreme layout's input acceptance or physical touch/gamepad acceptance closed.

The safe LocalOnly production candidate ran in confirmed unpublished Expansion1Review
and two child clients. Both earned entry and Pip licenses by ordinary digging, selling,
buying and trial controls. Three consecutive adventures completed in one server: solo
with a never-joined bystander; a late unready helper timed out; and a ready late helper
contributed 45 points while the original participant contributed 20. Neutral completion
delivery was participant-only. Automatic return restored both original tools/loan state;
a fourth run tested hauling cancellation and recovery. Input was injected through ordinary
UI/keyboard controls; movement and camera were assisted. No seeds, prerequisite bypasses,
resolver shims or direct remote input were used. Accepted unchanged aiming/recovery evidence
is retained rather than rerun as new physical-device evidence.

**Remaining Claude dependency:** actual local multiplayer settlement rejects Studio IDs
-1/-2 as BadParticipants (AdventureRewards validates positive IDs, as do trophy rules).
Consequently no reward outcome cards/grants were observed. Runtime forwards real IDs and
production validation remains intact. Coordinate a strict LocalOnly simulated-ID policy or
an authorized account-backed multiplayer environment before final reward-card acceptance.
See `assets/adventure/verification/accessibility/independent-two-client-settlement-dependency.md`.
The 11 old settlement test wording/recipient mismatches were reverified; the full suite is
not green. Claude-owned source/tests were left unchanged.

Evidence and exact gates: `assets/adventure/verification/accessibility/CONTINUATION.md`.
Targeted regressions, production/review/candidate builds and mapped adventure analysis pass.
Studio candidate was uninstalled, original parked roots/service properties restored, child
test windows closed, viewport reset to default, and local injector stopped. No place save,
publication, upload or merge occurred. Physical devices, uncoached play, performance,
streaming/rejoin/live durability and merged reward delivery remain release gates.

10 October 2026; Codex branch `codex/spring-vault-input-parity`, based on fetched default
`d96ac75`. Coordination is through this reviewable ownership boundary document. No other
chat was messaged. Codex owns runtime/input/presentation; Claude retains boot/controller,
entry, rewards, storage and catalogs. Claude-owned source and tests were not modified.

## Completion contract and merged-suite expectations

The runtime now consumes `OutcomeOwner = "External"`. A supplied `OnCompletion` callback
also selects external presentation, covering production with AdventureRewards disabled
(its boot supplies a refusal callback without the explicit option). External mode removes
the dedicated-review no-reward objective. Completion feedback is the neutral `Ball rescued.`;
per-player `AdventureOutcome` cards remain settlement-owned. A callback exception retains
`Completion handoff failed; no rewards confirmed.`. Generic callback text is deliberately
not presented as an individual's result.

Completion messages target connected players whose UserIds occur in the captured completion
context. Non-contributing participants still receive neutral feedback and their own refusal
outcomes. Never-joined bystanders receive ordinary world snapshots but no participant
completion message. Disconnected participants remain in the immutable settlement context;
this change does not alter eligibility, grants, receipts, persistence or reconciliation.

`assets/adventure/verification/input-parity/merged-suite.log` records 11 failures in
`settlement-durability.spec.luau`: 198 checks pass. All 11 failures are obsolete runtime
wording/recipient expectations. The substantive grant/outcome/durability assertions pass.
This is an integration-contract mismatch, not evidence that the full suite passes.

Requested Claude-owned test changes, for explicit owner review:

- Lines 477–485: replace the callback-message equality and all-player completion broadcast
  assumption. Ana, Ben and Cal should receive `Ball rescued.` without reward claims;
  Eli (never joined) should have no completion message. Preserve the existing assertions that
  Ben gets refused outcome cards and Eli gets no outcome cards. These produce five current
  failures: four text equalities and Eli's absent-message assertion.
- Lines 732–740: replace the rewards-disabled refusal-message broadcast expectation for
  every connected player. Gus, the only participant in this run, receives `Ball rescued.`;
  Ana, Ben, Eli, Cal and Fin receive no completion message. Keep all assertions that no
  settlement runs, no outcome cards exist, and coins/trophy/certification are not granted.
  These produce six current failures.
- Line 693's `Boot.Options(Flags).OutcomeOwner == nil` still passes and accurately checks
  current boot configuration. Its explanation should stop asserting that production keeps
  review copy: runtime now infers external ownership from the supplied refusal callback.
- Update the introductory all-player broadcast description and the descriptive rewards-off
  section heading. The production rewards-off run is not the dedicated review adapter.
  Upgrade the existing diagnostic review-copy scan to assert that production has no
  `REVIEW ONLY` contradiction, while retaining dedicated-review checks separately.

New Codex-owned `spring-vault-outcome-owner.spec.luau` passes 85 checks against actual
runtime source in API-aware headless mocks. It covers successful/refused callbacks,
implicit ownership, callback exceptions, eligible/non-contributing/bystander delivery,
dedicated-review labels and single handoff delivery. Completion state is driven explicitly;
this is neither gameplay input acceptance nor durability evidence. Before/after logs are
in the same evidence folder.

## Presentation compatibility

The visible production title is neutral `SPRING VAULT`. Dedicated adapter snapshots label
the title `SPRING VAULT · Dedicated review`. The panel is named `Panel`. The ScreenGui retains
`SpringVaultAdventureReview` as an internal compatibility identifier: Claude-owned
`AdventureHUD.RUNTIME_GUI` and equip discovery depend on it. Renaming that identifier
requires coordinated adapter changes and is not necessary to remove player-facing claims.
The production-review isolated-memory banner remains untouched and truthful.

## Final merged candidate evidence and resolved gates

Default advanced to `2d4f0cc` and was merged into this branch. Frozen source `ed5dba7`
was installed into the confirmed Expansion1Review candidate. The earlier statement that
safe provisioning, controller adoption and license acquisition were absent is superseded:
CandidateProfile/StorageGate now select fail-closed LocalOnly before service initialization;
AdventureController adopts runtime startup before arena replication; PipQuest legitimately
grants the Broadwave license from authoritative trial state. Independent candidate storage,
PipQuest and client-stream regressions pass. No Claude-owned implementation was edited.

Saved evidence under `assets/adventure/verification/merged-candidate/` records a normal
fresh profile, earned sale/deposit eligibility and purchased Garden Trowel. Parent-agent
Studio verification used injected keyboard/mouse input through ordinary client controls
and assisted Humanoid navigation; it did not seed eligibility, bypass prerequisites,
install a resolver or fire input remotes directly. This is one-client assisted acceptance,
not physical hardware input or uncoached play.

- `trial-complete.json` and `trial-exit-and-shared-stow.json`: Pip trial/license, exit,
  shared equip/stow and restoration of the exact original Garden Trowel instance.
- `run1-completion-and-return.json` and `run2-auto-return.json`: two consecutive completed
  adventures on the rebuilt scene, clears increasing from 1 to 2, coins 71 to 131, individual
  settlement receipts, automatic surface return, WalkSpeed 16, original Garden Trowel
  equipped and licensed Broadwave stowed. The second adventure verifies latch/route recovery
  through actual prompt input; delayed server prompt replication is separately mock-regressed.
- `hauling-before-leave.json` and `hauling-after-leave.json`: Leave during third-run active
  hauling returns to the surface, restores WalkSpeed 16 and the exact original Garden Trowel.
- These snapshots report Mode/StorageMode LocalOnly, PlaceId/GameId 0 and empty acquired
  and refused storage counters throughout. Rewards and license records are isolated-memory
  simulation; they do not establish live durability.

Independent final targeted source/merged integration checks pass; logs are
`independent-targeted.log`, `independent-build-analysis.log` and
`independent-build-retry.log` in the same evidence folder. The first local build attempt
was denied by the sandbox; the authorized retry created a fresh sourcemap and successfully
built production, dedicated review and candidate projects. Mapped adventure analysis and
changed-source formatting pass. The known 11 obsolete Claude-owned completion expectations
remain explicitly unmodified as documented above; the full suite is not green.

## Exact remaining launch gates

- Claude-owned settlement-durability test expectations need the coordinated updates above.
  Actual settlement/per-player outcomes continue to pass targeted checks; mock coverage
  does not substitute for a two-client final-merged production journey.
- Production preference integration, the tutorial guide arrow overlapping the arena panel,
  physical phone/controller controls and short-screen layout remain presentation gates.
  The licensed-beach panel finding is fixed and covered by actual-source regressions.
- Initial stream-in and stream-out are mock-covered with the final controller; real streaming
  radii, populated performance, same-account rejoin and uncoached discovery remain open.
- Permanent first-sale/deposit evidence (catch-up accepts accidental deposit discovery),
  kill-switch trigger, rewards-flag scope, trial-only hatch entry, and whether End trial should
  return to the beach remain owner decisions. The q_pip license grant now exists; its separate
  proposed 150-coin quest reward is not implemented. Candidate outcome cards still call
  memory results Saved, with the explicit local-simulation banner retained.
- Live and cross-server durability remain open and require a separately authorized plan;
  no live save access was used here. Existing accepted aiming/two-client recovery evidence
  remains reusable where unaffected, but does not close the final production two-client gate.

No production Studio changes, publication, upload, live save tests or merge are authorized
by this handoff.
