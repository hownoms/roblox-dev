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
Going **Public** needs only what the Limited test already required (age check + questionnaire),
so Phase 3 itself is a settings change. ID verification + 2FA + the 1,000 R$ fee (or 2 months of
Premium) are what unlock **under-16 players** (Kids/Select). For a kids' game that is most of the
audience, so start them now; they run alongside and don't block the Public switch. Music (1.3) and badges 11–15 are **not blockers**. They ride along if they're ready
when 1.7 is cut; otherwise they go in the first update. Nothing waits on them.

## Phase 1: release candidate v18 (Claude + Codex in parallel)

| # | Task | Who | Done when |
|---|---|---|---|
| [x] 1.1 | Prove the expansion is inert in the shipped boot: flags off, no adventure remotes/UI/parts reachable, no DataStore keys written | Claude | Test/assert in the suite and a Studio boot with no `[Adventure]` output. **Done 11 Oct** (`58109ef`): camp pad was shipping, now gated |
| [~] 1.2 | Map overhaul mobile performance: emulate a low-end phone in Studio, measure frame time and memory at spawn and pier, and cut or stream scenery if over the [PERFORMANCE.md](PERFORMANCE.md) budget | **Codex** (moved 11 Oct: critical path, Codex is free) | Numbers recorded and within budget |
| [x] 1.3 | Music and ambience: pick licensed Creator Store tracks for `MusicBeach`, `MusicDeep`, `Ambience`, wire ids in `Config/Sounds.luau`, check volume and the settings toggles | Claude picks, **owner approves** | Plays in Studio and the toggles work. Not a blocker: ships with v18 only if approved before 1.7. **Done 11 Oct**: owner approved the ★ picks (Beach `1845913205`, Deep `1848350082`, Ambience `9112751340` at 0.1); toggles checked in Studio |
| [x] 1.4 | Badges: 5 of 15 have ids. Art exists for 5 more (`marketing/badges/06`–`10`: FrozenAbyss, MagmaChamber, AlienHive, TheCore, FirstRebirth). The other 5 (MythicLuck, Collector, AncientRuins, BeachRegular, CoreBreaker) need art or get cut from the store copy | **Owner creates** in Creator Hub, Claude makes missing art and pastes ids | No `Id = 0` badge is promised anywhere. **Done 11 Oct** (`826d0fb`): owner made 6–10, ids pasted; the live description and badge page promise nothing else. All 15 arts exist; 11–15 get created on a later day's free quota (5/day) |
| [x] 1.5 | Core first-session blocker sweep on a fresh save: LAUNCH.md §1 checklist (chat vs Shop, toast order, off-screen arrow, Reduced Motion, full bag, upgrade) | Codex | Report of blockers only; each blocker fixed in its own PR. **Sweep reported 11 Oct**: no confirmed 1.5 blocker; evidence limits in [CORE_LAUNCH_SWEEP.md](CORE_LAUNCH_SWEEP.md) |
| [x] 1.6 | Purchase and save sweep: every pass/product grants once, survives rejoin, BindToClose saves on shutdown, no error spam with API access in Studio | Codex | Report and fixes merged. **Done 11 Oct**: one blocker fixed (PR #43, `3676be9`); the real-DataStore check moved to Phase 2 |
| [x] 1.7 | Green CI, preflight, and a v18 build from default, as soon as 1.2 merges | Claude | Commit hash recorded below. **Done 13 Oct**: `19a91ba`, full suite green, preflight 0 blocking (badges 11–15 only). Cut without 1.2: the Studio emulation stalled, so the phone check moved to Phase 2 |

## Phase 2: v18 on the Limited audience (owner + Claude)

- [x] Owner approves publishing v18 (Claude publishes and verifies the scripts match source, as for v17). **Done 13 Oct**: Roblox place version **19**, 206/206 scripts matched `19a91ba` before publish.
- [x] Note the rollback version (v17) in STATUS.
- [ ] Owner + at least one friend play 20 minutes together: **one phone, one PC**, same server.
- [ ] Real-phone performance (replaces the 1.2 Studio emulation): on the phone, Settings → Performance Stats on; about a minute each at spawn, the carnival pier and deep in the dig zone. Note FPS and F9 → Memory → Client total. Budget: ≥ 30 FPS, < 1.2 GB.
- [ ] One person who has never played, watched without coaching. Write down where they stall.
- [ ] Developer Console clean. `[LaunchCheck]` may list only items we've chosen to defer (badges 11–15 or music).
- [ ] Real persistence (1.6 leftover, needs the published place): owner buys the cheapest product
      once, leaves, rejoins on another server, and checks it was delivered exactly once and coins/bag/finds kept.
- [ ] Watch the newcomer for chat covering the Shop button (Codex logged it as post-launch; it becomes
      a blocker if they can't find the upgrade unaided).
- [ ] Fix only the blockers this finds, then republish.

## Phase 3: public (owner, with Claude's click-list)

- [x] Owner decision (11 Oct): **free route.** Launch Public to 16+ only; no 1,000 R$ fee and no Premium.
      Under-16 reach (Kids/Select) is Post-launch. ID verification and 2FA are free, so doing them now saves time later, but they unlock nothing alone.
- [x] Claude: recheck current Roblox public-launch rules and give the owner an exact click-list. **Done 11 Oct**, below.
- [x] Owner: maturity questionnaire, devices, genre, description checked against the game. **Checked 19 Oct**: questionnaire completed, label Minimal, no descriptors; genre Simulation → Incremental Simulator; 591-char description; all 8 passes listed with prices.
      Group skipped for launch (11 Oct): `DIGDEEP` is off, and the live description promises no group, code or badges.
- [x] Owner: set the experience **Public**. **Public by 19 Oct 2026** (found already saved as Public, Friends limit off; game page shows "Minimal • Ages 16+" and a Play button). Live build is still place version 19 (v18); the Phase 2 playtest happens on the public game.
- [ ] First 72 h: Claude reads Analytics (funnel, D1, session length, errors) and lists fixes.

### Click-list for going public (rules rechecked 11 Oct 2026)

Sources: [Publish games and places](https://create.roblox.com/docs/production/publishing/publish-experiences-and-places)
(fetched 11 Oct), [Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select),
[Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity),
[Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items) (updated 19 Aug 2026),
DevForum: [Kids and Select global launch](https://devforum.roblox.com/t/roblox-kids-and-select-global-launch-upcoming-updates-to-eligibility-ads-manager-and-expedited-review/4685717) (16 Jun 2026),
"Highly engaged player threshold drops to 250" (Aug 2026).

**What the rules are now.** Public has two reach levels:
- **16+ and Trusted Friends:** account in good standing and ≥ 2 days old, owner age-checked (face
  estimation or ID), questionnaire done. We already met this for Limited → Playtesters, so nothing new.
- **All ages (Kids 5–8, Select 9–15):** the above **plus** identity verification (government ID if 18+),
  2FA, **either** 2 consecutive months of Roblox Plus/Premium **or** a one-time refundable 1,000 R$
  fee per game (refunded after 25 highly engaged players held for 60 days with no moderation),
  **and** the game passes evaluation. The game starts in a 16+ trial and needs **250 highly engaged
  players within 60 days** to enter Kids/Select (Roblox also offers a paid Expedited Review; the docs
  and the DevForum disagree on its price, so check the Reach page if you want it).
- Max 5 never-public games may go public per account per day (not an issue for us).

**A. Before launch day** (owner chose the free route: only step 1 is needed now; 2–4 are for under-16 reach later)
1. Check eligibility: open `create.roblox.com/settings/eligibility/publishing-permissions`. It shows
   which requirements are met.
2. ID verification: roblox.com → **Settings → Account Info → Verify My Age** → government ID + selfie.
3. 2FA: roblox.com → **Settings → Security → 2-Step Verification** → turn on Authenticator App (preferred) or Email.
4. Fee or subscription: balance is 85 R$, so the 1,000 R$ fee needs a top-up, **or** keep/start
   Premium (needs 2 consecutive months). To pay later: Creator Dashboard → the game → **Audience → Reach**
   → *Refundable publishing fee* → **Pay** → **Pay 1,000**. (Robux spend: owner decides; Claude never pays.)

**B. Questionnaire (re-check; it may already be submitted from the Limited test)**
5. Creator Dashboard → click the game → left nav **Configure → Questionnaire** → **Start** (or **Edit**).
6. Answer per [STORE_PAGE.md §5](../marketing/STORE_PAGE.md): **No** to Violence, Blood, Fear, Crude humor,
   Gambling, Strong language, Romance, Alcohol, Social hangout, Free-form creation, Sensitive issues,
   Paid item trading, Media, AI interaction.
   **Paid random items: Yes.** Coin packs and Skip Rebirth sell coins for Robux, and coins hatch eggs/crates,
   so they count as indirect paid random items. The egg panel already shows true odds before every hatch,
   including luck (Stats.GetHatchOdds), which is what the policy requires.
7. **Save and Continue** through each page → **Questionnaire Preview** → expect label **Minimal** and no
   blocked regions → **Submit**.

**C. Settings check**
8. Studio with the published place open → **File → Experience Settings → Basic Info**:
   Genre as now; **Playable Devices: Computer, Phone, Tablet** on; **Console off** (no controller hardware
   test yet, see Post-launch); VR off. **Save**.
9. Creator Dashboard → the game → **Configure → Basic Info**: description = live text (promises no
   badges/group/code); icon and thumbnails as now.
10. **Monetization → Passes / Developer Products**: all on sale at the README prices (1.6 checked delivery).

**D. Launch day (after Phase 2 is ticked)**
11. Creator Dashboard → the game → **Configure → Settings** → **Audience** → **Public** → **Save Changes**.
    Leave *Exclude from Recommendations* unticked.
12. Open **Audience → Reach**: confirm 16+ is live and whether Kids/Select evaluation has started. Tell Claude what it shows.
13. Join from a logged-out phone browser search and an alt account to confirm it's findable and playable.

## Owner queue (only you can do these)

1. ~~Fee vs Premium~~ decided: free route, Public 16+ first. Optional: ID verification + 2FA now (free, saves time later).
2. ~~Badges 6–10~~ done (typo fixed, descriptions added). Claude creates 11–15 on 12 Oct's free quota.
3. ~~Approve the music picks~~ done (★ picks wired).
4. Line up one friend with a phone and one person who has never played.
5. Say "publish v18" and "go public" when ready.

## Post-launch (not now)

The post-launch path is now [SIX_MONTH_PLAN.md](SIX_MONTH_PLAN.md) (owner goal 19 Oct: run about six months hands-off).

Under-16 reach (Kids/Select: ID + 2FA + 1,000 R$ refundable fee or 2 months of Premium, then 250 engaged players in 60 days),
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
| 11 Oct 2026 | Claude | **Phase 3 click-list written** (rules rechecked against the live docs). Key change: Public only needs the age check + questionnaire we already have, but that reaches **16+ only**. Under-16 (Kids/Select) also needs ID + 2FA + 1,000 R$ refundable fee or 2 months of Premium, plus 250 highly engaged players in a 60-day trial. Paid random items stays **Yes** (coin packs buy egg currency; odds already shown). Music: 3 candidates per slot loaded and level-checked in Studio, sent to the owner for approval. Badges 11–15 wait for 12 Oct GMT; 1.7 waits for Codex's 1.2 |
| 11 Oct 2026 | Claude | **1.3 done**: owner approved the ★ music picks; ids wired, ambience at 0.1, toggles checked in Studio, full suite green, preflight lists only badges 11–15. Owner chose the free route: Public 16+ first, Kids/Select moved to Post-launch |
| 13 Oct 2026 | Claude | **1.7 done, v18 published** (owner said "publish"). Codex's 1.2 Studio emulation had stalled since 11 Oct with nothing committed, so the phone measurement moved into Phase 2. Full suite green and preflight 0 blocking on `19a91ba`. Rojo-synced into the Team Create place, 206/206 scripts matched the fresh build, published as Roblox place version 19. Rollback is version 17. Access unchanged (Limited). Next: owner's Phase 2 playtest, then Public |
| 19 Oct 2026 | Claude | Owner goal: a game that runs about six months hands-off. Wrote [SIX_MONTH_PLAN.md](SIX_MONTH_PLAN.md): live config switches (Experience configs), a dated content calendar shipped in one build, endgame past Rebirth 10. Going public stays step one. Nothing changed in Phase 2 since 13 Oct |
| 19 Oct 2026 | Claude | SIX_MONTH_PLAN part B built on `claude/live-config` (owner: "go public first, start on B"). `LiveConfig` reads Experience configs: codes on/off and extra codes, events off, bonus event, pauses for hatching / Auto Dig / leaderboards, announcement. Empty or failed config = game as published. New `live-config.spec` (configs set / ConfigService down); full suite green. Owner guide: LIVE_CONFIG.md. Not published, not merged |
| 19 Oct 2026 | Claude | Owner said "go public". Creator Dashboard → Manage audience already showed **Public** (Friends limit off) and "available to players ages 16+"; content rating Minimal, questionnaire complete; public game page live with Play button; 8 passes listed. Nothing was changed or saved (a mis-click on the Friends box in the dialog was cancelled, and the saved state rechecked as Public). Release candidate `9a7f556` (with live switches) passes preflight and boots clean in Studio; not published yet. Phase 2 playtest now runs on the public game |
| 19 Oct 2026 | Claude | Owner playtested ("its good") and said "publish". Published source `ec75979` as **place version 20** (rollback 19): 207/207 scripts matched the fresh build (digest `b64a6850`); ConfigService connects on the real place. Note: every unset key logs `ConfigService: Config value not found` once per server boot; creating the keys in the Creator Hub silences it |
| 20 Oct 2026 | Claude | Part C merged (89bce09: calendar + endgame; mastery skips Seasonal). Studio check: egg stand moved off plaza props; fixed Format.Abbreviate dropping whole-number zeros. Owner said publish: source `cb3eb05` is **place version 21** (rollback 20), 211/211 scripts matched (digest `b39b2c80`). Pause keys created in Configs (False) |
