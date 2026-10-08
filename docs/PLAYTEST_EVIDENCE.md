# Playtest evidence log

Dated record of what was observed, newest first. Keep three kinds of evidence apart: **normal
play** (ordinary input), **assisted** (dev commands, bots, teleports, source swaps) and
**headless/mock** tests. Mocks and bots never stand in for real clients or real DataStores.
Current status and open gates are in [STATUS.md](STATUS.md); don't add status summaries here.

## 8 October 2026: profiling labels, toast fix, private test proposal

| Evidence type | Result and limits |
|---|---|
| Owner report | Roblox account age check **complete**. Questionnaire, account standing and a published test identity are not yet verified |
| Normal play, DigTest (7 October continuation) | After the upgrade, a successful dig showed the Wet Sand banner at the target boundary with the avatar root near 17 m. That does not show traversal into Wet Sand or reaching Shell Bed. Reduced Motion ON digging and native selling were seen. No grants, teleports or scripted digs |
| Normal play, DigTest (8 October setup) | Reopened `build/DigTest.rbxl`, Rojo connected on 34872, fresh Play, Click to Move onto sand, Reduced Motion on before digging. Paused at the owner's request before any new dig or toast retest. Studio left in active Play; Stop/save pending |
| Client mock tests | Excavation/toast queue fix (PR #17): **1,388 passed**. Doesn't prove the live overlap is gone |
| Server mock tests | Synchronous MicroProfiler labels (PR #18) and balanced labels on terrain errors (PR #19, seven regressions): **2,174 normal / 2,153 Studio-mode passed**. Labels enable a server capture; they don't attribute the 82 ms / 253.3 ms heartbeat spikes. Heartbeat dt is the frame interval, not bot execution time |
| CI | PR #17 `7ad27eb` run `37773554284` (fixed a StyLua 2.0.2 vs 2.5.2 layout mismatch), merged `b07bb97`. PR #18 `75a1f4e` run `37773641661`, merged `904d6a7`. PR #19 `8633dc0` run `37774410859`, merged `aa22ebb` (code checkpoint). PR #20 `c31629b` run `37774722560`, merged `7563265` |
| Candidate | Rebuilt clean; manifest and SHA-256 verified: `0CCE34DB4E761A8B4642A2FE453819CA75B4834107251A691459F8741491D1AB`. Earlier `8328340` artifacts kept under `build/limited-playtest/history/8328340`. Preflight: zero blocking findings, five optional groups unset |
| Access | [TEST_EXPERIENCE_PROPOSAL.md](TEST_EXPERIENCE_PROPOSAL.md) written from official sources. No publication, uploads, access change, spending or tester contact |

## 7 October 2026: limited playtest preparation

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

## Earlier focused evidence (7 October 2026)

### Discovery name and reveal overlap

Ordinary DigTest before/after runs used starter autoequip, Click to Move and mouse digging, without live assisted setup. Before: natural excavation teardown target/result UI covered the Bottle Cap name/card while duplicate floating name text crossed the rarity headline; the Index toast appeared concurrently. After: natural Giant Bottle Cap (Common/Giant/Damaged, 24 coins) displayed its complete white name in a larger compact card alongside the Index toast, without excavation UI or duplicate name/value floats. Normal unanswered excavation cues and card auto-close were visible. Inline captures were inspected; no screenshot file is claimed. The rarity headline can still cross the avatar overhead label; all item names/viewports are not certified.

1,325 client checks, affected strict analysis, formatting, Rojo build and whitespace checks passed. No assisted live diagnostic was used; headless evidence is simulated. This closes only the observed focused discovery confusion, not the complete-sequence or any other release gate. Reactive successful/early/late ordinary-input timing, Reduced Motion, independent feedback, audio, hardware and broader dynamic contact remain open. No publication or uploads occurred.

### First-player run

A fresh DigTest ordinary-input run reached starter autoequip, digging, scan activation, excavation, retained bottle-cap discovery, full 20/20 bag, native sale (84 coins) and Garden Trowel purchase/autoequip (30 coins). This run used mouse clicks and Roblox Click to Move without dev grants or scripted digs/positioning. It still does **not close the complete-sequence gate**: scan direction, precise excavation timing, reward-name readability, audio listening, Reduced Motion across that sequence and meaningful post-upgrade digging remain unverified. Automated ordinary input is not independent fresh-player feedback.

Arrival after a confirmed boardwalk dig was fixed and retested live. Nearby target markers hide; excavation WAIT/TAP feedback and ground-creature follow sampling have regression coverage. Client checks now total 1,317 passing. Live excavation cue readability and full dynamic pet/equipment contact remain open. Separate `/pet sandy_crab` sessions were assisted diagnostics; the final Reduced Motion view was partly HUD-obscured. Offscreen sell navigation, chat covering Shop and overlapping upgrade toasts remain observed follow-ups. Hardware remains deferred, and no other gate is closed by this update.

### Scan direction

Evidence is integrated through PR #15 (`0e7f7d7`); GitHub CI run `37693736766` passed before merge. Integration closes no additional release gate.

Preserved and fetched intervening merged PRs #13/#14 (`0b1575a`). Ordinary current-source DigTest showed matching ground chevron/radar bearings at Cool/DOWN; movement and downward digs reached a natural fourth-dig excavation, before the sixth-dig guarantee. A separate fresh ordinary baseline run with only the two historical scan presentation files showed a plain white bar partly behind Scan, with no directional head and a round radar dot. Current files were restored exactly and DigTest stopped/saved. Source selection was assisted setup; gameplay used T, Click to Move and mouse digging without scripted actions or grants. Different natural deposits/positions limit the comparison; no HOT arrival, hot-band instruction, live Reduced Motion, controlled success-rate or independent fresh-player evidence is claimed. Current client checks: 1,373 passing; affected strict analysis, Windows-line-ending formatting and Rojo build passed. This supports the focused head/tail readability fix already merged in PR #14, without closing the complete sequence or any other release gate. Hardware remains deferred; no publication/uploads occurred.

### Excavation cues

Natural sixth-dig excavation in fresh ordinary-input DigTest runs visibly showed READY → WAIT → TAP and unanswered expiry, before and after the focused cue fix. Numbered results now remain separate from the next ring's centre cue, and graded rings disappear immediately. A separate synthetic client diagnostic showed pinned early MISS, PERFECT and late GOOD results; this is assisted presentation evidence. Client checks: 1,321 passing; affected strict analysis, formatting and Rojo build passed. Actual reactive successful/early/late ordinary-input timing, independent fresh-player feedback, physical controls, live Reduced Motion and full-sequence approval remain open. No other gate is closed; no publication or uploads occurred.
