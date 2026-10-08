# Limited core-gameplay playtest

How to build the test candidate, what the owner sets up, the player script and the tester checklist. Current progress is in [STATUS.md](STATUS.md).

Candidate preparation is authorized. Roblox publication, uploads, tester contact, spending and audience/access changes are not authorized. This package is not a public-launch sign-off.

## Build and reproduce

Build from a clean, synced checkout of the default branch (latest checkpoint in [STATUS.md](STATUS.md)). On Windows, with the existing `.tools` Luau/definitions and `rojo` and `python` on PATH:

```powershell
./tools/package-playtest.ps1
```

Output: `build/limited-playtest/LimitedPlaytest.rbxlx`, SHA-256/source manifest, this player script, packaging script and the evidence log. The manifest records Rojo/Python versions and hashes of Luau, Roblox definitions and the project, plus the DataStore name. Packaging refuses working changes, ignored source files and paths outside `build` or through junctions. Build artifacts are ignored; rebuild from the recorded commit with the recorded toolchain. Build hashes identify each output; identical bytes across different tool versions are not promised. Package generation checks blocking configuration, not gameplay or real persistence. Keep `build/DigTest.rbxl` as the ordinary-input Studio test place, connected to `rojo serve default.project.json --port 34872`. Do not replace it with the generated candidate for continued local review.

## Necessary owner setup

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

Preflight reports these five groups as missing but not blocking. Strict preflight is the existing fully-configured-feature gate; optional features need not block a limited core test or an explicitly reduced-scope public release with accurate copy.

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
