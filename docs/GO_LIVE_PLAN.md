# Go-live plan: Dig to the Core!

**Goal:** make the core game **public** as soon as it is safe, then grow it with updates.
**Owner of this plan:** Claude. Update the checkboxes in place at the end of every session.
STATUS.md still records state; this file only says what's next and who does it.

## The rule

Only **launch blockers** get worked on until the game is public. A blocker is one of these:

- a crash, script error or soft-lock in normal play;
- lost or wrong save data (coins, bag, finds, purchases);
- a player can't finish spawn → dig → find → sell → upgrade unaided;
- a purchase or pass that takes Robux and doesn't deliver;
- unreadable or unplayable on a phone;
- a Roblox policy or questionnaire problem.

Anything else goes to **Post-launch** at the bottom. Polish waits until after launch.

## Scope freeze (10/11 Oct 2026)

- **Launch scope:** the v17 core game, the merged map art overhaul, music and ambience, and the badges we can ship.
- **Spring Vault / Broadwave / trophies / camp:** **frozen** and not part of launch. The code stays
  in the tree with every `AdventureFlags` flag off. Nobody starts new expansion work until the game
  is public. It becomes the first post-launch update (game bible milestones 3–4).

## Critical path (updated 11 Oct)

**1.2 phone performance → 1.7 v18 build → owner says "publish v18" → Phase 2 playtest → public.**
The owner's ID verification + 2FA runs alongside and gates Phase 3, so it is the likeliest thing to
hold up launch. Music (1.3) and badges 11–15 are **not blockers**. They ride along if they're ready
when 1.7 is cut; otherwise they go in the first update. Nothing waits on them.

## Phase 1: release candidate v18 (Claude + Codex in parallel)

