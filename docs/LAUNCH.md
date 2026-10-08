# Current launch route — 8 October 2026

Owner account age check is **COMPLETE** by owner report; no published test experience identity exists. Older age-check/no-setup wording below is historical. No publication, uploads, audience/access changes, spending or tester contact is authorized. [TEST_EXPERIENCE_PROPOSAL.md](TEST_EXPERIENCE_PROPOSAL.md) is the concrete reviewable proposal: new dedicated owner-only Private test experience, Computer initially, Max Players 16/first coordinated test four, existing data names isolated by universe, optional IDs disabled. Later Limited → Playtesters plus named Play-only grants requires separate explicit access authorization.

Finish the remaining ordinary Shell Bed/HOT/full Reduced Motion, off-screen guidance/contact and four-client natural tide/reward checks. A successful Wet Sand dig banner at the target boundary while the avatar root was near 17 m and Reduced Motion ON digging/selling are partial evidence. Excavation/toast fix has 1,388 client mock passes but needs fresh live retest. Server profiler labels are ready; spike attribution remains open. Real save/rejoin/lock/interruption/shutdown checks await authorized identity; Universe 0/in-memory fallback does not pass them. Audio listening, independent feedback and physical phone/controller checks remain unperformed, hardware deferred.

The linked proposal records official Roblox publishing/access requirements rechecked 8 October 2026 with unchanged requirements; recheck before account setup changes. Confirm standing/account age/questionnaire, truthful devices and audience reach. Optional disabled/unpromised features need not block limited core testing. No invitation or public-launch readiness is claimed.

8 October fresh Studio setup reconnected DigTest/Rojo 34872 and enabled Reduced Motion before digging, then paused at the owner's request to finish repository/CI while the desktop was in use. No new successful dig/live toast retest is claimed. Combined local client/server/Studio/utility checks **1,388 / 2,174 / 2,153 / 8** passed; PR #17/#18 merged as `b07bb97`/`904d6a7` after successful CI runs `37773554284`/`37773641661`. PR #19 source `8633dc0` passed CI `37774410859` and merged as code-source checkpoint `aa22ebb`; seven terrain-error regressions verify balanced labels and preserved original errors.

The concrete owner-only Private publication proposal is ready for explicit approval and may proceed before remaining local gameplay gates to enable real persistence testing. External access/invitations remain gated by the outstanding gameplay, service and permitted-account checks. Last Studio observation was active Play; Stop/save remains pending while desktop input is paused at the owner's request.

Latest integrated validation: client **1,388**, server **2,174**, Studio-mode **2,153**, utility **8**, all passed. Full formatting, strict analysis (two existing deprecated API warnings), sourcemap and build passed. The documentation-only stage follows code-source checkpoint `aa22ebb`; merge it before packaging from the clean synchronized default branch. The generated manifest will identify the exact final documentation/source revision and SHA-256; package regeneration is not yet claimed. Gameplay, service, capture and access gates above remain open.

---

# Launch runbook: Dig to the Core! Beach Simulator

## Current limited-test route — 7 October 2026

Start with [LIMITED_PLAYTEST.md](LIMITED_PLAYTEST.md) and [PLAYTEST_EVIDENCE.md](PLAYTEST_EVIDENCE.md). Owner reports account age check COMPLETE; no published test identity exists. No publication/access authorization has been given. Missing optional passes/products/badges/group/ambience do not block a useful core-loop test while disabled and unpromised.

