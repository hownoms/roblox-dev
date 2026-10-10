# Project status: Dig to the Core! Beach Simulator

**Last updated:** 10 October 2026. This is the only page that tracks current state. Update it in
place; don't add dated "current status" blocks to other docs. Measurements and observations go
in [PLAYTEST_EVIDENCE.md](PLAYTEST_EVIDENCE.md) or a dated session record such as
[PLAYTEST_2026-10-08_PM.md](PLAYTEST_2026-10-08_PM.md).

## Where we are

- **Live on Roblox:** experience `10769863381`, start place `135511260983800`, **place version 17**
  ("Second-minute fixes - source 375625c"). All 157 published scripts were verified byte-identical
  to the merged source by opening v17 from Version History. Later commits are docs only.
- **Store page:** revised bacon-hair artwork from `marketing/publish-kit-bacon-v3/` uploaded.
  Icon is now visibly approved/displayed; main digging thumbnail is Active on Home. Revised
  digging, rare-find and depth images lead the detail-page gallery; prior images remain afterward.
  Live name is **Dig to the Core!**, with a saved 591-character discovery-led description and
  genre **Simulation → Incremental Simulator**. Evidence and exact description are in that kit.
- **Access:** Limited. **Playtesters on, Friends off.** Audience reach is "Ages 16+ and trusted
  friends". **Max Players is 16**, saved and rechecked under the owner's publishing-cleanup
  authorization. Account publishing eligibility lists Identity verification and 2-step
  verification as Start; camera age check is Done. Broader reach remains an owner step.
- **Code:** feature-complete through v3 (Discovery) plus the v17 second-minute fixes. See
  [CHANGELOG.md](CHANGELOG.md).
- **Map art overhaul (merged, not published):** a new skyline, boardwalk, carnival pier, hub buildings,
  beach scenes and client motion. Studio-reviewed. Record: [MAP_OVERHAUL_2026-10-08.md](MAP_OVERHAUL_2026-10-08.md).
- **First-expansion visual kit:** local Mara/Pip concepts and portraits, Broadwave, three
  Spring Vault stages, controlled beach ball, trophy display and matching icons are in
  [assets/expansion1](../assets/expansion1/README.md). Strict/headless construction and Rojo
  builds verified. Basic Studio construction, vault extents, anchor stages and R6/R15 equip
  passed; see [Studio review](../assets/expansion1/verification/STUDIO_REVIEW.md).
  Beach-ball panel polish, moving scoop/device review, image uploads and gameplay/reward
  integration remain pending. No expansion was published or enabled.
- **Spring Vault production candidate (merged to default `01eebba` on owner instruction, 10 October
  2026, not published, flags ship off):**
  - Fail-closed local-only storage, chosen before any service starts: zero DataStore
    acquisition, refused outside the authorized unpublished Expansion1Review.
  - The runtime starts from the remotes before the arena replicates.
  - Completing Pip's trial grants the permanent Broadwave license (q_pip).
  - Rides are refused in the pocket.
  - Reproducible candidate install and uninstall for Expansion1Review.
  - On `470465f`, with real Studio input, a fresh save earned eligibility in play and completed
    the whole journey: refusal, entry, Pip trial and license, licensed digging, Mara run,
    per-player outcomes (local simulation), return and digging.
  - Open: Codex panel and copy findings, two clients and devices, streaming radii, live
    persistence, owner decisions.
  - Record: [integration/production-candidate.md](integration/production-candidate.md).
- **Spring Vault player flow (merged to default on owner instruction, 10 October 2026, not
  published, every flag off):**
  - The journey is connected on the real production boot: hatch and invitation, equipped
    Broadwave and adventure controls, per-player completion card, and a safe return to the
    beach.
  - A full run was played in Studio Expansion1Review with real input. In-memory saves; the
    review prerequisite was seeded.
  - It contains Codex's PRs #36 to #40.
  - Before any flag goes on:
    - Codex: fallback prompts require line of sight, which stalls repeat runs; contextual buttons
      reflow under the cursor; the last line of B1 review copy.
    - Owner decisions, including who grants the Broadwave license.
    - Two clients, devices, streaming and live persistence.
  - Record: [integration/player-flow.md](integration/player-flow.md).
- **Spring Vault production integration (merged to default `1c0bd10` on owner instruction,
  not published, every flag off):**
  - Wiring is applied in this branch. Main boots TrophyService, AdventureSettlement and
    AdventureBoot, the camp and outcome remotes exist, and Q goes through the input arbiter.
  - With `AdventureFlags` off, which is how it ships, the adventure runtime is never required.
  - It contains Codex's merged PRs #33 and #34, plus Claude's work on:
    - a surface hatch and safe returns;
    - pocket lighting;
    - removing the arena spawn;
    - licensed Broadwave (`ResolveTool`) with an equip control that doesn't need the Backpack;
    - a settlement durability audit (9 fixes);
    - a camp lifecycle audit (8 fixes).
  - Every spec passes on the mock store, and Codex's candidate audit passes. Live DataStores,
    Studio lighting, devices and real cross-server play are still unverified.
  - The packet, with every open gate and owner decision, is
    [integration/README.md](integration/README.md).
