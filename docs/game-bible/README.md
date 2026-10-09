# Game plan — start here

This folder contains the complete game bible for expanding **Dig to the Core!** while preserving its digging foundation. It is checked into the workspace as ordinary repository documentation, so contributors can read it without a special app or account.

## Read the plan

- [Game bible introduction and decision register](00-start-here.md)
- [Current game and keep/change/add/retire decisions](01-current-game-and-gap.md)
- [Future game, loops, world and progression](02-future-game.md)
- [Future content catalog](03-future-content-catalog.md)
- [Mechanics, economy and implementation specifications](04-mechanics-economy-and-production.md)
- [Implementation roadmap and validation gates](05-roadmap-validation-and-handoff.md)
- [Existing content encyclopedia](06-current-content.md)
- [Exact baseline configuration reference](07-baseline-source.md)

[Read the entire book as one Markdown document](GAME_BIBLE_COMPLETE.md), or open [the formatted HTML book](GAME_BIBLE.html) locally in a browser. Individual chapters are the maintained design source; the combined book and HTML are generated reading copies.

## For anyone working on the game

1. Read [STATUS.md](../STATUS.md) to understand current implementation and evidence.
2. Read the bible introduction, then the current-game transformation matrix and roadmap.
3. Find the milestone relevant to your task. Read its feature specifications and catalog records before building.
4. Follow [ARCHITECTURE.md](../ARCHITECTURE.md). Proposed new services/interfaces in the bible require updating that contract when implemented.
5. Preserve existing saves, stable IDs, owned items and purchased entitlements. Do not infer that new proposals authorize destructive migrations or publication.
6. Complete the milestone's deliverables and validation gate before advancing. Record actual evidence and unresolved issues; a checked box alone is not proof.
7. Keep operational progress in STATUS.md and observations in the appropriate playtest record. Update the bible when an accepted design changes.

## Milestone checkpoints

These are a navigation checklist, not a second progress tracker. All expansion implementation remains pending unless STATUS.md records evidence otherwise. Each checkpoint links to its detailed work and acceptance gate.

- [ ] [0 — Agree on the design and preserve the baseline](05-roadmap-validation-and-handoff.md#milestone-0--agree-and-preserve)
- [ ] [1 — Observe players and close critical baseline gaps](05-roadmap-validation-and-handoff.md#milestone-1--observe-the-baseline-and-close-critical-gaps)
- [ ] [2 — Safe data migration and persistent trophies](05-roadmap-validation-and-handoff.md#milestone-2--safe-data-and-trophy-slice)
- [ ] [3 — Giant discovery and first specialist-tool slice](05-roadmap-validation-and-handoff.md#milestone-3--giant-discovery-vertical-slice)
- [ ] [4 — Varied attempts and cooperative hauling](05-roadmap-validation-and-handoff.md#milestone-4--different-attempts-and-hauling)
- [ ] [5 — First-session and progression integration](05-roadmap-validation-and-handoff.md#milestone-5--first-session-and-progression-integration)
- [ ] [6 — Bloomwild region and first earned mount](05-roadmap-validation-and-handoff.md#milestone-6--bloomwild-and-first-earned-mount)
- [ ] [7 — Optional fair competition](05-roadmap-validation-and-handoff.md#milestone-7--optional-competition)
- [ ] [8 — Frostfloat and Emberworks regions](05-roadmap-validation-and-handoff.md#milestone-8--frostfloat-and-emberworks)
- [ ] [9 — Odd Orbit and the Core finale](05-roadmap-validation-and-handoff.md#milestone-9--odd-orbit-and-core-finale)
- [ ] [10 — Complete content and live operations](05-roadmap-validation-and-handoff.md#milestone-10--full-content-and-live-operations)

## Design status

Owner-confirmed direction: keep digging; bright, funny adventure; increasingly strange discoveries; optional competition; protected permanent possessions. Specific new catalog entries and balance values remain proposals. **CURRENT** identifies baseline evidence; **TARGET** identifies future design; **TUNE** identifies values requiring playtesting; **GATE** identifies required validation.

The bible's exact configuration snapshot is dated 8 October 2026. It is historical reference, not a replacement for current runtime configuration. Do not claim a new feature exists merely because it appears in the future catalog.

## Maintaining the reading copies

From the roblox-dev directory, `python tools/build_game_bible.py` rebuilds the HTML, combined Markdown and current-config exports. This also refreshes baseline snapshots from the local source, so only run it when deliberately updating that reference and its date/version descriptions. `python tools/verify_game_bible.py` checks the existing snapshot/catalog counts, source hashes, future references and navigation. Update the verifier's expected catalog counts when an accepted catalog changes.

Current evidence stays in STATUS.md. The milestone checkboxes here may be marked only alongside the corresponding recorded completion evidence; do not maintain competing narrative status summaries.
