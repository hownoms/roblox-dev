# Integrated repository stages — 8 October 2026

PRs #17–#20 are merged; each passed CI before merge. Documentation PR #20 source `c31629b` passed CI `37774722560` and merged as `7563265`. The default branch was fetched and fast-forwarded without discarding intervening work. Gameplay source remains the reviewed `aa22ebb` code checkpoint.

The clean candidate was rebuilt and its manifest/source and SHA-256 verified. Place SHA-256: `0CCE34DB4E761A8B4642A2FE453819CA75B4834107251A691459F8741491D1AB`. The manifest records the exact clean repository revision, including these integration notes when repackaged. Earlier `8328340` artifacts are preserved under `build/limited-playtest/history/8328340`; profiler evidence remains intact. Zero blocking preflight findings and five disabled optional groups do not certify gameplay or persistence.

Repository preparation stages are complete. Studio was last observed in fresh active Play on DigTest with Rojo 34872; input remains paused at the owner's request, and Stop/save is pending. Resume with a fresh source Play session when the desktop is available. Shell Bed/HOT/full Reduced Motion, consequential contact/live toast overlap, coordinated four-client natural tide/reward isolation and server spike attribution remain open. Real services/access await explicit Private publication authorization and identity; audio, independent feedback and hardware remain unperformed/deferred. The concrete proposal is in TEST_EXPERIENCE_PROPOSAL.md. No publication, upload, access change, spending or tester contact occurred; no invitation/public-launch readiness is claimed.

---
# Current evidence update — 8 October 2026

This update preserves historical evidence below and separates ordinary gameplay, assisted diagnostics and mock tests. No publication/access change, uploads, spending or tester contact occurred.

| Evidence type | New result / limit |
|---|---|
| Owner report | Roblox account age check **COMPLETE**; questionnaire/standing/account identity not independently verified, no published test experience identity |
| Ordinary DigTest, 7 October continuation | A successful post-upgrade dig displayed Wet Sand at the target boundary while the avatar root was near 17 m; this does not establish traversal into Wet Sand or arrival in Shell Bed. Reduced Motion ON digging and native selling seen. Shell Bed, HOT and full Reduced Motion sequence remain open; no grants/teleports/scripted digs claimed for this ordinary segment |
| Client mock tests | Focused excavation/toast queue fix: **1,388 passed**, zero failures. Fresh ordinary live retest pending; headless results do not prove final overlap appearance |
| Server mock tests | New synchronous profiling labels: **2,174 normal / 2,153 Studio-mode**, zero failures. CLI mock tracks profiler marker nesting; this is not capture or real-service evidence |
| Profiling preparation | Labels identify stress bot creation/step, terrain read/write and tide fill chunks without intentional yields. Server capture/spike attribution remains open; prior client dump cannot attribute historical server 82 ms/253.3 ms heartbeat stalls. Heartbeat dt measures interval, not bot execution time |
| Access/service proposal | [TEST_EXPERIENCE_PROPOSAL.md](TEST_EXPERIENCE_PROPOSAL.md) prepared with official sources; owner-only Private publication and later exact Play-only access approvals remain outstanding |

Remaining: ordinary Shell Bed/HOT/full Reduced Motion/off-screen guidance, consequential contact and live overlap retest; coordinated four-client shared digging/reward isolation/natural tide; authorized identity and real saving/rejoining/locks/interrupted writes/shutdown/access checks; server/populated performance, listening and independent fresh-player feedback. Physical phone/controller checks remain unperformed/deferred. Completed collection/scenery sweeps remain complete. Final Studio saved state, integration checkpoint and regenerated candidate manifest must be recorded after ongoing work; no invitation/public-launch readiness is claimed.

8 October setup only: reopened actual `build/DigTest.rbxl`, Rojo visibly connected on 34872; fresh Play, ordinary Click to Move onto sand and Reduced Motion enabled before digging. Owner requested repository/CI work first while using the desktop, so no new successful dig or completed live toast retest occurred. Combined local client/server/Studio/utility **1,388 / 2,174 / 2,153 / 8** passed with zero failures; formatting/strict passed with two existing deprecated API warnings. PR #17 CI type-layout mismatch (pinned StyLua 2.0.2 versus local 2.5.2) was corrected at `7ad27eb`; CI run `37773554284` passed and PR #17 merged as `b07bb97`. Profiling PR #18 at `75a1f4e` passed CI `37773641661` and merged as `904d6a7`. PR #19 terrain-exception profiler-label balance preserves original errors and passes seven regressions; source `8633dc0` passed CI `37774410859` and merged as code-source checkpoint `aa22ebb`.

Latest integrated validation: client **1,388**, server **2,174**, Studio-mode **2,153**, utility **8**, all passed. Full formatting, strict analysis (two existing deprecated API warnings), sourcemap and build passed. The documentation-only stage follows code-source checkpoint `aa22ebb`; merge it before packaging from the clean synchronized default branch. The generated manifest will identify the exact final documentation/source revision and SHA-256; package regeneration is not yet claimed. Gameplay, service, capture and access gates above remain open.

---