- **Validation (latest):** client 1,464, server 2,199, Studio-mode 2,166, utility 8, seven
  tutorial scenarios and persistence boot all pass. Strict typecheck shows only the two existing
  deprecated-API warnings. CI is green on every merge.

## Verified so far

- **Real saving (live DataStore):** an existing save went through save, leave and rejoin on a
  *different* server. Coins, bag, equipped shovel, finds, Index and tutorial were all preserved.
- **Published code:** v15 and v17 scripts both match source exactly.
- **Fresh no-pass first session (Studio local server):** dig, first find, scan, a deliberately
  dug second find, readable named reveal cards, full bag, world Sell, Garden Trowel bought. The
  v17 fixes were retested here: "DIG DOWN HERE!" overhead detector, visible hip-height arrow,
  camera turn to Sell (under 4 s), and coins/price guidance when the trowel is unaffordable.
- **Two local Studio clients:** each sees the other, the server goal is shared, and finds go
  only to the player who dug them. This is Studio replication, not real-service multiplayer.

Mock tests, bots and Studio's in-memory DataStore don't count as real clients or real saving.

## Owner steps now

1. **Let your friend in:** Creator Hub → Dig to the Core! → Configure → Settings → Audience →
   keep **Limited**, tick **Friends** → Save. Alternatively add them as a playtester.
2. **All-ages reach:** finish government-ID verification and 2-step verification, then review
   the subscription/publishing-fee route and Roblox game evaluation. No payment or security
   change was performed. Public launch remains pending readiness checks and the owner's decision.

## Open

- **Spring Vault adventure (before any flag is turned on):** see "Open gates" in
  [integration/README.md](integration/README.md). In brief:
  - Codex's runtime copy still says "REVIEW ONLY".
  - There is a duplicate equip button.
  - Pocket lighting and the hatch need a Studio look.
  - Physical phone and controller input is untested.
  - Live persistence tests are listed in
    [integration/settlement-durability.md](integration/settlement-durability.md).
  - Owner decisions still open: who grants the Broadwave licence, permanent first-sale
    evidence, the kill-switch trigger, and the reach of the rewards flag.
  - Production camp gates: the 16 `TrophyCampPad` pads and a camp/trophy UI.

- **Map art overhaul:** mobile frame-time check with ~9.7k surface parts before publishing; motion
  not yet watched live.
- **Audio:** listen to the 12 candidates in `assets/audio/original-v1`, then choose, upload and
  integrate. Loudness was measured, not listened to. Also check engine muting while riding.
- **Real multiplayer:** shared holes, natural tide, recovery and reward isolation with real
  accounts. Profile a populated server and attribute its heartbeat spikes.
- **Moving contact:** shovel strike, pet follow/dig over slopes and holes, underground discovery,
  crowded readability.
- **Launch media:** full-resolution native gameplay captures to sit next to the illustrations.
- **Feedback:** watch an independent newcomer without coaching.
- **Hardware:** test on a real phone and controller (deferred).
- **Before public launch:** questionnaire and standing, rollback version, monitoring, and the
  owner's go-ahead.

## Working rules

- Fetch the default branch (`claude/pensive-meitner-6jx4u4`) first. The owner also works between
  sessions.
- Do one focused issue per stage: reproduce it, fix it, verify it, then open and merge its PR.
- Record evidence in three separate groups: normal play, assisted setup (dev commands, bots,
  teleports) and headless tests.
- Don't restart the finished collection and scenery sweeps.
- Never publish, upload, change access, spend money or contact testers without the owner's
  explicit approval in the current chat.
- Don't launch "Roblox Studio" from the Start menu while Studio windows are open: the updater can
  close them. Focus the existing window instead.

## Where things live

| Doc | Use |
|---|---|
| [LAUNCH.md](LAUNCH.md) | Go-live runbook, owner steps in order |
| [LIMITED_PLAYTEST.md](LIMITED_PLAYTEST.md) | Building the candidate, player script, tester checklist |
| [TEST_EXPERIENCE_PROPOSAL.md](TEST_EXPERIENCE_PROPOSAL.md) | Private test place setup and real-save test plan |
| [POLISH_ROADMAP.md](POLISH_ROADMAP.md) | Polish priorities by area |
| [POLISH_RELEASE_GATES.md](POLISH_RELEASE_GATES.md) | Release gate inventory, source findings, store-art comparison |
| [PLAYTEST_EVIDENCE.md](PLAYTEST_EVIDENCE.md) | Dated evidence log |
| [PLAYTEST_2026-10-08_PM.md](PLAYTEST_2026-10-08_PM.md) | Published-build verification, live save/rejoin, v17 fixes and audio measurements |
| [MAP_ART_DIRECTION.md](MAP_ART_DIRECTION.md) | Map art rules, area ownership, budgets, ambient motion tag contract |
| [MAP_OVERHAUL_2026-10-08.md](MAP_OVERHAUL_2026-10-08.md) | Map overhaul session record, Studio findings, captures |
| [TROPHY_INTEGRATION.md](TROPHY_INTEGRATION.md) | Trophy API for the adventure, persistence design, wiring patch, gates, test evidence |
| [PUBLISH_HANDOFF_2026-10-08.md](PUBLISH_HANDOFF_2026-10-08.md) | How v15 and v17 were published and verified |
| [history/](history/) | Old session handoffs and review logs |
