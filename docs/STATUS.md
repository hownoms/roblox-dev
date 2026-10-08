# Project status: Dig to the Core! Beach Simulator

**Last updated:** 8 October 2026. This is the only page that tracks current state. Update it in
place; don't add dated "current status" blocks to other docs. Measurements and observations go
in [PLAYTEST_EVIDENCE.md](PLAYTEST_EVIDENCE.md).

## Where we are

- **Code:** feature-complete through v3 (Discovery). See [CHANGELOG.md](CHANGELOG.md).
- **Stage:** polish and limited playtest. Nothing is published on Roblox yet.
- **Latest code checkpoint:** `aa22ebb` (PRs #17–#19). PR #20 and the commit after it are docs only.
- **Latest validation:** 1,388 client, 2,174 server, 2,153 Studio-mode and 8 utility tests pass.
  Format, strict typecheck (two existing deprecated-API warnings), sourcemap and build pass. CI
  was green on each merged PR.
- **Playtest candidate:** built with `tools/package-playtest.ps1`. Place SHA-256
  `0CCE34DB4E761A8B4642A2FE453819CA75B4834107251A691459F8741491D1AB`. The manifest records the
  exact revision. Rebuild from clean Git after any further source change.
- **Preflight:** no blocking findings. Five optional groups are unset on purpose: passes,
  products, badges, `GROUP_ID` and music/ambience.
- **Studio:** last seen in Play on `build/DigTest.rbxl` (Rojo port 34872), paused at the owner's
  request. Stop and save it before the next session.

## Verified so far

- **Normal play in Studio:** spawn, auto-equip, dig, scan, excavate, readable discovery card,
  full bag, sell, buy and equip the Garden Trowel. After the upgrade, a Wet Sand dig. Chat sits
  bottom-left without covering Shop. Reduced Motion can be turned on, and digging and selling work
  with it on.
- **Multiplayer:** four Studio clients spawned and the server dig goal replicated.
- **Load:** `/stress 15` bots ran with a 16.7 ms average and 82 ms max server heartbeat.
- **Client profile:** 16.7 ms mean CPU frame on desktop.

Mock tests, bots and Studio's in-memory DataStore don't count as real clients or real saving.

## Open: before inviting outside testers

1. **Finish the first session with normal play.** Reach Shell Bed, see the HOT scan
   instructions, run the full Reduced Motion sequence, and follow the arrow to an off-screen
   sell stand. Note any tool or pet contact problems.
2. **Retest the toast fix live.** Non-urgent toasts should wait while an excavation is showing.
   Mock tests pass; it hasn't been seen in game.
3. **Run a coordinated four-client test.** Check shared holes, that each player gets only their
   own rewards, and the natural tide refill.
4. **Publish a private test place (owner approval needed).** See
   [TEST_EXPERIENCE_PROPOSAL.md](TEST_EXPERIENCE_PROPOSAL.md). Then test real saving: rejoin,
   autosave, session lock, interrupted save and shutdown.
5. **Grant tester access (separate owner approval).** Limited → Playtesters with named
   Play-only accounts, then check that a permitted account can join.

## Open: before public launch

- **Server performance:** find what causes the heartbeat spikes (82 ms recently, 253 ms
  earlier), using the new MicroProfiler labels.
- **Feedback:** watch at least one new player without coaching.
- **Audio:** listen to the sounds in game.
- **Hardware:** test on a real phone and controller. Deferred until hardware is available.
- **Store page:** use real gameplay screenshots. Copy must only claim enabled features.
  Questionnaire answered.
- **Release:** a rollback place version, monitoring, and the owner's go-ahead.
- **Optional features:** if you turn any on (passes, products, badges, group, music), fill in
  their IDs and test them first.

## Owner decisions pending

| Decision | Doc |
|---|---|
| Publish an owner-only Private test experience | [TEST_EXPERIENCE_PROPOSAL.md](TEST_EXPERIENCE_PROPOSAL.md), Approval A |
| Open Limited → Playtesters to named accounts | Same doc, Approval B |
| Contact testers | Needs its own approval |
| Public launch, uploads, paid features, spending | [LAUNCH.md](LAUNCH.md) |

Your Roblox account age check is complete. Account standing and the maturity questionnaire
still need to be confirmed in Creator Hub.

## Working rules

- Fetch the default branch (`claude/pensive-meitner-6jx4u4`) first. The owner also works between
  sessions.
- Do one focused issue per stage: reproduce it, fix it, verify it, then open and merge its PR.
- Record evidence in three separate groups: normal play, assisted setup (dev commands, bots,
  teleports) and headless tests.
- Don't restart the finished collection and scenery sweeps.
- Never publish, upload, change access, spend money or contact testers without the owner's
  explicit approval.

## Where things live

| Doc | Use |
|---|---|
| [LAUNCH.md](LAUNCH.md) | Go-live runbook, owner steps in order |
| [LIMITED_PLAYTEST.md](LIMITED_PLAYTEST.md) | Building the candidate, player script, tester checklist |
| [TEST_EXPERIENCE_PROPOSAL.md](TEST_EXPERIENCE_PROPOSAL.md) | Private test place setup and real-save test plan |
| [POLISH_ROADMAP.md](POLISH_ROADMAP.md) | Polish priorities by area |
| [POLISH_RELEASE_GATES.md](POLISH_RELEASE_GATES.md) | Release gate inventory, source findings, store-art comparison |
| [PLAYTEST_EVIDENCE.md](PLAYTEST_EVIDENCE.md) | Dated evidence log |
| [history/](history/) | Old session handoffs and review logs |
