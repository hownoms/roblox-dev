# Dedicated test-experience proposal

Written 8 October 2026 for Howard's explicit approval. Nothing here has been carried out: no publication, upload, audience change, spending or tester contact. Eligibility status is tracked in [STATUS.md](STATUS.md).

## Proposed configuration

| Setting | Concrete proposal |
|---|---|
| Owner | Howard's existing Roblox user account; confirm the selected owner in the publication dialog |
| Name | Dig to the Core! — Limited Test |
| Description | A limited test of beach digging, treasure discovery, selling and shovel progression. Progress is under testing and may be reset with notice. Optional purchases, badges, group perks and ambience are unavailable. |
| Source | Fresh clean synchronized package from `tools/package-playtest.ps1`; record its exact commit and SHA-256 before publication |
| Place | Publish `build/limited-playtest/LimitedPlaytest.rbxlx` as a **new dedicated test experience**; retain `build/DigTest.rbxl` for ordinary local work on Rojo 34872 |
| Initial audience | Private, owner only; no extra Edit collaborators |
| Later test audience | Limited → Playtesters; named accounts with Play permission only, after separate explicit approval |
| Audience reach | Initial 16+ / eligible Trusted Friends route; no all-ages fee/subscription decision |
| Devices | Computer initially; phone/controller support stays deferred until physical checks pass |
| Capacity | Max Players 16 as intended configuration; first coordinated test four permitted real clients. Capacity is not a certified performance claim |
| Services | HTTP and third-party sales off. Studio API access off initially; approve enabling it only for this dedicated universe before Studio service diagnostics |
| Optional features | Existing zero/unset IDs for passes, products, badges, GROUP_ID and ambience retained; no uploads or purchases |
| Media | No custom icon/thumbnail upload within this proposal |

The current Roblox [publishing/access documentation](https://create.roblox.com/docs/production/publishing/publish-games-and-places) says Private is owner/Edit only; Playtest permissions require Limited → Playtesters. That route requires good standing, an account at least two days old, age check and completed maturity/compliance questionnaire. Confirm these in Creator Hub before changing access. [Collaboration documentation](https://create.roblox.com/docs/projects/collaboration) distinguishes Play from Edit; grant only Play to approved testers. The [Kids and Select requirements](https://create.roblox.com/docs/production/publishing/kids-and-select) add verification, 2FA, subscription/fee and evaluation for all-ages reach. None is proposed for this initial route. Do not assume ordinary friendship supplies Trusted Friends eligibility.

## Publication approval and access approval are separate

**Approval A — publication:** Approve publishing the recorded clean candidate as a new owner-only Private test experience under the configuration above. This creates Roblox content and identity. Record username/owner ID, universe ID, start-place ID, place version, source commit, manifest hash, UTC timestamp and resulting audience. Check the published settings and owner join before progressing. Owner-only Private publication may precede the remaining local gameplay gates to enable real persistence testing; it does not authorize external access or invitations. Record subsequent versions and source hashes within the owner's authorized publication scope.

**Approval B — access:** After local gates and owner persistence smoke pass, approve Limited → Playtesters and an exact list of Roblox usernames/user IDs. Verify intended accounts, eligibility and Play-only grants in the actual dashboard. Test permitted-account join plus an unpermitted-account denial where an owner-controlled account is available. No Public, Friends or Community Members audience change is proposed. Tester contact/invitations require their own explicit authorization; access permission alone does not authorize messages.

Questionnaire answers require truthful owner review of the actual candidate. Do not reuse assumed answers from marketing copy. Disabled paid offers do not authorize enabling monetization later.

## Data boundary and service verification

Recommend keeping the existing config names (`PlayerData_v1`, `Leaderboard_Coins`, `Leaderboard_Depth`) in the new test universe. Roblox [DataStore documentation](https://create.roblox.com/docs/cloud-services/data-stores) scopes storage to an experience and warns Studio can touch the same live data; it recommends a separate test experience. A dedicated universe supplies the isolation without modifying the reviewed candidate. Production must later be a separate universe. Record the namespace and never silently rename it or reset keys between rejoin checks. If the test universe is later repurposed, require an explicit migration/reset decision first.

Current profile key format is `Player_<UserId>`, DATA_VERSION 3, autosave 120 seconds and session-lock expiry 1,800 seconds. Universe-0 Studio uses in-memory fallback and cannot pass the rows below. Capture server logs proving real DataStore access with no fallback warning; record before/after values and persisted records through authorized service inspection. Protect identifiers in shared evidence.

| Case | Procedure and acceptance evidence | Boundary |
|---|---|---|
| Owner earn/rejoin | Record coins, shovel, bag, discoveries/settings; earn by ordinary input, leave and rejoin in Roblox client; compare expected retained state and logs | Real service; no grants |
| Autosave | Observe ordinary changes across the 120-second interval; independently inspect record revision/SavedAt, then rejoin | Real service; timing alone is insufficient |
| Player isolation | Four approved accounts share digging; track each reward/inventory/coin delta and rejoin separately | Real clients; bots do not substitute |
| Session contention | Dedicated diagnostic sessions attempt the same approved test profile while a live lock is held; verify rejection and no overwrite, then release and reacquire | Assisted real-service diagnostic; ordinary Roblox account handoff may close the first client, so do not claim contention merely from switching clients |
| Interrupted save | Controlled diagnostic interruption/delay of a test-profile write; verify retries/failure signal and rejoin does not replace a protected newer record with defaults/stale data | Test universe only; diagnostic mechanism and exact interruption point recorded. Injected failure alone is mock evidence |
| Shutdown | Earn known deltas on approved test accounts, request shutdown of the dedicated test server, rejoin and compare; retain BindToClose/final-save logs | Assisted operational test; orderly shutdown does not prove abrupt crash recovery |
| Abrupt interruption recovery | If feasible within authorized dedicated diagnostics, interrupt before a successful final write; verify latest completed autosave and lock behavior without promising unsaved deltas | Never force production failures; report unavailable cases as open |
| API restriction | Dedicated Studio session with API access disabled should log in-memory fallback; enabled diagnostic session must demonstrate real store access | Enabling security setting needs explicit approval; fallback is not persistence |
| Access | Exact approved account joins; an unapproved owner-controlled account cannot join, where available | No external contact or credential sharing |

Service-level failure/lock diagnostics need a separately reviewed method confined to disposable test profiles before execution. The normal client cannot reliably force every failure; unresolved cases remain release gates. Keep ordinary gameplay, assisted service diagnostics and headless/mock regressions separate in [PLAYTEST_EVIDENCE.md](PLAYTEST_EVIDENCE.md).

## Invitation and public-launch boundary

This proposal is reviewable but does not certify invitation readiness. Finish ordinary Shell Bed/HOT/Reduced Motion/off-screen guidance, consequential contact/overlap and coordinated four-client natural tide checks; establish identity and real persistence before promising saved progression. Resolve populated server spike attribution and obtain independent fresh-player feedback before public sign-off. Audio listening and physical phone/controller checks remain unperformed. Optional disabled/unpromised features can stay off. Public launch, broader device support, uploads, paid features and spending require additional explicit approval and their applicable evidence.

Official publishing/access, collaboration, DataStore and Kids and Select pages rechecked 8 October 2026; requirements unchanged. Recheck requirements at execution if the dashboard differs or time has passed; no account/security/audience setting was changed during preparation.
