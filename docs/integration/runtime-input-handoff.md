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

## Exact remaining acceptance and launch gates

- The local `claude/spring-vault-production-candidate` branch currently resolves to
  `d96ac75`; it contains no separate fail-closed storage provisioning. Existing
  `ProductionReview.ReviewBoot` calls `GetDataStore(...):GetAsync("__probe")` before
  allowing memory fallback. Do not run that boot as safe production acceptance.
- Claude must provide an authorized Expansion1Review PlaceId-0 candidate with explicit
  server candidate flags, actual production lifecycle and storage isolation before any
  store acquisition/request, including player saves, reward/trophy outboxes, purchase
  history and leaderboards. Normal shipped flags remain false.
- Earn entry eligibility through ordinary production sale/deposit gameplay and Pip trial
  eligibility through an actual purchased shovel. No seeded records, bypasses, installed
  resolver or direct remote requests count as input acceptance.
- Safely provisioned final merged source still needs ordinary UI verification of two
  consecutive adventures, Pip exit, shared equip/stow, exact original-tool restoration,
  Leave/automatic return and individual results. Label injected input and assisted
  movement explicitly. Isolated-memory rewards cannot establish durable live saves.
- Permanent Broadwave license grant ownership/path, lossy sale/deposit catch-up evidence,
  kill-switch trigger, rewards scope, trial-only entry policy, end-of-run return policy and
  arena presence for stage pay remain owner decisions unless separately resolved.
- Production preference integration and panel behavior with a licensed tool on the beach
  still need Claude/Codex coordination. Initial licensed-tool startup adoption and legitimate
  license acquisition must be verified against the final controller; previous handoff
  findings should not be assumed current without inspecting its source.
- Physical devices, uncoached discovery, real streaming/populated performance, same-account
  rejoin and live cross-server durability remain separate launch gates. Existing accepted
  aiming/two-client recovery evidence can be reused unless affected by these changes.

No production Studio changes, publication, upload, live save tests or merge are authorized
by this handoff.
