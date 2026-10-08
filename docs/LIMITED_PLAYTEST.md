# Current limited-test preparation — 8 October 2026

Owner reports Roblox account age check **COMPLETE**; questionnaire/standing and published experience identity remain unverified. This supersedes older age-check tasks below. Candidate/source preparation and integration are authorized; publication, uploads, audience/access changes, spending and tester contact remain unauthorized.

Review [TEST_EXPERIENCE_PROPOSAL.md](TEST_EXPERIENCE_PROPOSAL.md): a new owner-only Private test experience from the final reviewed package, Computer initially, intended Max Players 16/first four-client test, optional features disabled, data isolated from future production by universe. Publication and later Limited → Playtesters/named Play-only access are separate explicit decisions. Keep existing DigTest/Rojo 34872 for local ordinary play.

Current ordinary evidence reaches a successful Wet Sand dig banner at the target boundary while the avatar root was near 17 m after upgrading, and Reduced Motion ON digging/selling. Finish Shell Bed, HOT/full Reduced Motion, off-screen sell guidance/contact and coordinated four-client shared holes/reward isolation/natural tide. The excavation/toast fix passes 1,388 client mock checks; fresh live retest pending. New server MicroProfiler labels support capture, but historical heartbeat spikes remain unattributed; server normal/Studio mocks pass 2,174/2,153. Bots and mocks do not substitute for real clients or services.

Universe-0 in-memory fallback leaves real persistence unverified. Obtain authorized identity before save/rejoin, locks, interrupted writes, shutdown and permitted-account access checks. Listening, fresh-player feedback and physical phone/controller checks remain unperformed; hardware deferred. Rebuild the candidate from the final clean checkpoint and record manifest/hash; the prior 8328340 candidate is historical until regenerated. No external invitation or public-launch sign-off.

8 October fresh Studio setup reconnected DigTest/Rojo 34872 and enabled Reduced Motion before digging, then paused at the owner's request to finish repository/CI while the desktop was in use. No new successful dig/live toast retest is claimed. Combined local client/server/Studio/utility checks **1,388 / 2,174 / 2,153 / 8** passed; PR #17/#18 merged as `b07bb97`/`904d6a7` after successful CI runs `37773554284`/`37773641661`. PR #19 source `8633dc0` passed CI `37774410859` and merged as code-source checkpoint `aa22ebb`; seven terrain-error regressions verify balanced labels and preserved original errors.

The concrete owner-only Private publication proposal is ready for explicit approval and may proceed before remaining local gameplay gates to enable real persistence testing. External access/invitations remain gated by the outstanding gameplay, service and permitted-account checks. Last Studio observation was active Play; Stop/save remains pending while desktop input is paused at the owner's request.

Latest integrated validation: client **1,388**, server **2,174**, Studio-mode **2,153**, utility **8**, all passed. Full formatting, strict analysis (two existing deprecated API warnings), sourcemap and build passed. The documentation-only stage follows code-source checkpoint `aa22ebb`; merge it before packaging from the clean synchronized default branch. The generated manifest will identify the exact final documentation/source revision and SHA-256; package regeneration is not yet claimed. Gameplay, service, capture and access gates above remain open.

---

# Limited core-gameplay playtest — 7 October 2026

Candidate preparation is authorized. Roblox publication, uploads, tester contact, spending and audience/access changes are not authorized. This package is not a public-launch sign-off.

## Build and reproduce

Use the clean synchronized preparation checkpoint from POLISH_HANDOFF.md. On Windows, with the existing `.tools` Luau/definitions and `rojo` and `python` on PATH:

```powershell
./tools/package-playtest.ps1
```

Output: `build/limited-playtest/LimitedPlaytest.rbxlx`, SHA-256/source manifest, this player script, packaging script and the evidence log. The manifest records Rojo/Python versions and hashes of Luau, Roblox definitions and the project, plus the DataStore name. Packaging refuses working changes, ignored source files and paths outside `build` or through junctions. Build artifacts are ignored; rebuild from the recorded commit with the recorded toolchain. Build hashes identify each output; identical bytes across different tool versions are not promised. Package generation checks blocking configuration, not gameplay or real persistence. Keep `build/DigTest.rbxl` as the ordinary-input Studio test place, connected to `rojo serve default.project.json --port 34872`. Do not replace it with the generated candidate for continued local review.

## Necessary owner setup

Owner reports the account age check **COMPLETE**. No published experience identity exists; account standing/age and questionnaire remain unverified.

1. Account age check **COMPLETE** by owner report; confirm remaining eligibility and questionnaire in Creator Hub. The initial 16+ / Trusted Friends route needs an account in good standing, at least two days old, an age check, and a completed maturity/compliance questionnaire. Do not pay for an all-ages route merely to run the initial core test.
2. When explicitly authorized, publish the reviewed candidate as a new test experience, recording universe ID, start-place ID and version. Use a separate test experience/data namespace from future production. Record the current `DATASTORE_NAME`; do not silently reset test saves between rejoin checks.
3. Complete the questionnaire truthfully against the actual game, including paid currency used for egg purchases if enabling monetization later. Select appropriate devices and verify Max Players (target 16; first test four).
4. Creator Hub → select experience → **Configure → Settings → Audience**: select **Limited → Playtesters** only after explicit access-change authorization (the current dashboard may also surface Audience → Access). Grant named accounts Playtest permissions through collaboration controls; do not give Edit permission merely to play. Private is owner/editor only under current documentation. Test the link using a permitted account and check the account-age audience restriction. Roblox documents a Trusted Friends exception for playtesters of an age-checked owner; ordinary friendship alone does not establish that status.
5. Use Roblox clients to earn/leave/rejoin and verify real persistence. For Studio DataStore tests, the owner must enable Studio API access in the dedicated test experience; Studio otherwise uses the documented in-memory fallback. Never point destructive diagnostics at production saves. HTTP and third-party sales are unnecessary for this test.

