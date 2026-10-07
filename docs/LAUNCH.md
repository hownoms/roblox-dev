# Launch runbook: Dig to the Core! Beach Simulator

The ordered path from this repo to a public experience. Each step says who does it. "Owner"
steps need the Roblox account and Creator Hub; nothing in the repo can do them. Release gates
and their evidence live in [POLISH_RELEASE_GATES.md](POLISH_RELEASE_GATES.md); this file is the
checklist that ties them together. Publishing is the owner's decision, made explicitly. Nothing
here authorizes it on its own.

Run `tools/preflight.sh` at any time. It lists every id and asset that is still a placeholder
and fails if something that must not ship is switched on. Live servers print the same summary
once at boot as a `[LaunchCheck]` warning in the Developer Console.
`tools/preflight.sh strict` fails until every placeholder is filled; run it right before the
public launch.

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
- [ ] Data: join, earn, leave, rejoin; two Studio servers on one account (session lock);
      shutdown during play (BindToClose save).
- [ ] At least one fresh-player session watched without coaching (where they stall, whether
      they keep playing after the first upgrade).

## 2. Creator Hub setup (owner)

1. [ ] Publish the place (File → Publish to Roblox). Max Players **16**. Genre Simulation.
2. [ ] Game Settings → Security: **Enable Studio Access to API Services** on; HTTP off;
       third-party sales off.
3. [ ] Game passes: create the 8 passes in `src/shared/Config/Monetization.luau`
       (README §2 has names and suggested prices); paste each id.
4. [ ] Developer products: create the 6 products; paste each id.
5. [ ] Badges: create the 10 badges in `src/shared/Config/Badges.luau` (art in
       `marketing/badges/`); paste ids. Awards retry automatically after a BadgeService
       failure (30 s, 2 min, 10 min).
6. [ ] Group: create the Roblox group; paste its id into `GROUP_ID` in
       `src/shared/Config/init.luau` (turns on the group sand bonus and the `DIGDEEP` code).
7. [ ] Audio (optional but recommended): upload or pick owned/Creator Store audio for
       `MusicBeach`, `MusicDeep` and `Ambience` in `src/shared/Config/Sounds.luau`. Ambience
       loops at the surface and follows the Sound Effects setting; music follows the Music
       setting. Grant the experience permission to use each asset and listen in Studio.
8. [ ] Re-run `tools/preflight.sh strict` until it passes; commit the ids; republish.

## 3. Store page (owner)

- [ ] Icon and thumbnails: upload `marketing/icon.png` and `marketing/thumbnails/`. Prefer
      real gameplay captures once the game is representative; see the art findings in
      POLISH_RELEASE_GATES.md (the generated thumbnails are illustrations).
- [ ] Description, keywords and badge copy from `marketing/STORE_PAGE.md`; recount
      collections and check every claim against the game.
- [ ] Experience Questionnaire: answer as described in STORE_PAGE.md. No Robux item sells a
      random outcome since v2.3; coin packs and Skip Rebirth are still marked paid-random
      (they buy currency that buys eggs) and are hidden for policy-restricted players.
- [ ] Devices: Phone, Tablet, Computer, Console.
- [ ] Private servers on (suggested 50–100 R$/month).

## 4. Soft launch (owner)

- [ ] Keep the experience private or friends-only for a first real session on a phone and a
      PC. Check loading, safe areas, dig/scan/excavate/sell, panel scrolling, and purchases
      (one cheap product end to end).
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