Current [Roblox publishing documentation](https://create.roblox.com/docs/production/publishing/publish-games-and-places) supersedes older private-test advice below: Private is owner/Edit only; Playtest permission requires **Limited → Playtesters**. The initial 16+ / Trusted Friends route requires good standing, a two-day-old account, age check and completed maturity/compliance questionnaire. All-ages reach has additional eligibility/evaluation; see [Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select). Owner performs account verification. No payment is necessary for the initial 16+ route.

The ordered path from this repo to a public experience. Each step says who does it. "Owner"
steps need the Roblox account and Creator Hub; nothing in the repo can do them. Release gates
and their evidence live in [POLISH_RELEASE_GATES.md](POLISH_RELEASE_GATES.md); this file is the
checklist that ties them together. Publishing is the owner's decision, made explicitly. Nothing
here authorizes it on its own.

Run `tools/preflight.sh` at any time. It lists every id and asset that is still a placeholder
and fails if something that must not ship is switched on. Live servers print the same summary
once at boot as a `[LaunchCheck]` warning in the Developer Console.
`tools/preflight.sh strict` fails until every placeholder is filled; use it for a fully configured
public launch. Disabled optional features may remain unset if store copy promises only the enabled scope.

## 0. Repo health (automatic)

- [ ] CI is green on the branch you publish from (`.github/workflows/ci.yml`: format, strict
      typecheck, Rojo build, headless tests, preflight).
- [ ] Locally: `tools/check.sh` says ALL CHECKS PASSED and `tests/run.sh` says ALL TESTS PASSED.
      On Linux, `tools/setup_toolchain.sh` installs the pinned toolchain.

## 1. Gameplay sign-off in Studio (owner + Claude/Codex)

Follow [POLISH_ROADMAP.md](POLISH_ROADMAP.md): one issue per stage, ordinary input first.

- [ ] Complete unassisted first session in DigTest: spawn → equip → dig → scan/excavate →
      reveal → full bag → sell → upgrade/equip, with sound on and again with Reduced Motion.
- [ ] Off-screen guidance: fill the bag while facing away from the sell stand; the edge arrow
      leads you there and hides once the stand is on screen.
- [ ] PC chat: open chat at spawn; it sits bottom-left and no longer covers Shop.
- [ ] Reveal + toasts: sell into an affordable upgrade during a discovery card; the upgrade
      toast appears after the card closes, never over the rarity headline.
- [ ] Multi-client: Test → Clients and Servers with 4 players: shared beach, tide refill,
      server dig goal, friends bonus, nameplates.
- [ ] Data: join, earn, leave, rejoin; dedicated real-server competing-session diagnostics (session lock);
      shutdown during play (BindToClose save).
- [ ] At least one fresh-player session watched without coaching (where they stall, whether
      they keep playing after the first upgrade).

## 2. Creator Hub setup (owner; conditional feature checklist)

1. [ ] Publish the place (File → Publish to Roblox). Max Players **16**. Genre Simulation.
2. [ ] Game Settings → Security: **Enable Studio Access to API Services** on; HTTP off;
       third-party sales off.
3. [ ] If enabling paid passes: create the 8 passes in `src/shared/Config/Monetization.luau`
       (README §2 has names and suggested prices); paste each id.
4. [ ] If enabling developer products: create the 6 products; paste each id.
5. [ ] If promising badges: create the 10 badges in `src/shared/Config/Badges.luau` (art in
       `marketing/badges/`); paste ids. Awards retry automatically after a BadgeService
       failure (30 s, 2 min, 10 min).
6. [ ] If enabling group perks: create the Roblox group; paste its id into `GROUP_ID` in
       `src/shared/Config/init.luau` (turns on the group sand bonus and the `DIGDEEP` code).
7. [ ] Audio (optional but recommended): upload or pick owned/Creator Store audio for
       `MusicBeach`, `MusicDeep` and `Ambience` in `src/shared/Config/Sounds.luau`. Ambience
       loops at the surface and follows the Sound Effects setting; music follows the Music
       setting. Grant the experience permission to use each asset and listen in Studio.
8. [ ] Run ordinary `tools/preflight.sh` for a reduced-scope core test. Use `tools/preflight.sh strict` for a fully configured launch; fill only enabled/promised feature IDs for reduced scope. Commit the configuration; republishing requires explicit authorization.

## 3. Store page (owner)

- [ ] Icon and thumbnails: upload `marketing/icon.png` and `marketing/thumbnails/`. Prefer
      real gameplay captures once the game is representative; see the art findings in
      POLISH_RELEASE_GATES.md (the generated thumbnails are illustrations).
- [ ] Description, keywords and badge copy from `marketing/STORE_PAGE.md`; recount
      collections and check every claim against the game.
- [ ] Experience Questionnaire: answer as described in STORE_PAGE.md. No Robux item sells a
      random outcome since v2.3; coin packs and Skip Rebirth are still marked paid-random
      (they buy currency that buys eggs) and are hidden for policy-restricted players.
- [ ] Devices: enable only supported/tested devices; phone/controller hardware remains deferred.
- [ ] Private servers/pricing are optional owner decisions; unnecessary for the core test.

## 4. Soft launch (owner)

- [ ] Use the authorized Limited → Playtesters audience for a first real session on a phone and a
      PC. Check loading, safe areas, dig/scan/excavate/sell, panel scrolling, and purchases
      (end-to-end receipt/entitlement checks only if enabling paid offers).
- [ ] Phone and controller hardware checks (deferred until hardware is available; emulators
      do not close this gate).
- [ ] Watch the Developer Console for errors and the one-line `[LaunchCheck]` summary
      (it should be gone once every id is filled in).
- [ ] Performance on a populated server: see [PERFORMANCE.md](PERFORMANCE.md) budgets.

## 5. Public launch (owner)

- [ ] Make the experience public. Launching on a Friday afternoon (US time) suits the audience.
- [ ] Turn on Roblox Managed Pricing for developer products after launch.
- [ ] Start sponsored ads at a small daily budget for about 3 days; scale only if D1 > 15% and
      playtime > 10 min. ([GDD.md](GDD.md) §11 has the full plan.)
- [ ] Watch Creator Hub Analytics: the onboarding funnel ([ANALYTICS.md](ANALYTICS.md)),
      D1/D7 retention, session time and conversion. Fix the first-session funnel first.
- [ ] Enable milestone codes (`1KLIKES` etc. in `Config/Codes.luau`) as they are reached.
