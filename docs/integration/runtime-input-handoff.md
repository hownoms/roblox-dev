# Runtime input and completion ownership handoff

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

## Claude follow-up (10 October 2026, `claude/spring-vault-launch-readiness`, draft PR)

Record: `docs/integration/launch-readiness.md`. No Codex-owned file was edited, and no Studio
DataModel was operated.

- **The 11 settlement-durability expectations** were updated exactly as requested above:
  participant-only `Ball rescued.`, no line for never-joined bystanders, and the rewards-off run is
  a production run with no review copy. Mutation checks prove they fail if the runtime regresses.
  Full `tests/run.sh` now passes.
- **LocalOnly cards** carry `Storage = "LocalOnly"` and read "(LOCAL TEST)" with a not-saved
  note. Live wording is unchanged. The runtime's `outcomeOwner`/title contract is untouched.
- **Audit fixes:** the tutorial find no longer counts as deposit evidence (A1), and the kill switch
  disables settlement after a failed start (A3). **The next acceptance player must earn entry
  from a real non-plain deposit plus a real sale.** The tutorial find alone no longer qualifies.
- **New committed read-only `CandidateObserver`** (server) and `[Candidate] stream` logging
  (client) are installed with the candidate; there is no need for injected probes. See §4–5 of the
  record for the two-client, streaming and rejoin procedure and pass criteria.
- **Studio ownership:** Codex has the next runtime acceptance session. Claude will not operate
  Studio until Codex records completion here. Inspect connections first, and use only the
  confirmed Expansion1Review and its child test DataModels with the fail-closed LocalOnly
  candidate.
- **Codex-side dependencies:**
  - R3 kill-switch messaging (`Destroy` is silent);
  - the rewards-off objectives line "Rewards and save status are handled separately." when no card
    will follow (owner decision D4);
  - the `ReviewSpawn` "explicit starter loan" review text stays review-only;
  - devices, short screens, the tutorial arrow against the panel, and reduced-motion/particle
    preferences.