# Playtest evidence and issues — 7 October 2026

Observations, assisted diagnostics and simulations are separate. No public-launch gate is closed by packaging.

| Evidence | Result / limit |
|---|---|
| Repository | Started clean at 2e58982; fetched and preserved merged PRs #13–#15; preparation 655dc15 and save fix 46833d7 pushed to default branch |
| Interrupted client validation | Rerun completed: 1,373 passed, zero failed; build/client-preparation.log |
| Server tests after save fix | 2,167 normal / 2,146 Studio-mode, zero failures; targeted overlapping saves and stalled-release rejoin regressions are mocks |
| Utility / preflight | 8 passed; zero blocking flags, five missing optional configuration groups |
| Source validation | Windows StyLua passed; strict analysis passed with existing social API deprecations; affected save file strict check, Rojo map/build and whitespace passed |
| Live setup | Existing DigTest, Rojo visibly connected localhost:34872, fresh ordinary Play; setup separate from gameplay |
| Ordinary discovery | Starter autoequip, Click to Move, mouse digs and natural excavation; readable Tiny Cool Sunglasses Rare/Tiny/Damaged/18-coin card, own nameplate hidden; no live grants/teleports/dev commands |
| Ordinary economy | Filled 20/20 bag; native Sell zone emptied bag for 88 coins; bought/auto-equipped 30-coin Garden Trowel, 58 coins left; readable gain card and deeper-layer objective; one further dig produced sand, Shell Bed not reached |
| Ordinary UI/settings | Chat bottom-left, Shop unobscured; chat overlapped left bag region. Reduced Motion OFF→ON then Cool/DOWN scan; HOT and complete settings sequence unverified. Quest/Index toasts crossed later excavation heading |
| Actual multiplayer | Four Studio clients spawned; two controlled with ordinary input. Goal increments visible and avatars shared area. Full coordinated shared-hole, reward isolation and natural tide tests incomplete |
| Assisted stress | /stress 15 fx ~74.5 s; 123.8 edits/s, 88% successful, heartbeat 16.7 ms average / 82 ms max, reported server memory 1,833 MB, send 62 kbps. Bots not real clients; silent digs omit discoveries/reveals. Goal completion replicated; stop cleaned bots/forced refill and operator returned to surface |
| Actual desktop profiling | Saved 128-frame client MicroProfiler (~2.13 s): CPU mean 16.658 ms, p95 17.998, max 18.764; memory 2,056–2,060 MB. Studio Win64 / Ryzen 5800X3D / RTX 4070, 896×712, auto quality 14. Script aggregate mean .563 ms; terrain meshing worker maxima warrant investigation but do not explain server spikes |
| Service limitations | Universe 0/in-memory fallback; social/localization HTTP errors present. No actual DataStore/lock/shutdown sign-off. Server native capture failed outside monitor even after owner assistance |
| Unperformed | Audio listening, independent feedback, physical phone/controller checks, real persistence and populated release performance approval |

| Issue | Priority / next evidence |
|---|---|
| Ordinary first session ends before new layer; HOT/full Reduced Motion unverified | Before invitation: finish ordinary sequence and resolve concrete progression/control blockers |
| Four-client shared digging/natural tide incomplete | Before invitation: coordinated input, replicated holes, safe refill and cross-player reward isolation |
| No published test experience | Owner age check COMPLETE; explicit publication/access authorization, questionnaire/remaining eligibility, identity and permitted join still needed |
| Real save/rejoin untested | Before saved-progress invitations; locking/interruption/shutdown before public launch. Fix serialized saves and fails closed after 30 s stalled release; retry exhaustion/shutdown deadline/loading remain service-test concerns |
| Server spikes | Public gate open: first window 82 ms, later 49.6 ms; obtain server profiler spanning spike/refill. Earlier 253.3 ms capture remains historical unresolved evidence |
| Quest/Index toasts crossing later excavation heading | Presentation follow-up; readable reward cards observed. Reproduce queue timing impact before choosing fix |
| Contact | Starter equipment seen moving, no proven blocker; ordinary pets/varied avatar/slope contact not certified |

Saved local evidence (ignored build files):

- build/limited-playtest/evidence/microprofile-20261007-183019.html; SHA-256 94C5CF9A75C129AF1DF4D6457541904A5096BAD4F8B5A8B486C1D4FB310F8D44.
- Adjacent client-profiler-analysis.md and studio-stress.txt. Source server log: 0.742.0.7421053_20261007T222808Z_Studio_034DC_last.log.
- CPU intervals, GPU dump fields and separately observed UI memory/GPU values differ in scope/time; do not combine them. Worker scopes overlap and must not be summed. Client capture cannot attribute server heartbeat spikes.

Screenshots were inspected inline, not saved. Candidate source/toolchain/hash is in the generated manifest. No Roblox publication/uploads/access changes, spending or tester contact occurred. Hardware remains deferred. See LIMITED_PLAYTEST.md for player script, owner actions and prioritized checklist.

Current Studio state, 8 October: last observed in active fresh Play; desktop input paused at owner request. Stop/save is pending; no stopped/saved final state is claimed.
