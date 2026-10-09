# 00 — Dig to the Core: game bible

Version 1.0 design draft · 8 October 2026 · Owner: Howard · Working product title: Dig to the Core!

## What this book is

This is the central design specification for expanding the existing Roblox digging game into a bright, funny discovery adventure. It explains the current game, the intended future game, every proposed launch-content record, systemic rules and a staged route between them. It is a book-sized specification, not authorization to implement, purchase, publish or change live player data.

The owner approved designing the complete future game as proposals. The owner confirmed: keep foundational digging; expand extreme tools, mounts, regions, biomes, NPCs and spontaneous events; make repeat attempts meaningfully different, including other players; use bright comedy and increasingly strange discoveries; competition is optional and permanent possessions are protected.

**The player promise:** Start with a bucket on a normal beach. Dig into an increasingly impossible world. Discover things that become adventures. Bring friends, bring ridiculous equipment, and bring back something worth showing.

**The short pitch:** You never know what your next hole will lead to.

## How to read it

- Chapter 01: existing implementation, exact baseline behavior, strengths and transition decisions.
- Chapter 02: full future game, world structure, session loops, progression and universal rules.
- Chapter 03: finite future launch catalog—regions, biomes, NPCs, tools, mounts, discoveries, events, cosmetics and quests.
- Chapter 04: detailed mechanics, economy, interface, data, multiplayer and content-production contracts.
- Chapter 05: migration, dependency order, implementation milestones, validation and launch gates.
- Chapter 06: every existing named catalog record, summary tables and exact individual definitions.
- Chapter 07: complete copies of all 27 current shared configuration modules, including formulas, keyed monetization records, presentation values and default player data.

GAME_BIBLE.html is the readable local book. GAME_BIBLE_COMPLETE.md is the single-file archival version. current-catalog.json is the machine-readable existing catalog. baseline-manifest.json records source hashes. tools/build_game_bible.py regenerates the baseline appendices and book from the maintained chapters; it does not change gameplay.

## Authority and status labels

**CURRENT** means verified in the repository or attributed to a dated evidence record. It does not mean independently playtested with the target audience. **TARGET** means the proposed future rule, consistently specified here, awaiting owner acceptance and implementation. **TUNE** means an explicit prototype starting value, not measured or validated balance. **LATER** means deliberately outside the finite target release. **GATE** means evidence required before advancing a stage.

This book becomes the product design authority when accepted by the owner. Until then it is a complete proposal. For the running game, current code and configuration remain the behavior authority; docs/STATUS.md remains the sole current operational-status tracker. The historical GDD and V2/design documents describe earlier versions and are not silently rewritten as future truth. docs/ARCHITECTURE.md remains the existing implementation contract; proposed changes here must be reviewed and applied to it when implemented.

Every future entity has a stable ID. Display names may change; IDs must not. Catalog rules inherit the common contracts in chapter 04. A row specifying an exception overrides its common default. Unlisted content is not part of the target release. Builders may not silently invent another currency, combat system, region or pet class.

## What “recreate from this book” means

The book specifies a mechanically equivalent playable game: entity catalogs, interactions, state transitions, rewards, unlocks, failure rules, interfaces and acceptance conditions. Existing configuration is preserved exactly. Target art direction and asset briefs specify what new assets must depict; finished models, animation, sounds and scripts still need production. Exact visual reconstruction of the current map additionally requires the repository's builders, source models and owned assets. A design document cannot reproduce binary artwork, backend operations or validated balance by itself.

Technical production must resolve platform-specific details against current Roblox documentation at implementation time. No load capacity, retention, price, eligibility or commercial outcome is guaranteed here. The design deliberately distinguishes desired experience from evidence.

## The boundaries that keep the vision coherent

1. Digging remains the primary action. New content emerges from finding, opening, moving or changing something through digging.
2. Discoveries can start activities; not everything reduces to sale money.
3. Depth changes interaction as well as appearance and value.
4. Players can relax, explore or join in without entering compulsory competition.
5. Friends create opportunities; the game remains viable alone and with a quiet server.
6. Permanent possessions, accepted rewards and paid entitlements survive failure, disconnects and prestige.
7. Comical hazards create decisions without gore, humiliation or mandatory theft.
8. New mechanics appear through visible demonstrations before menu explanations.
9. An enormous vision ships through small proven slices. The full catalog is a destination, not one development batch.
10. Every major addition must change a decision, create an interaction or give a player something personal to care about.

## Decision register

| Decision | Status | Basis |
|---|---|---|
| Keep digging and discovery foundation | OWNER CONFIRMED | Owner's latest direction |
| Bright, funny adventure | OWNER CONFIRMED | Owner's questionnaire answer |
| Optional competition; permanent possessions protected | OWNER CONFIRMED | Owner's questionnaire answer |
| Fully design new content as proposals | OWNER CONFIRMED | Owner's questionnaire answer |
| Retain current public title during development | TARGET | Avoid changing positioning before a playable slice |
| Persistent shared beach plus short discovery adventures | TARGET | Reconcile relaxed progression and varied attempts |
| Five regions and twenty biome bands in complete target | TARGET | Finite scope defined in chapter 03 |
| No new spendable currency in first expansion | TARGET | Reduce comprehension and economy risk |
| Replace mandatory rebirth gates with adventure certification | TARGET | Show the promised world without compulsory repeated resets |
| Replace routine heat penalty with event-local environmental challenges | TARGET | Keep beach flavor while centering discovery |
| New mounts earned deterministically | TARGET | Ensure exciting mechanics are reachable, not lottery-only |
| No trading, permanent theft or open PvP at target launch | TARGET | Preserve tone and reward safety |

Changes must update the relevant catalog, rule, implementation milestone and decision register together. Do not leave conflicting versions scattered across documents.
