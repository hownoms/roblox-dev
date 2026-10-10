# Spring Vault two-client reward acceptance: local simulation policy

Branch `claude/spring-vault-two-client`, 10 October 2026. It is launch readiness (`af0ed43`)
merged with default `b3ef585` (Codex PR #42). The merge is `f488b16`, plus this policy. No
Studio session, publication, upload, live save or flag change. Every `AdventureFlags` flag
still ships `false`. No Codex-owned file was edited.

## 1. Historical findings checked before reopening

| Finding (source) | Checked on the merge | State |
|---|---|---|
| 11 settlement-durability expectations fail; full suite not green (`CONTINUATION.md`, `runtime-input-handoff.md`) | `af0ed43` already updated them, and they agree with PR #42's runtime. `SETTLEMENT DURABILITY (on): 218 passed`, `(off): 76 passed`, full suite `ALL TESTS PASSED` (`evidence/two-client/full-suite.log`) | **Closed**, not reopened |
| Codex specs after the merge | spring-vault 22, runtime 52, return 111, input 295, initial-stream 29, scene 81, presentation 103, outcome-owner 85, preferences 21, trophy-contract 24, broadwave-dig 24, all passing (`evidence/two-client/codex-specs.log`) | Green |
| Studio players -1/-2 rejected as `BadParticipants` (`independent-two-client-settlement-dependency.md`) | Reproduced in the mock: `AdventureRewards.validateContext` and `Trophies.Rules.IsParticipant` both require `UserId` in [1, 2^53] | **Fixed** by §2, only for LocalOnly Studio |

## 2. Integration contract: `LocalSimulationPolicy`

`src/server/Services/LocalSimulationPolicy.luau` (server only).

**Guard.** It is checked on every settlement call, and all three conditions must hold:
1. `RunService:IsStudio()`
2. `CandidateProfile.IsLocalOnly()`
3. `DataService.StorageMode() == "LocalOnly"`. The `Mock` Studio fallback and `DataStore` both fail this.

**Accepted ids.** Both conditions must hold:
- an integer in `[-64, -1]` (`Trophies.Rules.LOCAL_SIM_MIN_USER_ID`);
- a `Player` with that UserId joined **this** server. That means it is here now, or it was recorded on `PlayerAdded` and later left.

**64-client limit.** One Studio test server hands out new negative ids as clients are added. After
64 clients, a new client's id is outside the window, and any adventure that player is in fails
closed as `BadParticipants` for everyone. Start a fresh Play session well before that.

**Wiring.**
- `AdventureSettlement.SettleStage` and `SettleCompletion` call `Predicate()` once. They pass the same function to `Rewards.StageDecisions` / `FinalDecisions` (`options.AcceptLocalUserId`) and to `TrophyService.PrepareCompletionContext`.
- The shared modules hold no switch. With no predicate (production, `Mock`, and TrophyService's standalone `OnCompletion` / `SettleCompletionContext`), the rule is exactly the old one.

**What is unchanged.** Only the UserId range check is widened. All of these apply unchanged:
- points;
- objectives;
- `ActiveSeconds`;
- the runtime's `Eligible` / `Connected` / `Left` facts;
- the trophy contribution rule;
- receipts and duplicate replay.

There is no id remapping, no seeding, no resolver and no prerequisite bypass. Entry still needs real `CanEnter` evidence, which after A1 means a non-plain deposit plus a real sale.

**Never durable.** Simulated ids never enter either outbox:
- An eligible simulated id that is not loaded is `Refused / LocalSimulationNotLoaded`, not `PendingRejoin`.
- A failed save write for a loaded simulated id becomes `Unconfirmed`, never `Queued`. The normal in-session retry then resolves the card.
- Cards keep `Storage = "LocalOnly"`, so they read "(LOCAL TEST)" and say nothing about saving.

**Tests.** `tests/candidate-storage.spec.luau -a localids [mock|production|notstudio]`, added to `tests/run.sh`, results 96 / 55 / 55 / 57:
- A real Main runs LocalOnly with -1 (contributor) and -2 (0 points); -3 is a bystander who never joined.
  - -1 gets Accepted stage and final cards plus the trophy.
  - -2 is Refused.
  - -3 gets nothing.
- A second, consecutive instance settles.
- A replay gives `Duplicate` with no extra coins.
- An unknown id -9 gives `BadParticipants`.
- No DataStore calls are made.
- Under `Mock`, live `DataStore`, and LocalOnly with `IsStudio` false, the same contexts give `BadParticipants` with no cards or grants. A real id still settles in those same servers.
- 14 mutants were all caught (`evidence/two-client/local-ids-mutation.log`).

## 3. Candidate for Codex's Studio acceptance

Freeze on the branch commit named in `runtime-input-handoff.md` (Claude section, two-client
policy). The policy module is under `src/server/Services`, so the existing
`inject-production-candidate.py` / installer pick it up; its hash appears in the manifest. The
read-only `CandidateObserver` needs no change, because its rows are keyed by `tostring(UserId)`,
so `"-1"` and `"-2"`.

Procedure (`launch-readiness.md` §5 still applies; this replaces the reward part):

1. Confirm the Studio is `Expansion1Review.rbxlx`, PlaceId/GameId 0. Inject with `--write-manifest`, install in Edit, and record the install return.
2. Test → **Server & Clients, 2 players** (then 3 for the bystander), fresh profiles, ordinary input only.
3. Both players earn entry by digging, an excavated non-plain deposit, and a real sale. Observer: `CanEnter=true/CatchUp`. A player without evidence stays refused.
4. **Run A, eligible plus refused:** Player1 contributes. Player2 joins and stays under `MIN_POINTS` (5), or does not contribute.

   | Check | Expected |
   |---|---|
   | Observer `outcome` row for -1 | `Final Accepted`, `storage=LocalOnly` |
   | Observer `outcome` row for -2 | `Refused` with a reason |
   | Cards on screen | -1's card reads "ADVENTURE REWARDS (LOCAL TEST)" with the local note. -2's card shows the refusal. Neither says "SAVED". |
   | Stage rows | Exist only for contributors who were connected when the stage completed |

5. **Bystander:** a third client that never joins gets no outcome rows and no `Ball rescued.`.
6. **Run B, consecutive:** a new instance in the same server settles independently. Player2 contributes this time and also gets Accepted. Coins rise by the card's amount.
7. **Leave mid-run:** a participant who left gets `Left` or `Disconnected` and no final grant.
8. Throughout: `Storage.Acquired` / `Storage.Refused` stay `{}`, and there are zero DataStore calls.
9. Stop, uninstall, confirm restoration, and do not save. Put the evidence under `assets/adventure/verification/<session>/` and record completion in `runtime-input-handoff.md`.

**Not provable with simulated ids** (needs the account-backed environment below):
- rejoin delivery of `PendingRejoin` rewards;
- durability across servers;
- outbox drains;
- the live "SAVED" wording.

## 4. Account-backed environment (for the gates above)

These gates need:
- a separately owner-authorized **private, unpublished-to-players test place** with Studio API / DataStore access enabled, on a non-production universe;
- two or more **real Roblox accounts** (positive UserIds) added as collaborators, or a private-server live test;
- `AdventureFlags` enabled **only in that place**;
- production validation with **no** local policy, since the guard fails outside Studio LocalOnly.

That environment is not set up and needs owner authorization (gate 5 in `launch-readiness.md`).

## 5. Independent review

A separate agent reviewed the diff adversarially, checking production invariance, no
spoofing or bypass, downstream receipts and outboxes, membership tracking, ownership and test
quality. It reran the suites. **No blocking defects.** Its findings, all fixed:
- **Save-failure path not covered by tests.** Covering it exposed a real bug: the early return
  left a loaded simulated id's part at `Applied`, so no retry started. It now flips to
  `Unconfirmed` and retries, for both the coins/cert part and the trophy part. The new
  save-failure tests cover -1 and a first-time trophy for -4.
- **Wrong trophy reason.** An unloaded simulated id's trophy entry kept a stale
  `PendingWriteFailed`; it now reads `LocalSimulationNotLoaded`.
- **Policy module could be patched.** The module is now frozen.
- **64-client limit** documented in §2.

A second pass over the fixes found no blockers.
