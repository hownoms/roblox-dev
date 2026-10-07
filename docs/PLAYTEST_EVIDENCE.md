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
| No test experience/account setup | Owner age check now; later explicit publication/access authorization, questionnaire, identity and permitted join |
| Real save/rejoin untested | Before saved-progress invitations; locking/interruption/shutdown before public launch. Fix serialized saves and fails closed after 30 s stalled release; retry exhaustion/shutdown deadline/loading remain service-test concerns |
| Server spikes | Public gate open: first window 82 ms, later 49.6 ms; obtain server profiler spanning spike/refill. Earlier 253.3 ms capture remains historical unresolved evidence |
| Quest/Index toasts crossing later excavation heading | Presentation follow-up; readable reward cards observed. Reproduce queue timing impact before choosing fix |
| Contact | Starter equipment seen moving, no proven blocker; ordinary pets/varied avatar/slope contact not certified |

Saved local evidence (ignored build files):

- build/limited-playtest/evidence/microprofile-20261007-183019.html; SHA-256 94C5CF9A75C129AF1DF4D6457541904A5096BAD4F8B5A8B486C1D4FB310F8D44.
- Adjacent client-profiler-analysis.md and studio-stress.txt. Source server log: 0.742.0.7421053_20261007T222808Z_Studio_034DC_last.log.
- CPU intervals, GPU dump fields and separately observed UI memory/GPU values differ in scope/time; do not combine them. Worker scopes overlap and must not be summed. Client capture cannot attribute server heartbeat spikes.

Screenshots were inspected inline, not saved. Candidate source/toolchain/hash is in the generated manifest. No Roblox publication/uploads/access changes, spending or tester contact occurred. Hardware remains deferred. See LIMITED_PLAYTEST.md for player script, owner actions and prioritized checklist.