Current official sources rechecked 8 October 2026, unchanged: [publishing/access](https://create.roblox.com/docs/production/publishing/publish-games-and-places), [age audiences](https://create.roblox.com/docs/production/publishing/kids-and-select), [DataStores](https://create.roblox.com/docs/cloud-services/data-stores), [collaboration](https://create.roblox.com/docs/projects/collaboration). All-ages reach additionally requires verification/2FA, subscription or fee, and evaluation; check Audience Reach rather than promising launch today. Official pages differ on fee refund details; no fee decision is needed here.

## Optional configuration for this test

| Group | Core test decision | Later verification |
|---|---|---|
| 8 passes / 6 products | Keep IDs zero; purchase availability checks refuse unconfigured offers. No purchases or money required. | Real IDs, policy behavior, receipts and entitlements before enabling sales |
| 10 badges | Keep disabled; progression/discovery do not depend on awards. | Actual experience badge IDs and real awards before promising badges |
| GROUP_ID | Keep zero; group bonus off, DIGDEEP unavailable. | Ownership/membership/bonus and code behavior if enabled |
| MusicBeach / MusicDeep / Ambience | Silent core test acceptable; disclose missing ambience. | Owned/licensed assets, experience permissions, loading and listening |

Preflight currently finds zero blocking flags and these five missing groups. Strict preflight is the existing fully-configured-feature gate; optional features need not block a limited core test or an explicitly reduced-scope public release with accurate copy.

## Player script (15–20 minutes)

Observe without coaching first. No grants, teleports, scripted digs or dev commands in this portion.

1. Spawn and follow the objective. Dig, scan and find something; describe what the scan direction and HOT instructions mean. Try excavation and read the item/quality/value.
2. Fill the bag while facing away from Sell. Follow guidance, sell, buy/equip the first shovel, then dig down to its newly available layer. Describe the difference after buying.
3. Open chat and Shop. Note covered buttons, unreadable text or overlapping rewards. Toggle Reduced Motion; repeat scanning, excavation, selling and upgrading where available.
4. Walk near another player and dig the same area. Watch shared holes, server goal, tide/refill and safe recovery. Record any pet/tool contact problem that obstructs play.
5. Record coins, shovel, bag and discovery inventory; leave and rejoin. Compare. Report errors and where you wanted to stop playing.

Separate operator diagnostics: four Studio clients; two real server sessions competing for one account/profile lock; shutdown save; controlled tide and stress; client/server MicroProfiler captures. Label assistance and population honestly. Record revision/place version, observer, platform, timestamps, reproduction steps, expected/actual result and console/capture paths. Do not call mock tests real persistence or bots multiplayer replication.

## Prioritized checklist

**Must fix/resolve before inviting external testers**

- [ ] Explicit owner authorization for publishing and named-account access; complete eligibility/questionnaire and record test identity.
- [ ] Finish ordinary first session through post-upgrade digging, HOT cases and Reduced Motion; resolve any stuck progression or inaccessible controls.
- [ ] Four real Studio clients: join/shared digging/tide/server goal; no crashes or cross-player reward corruption.
- [ ] Real test-experience save/rejoin and error handling before asking testers to invest in saved progress. If a disposable no-save observation is chosen instead, clearly disclose it and do not call persistence passed.
- [ ] Build/checkpoint manifest and permitted-account join smoke; capture issue log.

**Must verify before public launch**

- [ ] Real locking, interrupted writes and shutdown saves; production namespace/permissions confirmed.
- [ ] Independent fresh-player evidence; ordinary full sequence and settings, chat, guidance and contact resolved.
- [ ] Measure populated client/server spikes with discoveries/pets/tide and profiler captures; historical 253 ms heartbeat spike remains unresolved.
- [ ] Hardware phone/controller checks when available (still deferred); choose supported devices honestly.
- [ ] Confirm policy/questionnaire, truthful capacity/media/copy, asset rights; configure and verify only features actually enabled/promised.
- [ ] CI green on final source; rollback place version and monitoring ready; explicit public-launch authorization and Audience Reach eligibility.

**Can follow after launch if disabled/unpromised**

- Optional passes/products, badges, group perks, additional ambience and acquisition artwork refinement.
- Exhaustive scenery pockets/asset angles and cosmetic collection sweeps; completed sweeps need no restart.

Next practical steps: finish local gameplay/multiplayer evidence and review the dedicated owner-only Private publication proposal. Authorized Private publication establishes identity for owner persistence testing; external access remains a separate decision after the invitation gates. No external invitation is ready yet.
