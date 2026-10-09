# Project status: Dig to the Core! Beach Simulator

**Last updated:** 8 October 2026 (evening). This is the only page that tracks current state. Update it in
place; don't add dated "current status" blocks to other docs. Measurements and observations go
in [PLAYTEST_EVIDENCE.md](PLAYTEST_EVIDENCE.md) or a dated session record such as
[PLAYTEST_2026-10-08_PM.md](PLAYTEST_2026-10-08_PM.md).

## Where we are

- **Live on Roblox:** experience `10769863381`, start place `135511260983800`, **place version 17**
  ("Second-minute fixes - source 375625c"). All 157 published scripts were verified byte-identical
  to the merged source by opening v17 from Version History. Later commits are docs only.
- **Store page:** new icon and three illustrated thumbnails (Experience Detail Page list) from
  `marketing/publish-kit-2026-10-08/`. Roblox moderation result not confirmed. The Creator Hub
  name now reads **Dig to the Core!**.
- **Access:** Limited. **Playtesters on, Friends off.** Audience reach is "Ages 16+ and trusted
  friends". **Max Players is 50** (the intended value is 16). Neither was changed by the
  automation; both are owner steps (see below).
- **Code:** feature-complete through v3 (Discovery) plus the v17 second-minute fixes. See
  [CHANGELOG.md](CHANGELOG.md).
- **First-expansion visual kit:** local Mara/Pip concepts and portraits, Broadwave, three
  Spring Vault stages, controlled beach ball, trophy display and matching icons are in
  [assets/expansion1](../assets/expansion1/README.md). Strict/headless construction and Rojo
  builds verified; Studio contact/movement/device review, image uploads and gameplay/reward
  integration remain pending. No expansion was published or enabled.
- **Validation (latest):** client 1,413, server 2,195, Studio-mode 2,162, utility 8, seven
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
2. **Optional: Max Players 16:** Places → start place → Access → Maximum Visitor Count 16 → Save.

## Open

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
| [PUBLISH_HANDOFF_2026-10-08.md](PUBLISH_HANDOFF_2026-10-08.md) | How v15 and v17 were published and verified |
| [history/](history/) | Old session handoffs and review logs |