| # | Task | Who | Done when |
|---|---|---|---|
| [x] 1.1 | Prove the expansion is inert in the shipped boot: flags off, no adventure remotes/UI/parts reachable, no DataStore keys written | Claude | Test/assert in the suite and a Studio boot with no `[Adventure]` output. **Done 11 Oct** (`58109ef`): camp pad was shipping, now gated |
| [ ] 1.2 | Map overhaul mobile performance: emulate a low-end phone in Studio, measure frame time and memory at spawn and pier, and cut or stream scenery if over the [PERFORMANCE.md](PERFORMANCE.md) budget | **Codex** (moved 11 Oct: critical path, Codex is free) | Numbers recorded and within budget |
| [ ] 1.3 | Music and ambience: pick licensed Creator Store tracks for `MusicBeach`, `MusicDeep`, `Ambience`, wire ids in `Config/Sounds.luau`, check volume and the settings toggles | Claude picks, **owner approves** | Plays in Studio and the toggles work. Not a blocker: ships with v18 only if approved before 1.7 |
| [x] 1.4 | Badges: 5 of 15 have ids. Art exists for 5 more (`marketing/badges/06`–`10`: FrozenAbyss, MagmaChamber, AlienHive, TheCore, FirstRebirth). The other 5 (MythicLuck, Collector, AncientRuins, BeachRegular, CoreBreaker) need art or get cut from the store copy | **Owner creates** in Creator Hub, Claude makes missing art and pastes ids | No `Id = 0` badge is promised anywhere. **Done 11 Oct** (`826d0fb`): owner made 6–10, ids pasted; the live description and badge page promise nothing else. All 15 arts exist; 11–15 get created on a later day's free quota (5/day) |
| [x] 1.5 | Core first-session blocker sweep on a fresh save: LAUNCH.md §1 checklist (chat vs Shop, toast order, off-screen arrow, Reduced Motion, full bag, upgrade) | Codex | Report of blockers only; each blocker fixed in its own PR. **Sweep reported 11 Oct**: no confirmed 1.5 blocker; evidence limits in [CORE_LAUNCH_SWEEP.md](CORE_LAUNCH_SWEEP.md) |
| [x] 1.6 | Purchase and save sweep: every pass/product grants once, survives rejoin, BindToClose saves on shutdown, no error spam with API access in Studio | Codex | Report and fixes merged. **Done 11 Oct**: one blocker fixed (PR #43, `3676be9`); the real-DataStore check moved to Phase 2 |
| [ ] 1.7 | Green CI, preflight, and a v18 build from default, as soon as 1.2 merges | Claude | Commit hash recorded below |

## Phase 2: v18 on the Limited audience (owner + Claude)

- [ ] Owner approves publishing v18 (Claude publishes and verifies the scripts match source, as for v17).
- [ ] Note the rollback version (v17) in STATUS.
- [ ] Owner + at least one friend play 20 minutes together: **one phone, one PC**, same server.
- [ ] One person who has never played, watched without coaching. Write down where they stall.
- [ ] Developer Console clean. `[LaunchCheck]` may list only items we've chosen to defer (badges 11–15 or music).
- [ ] Real persistence (1.6 leftover, needs the published place): owner buys the cheapest product
      once, leaves, rejoins on another server, and checks it was delivered exactly once and coins/bag/finds kept.
- [ ] Watch the newcomer for chat covering the Shop button (Codex logged it as post-launch; it becomes
      a blocker if they can't find the upgrade unaided).
- [ ] Fix only the blockers this finds, then republish.

## Phase 3: public (owner, with Claude's click-list)

- [ ] Owner: finish ID verification and 2-step verification (**start now**; it can take time).
- [ ] Claude: recheck current Roblox public-launch rules and give the owner an exact click-list.
- [ ] Owner: maturity questionnaire, devices, genre, description checked against the game.
      Group skipped for launch (11 Oct): `DIGDEEP` is off, and the live description promises no group, code or badges.
- [ ] Owner: set the experience **Public**. Friday afternoon US time is the suggested slot.
- [ ] First 72 h: Claude reads Analytics (funnel, D1, session length, errors) and lists fixes.

## Owner queue (only you can do these)

1. ID verification + 2FA on the Roblox account.
2. ~~Badges 6–10~~ done (typo fixed, descriptions added). Claude creates 11–15 on 12 Oct's free quota.
3. Approve the music picks (Claude sends three candidates per slot).
4. Line up one friend with a phone and one person who has never played.
5. Say "publish v18" and "go public" when ready.

## Post-launch (not now)

Spring Vault adventure and its open gates (see [integration/README.md](integration/README.md)),
camp/trophy UI, audio SFX swap from `assets/audio/original-v1`, native gameplay screenshots,
controller hardware test, sponsored ads, more regions from the game bible.

## Session log

| Date | Who | What moved |
|---|---|---|
| 11 Oct 2026 | Claude | Plan written; expansion frozen; Phase 1 tasks assigned |
| 11 Oct 2026 | Claude | **1.1 done** (merged `58109ef`). Blocker found and fixed: the flags-off boot still built the TROPHY CAMP pad on the plaza with live "Display trophy" prompts and a status card. World now builds it only with `AdventureRewards`. New inertness checks in `production-wiring.spec` (off): no camp/adventure parts, prompts, remote folders or tools; a fresh session writes no outbox key and grants nothing; no expansion output. Full suite green. Studio Play of a `default.project.json` build: 0 pads, nothing stray, console has no `[Adventure]`/`[Trophy]` lines (only the known LaunchCheck list). Remaining by design: the empty `AdventureOutcome`/camp remotes and empty save containers (`TrophyRecords`, `CampLayout`, `Certifications`, `AdventureProgress`) that the load reconcile adds. Next Claude task: 1.2 |
| 11 Oct 2026 | Codex | Swept 1.5 then 1.6. One confirmed blocker: paid receipts could acknowledge failed saves or regrant after the history-write crash window. Fix and regressions in [PR #43](https://github.com/hownoms/roblox-dev/pull/43); live API persistence remains pending a test place. Evidence/limits and unfixed post-launch findings: CORE_LAUNCH_SWEEP.md. |
| 11 Oct 2026 | Claude | Reviewed Codex's PR #43 (receipt markers saved with the grant; legacy saves reconciled; rebirth keeps markers; failed save on leave replays exactly once). Full suite green on `802fa0e`. Ticked 1.6; live persistence and chat-vs-Shop added to Phase 2. Next Claude task: 1.2 |
| 11 Oct 2026 | Claude | **1.4 done** (merged `826d0fb`): ids for the 5 badges the owner created (Frozen Abyss, Magma Chamber, Alien Hive, The Core, First Rebirth). Today's 5 free creations are used (next costs 100 R$, balance 85), so 11–15 wait. Live description checked: promises no badges, group or `DIGDEEP`, so the group is optional for launch |
| 11 Oct 2026 | Claude | Badge page: "Magma Chamber" typo fixed and descriptions added for 6–10 (owner OK). Group skipped: `DIGDEEP` off, LaunchCheck lists `GROUP_ID` only with an enabled group code (`3d1665b`). Preflight shows only badges 11–15 + music. Critical path written; 1.2 moved to Codex. Claude next: Phase 3 click-list, music picks, badges 11–15 (12 Oct), 1.7 |
