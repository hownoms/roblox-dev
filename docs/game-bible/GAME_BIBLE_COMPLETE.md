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


---

# 01 — Current game and the transformation

Status: CURRENT baseline with TARGET disposition. Source snapshot: 8 October 2026. The dated baseline here is reference evidence; ongoing operational changes belong in STATUS.md.

## Existing build

STATUS reports live place version 17, source 375625c, with 157 published scripts checked byte-identical to the merged implementation. Experience 10769863381; start place 135511260983800. Current capacity is 16 players. Publishing access remains Limited. Artwork is the approved bacon-hair kit; artwork approval is separate from gameplay validation.

The implementation uses strict Luau, a Rojo project, centralized shared configuration, server services, client controllers and procedural models/world builders. The existing architecture prohibits external packages and unowned assets. The expansion should work within this foundation; any deliberate architecture changes must be recorded before implementation.

The current named catalogs contain 15 layers, 14 shovels, 13 backpacks, 56 pets, 13 eggs/crates, 53 treasures, 12 quests, seven rarities, seven shades, seven consumables, eight rebirth perks, six boosts, two scheduled reward events and fifteen badge definitions (five have nonzero configured Roblox IDs; ten remain unconfigured). Four codes, seven daily rewards and fifteen depth titles are also configured. All individual records, nested looks, loot tables and rewards appear in chapters 06–07. This review found no dedicated implemented NPC dialogue/quest framework in the world/services searched; shop prompts are not evidence of the future named characters existing.

## Actual core loop

The beach is one shared mutable strip, not personal plots. The dig footprint is 768 by 56 studs. Surface Y is 1024; total layered depth is 1,000, leaving the bottom at Y24. The UI uses one stud as one displayed meter. The map's boardwalk is inland, the sea is toward negative Z, and the hub is beyond the boardwalk. The initial sell station is behind the spawn-facing dig direction; v17 added a tutorial camera turn to improve that transition.

A server-validated manual dig checks cooldown, world bounds/floor, reach, layer hardness, capacity and remaining solid terrain. The equipped shovel gates hardness. Terrain is carved in voxel-aligned cubes clamped to dig boundaries. A successful dig produces sand using layer value and shovel, pet, rebirth and other multipliers; it updates depth and broadcasts carve/dig signals. Sand sells at one coin per sand unit. The configured starter bag is 20; pass multipliers explain screenshots showing different capacities.

Buying a shovel increases power, radius, speed and/or sand yield. Backpacks increase capacity. Most late tools have rebirth requirements; Core Breaker requires ten. The player can return to the surface with a dedicated action. Holes refill after inactivity (240 seconds with a 12-stud clear radius in configuration), and tide systems also restore terrain. This is not persistent individual tunnel ownership.

## Discovery subsystem

Deposits are lazily seeded into 32×16×32-stud chunks. The cap is sixteen deposits per chunk and 4,000 per server, with five-stud separation, replenishment of one per 90 seconds and eviction of untouched empty-neighborhood chunks after 300 seconds. Density varies by layer and compensates for larger/faster shovels. Seeded item identity uses layer loot weights; owner luck changes variants when uncovered. A 1/400 relic opportunity exists per deposit, subject to eligible relic layers.

Scan has a 24-stud range, six-second active period, eight-second start-to-start cooldown and half-second updates. It reports distance bands and coarse direction/vertical relation. The v17 overhead fix instructs DIG DOWN HERE where appropriate. An owner's dig within three studs of a deposit uncovers it; the first uncoverer owns the excavation. Other players can see but cannot help or take it.

Excavation has three 0.9-second shrinking rings with 0.25-second gaps. Good taps are within 0.22 seconds of target, Perfect within 0.09. Grades score one/two points; Good item quality begins at score two, Pristine at five; misses never destroy the item. An impossibly fast finish caps quality at Good. A nine-second timeout resolves as damaged. Quality multiplies item value by 0.6/1/1.5. The new player's sixth successful dig guarantees a Common find.

Size base weights: Tiny20, Normal62, Large14, Giant4; value multipliers 0.5/1/2/5. Material weights: ordinary88, Golden7, Fossilized3.5, Crystal1.5; value multipliers 1/3/5/10. Luck modifies positive variant weights through one shared displayed-and-rolled odds function. Unsold variant counts live in Finds; Index and FindVariants preserve discovery history. Ordinary reveals remain about five seconds; Mythic/Relic spectacle twelve. Selling clears unsold finds with sand. Tiny ambient Common drops can occur between deposits. Companion and ride digging does not uncover deposits; Auto Dig does.

## Pets, mounts and support systems

Pets are a combined collection of creatures and construction vehicles. Equipped bonuses add contributions above one rather than multiplying each pet's whole multiplier. Base equip slots are three; inventory cap 200; passes/perks can expand slots. Some companions perform sand-producing digs near their owner. Five identical non-Golden pets fuse into a Golden version; Golden boosts the pet's additive bonus and dig speed. Egg/crate pity counters guarantee a Rare-or-better outcome after configured unsuccessful streaks. Exact weights and pity limits are in the existing catalogs.

The Mega Excavator is rideable; current ride movement is restricted near the beach surface and boardwalk. It bridges holes rather than traversing the full underground world. Max speed18 studs/s; it digs ahead within surface-depth constraints. It is not an implemented cavern exploration mount.

Heat is a soft sunburn slowdown, not damage/death. New players get 180 seconds of grace. Sun and digs raise it, shade/underground/hub cool it. Sunburn at100 persists until40 and multiplies dig cooldown by1.6. Water is free at the fountain; shades and snacks provide cooling/temporary benefits. This is a routine environmental economy separate from discovery.

Offline income uses equipped digging pets, reached/power-eligible layers, a five-minute minimum absence, two-hour base cap and40% base efficiency; Long Nap extends it. It grants coins, not autonomous rare discoveries. Quests award fixed or depth-scaled rewards. Daily rewards use a20-hour claim cooldown and48-hour streak grace. Titles track deepest layer. Server goals aggregate sand to trigger Golden Hour; friend presence provides a capped output bonus. These are useful support systems but little direct cooperation.

## Rebirth and paid benefits

Rebirth one costs500K, then approximately2.8M,15M,85M and470M; subsequent growth follows the configured3.3 factor. Each gives a permanent +0.5 multiplier and token reward starting at two, with later increases. A separate first-rebirth quest grants two additional tokens when claimed. Reset money, sand, ordinary shovel/backpack ownership and unsold finds; keep pets, records, collection history, perks and other persistent systems. Perks can restore starting equipment, retain backpacks or permit selling anywhere.

Configured passes include convenience/output/slots. Developer products include deterministic grants of resources/boosts; purchases indirectly supplying currencies usable on random eggs require the existing policy controls. Runtime configured marketplace IDs exist despite older header comments describing placeholders. Configured suggested prices are not a verified live-price snapshot. All records are copied exactly in chapter07. Do not redesign purchased entitlements away without a compatible benefit and explicit owner decision.

## Evidence and limits

Recorded checks include fresh no-pass Studio dig/find/scan/sell/upgrade, real owner save/leave/rejoin on another server, two local Studio clients with isolated find rewards, extensive static visual galleries and large automated suites. These do not establish independent newcomer comprehension, excavation comfort, retention or populated production performance. Open checks include listening/integrating audio, live multiple accounts, natural tide/recovery, moving contact, phone/controller use and independent playtests. The current source is technically mature relative to the evidence of audience appeal.

## Keep/change/add/retire matrix

| System | Decision | Target behavior | Migration/dependency |
|---|---|---|---|
| Manual digging and physical terrain | KEEP/EXTEND | Universal action across all adventures | Region-aware bounds and protected structures |
| Scanner and forgiving excavation | KEEP/EXTEND | Personal finds plus event/landmark hints | Different discovery classes; cooperative event flow |
| Private finds | KEEP | Owner-safe routine discoveries | Keep existing ownership rules |
| Giant communal discoveries | ADD | Shared contribution and personal grants | EventService and reward receipts |
| Fifteen original depth layers | KEEP/ENRICH | Main beach depth spine with living interactions | Preserve IDs and visited records |
| Existing shovel/backpack ownership | KEEP | Legacy progression plus specialist abilities | Equip loadout independent from ownership |
| Mandatory rebirth gates | ADJUST | Certification unlocks adventure; prestige optional | Entitlement/legacy mapping; economy calibration |
| Rebirth perks and tokens | KEEP/ADAPT | Optional prestige advantages, not admission fees | No destructive token conversion |
| Random pets/crates | KEEP AS SIDE COLLECTION | Companion identity and modest support | No new essential mount lottery |
| Rideable excavator | ADJUST | Explicit surface vehicle; later bounded cavern equivalent | Preserve owned pet/pass effects |
| Selling all physical finds | ADJUST | Payout plus persistent trophy record | Idempotent trophy granting; best-record migration |
| Heat slowdown | RETIRE FROM ROUTINE | Environmental challenges local to optional events | Keep owned shade/snacks; equivalent usable benefits |
| Shade/snacks | REPURPOSE | Cosmetic camp comfort and optional activity utility | No lost items, no purchasable friction relief |
| Global output events | KEEP/ENRICH | Quiet bonuses plus discovery-triggered activities | Shared scheduler and stacking limits |
| Passive server counter | ADJUST | Counts toward visibly opening a shared landmark | Equivalent per-player credit avoids veteran domination |
| Daily chores | REDUCE EMPHASIS | Three optional rotating adventure suggestions | Protect claimed historical rewards |
| NPCs and region travel | ADD | Characters guide discoveries and unlock activities | NPC and Adventure services |
| Mounts, customization, trophies | ADD | Deterministic earned mechanics and identity | Stable inventories/placement validation |
| Trading, open PvP, permanent theft | EXCLUDE | Optional isolated contests only | No target-launch implementation |
| Audio and movement polish | FINISH | Clear physical feedback and readable cues | Existing evidence gaps first |

## Why the new game can be stronger

The current reveal sequence already creates anticipation. The expansion gives it consequences: a discovery opens a chamber, introduces a character, activates a machine, changes a route or attracts other players. A returning player can pursue a different activity with different people instead of only repeating the same economic ladder faster. That is the working hypothesis. The milestone gates test it rather than assume it.


---

# 02 — The complete future game

Status: TARGET. All numerical targets are TUNE unless explicitly inherited from current code. The finite full release is defined here; roadmap stages determine when each part ships.

## Fantasy, audience and tone

Players are ordinary Roblox visitors who become improbable explorers. The world begins in bright daylight with understandable sand, a shovel, a bucket and a shop. Each descent reveals something less plausible: pirate compartments, dinosaurs, living mushrooms, icebound machines, lost cities and an alien postal service. The Core is a strange destination with an earned finale, not merely an unbreakable floor.

Primary intended audience is players who enjoy collecting, exploration and social surprises, with an initial design focus on ages 9–15 and mobile-friendly sessions. This is design intent, not platform age eligibility. Secondary audiences include friend groups, parents joining children, casual completionists and creators looking for understandable situations. Do not require voice chat, fast reading, spending or an established friend group.

Comedy comes from scale, character reactions and consequences: a tiny chest contains a giant rubber duck; a serious captain cannot navigate; a beetle insists it is a truck. Hazards are readable and recoverable. Characters may be startled, launched gently or returned to safety. No gore, hostile player humiliation or loss of paid/permanent possessions. Mystery can be eerie without becoming a horror identity.

The player's own Roblox avatar remains their character. Marketing uses the exact classic bacon-hair outfit already approved; do not force all players into that outfit in gameplay. NPCs use distinct blocky silhouettes, expressive simple faces and restrained visual detail. Saturated, flatter illustration-style publishing art must depict mechanics that are actually available in the represented release.

## Three compatible ways to play

**Relax:** Dig routine deposits, sell materials, collect variants, personalize the camp and improve equipment. No timer threatens the player's collection.

**Explore:** Follow a special signal, open a landmark, meet an NPC and complete a short adventure. Choose a route or tool approach. A complete story has a beginning and ending within a session.

**Join in:** Respond to a nearby giant discovery, help another player, enter an optional fair contest or join a crew adventure. Shared play changes what happens; a player can decline without losing access to the ordinary world.

These are priorities, not separate compulsory modes. A player can dig casually and voluntarily join a five-minute encounter. Invitations explain objective, duration, rewards and any temporary setback before entry. An event cannot capture a player's ordinary activity by silently placing them into competition.

## Loop hierarchy

| Time scale | Activity | Payoff | Next decision |
|---|---|---|---|
| 3–10 seconds | Swing, scan, tap, reveal | Responsive feedback and small find | Continue digging or follow a signal |
| 30–90 seconds | Clear a deposit, fill bag, inspect find | Sale, collection entry, visible progress | Sell, choose a tool, approach a landmark |
| 4–8 minutes | Complete a discovery encounter | Shared story, trophy, useful unlock progress | Replay differently, explore or return to camp |
| 10–25 minutes | Pursue a chosen expedition and improvement | New interaction/equipment or chapter progress | Choose the next goal |
| Multiple visits | Complete a region chapter or collection | Region access, signature tool/mount, identity | Explore a new region or specialize |
| Long term | Master alternate routes and collections | Records, customization and optional prestige | Play with others and pursue self-chosen challenges |

These are pacing targets, not measured times. Never slow a short action merely to hit session length. If an activity is enjoyable, allow replay; if not, change the activity rather than attach an obligatory reward timer.

## World topology

The main world is Sunshine Shore and its original 1,000-meter depth spine. Keep its existing fifteen layer IDs and records. Add meaningful landmarks in those bands, not fifteen separate enormous maps. Four satellite regions provide different physical rules: Bloomwild Basin, Frostfloat Shelf, Emberworks Isle and Odd Orbit Atoll. Their complete roster is chapter 03.

Region travel occurs from the hub expedition pier after deterministic story certifications. Owned-region checkpoints permit direct return. The main beach remains a social home with the most population, tutorial and public trophy displays. Satellite travel is a short fade/load to an authored region; final place-vs-same-server deployment must be decided from performance measurements. The first two stages use one server and a bounded nearby event arena to avoid unnecessary teleport infrastructure.

Full target supports up to 16 players in a social world; private adventure parties contain 1–4; cooperative public landmarks admit up to 8; competitions use 2–8. These are target capacities requiring populated profiling. Keep event areas bounded and provide an explicit return. Never generate five complete enormous regions for every social server merely because the catalog contains them.

Each satellite region has a 320×256-stud accessible hub footprint, a 192×128-stud mutable dig area, protected transit/NPC islands and three local 160-stud depth bands. Use local depth for terrain and discovery gating; global career records distinguish region and band. Region builds occupy separate bounds and carry RegionId on interactive objects. Reuse the current 4-stud voxel grid. Each local biome includes a 64×64×32-stud encounter pocket separated from ordinary tunnels by protected walls. Larger flagship encounters use a 128×96×48 arena. These are initial construction envelopes, not performance guarantees.

Landmark entrances occur at authored accessible positions plus rotating discoverable anchors, not anywhere a player could uncover them through arbitrary protected geometry. A dig reveals a portal/door into a bounded activity volume. Physical ordinary tunnel carving and hand-authored encounter geometry remain separate. This avoids making a puzzle impossible because someone excavated its support wall.

## Depth progression and certifications

The first three original layers introduce collecting and scanning. Pirate Cove and Shipwreck introduce oversized group discoveries. Fossil/Bedrock teach careful excavation and route clearing. Crystal/Frozen introduce environmental interactions. Ruins/Magma/Obsidian teach multi-step machines and local hazards. Alien Hive and Core pay off the world's increasing absurdity.

Use certification chapters independent of rebirth:

| Certification ID | Requirements | Unlock |
|---|---|---|
| cert_rookie | First sell and scanner-found personal deposit | First ability-tool trial and public mini-vault |
| cert_crew | Finish one salvage event alone or with helpers | Personal trophy stand; official crew adventures |
| cert_explorer | Reach Pirate Cove and finish Captain Pebble's map quest | Bloomwild travel and broadwave shovel license |
| cert_pathfinder | Finish Bloomwild chapter and one crystal encounter | Frostfloat travel and hauling mount license |
| cert_engineer | Finish Frostfloat chapter and repair Tink's pump | Emberworks travel and machine specialist license |
| cert_weird | Finish Emberworks chapter and alien signal encounter | Odd Orbit travel |
| cert_core | Finish all five region chapters and open the Core observatory | Core finale admission; no rebirth requirement |

Each requirement supports a solo path; group help can make it social without bypassing the learning step. Certification credit is an explicit persisted receipt. Tool hardness still controls ordinary digging, but story reward tool loans permit a player to experience each newly unlocked interaction. Costs must not put a long grind between certification and its first demonstration.

The full journey is paced across visits. A newcomer should encounter the game's absurd personality within the first few minutes and complete a small adventure in the first session. The Core is long-term aspiration, while every region has a satisfying nearer ending.

## First session screenplay

Spawn facing an obvious patch of sand, with Mara waving beside a large half-buried shape. Show only bag, contextual dig action, scanner when introduced and one quest card. Currency is compact; heat, stacks of shop badges and unrelated timers are absent.

Mara says: “That beach has swallowed everything. Start with the shovel!” First successful swing creates a clear scoop, sound, bag change and terrain change. On dig six preserve the guaranteed harmless find. The reveal shows its name and one sentence; first-time timing mistakes never remove the prize.

After the first find, show a strong nearby scanner signal so the player can deliberately locate another. After first sale, Pip offers the affordable first shovel and lets the player try a charge ability on a marked patch. If money is short, explain the gap and guide to another ordinary sell; do not claim affordability without checking.

Mara then identifies a giant signal in a public mini-vault 8–12 studs down. The player clears three marked anchors. A nearby player can help; solo takes only a little longer. Opening the vault releases an enormous springy beach ball. It rolls along a protected channel; players guide it home. Completion awards coins, the first camp trophy, cert_crew and a clear “another strange signal” option.

Target sequence: first action under 30 seconds, first find under 90 seconds, first deliberate scan before 3 minutes, first distinct activity before 5 minutes, small ending around 6–10 minutes. Measure actual player behavior; do not confuse computer automation latency with human timing.

Tutorial quests can be resumed, dismissed after comprehension and reopened. Returning legacy players get a brief optional catch-up: a nearby special signal and the camp trophy explanation. Do not reset their save or require their first shovel purchase again.

## Events emerge from discoveries

Personal deposits remain reliable background collecting. Landmark deposits can expose an activity entrance or shared object. Wild discoveries produce a short local scene. Scheduled festivals add region changes with an announced window. These classes use separate seed tables and caps; making a common bottle cap activate a server event every few seconds would exhaust novelty.

A newcomer sees a curated first landmark. Ordinary eligible digging thereafter accrues encounter charge, once per second of genuine activity, until an opportunity can be seeded; details are in chapter 04. Players cannot trigger rare events by remote-spamming empty sand. No event destroys a personal deposit or takes someone else's finds.

Public invitation: “GIANT CHEST FOUND · Help uncover it · about 5 minutes.” Show a world beacon, distance, Join/Ignore and activity size. Joining gives temporary event tools if needed. Credit actual assistance from validated actions. A participant who leaves keeps completed stage grants but does not automatically receive a final reward they did not help earn.

Encounter variation comes from authored route arrangements, objective location, one safe modifier and team composition. Keep the objective recognizable. Two attempts should differ in a decision or incident, not only item color. Repeat the same mechanics sufficiently for mastery; random rules every minute would undermine comprehension.

## Competition without compulsory hostility

All competitive events require explicit opt-in. Use event equipment, normalized yield, fixed rewards and mirrored or shared-fair terrain. Paid speed, high-tier pets and prestige bonuses cannot decide a fair contest. Competitions reward participation and reasonable effort; winning adds modest identity/status rather than essential progression.

Target modes: Treasure Dash, Dig Derby, Crew Cart Rally and Signal Showdown. The mode catalog specifies exact objectives and tie handling. No player can steal from permanent inventories. Carryable contest tokens disappear at match end and are distinct from owned treasures. No invitation repeats after dismissal during the same event.

## Ownership and customization

Every notable discovery creates a trophy record automatically while preserving its normal payout. A trophy is a display copy, not a sellable duplicate. Records preserve the best variant/value/depth/context known at time of discovery. Legacy Index entries receive basic historical replicas rather than invented grades or timestamps.

Each player has a instanced camp layout displayed in one of sixteen reserved beach camp pads when loaded. There is no dig ownership on these pads. Camp templates persist; pad location does not. Offline camps unload. A private preview remains usable if the social display space is unavailable.

Start with three trophy slots, two furniture slots and one banner. Certification increases to six trophies/eight furniture/one mount stand; full mastery caps at twelve trophies/sixteen furniture/two mount stands. Placement snaps to a 2-stud grid within a 24×24 pad and cannot collide with transit, hide another player's NPC or permit offensive free-text signs. Use curated names/stickers and platform-filtered labels only if that label feature is later implemented and reviewed.

Equipment customization changes visual paint, decals and optional trail; it does not change mechanical stats. Saved loadouts hold one ordinary digging tool, one specialist ability tool, one support gadget and one mount. Companions retain existing equip rules but their mechanical output is bounded inside adventures.

## The Core finale

The final target is a 6–10-minute replayable adventure, solo or crew. It begins at an observatory unlocked by cert_core. The crew clears three paths to buried resonators; each region's learned interaction provides a short puzzle. Activating all three opens a golden chamber containing the First Beach Ball, an absurd cosmic toy rather than a grim boss.

Players roll it through a final tunnel with optional treasure detours. The chamber shifts through bright echoes of prior biomes. Success places a trophy replica on the player's camp stand, grants title Core Storyteller, awards the Core capsule mount skin and unlocks remix routes. The journey ends with a celebratory surface arrival; it does not require wiping money or paying to finish.

Failure returns the crew to the observatory with stage rewards retained and a clear retry. There are no stolen owned items or forced prestige. Repeat finales change route arrangement and optional challenge; first-clear story reward grants once, repeat base rewards remain bounded.

## Optional prestige

Keep historical rebirth data and perks. Future prestige is voluntary after cert_crew and presented as restarting the ordinary production ladder for persistent convenience/status, not erasing story travel/certifications/trophies. Existing paid benefits remain. Full rules and migration are chapter 04. Adventure challenge can scale through optional badges and event equipment presets without requiring the same shop ladder ten times.

## Content discipline

Complete target launch includes five regions, twenty-seven defined biome bands including the existing fifteen, twelve modeled recurring NPCs plus the A.D. terminal persona, ten added specialist tools, four support gadgets, eight added mounts, twenty added personal treasures, twelve reusable shared landmark objects plus two finale structures, fourteen adventure quests, twelve events and six themed festival templates. Existing objects remain in the baseline encyclopedia. Cosmetic categories have a finite defined launch roster; no open-ended promise of “all conceivable content.”

Release subsets are explicit. The first playable expansion has one new tool, one landmark, two NPCs and trophies. Subsequent releases add only the next tested chapter. No complete new region is an automatic requirement for the first release.

## External comparisons

Checked 8 October 2026: [DIG](https://www.roblox.com/games/126244816328678/DIG) publicly emphasizes digging/exploration. [Grow a Garden](https://www.roblox.com/games/126884695634066/Grow-a-Garden) describes a persistent garden, offline growth and showing finds to friends. [Dead Rails](https://www.roblox.com/games/116495829188952/Dead-Rails) describes a shared journey with friends; [99 Nights in the Forest](https://www.roblox.com/games/79546208627805/99-Nights-in-the-Forest) emphasizes a camp with friends and a threat. These support comparisons of product promises, not a causal claim about success. [Roblox discovery guidance](https://create.roblox.com/docs/discovery) emphasizes repeat engagement and social behavior. Our design inference is to combine persistent expression with short narratable discovery adventures while keeping digging central. Do not copy branded characters, maps or assets.


---

# 03 — Future content encyclopedia

Status: TARGET catalog; numerical entries are TUNE. All entries are new proposals unless explicitly marked retained. Stable IDs are listed so content, quest, asset and migration references can agree. Universal behavior/reward defaults are chapter 04. This chapter enumerates the finite complete expansion; it is not a promise that all entries ship at once.

## Regions

| ID / region | Access | Identity and hub | Biomes | Signature activity / completion |
|---|---|---|---|---|
| sunshine_shore / Sunshine Shore | Starting region | Retained beach/boardwalk, hub shops, expedition pier and camps; navy, cream, coral, turquoise | Original 15 bands | Giant salvage and Core journey; q_captain opens satellites |
| bloomwild_basin / Bloomwild Basin | cert_explorer | Giant greenery and tiny settlements; hub on a tree stump, green/peach/violet | Mossburrow, Mushroom Metropolis, Root Cathedral | Recover beetle and grow a route; q_beetle completes chapter |
| frostfloat_shelf / Frostfloat Shelf | cert_pathfinder | A cold holiday resort over a frozen sea; hub on stable dock, cyan/navy/orange | Snowdrift Market, Frozen Aquarium, Clockwork Glacier | Free a stopped transport and carry its cargo; q_penguin completes chapter |
| emberworks_isle / Emberworks Isle | cert_engineer | A cheerful geothermal factory run badly; hub on cooled rock, orange/charcoal/cyan | Ash Orchard, Steamworks, Ember Foundry | Clear ducts and restart a giant machine; q_ember completes chapter |
| odd_orbit_atoll / Odd Orbit Atoll | cert_weird | Aliens mistake a beach for an interplanetary post office; hub under a saucer umbrella, lime/violet/cream | Meteor Playground, Alien Post Office, Upside-Down Reef | Deliver absurd parcels and align a beacon; q_alien completes chapter |

Region hub footprint 320×256, dig footprint 192×128 and three 160-meter local bands inherit chapter 02. Sunshine retains current dimensions and 1,000-meter spine. No new region changes historical main-beach MaxDepth. Satellite records use RegionDepths[regionId]. Travel takes no coins; first access follows certification, return checkpoints are permanent. Region exits always provide a free return to Sunshine.

## Biomes: retained depth spine with added interactions

All fifteen retain current IDs, depth boundaries, terrain materials, ordinary loot and records. New activity pockets are protected geometry with mutable entry corridors. Exact old bands appear in chapter 06.

| Existing biome ID | Expansion interaction | Landmark/NPC | Readable visual cue |
|---|---|---|---|
| dry_sand | Mini-vault introduction and rolling ball | landmark_spring_vault / Mara | Half-buried lid and striped handles |
| wet_sand | Short drainage paths and beach salvage | landmark_tide_chest / Mara | Blue flow arrows |
| shell_bed | Match shell tones to open a door | landmark_shell_gate / Professor Shellby | Three large colored shell pads |
| tidal_clay | Sticky corridor cleared by broad scoop | landmark_anchor_cache / Captain Pebble | Rope and large anchor silhouette |
| pirate_cove | Open compartments in an oversized ship | landmark_pirate_ship / Captain Pebble | Three marked deck sections |
| shipwreck | Move cargo through a cleared path | landmark_tide_chest / Captain Pebble | Cargo route marked with flags |
| fossil_bed | Excavate skeleton anchors without removing protected bones | landmark_colossus / Professor Shellby | Exposed rib and sand-covered anchor pads |
| bedrock | Clear reinforced debris with charge tool | landmark_drill_gate / Tink | Cyan fault lines on removable blocks |
| crystal_caverns | Rotate crystals and redirect light | landmark_prism_engine / Ruby Ray | Visible beams and distinct receiver shapes |
| frozen_abyss | Thaw marked joints to free cargo | landmark_frozen_train / Nori | Frost cracks with warm outline |
| ancient_ruins | Activate machines and reveal city doors | landmark_prism_engine / Ruby Ray | Three readable symbol plaques |
| magma_chamber | Clear ducts between harmless timed steam bursts | landmark_steam_pump / Boiler Bob | Gauge, warning stripes and safe platforms |
| obsidian_depths | Magnetic route panels bridge a gap | landmark_drill_gate / Tink | Floating steel panels and anchor sockets |
| alien_hive | Sort excavated parcels into a silly machine | landmark_postal_saucer / Zip | Parcel shapes matching chute silhouettes |
| the_core | Resonator finale and First Beach Ball | landmark_core_observatory / A.D. | Three large region-symbol paths |

## Satellite biomes

Every row defines a local depth band, primary interaction and new personal loot pool. Within each three-band region, default hardness uses equipment license level 1/2/3 mapped to current shovel-power gates at implementation; adventure tools are loaned at entry so the mechanical demonstration is accessible. Ordinary regional economy uses chapter 04 rates rather than arbitrarily inheriting late main-beach income.

| ID / local band | Appearance / ambient | Digging behavior | Encounter hook | Loot IDs |
|---|---|---|---|---|
| mossburrow / 0–160 | Moss-green earth, oversized roots, warm daylight | Digging marked root knots reveals stable side routes | Search for sprout guides | moss_coin, seed_compass |
| mushroom_metropolis / 160–320 | Violet mushrooms and orange tiny doors | Open spore vents to grow spring platforms | Beetle recovery and bouncing parcels | mushroom_teacup, spore_lantern |
| root_cathedral / 320–480 | Pale root arches, golden pollen | Route water to roots; platforms grow in fixed sockets | landmark_beetle_garage | amber_seed |
| snowdrift_market / 0–160 | Cyan snow, colorful buried stalls | Wide scoops clear marked stalls | Find the misplaced shipment | frozen_ticket, mitten_pair |
| frozen_aquarium / 160–320 | Blue translucent walls, comical frozen fish silhouettes | Thaw designated joints; ordinary terrain remains solid | Help restore an aquarium lift | ice_pearl, fish_clock |
| clockwork_glacier / 320–480 | Navy ice, orange gears | Excavate gears and turn three safe valves | landmark_frozen_train | clockwork_penguin |
| ash_orchard / 0–160 | Dark soil, bright orange mineral fruit | Clear cooling trenches at marked anchors | Find Bob's missing gauge | ember_apple, soot_boot |
| steamworks / 160–320 | Brass pipes, cyan gauges, puffing steam | Dig blocked ducts between telegraphed bursts | landmark_steam_pump | pressure_badge, brass_frog |
| ember_foundry / 320–480 | Charcoal chamber, glowing orange machinery | Clear and magnetically align cooling panels | Restart a furnace that makes beach toys | singing_ingot |
| meteor_playground / 0–160 | Lime sand, purple craters, oversized toys | Some marked mineral pads provide bounded low-gravity jumps | Investigate a wrong-address meteor | meteor_marble, space_sunscreen |
| alien_post_office / 160–320 | Cream sorting machines, bright parcel tubes | Dig parcels out and place them in matching chutes | landmark_postal_saucer | alien_stamp, floating_spoon |
| upside_down_reef / 320–480 | Coral overhead, lime bubbles, inverted scenery | Dig gravity-anchor sockets to switch fixed route platforms | Open the final beacon | pocket_planet |

Do not globally invert player gravity or rewrite arbitrary Terrain:SetMaterialColor per loaded region. Use local authored geometry/material accents and existing global terrain-material constraints. Low gravity/inversion are bounded platform/launch interactions, with immediate safe recovery.

## NPC roster

NPCs do not wander through live diggable terrain. Each has a protected spawn, interaction distance 10 studs, icon and nameplate. Dialogue is at most two short lines per page with one clear action; no voice dependency. They are quest-givers/shop personalities, not damageable targets. Event versions are anchored/kinematic actors. Their state is per player; the visible shared NPC does not disappear because one player completed a quest.

| ID / name | Location, appearance and personality | Service / quests | Intro line | Completion line |
|---|---|---|---|---|
| npc_mara / Mara the Lifeguard | Sunshine tutorial pad; coral jacket, whistle; calm amidst chaos | q_mara; rescue return explanation; event invitations | “The beach keeps swallowing things. Let's find one!” | “Excellent rescue. Of the treasure. You were fine.” |
| npc_pip / Pip Pocket | Sunshine shovel shop; blue apron, huge pencil; excited salesperson | q_pip; tool trials and upgrades | “Small shovel. Ridiculously big plans.” | “Please point the wave away from my stall.” |
| npc_tink / Tink Torque | Sunshine crate yard/workshop; goggles, yellow gloves; enthusiastic inventor | q_pump; tools and mount licenses | “It only exploded in the drawing.” | “A working machine! That's a new record.” |
| npc_captain / Captain Pebble | Pirate entrance and pier; oversized hat, map upside-down | q_captain; ship salvage and regions | “I buried the map. For safekeeping. Help.” | “Perfect. Now which way is north?” |
| npc_shellby / Professor Shellby | Shell/Fossil protected ledge; shell spectacles, brush | q_fossil; collection lore | “A tiny bone! Probably a very big problem.” | “Please don't let the skeleton sneeze.” |
| npc_ruby / Ruby Ray | Crystal protected landing; prism visor, violet coat | q_crystal; resonator instruction | “The crystals sing. We need the right chorus.” | “Beautiful. Only slightly louder than planned.” |
| npc_sprig / Sprig | Bloomwild hub; tiny explorer on raised mushroom | q_bloom; root navigation | “You are enormous. Your shovel is terrifying.” | “Our village votes you Mostly Careful.” |
| npc_bramble / Bramble the Beetle | Beetle garage; friendly mechanical beetle, expressive headlights | q_beetle; mount recovery | “I am a truck. Ignore the legs.” | “Cargo accepted. Leaves also accepted.” |
| npc_nori / Nori Snowcap | Frostfloat dock; orange parka, goggles, dripping ice cream | q_frost; thaw activities | “My delivery is late by one ice age.” | “Next time we're shipping by beach ball.” |
| npc_penny / Penny Penguin | Frozen train station; navy penguin with clock backpack | q_penguin; train dispatch | “The train leaves at… ice o'clock.” | “All aboard! Mind the enormous fish.” |
| npc_bob / Boiler Bob | Emberworks hub; brass helmet, cyan gauge | q_ember; steam safety and factory | “If it whistles, stand on the blue bit.” | “The factory makes toys again. Probably.” |
| npc_zip / Zip | Odd Orbit hub; lime blocky alien carrying stamps; very earnest postal worker | q_alien; parcels and alien beacon | “One parcel for… everyone on this planet?” | “Delivered! Only one galaxy late.” |
| npc_ad_terminal / A.D. | Core observatory terminal; blocky screen, three region-symbol buttons; mysterious explorer's recorded messages | q_core; finale and replay routes | “You made it. Now we can unpack the biggest discovery.” | “The Core was always a beach toy. A very important one.” |

This is thirteen NPC interaction records: twelve modeled characters and one terminal persona. A.D. has its own state, portrait and terminal asset; it does not require an extra walking character model.

## Specialist tools

Existing fourteen shovels remain owned and equippable. Specialist tools are a second loadout slot; their ability is distinct from the main shovel's ordinary yield/power. Unlocks are deterministic. The given acquisition cost is coins after the named quest grants a free first demonstration; essential story use also receives temporary loans. Ability action validates range/line-of-sight/bounds and ignores protected geometry. Ability carves grant sand only through the chapter 04 normalized-yield rule.

| ID / tool | Unlock / price | Action and exact starting parameters | Limits / visual brief |
|---|---|---|---|
| tool_broadwave / Broadwave Shovel | q_pip trial; cert_explorer permanent;1,500 | Hold 0.8 s, release a 12×8×8 corridor wave within 12 studs; cooldown 8 s | Direction locks at release; wide blue shovel, foam-like wave |
| tool_sandvac / Sand Vacuum | cert_crew;2,000 | Channel up to 3 s, clear one 4-stud voxel every 0.5 s in an 8-stud cone; cooldown 6 s from end | Stop when bag full; cannot pull players/items; orange canister |
| tool_jackhammer / Popcorn Jackhammer | q_fossil;8,000 | Six 4-stud clear pulses over 2 s at targeted anchor; cooldown 10 s | Comical recoil animation, no physics knockback on others; yellow tool |
| tool_brush / Professor's Brush | q_fossil free | Personal excavation Good window+0.05 s; active brush marks one nearby eligible anchor; cooldown 8 s | No rarity/luck benefit; mint handle, broad soft bristles |
| tool_prism / Prism Pick | q_crystal free | Rotate one addressed prism 90° at range 10; clear small ordinary 4-stud voxel; cooldown 2 s | Mirrors change only inside active puzzle; violet pick |
| tool_root / Root Rake | q_bloom free | Clear one root knot or expose one water socket at range 10; cooldown 4 s | Growth has authored sockets/cap, not arbitrary construction; green rake |
| tool_thaw / Toasty Spade | q_frost free | Hold 1 s to thaw one marked joint within 10; cooldown 3 s | No melt of entire frozen map; orange/cyan warm blade |
| tool_magnet / Magnet Fork | q_pump free | Attach one tagged panel within 12, move between two predefined sockets;8 s cooldown | Does not grab arbitrary parts or player possessions; horseshoe fork |
| tool_plasma / Bubble Beam Drill | q_alien trial; cert_weird;25,000 | Three successive 4-stud pulses at 12-stud range in 1.5 s; cooldown 8 s; activates gravity anchor | No paid bypass into locked area; lime emitter and soap bubbles |
| tool_core_echo / Core Echo Scoop | q_core free | Marks a reachable alternate deposit/path within 20 for 6 s; cooldown 20 s | Hint, not guaranteed Mythic spawn; gold toy shovel with rotating ball |

## Support gadgets

One support slot equipped. No consumable charge purchases. Existing scanner is always available and does not occupy the support slot. Gadgets never block solo completion.

| ID / gadget | Unlock / coins | Behavior / cooldown | Constraints |
|---|---|---|---|
| gadget_rope / Return Rope | cert_crew /500 | Place a personal waypoint on a validated safe pad; return after 2 s stationary hold;20 s cooldown | In timed activity return is to checkpoint, never free delivery of cargo |
| gadget_lamp / Firefly Lamp | q_bloom /free | Toggle cosmetic/local illumination and highlight nearby interactable silhouettes within 12 | Client light, server controls eligible hint objects; no hidden deposit wallhack |
| gadget_beacon / Crew Beacon | cert_explorer /1,000 | Place invitation ping for an active public objective;45 s cooldown | One per owner; expires 20 s; no repeated notification after recipient ignores |
| gadget_cart / Pocket Cart | q_captain /free | Spawn solo hauling alternative at a tagged cargo station; despawn after 60 s unused | Does not duplicate cargo; current owner/claim preserved; disabled in unrelated races |

## Mounts

Current Mega Excavator remains a surface vehicle/collectible. New mounts are separate deterministic licenses and skins, not randomly rolled essential pets. One active mount per player, one active mount in a narrow encounter crew by default; more only in certified wide arenas. All use safe bounds, distance validation and instant dismount. Each mount has a 24×24 minimum deployment pad, no collision damage, no passive offline mount rewards and no entrance bypass.

| ID / mount | Earned by | Speed / footprint | Ability / cooldown | Where usable |
|---|---|---|---|---|
| mount_mole / Bucket Mole | cert_crew + q_trophies |16;8×10 | Opens a marked 4×8 soft tunnel patch;8 s | Sunshine wide dig pads and designated tunnels |
| mount_crab / Cargo Crab | q_captain |14;10×12 | Hauls oversized object at 12 speed; no separate dig ability | Cargo events and region hubs |
| mount_beetle / Bramble Crawler | q_beetle |18;8×12 | Traverses marked root bridges; boosts small crew cargo for 4 s,20 s cooldown | Bloomwild and cargo-certified paths |
| mount_penguin / Clockwork Penguin | q_penguin |20;6×10 | Controlled glide on certified ice lane; brake always available | Frostfloat and rally tracks |
| mount_drill / Tink's Drill Crawler | q_pump + cert_engineer |16;10×14 | Clears marked reinforced entrance over 3 s;15 s cooldown | Wide mine entrances; not arbitrary vertical holes |
| mount_steam / Steam Snail | q_ember |12;10×12 | Covers crew in safe cooling bubble for 5 s;20 s cooldown | Emberworks steam arenas |
| mount_saucer / Postal Saucer | q_alien |18;10×10 | Bounded hover across tagged gaps, maximum rise 8;15 s cooldown | Odd Orbit route pads; no freeflight |
| mount_ball / Core Capsule | q_core |18;8×8 | Cosmetic rolling shell, optional marked bounce shortcut;15 s cooldown | Approved hubs/remix routes |

Mount steering uses ordinary move input and one contextual ability. Acceleration 20, reverse 0.6×speed, turn rate 1.6 radians/s default; slopes use sampled ground and authored bridges. Server corrects invalid movement. Passenger support is limited to Cargo Crab and Bramble, one passenger each, with explicit consent and no trapped seat. Cargo mounts can be replaced by Pocket Cart in solo or unavailable-license situations.

## New personal treasures

Existing 53 treasures remain; these 20 are added. Regional personal loot weights are rarity-class weights Common 60, Uncommon 25, Rare 10, Epic 4, Legendary 0.9, Mythic 0.1 divided equally among eligible entries of each class and then normalized across present classes. Discovery still rolls size/material/quality through current shared functions; no new seventh variant currency. BaseValue is measured in reference-income seconds U, defined chapter 04; all prizes also update trophy eligibility according to rarity/first-find rules.

| ID / item | Region / biome | Rarity / BaseValue U | Appearance and flavor |
|---|---|---|---|
| moss_coin / Mossy Coin | Bloomwild / mossburrow | Common /8 | Green-edged copper disk; “Accepted by approximately one beetle.” |
| seed_compass / Seed Compass | Bloomwild / mossburrow | Rare /60 | Sprout inside a compass; needle points to sunlight |
| mushroom_teacup / Mushroom Teacup | Bloomwild / mushroom_metropolis | Uncommon /20 | Tiny cup with spotted cap lid |
| spore_lantern / Spore Lantern | Bloomwild / mushroom_metropolis | Epic /200 | Violet glass jar with gentle fireflies |
| amber_seed / Amber Seed | Bloomwild / root_cathedral | Legendary /800 | Large gold seed encased in amber |
| frozen_ticket / Frozen Ticket | Frostfloat / snowdrift_market | Common /8 | Blue ticket with a snowflake hole |
| mitten_pair / Matching Mittens | Frostfloat / snowdrift_market | Uncommon /20 | Oversized orange mittens; finally a complete pair |
| ice_pearl / Ice Pearl | Frostfloat / frozen_aquarium | Rare /60 | White pearl with cyan ring |
| fish_clock / Fish Clock | Frostfloat / frozen_aquarium | Epic /200 | Fish-shaped clock running backward |
| clockwork_penguin / Clockwork Penguin Toy | Frostfloat / clockwork_glacier | Legendary /800 | Brass toy penguin; distinct from licensed mount |
| ember_apple / Ember Apple | Emberworks / ash_orchard | Common /8 | Orange mineral apple; decorative, not edible inventory |
| soot_boot / Sooty Boot | Emberworks / ash_orchard | Uncommon /20 | Black rubber boot with cheerful flower |
| pressure_badge / Pressure Badge | Emberworks / steamworks | Rare /60 | Brass dial pin with smiling indicator |
| brass_frog / Brass Frog | Emberworks / steamworks | Epic /200 | Tiny mechanical frog blowing one bubble |
| singing_ingot / Singing Ingot | Emberworks / ember_foundry | Legendary /800 | Cyan-striped ingot humming a short owned sound |
| meteor_marble / Meteor Marble | Odd Orbit / meteor_playground | Common /8 | Purple rock with lime swirl |
| space_sunscreen / Space Sunscreen | Odd Orbit / meteor_playground | Uncommon /20 | Three-spout bottle labeled SPF∞ through curated artwork |
| alien_stamp / Alien Stamp | Odd Orbit / alien_post_office | Rare /60 | Stamp depicting a baffled crab |
| floating_spoon / Floating Spoon | Odd Orbit / alien_post_office | Epic /200 | Spoon levitating inside a small trophy frame |
| pocket_planet / Pocket Planet | Odd Orbit / upside_down_reef | Mythic /3,000 | Tiny ringed world in a glass orb; no functional infinite planet |

Each satellite band includes its own listed items plus all earlier-band items from that region. Consequently, the final-band Legendary/Mythic shares a pool with earlier Common/Uncommon/Rare/Epic items; it is not a guaranteed jackpot. Normalize only rarity classes actually present. Empty eligible pools fall back to the region's first-band Common. Completing a region collection requires its five new treasures; base object completion suffices, not all variants. Grant cosmetic banner, not a multiplier that compounds every region's income without bound.

## Shared landmark objects

These are activities/props, not sellable personal copies. Every object grants a named trophy replica on first successful completion plus event rewards. Object ID and event/quest identity are separate. Retained existing treasure IDs are never reused for a shared object.

| ID / object | Size envelope studs | Objective and required anchors | Event / adventure |
|---|---|---|---|
| landmark_spring_vault / Spring Vault |12×10×8 | Clear 3 sand anchors, open latch, guide ball through 3 gates | event_vault |
| landmark_tide_chest / Tide Chest |10×8×8 | Clear 3 anchors, move chest to dock checkpoint | event_salvage |
| landmark_shell_gate / Shell Gate |16×12×4 | Clear 3 shells, tap shown tone order of 3 | q_fossil intro encounter |
| landmark_anchor_cache / Anchor Cache |12×8×6 | Clear 2 clay anchors, haul anchor along marked route | q_captain stage 1 |
| landmark_pirate_ship / Buried Pirate Ship |48×24×20 | Clear 3 deck sections and deliver 3 cargo props | q_captain stage 2 |
| landmark_colossus / Beach Colossus |40×16×24 | Expose 6 bone anchors and assemble 3 marked joints | event_fossil |
| landmark_drill_gate / Drill Gate |20×16×4 | Clear 3 reinforced patches, align 2 metal panels | q_pump encounter |
| landmark_prism_engine / Prism Engine |20×16×16 | Clear 3 mirrors, rotate into 3 shape-coded receivers | event_prism |
| landmark_beetle_garage / Beetle Garage |24×16×16 | Clear 3 root knots, water 2 sockets, recover beetle | event_roots |
| landmark_frozen_train / Frozen Train |48×12×16 | Thaw 3 joints, clear 2 gears, haul 1 parcel | event_frost |
| landmark_steam_pump / Steam Pump |24×20×20 | Clear 3 ducts, magnetically seat 2 panels, start pump | event_steam |
| landmark_postal_saucer / Postal Saucer |32×12×32 | Uncover 6 parcels and sort by 3 distinct shapes | event_post |

The Core observatory and First Beach Ball are finale-specific structures described in chapter 02, outside the twelve reusable landmark-object roster. Their stable IDs are landmark_core_observatory and finale_first_ball. Both require assets and implementation; excluding them from the reusable count does not omit their specification.

## Activity/event roster

All durations below are maximum active periods, not forced waits. Complete as soon as objectives are met. World events use helper reward rules; competitions use normalized equipment. See chapter 04 for state machine, tie rules, disconnects and reward formulas.

| ID / name | Trigger / players | Objective / duration | Variations | Reward tier |
|---|---|---|---|---|
| event_vault / Spring Surprise | Curated first encounter then dig opportunity;1–4 |3 anchors +3 ball gates;4 min | Left/right route; small spring bounce | Intro |
| event_salvage / Beat the Tide | Wet/Pirate discovery;1–4 | Move chest through 2 checkpoints to dock;6 min | Safe long route or short wet route; optional signal | Standard |
| event_fossil / Colossal Find | Fossil discovery;1–8 |6 anchors +3 joints;6 min | Skeleton orientation and one sand-slide corridor | Standard |
| event_prism / Crystal Chorus | Crystal discovery;1–4 |3 beams aligned simultaneously;5 min | Two mirror layouts; one receiver order clue | Standard |
| event_roots / Beetle Rescue | Bloomwild story/discovery;1–4 |3 knots +2 watering sockets + return beetle;6 min | Dry route or spring-platform route | Standard |
| event_frost / Frozen Delivery | Frostfloat discovery;1–4 |3 joints +2 gears + parcel return;6 min | Ice lane or stable footpath | Standard |
| event_steam / Factory Restart | Emberworks discovery;1–4 |3 ducts +2 panels + pump start;6 min | Alternate burst cycle and two panel routes | Standard |
| event_post / Wrong Planet Express | Odd Orbit discovery;1–4 |6 parcels correctly sorted then activate beacon;6 min | Parcel order and two tagged low-gravity routes | Standard |
| event_dash / Treasure Dash | Optional board signup;2–8 | Collect temporary contest tokens for 180 s | Two mirrored layouts, seeded token schedule | Contest |
| event_derby / Dig Derby | Optional board signup;2–8 | Clear personal identical lane to finish;180 s limit | Two course layouts; one bypass choice | Contest |
| event_rally / Crew Cart Rally | Optional board;2–8, teams 1–2 | Deliver shared cart through 3 gates;240 s | Two routes and one marked shortcut | Contest |
| event_signal / Signal Showdown | Optional board signup;2–8 | Locate 5 target signals in personal mirrored arena;240 s | Two signal distributions | Contest |

Story use of an event grants quest credit once; repeating the event does not reset the quest. Contests never supply required region certification. Public discoveries cap at one major invitation per region per server; private parties can run one activity each only within measured capacity limits.

## Festival templates

Festivals are controlled content windows, initially manual staging. They reskin or remix existing activities and add one cosmetic first-completion reward. No unique required mechanics disappear when the festival ends. Players keep granted items. Festival trophy is earnable through at least three completions during the window, avoiding dependence on a rare roll. Drop tables and dates are published only when implemented.

| ID / festival | Base activity | World change | Cosmetic reward |
|---|---|---|---|
| festival_ghost_pirates / Friendly Ghost Fleet | event_salvage | Transparent comic pirate decorations, glowing cargo | cosmetic_banner_ghost |
| festival_meteor_mail / Meteor Mail Week | event_post | New parcel artwork and meteor sky accents | cosmetic_tool_meteor |
| festival_snowday / Summer Snow Day | event_frost | Sunshine public arena gets bounded snow props | cosmetic_mount_snow |
| festival_bloom / Bloom Parade | event_roots | Village flags and giant flower cargo | cosmetic_banner_bloom |
| festival_toy_factory / Toy Factory Overtime | event_steam | Machine produces absurd toy props | cosmetic_camp_toy |
| festival_core_carnival / Core Carnival | event_vault remix | Giant ball colors, party confetti, three extra optional gates | cosmetic_trail_confetti |

Full target ships six supported templates, not six simultaneous festivals. Maximum one active festival, with an evergreen counterpart always available. Exact calendar and availability are owner-controlled live-ops decisions.

## Adventure quests

All quests are once-per-account story chains, objective progress persists, and failure retries only the current encounter. Reward grants use receipt IDs. Standard reward reference R is chapter 04. Temporary tool loans are not owned items until a listed permanent grant. No random find is mandatory to advance story.

| ID / NPC | Ordered stages | Reward / unlock |
|---|---|---|
| q_mara / Mara | Dig once; uncover guaranteed find; locate scanner deposit; sell once; finish event_vault | cert_rookie after sell+scan; cert_crew at finish; camp_trophy_stand and 1 R intro grant |
| q_pip / Pip | Buy first shovel; try Broadwave at marked patch; clear 3 ordinary targets | Broadwave demo loan;150 coins first-clear; permanent license at cert_explorer |
| q_captain / Captain Pebble | Reach Pirate Cove; clear Anchor Cache; find guaranteed map prop; salvage 3 ship cargo | cert_explorer; Cargo Crab and Pocket Cart;2 R; Bloomwild access |
| q_fossil / Shellby | Open Shell Gate; expose 3 practice bone anchors; finish event_fossil | Professor's Brush and Jackhammer license;2 R; fossil trophy |
| q_crystal / Ruby | Reach Crystal Caverns or accept story pocket loan; rotate practice prism; finish event_prism | Prism Pick;2 R; crystal encounter completion for cert_pathfinder |
| q_bloom / Sprig | Arrive Bloomwild; open 3 root knots; route water to 1 practice socket | Root Rake and Firefly Lamp;1 R |
| q_beetle / Bramble | q_bloom; finish event_roots; drive marked return route | Bramble Crawler;2 R; Bloomwild chapter complete |
| q_frost / Nori | Arrive Frostfloat; try Toasty Spade; thaw 3 practice joints | Toasty Spade;1 R |
| q_penguin / Penny | q_frost; finish event_frost; deliver train parcel | Clockwork Penguin;2 R; Frostfloat chapter complete |
| q_pump / Tink | cert_pathfinder; visit Sunshine workshop; clear Drill Gate; seat 2 pump panels in workshop pocket | Magnet Fork; Tink's Drill Crawler;2 R; cert_engineer after Frost chapter |
| q_ember / Bob | Arrive Emberworks; safely clear 1 duct; finish event_steam | Steam Snail;2 R; Emberworks chapter; cert_weird after alien signal intro |
| q_alien / Zip | Complete Ember chapter; find guaranteed alien beacon at Sunshine workshop; receive Odd Orbit invitation; finish event_post | Bubble Beam license, Postal Saucer;2 R; Odd Orbit chapter complete |
| q_core / A.D. terminal | Five region chapter flags including Sunshine q_captain; open observatory; complete finale | cert_core admission before finale; Core Echo Scoop; Core Capsule; finale trophy/title;3 R |
| q_trophies / Mara | Place 3 distinct trophy replicas; visit 1 other camp or inspect NPC sample camp solo | Bucket Mole; camp slot tier 2;1 R |

Cert_pathfinder requires both q_beetle and event_prism. Cert_engineer requires q_penguin and q_pump. Cert_weird is awarded when q_ember and q_alien's guaranteed beacon stage are complete; that unlocks Odd Orbit before q_alien's later stages. This avoids circular access dependencies. Sunshine chapter flag is q_captain, not completion of the entire main depth spine. Core admission requires chapters plus observatory intro, not ten rebirths.

## Customization catalog

These are the complete base cosmetic records for the full target. Cosmetic IDs are deterministic rewards or coin purchases; no new random cosmetic boxes. Paint applies to compatible slots; decals use curated owned artwork. Existing equipment appearance is still available as Original.

| ID | Category | Earn/cost | Appearance / placement |
|---|---|---|---|
| paint_coral | Equipment paint | Free | Coral main/navy trim |
| paint_ocean | Equipment paint | Free | Turquoise main/cream trim |
| paint_sunshine | Equipment paint |500 coins | Yellow main/orange trim |
| paint_moss | Equipment paint | Bloomwild collection | Moss green/peach |
| paint_frost | Equipment paint | Frostfloat collection | Cyan/navy |
| paint_ember | Equipment paint | Emberworks collection | Charcoal/orange |
| paint_orbit | Equipment paint | Odd Orbit collection | Violet/lime |
| paint_core | Equipment paint | q_core | Gold/navy |
| decal_crab | Equipment decal | cert_crew | Smiling crab, one surface |
| decal_shovel | Equipment decal | q_pip | Crossed toy shovels |
| decal_beetle | Equipment decal | q_beetle | Two expressive headlights |
| decal_planet | Equipment decal | q_alien | Ringed lime planet |
| camp_trophy_stand | Camp furniture | q_mara | Cream pedestal,2×2 footprint |
| camp_bench | Camp furniture |300 coins | Boardwalk bench,6×2 |
| camp_table | Camp furniture |500 coins | Picnic table,6×6 |
| camp_lantern | Camp furniture | q_bloom | Firefly lantern,2×2 |
| camp_mount_stand | Camp furniture | cert_pathfinder |8×12 mount showcase, noncolliding replica |
| camp_map_board | Camp furniture | q_captain |4×2 expedition board showing owned-region symbols |
| banner_rookie | Camp banner | cert_crew | Bucket emblem; pole 1×1 |
| banner_explorer | Camp banner | cert_explorer | Compass emblem |
| banner_core | Camp banner | q_core | First Beach Ball emblem |
| trail_bubbles | Optional mount trail |1,000 coins | Low particle rate, no screen-filling opacity |
| trail_fireflies | Optional mount trail | q_beetle | Tiny warm particles |
| trail_stars | Optional mount trail | q_alien | Small violet stars |

The six festival reward IDs in the festival table are additional fixed cosmetic records: ghost/bloom banners use existing banner dimensions; meteor is paint/decal for Bubble Beam; snow is a Penguin mount skin; toy is a 4×4 toy chest camp prop; confetti is an optional capped mount trail. All cosmetics are mechanically neutral. This is 30 cosmetic records total.

## Asset production index

Every catalog record needs a recognizable model or icon, acquisition text, collection entry and appropriate animation/audio hook. Existing assets may be reused only where the visual remains accurate. Region set: hub silhouette, terrain/scenery kit, three biome kits, safe pads, entrance marker and transit icon. NPC set: blocky model, idle, point/celebrate gesture, portrait and two dialogue poses. Tool set: held model, strike/ability animation,32/120/240 icon previews and effect. Mount set: body, deploy/dismount/ability animation, steering/contact, preview and ability icon. Shared object set: covered/uncovered stages, anchors, completion state and trophy replica.

Activity markers use silhouette and pattern alongside color. No asset is complete based on a gallery screenshot alone: moving interaction, mobile readability and crowded event view must pass. All sounds and artwork must be owned/appropriately licensed, with asset provenance recorded. Production filenames follow stable entity IDs; variants suffix the ID rather than inventing new reward IDs.


---

# 04 — Mechanics, economy and production specification

Status: TARGET with explicit CURRENT compatibility. This chapter supplies defaults for every proposed catalog record. Numerical values are prototype tuning inputs. They must be centralized in new Config modules and validated, not copied into service/UI scripts.

## Units and content records

Distances are Roblox studs; displayed depth uses the existing one-stud/one-meter convention. Time is seconds. Player-facing names use the catalog; internal IDs use snake_case. Existing stable IDs are retained. Every new record carries ContentVersion, ReleaseStage, RegionId, DisplayName, Status and AssetKey. Target chapters are maintained design; runtime tables are generated/implemented separately and do not change when a report is edited.

RegionDef includes bounds, safe hub, dig areas, local depth bands, palette, certification prerequisite and checkpoint list. BiomeDef includes bounds, hardness, reference-income scale, material/scenery kit, loot pool and encounter pools. ToolAbilityDef includes action kind, duration, cooldown, range, carve shape, valid tags and audiovisual hooks. MountDef includes license, footprint, speed, turn/acceleration, allowed zones, ability, passengers and recovery. NPCDef includes protected spawn, dialogue state selector, quest IDs and shop link. EventDef includes participant bounds, prerequisites, objectives, layout seeds, duration, normalization, rewards and fallback. QuestDef includes ordered objective IDs, grants and prerequisite expression. TrophyDef references a discovery record; no payout field.

A configuration validator checks unique IDs, all references, nonempty pools, noncircular certifications, positive durations, allowed bounds, reward IDs, cosmetic compatibility and stage completeness. Missing asset or unsupported mechanic disables that content in production instead of falling back to a misleading placeholder reward.

## Manual digging and yield

Retain DigService's authoritative raycast, cooldown, hardness, bounds and bag checks. Introduce RegionContext.Resolve(position) so every action obtains region, biome, allowed source and protected structures. Current main-beach carving stays voxel-aligned and bounded. New specialist tools call the same carving primitive; they do not directly write Terrain from the client.

Main ordinary sand formula remains the existing Stats result until measured rebalance. In new satellite regions the baseline ordinary dig grant is RegionU×0.5×BandFactor, multiplied by active gear/pet/pass factors under the target cap. RegionU is Sunshine 1, Bloomwild 10, Frostfloat 50, Emberworks 200, OddOrbit 500; BandFactor 1/1.5/2. These are coins-equivalent/sand units for the prototype, not actual guaranteed player income. Existing side currencies remain Coins and RebirthTokens.

Specialist ability output is capped to equivalent ordinary digs: successful total ability reward <= ordinary matched-shovel sand per dig × (active ability seconds / matched shovel cooldown), with minimum one-dig reward only if solid material is removed. A charged instant Broadwave counts its 0.8-second charge duration. Reward is limited by actual filled voxels removed and capacity; repeated empty/protected targets grant zero. Inside normalized events, carved terrain yields event progress only; participation rewards replace ordinary sand output. This prevents enormous tool shapes from multiplying income or granting event progress twice.

Default regional hardness bands are 4,15,45 for each satellite's first/second/third band. Access certification grants a temporary loan with enough power for the current story encounter. Ordinary free digging still uses the owned shovel's power. Optional event loops always provide standardized gear; story cannot trap a player behind an unaffordable shovel. Legacy late tools work in satellites, but cannot bypass protected entrances, quest admission or normalize-to-win rules.

Action failures have one contextual hint: full bag points to nearest sell/return; too hard names the required tool power and an available option; out of zone shows protected boundary; empty target quietly changes cursor. Do not stack server notification and client hint for the same failed action.

## Discoveries and encounter seeding

Personal discovery retains current deposits, odds and ownership. Add region/biome-aware loot selection; do not rewrite the variant odds separately in the UI. First curated landmark uses a guaranteed authored anchor after q_mara prerequisites; it does not consume the player's ordinary deposit.

For repeat special opportunities, an eligible player accrues EncounterCharge at 1 per second while making successful manual/Auto digs or validated scanner movement toward a deposit, with a 30-second inactivity pause. Threshold 180 charge; cap 360; minimum 180 seconds after the player's last major event invitation. On threshold, if the region has no active public major event and a reachable anchor exists, consume 180 and select an eligible template. If blocked, retain charge, try again every 10 seconds, and do not promise an event. Ability/pet empty-spam earns no charge. Crew event participation suspends accumulation.

Template weighting is equal across eligible activities, excluding the last two seen by that player where at least three are available. A region with one event can repeat after the cooldown. Layout choice avoids the last layout where a second exists. No same clue layout is required to always produce a rare prize. World event content is server-authoritative and one seed is logged for debugging.

RNG streams separate personal loot, encounter selection, layout and cosmetic presentation. Per-event seeded order is fixed at spawn; users cannot reroll by reconnecting. No luck modifier changes contest seed or objective allocation. Activity appearance and actual available loot must agree.

## Excavation interactions

Keep three-ring personal excavation and its miss-safe reward. Add slower practice setting for tutorial/accessibility: same item, quality remains bounded, clear explanation when assisted timing changes grade eligibility. The existing +0.05 brush benefit expands Good tolerance only; Perfect remains 0.09. Automatic timeout still grants damaged item.

Shared giant discoveries use anchors, not simultaneous ring UI for every player. Each covered anchor has WorkRequired=8 validated ordinary-equivalent hits in standardized gear, range 12. Work coalesces across helpers; cooldown 0.5 s per player. Final clearing is atomic. Solo giant anchors scale down to WorkRequired 6;2+ participants use 8 per anchor, rather than linearly multiplying every requirement by group size. Removing visuals does not create additional sand income in event volumes.

Protected bone/ship/prism pieces are tagged and never removed by generic tools. Mark covered anchors with outline, icon and progress; geometry visually transitions at 25/50/75/100%. One anchor completion produces one audio/particle cue regardless of number of helpers. After activity completion remove mutable anchor state only after players return and all receipts are prepared.

## Event state machine

States: Dormant → Discovered → Inviting → Preparing → Active → Resolving → Rewarded → Cleanup → Dormant. Failure branch: Active → Recovering → Resolving → Cleanup. A unique EventInstanceId identifies every attempt. Server owns transitions; clients display state/progress, not authority.

Discovered validates anchor, prerequisites and capacity. Inviting lasts up to 30 seconds but starter can begin after 5; joining participants are shown. Preparing allocates arena, checkpoints, temporary equipment and saved return positions. Active begins only when required geometry and client-ready acknowledgement are available or after a bounded 10-second timeout with safe return for unready clients. Timer never starts while someone is still loading.

Objectives are a server-defined acyclic sequence with IDs and dependencies. Stage transitions are atomic. Clients may request an interaction with target ID; server validates membership, event state, range, action cooldown and target availability. No client submits score, time, reward amount or raw object ownership.

Resolving freezes scoring, snapshots contributions and writes reward intents. Rewarded shows results after per-player save mutation is accepted. Cleanup returns participants, despawns temporary equipment, removes actor/effect/cargo instances and restores/recycles bounded terrain. Disconnects must not strand cleanup. Each active instance has a watchdog; an invalid critical state returns players safely and grants already completed stages, not a fake full win.

Public world discovery locks new entry after the penultimate objective or last 60 seconds, whichever occurs first. Private crew activities can start immediately from a ready list. A queued/invited player can decline. When no active participant remains for 30 seconds, abandon safely. Late joiners receive only stage/final credit they qualify for.

## Participation, sharing and reward safety

Contribution points: one anchor's total work earns up to 10 points divided among actual workers; a validated puzzle transition 5; cargo checkpoint 10 divided among attached haulers; a rescue/helper checkpoint 5. Repeating an already-completed target earns zero. Movement/chat/presence alone earns zero. Every participant has a personal minimum contribution opportunity near entry.

Final eligibility requires at least 5 points plus presence for a validated objective completion or 30 seconds of active participation. For solo activities one meaningful objective completion qualifies. A player who carried but did not dig still qualifies. Points are for eligibility, not proportionally distributing a shared pot; each eligible player receives the same base completion grant. A useful late helper can qualify; a spectator cannot farm by standing still.

Completed-stage grants are 10% of base completion reward per unique major stage, capped 30% total, credited on stage completion. Final successful completion grants remaining 70% when all three stage grants were earned; missing stages do not prevent the eligible player's defined base completion total but reconcile against amounts already granted. Failure keeps stage grants and grants no full completion trophy. Avoid duplicate grants when replaying the same stage after a recovery. Each reward ID is EventInstanceId + UserId + Stage/Final + RewardVersion.

For disconnect during active event, hold slot/state 90 seconds. If rejoin/resume routing is available, restore checkpoint and unfinished participation; otherwise retain saved stage grants and show a truthful summary. Do not promise cross-server resume before it is implemented. The prototype supports safe settlement rather than live event resume. Critical carry objects become available to remaining members after 3 seconds; already banked possessions never drop.

## Cargo, solo support and local setbacks

Cargo is server-owned, kinematic and tied to event ID. Use discrete attachment points and controlled movement instead of unrestricted physics pulling a heavy assembly across mutable terrain. Haulers can attach at range 8, detach anytime, and move at 10 studs/s solo or 12 with two; carrying disables digging but a partner can clear ahead. Pocket Cart moves at 10 and requires only one player, preserving solo completion. A third player helps route clearing, not a mandatory three-person lock.

Checkpoints reset temporary cargo to its last safe position after falling/out-of-bounds; recovery delay 3 seconds. Player falling returns to checkpoint after 2 seconds. Tide reaches safe platforms progressively, with 15 seconds of warning before a route closes. Closing a route never deletes permanent objects or traps an ordinary-world nonparticipant. A guaranteed safe return route/exit remains usable until event end.

An optional detour adds a personal bonus cache worth 20 U on success; it does not risk the base reward already banked. Failure can cost attempt time and unbanked temporary bonus, not inventory, purchased equipment or coins held before entry. Replay is free. No rescue payment prompts.

## Puzzle contracts

Prisms rotate by 90° on interaction. Beams trace among tagged sockets; receivers are shape-coded triangle/square/circle plus color. The solved layout must exist and be stored in config; random layouts choose from certified solutions. Display success only when all required receivers are hit in the same server update.

Root watering moves a marked source to a socket; resulting platforms grow along authored spline positions and cap at 3 per encounter. Steam vents follow an 8-second cycle:5 safe,2 warning,1 burst; tagged blue pads are always safe. A burst sends player to nearby safe pad, not damage or inventory loss. Thaw joints take 1 second held interaction, checked server-side; interruption resets that joint's unfinished hold only.

Parcel sorting uses three distinct shapes and matching chute symbols. Wrong chute gently returns parcel to sorting shelf; no loss. Shell tones display a three-symbol sequence visually and audibly; players can replay it without penalty. Gravity anchors enable predetermined platforms/launch paths only. None of these puzzles require sound, red/green distinction or text alone.

## Competition contracts

Treasure Dash: temporary tokens spawn at five scheduled points per personal mirrored layout,30-second intervals; each worth 1 point. Highest score wins, tie means joint winners. Dig Derby: identical terrain and standardized tool; earliest server-recorded finish wins; nonfinish rank by validated lane progress, exact ties joint. Rally:1–2 player crews; matchmaking matches equal crew sizes, or offers nonranked time trial when insufficient; first complete gate sequence wins, ties within 0.1 second joint. Signal Showdown: five assigned targets; earliest complete wins; ties within 0.1 second joint; no target ownership conflict between players.

Countdown 10 seconds; players begin from locked safe pads and all effects activate at server start time. No late joins after countdown. If fewer than 2 remain before start, offer solo practice without winner reward. Disconnect after start preserves participation eligibility already earned, no automatic win; remaining competitors complete normally. A sole remaining competitor gets ordinary completion, not repeated opponent-leave winner farming. A match is ranked only when 2+ qualifying finishers/participants completed meaningful work.

Standardized gear, disabled pet/paid/prestige output bonuses, consistent mobility, mirrored seeded resources and server-side scoring are mandatory. Limit ranked reward to the first three contests per player per UTC day; subsequent matches offer records/practice and normal capped participation coins. This is a farm-control starting rule, not an instruction to gate social fun. Show the reward rule upfront.

## Economy and rewards

Use existing Coins, sand and RebirthTokens. No expansion gems, tickets, energy or stamina currency. Certification is a flag, not spendable money. RegionU values above serve new rewards; current main-depth RewardScale continues for legacy quests until revised based on measurements. Record grant basis at activity start; a higher equipped shovel or late join does not retroactively multiply a prize.

Define R=60×RegionU. Intro event base=60 coins; standard event base=3 R (three minutes of reference income); finale base=3 R with U capped to the highest region's 500; contest participation=1 R and winner bonus=0.5 R. One-time quest grants use the chapter 03 multiplier. Personal new treasure BaseValue=U×listed seconds, then existing size/material/quality multipliers. Every activity carries RewardScaleVersion so tuning does not reinterpret a pending receipt.

No passive income, friend, Premium, paid, luck or rebirth multiplier applies to fixed event/quest/contest awards. Ordinary main-beach paid benefits keep their existing behavior. New satellite free digging caps the combined non-tool income multiplier at 4 during prototype. Do not apply that cap to already shipped beach output without an explicit reviewed balance/entitlement change.

Selling converts sand and unsold personal finds once, creates trophy records before clearing and applies only the existing normal sale multipliers. Shared object replicas have no sale value. Sale and trophy mutations share the same player-data transaction; an error cannot clear the find without recording its entitlement.

Coin sinks remain tools/backpacks/eggs and optional cosmetic purchases. Essential story loans/grants provide interaction access. New mount licenses are quest rewards. Prestige tokens stay for existing perks and token eggs; no conversion into a new money type. Reward inflation must be measured against actual ordinary income, not assumed RegionU. These starting values are mechanically reproducible but not claimed balanced.

## Prestige migration and entitlements

Keep Rebirths, RebirthTokens, purchased passes and owned gear IDs intact. New cert access can replace rebirth requirements for equivalent main-beach story progression: Trident cert_pathfinder; Magma cert_engineer; Obsidian/Plasma cert_weird; Core Breaker cert_core. Admission is either historical rebirth requirement OR new certification; coin purchase price remains current initially. Core story encounter lends an eligible tool independent of purchase.

Optional new prestige keeps the existing economic reset and multiplier/perks, but never clears certifications, region chapters/checkpoints, trophies, cosmetics, licenses, quest receipts or story unlocks. UI previews the exact reset/keep list and requires deliberate confirmation. Coins and unsold finds are voluntarily reset only after preview; sell-first reminder is available. Failure/events never trigger prestige. Existing players receive chapter certifications from valid historical evidence where it matches requirements; don't invent completed adventures just from a high coin balance.

Heat: disable routine sunburn gain/penalty by feature flag only after testing. Owned shades become placeable camp/community comfort props. Owned cooling consumables retain cosmetic/use feedback and gain a bounded event utility only where explicitly supported; no silent conversion/deletion. Existing speed/sand consumables continue ordinary digging benefits. No new paid item relieves a new artificial environmental penalty.

Paid benefits cannot influence fair contests. Existing entitlements should retain useful casual-world effects and receive a clear explanation of event normalization. New monetization scope is deterministic cosmetic bundles only after core loop validation; prices/catalog are not invented here. Follow existing policy-service handling for current indirect paid-random currencies and verify current rules at implementation. Do not change purchases/receipts as part of a document task.

## Trophy records and camp storage

On first discovery of any new treasure, or an improved Rare+ variant, store TrophyRecord{TreasureId, BestVariantKey, ValueAtDiscovery, RegionId, Depth, AcquiredAt?, Source, Legacy, ReceiptId}. Cap one best record per treasure ID; optional recent log stores last 20 notable records for the results screen. Record comparisons use value first, then quality, size and earliest acquisition for ties. Existing find counts remain sell inventory; trophies cannot be converted back into finds.

Legacy Index creates Original variant historical replica with Legacy=true and unknown fields omitted. Legacy FindVariants can add known material/size badges but cannot prove a particular combined best variant. Unsold Finds can produce a precise trophy if its key contains valid variants. Migration never synthesizes a rarity the player did not own.

Camp placement whitelist includes owned cosmetic/trophy IDs, allowed slot kind, rotation 0/90/180/270 and 2-stud grid position. Server validates bounds/overlap/slot counts; replicas are noncolliding where appropriate. Avoid client-specified asset IDs. Camp layout cap 32 placements plus banner/mount slots; pack small records, not world Instances. Display camp owner and interaction prompts without blocking public paths.

## UI and controls

Primary actions: Dig, Scan, Ability, Interact, Surface/Exit, and optional Mount. Desktop keeps existing controls where possible: click dig, T scan, E contextual interact, Q specialist ability, V mount. Existing E excavation remains contextual. Gamepad retains current scan L 2 and excavation A/R 2; ability uses L 1, interact X, mount DPadUp. Exact final mapping must resolve actual existing bindings during implementation; never overwrite a shipped action silently. Mobile uses large contextual controls, minimum 48 logical pixels, no more than four active primary buttons at once. Mount replaces dig controls with steering/ability/dismount; NPC dialogue suppresses dig input.

One active quest card; one major event invitation; at most one reveal card at a time. Queue lesser toasts and rate-limit announcements. Bag/currency stay compact. Show event objective and timer only after opting in. Camp editing is a separate interaction with undo/cancel; no shop UI opens during timed tapping.

Settings include reduced motion, particle reduction, sound/music volume, readable UI scaling and tutorial replay. Visual/audio shape redundancy is mandatory. Reduced motion removes involuntary shake/long launch cameras; event outcome is unchanged. A player can dismiss an invitation and continue normal play. Device layout is validated on actual phone and controller, not only a resized screenshot.

## Technical system boundaries

Keep DataService, Net, DigService, DiscoveryService, EconomyService, Shops, Pets and existing controllers. Proposed modules: RegionService resolves access/bounds/checkpoints; AdventureService manages parties/admission; EventService owns states/objectives; ContributionService validates work; RewardService owns idempotent grants; NPCService selects dialogue/quest interactions; TrophyService records replicas; CampService validates placement; AbilityService handles tool/mount actions. Pure utilities implement predicates, score/math, seeded choices and migration transforms.

New remotes carry small whitelisted IDs and action intents: RequestTravel(regionId), JoinEvent(instanceId), LeaveEvent(instanceId), InteractObjective(instanceId,targetId,action), UseAbility(abilityId,targetHint), SetLoadout(slot,ownedId), PlaceCampItem(placement), RemoveCampItem(placementId). Server sends EventSnapshot, ObjectiveDelta, NPCDialogue, RewardSummary and CampSnapshot. Values are bounded/rate-limited; no generic remote invoking arbitrary server methods.

Server validates event membership/access/range/cooldown/ownership; client owns only presentation and responsive previews. All final reward and world mutations are server-side. Cargo physics/constraint behavior, movement validation and streamed-instance absence require real-client tests. Use region/event namespaces for IDs and cleanup ownership; avoid global object search every frame.

## Player data additions and reliability

Introduce DataVersion 4 only when migration is implemented and tested. Add Certifications{}, RegionChapters{}, RegionDepths{}, RegionCheckpoints{}, ToolLicenses{}, MountLicenses{}, Cosmetics{}, Loadouts{}, TrophyRecords{}, CampLayout{}, AdventureProgress{}, RecentActivitySummaries{}, RewardReceipts{} and ExpansionTutorial{}. Keep all prior fields intact.

Bound all tables. RewardReceipts retains current active intents plus a rolling settled window of 512 IDs/30 days; compact settled receipts only after replay prevention can no longer reference them. Persistent quest/first-clear flags prevent old first-clear grants being retriggered after receipt pruning. Event uniqueness includes server session GUID and monotonically increasing sequence, not just timestamp. Exactly-once guarantees across failures require persisted intent/settlement design and tests; this document does not pretend an in-memory set is sufficient.

Data load failure follows current refusal/safe behavior, never starts a writable blank save over an unknown existing player. Migration is idempotent, schema-validated and backup-tested. Server shutdown stops admission, settles completed grants and returns checkpoints; unfinished activities do not become fake wins. No permanent terrain tunnel persistence is required for target launch.

## Performance and asset contracts

Do not assume current map part counts leave room for five regions, eight mounts and giant events. Stage budgets initially:16 social players, one major public event per loaded region, one public-event arena in the first release, maximum 8 active large ride models in a hub and one in a narrow event. Verify by measured frame time, memory, network and heartbeat before raising limits. Reuse event arenas/pools; batch anchor updates; replicate progress deltas rather than every particle.

Personal decoration and cosmetic effects are client-local where safe. Reduce particles/companions at distance; keep objective silhouettes visible. Streaming-safe prompts wait for eligible objects and recover if absent. World builders are idempotent, bounds/data-driven and asset provenance documented. No copy of a competitor's trademarked character or map is part of the design.

Completion evidence includes static views, held/worn contact, moving use, camera framing, crowded views, audio audition and physical-device use. Set interaction sound priorities: objective/scan cue > routine dig > ambient > engine; engine never masks the detector. Apply reduced-motion/volume preferences to new systems.

## Analytics and operational visibility

Preserve existing onboarding step numbers; append new flags or use a separate Expansion/Adventure funnel. Record encounter offered/ignored/joined/started, objective completion, participation eligibility, success/failure/abandon, reward settlement, replay, region unlock and camp placement. Fields: content version, template/layout, party size, normalization and reason. Do not log chat, personal identity beyond platform-required player association or high-cardinality arbitrary text.

Dashboard questions: Did newcomers reach the first surprise? Did they understand the objective? Did another player influence the attempt? Did they choose replay? Did they return later? Compare solo and crew, new and legacy, mobile and desktop. Reward abuse and errors have alerts; raw session length/coins spent do not substitute for voluntary engagement. Roblox discovery documentation is checked at implementation because signals evolve.


---

# 05 — From the current game to the target

Status: TARGET implementation roadmap. No calendar estimate is asserted; duration depends on team capacity, asset production and feedback. Each milestone produces a playable/reviewable increment. Future content stays behind feature flags until its gate passes.

## Dependency order

Baseline evidence → reward safety/region context → trophy retention → giant discovery → useful ability → cooperative cargo → first-session integration → certification/progression → first satellite → mount interactions → competitions → remaining regions → finale → festival templates.

The first expansion is not five regions at once. Broadwave plus a giant find plus trophies is the earliest proof of the new promise. If people do not understand or want another attempt, stop adding content and improve that slice.

## Milestone 0 — Agree and preserve

Review this bible's TARGET decisions and accept or edit them. Preserve current build, data schema, owned entitlements and a rollback version. Record source/build correspondence and current configuration snapshot. Do not delete older design evidence; add a pointer saying it is historical for future expansion. STATUS remains the sole operational-status file.

Confirm the first feature set: Sunshine mini-vault, Mara/Pip, Broadwave trial, personal trophy records and one camp display. Confirm no public rename, paid product changes or live save migration until their individual review. Track design changes in the decision register.

Deliverables: accepted design version, current baseline reference, existing-purchase inventory, implementation issues grouped by milestone, and a feature-flag plan. GATE: every first-slice requirement maps to a code/asset/UI/reward owner and a concrete acceptance check.

## Milestone 1 — Observe the baseline and close critical gaps

Observe uncoached newcomers using the current build, including solo and friend pairs. Collect first action/find/scan/sell/upgrade timings, confusion and spontaneous reactions. Audio needs real listening; use current audition candidates rather than generating another library blindly. Verify moving shovel/pet contact, real multi-account reward isolation, natural tide/recovery and a real phone/controller.

Profile a representative populated baseline: heartbeat duration, client frame time, memory, network and worst moments during digging/tide. Save a repeatable scenario and hardware context. Do not infer performance from parts alone or automated test success.

Deliverables: baseline observation report, performance budget proposal and resolved first-session blockers. GATE: the existing core dig/find/sell works reliably enough that the expansion test measures concept rather than crashes, invisible cues or missing audio.

## Milestone 2 — Safe data and trophy slice

Implement TrophyService and data additions under versioned migration. Preserve all old fields; create basic historical replicas only from known Index evidence. Add one camp pad prototype, three trophy slots and preview mode. Selling still pays normally; replicas cannot be sold. Provide Mara's optional explanation for returning players.

Implement reward receipt primitives needed by later events. Test save interruption, migration rerun, duplicate intent, receipt pruning and recovery. Keep expansion off by default until a restored copy of representative legacy data passes.

Deliverables: trophy persistence, basic camp display, migration tests and transaction evidence. GATE: no lost finds/payouts, no invented legacy quality, no sellable trophy duplication, correct rejoin on a different server, no blocker in existing purchase receipt handling.

## Milestone 3 — Giant discovery vertical slice

Implement RegionContext for main-beach bounds and one protected mini-vault pocket. Build landmark_spring_vault, three work anchors, stage transitions, result screen and helper eligibility. Introduce Mara and Pip. First version may guide a ball through three tagged gates with controlled interaction rather than unrestricted physics.

Add one Broadwave trial with clear charge/release feedback; route it through authoritative carving and normalized yield. Ensure a starter shovel can finish without the ability. Invites are opt-in; nonparticipants continue ordinary digging. Use one certified layout first; add a second only after the first is reliable.

Deliverables: first complete adventure, tool trial, trophies and stage receipts. GATE: solo completion, two-client cooperation, late helper eligibility, duplicate target requests, leaving mid-stage, empty arena abandonment, cleanup/restart and low-end mobile readability all work.

## Milestone 4 — Different attempts and hauling

Add two certified route arrangements, one voluntary bonus detour and controlled cargo/Pocket Cart. Implement event_salvage with readable rising tide, checkpoints and recovery. Add Captain Pebble's initial salvage quest. Keep timers forgiving in the first test; prioritize understandable decisions over near-impossible finishes.

Observe the same players' second attempts. Look for a changed route, different role, different decision or different incident. Do not count a different item color as successful variation. Record whether players notice/help another person and voluntarily replay without a daily reward promise.

Deliverables: repeatable social slice and comparison to baseline. GATE: most observed players explain the goal unaided; a repeat attempt creates a meaningful difference; no permanent loss; no cargo griefing; players demonstrate interest in another attempt. Small-sample feedback is diagnostic, not statistical proof. If the gate fails, revise interaction/pacing before producing a satellite region.

## Milestone 5 — First-session and progression integration

Replace the expansion opening with chapter 02's sequence while retaining resumed legacy tutorials. Reduce early HUD clutter; introduce scanner, ability and event in order. Add certification service, deterministic loans/grants, catch-up for legacy players and explicit prestige reset preview. Change tool admission to rebirth OR certification only after checking economic pacing and historical entitlements.

Retire routine heat penalty via a flag and compare experience; preserve shade/snack ownership and compatible uses. Add personal loadouts, camp tier 2 and q_trophies. Keep current main-beach economy values until real data justifies a focused change.

Deliverables: coherent first 10 minutes, legacy return flow and progression path. GATE: no circular prerequisites, early affordability explained, alternate solo story paths work, paid passes retain valid benefits, ordinary digging remains enjoyable outside events.

## Milestone 6 — Bloomwild and first earned mount

Build one satellite region using the three defined bands. Add Sprig, Bramble, Root Rake, five regional treasures, root interaction and event_roots. Implement deterministic Bramble license, bounded driving and cargo role. Add region travel/checkpoints only to the level needed by measured performance architecture.

Deliverables: first full region chapter from unlocking travel to returning with a mount/trophy. GATE: region rule feels different from Sunshine, solo/crew routes remain viable, mount contact/streaming/recovery validated, income rewards measured against real play, and players recognize why to return.

## Milestone 7 — Optional competition

Implement one contest first: Dig Derby, using standardized equipment and mirrored lanes. Add opt-in board, server countdown/scoring, tie rules, disconnect behavior, practice fallback and modest rewards. Verify that paid/pet/prestige advantages are disabled only in the explicitly normalized mode.

Deliverables: fair match and solo practice. GATE: real accounts confirm consistent start, scores and outcomes; players understand temporary contest tokens/gear; no permanent possessions are affected; helper/leave/queue spam cannot farm winner rewards. Add remaining modes only if there is genuine demand and sufficient population. Do not create a four-mode empty queue system at launch.

## Milestone 8 — Frostfloat and Emberworks

Implement Frostfloat's thaw/ice interactions before adding its train event and Penguin mount. Then implement Tink's workshop pump and cert_engineer before Emberworks travel. Add Bob, steam cycles, panels, factory event and Steam Snail. Use readable shapes and safe pads; inspect mounted and unmounted routes.

Deliverables: two complete region chapters with unique interaction and signature license. GATE: each biome teaches its rule without extensive text; no mandatory repeated chore loops; chapter completion and rewards survive rejoin; no growing server-part/terrain leak over repeated events.

## Milestone 9 — Odd Orbit and Core finale

Add the guaranteed alien beacon before locking Odd Orbit access behind cert_weird. Implement Zip's parcel sorting and bounded gravity pads. A.D. terminal follows only after all region flags. Build Core observatory, three resonator paths, First Beach Ball return and celebratory ending. Support solo and crew with the same permanent reward entitlement.

Deliverables: complete beginning-to-finale journey and remix replay. GATE: end-to-end certification graph passes; no spend or rebirth is required to experience the finale; first-clear grants once; retries are free; spectacle stays legible on target mobile device; marketed finale corresponds to actual player-accessible content.

## Milestone 10 — Full content and live operations

Finish remaining tools/gadgets/cosmetics/contests only where they add distinct roles. Validate all current and new catalog records and asset references. Ship one festival template at a time with evergreen fallback, clear availability and nonessential cosmetic rewards. Do not turn live operations into weekly new-system development before the base game is maintainable.

Deliverables: finite full-target inventory complete, support runbooks, honest public media, configuration/change review process and monitoring. GATE: all launch tests below pass, capacity is measured, moderation/publication requirements are checked from current official sources, rollback has been exercised and owner authorizes release.

## Implementation work map

| Workstream | Existing home | New work | Completion evidence |
|---|---|---|---|
| Content configuration | src/shared/Config | Regions, abilities, mounts, NPCs, adventures, trophies/cosmetics | IDs/references/bounds/rewards validated |
| World | server/World builders | Protected pockets, region bounds, entrance/checkpoint tags | Natural reachability and safe return |
| Digging/discovery | DigService / DiscoveryService | Region context, ability carving, landmark hooks | No boundary break, no empty-spam reward |
| Economy/data | DataService / EconomyService / monetization | Versioned additions, receipts, trophy sale transaction | Legacy restore/rejoin/duplicate-grant tests |
| Social adventures | Existing server goal/signals | Party, event, contribution, cargo and recovery services | Real multi-account completion/failure/leave |
| NPC/quests | QuestService and panels | Per-player dialogue/story states and certifications | Resume/solo/prerequisite graph checks |
| Models/audio | Shared model factories, owned assets | Catalog asset briefs, contact, ability effects and cues | Static plus moving/crowded/device review |
| UI/input | Controllers and UI panels | Contextual action, event/results/camp/loadout flows | Phone/controller accessibility and no conflicts |
| Operations | STATUS, release gates and CI | Flags, alerts, rollback, new funnel | Staged release and demonstrated rollback |

## Feature flags and rollback

Flags: ExpansionData, Trophies, MiniVault, ToolAbilities, CrewCargo, Certifications, HeatRetired, RegionBloomwild, FairContests, RegionFrostfloat, RegionEmberworks, RegionOddOrbit, CoreFinale, Festivals. Flags are server-owned, default off for incomplete systems, and logged with build version. Development/test servers may enable individually. Player grants already earned do not vanish when a flag is disabled.

An event kill switch blocks new admission, safely settles completed stages and returns participants. Region kill switch preserves travel entitlement and sends players to Sunshine; save migration is never rolled backward by deleting fields. Economy emergency switch disables only a flawed new grant path, while recording pending settlements for repair. Old published place versions may not understand new fields; rollback compatibility must be tested before migration release.

## Minimum validation matrix

| Scenario | Expected result |
|---|---|
| New player first session, no passes | Dig/find/scan/sell/tool trial/adventure understood and reachable |
| Existing high-depth player | Owned items remain; optional catch-up; no tutorial reset |
| Existing paid-pass player | Valid casual benefits retained; fair-mode normalization explained |
| Solo starter enters every story encounter | Loan/cart route makes completion possible |
| Friend pair with very different progression | Both have meaningful roles; veteran cannot erase objective |
| Helper joins late | Fair eligibility and truthful rewards; no first-owner capture |
| Player ignores world event | Ordinary dig/find/sell unaffected |
| Hauler leaves or disconnects | Cargo releases/recoverable; remaining crew can finish |
| Server ends mid-stage | Accepted stage grants persist; unfinished work not falsely paid |
| Duplicate interaction/reward requests | No double progress or grant |
| Migration interrupted and rerun | Idempotent data; no overwritten save or synthesized best variant |
| Region checkpoint missing/streamed out | Safe fallback to regional hub/Sunshine |
| Repeated 100 activity lifecycles in test harness | No accumulating instances/connections/terrain allocations |
| Phone touch, controller, reduced motion, muted audio | Objectives readable and completable |
| Camp boundary/asset-ID spoof | Rejected server-side; no external asset injection |
| Contest paid boost/late start/tie/leave | Normalized fair result and defined settlement |
| Prestige confirmation | Exact preview; story/permanent data survives |
| Festival ends while active | Complete/settle activity safely; granted cosmetics remain |

Automated tests should target pure math, migration, state transitions and security/reward invariants. Real gameplay checks cover cues, interaction comfort, physical contact, co-play and devices. Neither replaces the other. Keep evidence separated into ordinary play, assisted setup and headless checks.

## Audience validation plan

Initial diagnostic group:6–10 independent newcomers, some solo and some paired, with appropriately arranged target-audience testing. Use neutral observation; don't explain every button. Ask afterward: what were you trying to do, what surprised you, how did another person affect it, and what would you do next time? Observe voluntary next attempt and later return. The sample identifies problems; it does not establish statistical retention.

Expand only after core confusion is resolved. Compare cohorts by first build, acquisition source, device, party size and legacy status. Useful measures: first-action time, first-surprise time, first-session bounce, encounter offer/join/finish, replay within session, next-day return, co-play return and meaningful interactions. Use actual Roblox analytics/benchmarks for current definitions; do not fabricate industry thresholds. Discuss attrition against concrete player observations.

Creator test: give a creator or expressive friend group an ordinary playable build without developer-triggered jackpots. Can they explain a premise, produce a surprising middle and reach an ending? Does the resulting footage contain decisions and reactions rather than only purchases? A successful creator test is promising evidence, not guaranteed distribution or sponsorship.

## Before publishing an expansion

Confirm source/live build correspondence, data migration/backups, new owned asset moderation, device/populated tests, entitlement behavior, current questionnaire/age/reach eligibility, store metadata accuracy, staged access, monitoring and rollback. Use current official Roblox requirements at that time; this book is not a permanent publishing-policy reference. Public artwork should show the released slice, not future-only mounts or regions. The owner retains the release decision.

## Deliberately excluded and future possibilities

Not in this target: permanent theft, open combat/PvP, trading economy, unrestricted player-built tunnels saved forever, user-uploaded assets, procedural infinite worlds, fully simulated underground civilizations, freeflight mounts, mandatory classes, voice-chat-dependent puzzles or a paid energy system. These require separate design/evidence before consideration.

Possible later extensions: player-curated expedition routes, additional region chapters, new mount handling roles, museum tours and more certified contest layouts. New content should reuse the existing contracts and satisfy the same player-value rule. “Possibilities are limitless” is a creative stance, not a requirement to leave the production scope unbounded.

## Definition of the complete target

The target is complete when every catalog entity in chapter 03 is implemented or explicitly revised out by the owner; existing inventories remain valid; every region/story path can be completed alone; a friend changes an adventure meaningfully; optional fair competitions work without permanent losses; trophies/customization persist; the Core has an accessible finale; and evidence gates pass. A hundred extra items do not compensate for an opening players do not understand or a second attempt they do not want.


---

# 06 — Current content encyclopedia

Status: CURRENT SNAPSHOT, 8 October 2026. Generated from actual configuration, not the old GDD.

Every detected top-level named record is listed. Summary tables are navigation aids; the complete definition under each record includes nested loot weights, looks, requirements and rewards. The complete configuration snapshot in chapter 07 covers keyed tables, helper formulas and records without names/IDs. Luau expressions are preserved, not guessed or evaluated. Prices here are configuration values; live marketplace prices require a separate dashboard check.

## Backpacks — 13 records

| ID | Name | Price | Capacity | RebirthsRequired |
|---|---|---|---|---|
| bucket | Beach Bucket | 0 | 20 | 0 |
| sand_pail | Sand Pail | 50 | 60 | 0 |
| beach_bag | Beach Bag | 300 | 200 | 0 |
| cooler | Cooler | 1500 | 700 | 0 |
| treasure_sack | Treasure Sack | 7000 | 2500 | 0 |
| barrel | Pirate Barrel | 30000 | 9000 | 0 |
| mine_cart | Mine Cart | 130000 | 30000 | 0 |
| wheelbarrow | Wheelbarrow | 600000 | 100000 | 0 |
| dump_truck | Dump Truck | 3000000 | 400000 | 0 |
| sand_truck | Sand Truck | 18000000 | 1600000 | 1 |
| cargo_ship | Cargo Ship | 120000000 | 8000000 | 3 |
| black_hole_bag | Black Hole Bag | 900000000 | 50000000 | 6 |
| pocket_dimension | Pocket Dimension | 6000000000 | 400000000 | 9 |

### Beach Bucket (`bucket`)

```lua
{
		Id = "bucket",
		Name = "Beach Bucket",
		Price = 0,
		Capacity = 20,
		RebirthsRequired = 0,
		Description = "A trusty plastic bucket. Holds a little sand.",
		Look = {
			Color = rgb(60, 170, 255),
			AccentColor = rgb(255, 230, 60),
			Shape = "Bucket",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	}
```

### Sand Pail (`sand_pail`)

```lua
{
		Id = "sand_pail",
		Name = "Sand Pail",
		Price = 50,
		Capacity = 60,
		RebirthsRequired = 0,
		Description = "Bigger bucket, bigger trips.",
		Look = {
			Color = rgb(255, 120, 60),
			AccentColor = rgb(255, 255, 255),
			Shape = "Bucket",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	}
```

### Beach Bag (`beach_bag`)

```lua
{
		Id = "beach_bag",
		Name = "Beach Bag",
		Price = 300,
		Capacity = 200,
		RebirthsRequired = 0,
		Description = "Towel, sunscreen... and LOTS of sand.",
		Look = {
			Color = rgb(255, 90, 160),
			AccentColor = rgb(255, 240, 120),
			Shape = "Bag",
			Material = Enum.Material.Fabric,
			Glow = false,
		},
	}
```

### Cooler (`cooler`)

```lua
{
		Id = "cooler",
		Name = "Cooler",
		Price = 1500,
		Capacity = 700,
		RebirthsRequired = 0,
		Description = "Keeps your sand nice and cool.",
		Look = {
			Color = rgb(40, 200, 230),
			AccentColor = rgb(255, 255, 255),
			Shape = "Box",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	}
```

### Treasure Sack (`treasure_sack`)

```lua
{
		Id = "treasure_sack",
		Name = "Treasure Sack",
		Price = 7000,
		Capacity = 2500,
		RebirthsRequired = 0,
		Description = "A pirate's loot bag, patched with gold thread.",
		Look = {
			Color = rgb(170, 120, 70),
			AccentColor = rgb(255, 210, 60),
			Shape = "Bag",
			Material = Enum.Material.Fabric,
			Glow = false,
		},
	}
```

### Pirate Barrel (`barrel`)

```lua
{
		Id = "barrel",
		Name = "Pirate Barrel",
		Price = 30000,
		Capacity = 9000,
		RebirthsRequired = 0,
		Description = "Rum not included. Sand very included.",
		Look = {
			Color = rgb(140, 90, 50),
			AccentColor = rgb(80, 80, 90),
			Shape = "Barrel",
			Material = Enum.Material.Wood,
			Glow = false,
		},
	}
```

### Mine Cart (`mine_cart`)

```lua
{
		Id = "mine_cart",
		Name = "Mine Cart",
		Price = 130000,
		Capacity = 30000,
		RebirthsRequired = 0,
		Description = "Rolls on tiny rails strapped to your back.",
		Look = {
			Color = rgb(110, 110, 125),
			AccentColor = rgb(200, 60, 50),
			Shape = "Cart",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	}
```

### Wheelbarrow (`wheelbarrow`)

```lua
{
		Id = "wheelbarrow",
		Name = "Wheelbarrow",
		Price = 600000,
		Capacity = 100000,
		RebirthsRequired = 0,
		Description = "Somehow fits on your back. Don't ask.",
		Look = {
			Color = rgb(60, 180, 90),
			AccentColor = rgb(60, 60, 60),
			Shape = "Cart",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	}
```

### Dump Truck (`dump_truck`)

```lua
{
		Id = "dump_truck",
		Name = "Dump Truck",
		Price = 3000000,
		Capacity = 400000,
		RebirthsRequired = 0,
		Description = "A whole toy dump truck... that isn't a toy.",
		Look = {
			Color = rgb(255, 200, 30),
			AccentColor = rgb(50, 50, 60),
			Shape = "Vehicle",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	}
```

### Sand Truck (`sand_truck`)

```lua
{
		Id = "sand_truck",
		Name = "Sand Truck",
		Price = 18000000,
		Capacity = 1600000,
		RebirthsRequired = 1,
		Description = "The biggest truck on the beach. Requires 1 Rebirth.",
		Look = {
			Color = rgb(255, 130, 30),
			AccentColor = rgb(240, 240, 240),
			Shape = "Vehicle",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	}
```

### Cargo Ship (`cargo_ship`)

```lua
{
		Id = "cargo_ship",
		Name = "Cargo Ship",
		Price = 120000000,
		Capacity = 8000000,
		RebirthsRequired = 3,
		Description = "Carry a shipyard of sand. Requires 3 Rebirths.",
		Look = {
			Color = rgb(40, 90, 200),
			AccentColor = rgb(230, 60, 60),
			Shape = "Vehicle",
			Material = Enum.Material.Metal,
			Glow = true,
		},
	}
```

### Black Hole Bag (`black_hole_bag`)

```lua
{
		Id = "black_hole_bag",
		Name = "Black Hole Bag",
		Price = 900000000,
		Capacity = 50000000,
		RebirthsRequired = 6,
		Description = "Bigger on the inside. Requires 6 Rebirths.",
		Look = {
			Color = rgb(80, 20, 140),
			AccentColor = rgb(255, 120, 255),
			Shape = "Orb",
			Material = Enum.Material.Neon,
			Glow = true,
		},
	}
```

### Pocket Dimension (`pocket_dimension`)

```lua
{
		Id = "pocket_dimension",
		Name = "Pocket Dimension",
		Price = 6000000000,
		Capacity = 400000000,
		RebirthsRequired = 9,
		Description = "An entire beach folded into a marble. Requires 9 Rebirths.",
		Look = {
			Color = rgb(255, 215, 90),
			AccentColor = rgb(120, 255, 255),
			Shape = "Orb",
			Material = Enum.Material.Neon,
			Glow = true,
		},
	}
```
## Badges — 15 records

| ID | Name | Price | Description | Reward |
|---|---|---|---|---|
| Welcome | Welcome to the Beach! | — | — | — |
| FirstPet | New Best Friend | — | — | — |
| PirateCove | Arrr, Pirate Cove! | — | — | — |
| FossilBed | Dino Digger | — | — | — |
| CrystalCaverns | Crystal Clear | — | — | — |
| FrozenAbyss | Underground Ice Age | — | — | — |
| MagmaChamber | Too Hot to Handle | — | — | — |
| AlienHive | Close Encounter | — | — | — |
| TheCore | I Reached the Core! | — | — | — |
| FirstRebirth | Born Again | — | — | — |
| MythicLuck | Mythic Luck | — | — | — |
| Collector | Collector | — | — | — |
| AncientRuins | Lost Civilization | — | — | — |
| BeachRegular | Beach Regular | — | — | — |
| CoreBreaker | Core Breaker | — | — | — |

### Welcome to the Beach! (`Welcome`)

```lua
{ Key = "Welcome", Id = 305615989875213, Name = "Welcome to the Beach!", Kind = "FirstDig" }
```

### New Best Friend (`FirstPet`)

```lua
{ Key = "FirstPet", Id = 1399687731914868, Name = "New Best Friend", Kind = "FirstPet" }
```

### Arrr, Pirate Cove! (`PirateCove`)

```lua
{
		Key = "PirateCove",
		Id = 3721202346547107,
		Name = "Arrr, Pirate Cove!",
		Kind = "ReachLayer",
		Layer = "Pirate Cove",
	}
```

### Dino Digger (`FossilBed`)

```lua
{ Key = "FossilBed", Id = 1841450014262918, Name = "Dino Digger", Kind = "ReachLayer", Layer = "Fossil Bed" }
```

### Crystal Clear (`CrystalCaverns`)

```lua
{
		Key = "CrystalCaverns",
		Id = 3808710393122420,
		Name = "Crystal Clear",
		Kind = "ReachLayer",
		Layer = "Crystal Caverns",
	}
```

### Underground Ice Age (`FrozenAbyss`)

```lua
{ Key = "FrozenAbyss", Id = 0, Name = "Underground Ice Age", Kind = "ReachLayer", Layer = "Frozen Abyss" }
```

### Too Hot to Handle (`MagmaChamber`)

```lua
{ Key = "MagmaChamber", Id = 0, Name = "Too Hot to Handle", Kind = "ReachLayer", Layer = "Magma Chamber" }
```

### Close Encounter (`AlienHive`)

```lua
{ Key = "AlienHive", Id = 0, Name = "Close Encounter", Kind = "ReachLayer", Layer = "Alien Hive" }
```

### I Reached the Core! (`TheCore`)

```lua
{ Key = "TheCore", Id = 0, Name = "I Reached the Core!", Kind = "ReachLayer", Layer = "The Core" }
```

### Born Again (`FirstRebirth`)

```lua
{ Key = "FirstRebirth", Id = 0, Name = "Born Again", Kind = "Rebirth", Count = 1 }
```

### Mythic Luck (`MythicLuck`)

```lua
{ Key = "MythicLuck", Id = 0, Name = "Mythic Luck", Kind = "FindRarity", Rarity = "Mythic" }
```

### Collector (`Collector`)

```lua
{ Key = "Collector", Id = 0, Name = "Collector", Kind = "CompleteLayer" }
```

### Lost Civilization (`AncientRuins`)

```lua
{ Key = "AncientRuins", Id = 0, Name = "Lost Civilization", Kind = "ReachLayer", Layer = "Ancient Ruins" }
```

### Beach Regular (`BeachRegular`)

```lua
{ Key = "BeachRegular", Id = 0, Name = "Beach Regular", Kind = "DailyStreak", Count = 7 }
```

### Core Breaker (`CoreBreaker`)

```lua
{ Key = "CoreBreaker", Id = 0, Name = "Core Breaker", Kind = "Rebirth", Count = 10 }
```
## Boosts — 6 records

| ID | Name | Price | Description | Reward |
|---|---|---|---|---|
| SandBoost | 2x Sand | — | "Double sand from every dig!" | — |
| LuckBoost | 2x Luck | — | "Double treasure chance and better pets from eggs!" | — |
| CoinBoost | 2x Coins | — | "Double coins every time you sell!" | — |
| SpeedBoost | Fast Dig | — | "Dig 50% faster!" | — |
| SugarRush | Sugar Rush | — | "Brain freeze! Dig 25% faster for a little while." | — |
| MelonPower | Melon Power | — | "Juicy! +50% sand for a little while." | — |

### 2x Sand (`SandBoost`)

```lua
{
		Id = "SandBoost",
		Name = "2x Sand",
		Kind = "Sand",
		Multiplier = 2,
		Description = "Double sand from every dig!",
		Color = rgb(255, 205, 60),
	}
```

### 2x Luck (`LuckBoost`)

```lua
{
		Id = "LuckBoost",
		Name = "2x Luck",
		Kind = "Luck",
		Multiplier = 2,
		Description = "Double treasure chance and better pets from eggs!",
		Color = rgb(90, 230, 120),
	}
```

### 2x Coins (`CoinBoost`)

```lua
{
		Id = "CoinBoost",
		Name = "2x Coins",
		Kind = "Coins",
		Multiplier = 2,
		Description = "Double coins every time you sell!",
		Color = rgb(255, 170, 30),
	}
```

### Fast Dig (`SpeedBoost`)

```lua
{
		Id = "SpeedBoost",
		Name = "Fast Dig",
		Kind = "Speed",
		Multiplier = 1.5,
		Description = "Dig 50% faster!",
		Color = rgb(60, 190, 255),
	}
```

### Sugar Rush (`SugarRush`)

```lua
{
		Id = "SugarRush",
		Name = "Sugar Rush",
		Kind = "Speed",
		Multiplier = 1.25,
		Description = "Brain freeze! Dig 25% faster for a little while.",
		Color = rgb(255, 120, 200),
	}
```

### Melon Power (`MelonPower`)

```lua
{
		Id = "MelonPower",
		Name = "Melon Power",
		Kind = "Sand",
		Multiplier = 1.5,
		Description = "Juicy! +50% sand for a little while.",
		Color = rgb(90, 220, 110),
	}
```
## Codes — 4 records

| ID | Name | Price | Description | Reward |
|---|---|---|---|---|
| RELEASE | RELEASE | — | — | { ScaledCoins = 300, Coins = 500, Pet = "launch_crab" } |
| SANDY | SANDY | — | — | { Boost = "SandBoost", BoostSeconds = 900 } |
| DIGDEEP | DIGDEEP | — | — | { Boost = "LuckBoost", BoostSeconds = 900, Egg = "beach_egg", EggCount = 1 } |
| 1KLIKES | 1KLIKES | — | — | { ScaledCoins = 600, RebirthTokens = 1 } |

### RELEASE (`RELEASE`)

```lua
{
		Code = "RELEASE",
		Reward = { ScaledCoins = 300, Coins = 500, Pet = "launch_crab" },
		Enabled = true,
		Expires = nil,
		Note = "Launch code. Gives the exclusive Launch Party Crab.",
	}
```

### SANDY (`SANDY`)

```lua
{
		Code = "SANDY",
		Reward = { Boost = "SandBoost", BoostSeconds = 900 },
		Enabled = true,
		Expires = nil,
		Note = "Evergreen code shown on the loading screen / game description.",
	}
```

### DIGDEEP (`DIGDEEP`)

```lua
{
		Code = "DIGDEEP",
		Reward = { Boost = "LuckBoost", BoostSeconds = 900, Egg = "beach_egg", EggCount = 1 },
		Enabled = true,
		Expires = nil,
		GroupOnly = true,
		Note = "Group code: post it in the Roblox group and Discord.",
	}
```

### 1KLIKES (`1KLIKES`)

```lua
{
		Code = "1KLIKES",
		Reward = { ScaledCoins = 600, RebirthTokens = 1 },
		Enabled = false,
		Expires = nil,
		Note = "Enable when the game reaches 1,000 likes.",
	}
```
## Consumables — 7 records

| ID | Name | Price | Cooling | Boost | BoostSeconds |
|---|---|---|---|---|---|
| water | Fountain Water | 0 | 70 | — | — |
| lemonade | Lemonade | 40 | 35 | — | — |
| coconut_water | Coconut Water | 250 | 60 | — | — |
| popsicle | Popsicle | 1200 | 50 | "SugarRush" | 30 |
| shaved_ice | Shaved Ice | 6000 | 80 | "SugarRush" | 60 |
| watermelon_slice | Watermelon Slice | 25000 | 100 | "MelonPower" | 45 |
| giant_watermelon | Giant Watermelon | 250000 | 100 | "MelonPower" | 150 |

### Fountain Water (`water`)

```lua
{
		Id = "water",
		Name = "Fountain Water",
		Price = 0,
		Cooling = 70,
		Icon = "💧",
		Description = "Free at the fountain! Cools you right down.",
		Look = { Style = "Bottle", Color = rgb(120, 200, 255) },
	}
```

### Lemonade (`lemonade`)

```lua
{
		Id = "lemonade",
		Name = "Lemonade",
		Price = 40,
		Cooling = 35,
		Icon = "🍋",
		Description = "Fresh and fizzy. A quick cool-down.",
		Look = { Style = "Cup", Color = rgb(255, 235, 90) },
	}
```

### Coconut Water (`coconut_water`)

```lua
{
		Id = "coconut_water",
		Name = "Coconut Water",
		Price = 250,
		Cooling = 60,
		Icon = "🥥",
		Description = "Straight from the palm tree. Big cool-down.",
		Look = { Style = "Coconut", Color = rgb(130, 85, 50) },
	}
```

### Popsicle (`popsicle`)

```lua
{
		Id = "popsicle",
		Name = "Popsicle",
		Price = 1200,
		Cooling = 50,
		Boost = "SugarRush",
		BoostSeconds = 30,
		Icon = "🍭",
		Description = "Brain freeze! Dig 25% faster for 30s.",
		Look = { Style = "Popsicle", Color = rgb(255, 90, 140) },
	}
```

### Shaved Ice (`shaved_ice`)

```lua
{
		Id = "shaved_ice",
		Name = "Shaved Ice",
		Price = 6000,
		Cooling = 80,
		Boost = "SugarRush",
		BoostSeconds = 60,
		Icon = "🍧",
		Description = "Rainbow syrup! Dig 25% faster for 60s.",
		Look = { Style = "ShavedIce", Color = rgb(90, 180, 255) },
	}
```

### Watermelon Slice (`watermelon_slice`)

```lua
{
		Id = "watermelon_slice",
		Name = "Watermelon Slice",
		Price = 25000,
		Cooling = 100,
		Boost = "MelonPower",
		BoostSeconds = 45,
		Icon = "🍉",
		Description = "Fully cooled AND +50% sand for 45s.",
		Look = { Style = "Slice", Color = rgb(255, 80, 90) },
	}
```

### Giant Watermelon (`giant_watermelon`)

```lua
{
		Id = "giant_watermelon",
		Name = "Giant Watermelon",
		Price = 250000,
		Cooling = 100,
		Boost = "MelonPower",
		BoostSeconds = 150,
		Icon = "🍈",
		Description = "A whole melon! Fully cooled AND +50% sand for 2.5 min.",
		Look = { Style = "Melon", Color = rgb(70, 170, 80) },
	}
```
## DailyRewards — 7 records

| ID | Name | Price | Description | Reward |
|---|---|---|---|---|
| 1 | Coins | — | — | — |
| 2 | 2x Sand (15 min) | — | — | — |
| 3 | Big Coins | — | — | — |
| 4 | 2x Luck (15 min) | — | — | — |
| 5 | Free Eggs | — | — | — |
| 6 | Huge Coins + Token | — | — | — |
| 7 | Sunny Seal Pet! | — | — | { Pet = "sunny_seal", Boost = "CoinBoost", BoostSeconds = 1800 } |

### Coins (`1`)

```lua
{ Day = 1, Label = "Coins", Reward = { ScaledCoins = 120, Coins = 100 } }
```

### 2x Sand (15 min) (`2`)

```lua
{ Day = 2, Label = "2x Sand (15 min)", Reward = { Boost = "SandBoost", BoostSeconds = 900 } }
```

### Big Coins (`3`)

```lua
{ Day = 3, Label = "Big Coins", Reward = { ScaledCoins = 300, Coins = 250 } }
```

### 2x Luck (15 min) (`4`)

```lua
{ Day = 4, Label = "2x Luck (15 min)", Reward = { Boost = "LuckBoost", BoostSeconds = 900 } }
```

### Free Eggs (`5`)

```lua
{ Day = 5, Label = "Free Eggs", Reward = { Egg = "beach_egg", EggCount = 3 } }
```

### Huge Coins + Token (`6`)

```lua
{ Day = 6, Label = "Huge Coins + Token", Reward = { ScaledCoins = 600, Coins = 500, RebirthTokens = 1 } }
```

### Sunny Seal Pet! (`7`)

```lua
{
		Day = 7,
		Label = "Sunny Seal Pet!",
		Reward = { Pet = "sunny_seal", Boost = "CoinBoost", BoostSeconds = 1800 },
	}
```
## Eggs — 13 records

| ID | Name | Currency | Price | UnlockLayer | PityAt | Kind |
|---|---|---|---|---|---|---|
| beach_egg | Beach Egg | "Coins" | 100 | 1 | 40 | — |
| tidepool_egg | Tide Pool Egg | "Coins" | 2500 | 3 | 30 | — |
| pirate_egg | Pirate Egg | "Coins" | 40000 | 5 | 30 | — |
| fossil_egg | Fossil Egg | "Coins" | 600000 | 7 | 30 | — |
| crystal_egg | Crystal Egg | "Coins" | 8000000 | 9 | 30 | — |
| magma_egg | Magma Egg | "Coins" | 150000000 | 12 | 30 | — |
| cosmic_egg | Cosmic Egg | "Coins" | 3000000000 | 14 | 25 | — |
| rebirth_egg | Rebirth Egg | "Tokens" | 3 | 1 | — | — |
| golden_egg | Golden Egg | "Tokens" | 10 | 1 | — | — |
| sandbox_crate | Sandbox Crate | "Coins" | 1000 | 3 | 35 | "Crate" |
| quarry_crate | Quarry Crate | "Coins" | 75000 | 6 | 35 | "Crate" |
| mine_crate | Deep Mine Crate | "Coins" | 6000000 | 10 | 35 | "Crate" |
| core_crate | Core Crate | "Coins" | 1500000000 | 14 | 25 | "Crate" |

### Beach Egg (`beach_egg`)

```lua
{
		Id = "beach_egg",
		Name = "Beach Egg",
		Currency = "Coins",
		Price = 100,
		UnlockLayer = 1,
		PityAt = 40,
		Pets = {
			{ PetId = "sandy_crab", Weight = 60 },
			{ PetId = "seagull", Weight = 28 },
			{ PetId = "starfish", Weight = 10 },
			{ PetId = "baby_turtle", Weight = 1.9 },
			{ PetId = "golden_crab", Weight = 0.1 },
		},
		Look = { ShellColor = rgb(255, 240, 200), SpotColor = rgb(80, 200, 255), Glow = false },
	}
```

### Tide Pool Egg (`tidepool_egg`)

```lua
{
		Id = "tidepool_egg",
		Name = "Tide Pool Egg",
		Currency = "Coins",
		Price = 2500,
		UnlockLayer = 3,
		PityAt = 30,
		Pets = {
			{ PetId = "clownfish", Weight = 60 },
			{ PetId = "pufferfish", Weight = 28 },
			{ PetId = "octopus", Weight = 10 },
			{ PetId = "sea_turtle", Weight = 1.9 },
			{ PetId = "rainbow_starfish", Weight = 0.1 },
		},
		Look = { ShellColor = rgb(120, 220, 240), SpotColor = rgb(255, 150, 180), Glow = false },
	}
```

### Pirate Egg (`pirate_egg`)

```lua
{
		Id = "pirate_egg",
		Name = "Pirate Egg",
		Currency = "Coins",
		Price = 40000,
		UnlockLayer = 5,
		PityAt = 30,
		Pets = {
			{ PetId = "parrot", Weight = 60 },
			{ PetId = "pirate_crab", Weight = 28 },
			{ PetId = "ghost_blob", Weight = 10 },
			{ PetId = "skeleton_shark", Weight = 1.9 },
			{ PetId = "kraken", Weight = 0.1 },
		},
		Look = { ShellColor = rgb(150, 100, 60), SpotColor = rgb(255, 210, 50), Glow = false },
	}
```

### Fossil Egg (`fossil_egg`)

```lua
{
		Id = "fossil_egg",
		Name = "Fossil Egg",
		Currency = "Coins",
		Price = 600000,
		UnlockLayer = 7,
		PityAt = 30,
		Pets = {
			{ PetId = "mole", Weight = 60 },
			{ PetId = "baby_raptor", Weight = 28 },
			{ PetId = "stegosaurus", Weight = 10 },
			{ PetId = "trex", Weight = 1.9 },
			{ PetId = "bone_dragon", Weight = 0.1 },
		},
		Look = { ShellColor = rgb(230, 215, 180), SpotColor = rgb(140, 120, 90), Glow = false },
	}
```

### Crystal Egg (`crystal_egg`)

```lua
{
		Id = "crystal_egg",
		Name = "Crystal Egg",
		Currency = "Coins",
		Price = 8000000,
		UnlockLayer = 9,
		PityAt = 30,
		Pets = {
			{ PetId = "crystal_bat", Weight = 60 },
			{ PetId = "gem_blob", Weight = 28 },
			{ PetId = "crystal_golem", Weight = 10 },
			{ PetId = "frost_seal", Weight = 1.9 },
			{ PetId = "diamond_dragon", Weight = 0.1 },
		},
		Look = { ShellColor = rgb(180, 120, 255), SpotColor = rgb(150, 240, 255), Glow = true },
	}
```

### Magma Egg (`magma_egg`)

```lua
{
		Id = "magma_egg",
		Name = "Magma Egg",
		Currency = "Coins",
		Price = 150000000,
		UnlockLayer = 12,
		PityAt = 30,
		Pets = {
			{ PetId = "lava_salamander", Weight = 60 },
			{ PetId = "magma_golem", Weight = 28 },
			{ PetId = "fire_bird", Weight = 10 },
			{ PetId = "lava_kraken", Weight = 1.9 },
			{ PetId = "phoenix", Weight = 0.09 },
			{ PetId = "core_dragon", Weight = 0.01 },
		},
		Look = { ShellColor = rgb(60, 30, 30), SpotColor = rgb(255, 100, 30), Glow = true },
	}
```

### Cosmic Egg (`cosmic_egg`)

```lua
{
		Id = "cosmic_egg",
		Name = "Cosmic Egg",
		Currency = "Coins",
		Price = 3000000000,
		UnlockLayer = 14,
		PityAt = 25,
		Pets = {
			{ PetId = "alien_blob", Weight = 70 },
			{ PetId = "cosmic_turtle", Weight = 25 },
			{ PetId = "star_golem", Weight = 4.9 },
			{ PetId = "galaxy_dragon", Weight = 0.1 },
		},
		Look = { ShellColor = rgb(40, 30, 100), SpotColor = rgb(120, 255, 160), Glow = true },
	}
```

### Rebirth Egg (`rebirth_egg`)

```lua
{
		Id = "rebirth_egg",
		Name = "Rebirth Egg",
		Currency = "Tokens",
		Price = 3,
		UnlockLayer = 1,
		Pets = {
			{ PetId = "tide_spirit", Weight = 70 },
			{ PetId = "rebirth_phoenix", Weight = 25 },
			{ PetId = "sandlantis_guardian", Weight = 5 },
		},
		Look = { ShellColor = rgb(120, 255, 200), SpotColor = rgb(255, 255, 255), Glow = true },
	}
```

### Golden Egg (`golden_egg`)

```lua
{
		-- v2.3: earnable only (was a Robux product). 10 Rebirth Tokens ~ 4 early rebirths.
		Id = "golden_egg",
		Name = "Golden Egg",
		Currency = "Tokens",
		Price = 10,
		UnlockLayer = 1,
		Pets = {
			{ PetId = "golden_seagull", Weight = 70 },
			{ PetId = "golden_turtle", Weight = 27 },
			{ PetId = "sun_dragon", Weight = 3 },
		},
		Look = { ShellColor = rgb(255, 210, 50), SpotColor = rgb(255, 255, 255), Glow = true },
	}
```

### Sandbox Crate (`sandbox_crate`)

```lua
{
		Id = "sandbox_crate",
		Name = "Sandbox Crate",
		Kind = "Crate",
		Currency = "Coins",
		Price = 1000,
		UnlockLayer = 3,
		PityAt = 35,
		Pets = {
			{ PetId = "toy_truck", Weight = 65 },
			{ PetId = "dump_truck", Weight = 28 },
			{ PetId = "mini_excavator", Weight = 7 },
		},
		Look = { ShellColor = rgb(214, 160, 96), SpotColor = rgb(255, 200, 40), Glow = false },
	}
```

### Quarry Crate (`quarry_crate`)

```lua
{
		Id = "quarry_crate",
		Name = "Quarry Crate",
		Kind = "Crate",
		Currency = "Coins",
		Price = 75000,
		UnlockLayer = 6,
		PityAt = 35,
		Pets = {
			{ PetId = "skid_steer", Weight = 65 },
			{ PetId = "bulldozer", Weight = 28 },
			{ PetId = "backhoe", Weight = 7 },
		},
		Look = { ShellColor = rgb(150, 156, 168), SpotColor = rgb(255, 170, 30), Glow = false },
	}
```

### Deep Mine Crate (`mine_crate`)

```lua
{
		Id = "mine_crate",
		Name = "Deep Mine Crate",
		Kind = "Crate",
		Currency = "Coins",
		Price = 6000000,
		UnlockLayer = 10,
		PityAt = 35,
		Pets = {
			{ PetId = "drill_rig", Weight = 65 },
			{ PetId = "mining_drill", Weight = 28 },
			{ PetId = "tunnel_borer", Weight = 7 },
		},
		Look = { ShellColor = rgb(110, 80, 60), SpotColor = rgb(255, 120, 30), Glow = false },
	}
```

### Core Crate (`core_crate`)

```lua
{
		Id = "core_crate",
		Name = "Core Crate",
		Kind = "Crate",
		Currency = "Coins",
		Price = 1500000000,
		UnlockLayer = 14,
		PityAt = 25,
		Pets = {
			{ PetId = "mole_machine", Weight = 62 },
			{ PetId = "lava_drill", Weight = 30 },
			{ PetId = "core_driller", Weight = 7.5 },
			{ PetId = "mega_excavator", Weight = 0.5 },
		},
		Look = { ShellColor = rgb(60, 60, 72), SpotColor = rgb(255, 210, 60), Glow = true },
	}
```
## Events — 2 records

| ID | Name | Kind | Multiplier | IntervalSeconds | DurationSeconds |
|---|---|---|---|---|---|
| HighTide | High Tide | "Luck" | 2 | 20 * 60 | 3 * 60 |
| GoldenHour | Golden Hour | "Coins" | 2 | 45 * 60 | 5 * 60 |

### High Tide (`HighTide`)

```lua
{
		Id = "HighTide",
		Name = "High Tide",
		Description = "The tide washes treasure into the sand! 2x Luck for everyone.",
		Kind = "Luck",
		Multiplier = 2,
		IntervalSeconds = 20 * 60,
		DurationSeconds = 3 * 60,
		OffsetSeconds = 0,
		Color = rgb(50, 170, 255),
	}
```

### Golden Hour (`GoldenHour`)

```lua
{
		Id = "GoldenHour",
		Name = "Golden Hour",
		Description = "The sunset makes everything shine. 2x Coins when you sell!",
		Kind = "Coins",
		Multiplier = 2,
		IntervalSeconds = 45 * 60,
		DurationSeconds = 5 * 60,
		OffsetSeconds = 10 * 60,
		Color = rgb(255, 160, 40),
	}
```
## Layers — 15 records

| ID | Name | DepthStart | DepthEnd | Hardness | SandValue | RewardScale |
|---|---|---|---|---|---|---|
| dry_sand | Dry Sand | 0 | 20 | 1 | 1 | 1 |
| wet_sand | Wet Sand | 20 | 45 | 2 | 2 | 1.5 |
| shell_bed | Shell Bed | 45 | 75 | 4 | 4 | 3 |
| tidal_clay | Tidal Clay | 75 | 110 | 8 | 8 | 8 |
| pirate_cove | Pirate Cove | 110 | 150 | 15 | 15 | 25 |
| shipwreck | Sunken Shipwreck | 150 | 200 | 25 | 30 | 80 |
| fossil_bed | Fossil Bed | 200 | 260 | 45 | 60 | 250 |
| bedrock | Bedrock | 260 | 330 | 80 | 120 | 450 |
| crystal_caverns | Crystal Caverns | 330 | 410 | 140 | 250 | 1200 |
| frozen_abyss | Frozen Abyss | 410 | 495 | 250 | 550 | 4000 |
| ancient_ruins | Ancient Ruins | 495 | 585 | 450 | 1200 | 15000 |
| magma_chamber | Magma Chamber | 585 | 680 | 800 | 2800 | 60000 |
| obsidian_depths | Obsidian Depths | 680 | 780 | 1400 | 6500 | 250000 |
| alien_hive | Alien Hive | 780 | 885 | 2500 | 16000 | 700000 |
| the_core | The Core | 885 | 1000 | 4500 | 40000 | 1800000 |

### Dry Sand (`dry_sand`)

```lua
{
		Id = "dry_sand",
		Name = "Dry Sand",
		DepthStart = 0,
		DepthEnd = 20,
		Material = Enum.Material.Sand,
		Color = rgb(255, 224, 150),
		Hardness = 1,
		SandValue = 1,
		TreasureChance = 0.04,
		LootTable = {
			{ TreasureId = "bottle_cap", Weight = 70 },
			{ TreasureId = "lost_flip_flop", Weight = 22 },
			{ TreasureId = "cool_sunglasses", Weight = 8 },
		},
		RewardScale = 1,
		FlavorText = "Warm, sunny and full of stuff tourists dropped. Every legend starts with a bucket!",
		AmbientColor = rgb(255, 236, 190),
	}
```

### Wet Sand (`wet_sand`)

```lua
{
		Id = "wet_sand",
		Name = "Wet Sand",
		DepthStart = 20,
		DepthEnd = 45,
		Material = Enum.Material.Sandstone,
		Color = rgb(214, 172, 112),
		Hardness = 2,
		SandValue = 2,
		TreasureChance = 0.035,
		LootTable = {
			{ TreasureId = "seashell", Weight = 70 },
			{ TreasureId = "sand_dollar", Weight = 22 },
			{ TreasureId = "message_in_a_bottle", Weight = 8 },
		},
		RewardScale = 1.5,
		FlavorText = "Squishy, salty and perfect for sandcastles. The tide hides little gifts down here.",
		AmbientColor = rgb(230, 200, 150),
	}
```

### Shell Bed (`shell_bed`)

```lua
{
		Id = "shell_bed",
		Name = "Shell Bed",
		DepthStart = 45,
		DepthEnd = 75,
		Material = Enum.Material.Salt,
		Color = rgb(255, 214, 214),
		Hardness = 4,
		SandValue = 4,
		TreasureChance = 0.035,
		LootTable = {
			{ TreasureId = "conch_shell", Weight = 70 },
			{ TreasureId = "glowing_pearl", Weight = 25 },
			{ TreasureId = "giant_clam", Weight = 5 },
		},
		RewardScale = 3,
		FlavorText = "A million years of seashells packed together. Hold one to your ear... is that the Core humming?",
		AmbientColor = rgb(255, 210, 220),
	}
```

### Tidal Clay (`tidal_clay`)

```lua
{
		Id = "tidal_clay",
		Name = "Tidal Clay",
		DepthStart = 75,
		DepthEnd = 110,
		Material = Enum.Material.Mud,
		Color = rgb(150, 108, 82),
		Hardness = 8,
		SandValue = 8,
		TreasureChance = 0.03,
		LootTable = {
			{ TreasureId = "rusty_anchor", Weight = 70 },
			{ TreasureId = "pocket_watch", Weight = 22 },
			{ TreasureId = "mermaid_comb", Weight = 8 },
		},
		RewardScale = 8,
		FlavorText = "Sticky clay that swallowed whole fishing boats. Something shiny is stuck in it.",
		AmbientColor = rgb(170, 130, 100),
	}
```

### Pirate Cove (`pirate_cove`)

```lua
{
		Id = "pirate_cove",
		Name = "Pirate Cove",
		DepthStart = 110,
		DepthEnd = 150,
		Material = Enum.Material.Ground,
		Color = rgb(122, 86, 56),
		Hardness = 15,
		SandValue = 15,
		TreasureChance = 0.03,
		LootTable = {
			{ TreasureId = "gold_doubloon", Weight = 68 },
			{ TreasureId = "pirate_hook", Weight = 22 },
			{ TreasureId = "treasure_map", Weight = 9 },
			{ TreasureId = "pirate_chest", Weight = 1 },
		},
		RewardScale = 25,
		FlavorText = "Captain Sandbeard buried his loot here 300 years ago. His map says 'X marks... deeper'.",
		AmbientColor = rgb(140, 100, 60),
	}
```

### Sunken Shipwreck (`shipwreck`)

```lua
{
		Id = "shipwreck",
		Name = "Sunken Shipwreck",
		DepthStart = 150,
		DepthEnd = 200,
		Material = Enum.Material.WoodPlanks,
		Color = rgb(128, 88, 54),
		Hardness = 25,
		SandValue = 30,
		TreasureChance = 0.03,
		LootTable = {
			{ TreasureId = "ships_wheel", Weight = 70 },
			{ TreasureId = "captains_spyglass", Weight = 26 },
			{ TreasureId = "cursed_skull", Weight = 4 },
		},
		RewardScale = 80,
		FlavorText = "The Salty Gull sank into the sand, not the sea. You're digging through its decks.",
		AmbientColor = rgb(110, 80, 55),
	}
```

### Fossil Bed (`fossil_bed`)

```lua
{
		Id = "fossil_bed",
		Name = "Fossil Bed",
		DepthStart = 200,
		DepthEnd = 260,
		Material = Enum.Material.Limestone,
		Color = rgb(228, 212, 176),
		Hardness = 45,
		SandValue = 60,
		TreasureChance = 0.03,
		LootTable = {
			{ TreasureId = "trilobite", Weight = 66 },
			{ TreasureId = "ammonite", Weight = 24 },
			{ TreasureId = "trex_tooth", Weight = 9 },
			{ TreasureId = "dino_skull", Weight = 1 },
		},
		RewardScale = 250,
		FlavorText = "Before the beach there was a jungle. Before the jungle there were DINOSAURS.",
		AmbientColor = rgb(220, 205, 170),
	}
```

### Bedrock (`bedrock`)

```lua
{
		Id = "bedrock",
		Name = "Bedrock",
		DepthStart = 260,
		DepthEnd = 330,
		Material = Enum.Material.Rock,
		Color = rgb(108, 110, 122),
		Hardness = 80,
		SandValue = 120,
		TreasureChance = 0.025,
		LootTable = {
			{ TreasureId = "geode", Weight = 70 },
			{ TreasureId = "iron_nugget", Weight = 22 },
			{ TreasureId = "ancient_arrowhead", Weight = 8 },
		},
		RewardScale = 450,
		FlavorText = "Solid stone that most diggers never get past. Crack a geode and see what sparkles.",
		AmbientColor = rgb(100, 100, 115),
	}
```

### Crystal Caverns (`crystal_caverns`)

```lua
{
		Id = "crystal_caverns",
		Name = "Crystal Caverns",
		DepthStart = 330,
		DepthEnd = 410,
		Material = Enum.Material.Glacier,
		Color = rgb(176, 112, 255),
		Hardness = 140,
		SandValue = 250,
		TreasureChance = 0.025,
		LootTable = {
			{ TreasureId = "amethyst", Weight = 66 },
			{ TreasureId = "sapphire", Weight = 24 },
			{ TreasureId = "glow_crystal", Weight = 9 },
			{ TreasureId = "rainbow_diamond", Weight = 1 },
		},
		RewardScale = 1200,
		FlavorText = "Glittering purple caves that glow in the dark. Nobody knows who lit them.",
		AmbientColor = rgb(150, 100, 230),
	}
```

### Frozen Abyss (`frozen_abyss`)

```lua
{
		Id = "frozen_abyss",
		Name = "Frozen Abyss",
		DepthStart = 410,
		DepthEnd = 495,
		Material = Enum.Material.Ice,
		Color = rgb(160, 226, 255),
		Hardness = 250,
		SandValue = 550,
		TreasureChance = 0.025,
		LootTable = {
			{ TreasureId = "frozen_fish", Weight = 70 },
			{ TreasureId = "mammoth_tusk", Weight = 26 },
			{ TreasureId = "ice_crown", Weight = 4 },
		},
		RewardScale = 4000,
		FlavorText = "An underground ice age! Brr... a woolly mammoth is still frozen in here somewhere.",
		AmbientColor = rgb(170, 225, 255),
	}
```

### Ancient Ruins (`ancient_ruins`)

```lua
{
		Id = "ancient_ruins",
		Name = "Ancient Ruins",
		DepthStart = 495,
		DepthEnd = 585,
		Material = Enum.Material.Brick,
		Color = rgb(206, 176, 110),
		Hardness = 450,
		SandValue = 1200,
		TreasureChance = 0.025,
		LootTable = {
			{ TreasureId = "stone_tablet", Weight = 66 },
			{ TreasureId = "golden_idol", Weight = 26 },
			{ TreasureId = "sun_mask", Weight = 7 },
			{ TreasureId = "atlantis_crown", Weight = 1 },
		},
		RewardScale = 15000,
		FlavorText = "The lost city of Sandlantis. Its people dug down too... and never came back up.",
		AmbientColor = rgb(200, 170, 110),
	}
```

### Magma Chamber (`magma_chamber`)

```lua
{
		Id = "magma_chamber",
		Name = "Magma Chamber",
		DepthStart = 585,
		DepthEnd = 680,
		Material = Enum.Material.CrackedLava,
		Color = rgb(255, 92, 32),
		Hardness = 800,
		SandValue = 2800,
		TreasureChance = 0.02,
		LootTable = {
			{ TreasureId = "obsidian_shard", Weight = 70 },
			{ TreasureId = "fire_ruby", Weight = 28 },
			{ TreasureId = "dragon_egg", Weight = 2 },
		},
		RewardScale = 60000,
		FlavorText = "Hot hot HOT! Rivers of lava light the way. Don't touch the glowing bits.",
		AmbientColor = rgb(255, 110, 50),
	}
```

### Obsidian Depths (`obsidian_depths`)

```lua
{
		Id = "obsidian_depths",
		Name = "Obsidian Depths",
		DepthStart = 680,
		DepthEnd = 780,
		Material = Enum.Material.Basalt,
		Color = rgb(52, 40, 72),
		Hardness = 1400,
		SandValue = 6500,
		TreasureChance = 0.02,
		LootTable = {
			{ TreasureId = "shadow_gem", Weight = 70 },
			{ TreasureId = "void_pearl", Weight = 26 },
			{ TreasureId = "dragon_scale", Weight = 4 },
		},
		RewardScale = 250000,
		FlavorText = "Black glass, total silence. Strange footprints lead deeper... they aren't human.",
		AmbientColor = rgb(70, 50, 100),
	}
```

### Alien Hive (`alien_hive`)

```lua
{
		Id = "alien_hive",
		Name = "Alien Hive",
		DepthStart = 780,
		DepthEnd = 885,
		Material = Enum.Material.Slate,
		Color = rgb(96, 232, 124),
		Hardness = 2500,
		SandValue = 16000,
		TreasureChance = 0.02,
		LootTable = {
			{ TreasureId = "alien_goo", Weight = 66 },
			{ TreasureId = "ufo_part", Weight = 24 },
			{ TreasureId = "alien_artifact", Weight = 9 },
			{ TreasureId = "alien_egg", Weight = 1 },
		},
		RewardScale = 700000,
		FlavorText = "A crashed spaceship grew into a glowing green hive. The aliens were looking for the Core too.",
		AmbientColor = rgb(110, 240, 140),
	}
```

### The Core (`the_core`)

```lua
{
		Id = "the_core",
		Name = "The Core",
		DepthStart = 885,
		DepthEnd = 1000,
		Material = Enum.Material.Pavement,
		Color = rgb(255, 200, 60),
		Hardness = 4500,
		SandValue = 40000,
		TreasureChance = 0.02,
		LootTable = {
			{ TreasureId = "core_fragment", Weight = 75 },
			{ TreasureId = "molten_gold", Weight = 22 },
			{ TreasureId = "heart_of_the_earth", Weight = 2.9 },
			{ TreasureId = "beach_ball_of_creation", Weight = 0.1 },
		},
		RewardScale = 1800000,
		FlavorText = "The golden heart of the planet. Legends say the very first beach ball was made here.",
		AmbientColor = rgb(255, 210, 90),
	}
```
## Pets — 56 records

| ID | Name | Rarity | Multiplier | Exclusive | VehicleKind | Rideable | Dig |
|---|---|---|---|---|---|---|---|
| sandy_crab | Sandy Crab | "Common" | 1.05 | false | — | — | { Power = 4, Interval = 4, Radius = 2, SandMultiplier = 1 } |
| seagull | Seagull | "Common" | 1.08 | false | — | — | — |
| starfish | Starfish | "Uncommon" | 1.12 | false | — | — | — |
| baby_turtle | Baby Turtle | "Rare" | 1.2 | false | — | — | — |
| golden_crab | Golden Crab | "Legendary" | 1.5 | false | — | — | — |
| clownfish | Clownfish | "Common" | 1.15 | false | — | — | — |
| pufferfish | Pufferfish | "Uncommon" | 1.22 | false | — | — | — |
| octopus | Octopus | "Rare" | 1.3 | false | — | — | — |
| sea_turtle | Sea Turtle | "Epic" | 1.45 | false | — | — | — |
| rainbow_starfish | Rainbow Starfish | "Legendary" | 1.8 | false | — | — | — |
| parrot | Pirate Parrot | "Common" | 1.3 | false | — | — | — |
| pirate_crab | Pirate Crab | "Uncommon" | 1.4 | false | — | — | { Power = 25, Interval = 3.5, Radius = 2.2, SandMultiplier = 3 } |
| ghost_blob | Ghost Blob | "Rare" | 1.55 | false | — | — | — |
| skeleton_shark | Skeleton Shark | "Epic" | 1.75 | false | — | — | — |
| kraken | Kraken | "Legendary" | 2.3 | false | — | — | — |
| mole | Mole | "Common" | 1.5 | false | — | — | { Power = 45, Interval = 3, Radius = 2.2, SandMultiplier = 4.2 } |
| baby_raptor | Baby Raptor | "Uncommon" | 1.7 | false | — | — | — |
| stegosaurus | Stegosaurus | "Rare" | 1.9 | false | — | — | — |
| trex | T-Rex | "Epic" | 2.2 | false | — | — | { Power = 80, Interval = 2.8, Radius = 2.4, SandMultiplier = 7.2 } |
| bone_dragon | Bone Dragon | "Legendary" | 3 | false | — | — | — |
| crystal_bat | Crystal Bat | "Common" | 1.8 | false | — | — | — |
| gem_blob | Gem Blob | "Uncommon" | 2.1 | false | — | — | — |
| crystal_golem | Crystal Golem | "Rare" | 2.5 | false | — | — | { Power = 140, Interval = 3, Radius = 2.4, SandMultiplier = 12 } |
| frost_seal | Frost Seal | "Epic" | 3 | false | — | — | — |
| diamond_dragon | Diamond Dragon | "Legendary" | 4 | false | — | — | — |
| lava_salamander | Lava Salamander | "Common" | 2.5 | false | — | — | { Power = 800, Interval = 3, Radius = 2.4, SandMultiplier = 34 } |
| magma_golem | Magma Golem | "Uncommon" | 3 | false | — | — | — |
| fire_bird | Fire Bird | "Rare" | 3.5 | false | — | — | — |
| lava_kraken | Lava Kraken | "Epic" | 4.5 | false | — | — | — |
| phoenix | Phoenix | "Legendary" | 6 | false | — | — | — |
| core_dragon | Core Dragon | "Mythic" | 10 | false | — | — | — |
| alien_blob | Alien Blob | "Common" | 3.5 | false | — | — | — |
| cosmic_turtle | Cosmic Turtle | "Rare" | 5 | false | — | — | — |
| star_golem | Star Golem | "Epic" | 7 | false | — | — | { Power = 2500, Interval = 2.8, Radius = 2.6, SandMultiplier = 104 } |
| galaxy_dragon | Galaxy Dragon | "Mythic" | 15 | false | — | — | — |
| tide_spirit | Tide Spirit | "Rare" | 1.6 | false | — | — | — |
| rebirth_phoenix | Rebirth Phoenix | "Epic" | 2 | false | — | — | — |
| sandlantis_guardian | Sandlantis Guardian | "Legendary" | 3 | false | — | — | — |
| golden_seagull | Golden Seagull | "Epic" | 1.8 | false | — | — | — |
| golden_turtle | Golden Turtle | "Legendary" | 2.6 | false | — | — | — |
| sun_dragon | Sun Dragon | "Mythic" | 4.5 | false | — | — | — |
| sunny_seal | Sunny Seal | "Epic" | 1.5 | true | — | — | — |
| launch_crab | Launch Party Crab | "Rare" | 1.25 | true | — | — | — |
| toy_truck | Toy Sand Truck | "Common" | 1.05 | false | "ToyTruck" | — | { Power = 15, Interval = 3, Radius = 2.2, SandMultiplier = 2.25 } |
| dump_truck | Little Dump Truck | "Uncommon" | 1.08 | false | "DumpTruck" | — | { Power = 25, Interval = 2.8, Radius = 2.2, SandMultiplier = 3.6 } |
| mini_excavator | Mini Excavator | "Rare" | 1.12 | false | "Excavator" | — | { Power = 45, Interval = 2.6, Radius = 2.4, SandMultiplier = 6.4 } |
| skid_steer | Skid Steer | "Common" | 1.15 | false | "SkidSteer" | — | { Power = 80, Interval = 2.4, Radius = 2.4, SandMultiplier = 6.2 } |
| bulldozer | Bulldozer | "Uncommon" | 1.2 | false | "Bulldozer" | — | { Power = 140, Interval = 2.3, Radius = 2.6, SandMultiplier = 10.8 } |
| backhoe | Backhoe Loader | "Rare" | 1.3 | false | "Backhoe" | — | { Power = 250, Interval = 2.2, Radius = 2.6, SandMultiplier = 18.5 } |
| drill_rig | Drill Rig | "Common" | 1.4 | false | "DrillRig" | — | { Power = 450, Interval = 2, Radius = 2.8, SandMultiplier = 18 } |
| mining_drill | Mining Cart Drill | "Uncommon" | 1.55 | false | "MiningDrill" | — | { Power = 800, Interval = 1.9, Radius = 2.8, SandMultiplier = 32 } |
| tunnel_borer | Tunnel Borer | "Rare" | 1.75 | false | "TunnelBorer" | — | { Power = 1400, Interval = 1.8, Radius = 2.8, SandMultiplier = 56 } |
| mole_machine | Mole Machine | "Common" | 2 | false | "Mole" | — | { Power = 2500, Interval = 1.7, Radius = 2.8, SandMultiplier = 63 } |
| lava_drill | Lava Drill | "Rare" | 2.4 | false | "LavaDrill" | — | { Power = 2500, Interval = 1.6, Radius = 2.8, SandMultiplier = 77 } |
| core_driller | Core Driller | "Legendary" | 3 | false | "CoreDriller" | — | { Power = 4500, Interval = 1.5, Radius = 3.2, SandMultiplier = 140 } |
| mega_excavator | Mega Excavator | "Mythic" | 4 | false | "Excavator" | true | { Power = 4500, Interval = 1.4, Radius = 3.6, SandMultiplier = 140 } |

### Sandy Crab (`sandy_crab`)

```lua
{
		Id = "sandy_crab",
		Name = "Sandy Crab",
		Rarity = "Common",
		Multiplier = 1.05,
		Dig = { Power = 4, Interval = 4, Radius = 2, SandMultiplier = 1 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 110, 80),
			AccentColor = rgb(255, 220, 180),
			Shape = "Crab",
			Size = 1,
			Glow = false,
		},
	}
```

### Seagull (`seagull`)

```lua
{
		Id = "seagull",
		Name = "Seagull",
		Rarity = "Common",
		Multiplier = 1.08,
		Exclusive = false,
		Look = {
			BodyColor = rgb(250, 250, 250),
			AccentColor = rgb(255, 190, 40),
			Shape = "Bird",
			Size = 1,
			Glow = false,
		},
	}
```

### Starfish (`starfish`)

```lua
{
		Id = "starfish",
		Name = "Starfish",
		Rarity = "Uncommon",
		Multiplier = 1.12,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 150, 60),
			AccentColor = rgb(255, 230, 120),
			Shape = "Star",
			Size = 1,
			Glow = false,
		},
	}
```

### Baby Turtle (`baby_turtle`)

```lua
{
		Id = "baby_turtle",
		Name = "Baby Turtle",
		Rarity = "Rare",
		Multiplier = 1.2,
		Exclusive = false,
		Look = {
			BodyColor = rgb(110, 200, 90),
			AccentColor = rgb(190, 140, 80),
			Shape = "Turtle",
			Size = 0.9,
			Glow = false,
		},
	}
```

### Golden Crab (`golden_crab`)

```lua
{
		Id = "golden_crab",
		Name = "Golden Crab",
		Rarity = "Legendary",
		Multiplier = 1.5,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 210, 40),
			AccentColor = rgb(255, 255, 200),
			Shape = "Crab",
			Size = 1.2,
			Glow = true,
		},
	}
```

### Clownfish (`clownfish`)

```lua
{
		Id = "clownfish",
		Name = "Clownfish",
		Rarity = "Common",
		Multiplier = 1.15,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 130, 30),
			AccentColor = rgb(255, 255, 255),
			Shape = "Fish",
			Size = 1,
			Glow = false,
		},
	}
```

### Pufferfish (`pufferfish`)

```lua
{
		Id = "pufferfish",
		Name = "Pufferfish",
		Rarity = "Uncommon",
		Multiplier = 1.22,
		Exclusive = false,
		Look = {
			BodyColor = rgb(250, 220, 100),
			AccentColor = rgb(120, 90, 60),
			Shape = "Blob",
			Size = 1,
			Glow = false,
		},
	}
```

### Octopus (`octopus`)

```lua
{
		Id = "octopus",
		Name = "Octopus",
		Rarity = "Rare",
		Multiplier = 1.3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(240, 90, 170),
			AccentColor = rgb(255, 200, 230),
			Shape = "Squid",
			Size = 1.1,
			Glow = false,
		},
	}
```

### Sea Turtle (`sea_turtle`)

```lua
{
		Id = "sea_turtle",
		Name = "Sea Turtle",
		Rarity = "Epic",
		Multiplier = 1.45,
		Exclusive = false,
		Look = {
			BodyColor = rgb(40, 170, 140),
			AccentColor = rgb(220, 190, 120),
			Shape = "Turtle",
			Size = 1.2,
			Glow = false,
		},
	}
```

### Rainbow Starfish (`rainbow_starfish`)

```lua
{
		Id = "rainbow_starfish",
		Name = "Rainbow Starfish",
		Rarity = "Legendary",
		Multiplier = 1.8,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 90, 200),
			AccentColor = rgb(90, 220, 255),
			Shape = "Star",
			Size = 1.3,
			Glow = true,
		},
	}
```

### Pirate Parrot (`parrot`)

```lua
{
		Id = "parrot",
		Name = "Pirate Parrot",
		Rarity = "Common",
		Multiplier = 1.3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(230, 40, 40),
			AccentColor = rgb(40, 120, 255),
			Shape = "Bird",
			Size = 1,
			Glow = false,
		},
	}
```

### Pirate Crab (`pirate_crab`)

```lua
{
		Id = "pirate_crab",
		Name = "Pirate Crab",
		Rarity = "Uncommon",
		Multiplier = 1.4,
		Dig = { Power = 25, Interval = 3.5, Radius = 2.2, SandMultiplier = 3 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(200, 50, 40),
			AccentColor = rgb(30, 30, 30),
			Shape = "Crab",
			Size = 1.1,
			Glow = false,
		},
	}
```

### Ghost Blob (`ghost_blob`)

```lua
{
		Id = "ghost_blob",
		Name = "Ghost Blob",
		Rarity = "Rare",
		Multiplier = 1.55,
		Exclusive = false,
		Look = {
			BodyColor = rgb(200, 255, 230),
			AccentColor = rgb(120, 220, 200),
			Shape = "Blob",
			Size = 1.1,
			Glow = true,
		},
	}
```

### Skeleton Shark (`skeleton_shark`)

```lua
{
		Id = "skeleton_shark",
		Name = "Skeleton Shark",
		Rarity = "Epic",
		Multiplier = 1.75,
		Exclusive = false,
		Look = {
			BodyColor = rgb(240, 235, 220),
			AccentColor = rgb(80, 80, 90),
			Shape = "Fish",
			Size = 1.3,
			Glow = false,
		},
	}
```

### Kraken (`kraken`)

```lua
{
		Id = "kraken",
		Name = "Kraken",
		Rarity = "Legendary",
		Multiplier = 2.3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(120, 40, 160),
			AccentColor = rgb(255, 120, 200),
			Shape = "Squid",
			Size = 1.5,
			Glow = true,
		},
	}
```

### Mole (`mole`)

```lua
{
		Id = "mole",
		Name = "Mole",
		Rarity = "Common",
		Multiplier = 1.5,
		Dig = { Power = 45, Interval = 3, Radius = 2.2, SandMultiplier = 4.2 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(110, 80, 70),
			AccentColor = rgb(255, 170, 180),
			Shape = "Mole",
			Size = 1,
			Glow = false,
		},
	}
```

### Baby Raptor (`baby_raptor`)

```lua
{
		Id = "baby_raptor",
		Name = "Baby Raptor",
		Rarity = "Uncommon",
		Multiplier = 1.7,
		Exclusive = false,
		Look = {
			BodyColor = rgb(120, 180, 80),
			AccentColor = rgb(230, 200, 120),
			Shape = "Dino",
			Size = 1,
			Glow = false,
		},
	}
```

### Stegosaurus (`stegosaurus`)

```lua
{
		Id = "stegosaurus",
		Name = "Stegosaurus",
		Rarity = "Rare",
		Multiplier = 1.9,
		Exclusive = false,
		Look = {
			BodyColor = rgb(90, 150, 200),
			AccentColor = rgb(255, 140, 60),
			Shape = "Dino",
			Size = 1.2,
			Glow = false,
		},
	}
```

### T-Rex (`trex`)

```lua
{
		Id = "trex",
		Name = "T-Rex",
		Rarity = "Epic",
		Multiplier = 2.2,
		Dig = { Power = 80, Interval = 2.8, Radius = 2.4, SandMultiplier = 7.2 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(70, 140, 70),
			AccentColor = rgb(250, 240, 220),
			Shape = "Dino",
			Size = 1.4,
			Glow = false,
		},
	}
```

### Bone Dragon (`bone_dragon`)

```lua
{
		Id = "bone_dragon",
		Name = "Bone Dragon",
		Rarity = "Legendary",
		Multiplier = 3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(245, 240, 225),
			AccentColor = rgb(120, 255, 180),
			Shape = "Dragon",
			Size = 1.5,
			Glow = true,
		},
	}
```

### Crystal Bat (`crystal_bat`)

```lua
{
		Id = "crystal_bat",
		Name = "Crystal Bat",
		Rarity = "Common",
		Multiplier = 1.8,
		Exclusive = false,
		Look = {
			BodyColor = rgb(120, 70, 200),
			AccentColor = rgb(220, 170, 255),
			Shape = "Bird",
			Size = 1,
			Glow = false,
		},
	}
```

### Gem Blob (`gem_blob`)

```lua
{
		Id = "gem_blob",
		Name = "Gem Blob",
		Rarity = "Uncommon",
		Multiplier = 2.1,
		Exclusive = false,
		Look = {
			BodyColor = rgb(80, 200, 255),
			AccentColor = rgb(255, 255, 255),
			Shape = "Blob",
			Size = 1,
			Glow = true,
		},
	}
```

### Crystal Golem (`crystal_golem`)

```lua
{
		Id = "crystal_golem",
		Name = "Crystal Golem",
		Rarity = "Rare",
		Multiplier = 2.5,
		Dig = { Power = 140, Interval = 3, Radius = 2.4, SandMultiplier = 12 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(180, 110, 255),
			AccentColor = rgb(240, 220, 255),
			Shape = "Golem",
			Size = 1.3,
			Glow = true,
		},
	}
```

### Frost Seal (`frost_seal`)

```lua
{
		Id = "frost_seal",
		Name = "Frost Seal",
		Rarity = "Epic",
		Multiplier = 3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(200, 240, 255),
			AccentColor = rgb(80, 160, 255),
			Shape = "Seal",
			Size = 1.2,
			Glow = true,
		},
	}
```

### Diamond Dragon (`diamond_dragon`)

```lua
{
		Id = "diamond_dragon",
		Name = "Diamond Dragon",
		Rarity = "Legendary",
		Multiplier = 4,
		Exclusive = false,
		Look = {
			BodyColor = rgb(200, 250, 255),
			AccentColor = rgb(150, 120, 255),
			Shape = "Dragon",
			Size = 1.5,
			Glow = true,
		},
	}
```

### Lava Salamander (`lava_salamander`)

```lua
{
		Id = "lava_salamander",
		Name = "Lava Salamander",
		Rarity = "Common",
		Multiplier = 2.5,
		Dig = { Power = 800, Interval = 3, Radius = 2.4, SandMultiplier = 34 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 110, 30),
			AccentColor = rgb(60, 30, 30),
			Shape = "Dino",
			Size = 1,
			Glow = true,
		},
	}
```

### Magma Golem (`magma_golem`)

```lua
{
		Id = "magma_golem",
		Name = "Magma Golem",
		Rarity = "Uncommon",
		Multiplier = 3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(100, 65, 60),
			AccentColor = rgb(255, 120, 30),
			Shape = "Golem",
			Size = 1.3,
			Glow = true,
		},
	}
```

### Fire Bird (`fire_bird`)

```lua
{
		Id = "fire_bird",
		Name = "Fire Bird",
		Rarity = "Rare",
		Multiplier = 3.5,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 80, 30),
			AccentColor = rgb(255, 220, 60),
			Shape = "Bird",
			Size = 1.1,
			Glow = true,
		},
	}
```

### Lava Kraken (`lava_kraken`)

```lua
{
		Id = "lava_kraken",
		Name = "Lava Kraken",
		Rarity = "Epic",
		Multiplier = 4.5,
		Exclusive = false,
		Look = {
			BodyColor = rgb(200, 40, 20),
			AccentColor = rgb(255, 200, 40),
			Shape = "Squid",
			Size = 1.4,
			Glow = true,
		},
	}
```

### Phoenix (`phoenix`)

```lua
{
		Id = "phoenix",
		Name = "Phoenix",
		Rarity = "Legendary",
		Multiplier = 6,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 170, 30),
			AccentColor = rgb(255, 60, 40),
			Shape = "Bird",
			Size = 1.5,
			Glow = true,
		},
	}
```

### Core Dragon (`core_dragon`)

```lua
{
		Id = "core_dragon",
		Name = "Core Dragon",
		Rarity = "Mythic",
		Multiplier = 10,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 210, 60),
			AccentColor = rgb(255, 90, 20),
			Shape = "Dragon",
			Size = 1.6,
			Glow = true,
		},
	}
```

### Alien Blob (`alien_blob`)

```lua
{
		Id = "alien_blob",
		Name = "Alien Blob",
		Rarity = "Common",
		Multiplier = 3.5,
		Exclusive = false,
		Look = {
			BodyColor = rgb(110, 255, 120),
			AccentColor = rgb(40, 120, 60),
			Shape = "Blob",
			Size = 1,
			Glow = true,
		},
	}
```

### Cosmic Turtle (`cosmic_turtle`)

```lua
{
		Id = "cosmic_turtle",
		Name = "Cosmic Turtle",
		Rarity = "Rare",
		Multiplier = 5,
		Exclusive = false,
		Look = {
			BodyColor = rgb(60, 40, 140),
			AccentColor = rgb(150, 220, 255),
			Shape = "Turtle",
			Size = 1.3,
			Glow = true,
		},
	}
```

### Star Golem (`star_golem`)

```lua
{
		Id = "star_golem",
		Name = "Star Golem",
		Rarity = "Epic",
		Multiplier = 7,
		Dig = { Power = 2500, Interval = 2.8, Radius = 2.6, SandMultiplier = 104 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(65, 65, 110),
			AccentColor = rgb(255, 240, 120),
			Shape = "Golem",
			Size = 1.4,
			Glow = true,
		},
	}
```

### Galaxy Dragon (`galaxy_dragon`)

```lua
{
		Id = "galaxy_dragon",
		Name = "Galaxy Dragon",
		Rarity = "Mythic",
		Multiplier = 15,
		Exclusive = false,
		Look = {
			BodyColor = rgb(90, 40, 200),
			AccentColor = rgb(255, 120, 255),
			Shape = "Dragon",
			Size = 1.6,
			Glow = true,
		},
	}
```

### Tide Spirit (`tide_spirit`)

```lua
{
		Id = "tide_spirit",
		Name = "Tide Spirit",
		Rarity = "Rare",
		Multiplier = 1.6,
		Exclusive = false,
		Look = {
			BodyColor = rgb(120, 220, 255),
			AccentColor = rgb(255, 255, 255),
			Shape = "Blob",
			Size = 1.1,
			Glow = true,
		},
	}
```

### Rebirth Phoenix (`rebirth_phoenix`)

```lua
{
		Id = "rebirth_phoenix",
		Name = "Rebirth Phoenix",
		Rarity = "Epic",
		Multiplier = 2,
		Exclusive = false,
		Look = {
			BodyColor = rgb(120, 255, 200),
			AccentColor = rgb(255, 255, 140),
			Shape = "Bird",
			Size = 1.3,
			Glow = true,
		},
	}
```

### Sandlantis Guardian (`sandlantis_guardian`)

```lua
{
		Id = "sandlantis_guardian",
		Name = "Sandlantis Guardian",
		Rarity = "Legendary",
		Multiplier = 3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(230, 190, 100),
			AccentColor = rgb(60, 200, 200),
			Shape = "Golem",
			Size = 1.5,
			Glow = true,
		},
	}
```

### Golden Seagull (`golden_seagull`)

```lua
{
		Id = "golden_seagull",
		Name = "Golden Seagull",
		Rarity = "Epic",
		Multiplier = 1.8,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 215, 60),
			AccentColor = rgb(255, 255, 255),
			Shape = "Bird",
			Size = 1.2,
			Glow = true,
		},
	}
```

### Golden Turtle (`golden_turtle`)

```lua
{
		Id = "golden_turtle",
		Name = "Golden Turtle",
		Rarity = "Legendary",
		Multiplier = 2.6,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 200, 40),
			AccentColor = rgb(255, 240, 170),
			Shape = "Turtle",
			Size = 1.4,
			Glow = true,
		},
	}
```

### Sun Dragon (`sun_dragon`)

```lua
{
		Id = "sun_dragon",
		Name = "Sun Dragon",
		Rarity = "Mythic",
		Multiplier = 4.5,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 180, 30),
			AccentColor = rgb(255, 255, 180),
			Shape = "Dragon",
			Size = 1.6,
			Glow = true,
		},
	}
```

### Sunny Seal (`sunny_seal`)

```lua
{
		Id = "sunny_seal",
		Name = "Sunny Seal",
		Rarity = "Epic",
		Multiplier = 1.5,
		Exclusive = true,
		Look = {
			BodyColor = rgb(250, 250, 255),
			AccentColor = rgb(255, 190, 60),
			Shape = "Seal",
			Size = 1.1,
			Glow = false,
		},
	}
```

### Launch Party Crab (`launch_crab`)

```lua
{
		Id = "launch_crab",
		Name = "Launch Party Crab",
		Rarity = "Rare",
		Multiplier = 1.25,
		Exclusive = true,
		Look = {
			BodyColor = rgb(60, 200, 255),
			AccentColor = rgb(255, 230, 60),
			Shape = "Crab",
			Size = 1,
			Glow = true,
		},
	}
```

### Toy Sand Truck (`toy_truck`)

```lua
{
		Id = "toy_truck",
		Name = "Toy Sand Truck",
		Rarity = "Common",
		Multiplier = 1.05,
		Exclusive = false,
		VehicleKind = "ToyTruck",
		Dig = { Power = 15, Interval = 3, Radius = 2.2, SandMultiplier = 2.25 },
		Look = {
			BodyColor = rgb(255, 210, 50),
			AccentColor = rgb(240, 70, 70),
			Shape = "Vehicle",
			Size = 0.95,
			Glow = false,
		},
	}
```

### Little Dump Truck (`dump_truck`)

```lua
{
		Id = "dump_truck",
		Name = "Little Dump Truck",
		Rarity = "Uncommon",
		Multiplier = 1.08,
		Exclusive = false,
		VehicleKind = "DumpTruck",
		Dig = { Power = 25, Interval = 2.8, Radius = 2.2, SandMultiplier = 3.6 },
		Look = {
			BodyColor = rgb(255, 150, 40),
			AccentColor = rgb(70, 80, 95),
			Shape = "Vehicle",
			Size = 0.85,
			Glow = false,
		},
	}
```

### Mini Excavator (`mini_excavator`)

```lua
{
		Id = "mini_excavator",
		Name = "Mini Excavator",
		Rarity = "Rare",
		Multiplier = 1.12,
		Exclusive = false,
		VehicleKind = "Excavator",
		Dig = { Power = 45, Interval = 2.6, Radius = 2.4, SandMultiplier = 6.4 },
		Look = {
			BodyColor = rgb(255, 200, 30),
			AccentColor = rgb(55, 55, 65),
			Shape = "Vehicle",
			Size = 0.85,
			Glow = false,
		},
	}
```

### Skid Steer (`skid_steer`)

```lua
{
		Id = "skid_steer",
		Name = "Skid Steer",
		Rarity = "Common",
		Multiplier = 1.15,
		Exclusive = false,
		VehicleKind = "SkidSteer",
		Dig = { Power = 80, Interval = 2.4, Radius = 2.4, SandMultiplier = 6.2 },
		Look = {
			BodyColor = rgb(80, 200, 90),
			AccentColor = rgb(45, 50, 60),
			Shape = "Vehicle",
			Size = 0.85,
			Glow = false,
		},
	}
```

### Bulldozer (`bulldozer`)

```lua
{
		Id = "bulldozer",
		Name = "Bulldozer",
		Rarity = "Uncommon",
		Multiplier = 1.2,
		Exclusive = false,
		VehicleKind = "Bulldozer",
		Dig = { Power = 140, Interval = 2.3, Radius = 2.6, SandMultiplier = 10.8 },
		Look = {
			BodyColor = rgb(255, 185, 20),
			AccentColor = rgb(60, 60, 70),
			Shape = "Vehicle",
			Size = 0.8,
			Glow = false,
		},
	}
```

### Backhoe Loader (`backhoe`)

```lua
{
		Id = "backhoe",
		Name = "Backhoe Loader",
		Rarity = "Rare",
		Multiplier = 1.3,
		Exclusive = false,
		VehicleKind = "Backhoe",
		Dig = { Power = 250, Interval = 2.2, Radius = 2.6, SandMultiplier = 18.5 },
		Look = {
			BodyColor = rgb(90, 170, 255),
			AccentColor = rgb(40, 60, 110),
			Shape = "Vehicle",
			Size = 0.8,
			Glow = false,
		},
	}
```

### Drill Rig (`drill_rig`)

```lua
{
		Id = "drill_rig",
		Name = "Drill Rig",
		Rarity = "Common",
		Multiplier = 1.4,
		Exclusive = false,
		VehicleKind = "DrillRig",
		Dig = { Power = 450, Interval = 2, Radius = 2.8, SandMultiplier = 18 },
		Look = {
			BodyColor = rgb(230, 60, 60),
			AccentColor = rgb(200, 205, 215),
			Shape = "Vehicle",
			Size = 0.8,
			Glow = false,
		},
	}
```

### Mining Cart Drill (`mining_drill`)

```lua
{
		Id = "mining_drill",
		Name = "Mining Cart Drill",
		Rarity = "Uncommon",
		Multiplier = 1.55,
		Exclusive = false,
		VehicleKind = "MiningDrill",
		Dig = { Power = 800, Interval = 1.9, Radius = 2.8, SandMultiplier = 32 },
		Look = {
			BodyColor = rgb(150, 100, 60),
			AccentColor = rgb(255, 120, 30),
			Shape = "Vehicle",
			Size = 0.8,
			Glow = false,
		},
	}
```

### Tunnel Borer (`tunnel_borer`)

```lua
{
		Id = "tunnel_borer",
		Name = "Tunnel Borer",
		Rarity = "Rare",
		Multiplier = 1.75,
		Exclusive = false,
		VehicleKind = "TunnelBorer",
		Dig = { Power = 1400, Interval = 1.8, Radius = 2.8, SandMultiplier = 56 },
		Look = {
			BodyColor = rgb(120, 70, 200),
			AccentColor = rgb(60, 40, 90),
			Shape = "Vehicle",
			Size = 0.75,
			Glow = true,
		},
	}
```

### Mole Machine (`mole_machine`)

```lua
{
		Id = "mole_machine",
		Name = "Mole Machine",
		Rarity = "Common",
		Multiplier = 2,
		Exclusive = false,
		VehicleKind = "Mole",
		Dig = { Power = 2500, Interval = 1.7, Radius = 2.8, SandMultiplier = 63 },
		Look = {
			BodyColor = rgb(140, 110, 95),
			AccentColor = rgb(90, 255, 140),
			Shape = "Vehicle",
			Size = 0.75,
			Glow = true,
		},
	}
```

### Lava Drill (`lava_drill`)

```lua
{
		Id = "lava_drill",
		Name = "Lava Drill",
		Rarity = "Rare",
		Multiplier = 2.4,
		Exclusive = false,
		VehicleKind = "LavaDrill",
		Dig = { Power = 2500, Interval = 1.6, Radius = 2.8, SandMultiplier = 77 },
		Look = {
			BodyColor = rgb(50, 35, 35),
			AccentColor = rgb(255, 100, 20),
			Shape = "Vehicle",
			Size = 0.75,
			Glow = true,
		},
	}
```

### Core Driller (`core_driller`)

```lua
{
		Id = "core_driller",
		Name = "Core Driller",
		Rarity = "Legendary",
		Multiplier = 3,
		Exclusive = false,
		VehicleKind = "CoreDriller",
		Dig = { Power = 4500, Interval = 1.5, Radius = 3.2, SandMultiplier = 140 },
		Look = {
			BodyColor = rgb(255, 210, 60),
			AccentColor = rgb(255, 120, 40),
			Shape = "Vehicle",
			Size = 0.75,
			Glow = true,
		},
	}
```

### Mega Excavator (`mega_excavator`)

```lua
{
		Id = "mega_excavator",
		Name = "Mega Excavator",
		Rarity = "Mythic",
		Multiplier = 4,
		Exclusive = false,
		VehicleKind = "Excavator",
		Dig = { Power = 4500, Interval = 1.4, Radius = 3.6, SandMultiplier = 140 },
		Rideable = true,
		Look = {
			BodyColor = rgb(255, 190, 20),
			AccentColor = rgb(255, 90, 160),
			Shape = "Vehicle",
			Size = 1.25,
			Glow = true,
		},
	}
```
## Quests — 12 records

| ID | Name | Kind | Target | Reset | Reward |
|---|---|---|---|---|---|
| daily_dig_100 | Busy Beaver | "DigTimes" | 100 | "Daily" | { ScaledCoins = 60 } |
| daily_dig_1000 | Dig Machine | "DigTimes" | 1000 | "Daily" | { ScaledCoins = 240, Boost = "SandBoost", BoostSeconds = 600 } |
| daily_sell_10 | Sand Salesman | "SellTimes" | 10 | "Daily" | { ScaledCoins = 120 } |
| daily_treasure_10 | Treasure Hunter | "FindTreasures" | 10 | "Daily" | { ScaledCoins = 120, Boost = "LuckBoost", BoostSeconds = 600 } |
| daily_rare_1 | Lucky Find | "FindRarity" | 1 | "Daily" | { ScaledCoins = 180 } |
| daily_hatch_5 | Egg-cellent | "HatchEggs" | 5 | "Daily" | { ScaledCoins = 150 } |
| daily_play_20 | Beach Day | "PlayMinutes" | 20 | "Daily" | { ScaledCoins = 120, Boost = "CoinBoost", BoostSeconds = 600 } |
| reach_pirate_cove | Yo Ho Ho! | "ReachDepth" | 110 | "Once" | { Coins = 1500 } |
| reach_fossil_bed | Jurassic Beach | "ReachDepth" | 200 | "Once" | { Coins = 25000, Egg = "beach_egg", EggCount = 3 } |
| reach_crystal_caverns | Shiny! | "ReachDepth" | 330 | "Once" | { Coins = 250000, Boost = "LuckBoost", BoostSeconds = 900 } |
| first_rebirth | Born Again Digger | "Rebirth" | 1 | "Once" | { RebirthTokens = 2 } |
| reach_the_core | Journey to the Center | "ReachDepth" | 885 | "Once" | { RebirthTokens = 10, ScaledCoins = 1800 } |

### Busy Beaver (`daily_dig_100`)

```lua
{
		Id = "daily_dig_100",
		Name = "Busy Beaver",
		Description = "Dig 100 times",
		Kind = "DigTimes",
		Target = 100,
		Reset = "Daily",
		Reward = { ScaledCoins = 60 },
	}
```

### Dig Machine (`daily_dig_1000`)

```lua
{
		Id = "daily_dig_1000",
		Name = "Dig Machine",
		Description = "Dig 1,000 times",
		Kind = "DigTimes",
		Target = 1000,
		Reset = "Daily",
		Reward = { ScaledCoins = 240, Boost = "SandBoost", BoostSeconds = 600 },
	}
```

### Sand Salesman (`daily_sell_10`)

```lua
{
		Id = "daily_sell_10",
		Name = "Sand Salesman",
		Description = "Sell your sand 10 times",
		Kind = "SellTimes",
		Target = 10,
		Reset = "Daily",
		Reward = { ScaledCoins = 120 },
	}
```

### Treasure Hunter (`daily_treasure_10`)

```lua
{
		Id = "daily_treasure_10",
		Name = "Treasure Hunter",
		Description = "Find 10 treasures",
		Kind = "FindTreasures",
		Target = 10,
		Reset = "Daily",
		Reward = { ScaledCoins = 120, Boost = "LuckBoost", BoostSeconds = 600 },
	}
```

### Lucky Find (`daily_rare_1`)

```lua
{
		Id = "daily_rare_1",
		Name = "Lucky Find",
		Description = "Find a Rare (or better) treasure",
		Kind = "FindRarity",
		Target = 1,
		Rarity = "Rare",
		Reset = "Daily",
		Reward = { ScaledCoins = 180 },
	}
```

### Egg-cellent (`daily_hatch_5`)

```lua
{
		Id = "daily_hatch_5",
		Name = "Egg-cellent",
		Description = "Hatch 5 eggs",
		Kind = "HatchEggs",
		Target = 5,
		Reset = "Daily",
		Reward = { ScaledCoins = 150 },
	}
```

### Beach Day (`daily_play_20`)

```lua
{
		Id = "daily_play_20",
		Name = "Beach Day",
		Description = "Play for 20 minutes",
		Kind = "PlayMinutes",
		Target = 20,
		Reset = "Daily",
		Reward = { ScaledCoins = 120, Boost = "CoinBoost", BoostSeconds = 600 },
	}
```

### Yo Ho Ho! (`reach_pirate_cove`)

```lua
{
		Id = "reach_pirate_cove",
		Name = "Yo Ho Ho!",
		Description = "Reach the Pirate Cove (110m)",
		Kind = "ReachDepth",
		Target = 110,
		Reset = "Once",
		Reward = { Coins = 1500 },
	}
```

### Jurassic Beach (`reach_fossil_bed`)

```lua
{
		Id = "reach_fossil_bed",
		Name = "Jurassic Beach",
		Description = "Reach the Fossil Bed (200m)",
		Kind = "ReachDepth",
		Target = 200,
		Reset = "Once",
		Reward = { Coins = 25000, Egg = "beach_egg", EggCount = 3 },
	}
```

### Shiny! (`reach_crystal_caverns`)

```lua
{
		Id = "reach_crystal_caverns",
		Name = "Shiny!",
		Description = "Reach the Crystal Caverns (330m)",
		Kind = "ReachDepth",
		Target = 330,
		Reset = "Once",
		Reward = { Coins = 250000, Boost = "LuckBoost", BoostSeconds = 900 },
	}
```

### Born Again Digger (`first_rebirth`)

```lua
{
		Id = "first_rebirth",
		Name = "Born Again Digger",
		Description = "Rebirth for the first time",
		Kind = "Rebirth",
		Target = 1,
		Reset = "Once",
		Reward = { RebirthTokens = 2 },
	}
```

### Journey to the Center (`reach_the_core`)

```lua
{
		Id = "reach_the_core",
		Name = "Journey to the Center",
		Description = "Reach THE CORE (885m)",
		Kind = "ReachDepth",
		Target = 885,
		Reset = "Once",
		Reward = { RebirthTokens = 10, ScaledCoins = 1800 },
	}
```
## Rarities — 7 records

| ID | Name | Price | Description | Reward |
|---|---|---|---|---|
| Common | Common | — | — | — |
| Uncommon | Uncommon | — | — | — |
| Rare | Rare | — | — | — |
| Epic | Epic | — | — | — |
| Legendary | Legendary | — | — | — |
| Mythic | Mythic | — | — | — |
| Relic | Relic | — | — | — |

### Common (`Common`)

```lua
{
		Name = "Common",
		Order = 1,
		Color = rgb(200, 205, 215),
		Gradient = { rgb(230, 232, 238), rgb(170, 176, 190) },
		Announce = false,
	}
```

### Uncommon (`Uncommon`)

```lua
{
		Name = "Uncommon",
		Order = 2,
		Color = rgb(90, 220, 100),
		Gradient = { rgb(150, 255, 150), rgb(40, 180, 80) },
		Announce = false,
	}
```

### Rare (`Rare`)

```lua
{
		Name = "Rare",
		Order = 3,
		Color = rgb(60, 160, 255),
		Gradient = { rgb(120, 210, 255), rgb(30, 100, 240) },
		Announce = false,
	}
```

### Epic (`Epic`)

```lua
{
		Name = "Epic",
		Order = 4,
		Color = rgb(180, 90, 255),
		Gradient = { rgb(220, 150, 255), rgb(130, 50, 230) },
		Announce = false,
	}
```

### Legendary (`Legendary`)

```lua
{
		Name = "Legendary",
		Order = 5,
		Color = rgb(255, 190, 30),
		Gradient = { rgb(255, 235, 100), rgb(255, 130, 20) },
		Announce = true,
	}
```

### Mythic (`Mythic`)

```lua
{
		Name = "Mythic",
		Order = 6,
		Color = rgb(255, 70, 140),
		Gradient = { rgb(255, 90, 90), rgb(255, 210, 60), rgb(90, 220, 255), rgb(200, 90, 255) },
		Announce = true,
	}
```

### Relic (`Relic`)

```lua
{
		Name = "Relic",
		Order = 7,
		Color = rgb(120, 255, 230),
		Gradient = { rgb(255, 255, 255), rgb(120, 255, 230), rgb(255, 120, 230), rgb(255, 230, 120) },
		Announce = true,
	}
```
## RebirthPerks — 8 records

| ID | Name | Costs | Effects |
|---|---|---|---|
| SellAnywhere | Sell Anywhere | { 5 } | — |
| HeadStart | Head Start | { 1, 2, 3, 5, 8 } | — |
| GoldenTouch | Golden Touch | { 1, 2, 3, 4, 5 } | — |
| KeepBackpack | Keep Backpack | { 1, 3, 6 } | — |
| DeepPockets | Deep Pockets | { 1, 1, 2, 3, 4 } | — |
| LuckyDigger | Lucky Digger | { 1, 2, 2, 3, 4 } | — |
| LongNap | Long Nap | { 1, 2, 3, 4 } | — |
| PetDen | Pet Den | { 3, 6 } | — |

### Sell Anywhere (`SellAnywhere`)

```lua
{
		Id = "SellAnywhere",
		Name = "Sell Anywhere",
		Icon = "sell|💸",
		Description = "Sell from anywhere with one tap, like the game pass.",
		Costs = { 5 },
		Levels = { { Unlocked = true } },
		Order = 1,
	}
```

### Head Start (`HeadStart`)

```lua
{
		Id = "HeadStart",
		Name = "Head Start",
		Icon = "shovel|⛏️",
		Description = "Start every rebirth with a better shovel and some coins.",
		Costs = { 1, 2, 3, 5, 8 },
		Levels = {
			{ ShovelIndex = 4, Coins = 500 }, -- Lifeguard Shovel
			{ ShovelIndex = 5, Coins = 5_000 }, -- Pirate Shovel
			{ ShovelIndex = 6, Coins = 25_000 }, -- Bone Claw
			{ ShovelIndex = 7, Coins = 100_000 }, -- Steel Pickaxe
			{ ShovelIndex = 8, Coins = 400_000 }, -- Crystal Spade
		},
		Order = 2,
	}
```

### Golden Touch (`GoldenTouch`)

```lua
{
		Id = "GoldenTouch",
		Name = "Golden Touch",
		Icon = "boost_coins|💰",
		Description = "More coins every time you sell.",
		Costs = { 1, 2, 3, 4, 5 },
		Levels = { { Coin = 1.1 }, { Coin = 1.2 }, { Coin = 1.3 }, { Coin = 1.4 }, { Coin = 1.5 } },
		Order = 3,
	}
```

### Keep Backpack (`KeepBackpack`)

```lua
{
		Id = "KeepBackpack",
		Name = "Keep Backpack",
		Icon = "backpack|🎒",
		Description = "Keep your backpack when you rebirth.",
		Costs = { 1, 3, 6 },
		Levels = {
			{ KeepIndex = 5 }, -- up to Treasure Sack
			{ KeepIndex = 8 }, -- up to Wheelbarrow
			{ KeepIndex = 99 }, -- any backpack
		},
		Order = 4,
	}
```

### Deep Pockets (`DeepPockets`)

```lua
{
		Id = "DeepPockets",
		Name = "Deep Pockets",
		Icon = "sand|⏳",
		Description = "Your backpack holds more sand.",
		Costs = { 1, 1, 2, 3, 4 },
		Levels = {
			{ Capacity = 1.1 },
			{ Capacity = 1.2 },
			{ Capacity = 1.3 },
			{ Capacity = 1.4 },
			{ Capacity = 1.5 },
		},
		Order = 5,
	}
```

### Lucky Digger (`LuckyDigger`)

```lua
{
		Id = "LuckyDigger",
		Name = "Lucky Digger",
		Icon = "boost_luck|🍀",
		Description = "Find treasure more often while digging.",
		Costs = { 1, 2, 2, 3, 4 },
		Levels = {
			{ TreasureChance = 1.1 },
			{ TreasureChance = 1.2 },
			{ TreasureChance = 1.3 },
			{ TreasureChance = 1.4 },
			{ TreasureChance = 1.5 },
		},
		Order = 6,
	}
```

### Long Nap (`LongNap`)

```lua
{
		Id = "LongNap",
		Name = "Long Nap",
		Icon = "hourglass|⏳",
		Description = "Your pets dig longer and harder while you are away.",
		Costs = { 1, 2, 3, 4 },
		Levels = {
			{ OfflineHours = 1, OfflineEfficiency = 0.1 },
			{ OfflineHours = 2, OfflineEfficiency = 0.2 },
			{ OfflineHours = 3, OfflineEfficiency = 0.3 },
			{ OfflineHours = 4, OfflineEfficiency = 0.4 },
		},
		Order = 7,
	}
```

### Pet Den (`PetDen`)

```lua
{
		Id = "PetDen",
		Name = "Pet Den",
		Icon = "pets|🐾",
		Description = "+1 pet slot.",
		Costs = { 3, 6 },
		Levels = { { PetSlots = 1 }, { PetSlots = 2 } },
		Order = 8,
	}
```
## Shades — 7 records

| ID | Name | Price | Radius | Cooling |
|---|---|---|---|---|
| beach_umbrella | Beach Umbrella | 120 | 6 | 1 |
| striped_umbrella | Striped Umbrella | 1200 | 8 | 1.4 |
| palm_tarp | Palm Tarp | 12000 | 10 | 1.8 |
| party_canopy | Party Canopy | 100000 | 12 | 2.3 |
| tiki_cabana | Tiki Cabana | 750000 | 14 | 2.8 |
| luxury_tent | Luxury Beach Tent | 6000000 | 17 | 3.5 |
| royal_pavilion | Royal Sand Pavilion | 80000000 | 21 | 4.5 |

### Beach Umbrella (`beach_umbrella`)

```lua
{
		Id = "beach_umbrella",
		Name = "Beach Umbrella",
		Price = 120,
		Radius = 6,
		Cooling = 1,
		Height = 7.5,
		Description = "A trusty umbrella. Shade for you and a friend.",
		Look = { Style = "Umbrella", Color = rgb(255, 80, 90), Accent = rgb(255, 255, 255) },
	}
```

### Striped Umbrella (`striped_umbrella`)

```lua
{
		Id = "striped_umbrella",
		Name = "Striped Umbrella",
		Price = 1200,
		Radius = 8,
		Cooling = 1.4,
		Height = 8,
		Description = "Extra-wide rainbow stripes. Cools faster!",
		Look = { Style = "Striped", Color = rgb(40, 170, 255), Accent = rgb(255, 225, 60) },
	}
```

### Palm Tarp (`palm_tarp`)

```lua
{
		Id = "palm_tarp",
		Name = "Palm Tarp",
		Price = 12000,
		Radius = 10,
		Cooling = 1.8,
		Height = 8.5,
		Description = "A big tarp tied between palm-wood poles. Room for the squad.",
		Look = { Style = "Tarp", Color = rgb(255, 150, 40), Accent = rgb(176, 120, 72) },
	}
```

### Party Canopy (`party_canopy`)

```lua
{
		Id = "party_canopy",
		Name = "Party Canopy",
		Price = 100000,
		Radius = 12,
		Cooling = 2.3,
		Height = 9,
		Description = "A pop-up party tent with bunting. Very cool. Literally.",
		Look = { Style = "Canopy", Color = rgb(90, 210, 120), Accent = rgb(255, 255, 255) },
	}
```

### Tiki Cabana (`tiki_cabana`)

```lua
{
		Id = "tiki_cabana",
		Name = "Tiki Cabana",
		Price = 750000,
		Radius = 14,
		Cooling = 2.8,
		Height = 9,
		Description = "A thatched tiki hut with curtains. Island vibes.",
		Look = { Style = "Cabana", Color = rgb(225, 190, 110), Accent = rgb(255, 120, 150) },
	}
```

### Luxury Beach Tent (`luxury_tent`)

```lua
{
		Id = "luxury_tent",
		Name = "Luxury Beach Tent",
		Price = 6000000,
		RebirthsRequired = 1,
		Radius = 17,
		Cooling = 3.5,
		Height = 9.5,
		Description = "Silk walls and gold poles. Requires 1 Rebirth.",
		Look = { Style = "Tent", Color = rgb(250, 245, 235), Accent = rgb(255, 200, 40) },
	}
```

### Royal Sand Pavilion (`royal_pavilion`)

```lua
{
		Id = "royal_pavilion",
		Name = "Royal Sand Pavilion",
		Price = 80000000,
		RebirthsRequired = 3,
		Radius = 21,
		Cooling = 4.5,
		Height = 10,
		Description = "Fit for the King of Sandlantis. Shade for the whole beach! Requires 3 Rebirths.",
		Look = { Style = "Pavilion", Color = rgb(150, 90, 255), Accent = rgb(255, 205, 40) },
	}
```
## Shovels — 14 records

| ID | Name | Price | Power | Cooldown | Radius | SandMultiplier | RebirthsRequired |
|---|---|---|---|---|---|---|---|
| toy_shovel | Hand Spade | 0 | 2 | 0.5 | 2 | 1 | 0 |
| garden_trowel | Garden Trowel | 30 | 4 | 0.46 | 2.2 | 1.5 | 0 |
| metal_spade | Metal Spade | 150 | 8 | 0.43 | 2.5 | 2 | 0 |
| lifeguard_shovel | Lifeguard Shovel | 600 | 15 | 0.4 | 2.8 | 3 | 0 |
| pirate_shovel | Pirate Shovel | 2500 | 25 | 0.37 | 3.2 | 4 | 0 |
| bone_claw | Bone Claw | 9000 | 45 | 0.34 | 3.5 | 6 | 0 |
| steel_pickaxe | Steel Pickaxe | 35000 | 80 | 0.31 | 3.8 | 8 | 0 |
| crystal_spade | Crystal Spade | 140000 | 140 | 0.28 | 4.4 | 11 | 0 |
| frostbite_pick | Frostbite Pick | 600000 | 250 | 0.25 | 5 | 15 | 0 |
| ancient_trident | Ancient Trident | 2500000 | 450 | 0.22 | 5.5 | 20 | 1 |
| magma_pick | Magma Pick | 12000000 | 800 | 0.2 | 6 | 28 | 2 |
| obsidian_drill | Obsidian Drill | 60000000 | 1400 | 0.17 | 6.6 | 38 | 4 |
| plasma_drill | Plasma Drill | 350000000 | 2500 | 0.14 | 7.2 | 52 | 6 |
| core_breaker | Core Breaker | 2500000000 | 4500 | 0.12 | 8 | 75 | 10 |

### Hand Spade (`toy_shovel`)

```lua
{
		Id = "toy_shovel", -- id kept from v1 ("Plastic Toy Shovel") so saves keep working
		Name = "Hand Spade",
		Price = 0,
		Power = 2,
		Cooldown = 0.5,
		Radius = 2,
		SandMultiplier = 1,
		RebirthsRequired = 0,
		Description = "A little plastic beach spade. Everyone starts somewhere! Digs Dry and Wet Sand.",
		Look = {
			HeadColor = rgb(255, 70, 70),
			HandleColor = rgb(255, 210, 50),
			HeadShape = "Scoop",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
			Size = "Hand",
		},
	}
```

### Garden Trowel (`garden_trowel`)

```lua
{
		Id = "garden_trowel",
		Name = "Garden Trowel",
		Price = 30,
		Power = 4,
		Cooldown = 0.46,
		Radius = 2.2,
		SandMultiplier = 1.5,
		RebirthsRequired = 0,
		Description = "Borrowed from Grandma's garden. Breaks into the Shell Bed!",
		Look = {
			HeadColor = rgb(190, 195, 205),
			HandleColor = rgb(70, 200, 90),
			HeadShape = "Trowel",
			Material = Enum.Material.Metal,
			Glow = false,
			Size = "Hand",
		},
	}
```

### Metal Spade (`metal_spade`)

```lua
{
		Id = "metal_spade",
		Name = "Metal Spade",
		Price = 150,
		Power = 8,
		Cooldown = 0.43,
		Radius = 2.5,
		SandMultiplier = 2,
		RebirthsRequired = 0,
		Description = "A real grown-up shovel. Cuts through sticky Tidal Clay.",
		Look = {
			HeadColor = rgb(170, 175, 185),
			HandleColor = rgb(140, 95, 55),
			HeadShape = "Spade",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	}
```

### Lifeguard Shovel (`lifeguard_shovel`)

```lua
{
		Id = "lifeguard_shovel",
		Name = "Lifeguard Shovel",
		Price = 600,
		Power = 15,
		Cooldown = 0.4,
		Radius = 2.8,
		SandMultiplier = 3,
		RebirthsRequired = 0,
		Description = "Red, white and ready for rescue digs. Reaches Pirate Cove.",
		Look = {
			HeadColor = rgb(235, 40, 40),
			HandleColor = rgb(255, 255, 255),
			HeadShape = "Spade",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	}
```

### Pirate Shovel (`pirate_shovel`)

```lua
{
		Id = "pirate_shovel",
		Name = "Pirate Shovel",
		Price = 2500,
		Power = 25,
		Cooldown = 0.37,
		Radius = 3.2,
		SandMultiplier = 4,
		RebirthsRequired = 0,
		Description = "Captain Sandbeard's own. Smashes through shipwreck planks.",
		Look = {
			HeadColor = rgb(255, 200, 40),
			HandleColor = rgb(90, 55, 30),
			HeadShape = "Spade",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	}
```

### Bone Claw (`bone_claw`)

```lua
{
		Id = "bone_claw",
		Name = "Bone Claw",
		Price = 9000,
		Power = 45,
		Cooldown = 0.34,
		Radius = 3.5,
		SandMultiplier = 6,
		RebirthsRequired = 0,
		Description = "Made from a raptor claw. Perfect for fossil hunting.",
		Look = {
			HeadColor = rgb(245, 238, 215),
			HandleColor = rgb(160, 120, 80),
			HeadShape = "Claw",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	}
```

### Steel Pickaxe (`steel_pickaxe`)

```lua
{
		Id = "steel_pickaxe",
		Name = "Steel Pickaxe",
		Price = 35000,
		Power = 80,
		Cooldown = 0.31,
		Radius = 3.8,
		SandMultiplier = 8,
		RebirthsRequired = 0,
		Description = "Miner-grade steel. Cracks Bedrock like a cookie.",
		Look = {
			HeadColor = rgb(165, 180, 195),
			HandleColor = rgb(60, 60, 70),
			HeadShape = "Pick",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	}
```

### Crystal Spade (`crystal_spade`)

```lua
{
		Id = "crystal_spade",
		Name = "Crystal Spade",
		Price = 140000,
		Power = 140,
		Cooldown = 0.28,
		Radius = 4.4,
		SandMultiplier = 11,
		RebirthsRequired = 0,
		Description = "Carved from a single giant amethyst. Opens the Crystal Caverns.",
		Look = {
			HeadColor = rgb(180, 110, 255),
			HandleColor = rgb(240, 220, 255),
			HeadShape = "Spade",
			Material = Enum.Material.Glass,
			Glow = true,
		},
	}
```

### Frostbite Pick (`frostbite_pick`)

```lua
{
		Id = "frostbite_pick",
		Name = "Frostbite Pick",
		Price = 600000,
		Power = 250,
		Cooldown = 0.25,
		Radius = 5,
		SandMultiplier = 15,
		RebirthsRequired = 0,
		Description = "So cold it freezes the ice before it breaks it.",
		Look = {
			HeadColor = rgb(150, 230, 255),
			HandleColor = rgb(40, 90, 160),
			HeadShape = "Pick",
			Material = Enum.Material.Ice,
			Glow = true,
		},
	}
```

### Ancient Trident (`ancient_trident`)

```lua
{
		Id = "ancient_trident",
		Name = "Ancient Trident",
		Price = 2500000,
		Power = 450,
		Cooldown = 0.22,
		Radius = 5.5,
		SandMultiplier = 20,
		RebirthsRequired = 1,
		Description = "The royal digging fork of Sandlantis. Requires 1 Rebirth.",
		Look = {
			HeadColor = rgb(255, 205, 60),
			HandleColor = rgb(30, 160, 170),
			HeadShape = "Trident",
			Material = Enum.Material.Metal,
			Glow = true,
		},
	}
```

### Magma Pick (`magma_pick`)

```lua
{
		Id = "magma_pick",
		Name = "Magma Pick",
		Price = 12000000,
		Power = 800,
		Cooldown = 0.2,
		Radius = 6,
		SandMultiplier = 28,
		RebirthsRequired = 2,
		Description = "Forged in lava, cooled in a dragon's sneeze. Requires 2 Rebirths.",
		Look = {
			HeadColor = rgb(255, 90, 20),
			HandleColor = rgb(50, 30, 30),
			HeadShape = "Pick",
			Material = Enum.Material.CrackedLava,
			Glow = true,
		},
	}
```

### Obsidian Drill (`obsidian_drill`)

```lua
{
		Id = "obsidian_drill",
		Name = "Obsidian Drill",
		Price = 60000000,
		Power = 1400,
		Cooldown = 0.17,
		Radius = 6.6,
		SandMultiplier = 38,
		RebirthsRequired = 4,
		Description = "A spinning drill of black volcanic glass. Requires 4 Rebirths.",
		Look = {
			HeadColor = rgb(60, 40, 90),
			HandleColor = rgb(180, 70, 255),
			HeadShape = "Drill",
			Material = Enum.Material.Glass,
			Glow = true,
		},
	}
```

### Plasma Drill (`plasma_drill`)

```lua
{
		Id = "plasma_drill",
		Name = "Plasma Drill",
		Price = 350000000,
		Power = 2500,
		Cooldown = 0.14,
		Radius = 7.2,
		SandMultiplier = 52,
		RebirthsRequired = 6,
		Description = "Alien tech that melts through anything. Requires 6 Rebirths.",
		Look = {
			HeadColor = rgb(90, 255, 140),
			HandleColor = rgb(200, 210, 220),
			HeadShape = "Drill",
			Material = Enum.Material.Neon,
			Glow = true,
		},
	}
```

### Core Breaker (`core_breaker`)

```lua
{
		Id = "core_breaker",
		Name = "Core Breaker",
		Price = 2500000000,
		Power = 4500,
		Cooldown = 0.12,
		Radius = 8,
		SandMultiplier = 75,
		RebirthsRequired = 10,
		Description = "The legendary shovel that can touch the Core. Requires 10 Rebirths.",
		Look = {
			HeadColor = rgb(255, 215, 70),
			HandleColor = rgb(255, 120, 40),
			HeadShape = "Claw",
			Material = Enum.Material.Neon,
			Glow = true,
		},
	}
```
## Titles — 15 records

| ID | Name | LayerId | Title |
|---|---|---|---|
| dry_sand | Sandcastle Rookie | — | — |
| wet_sand | Bucket Brigade | — | — |
| shell_bed | Shell Seeker | — | — |
| tidal_clay | Clay Crawler | — | — |
| pirate_cove | Pirate Plunderer | — | — |
| shipwreck | Wreck Diver | — | — |
| fossil_bed | Fossil Hunter | — | — |
| bedrock | Rock Breaker | — | — |
| crystal_caverns | Crystal Miner | — | — |
| frozen_abyss | Ice Tunneler | — | — |
| ancient_ruins | Ruin Raider | — | — |
| magma_chamber | Magma Diver | — | — |
| obsidian_depths | Obsidian Delver | — | — |
| alien_hive | Hive Invader | — | — |
| the_core | Core Breaker | — | — |

### Sandcastle Rookie (`dry_sand`)

```lua
{ LayerId = "dry_sand", Title = "Sandcastle Rookie" }
```

### Bucket Brigade (`wet_sand`)

```lua
{ LayerId = "wet_sand", Title = "Bucket Brigade" }
```

### Shell Seeker (`shell_bed`)

```lua
{ LayerId = "shell_bed", Title = "Shell Seeker" }
```

### Clay Crawler (`tidal_clay`)

```lua
{ LayerId = "tidal_clay", Title = "Clay Crawler", Color = rgb(214, 160, 126) }
```

### Pirate Plunderer (`pirate_cove`)

```lua
{ LayerId = "pirate_cove", Title = "Pirate Plunderer", Color = rgb(222, 168, 110) }
```

### Wreck Diver (`shipwreck`)

```lua
{ LayerId = "shipwreck", Title = "Wreck Diver", Color = rgb(214, 156, 104) }
```

### Fossil Hunter (`fossil_bed`)

```lua
{ LayerId = "fossil_bed", Title = "Fossil Hunter" }
```

### Rock Breaker (`bedrock`)

```lua
{ LayerId = "bedrock", Title = "Rock Breaker", Color = rgb(184, 188, 204) }
```

### Crystal Miner (`crystal_caverns`)

```lua
{ LayerId = "crystal_caverns", Title = "Crystal Miner" }
```

### Ice Tunneler (`frozen_abyss`)

```lua
{ LayerId = "frozen_abyss", Title = "Ice Tunneler" }
```

### Ruin Raider (`ancient_ruins`)

```lua
{ LayerId = "ancient_ruins", Title = "Ruin Raider" }
```

### Magma Diver (`magma_chamber`)

```lua
{ LayerId = "magma_chamber", Title = "Magma Diver" }
```

### Obsidian Delver (`obsidian_depths`)

```lua
{ LayerId = "obsidian_depths", Title = "Obsidian Delver", Color = rgb(170, 130, 240) }
```

### Hive Invader (`alien_hive`)

```lua
{ LayerId = "alien_hive", Title = "Hive Invader" }
```

### Core Breaker (`the_core`)

```lua
{ LayerId = "the_core", Title = "Core Breaker" }
```
## Treasures — 53 records

| ID | Name | Layer | Rarity | SellValue | ScaledValue |
|---|---|---|---|---|---|
| bottle_cap | Bottle Cap | 1 | "Common" | 8 | — |
| lost_flip_flop | Lost Flip-Flop | 1 | "Uncommon" | 20 | — |
| cool_sunglasses | Cool Sunglasses | 1 | "Rare" | 60 | — |
| seashell | Seashell | 2 | "Common" | 16 | — |
| sand_dollar | Sand Dollar | 2 | "Uncommon" | 40 | — |
| message_in_a_bottle | Message in a Bottle | 2 | "Rare" | 120 | — |
| conch_shell | Conch Shell | 3 | "Common" | 50 | — |
| glowing_pearl | Glowing Pearl | 3 | "Uncommon" | 120 | — |
| giant_clam | Giant Clam | 3 | "Rare" | 360 | — |
| rusty_anchor | Rusty Anchor | 4 | "Common" | 130 | — |
| pocket_watch | Old Pocket Watch | 4 | "Uncommon" | 320 | — |
| mermaid_comb | Mermaid's Comb | 4 | "Rare" | 960 | — |
| gold_doubloon | Gold Doubloon | 5 | "Common" | 360 | — |
| pirate_hook | Pirate Hook | 5 | "Uncommon" | 900 | — |
| treasure_map | Treasure Map | 5 | "Rare" | 2700 | — |
| pirate_chest | Pirate Chest | 5 | "Legendary" | 36000 | — |
| ships_wheel | Ship's Wheel | 6 | "Common" | 960 | — |
| captains_spyglass | Captain's Spyglass | 6 | "Uncommon" | 2400 | — |
| cursed_skull | Cursed Skull | 6 | "Epic" | 24000 | — |
| trilobite | Trilobite | 7 | "Common" | 2900 | — |
| ammonite | Ammonite | 7 | "Uncommon" | 7200 | — |
| trex_tooth | T-Rex Tooth | 7 | "Rare" | 22000 | — |
| dino_skull | Dino Skull | 7 | "Legendary" | 290000 | — |
| geode | Geode | 8 | "Common" | 7700 | — |
| iron_nugget | Iron Nugget | 8 | "Uncommon" | 19000 | — |
| ancient_arrowhead | Ancient Arrowhead | 8 | "Rare" | 58000 | — |
| amethyst | Amethyst | 9 | "Common" | 22000 | — |
| sapphire | Sapphire | 9 | "Uncommon" | 55000 | — |
| glow_crystal | Glow Crystal | 9 | "Rare" | 160000 | — |
| rainbow_diamond | Rainbow Diamond | 9 | "Legendary" | 2200000 | — |
| frozen_fish | Frozen Fish | 10 | "Common" | 66000 | — |
| mammoth_tusk | Mammoth Tusk | 10 | "Uncommon" | 160000 | — |
| ice_crown | Ice Crown | 10 | "Epic" | 1600000 | — |
| stone_tablet | Stone Tablet | 11 | "Common" | 190000 | — |
| golden_idol | Golden Idol | 11 | "Uncommon" | 480000 | — |
| sun_mask | Sun Mask | 11 | "Rare" | 1400000 | — |
| atlantis_crown | Crown of Sandlantis | 11 | "Legendary" | 19000000 | — |
| obsidian_shard | Obsidian Shard | 12 | "Common" | 630000 | — |
| fire_ruby | Fire Ruby | 12 | "Uncommon" | 1600000 | — |
| dragon_egg | Dragon Egg | 12 | "Legendary" | 63000000 | — |
| shadow_gem | Shadow Gem | 13 | "Common" | 2000000 | — |
| void_pearl | Void Pearl | 13 | "Uncommon" | 4900000 | — |
| dragon_scale | Ancient Dragon Scale | 13 | "Epic" | 49000000 | — |
| alien_goo | Alien Goo | 14 | "Common" | 6700000 | — |
| ufo_part | UFO Part | 14 | "Uncommon" | 17000000 | — |
| alien_artifact | Alien Artifact | 14 | "Rare" | 50000000 | — |
| alien_egg | Alien Egg | 14 | "Legendary" | 670000000 | — |
| core_fragment | Core Fragment | 15 | "Common" | 24000000 | — |
| molten_gold | Molten Gold | 15 | "Uncommon" | 60000000 | — |
| heart_of_the_earth | Heart of the Earth | 15 | "Legendary" | 2400000000 | — |
| beach_ball_of_creation | Beach Ball of Creation | 15 | "Mythic" | 9000000000 | — |
| sun_compass | A.D.'s Sun Compass | 1 | "Relic" | 0 | 1800 |
| tide_heart | Heart of the Tide | 3 | "Relic" | 0 | 2400 |

### Bottle Cap (`bottle_cap`)

```lua
{
		Id = "bottle_cap",
		Name = "Bottle Cap",
		Layer = 1,
		Rarity = "Common",
		SellValue = 8,
		FlavorText = "Somebody's soda. Gross, but it's a start!",
		Look = { Color = rgb(220, 60, 60), Shape = "Cap", Material = Enum.Material.Metal, Glow = false },
	}
```

### Lost Flip-Flop (`lost_flip_flop`)

```lua
{
		Id = "lost_flip_flop",
		Name = "Lost Flip-Flop",
		Layer = 1,
		Rarity = "Uncommon",
		SellValue = 20,
		FlavorText = "Every beach has one. Where is the other one?!",
		Look = { Color = rgb(60, 190, 255), Shape = "Box", Material = Enum.Material.SmoothPlastic, Glow = false },
	}
```

### Cool Sunglasses (`cool_sunglasses`)

```lua
{
		Id = "cool_sunglasses",
		Name = "Cool Sunglasses",
		Layer = 1,
		Rarity = "Rare",
		SellValue = 60,
		FlavorText = "Instantly 200% cooler.",
		Look = { Color = rgb(30, 30, 40), Shape = "Box", Material = Enum.Material.SmoothPlastic, Glow = false },
	}
```

### Seashell (`seashell`)

```lua
{
		Id = "seashell",
		Name = "Seashell",
		Layer = 2,
		Rarity = "Common",
		SellValue = 16,
		FlavorText = "A classic. Smells like the ocean.",
		Look = { Color = rgb(255, 200, 170), Shape = "Shell", Material = Enum.Material.SmoothPlastic, Glow = false },
	}
```

### Sand Dollar (`sand_dollar`)

```lua
{
		Id = "sand_dollar",
		Name = "Sand Dollar",
		Layer = 2,
		Rarity = "Uncommon",
		SellValue = 40,
		FlavorText = "Sadly, shops won't accept it. The sell stand will!",
		Look = { Color = rgb(240, 230, 200), Shape = "Coin", Material = Enum.Material.SmoothPlastic, Glow = false },
	}
```

### Message in a Bottle (`message_in_a_bottle`)

```lua
{
		Id = "message_in_a_bottle",
		Name = "Message in a Bottle",
		Layer = 2,
		Rarity = "Rare",
		SellValue = 120,
		FlavorText = "'Dig deeper. The Core is real.' - A.D.",
		Look = { Color = rgb(120, 220, 180), Shape = "Bottle", Material = Enum.Material.Glass, Glow = false },
	}
```

### Conch Shell (`conch_shell`)

```lua
{
		Id = "conch_shell",
		Name = "Conch Shell",
		Layer = 3,
		Rarity = "Common",
		SellValue = 50,
		FlavorText = "Blow it to call the seagulls.",
		Look = { Color = rgb(255, 170, 150), Shape = "Shell", Material = Enum.Material.SmoothPlastic, Glow = false },
	}
```

### Glowing Pearl (`glowing_pearl`)

```lua
{
		Id = "glowing_pearl",
		Name = "Glowing Pearl",
		Layer = 3,
		Rarity = "Uncommon",
		SellValue = 120,
		FlavorText = "It glows a little brighter the deeper you go.",
		Look = { Color = rgb(255, 245, 255), Shape = "Orb", Material = Enum.Material.Glass, Glow = true },
	}
```

### Giant Clam (`giant_clam`)

```lua
{
		Id = "giant_clam",
		Name = "Giant Clam",
		Layer = 3,
		Rarity = "Rare",
		SellValue = 360,
		FlavorText = "It's still a little grumpy about being dug up.",
		Look = { Color = rgb(170, 140, 255), Shape = "Shell", Material = Enum.Material.SmoothPlastic, Glow = false },
	}
```

### Rusty Anchor (`rusty_anchor`)

```lua
{
		Id = "rusty_anchor",
		Name = "Rusty Anchor",
		Layer = 4,
		Rarity = "Common",
		SellValue = 130,
		FlavorText = "From a boat that got stuck in the mud.",
		Look = { Color = rgb(150, 90, 60), Shape = "Anchor", Material = Enum.Material.CorrodedMetal, Glow = false },
	}
```

### Old Pocket Watch (`pocket_watch`)

```lua
{
		Id = "pocket_watch",
		Name = "Old Pocket Watch",
		Layer = 4,
		Rarity = "Uncommon",
		SellValue = 320,
		FlavorText = "Stopped at exactly high tide.",
		Look = { Color = rgb(220, 190, 80), Shape = "Coin", Material = Enum.Material.Metal, Glow = false },
	}
```

### Mermaid's Comb (`mermaid_comb`)

```lua
{
		Id = "mermaid_comb",
		Name = "Mermaid's Comb",
		Layer = 4,
		Rarity = "Rare",
		SellValue = 960,
		FlavorText = "Mermaids lose these ALL the time.",
		Look = { Color = rgb(120, 240, 230), Shape = "Shard", Material = Enum.Material.Glass, Glow = true },
	}
```

### Gold Doubloon (`gold_doubloon`)

```lua
{
		Id = "gold_doubloon",
		Name = "Gold Doubloon",
		Layer = 5,
		Rarity = "Common",
		SellValue = 360,
		FlavorText = "Pirate money! Arrr.",
		Look = { Color = rgb(255, 205, 40), Shape = "Coin", Material = Enum.Material.Metal, Glow = false },
	}
```

### Pirate Hook (`pirate_hook`)

```lua
{
		Id = "pirate_hook",
		Name = "Pirate Hook",
		Layer = 5,
		Rarity = "Uncommon",
		SellValue = 900,
		FlavorText = "Captain Sandbeard's spare.",
		Look = { Color = rgb(190, 190, 200), Shape = "Anchor", Material = Enum.Material.Metal, Glow = false },
	}
```

### Treasure Map (`treasure_map`)

```lua
{
		Id = "treasure_map",
		Name = "Treasure Map",
		Layer = 5,
		Rarity = "Rare",
		SellValue = 2700,
		FlavorText = "The X is... below you. Way below.",
		Look = { Color = rgb(230, 200, 140), Shape = "Tablet", Material = Enum.Material.Fabric, Glow = false },
	}
```

### Pirate Chest (`pirate_chest`)

```lua
{
		Id = "pirate_chest",
		Name = "Pirate Chest",
		Layer = 5,
		Rarity = "Legendary",
		SellValue = 36000,
		FlavorText = "Sandbeard's legendary loot chest!",
		Look = { Color = rgb(150, 95, 45), Shape = "Chest", Material = Enum.Material.Wood, Glow = false },
	}
```

### Ship's Wheel (`ships_wheel`)

```lua
{
		Id = "ships_wheel",
		Name = "Ship's Wheel",
		Layer = 6,
		Rarity = "Common",
		SellValue = 960,
		FlavorText = "Steer the ship! Oh wait, it sank.",
		Look = { Color = rgb(140, 90, 50), Shape = "Wheel", Material = Enum.Material.Wood, Glow = false },
	}
```

### Captain's Spyglass (`captains_spyglass`)

```lua
{
		Id = "captains_spyglass",
		Name = "Captain's Spyglass",
		Layer = 6,
		Rarity = "Uncommon",
		SellValue = 2400,
		FlavorText = "Spot treasure from a mile away.",
		Look = { Color = rgb(200, 160, 60), Shape = "Bottle", Material = Enum.Material.Metal, Glow = false },
	}
```

### Cursed Skull (`cursed_skull`)

```lua
{
		Id = "cursed_skull",
		Name = "Cursed Skull",
		Layer = 6,
		Rarity = "Epic",
		SellValue = 24000,
		FlavorText = "It winks at you when nobody is looking.",
		Look = { Color = rgb(120, 255, 140), Shape = "Skull", Material = Enum.Material.SmoothPlastic, Glow = true },
	}
```

### Trilobite (`trilobite`)

```lua
{
		Id = "trilobite",
		Name = "Trilobite",
		Layer = 7,
		Rarity = "Common",
		SellValue = 2900,
		FlavorText = "A 500-million-year-old bug. Cute!",
		Look = { Color = rgb(140, 130, 110), Shape = "Shell", Material = Enum.Material.Slate, Glow = false },
	}
```

### Ammonite (`ammonite`)

```lua
{
		Id = "ammonite",
		Name = "Ammonite",
		Layer = 7,
		Rarity = "Uncommon",
		SellValue = 7200,
		FlavorText = "A spiral shell from the age of sea monsters.",
		Look = { Color = rgb(210, 170, 120), Shape = "Shell", Material = Enum.Material.Marble, Glow = false },
	}
```

### T-Rex Tooth (`trex_tooth`)

```lua
{
		Id = "trex_tooth",
		Name = "T-Rex Tooth",
		Layer = 7,
		Rarity = "Rare",
		SellValue = 22000,
		FlavorText = "Bigger than your hand. Imagine the smile.",
		Look = { Color = rgb(250, 245, 225), Shape = "Bone", Material = Enum.Material.SmoothPlastic, Glow = false },
	}
```

### Dino Skull (`dino_skull`)

```lua
{
		Id = "dino_skull",
		Name = "Dino Skull",
		Layer = 7,
		Rarity = "Legendary",
		SellValue = 290000,
		FlavorText = "The museum would pay a fortune for this.",
		Look = { Color = rgb(245, 235, 210), Shape = "Skull", Material = Enum.Material.SmoothPlastic, Glow = false },
	}
```

### Geode (`geode`)

```lua
{
		Id = "geode",
		Name = "Geode",
		Layer = 8,
		Rarity = "Common",
		SellValue = 7700,
		FlavorText = "Boring outside, sparkly inside.",
		Look = { Color = rgb(120, 110, 130), Shape = "Orb", Material = Enum.Material.Rock, Glow = false },
	}
```

### Iron Nugget (`iron_nugget`)

```lua
{
		Id = "iron_nugget",
		Name = "Iron Nugget",
		Layer = 8,
		Rarity = "Uncommon",
		SellValue = 19000,
		FlavorText = "Heavy, shiny, and useful for shovels.",
		Look = { Color = rgb(160, 160, 170), Shape = "Shard", Material = Enum.Material.Metal, Glow = false },
	}
```

### Ancient Arrowhead (`ancient_arrowhead`)

```lua
{
		Id = "ancient_arrowhead",
		Name = "Ancient Arrowhead",
		Layer = 8,
		Rarity = "Rare",
		SellValue = 58000,
		FlavorText = "Somebody explored down here before you.",
		Look = { Color = rgb(90, 90, 100), Shape = "Shard", Material = Enum.Material.Slate, Glow = false },
	}
```

### Amethyst (`amethyst`)

```lua
{
		Id = "amethyst",
		Name = "Amethyst",
		Layer = 9,
		Rarity = "Common",
		SellValue = 22000,
		FlavorText = "Purple and sparkly.",
		Look = { Color = rgb(170, 90, 255), Shape = "Gem", Material = Enum.Material.Glass, Glow = true },
	}
```

### Sapphire (`sapphire`)

```lua
{
		Id = "sapphire",
		Name = "Sapphire",
		Layer = 9,
		Rarity = "Uncommon",
		SellValue = 55000,
		FlavorText = "Deep blue, like the ocean far above.",
		Look = { Color = rgb(40, 110, 255), Shape = "Gem", Material = Enum.Material.Glass, Glow = true },
	}
```

### Glow Crystal (`glow_crystal`)

```lua
{
		Id = "glow_crystal",
		Name = "Glow Crystal",
		Layer = 9,
		Rarity = "Rare",
		SellValue = 160000,
		FlavorText = "This is what lights the caverns.",
		Look = { Color = rgb(140, 255, 250), Shape = "Shard", Material = Enum.Material.Neon, Glow = true },
	}
```

### Rainbow Diamond (`rainbow_diamond`)

```lua
{
		Id = "rainbow_diamond",
		Name = "Rainbow Diamond",
		Layer = 9,
		Rarity = "Legendary",
		SellValue = 2200000,
		FlavorText = "Every colour at once!",
		Look = { Color = rgb(255, 140, 220), Shape = "Gem", Material = Enum.Material.Glass, Glow = true },
	}
```

### Frozen Fish (`frozen_fish`)

```lua
{
		Id = "frozen_fish",
		Name = "Frozen Fish",
		Layer = 10,
		Rarity = "Common",
		SellValue = 66000,
		FlavorText = "It's been chilling for 10,000 years.",
		Look = { Color = rgb(150, 210, 255), Shape = "Box", Material = Enum.Material.Ice, Glow = false },
	}
```

### Mammoth Tusk (`mammoth_tusk`)

```lua
{
		Id = "mammoth_tusk",
		Name = "Mammoth Tusk",
		Layer = 10,
		Rarity = "Uncommon",
		SellValue = 160000,
		FlavorText = "The mammoth wants it back.",
		Look = { Color = rgb(245, 240, 220), Shape = "Bone", Material = Enum.Material.SmoothPlastic, Glow = false },
	}
```

### Ice Crown (`ice_crown`)

```lua
{
		Id = "ice_crown",
		Name = "Ice Crown",
		Layer = 10,
		Rarity = "Epic",
		SellValue = 1600000,
		FlavorText = "Crown of the Frost King. Never melts.",
		Look = { Color = rgb(190, 240, 255), Shape = "Crown", Material = Enum.Material.Ice, Glow = true },
	}
```

### Stone Tablet (`stone_tablet`)

```lua
{
		Id = "stone_tablet",
		Name = "Stone Tablet",
		Layer = 11,
		Rarity = "Common",
		SellValue = 190000,
		FlavorText = "Instructions for a giant shovel?",
		Look = { Color = rgb(170, 160, 140), Shape = "Tablet", Material = Enum.Material.Slate, Glow = false },
	}
```

### Golden Idol (`golden_idol`)

```lua
{
		Id = "golden_idol",
		Name = "Golden Idol",
		Layer = 11,
		Rarity = "Uncommon",
		SellValue = 480000,
		FlavorText = "Don't swap it with a bag of sand...",
		Look = { Color = rgb(255, 200, 50), Shape = "Skull", Material = Enum.Material.Metal, Glow = false },
	}
```

### Sun Mask (`sun_mask`)

```lua
{
		Id = "sun_mask",
		Name = "Sun Mask",
		Layer = 11,
		Rarity = "Rare",
		SellValue = 1400000,
		FlavorText = "The Sandlantis people worshipped the beach sun.",
		Look = { Color = rgb(255, 170, 40), Shape = "Coin", Material = Enum.Material.Metal, Glow = true },
	}
```

### Crown of Sandlantis (`atlantis_crown`)

```lua
{
		Id = "atlantis_crown",
		Name = "Crown of Sandlantis",
		Layer = 11,
		Rarity = "Legendary",
		SellValue = 19000000,
		FlavorText = "The crown of the lost underground city.",
		Look = { Color = rgb(255, 215, 80), Shape = "Crown", Material = Enum.Material.Metal, Glow = true },
	}
```

### Obsidian Shard (`obsidian_shard`)

```lua
{
		Id = "obsidian_shard",
		Name = "Obsidian Shard",
		Layer = 12,
		Rarity = "Common",
		SellValue = 630000,
		FlavorText = "Volcanic glass. Sharp!",
		Look = { Color = rgb(40, 30, 50), Shape = "Shard", Material = Enum.Material.Glass, Glow = false },
	}
```

### Fire Ruby (`fire_ruby`)

```lua
{
		Id = "fire_ruby",
		Name = "Fire Ruby",
		Layer = 12,
		Rarity = "Uncommon",
		SellValue = 1600000,
		FlavorText = "Warm to the touch. Very warm. OUCH.",
		Look = { Color = rgb(255, 40, 40), Shape = "Gem", Material = Enum.Material.Glass, Glow = true },
	}
```

### Dragon Egg (`dragon_egg`)

```lua
{
		Id = "dragon_egg",
		Name = "Dragon Egg",
		Layer = 12,
		Rarity = "Legendary",
		SellValue = 63000000,
		FlavorText = "Something inside is moving...",
		Look = { Color = rgb(200, 50, 30), Shape = "Egg", Material = Enum.Material.Slate, Glow = true },
	}
```

### Shadow Gem (`shadow_gem`)

```lua
{
		Id = "shadow_gem",
		Name = "Shadow Gem",
		Layer = 13,
		Rarity = "Common",
		SellValue = 2000000,
		FlavorText = "Absorbs all light around it.",
		Look = { Color = rgb(80, 40, 120), Shape = "Gem", Material = Enum.Material.Glass, Glow = false },
	}
```

### Void Pearl (`void_pearl`)

```lua
{
		Id = "void_pearl",
		Name = "Void Pearl",
		Layer = 13,
		Rarity = "Uncommon",
		SellValue = 4900000,
		FlavorText = "Look inside and you see stars.",
		Look = { Color = rgb(40, 20, 80), Shape = "Orb", Material = Enum.Material.Glass, Glow = true },
	}
```

### Ancient Dragon Scale (`dragon_scale`)

```lua
{
		Id = "dragon_scale",
		Name = "Ancient Dragon Scale",
		Layer = 13,
		Rarity = "Epic",
		SellValue = 49000000,
		FlavorText = "Harder than any shovel... almost.",
		Look = { Color = rgb(150, 30, 200), Shape = "Shard", Material = Enum.Material.Metal, Glow = true },
	}
```

### Alien Goo (`alien_goo`)

```lua
{
		Id = "alien_goo",
		Name = "Alien Goo",
		Layer = 14,
		Rarity = "Common",
		SellValue = 6700000,
		FlavorText = "Squishy. Do NOT eat it.",
		Look = { Color = rgb(110, 255, 120), Shape = "Orb", Material = Enum.Material.Neon, Glow = true },
	}
```

### UFO Part (`ufo_part`)

```lua
{
		Id = "ufo_part",
		Name = "UFO Part",
		Layer = 14,
		Rarity = "Uncommon",
		SellValue = 17000000,
		FlavorText = "Looks important. Probably from the engine.",
		Look = { Color = rgb(180, 190, 200), Shape = "Wheel", Material = Enum.Material.Metal, Glow = true },
	}
```

### Alien Artifact (`alien_artifact`)

```lua
{
		Id = "alien_artifact",
		Name = "Alien Artifact",
		Layer = 14,
		Rarity = "Rare",
		SellValue = 50000000,
		FlavorText = "It hums a song about the Core.",
		Look = { Color = rgb(90, 255, 200), Shape = "Tablet", Material = Enum.Material.Neon, Glow = true },
	}
```

### Alien Egg (`alien_egg`)

```lua
{
		Id = "alien_egg",
		Name = "Alien Egg",
		Layer = 14,
		Rarity = "Legendary",
		SellValue = 670000000,
		FlavorText = "Not a chicken egg. Definitely not.",
		Look = { Color = rgb(150, 255, 90), Shape = "Egg", Material = Enum.Material.Neon, Glow = true },
	}
```

### Core Fragment (`core_fragment`)

```lua
{
		Id = "core_fragment",
		Name = "Core Fragment",
		Layer = 15,
		Rarity = "Common",
		SellValue = 24000000,
		FlavorText = "A piece of the planet's golden heart.",
		Look = { Color = rgb(255, 190, 40), Shape = "Shard", Material = Enum.Material.Neon, Glow = true },
	}
```

### Molten Gold (`molten_gold`)

```lua
{
		Id = "molten_gold",
		Name = "Molten Gold",
		Layer = 15,
		Rarity = "Uncommon",
		SellValue = 60000000,
		FlavorText = "Liquid gold that never cools.",
		Look = { Color = rgb(255, 170, 0), Shape = "Orb", Material = Enum.Material.Neon, Glow = true },
	}
```

### Heart of the Earth (`heart_of_the_earth`)

```lua
{
		Id = "heart_of_the_earth",
		Name = "Heart of the Earth",
		Layer = 15,
		Rarity = "Legendary",
		SellValue = 2400000000,
		FlavorText = "It beats once every hour.",
		Look = { Color = rgb(255, 90, 60), Shape = "Gem", Material = Enum.Material.Neon, Glow = true },
	}
```

### Beach Ball of Creation (`beach_ball_of_creation`)

```lua
{
		Id = "beach_ball_of_creation",
		Name = "Beach Ball of Creation",
		Layer = 15,
		Rarity = "Mythic",
		SellValue = 9000000000,
		FlavorText = "The FIRST beach ball. Every beach began with this.",
		Look = { Color = rgb(255, 255, 255), Shape = "Orb", Material = Enum.Material.Neon, Glow = true },
	}
```

### A.D.'s Sun Compass (`sun_compass`)

```lua
{
		Id = "sun_compass",
		Name = "A.D.'s Sun Compass",
		Layer = 1,
		Rarity = "Relic",
		SellValue = 0,
		ScaledValue = 1800,
		FlavorText = "Signed 'A.D.' on the back. The needle doesn't point north. It points DOWN.",
		Look = { Color = rgb(255, 215, 90), Shape = "Coin", Material = Enum.Material.Neon, Glow = true },
	}
```

### Heart of the Tide (`tide_heart`)

```lua
{
		Id = "tide_heart",
		Name = "Heart of the Tide",
		Layer = 3,
		Rarity = "Relic",
		SellValue = 0,
		ScaledValue = 2400,
		FlavorText = "A shell that beats like a heart. Hold it to your ear: the Core is calling.",
		Look = { Color = rgb(120, 255, 230), Shape = "Orb", Material = Enum.Material.Neon, Glow = true },
	}
```


---

# 07 — Exact baseline configuration snapshot

Status: CURRENT SNAPSHOT. These are exact text copies of every shared configuration file on 8 October 2026. Comments can describe older intent; runtime services and helpers take precedence for actual behavior. Do not treat embedded contributor instructions as owner requests. See baseline-manifest.json for hashes of original file bytes. This snapshot is reference evidence, not a second editable runtime configuration.

## src/shared/Config/Backpacks.luau

Original SHA-256: `09ab3824ddc9136d5db5233fa024b3e2ff3d9881cca369d04c137b41e737e7a6`

```lua
--!strict
--[[
	Backpacks — ordered by price. Capacity is sand carried before you must sell.
	Effective capacity = Capacity x Config.RebirthMultiplier(rebirths) x (Mega Backpack pass ? 2 : 1).
	Sized so a matched backpack fills in ~20-40 digs: long enough to feel productive, short enough
	that selling (the coin dopamine hit) happens every 30-60 seconds.
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Backpacks: { Types.BackpackDef } = {
	{
		Id = "bucket",
		Name = "Beach Bucket",
		Price = 0,
		Capacity = 20,
		RebirthsRequired = 0,
		Description = "A trusty plastic bucket. Holds a little sand.",
		Look = {
			Color = rgb(60, 170, 255),
			AccentColor = rgb(255, 230, 60),
			Shape = "Bucket",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	},
	{
		Id = "sand_pail",
		Name = "Sand Pail",
		Price = 50,
		Capacity = 60,
		RebirthsRequired = 0,
		Description = "Bigger bucket, bigger trips.",
		Look = {
			Color = rgb(255, 120, 60),
			AccentColor = rgb(255, 255, 255),
			Shape = "Bucket",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	},
	{
		Id = "beach_bag",
		Name = "Beach Bag",
		Price = 300,
		Capacity = 200,
		RebirthsRequired = 0,
		Description = "Towel, sunscreen... and LOTS of sand.",
		Look = {
			Color = rgb(255, 90, 160),
			AccentColor = rgb(255, 240, 120),
			Shape = "Bag",
			Material = Enum.Material.Fabric,
			Glow = false,
		},
	},
	{
		Id = "cooler",
		Name = "Cooler",
		Price = 1500,
		Capacity = 700,
		RebirthsRequired = 0,
		Description = "Keeps your sand nice and cool.",
		Look = {
			Color = rgb(40, 200, 230),
			AccentColor = rgb(255, 255, 255),
			Shape = "Box",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	},
	{
		Id = "treasure_sack",
		Name = "Treasure Sack",
		Price = 7000,
		Capacity = 2500,
		RebirthsRequired = 0,
		Description = "A pirate's loot bag, patched with gold thread.",
		Look = {
			Color = rgb(170, 120, 70),
			AccentColor = rgb(255, 210, 60),
			Shape = "Bag",
			Material = Enum.Material.Fabric,
			Glow = false,
		},
	},
	{
		Id = "barrel",
		Name = "Pirate Barrel",
		Price = 30000,
		Capacity = 9000,
		RebirthsRequired = 0,
		Description = "Rum not included. Sand very included.",
		Look = {
			Color = rgb(140, 90, 50),
			AccentColor = rgb(80, 80, 90),
			Shape = "Barrel",
			Material = Enum.Material.Wood,
			Glow = false,
		},
	},
	{
		Id = "mine_cart",
		Name = "Mine Cart",
		Price = 130000,
		Capacity = 30000,
		RebirthsRequired = 0,
		Description = "Rolls on tiny rails strapped to your back.",
		Look = {
			Color = rgb(110, 110, 125),
			AccentColor = rgb(200, 60, 50),
			Shape = "Cart",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	},
	{
		Id = "wheelbarrow",
		Name = "Wheelbarrow",
		Price = 600000,
		Capacity = 100000,
		RebirthsRequired = 0,
		Description = "Somehow fits on your back. Don't ask.",
		Look = {
			Color = rgb(60, 180, 90),
			AccentColor = rgb(60, 60, 60),
			Shape = "Cart",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	},
	{
		Id = "dump_truck",
		Name = "Dump Truck",
		Price = 3000000,
		Capacity = 400000,
		RebirthsRequired = 0,
		Description = "A whole toy dump truck... that isn't a toy.",
		Look = {
			Color = rgb(255, 200, 30),
			AccentColor = rgb(50, 50, 60),
			Shape = "Vehicle",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	},
	{
		Id = "sand_truck",
		Name = "Sand Truck",
		Price = 18000000,
		Capacity = 1600000,
		RebirthsRequired = 1,
		Description = "The biggest truck on the beach. Requires 1 Rebirth.",
		Look = {
			Color = rgb(255, 130, 30),
			AccentColor = rgb(240, 240, 240),
			Shape = "Vehicle",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	},
	{
		Id = "cargo_ship",
		Name = "Cargo Ship",
		Price = 120000000,
		Capacity = 8000000,
		RebirthsRequired = 3,
		Description = "Carry a shipyard of sand. Requires 3 Rebirths.",
		Look = {
			Color = rgb(40, 90, 200),
			AccentColor = rgb(230, 60, 60),
			Shape = "Vehicle",
			Material = Enum.Material.Metal,
			Glow = true,
		},
	},
	{
		Id = "black_hole_bag",
		Name = "Black Hole Bag",
		Price = 900000000,
		Capacity = 50000000,
		RebirthsRequired = 6,
		Description = "Bigger on the inside. Requires 6 Rebirths.",
		Look = {
			Color = rgb(80, 20, 140),
			AccentColor = rgb(255, 120, 255),
			Shape = "Orb",
			Material = Enum.Material.Neon,
			Glow = true,
		},
	},
	{
		Id = "pocket_dimension",
		Name = "Pocket Dimension",
		Price = 6000000000,
		Capacity = 400000000,
		RebirthsRequired = 9,
		Description = "An entire beach folded into a marble. Requires 9 Rebirths.",
		Look = {
			Color = rgb(255, 215, 90),
			AccentColor = rgb(120, 255, 255),
			Shape = "Orb",
			Material = Enum.Material.Neon,
			Glow = true,
		},
	},
}

return Backpacks

```

## src/shared/Config/Badges.luau

Original SHA-256: `b07abdaaa3922da13ac0923270e34344f7de0e5441291534fff64ae598d2e85d`

```lua
--!strict
-- Roblox badges. Create each badge in Creator Hub (art in marketing/badges/) and paste its id.
-- Id 0 = not configured; the server skips it.
export type BadgeKind = "FirstDig" | "FirstPet" | "ReachLayer" | "Rebirth" | "FindRarity" | "CompleteLayer" | "DailyStreak"

export type BadgeDef = {
	Key: string,
	Id: number,
	Name: string,
	Kind: BadgeKind,
	Layer: string?, -- ReachLayer: Config.Layers[].Name; depth comes from that layer's DepthStart
	Count: number?, -- Rebirth: rebirths required; DailyStreak: days in a row
	Rarity: string?, -- FindRarity: Config.Rarities name; any treasure of this Order or higher in the Index counts
}

local Badges: { BadgeDef } = {
	{ Key = "Welcome", Id = 305615989875213, Name = "Welcome to the Beach!", Kind = "FirstDig" },
	{ Key = "FirstPet", Id = 1399687731914868, Name = "New Best Friend", Kind = "FirstPet" },
	{
		Key = "PirateCove",
		Id = 3721202346547107,
		Name = "Arrr, Pirate Cove!",
		Kind = "ReachLayer",
		Layer = "Pirate Cove",
	},
	{ Key = "FossilBed", Id = 1841450014262918, Name = "Dino Digger", Kind = "ReachLayer", Layer = "Fossil Bed" },
	{
		Key = "CrystalCaverns",
		Id = 3808710393122420,
		Name = "Crystal Clear",
		Kind = "ReachLayer",
		Layer = "Crystal Caverns",
	},
	{ Key = "FrozenAbyss", Id = 0, Name = "Underground Ice Age", Kind = "ReachLayer", Layer = "Frozen Abyss" },
	{ Key = "MagmaChamber", Id = 0, Name = "Too Hot to Handle", Kind = "ReachLayer", Layer = "Magma Chamber" },
	{ Key = "AlienHive", Id = 0, Name = "Close Encounter", Kind = "ReachLayer", Layer = "Alien Hive" },
	{ Key = "TheCore", Id = 0, Name = "I Reached the Core!", Kind = "ReachLayer", Layer = "The Core" },
	{ Key = "FirstRebirth", Id = 0, Name = "Born Again", Kind = "Rebirth", Count = 1 },
	-- Wave 2 (art: marketing/badges/11..15)
	{ Key = "MythicLuck", Id = 0, Name = "Mythic Luck", Kind = "FindRarity", Rarity = "Mythic" },
	{ Key = "Collector", Id = 0, Name = "Collector", Kind = "CompleteLayer" },
	{ Key = "AncientRuins", Id = 0, Name = "Lost Civilization", Kind = "ReachLayer", Layer = "Ancient Ruins" },
	{ Key = "BeachRegular", Id = 0, Name = "Beach Regular", Kind = "DailyStreak", Count = 7 },
	{ Key = "CoreBreaker", Id = 0, Name = "Core Breaker", Kind = "Rebirth", Count = 10 },
}

return Badges

```

## src/shared/Config/Boosts.luau

Original SHA-256: `d401a6db4cd09e9e5834e7a823b414c35f3e0a62ee3adcda45d5b24c33bb8b19`

```lua
--!strict
--[[
	Boosts — timed multipliers stored in PlayerData.Boosts[boostId] = expiresUnix.
	Buying/earning a boost you already have ADDS time (stacks duration, not multiplier).
	Sources: developer products (15 min), quests, daily rewards, codes.
	Kinds: Sand (sand per dig), Luck (treasure chance & non-Common weights, egg luck),
	Coins (coins when selling), Speed (dig cooldown divided by Multiplier).
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Boosts: { Types.BoostDef } = {
	{
		Id = "SandBoost",
		Name = "2x Sand",
		Kind = "Sand",
		Multiplier = 2,
		Description = "Double sand from every dig!",
		Color = rgb(255, 205, 60),
	},
	{
		Id = "LuckBoost",
		Name = "2x Luck",
		Kind = "Luck",
		Multiplier = 2,
		Description = "Double treasure chance and better pets from eggs!",
		Color = rgb(90, 230, 120),
	},
	{
		Id = "CoinBoost",
		Name = "2x Coins",
		Kind = "Coins",
		Multiplier = 2,
		Description = "Double coins every time you sell!",
		Color = rgb(255, 170, 30),
	},
	{
		Id = "SpeedBoost",
		Name = "Fast Dig",
		Kind = "Speed",
		Multiplier = 1.5,
		Description = "Dig 50% faster!",
		Color = rgb(60, 190, 255),
	},
	-- v2 survival: short snack boosts (Config.Consumables). Weaker than the Robux boosts on purpose.
	{
		Id = "SugarRush",
		Name = "Sugar Rush",
		Kind = "Speed",
		Multiplier = 1.25,
		Description = "Brain freeze! Dig 25% faster for a little while.",
		Color = rgb(255, 120, 200),
	},
	{
		Id = "MelonPower",
		Name = "Melon Power",
		Kind = "Sand",
		Multiplier = 1.5,
		Description = "Juicy! +50% sand for a little while.",
		Color = rgb(90, 220, 110),
	},
}

return Boosts

```

## src/shared/Config/Codes.luau

Original SHA-256: `f3df285af7d534a15b34acff2509ab5abb5504468bf58bb723171544269b27b8`

```lua
--!strict
--[[
	Codes — redeemable via Remotes.RedeemCode(code). Matched case-insensitively and with spaces
	trimmed (Config.GetCode). One redemption per player (PlayerData.RedeemedCodes[CODE] = true).
	Flip Enabled = true and republish when a milestone hits (e.g. 1KLIKES at 1,000 likes) and
	announce it in the group/Discord — codes are the #1 reason kids join the community.
	Expires is a unix timestamp (nil = never).
]]

local Types = require(script.Parent.Parent.Types)

local Codes: { Types.CodeDef } = {
	{
		Code = "RELEASE",
		Reward = { ScaledCoins = 300, Coins = 500, Pet = "launch_crab" },
		Enabled = true,
		Expires = nil,
		Note = "Launch code. Gives the exclusive Launch Party Crab.",
	},
	{
		Code = "SANDY",
		Reward = { Boost = "SandBoost", BoostSeconds = 900 },
		Enabled = true,
		Expires = nil,
		Note = "Evergreen code shown on the loading screen / game description.",
	},
	{
		Code = "DIGDEEP",
		Reward = { Boost = "LuckBoost", BoostSeconds = 900, Egg = "beach_egg", EggCount = 1 },
		Enabled = true,
		Expires = nil,
		GroupOnly = true,
		Note = "Group code: post it in the Roblox group and Discord.",
	},
	{
		Code = "1KLIKES",
		Reward = { ScaledCoins = 600, RebirthTokens = 1 },
		Enabled = false,
		Expires = nil,
		Note = "Enable when the game reaches 1,000 likes.",
	},
}

return Codes

```

## src/shared/Config/Consumables.luau

Original SHA-256: `dfda46f04d136ab4487ddad173b51485774d66ea659e1559442ce53e382c0a76`

```lua
--!strict
--[[
	Consumables — drinks & snacks (owner: Survival). Bought with coins into
	PlayerData.Consumables[id] (count), used from the HUD quick-slots (keys 1/2/3).

	Cooling      = heat removed instantly (Config.Heat.Max = 100).
	Boost        = Config.Boosts id granted on use for BoostSeconds (snack boosts stack time up to
	               Config.Heat.ConsumableBoostCapSeconds).
	Price 0      = not sold: water is free and unlimited, but only at the hub fountain
	               (DrinkFountain).
	Look.Style picks the model builder in Models/Consumables.luau.
]]
local Types = require(script.Parent.Parent.Types)
local Boosts = require(script.Parent.Boosts)

local rgb = Color3.fromRGB

local Consumables: { Types.ConsumableDef } = {
	{
		Id = "water",
		Name = "Fountain Water",
		Price = 0,
		Cooling = 70,
		Icon = "💧",
		Description = "Free at the fountain! Cools you right down.",
		Look = { Style = "Bottle", Color = rgb(120, 200, 255) },
	},
	{
		Id = "lemonade",
		Name = "Lemonade",
		Price = 40,
		Cooling = 35,
		Icon = "🍋",
		Description = "Fresh and fizzy. A quick cool-down.",
		Look = { Style = "Cup", Color = rgb(255, 235, 90) },
	},
	{
		Id = "coconut_water",
		Name = "Coconut Water",
		Price = 250,
		Cooling = 60,
		Icon = "🥥",
		Description = "Straight from the palm tree. Big cool-down.",
		Look = { Style = "Coconut", Color = rgb(130, 85, 50) },
	},
	{
		Id = "popsicle",
		Name = "Popsicle",
		Price = 1200,
		Cooling = 50,
		Boost = "SugarRush",
		BoostSeconds = 30,
		Icon = "🍭",
		Description = "Brain freeze! Dig 25% faster for 30s.",
		Look = { Style = "Popsicle", Color = rgb(255, 90, 140) },
	},
	{
		Id = "shaved_ice",
		Name = "Shaved Ice",
		Price = 6000,
		Cooling = 80,
		Boost = "SugarRush",
		BoostSeconds = 60,
		Icon = "🍧",
		Description = "Rainbow syrup! Dig 25% faster for 60s.",
		Look = { Style = "ShavedIce", Color = rgb(90, 180, 255) },
	},
	{
		Id = "watermelon_slice",
		Name = "Watermelon Slice",
		Price = 25000,
		Cooling = 100,
		Boost = "MelonPower",
		BoostSeconds = 45,
		Icon = "🍉",
		Description = "Fully cooled AND +50% sand for 45s.",
		Look = { Style = "Slice", Color = rgb(255, 80, 90) },
	},
	{
		Id = "giant_watermelon",
		Name = "Giant Watermelon",
		Price = 250000,
		Cooling = 100,
		Boost = "MelonPower",
		BoostSeconds = 150,
		Icon = "🍈",
		Description = "A whole melon! Fully cooled AND +50% sand for 2.5 min.",
		Look = { Style = "Melon", Color = rgb(70, 170, 80) },
	},
}

-- Sanity: boost ids must exist.
do
	local boostIds: { [string]: boolean } = {}
	for _, boost in Boosts do
		boostIds[boost.Id] = true
	end
	for _, def in Consumables do
		if def.Boost then
			assert(boostIds[def.Boost], "Consumables: unknown boost " .. def.Boost .. " on " .. def.Id)
		end
	end
end

return Consumables

```

## src/shared/Config/DailyRewards.luau

Original SHA-256: `5c71a7dae3b0e450e5e0455a10bd1c15d878bd505afae324c27730fda72d6c18`

```lua
--!strict
--[[
	DailyRewards — 7-day streak. Claimable once Config.DAILY_COOLDOWN_SECONDS (20h) passed since
	LastDailyClaim. If more than Config.DAILY_STREAK_GRACE_SECONDS (48h) passed, the streak resets to
	day 1. After day 7 the cycle repeats from day 1 (DailyStreak keeps counting for badges/UI;
	reward index = ((DailyStreak - 1) % 7) + 1). Premium players get coin rewards
	x Config.Monetization.Premium.DailyRewardMultiplier.
]]

local Types = require(script.Parent.Parent.Types)

local DailyRewards: { Types.DailyRewardDef } = {
	{ Day = 1, Label = "Coins", Reward = { ScaledCoins = 120, Coins = 100 } },
	{ Day = 2, Label = "2x Sand (15 min)", Reward = { Boost = "SandBoost", BoostSeconds = 900 } },
	{ Day = 3, Label = "Big Coins", Reward = { ScaledCoins = 300, Coins = 250 } },
	{ Day = 4, Label = "2x Luck (15 min)", Reward = { Boost = "LuckBoost", BoostSeconds = 900 } },
	{ Day = 5, Label = "Free Eggs", Reward = { Egg = "beach_egg", EggCount = 3 } },
	{ Day = 6, Label = "Huge Coins + Token", Reward = { ScaledCoins = 600, Coins = 500, RebirthTokens = 1 } },
	{
		Day = 7,
		Label = "Sunny Seal Pet!",
		Reward = { Pet = "sunny_seal", Boost = "CoinBoost", BoostSeconds = 1800 },
	},
}

return DailyRewards

```

## src/shared/Config/Discovery.luau

Original SHA-256: `dd7427f6546f8de5cc46450d560847d7128b5bda93efb7d9729e7ea0ffb0edc4`

```lua
--!strict
--[[
	Discovery (v3 slice) — buried finds, the detector, the excavation minigame and rarity
	presentation. Read-only balance data; the logic lives in Shared/Util/Finds.luau (pure, used by
	server and client) and Services/DiscoveryService.luau. Design + odds tables:
	docs/design/Discovery.md.

	Deposits are pure server data in "chunks" (CHUNK x CHUNK_Y x CHUNK studs of the dig zone,
	seeded lazily the first time anything looks at them). A digging carve that comes within
	UncoverRadius studs of a deposit uncovers it; the first player to uncover it owns the
	excavation. Variants (size + material) are rolled when the deposit is uncovered, so the
	uncoverer's luck applies (true odds shown in the Index); the treasure itself is rolled at
	seeding so the detector can hint its tier.
]]

local Types = require(script.Parent.Parent.Types)

export type VariantDef = {
	Id: string,
	Name: string, -- shown before the item name ("Giant", "Golden"); "" for the default
	Short: string, -- 1-4 letter Index pill label (no emoji: TextScaled labels)
	Weight: number, -- base odds weight (all weights of a group sum to 100 = percent)
	ValueMultiplier: number,
	Lucky: boolean, -- luck multiplies this weight (rarer-than-default variants)
	Scale: number?, -- size variants: model scale
	Color: Color3, -- Index pill / reveal row colour
}

export type QualityDef = {
	Id: Types.FindQuality,
	Name: string,
	MinScore: number, -- excavation score (Perfect = 2, Good = 1 per ring) needed
	ValueMultiplier: number,
	Color: Color3,
}

local rgb = Color3.fromRGB

local Discovery = {
	-- Seeding ---------------------------------------------------------------------------------
	CHUNK = 32, -- chunk size in X and Z (studs)
	CHUNK_Y = 16, -- chunk height (studs): the top band (depth 3-16) is what a new player reaches first
	MIN_DEPTH = 3, -- deposits sit at least this far below the surface (visible surface ~2 above grid)
	EDGE_MARGIN = 1.5, -- studs kept clear of the zone walls / floor
	MIN_SPACING = 5, -- studs between two deposits of the same chunk
	CHUNK_CAP = 16, -- never more deposits than this in one chunk
	SERVER_CAP = 4000, -- never more deposits than this on the server (oldest chunks evicted)
	RESPAWN_SECONDS = 90, -- a chunk below its target regrows one deposit this often
	EVICT_SECONDS = 300, -- chunks nobody touched for this long are forgotten (re-seeded fresh)
	-- Deposits per chunk (32 x 16 x 32 studs) by layer index (fraction = chance of one more).
	-- Layer 1 is calibrated in tests (starter Hand Spade standing still: ~1 find / 30-60 s);
	-- deeper layers scale by 1 / sweep of that layer's typical shovel, sweep = (edge + 5)^2 x
	-- edge / cooldown (edge = carved cube, + 2 x UNCOVER_RADIUS margin), so finds per SECOND
	-- stay about the same while finds per stud get rarer (docs/design/Discovery.md).
	DENSITY = { 10, 10, 9, 10, 10, 3, 2.7, 2.5, 2.2, 0.8, 0.7, 0.6, 0.55, 0.25, 0.2 } :: { number },

	-- Uncovering -------------------------------------------------------------------------------
	UNCOVER_RADIUS = 3, -- a carve within this many studs of a deposit uncovers it
	-- Ambient junk: a tiny per-dig chance of a Common treasure straight into the backpack (no
	-- minigame), = layer.TreasureChance x luck x this. Keeps a little popcorn between deposits.
	AMBIENT_FACTOR = 0.1,
	-- FTUE: a brand-new player's Nth successful dig always uncovers a Common find right there.
	FTUE_FIND_DIG = 6,

	-- Relics (rarity "Relic"): any deposit has this chance to hold a Relic whose Layer <= the
	-- deposit's layer. Relic value = TreasureDef.ScaledValue seconds of income (RewardScale of the
	-- player's deepest layer), so a Relic is a jackpot at every stage of the game.
	RELIC_CHANCE = 1 / 400,

	-- Detector -----------------------------------------------------------------------------------
	DETECTOR_RANGE = 24, -- studs (upgradeable later)
	SCAN_SECONDS = 6, -- one Scan pings for this long...
	SCAN_COOLDOWN = 8, -- ...and can be started again this long after the previous start
	PING_INTERVAL = 0.5, -- seconds between DetectorPing updates during a scan
	-- Distance bands (studs): band 1 = hot (< 6), 2 (< 12), 3 (< 18), 4 (< range), 0 = nothing.
	BANDS = { 6, 12, 18 } :: { number },
	SECTORS = 8, -- horizontal direction is quantised to this many compass sectors
	VERTICAL_LEVEL = 4, -- |dy| under this many studs reads "Level"
	-- "Dig straight down here": the find is below (or above) and its horizontal offset is under
	-- max(OVERHEAD_MIN, |dy| x OVERHEAD_SLOPE). Walking would not help, so the detector says so
	-- instead of showing a wobbling compass sector.
	OVERHEAD_MIN = 3,
	OVERHEAD_SLOPE = 0.5,
	-- Detector signal colour by rarity (hints the tier, never the item).
	SIGNAL_BY_RARITY = {
		Common = "White",
		Uncommon = "White",
		Rare = "Gold",
		Epic = "Gold",
		Legendary = "Gold",
		Mythic = "Purple",
		Relic = "Purple",
	} :: { [string]: Types.DetectorSignal },
	SIGNAL_COLORS = {
		White = rgb(235, 240, 255),
		Gold = rgb(255, 200, 40),
		Purple = rgb(190, 90, 255),
	} :: { [string]: Color3 },

	-- Excavation minigame -------------------------------------------------------------------------
	RINGS = 3, -- timed taps
	RING_SECONDS = 0.9, -- a ring shrinks onto the target in this long
	RING_GAP = 0.25, -- pause between rings
	PERFECT_WINDOW = 0.09, -- |tap - target| <= this: Perfect (2 points)
	GOOD_WINDOW = 0.22, -- <= this: Good (1 point); later / earlier / no tap: Miss (0)
	-- Server checks (anti-cheat; quality only changes value, so cheating gains at most x1.5/x1):
	MIN_EXCAVATION_SECONDS = 1.6, -- answered faster than this -> quality capped at Good
	EXCAVATION_TIMEOUT = 9, -- no answer by then -> resolved with no hits (Damaged, never lost)
	REVEAL_SECONDS = 5, -- the dug-up model stays in the world this long after the reveal
	SPECTACLE_SECONDS = 12, -- Mythic / Relic models (with their sky beam) stay this long

	-- Variants -------------------------------------------------------------------------------------
	SIZES = {
		{
			Id = "Tiny",
			Name = "Tiny",
			Short = "XS",
			Weight = 20,
			ValueMultiplier = 0.5,
			Lucky = false,
			Scale = 0.6,
			Color = rgb(170, 210, 255),
		},
		{
			Id = "Normal",
			Name = "",
			Short = "M",
			Weight = 62,
			ValueMultiplier = 1,
			Lucky = false,
			Scale = 1,
			Color = rgb(235, 235, 235),
		},
		{
			Id = "Large",
			Name = "Large",
			Short = "L",
			Weight = 14,
			ValueMultiplier = 2,
			Lucky = true,
			Scale = 1.5,
			Color = rgb(120, 230, 120),
		},
		{
			Id = "Giant",
			Name = "Giant",
			Short = "XL",
			Weight = 4,
			ValueMultiplier = 5,
			Lucky = true,
			Scale = 2.4,
			Color = rgb(255, 140, 60),
		},
	} :: { VariantDef },
	MATERIALS = {
		{
			Id = "None",
			Name = "",
			Short = "-",
			Weight = 88,
			ValueMultiplier = 1,
			Lucky = false,
			Color = rgb(235, 235, 235),
		},
		{
			Id = "Golden",
			Name = "Golden",
			Short = "Gold",
			Weight = 7,
			ValueMultiplier = 3,
			Lucky = true,
			Color = rgb(255, 205, 40),
		},
		{
			Id = "Fossilized",
			Name = "Fossilized",
			Short = "Fos",
			Weight = 3.5,
			ValueMultiplier = 5,
			Lucky = true,
			Color = rgb(170, 140, 110),
		},
		{
			Id = "Crystal",
			Name = "Crystal",
			Short = "Cry",
			Weight = 1.5,
			ValueMultiplier = 10,
			Lucky = true,
			Color = rgb(120, 230, 255),
		},
	} :: { VariantDef },
	QUALITIES = {
		{ Id = "Damaged", Name = "Damaged", MinScore = 0, ValueMultiplier = 0.6, Color = rgb(200, 150, 120) },
		{ Id = "Good", Name = "Good", MinScore = 2, ValueMultiplier = 1, Color = rgb(235, 235, 235) },
		{ Id = "Pristine", Name = "Pristine", MinScore = 5, ValueMultiplier = 1.5, Color = rgb(120, 255, 200) },
	} :: { QualityDef },

	-- Presentation tier by rarity (Finds.Tier also bumps a Pop to a Beam for Giant / material finds).
	TIER_BY_RARITY = {
		Common = "Pop",
		Uncommon = "Pop",
		Rare = "Beam",
		Epic = "Card",
		Legendary = "Card",
		Mythic = "Server",
		Relic = "Spectacle",
	} :: { [string]: Types.FindTier },
}

return Discovery

```

## src/shared/Config/Eggs.luau

Original SHA-256: `861afbc987e851571c0e06fddf0d9f41ef2ece72a42fff8e5830d3b56df0880c`

```lua
--!strict
--[[
	Eggs — hatch pets. Coin eggs unlock when your MaxDepth reaches the layer UnlockLayer
	(Config.IsEggUnlocked). Weights are relative (they sum to 100 for readability).
	Rebirth Egg and Golden Egg cost Rebirth Tokens (v2.3: the Golden Egg is no longer sold for
	Robux; Config rejects any egg with Currency "Robux").
	Luck boosts multiply the weight of non-Common pets; Triple Hatch pass hatches 3 at once.

	v2.1: Construction Crates (Kind = "Crate") are eggs that hatch digging vehicle pets (see
	Config/Pets.luau and docs/design/Companions.md). Same hatch flow, prices and unlocks; the world
	builds them in a small crate yard next to the plaza and the UI draws them as crates. The top
	crate hides the rideable Mythic "mega_excavator" (0.5%).

	v2.2 PITY (PityAt): after PityAt hatches IN A ROW without a Rare-or-better pet, the next hatch
	of that egg is guaranteed Rare+ (re-rolled among the Rare+ entries by their relative weights).
	Counter per egg in PlayerData.Pity, reset by any Rare+ hatch. Odds shown in the egg panel and
	rolled on the server come from the same function, Stats.GetHatchOdds. Tuning (base Rare+ chance
	-> chance a player ever reaches pity on a streak):
	  Beach Egg 2% -> 40 (cheap egg, ~45% of 40-streaks)    other coin eggs 12% -> 30 (~2%)
	  Cosmic Egg 30% -> 25 (almost never)                   Sandbox/Quarry/Mine Crate 7% -> 35 (~8%)
	  Core Crate 38% -> 25 (almost never)                   Rebirth / Golden Egg: all Rare+, no pity
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Eggs: { Types.EggDef } = {
	{
		Id = "beach_egg",
		Name = "Beach Egg",
		Currency = "Coins",
		Price = 100,
		UnlockLayer = 1,
		PityAt = 40,
		Pets = {
			{ PetId = "sandy_crab", Weight = 60 },
			{ PetId = "seagull", Weight = 28 },
			{ PetId = "starfish", Weight = 10 },
			{ PetId = "baby_turtle", Weight = 1.9 },
			{ PetId = "golden_crab", Weight = 0.1 },
		},
		Look = { ShellColor = rgb(255, 240, 200), SpotColor = rgb(80, 200, 255), Glow = false },
	},
	{
		Id = "tidepool_egg",
		Name = "Tide Pool Egg",
		Currency = "Coins",
		Price = 2500,
		UnlockLayer = 3,
		PityAt = 30,
		Pets = {
			{ PetId = "clownfish", Weight = 60 },
			{ PetId = "pufferfish", Weight = 28 },
			{ PetId = "octopus", Weight = 10 },
			{ PetId = "sea_turtle", Weight = 1.9 },
			{ PetId = "rainbow_starfish", Weight = 0.1 },
		},
		Look = { ShellColor = rgb(120, 220, 240), SpotColor = rgb(255, 150, 180), Glow = false },
	},
	{
		Id = "pirate_egg",
		Name = "Pirate Egg",
		Currency = "Coins",
		Price = 40000,
		UnlockLayer = 5,
		PityAt = 30,
		Pets = {
			{ PetId = "parrot", Weight = 60 },
			{ PetId = "pirate_crab", Weight = 28 },
			{ PetId = "ghost_blob", Weight = 10 },
			{ PetId = "skeleton_shark", Weight = 1.9 },
			{ PetId = "kraken", Weight = 0.1 },
		},
		Look = { ShellColor = rgb(150, 100, 60), SpotColor = rgb(255, 210, 50), Glow = false },
	},
	{
		Id = "fossil_egg",
		Name = "Fossil Egg",
		Currency = "Coins",
		Price = 600000,
		UnlockLayer = 7,
		PityAt = 30,
		Pets = {
			{ PetId = "mole", Weight = 60 },
			{ PetId = "baby_raptor", Weight = 28 },
			{ PetId = "stegosaurus", Weight = 10 },
			{ PetId = "trex", Weight = 1.9 },
			{ PetId = "bone_dragon", Weight = 0.1 },
		},
		Look = { ShellColor = rgb(230, 215, 180), SpotColor = rgb(140, 120, 90), Glow = false },
	},
	{
		Id = "crystal_egg",
		Name = "Crystal Egg",
		Currency = "Coins",
		Price = 8000000,
		UnlockLayer = 9,
		PityAt = 30,
		Pets = {
			{ PetId = "crystal_bat", Weight = 60 },
			{ PetId = "gem_blob", Weight = 28 },
			{ PetId = "crystal_golem", Weight = 10 },
			{ PetId = "frost_seal", Weight = 1.9 },
			{ PetId = "diamond_dragon", Weight = 0.1 },
		},
		Look = { ShellColor = rgb(180, 120, 255), SpotColor = rgb(150, 240, 255), Glow = true },
	},
	{
		Id = "magma_egg",
		Name = "Magma Egg",
		Currency = "Coins",
		Price = 150000000,
		UnlockLayer = 12,
		PityAt = 30,
		Pets = {
			{ PetId = "lava_salamander", Weight = 60 },
			{ PetId = "magma_golem", Weight = 28 },
			{ PetId = "fire_bird", Weight = 10 },
			{ PetId = "lava_kraken", Weight = 1.9 },
			{ PetId = "phoenix", Weight = 0.09 },
			{ PetId = "core_dragon", Weight = 0.01 },
		},
		Look = { ShellColor = rgb(60, 30, 30), SpotColor = rgb(255, 100, 30), Glow = true },
	},
	{
		Id = "cosmic_egg",
		Name = "Cosmic Egg",
		Currency = "Coins",
		Price = 3000000000,
		UnlockLayer = 14,
		PityAt = 25,
		Pets = {
			{ PetId = "alien_blob", Weight = 70 },
			{ PetId = "cosmic_turtle", Weight = 25 },
			{ PetId = "star_golem", Weight = 4.9 },
			{ PetId = "galaxy_dragon", Weight = 0.1 },
		},
		Look = { ShellColor = rgb(40, 30, 100), SpotColor = rgb(120, 255, 160), Glow = true },
	},
	{
		Id = "rebirth_egg",
		Name = "Rebirth Egg",
		Currency = "Tokens",
		Price = 3,
		UnlockLayer = 1,
		Pets = {
			{ PetId = "tide_spirit", Weight = 70 },
			{ PetId = "rebirth_phoenix", Weight = 25 },
			{ PetId = "sandlantis_guardian", Weight = 5 },
		},
		Look = { ShellColor = rgb(120, 255, 200), SpotColor = rgb(255, 255, 255), Glow = true },
	},
	{
		-- v2.3: earnable only (was a Robux product). 10 Rebirth Tokens ~ 4 early rebirths.
		Id = "golden_egg",
		Name = "Golden Egg",
		Currency = "Tokens",
		Price = 10,
		UnlockLayer = 1,
		Pets = {
			{ PetId = "golden_seagull", Weight = 70 },
			{ PetId = "golden_turtle", Weight = 27 },
			{ PetId = "sun_dragon", Weight = 3 },
		},
		Look = { ShellColor = rgb(255, 210, 50), SpotColor = rgb(255, 255, 255), Glow = true },
	},
	-- v2.1 Construction Crates ------------------------------------------------------------------
	{
		Id = "sandbox_crate",
		Name = "Sandbox Crate",
		Kind = "Crate",
		Currency = "Coins",
		Price = 1000,
		UnlockLayer = 3,
		PityAt = 35,
		Pets = {
			{ PetId = "toy_truck", Weight = 65 },
			{ PetId = "dump_truck", Weight = 28 },
			{ PetId = "mini_excavator", Weight = 7 },
		},
		Look = { ShellColor = rgb(214, 160, 96), SpotColor = rgb(255, 200, 40), Glow = false },
	},
	{
		Id = "quarry_crate",
		Name = "Quarry Crate",
		Kind = "Crate",
		Currency = "Coins",
		Price = 75000,
		UnlockLayer = 6,
		PityAt = 35,
		Pets = {
			{ PetId = "skid_steer", Weight = 65 },
			{ PetId = "bulldozer", Weight = 28 },
			{ PetId = "backhoe", Weight = 7 },
		},
		Look = { ShellColor = rgb(150, 156, 168), SpotColor = rgb(255, 170, 30), Glow = false },
	},
	{
		Id = "mine_crate",
		Name = "Deep Mine Crate",
		Kind = "Crate",
		Currency = "Coins",
		Price = 6000000,
		UnlockLayer = 10,
		PityAt = 35,
		Pets = {
			{ PetId = "drill_rig", Weight = 65 },
			{ PetId = "mining_drill", Weight = 28 },
			{ PetId = "tunnel_borer", Weight = 7 },
		},
		Look = { ShellColor = rgb(110, 80, 60), SpotColor = rgb(255, 120, 30), Glow = false },
	},
	{
		Id = "core_crate",
		Name = "Core Crate",
		Kind = "Crate",
		Currency = "Coins",
		Price = 1500000000,
		UnlockLayer = 14,
		PityAt = 25,
		Pets = {
			{ PetId = "mole_machine", Weight = 62 },
			{ PetId = "lava_drill", Weight = 30 },
			{ PetId = "core_driller", Weight = 7.5 },
			{ PetId = "mega_excavator", Weight = 0.5 },
		},
		Look = { ShellColor = rgb(60, 60, 72), SpotColor = rgb(255, 210, 60), Glow = true },
	},
}

return Eggs

```

## src/shared/Config/Events.luau

Original SHA-256: `6531688dbf9474b5b1c194b678386d83fb8dfbfe6f2279ea946538e4ba8af98a`

```lua
--!strict
--[[
	Events — server-wide timed events, deterministic from os.time() so every server agrees
	without messaging: active while (os.time() + OffsetSeconds) % IntervalSeconds < DurationSeconds.
	Use Config.GetActiveEvents(now) to evaluate. The UI should show a countdown banner
	("High Tide in 2:31!") — anticipation is half the fun and pulls players back online.
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Events: { Types.EventDef } = {
	{
		Id = "HighTide",
		Name = "High Tide",
		Description = "The tide washes treasure into the sand! 2x Luck for everyone.",
		Kind = "Luck",
		Multiplier = 2,
		IntervalSeconds = 20 * 60,
		DurationSeconds = 3 * 60,
		OffsetSeconds = 0,
		Color = rgb(50, 170, 255),
	},
	{
		Id = "GoldenHour",
		Name = "Golden Hour",
		Description = "The sunset makes everything shine. 2x Coins when you sell!",
		Kind = "Coins",
		Multiplier = 2,
		IntervalSeconds = 45 * 60,
		DurationSeconds = 5 * 60,
		OffsetSeconds = 10 * 60,
		Color = rgb(255, 160, 40),
	},
}

return Events

```

## src/shared/Config/Heat.luau

Original SHA-256: `8f00b2553f3fb4f3328e827fa898aabced76023115d5715cdaf84da08f570a32`

```lua
--!strict
--[[
	Heat — the soft survival meter (owner: Survival). See docs/design/Survival.md.

	The server (SurvivalService) ticks every player's heat every TickSeconds:
	  underground (Depth >= UndergroundDepth)  -> falls UndergroundFallPerSecond
	  under any placed shade                   -> falls ShadeFallPerSecond x best shade Cooling
	  on the hot sand in the sun               -> rises SunRisePerSecond x event multiplier
	                                              + DigRisePerDig per dig (max DigRiseMaxPerSecond)
	  anywhere else (boardwalk, hub, the sea)  -> falls OffSandFallPerSecond
	At SunburntAt the player is Sunburnt (dig cooldown x SunburntCooldownMultiplier) until heat
	falls to RecoverAt. Never damage, never death.

	Tuning targets (fresh player, toy shovel at 2 digs/s, full sun, no shade / drinks):
	  0.45/s sun + 2 x 0.12/s digging = 0.69/s  ->  100 heat in ~145 s (~2.4 min) of digging,
	  ~220 s standing still. Fountain water (-70) fixes Sunburnt instantly; a Beach Umbrella
	  takes 100 -> 40 in 20 s. New players get NewPlayerGraceSeconds of total play time with no
	  heat gain (the FTUE stays heat-free until the first umbrella is nearly affordable).
]]
local Types = require(script.Parent.Parent.Types)

local Heat: Types.HeatConfig = {
	Max = 100,
	TickSeconds = 0.25,

	SunRisePerSecond = 0.45,
	DigRisePerDig = 0.12,
	DigRiseMaxPerSecond = 0.3,

	ShadeFallPerSecond = 3,
	UndergroundDepth = 12,
	UndergroundFallPerSecond = 2.5,
	OffSandFallPerSecond = 1.5,

	WarningAt = 75,
	SunburntAt = 100,
	RecoverAt = 40,
	SunburntCooldownMultiplier = 1.6,
	NewPlayerGraceSeconds = 180,

	-- Golden Hour: the low sun is hotter. High Tide: a cool sea breeze.
	EventSunMultipliers = {
		GoldenHour = 1.35,
		HighTide = 0.6,
	},

	FountainCooldownSeconds = 3,
	ConsumableMaxStack = 99,
	ConsumableBoostCapSeconds = 300,

	ShadeSlots = 1,
	ShadeSlotsVip = 2,
	ShadePlaceRange = 30,
	ShadeMinSpacing = 4,
	ShadeHubClearance = 10,
}

return Heat

```

## src/shared/Config/IconAtlas.luau

Original SHA-256: `a85ea2fc7ff5244637d53757dbfcf9769aa106182f65da24086d95378979deaa`

```lua
--!strict
--[[
	IconAtlas — GENERATED by tools/icons/generate_icons.py (re-run it after changing icons; the
	generator keeps the ASSET_ID below). Source art: assets/icons/atlas.png, 1024x1024, an 8x8 grid
	of 128x128 cells; Icons[name] is the cell's ImageRectOffset in pixels.

	Usage on an ImageLabel / ImageButton:
		local offset = IconAtlas.Resolve("coins") -- or a UI/Icons.luau key: IconAtlas.Resolve("Coins")
		if IconAtlas.AssetId ~= "" and offset then
			label.Image = IconAtlas.AssetId
			label.ImageRectOffset = offset
			label.ImageRectSize = Vector2.new(IconAtlas.CellSize, IconAtlas.CellSize)
		else -- fall back to the emoji text from UI/Icons.luau
		end
	Grouped Icons.luau tables (Icons.Layers, Icons.PetShapes, ...): Groups[group][key] or
	Groups[group].Default.

	UPLOADING THE ATLAS (owner, once per change of atlas.png):
	  1. Studio -> View -> Asset Manager -> Bulk Import -> choose assets/icons/atlas.png
	     (or Creator Hub -> Creations -> Development Items -> Decals/Images -> Upload).
	  2. Copy the IMAGE asset id, NOT the decal id. In Studio, insert the uploaded decal into the
	     Workspace and look at its Texture/Image property: "rbxassetid://<id>" — that <id> is the
	     image id. (Asset Manager -> right-click the image -> Copy Asset ID also gives the image id.)
	     The decal id from the website URL is a different number and will show a blank image.
	  3. Paste it below:  local ASSET_ID = "rbxassetid://<id>"
	While ASSET_ID is "" the UI should keep using the emoji icons (UI/Icons.luau).
]]

local ASSET_ID = "rbxassetid://97869519007106"

local Icons: { [string]: Vector2 } = {
	coins = Vector2.new(0, 0),
	tokens = Vector2.new(128, 0),
	sand = Vector2.new(256, 0),
	backpack = Vector2.new(384, 0),
	shovel = Vector2.new(512, 0),
	spade = Vector2.new(640, 0),
	pickaxe = Vector2.new(768, 0),
	depth = Vector2.new(896, 0),
	layer = Vector2.new(0, 128),
	trophy = Vector2.new(128, 128),
	multiplier = Vector2.new(256, 128),
	shop = Vector2.new(384, 128),
	beach_shop = Vector2.new(512, 128),
	eggs = Vector2.new(640, 128),
	crate = Vector2.new(768, 128),
	pets = Vector2.new(896, 128),
	index = Vector2.new(0, 256),
	quests = Vector2.new(128, 256),
	daily = Vector2.new(256, 256),
	gift = Vector2.new(384, 256),
	rebirth = Vector2.new(512, 256),
	store = Vector2.new(640, 256),
	settings = Vector2.new(768, 256),
	surface = Vector2.new(896, 256),
	sell = Vector2.new(0, 384),
	auto = Vector2.new(128, 384),
	ride = Vector2.new(256, 384),
	place_shade = Vector2.new(384, 384),
	heat = Vector2.new(512, 384),
	sun = Vector2.new(640, 384),
	shade = Vector2.new(768, 384),
	water = Vector2.new(896, 384),
	lemonade = Vector2.new(0, 512),
	coconut = Vector2.new(128, 512),
	popsicle = Vector2.new(256, 512),
	shaved_ice = Vector2.new(384, 512),
	watermelon_slice = Vector2.new(512, 512),
	giant_watermelon = Vector2.new(640, 512),
	boost_sand = Vector2.new(768, 512),
	boost_luck = Vector2.new(896, 512),
	boost_speed = Vector2.new(0, 640),
	boost_coins = Vector2.new(128, 640),
	golden_hour = Vector2.new(256, 640),
	high_tide = Vector2.new(384, 640),
	treasure = Vector2.new(512, 640),
	egg_hatch = Vector2.new(640, 640),
	lock = Vector2.new(768, 640),
	check = Vector2.new(896, 640),
	close = Vector2.new(0, 768),
	arrow_right = Vector2.new(128, 768),
	arrow_down = Vector2.new(256, 768),
	star = Vector2.new(384, 768),
	notify = Vector2.new(512, 768),
	music = Vector2.new(640, 768),
	sfx = Vector2.new(768, 768),
	codes = Vector2.new(896, 768),
	info = Vector2.new(0, 896),
	power = Vector2.new(128, 896),
	radius = Vector2.new(256, 896),
	hand = Vector2.new(384, 896),
	gem = Vector2.new(512, 896),
	shell = Vector2.new(640, 896),
	crab = Vector2.new(768, 896),
	hourglass = Vector2.new(896, 896),
}

-- UI/Icons.luau key -> atlas icon name
local Aliases: { [string]: string } = {
	Coins = "coins",
	Tokens = "tokens",
	Rebirth = "rebirth",
	Sand = "sand",
	Backpack = "backpack",
	Depth = "depth",
	Shop = "shop",
	Eggs = "eggs",
	Pets = "pets",
	Index = "index",
	Quests = "quests",
	Daily = "daily",
	Store = "store",
	Settings = "settings",
	Beach = "beach_shop",
	Garage = "ride",
	Dig = "pickaxe",
	Ride = "ride",
	Crate = "crate",
	Surface = "surface",
	Sell = "sell",
	AutoDig = "auto",
	Lock = "lock",
	Check = "check",
	Close = "close",
	Star = "star",
	Robux = "store",
	Power = "power",
	Speed = "boost_speed",
	Radius = "radius",
	Multiplier = "multiplier",
	Hand = "hand",
	Arrow = "arrow_down",
}

-- UI/Icons.luau grouped tables -> atlas icon name (per-key overrides, else Default)
local Groups: { [string]: { [string]: string } } = {
	Layers = {
		Default = "layer",
		crystal_caverns = "gem",
		shell_bed = "shell",
		tidal_clay = "crab",
		shipwreck = "treasure",
		the_core = "sun",
		dry_sand = "sand",
		wet_sand = "high_tide",
	},
	PetShapes = {
		Default = "pets",
		Crab = "crab",
		Star = "star",
	},
	VehicleKinds = {
		Default = "ride",
		MiningDrill = "pickaxe",
		Mole = "auto",
	},
	BackpackShapes = {
		Default = "backpack",
		Bucket = "sand",
		Box = "crate",
		Cart = "shop",
		Vehicle = "ride",
		Orb = "gem",
	},
	TreasureShapes = {
		Default = "treasure",
		Coin = "coins",
		Shell = "shell",
		Chest = "treasure",
		Gem = "gem",
		Egg = "eggs",
		Shard = "tokens",
		Box = "crate",
		Crown = "trophy",
	},
	BoostKinds = {
		Default = "multiplier",
		Sand = "boost_sand",
		Luck = "boost_luck",
		Coins = "boost_coins",
		Speed = "boost_speed",
	},
	Events = {
		Default = "star",
		HighTide = "high_tide",
		GoldenHour = "golden_hour",
	},
}

-- Atlas offset for an icon name ("coins") or a UI/Icons.luau key ("Coins"); nil if unknown.
local function Resolve(key: string): Vector2?
	local direct = Icons[key]
	if direct then
		return direct
	end
	local alias = Aliases[key]
	return if alias then Icons[alias] else nil
end

-- Atlas offset for a grouped Icons.luau entry, e.g. GroupOffset("PetShapes", "Crab").
local function GroupOffset(group: string, key: string): Vector2?
	local g = Groups[group]
	if not g then
		return nil
	end
	local name = g[key] or g.Default
	return if name then Icons[name] else nil
end

return {
	AssetId = ASSET_ID,
	CellSize = 128,
	Icons = Icons,
	Aliases = Aliases,
	Groups = Groups,
	Resolve = Resolve,
	GroupOffset = GroupOffset,
}

```

## src/shared/Config/init.luau

Original SHA-256: `17ea916112a67808b721cea82f1dcf5415301e4b0189304ed9a838606e01773e`

```lua
--!strict
--[[
	Config — single entry point for ALL balance & presentation data.
	ReplicatedStorage.Shared.Config (owner: Game design). Read-only at runtime: never mutate.

	Fields:   Layers, Shovels, Backpacks, Pets, Eggs, Treasures, Rarities, Rebirths, Quests,
	          DailyRewards, Codes, Monetization, Boosts, Events, Sounds, Theme
	Helpers:  see function list below; all lookups are O(1) via maps built at require time.

	Depth unit: studs below the beach surface (positive). 1 stud = 1 "meter" in the UI.
	Sand -> Coins at SELL_RATE. Sand per dig =
	    layer.SandValue * shovel.SandMultiplier * RebirthMultiplier * PetMultiplier
	    * (pass/premium/group/friend/boost/event multipliers, all multiplicative)
	Capacity = backpack.Capacity * RebirthMultiplier * (MegaBackpack ? 2 : 1)
]]

local Types = require(script.Parent.Types)

local Layers = require(script.Layers)
local Shovels = require(script.Shovels)
local Backpacks = require(script.Backpacks)
local Pets = require(script.Pets)
local Eggs = require(script.Eggs)
local Treasures = require(script.Treasures)
local Rarities = require(script.Rarities)
local Rebirths = require(script.Rebirths)
local Quests = require(script.Quests)
local DailyRewards = require(script.DailyRewards)
local Codes = require(script.Codes)
local Badges = require(script.Badges)
local Monetization = require(script.Monetization)
local Boosts = require(script.Boosts)
local Events = require(script.Events)
local Sounds = require(script.Sounds)
local Theme = require(script.Theme)
local Heat = require(script.Heat)
local Shades = require(script.Shades)
local Consumables = require(script.Consumables)
local Ride = require(script.Ride) -- v2.1 ride-on excavator tuning (Ride agent)
local RebirthPerks = require(script.RebirthPerks) -- v2.2 rebirth token perk shop (Rebirth agent)
local Titles = require(script.Titles) -- v2.2 nameplate titles (Status & Social agent)
local Social = require(script.Social) -- v2.2 announcements / leaderboard scopes / server goal
local Discovery = require(script.Discovery) -- v3 buried finds / detector / excavation (Discovery agent)

local TOTAL_DEPTH = Layers[#Layers].DepthEnd

local Config = {
	-- Data ---------------------------------------------------------------------------------
	Layers = Layers,
	Shovels = Shovels,
	Backpacks = Backpacks,
	Pets = Pets,
	Eggs = Eggs,
	Treasures = Treasures,
	Rarities = Rarities,
	Rebirths = Rebirths,
	Quests = Quests,
	DailyRewards = DailyRewards,
	Codes = Codes,
	Badges = Badges,
	Monetization = Monetization,
	Boosts = Boosts,
	Events = Events,
	Sounds = Sounds,
	Theme = Theme,
	Heat = Heat,
	Shades = Shades,
	Consumables = Consumables,
	Ride = Ride,
	RebirthPerks = RebirthPerks,
	Titles = Titles,
	Social = Social,
	Discovery = Discovery,

	-- World --------------------------------------------------------------------------------
	-- One shared dig zone along the shoreline (World.GetDigZone); no plots.
	MAX_PLAYERS = 16, -- OWNER: set Game Settings > Places > Max Players to this
	TOTAL_DEPTH = TOTAL_DEPTH, -- studs from surface to the bottom of The Core
	-- Surface is high up so the bottom of the hole (SURFACE_Y - TOTAL_DEPTH = 24) stays well above
	-- Workspace.FallenPartsDestroyHeight (-500). Terrain must not be generated below Y = 0.
	SURFACE_Y = 1024,
	STUDS_PER_METER = 1,
	-- The tide refills a dug 8x8 column once no player was within TIDE_CLEAR_RADIUS studs
	-- (horizontally) for this long. High Tide smooths every hole at once.
	TIDE_REFILL_SECONDS = 240,
	TIDE_CLEAR_RADIUS = 12,

	-- Digging ------------------------------------------------------------------------------
	REACH = 20, -- max studs from HumanoidRootPart to the dig point
	COOLDOWN_LENIENCY = 0.85, -- server accepts a dig after Cooldown * this (latency slack)
	SELL_RATE = 1, -- coins per sand
	MAX_TREASURE_CHANCE = 0.5, -- cap after luck multipliers
	-- Collection bonus: +2% sand for every layer whose treasures are ALL in PlayerData.Index
	-- (computed from Index, nothing extra persisted). Max 15 layers = +30%.
	INDEX_LAYER_BONUS = 0.02,

	-- Pets ---------------------------------------------------------------------------------
	-- Base equip slots (PlayerData.PetSlots default). Passes add GamePasses[*].ExtraPetSlots:
	-- ExtraPets +2, AutoDig +1 (Stats.GetPetSlots).
	MAX_EQUIPPED_PETS = 3,
	PET_INVENTORY_LIMIT = 200,
	TRIPLE_HATCH_COUNT = 3,
	-- v2.2 hatch pity + duplicate fusion (docs/design/Companions.md "Pity and Golden pets").
	PITY_MIN_RARITY_ORDER = 3, -- "Rare or better" (RarityDef.Order); EggDef.PityAt per egg
	GOLDEN_FUSE_COUNT = 5, -- identical non-golden copies fused into one Golden pet
	GOLDEN_SAND_BONUS = 1.5, -- a Golden pet's sand bonus (Multiplier - 1) is x1.5
	GOLDEN_DIG_SPEED = 1.25, -- a Golden digging pet digs 1.25x as often (Interval / 1.25)

	-- Social -------------------------------------------------------------------------------
	GROUP_ID = 0, -- OWNER: paste the Roblox group id; members get GROUP_SAND_MULTIPLIER
	GROUP_SAND_MULTIPLIER = 1.1,
	FRIEND_BONUS_PER_FRIEND = 0.05, -- +5% sand per friend in the same server...
	FRIEND_BONUS_MAX = 0.2, -- ...up to +20%
	LEADERBOARD_SIZE = 50,
	LEADERBOARD_REFRESH_SECONDS = 60,

	-- Retention ----------------------------------------------------------------------------
	DAILY_COOLDOWN_SECONDS = 20 * 3600,
	DAILY_STREAK_GRACE_SECONDS = 48 * 3600,

	-- Persistence --------------------------------------------------------------------------
	DATASTORE_NAME = "PlayerData_v1",
	LEADERBOARD_COINS_STORE = "Leaderboard_Coins",
	LEADERBOARD_DEPTH_STORE = "Leaderboard_Depth",
	-- 2: v2.1 converts data.Diggers into vehicle pets; 3: v3 moves unsold Treasures into Finds
	-- (DataService migrations)
	DATA_VERSION = 3,
	AUTOSAVE_SECONDS = 120,
	SESSION_LOCK_SECONDS = 1800,

	-- Onboarding (FTUE) --------------------------------------------------------------------
	-- Complete events: "AtSand", "Dig", "BackpackFull", "Sell", "BuyShovel", "HatchEgg".
	-- Target "Sand" = the nearest point of the dig zone.
	TUTORIAL_STEPS = {
		{ Id = "go_sand", Text = "Follow the arrow to the sand!", Target = "Sand", Complete = "AtSand" },
		{ Id = "first_dig", Text = "Tap the sand to DIG!", Target = "Sand", Complete = "Dig" },
		{ Id = "fill_up", Text = "Keep digging until your bucket is full!", Complete = "BackpackFull" },
		{ Id = "sell", Text = "Bucket full! Run to the SELL stand.", Target = "SellZone", Complete = "Sell" },
		{ Id = "shop", Text = "Buy a better shovel to dig deeper!", Target = "ShovelShop", Complete = "BuyShovel" },
		{ Id = "dig_deeper", Text = "New shovel! Dig DOWN into a new layer!", Target = "Sand", Complete = "NewLayer" },
		{ Id = "egg", Text = "Hatch a pet - pets give you more sand!", Target = "EggShop", Complete = "HatchEgg" },
	} :: { Types.TutorialStep },
}

-- Lookup maps --------------------------------------------------------------------------------

local function indexById<T>(list: { T }, getId: (T) -> string): ({ [string]: T }, { [string]: number })
	local byId: { [string]: T } = {}
	local indexOf: { [string]: number } = {}
	for i, item in list do
		local id = getId(item)
		assert(byId[id] == nil, "Config: duplicate id " .. id)
		byId[id] = item
		indexOf[id] = i
	end
	return byId, indexOf
end

local shovelById, shovelIndex = indexById(Shovels, function(s: Types.ShovelDef)
	return s.Id
end)
local backpackById, backpackIndex = indexById(Backpacks, function(b: Types.BackpackDef)
	return b.Id
end)
local petById = indexById(Pets, function(p: Types.PetDef)
	return p.Id
end)
local eggById = indexById(Eggs, function(e: Types.EggDef)
	return e.Id
end)
local treasureById = indexById(Treasures, function(t: Types.TreasureDef)
	return t.Id
end)
local rarityByName = indexById(Rarities, function(r: Types.RarityDef)
	return r.Name
end)
local questById = indexById(Quests, function(q: Types.QuestDef)
	return q.Id
end)
local boostById = indexById(Boosts, function(b: Types.BoostDef)
	return b.Id
end)
local eventById = indexById(Events, function(e: Types.EventDef)
	return e.Id
end)
local codeByCode = indexById(Codes, function(c: Types.CodeDef)
	return string.upper(c.Code)
end)

-- Helpers ------------------------------------------------------------------------------------

function Config.GetShovel(id: string): Types.ShovelDef?
	return shovelById[id]
end

function Config.GetShovelIndex(id: string): number?
	return shovelIndex[id]
end

function Config.GetBackpack(id: string): Types.BackpackDef?
	return backpackById[id]
end

function Config.GetBackpackIndex(id: string): number?
	return backpackIndex[id]
end

function Config.GetPet(id: string): Types.PetDef?
	return petById[id]
end

function Config.GetEgg(id: string): Types.EggDef?
	return eggById[id]
end

function Config.GetTreasure(id: string): Types.TreasureDef?
	return treasureById[id]
end

function Config.GetRarity(name: string): Types.RarityDef?
	return rarityByName[name]
end

function Config.GetQuest(id: string): Types.QuestDef?
	return questById[id]
end

function Config.GetBoost(id: string): Types.BoostDef?
	return boostById[id]
end

function Config.GetEvent(id: string): Types.EventDef?
	return eventById[id]
end

-- Case-insensitive, whitespace-trimmed. Returns nil for unknown codes (does NOT check Enabled/Expires).
function Config.GetCode(code: string): Types.CodeDef?
	local normalized = string.upper((string.gsub(code, "%s", "")))
	return codeByCode[normalized]
end

-- Index (1..#Layers) of the layer at `depth` studs below the surface. Clamped to the range.
function Config.GetLayerIndexAtDepth(depth: number): number
	if depth < 0 then
		return 1
	end
	for i, layer in Layers do
		if depth < layer.DepthEnd then
			return i
		end
	end
	return #Layers
end

function Config.GetLayerAtDepth(depth: number): Types.LayerDef
	return Layers[Config.GetLayerIndexAtDepth(depth)]
end

-- Deepest layer index this shovel power can dig (layers with Hardness <= power).
function Config.GetMaxLayerIndexForPower(power: number): number
	local best = 1
	for i, layer in Layers do
		if layer.Hardness <= power then
			best = i
		end
	end
	return best
end

function Config.DepthToMeters(depth: number): number
	return math.floor(math.max(depth, 0) / Config.STUDS_PER_METER)
end

-- Coins for the NEXT rebirth when the player has `rebirths` rebirths.
function Config.RebirthCost(rebirths: number): number
	return Rebirths.Cost(rebirths)
end

function Config.RebirthMultiplier(rebirths: number): number
	return Rebirths.Multiplier(rebirths)
end

function Config.RebirthTokens(rebirths: number): number
	return Rebirths.Tokens(rebirths)
end

-- Additive pet bonus: 1 + sum(Multiplier - 1). Unknown ids are ignored.
-- v2.2: golden[i] = true marks petIds[i] as a Golden pet (bonus x GOLDEN_SAND_BONUS).
function Config.PetMultiplier(petIds: { string }, golden: { [number]: boolean }?): number
	local total = 1
	for i, id in petIds do
		local pet = petById[id]
		if pet then
			local bonus = pet.Multiplier - 1
			if golden and golden[i] then
				bonus *= Config.GOLDEN_SAND_BONUS
			end
			total += bonus
		end
	end
	return total
end

-- v2.2: one pet's own multiplier (1 + bonus), Golden included. Unknown id -> 1.
function Config.PetEffectiveMultiplier(petId: string, golden: boolean?): number
	return Config.PetMultiplier({ petId }, { golden == true })
end

-- Flat Coins + ScaledCoins * RewardScale of the layer at maxDepth. Rounded down.
function Config.ResolveCoins(reward: Types.Reward, maxDepth: number): number
	local coins = reward.Coins or 0
	if reward.ScaledCoins then
		coins += reward.ScaledCoins * Config.GetLayerAtDepth(maxDepth).RewardScale
	end
	return math.floor(coins)
end

function Config.IsEggUnlocked(eggId: string, maxDepth: number): boolean
	local egg = eggById[eggId]
	if not egg then
		return false
	end
	local layer = Layers[egg.UnlockLayer]
	return layer ~= nil and maxDepth >= layer.DepthStart
end

-- Reward row for a streak value (1-based, cycles every #DailyRewards days).
function Config.GetDailyReward(streak: number): Types.DailyRewardDef
	local index = ((math.max(streak, 1) - 1) % #DailyRewards) + 1
	return DailyRewards[index]
end

-- Events active at unix time `now` (defaults to os.time()).
function Config.GetActiveEvents(now: number?): { Types.EventDef }
	local t = now or os.time()
	local active = {}
	for _, event in Events do
		if (t + event.OffsetSeconds) % event.IntervalSeconds < event.DurationSeconds then
			table.insert(active, event)
		end
	end
	return active
end

-- Seconds until the event next starts (0 if active now).
function Config.GetSecondsUntilEvent(eventId: string, now: number?): number
	local event = eventById[eventId]
	if not event then
		return math.huge
	end
	local phase = ((now or os.time()) + event.OffsetSeconds) % event.IntervalSeconds
	if phase < event.DurationSeconds then
		return 0
	end
	return event.IntervalSeconds - phase
end

function Config.GetGamePassKeyById(id: number): string?
	if id == 0 then
		return nil
	end
	for key, pass in Monetization.GamePasses do
		if pass.Id == id then
			return key
		end
	end
	return nil
end

function Config.GetProductKeyById(id: number): string?
	if id == 0 then
		return nil
	end
	for key, product in Monetization.Products do
		if product.Id == id then
			return key
		end
	end
	return nil
end

-- Companions (v2.1) ---------------------------------------------------------------------------

-- Construction Crates are eggs with Kind = "Crate" (they hatch vehicle pets).
function Config.IsCrate(eggId: string): boolean
	local egg = eggById[eggId]
	return egg ~= nil and egg.Kind == "Crate"
end

-- The pet's dig ability (vehicles from crates, a few creatures), or nil.
function Config.GetPetDig(petId: string): Types.PetDigDef?
	local pet = petById[petId]
	return if pet then pet.Dig else nil
end

-- v2.2: seconds between digs for this pet; Golden pets dig GOLDEN_DIG_SPEED x as often.
function Config.GetPetDigInterval(petId: string, golden: boolean?): number?
	local dig = Config.GetPetDig(petId)
	if not dig then
		return nil
	end
	return (dig :: Types.PetDigDef).Interval / (if golden then Config.GOLDEN_DIG_SPEED else 1)
end

-- Compliance (v2.2) -----------------------------------------------------------------------------

-- Is this pass / product a paid random item, a paid luck modifier or currency that buys random
-- items (Monetization PaidRandom)? Those are hidden and refused for PolicyService-restricted
-- players (ArePaidRandomItemsRestricted). kind: "GamePass" | "Product".
function Config.IsPaidRandom(kind: string, key: string): boolean
	if kind == "GamePass" then
		local pass = Monetization.GamePasses[key]
		return pass ~= nil and pass.PaidRandom == true
	elseif kind == "Product" then
		local product = Monetization.Products[key]
		return product ~= nil and product.PaidRandom == true
	end
	return false
end

-- Ride (v2.1, Ride agent) ----------------------------------------------------------------------

-- The best rideable pet (PetDef.Rideable) among an inventory (PlayerData.Pets), or nil. Scans
-- Config.Pets (not the id map) so every def counts. Best = highest Dig.Power, then SandMultiplier.
function Config.FindRideablePet(pets: { [string]: Types.PetInstance }?): Types.PetDef?
	if not pets then
		return nil
	end
	local owned: { [string]: boolean } = {}
	for _, pet in pets :: { [string]: Types.PetInstance } do
		if type(pet) == "table" and type(pet.Id) == "string" then
			owned[pet.Id] = true
		end
	end
	local best: Types.PetDef? = nil
	for _, def in Pets do
		if def.Rideable == true and owned[def.Id] then
			local current = best
			local power = if def.Dig then def.Dig.Power else 0
			local sand = if def.Dig then def.Dig.SandMultiplier else 0
			local bestPower = if current and current.Dig then current.Dig.Power else -1
			local bestSand = if current and current.Dig then current.Dig.SandMultiplier else -1
			if current == nil or power > bestPower or (power == bestPower and sand > bestSand) then
				best = def
			end
		end
	end
	return best
end

-- Survival (v2) ---------------------------------------------------------------------------------

local shadeById, shadeIndex = indexById(Shades, function(d: Types.ShadeDef)
	return d.Id
end)
local consumableById = indexById(Consumables, function(d: Types.ConsumableDef)
	return d.Id
end)

function Config.GetShade(id: string): Types.ShadeDef?
	return shadeById[id]
end

function Config.GetShadeIndex(id: string): number?
	return shadeIndex[id]
end

function Config.GetConsumable(id: string): Types.ConsumableDef?
	return consumableById[id]
end

-- Number of layers whose every treasure is in `index` (collection book completion).
function Config.CountCompletedIndexLayers(index: { [string]: boolean }): number
	local complete = 0
	for _, layer in Layers do
		local all = true
		for _, entry in layer.LootTable do
			if not index[entry.TreasureId] then
				all = false
				break
			end
		end
		if all then
			complete += 1
		end
	end
	return complete
end

-- Status & Social (v2.2) ------------------------------------------------------------------------

-- Nameplate title for a layer index (clamped to 1..#Layers): (title, colour).
function Config.GetTitle(layerIndex: number): (string, Color3)
	local index = math.clamp(math.floor(layerIndex), 1, #Titles)
	local def = Titles[index]
	return def.Title, def.Color or Layers[index].Color
end

-- Server dig goal (sand) for a server whose players have these MaxDepth values. See Config/Social.
function Config.ServerGoalTarget(maxDepths: { number }): number
	local goal = Social.ServerGoal
	local total = 0
	for _, depth in maxDepths do
		local layer = Config.GetLayerAtDepth(depth)
		total += math.max(goal.PerPlayerSand, layer.RewardScale * goal.DigSeconds)
	end
	total = math.max(total, goal.MinSand)
	return math.ceil(total / goal.Round) * goal.Round
end

-- Fresh default save for a brand-new player.
function Config.NewPlayerData(): Types.PlayerData
	local firstShovel = Shovels[1].Id
	local firstBackpack = Backpacks[1].Id
	return {
		Coins = 0,
		Sand = 0,
		TotalSandDug = 0,
		Rebirths = 0,
		RebirthTokens = 0,
		MaxDepth = 0,
		Shovel = firstShovel,
		OwnedShovels = { [firstShovel] = true },
		Backpack = firstBackpack,
		OwnedBackpacks = { [firstBackpack] = true },
		Pets = {},
		PetSlots = Config.MAX_EQUIPPED_PETS,
		Treasures = {},
		Finds = {}, -- v3 discovery
		FindVariants = {}, -- v3 discovery
		Index = {},
		DailyStreak = 0,
		LastDailyClaim = 0,
		Quests = {},
		RedeemedCodes = {},
		Settings = {},
		Boosts = {},
		Consumables = {},
		OwnedShades = {},
		Diggers = {},
		LastOnline = 0,
		Pity = {},
		RebirthPerks = {},
		PlayTime = 0,
		FirstJoin = os.time(),
		Version = Config.DATA_VERSION,
	}
end

-- Sanity checks on require (cheap; catches typos in ids when editing balance data) ----------

do
	for i, layer in Layers do
		assert(layer.DepthEnd > layer.DepthStart, "Config: bad depth band in layer " .. layer.Id)
		if i > 1 then
			assert(layer.DepthStart == Layers[i - 1].DepthEnd, "Config: gap before layer " .. layer.Id)
		end
		for _, entry in layer.LootTable do
			assert(treasureById[entry.TreasureId], "Config: unknown treasure " .. entry.TreasureId)
		end
	end
	for _, egg in Eggs do
		for _, entry in egg.Pets do
			assert(petById[entry.PetId], "Config: unknown pet " .. entry.PetId .. " in egg " .. egg.Id)
		end
		if egg.ProductKey then
			assert(Monetization.Products[egg.ProductKey], "Config: unknown product key " .. egg.ProductKey)
		end
		if egg.PityAt then
			local hasRarePlus = false
			for _, entry in egg.Pets do
				local rarity = rarityByName[petById[entry.PetId].Rarity]
				hasRarePlus = hasRarePlus or rarity.Order >= Config.PITY_MIN_RARITY_ORDER
			end
			assert(egg.PityAt >= 1 and hasRarePlus, "Config: PityAt needs a Rare+ pet in egg " .. egg.Id)
		end
	end
	for _, treasure in Treasures do
		assert(rarityByName[treasure.Rarity], "Config: unknown rarity on " .. treasure.Id)
		assert(not string.find(treasure.Id, "[|/]"), "Config: treasure ids may not contain | or / " .. treasure.Id)
		if treasure.Rarity == "Relic" then
			assert((treasure.ScaledValue or 0) > 0, "Config: Relic without ScaledValue " .. treasure.Id)
		end
	end
	assert(#Discovery.DENSITY == #Layers, "Config: one Discovery.DENSITY per layer")
	for _, group in { Discovery.SIZES, Discovery.MATERIALS } do
		local total = 0
		for _, v in group do
			total += v.Weight
		end
		assert(math.abs(total - 100) < 1e-6, "Config: Discovery variant weights must sum to 100")
	end
	-- v2.3 paid randomness rules (owner decision, docs/CHANGELOG.md v2.3): no Robux item sells
	-- a random outcome or a luck modifier.
	for _, egg in Eggs do
		assert(egg.Currency ~= "Robux" and egg.ProductKey == nil, "Config: eggs are never sold for Robux " .. egg.Id)
	end
	for key, pass in Monetization.GamePasses do
		assert(pass.LuckMultiplier == nil, "Config: no paid luck (pass " .. key .. ")")
	end
	for key, product in Monetization.Products do
		local boostDef: Types.BoostDef? = nil
		for _, b in Boosts do
			if b.Id == product.Grant.Boost then
				boostDef = b
			end
		end
		assert(product.Grant.Egg == nil, "Config: no paid eggs (product " .. key .. ")")
		assert(not (boostDef and boostDef.Kind == "Luck"), "Config: no paid luck (product " .. key .. ")")
	end
	assert(#Titles == #Layers, "Config: one title per layer")
	for i, title in Titles do
		assert(title.LayerId == Layers[i].Id, "Config: title " .. i .. " is not for layer " .. Layers[i].Id)
	end
	for _, pet in Pets do
		local dig = pet.Dig
		if dig then
			assert(dig.Power > 0 and dig.Interval > 0 and dig.Radius > 0, "Config: bad Dig stats on " .. pet.Id)
		end
	end
	for _, egg in Eggs do
		if egg.Kind == "Crate" then
			for _, entry in egg.Pets do
				assert(petById[entry.PetId].Dig, "Config: crate pet without Dig " .. entry.PetId)
			end
		end
	end
end

return Config

```

## src/shared/Config/Layers.luau

Original SHA-256: `45ff3cda82a268ccbf972d8905008a5f8f478b0083777f5dc3e2a8242c4621b0`

```lua
--!strict
--[[
	Layers — the hole, top to bottom. Ordered array; index 1 is the surface.
	Depths are studs below the beach surface. Total depth = 1000 studs ("1,000 m to the Core",
	Config.STUDS_PER_METER = 1).

	Rules:
	- Each layer uses a UNIQUE terrain Material because Terrain:SetMaterialColor is global per
	  material. The map may additionally use Water, Grass, LeafyGrass, Snow, Concrete, Asphalt,
	  Cobblestone for scenery, and Sand only with the Dry Sand colour.
	- Hardness gates progress: equipped shovel Power >= Hardness (see Shovels.luau, 1:1 ladder).
	- SandValue is sand per dig before multipliers; sand sells 1:1 for Coins.
	- RewardScale ~= coins/second a typical (un-rebirthed) player earns here; ScaledCoins rewards
	  are "seconds of income" multiplied by this.
	- TreasureChance is per successful dig; Luck multiplies it (cap 50%) and multiplies the
	  weight of every non-Common entry.
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Layers: { Types.LayerDef } = {
	{
		Id = "dry_sand",
		Name = "Dry Sand",
		DepthStart = 0,
		DepthEnd = 20,
		Material = Enum.Material.Sand,
		Color = rgb(255, 224, 150),
		Hardness = 1,
		SandValue = 1,
		TreasureChance = 0.04,
		LootTable = {
			{ TreasureId = "bottle_cap", Weight = 70 },
			{ TreasureId = "lost_flip_flop", Weight = 22 },
			{ TreasureId = "cool_sunglasses", Weight = 8 },
		},
		RewardScale = 1,
		FlavorText = "Warm, sunny and full of stuff tourists dropped. Every legend starts with a bucket!",
		AmbientColor = rgb(255, 236, 190),
	},
	{
		Id = "wet_sand",
		Name = "Wet Sand",
		DepthStart = 20,
		DepthEnd = 45,
		Material = Enum.Material.Sandstone,
		Color = rgb(214, 172, 112),
		Hardness = 2,
		SandValue = 2,
		TreasureChance = 0.035,
		LootTable = {
			{ TreasureId = "seashell", Weight = 70 },
			{ TreasureId = "sand_dollar", Weight = 22 },
			{ TreasureId = "message_in_a_bottle", Weight = 8 },
		},
		RewardScale = 1.5,
		FlavorText = "Squishy, salty and perfect for sandcastles. The tide hides little gifts down here.",
		AmbientColor = rgb(230, 200, 150),
	},
	{
		Id = "shell_bed",
		Name = "Shell Bed",
		DepthStart = 45,
		DepthEnd = 75,
		Material = Enum.Material.Salt,
		Color = rgb(255, 214, 214),
		Hardness = 4,
		SandValue = 4,
		TreasureChance = 0.035,
		LootTable = {
			{ TreasureId = "conch_shell", Weight = 70 },
			{ TreasureId = "glowing_pearl", Weight = 25 },
			{ TreasureId = "giant_clam", Weight = 5 },
		},
		RewardScale = 3,
		FlavorText = "A million years of seashells packed together. Hold one to your ear... is that the Core humming?",
		AmbientColor = rgb(255, 210, 220),
	},
	{
		Id = "tidal_clay",
		Name = "Tidal Clay",
		DepthStart = 75,
		DepthEnd = 110,
		Material = Enum.Material.Mud,
		Color = rgb(150, 108, 82),
		Hardness = 8,
		SandValue = 8,
		TreasureChance = 0.03,
		LootTable = {
			{ TreasureId = "rusty_anchor", Weight = 70 },
			{ TreasureId = "pocket_watch", Weight = 22 },
			{ TreasureId = "mermaid_comb", Weight = 8 },
		},
		RewardScale = 8,
		FlavorText = "Sticky clay that swallowed whole fishing boats. Something shiny is stuck in it.",
		AmbientColor = rgb(170, 130, 100),
	},
	{
		Id = "pirate_cove",
		Name = "Pirate Cove",
		DepthStart = 110,
		DepthEnd = 150,
		Material = Enum.Material.Ground,
		Color = rgb(122, 86, 56),
		Hardness = 15,
		SandValue = 15,
		TreasureChance = 0.03,
		LootTable = {
			{ TreasureId = "gold_doubloon", Weight = 68 },
			{ TreasureId = "pirate_hook", Weight = 22 },
			{ TreasureId = "treasure_map", Weight = 9 },
			{ TreasureId = "pirate_chest", Weight = 1 },
		},
		RewardScale = 25,
		FlavorText = "Captain Sandbeard buried his loot here 300 years ago. His map says 'X marks... deeper'.",
		AmbientColor = rgb(140, 100, 60),
	},
	{
		Id = "shipwreck",
		Name = "Sunken Shipwreck",
		DepthStart = 150,
		DepthEnd = 200,
		Material = Enum.Material.WoodPlanks,
		Color = rgb(128, 88, 54),
		Hardness = 25,
		SandValue = 30,
		TreasureChance = 0.03,
		LootTable = {
			{ TreasureId = "ships_wheel", Weight = 70 },
			{ TreasureId = "captains_spyglass", Weight = 26 },
			{ TreasureId = "cursed_skull", Weight = 4 },
		},
		RewardScale = 80,
		FlavorText = "The Salty Gull sank into the sand, not the sea. You're digging through its decks.",
		AmbientColor = rgb(110, 80, 55),
	},
	{
		Id = "fossil_bed",
		Name = "Fossil Bed",
		DepthStart = 200,
		DepthEnd = 260,
		Material = Enum.Material.Limestone,
		Color = rgb(228, 212, 176),
		Hardness = 45,
		SandValue = 60,
		TreasureChance = 0.03,
		LootTable = {
			{ TreasureId = "trilobite", Weight = 66 },
			{ TreasureId = "ammonite", Weight = 24 },
			{ TreasureId = "trex_tooth", Weight = 9 },
			{ TreasureId = "dino_skull", Weight = 1 },
		},
		RewardScale = 250,
		FlavorText = "Before the beach there was a jungle. Before the jungle there were DINOSAURS.",
		AmbientColor = rgb(220, 205, 170),
	},
	{
		Id = "bedrock",
		Name = "Bedrock",
		DepthStart = 260,
		DepthEnd = 330,
		Material = Enum.Material.Rock,
		Color = rgb(108, 110, 122),
		Hardness = 80,
		SandValue = 120,
		TreasureChance = 0.025,
		LootTable = {
			{ TreasureId = "geode", Weight = 70 },
			{ TreasureId = "iron_nugget", Weight = 22 },
			{ TreasureId = "ancient_arrowhead", Weight = 8 },
		},
		RewardScale = 450,
		FlavorText = "Solid stone that most diggers never get past. Crack a geode and see what sparkles.",
		AmbientColor = rgb(100, 100, 115),
	},
	{
		Id = "crystal_caverns",
		Name = "Crystal Caverns",
		DepthStart = 330,
		DepthEnd = 410,
		Material = Enum.Material.Glacier,
		Color = rgb(176, 112, 255),
		Hardness = 140,
		SandValue = 250,
		TreasureChance = 0.025,
		LootTable = {
			{ TreasureId = "amethyst", Weight = 66 },
			{ TreasureId = "sapphire", Weight = 24 },
			{ TreasureId = "glow_crystal", Weight = 9 },
			{ TreasureId = "rainbow_diamond", Weight = 1 },
		},
		RewardScale = 1200,
		FlavorText = "Glittering purple caves that glow in the dark. Nobody knows who lit them.",
		AmbientColor = rgb(150, 100, 230),
	},
	{
		Id = "frozen_abyss",
		Name = "Frozen Abyss",
		DepthStart = 410,
		DepthEnd = 495,
		Material = Enum.Material.Ice,
		Color = rgb(160, 226, 255),
		Hardness = 250,
		SandValue = 550,
		TreasureChance = 0.025,
		LootTable = {
			{ TreasureId = "frozen_fish", Weight = 70 },
			{ TreasureId = "mammoth_tusk", Weight = 26 },
			{ TreasureId = "ice_crown", Weight = 4 },
		},
		RewardScale = 4000,
		FlavorText = "An underground ice age! Brr... a woolly mammoth is still frozen in here somewhere.",
		AmbientColor = rgb(170, 225, 255),
	},
	{
		Id = "ancient_ruins",
		Name = "Ancient Ruins",
		DepthStart = 495,
		DepthEnd = 585,
		Material = Enum.Material.Brick,
		Color = rgb(206, 176, 110),
		Hardness = 450,
		SandValue = 1200,
		TreasureChance = 0.025,
		LootTable = {
			{ TreasureId = "stone_tablet", Weight = 66 },
			{ TreasureId = "golden_idol", Weight = 26 },
			{ TreasureId = "sun_mask", Weight = 7 },
			{ TreasureId = "atlantis_crown", Weight = 1 },
		},
		RewardScale = 15000,
		FlavorText = "The lost city of Sandlantis. Its people dug down too... and never came back up.",
		AmbientColor = rgb(200, 170, 110),
	},
	{
		Id = "magma_chamber",
		Name = "Magma Chamber",
		DepthStart = 585,
		DepthEnd = 680,
		Material = Enum.Material.CrackedLava,
		Color = rgb(255, 92, 32),
		Hardness = 800,
		SandValue = 2800,
		TreasureChance = 0.02,
		LootTable = {
			{ TreasureId = "obsidian_shard", Weight = 70 },
			{ TreasureId = "fire_ruby", Weight = 28 },
			{ TreasureId = "dragon_egg", Weight = 2 },
		},
		RewardScale = 60000,
		FlavorText = "Hot hot HOT! Rivers of lava light the way. Don't touch the glowing bits.",
		AmbientColor = rgb(255, 110, 50),
	},
	{
		Id = "obsidian_depths",
		Name = "Obsidian Depths",
		DepthStart = 680,
		DepthEnd = 780,
		Material = Enum.Material.Basalt,
		Color = rgb(52, 40, 72),
		Hardness = 1400,
		SandValue = 6500,
		TreasureChance = 0.02,
		LootTable = {
			{ TreasureId = "shadow_gem", Weight = 70 },
			{ TreasureId = "void_pearl", Weight = 26 },
			{ TreasureId = "dragon_scale", Weight = 4 },
		},
		RewardScale = 250000,
		FlavorText = "Black glass, total silence. Strange footprints lead deeper... they aren't human.",
		AmbientColor = rgb(70, 50, 100),
	},
	{
		Id = "alien_hive",
		Name = "Alien Hive",
		DepthStart = 780,
		DepthEnd = 885,
		Material = Enum.Material.Slate,
		Color = rgb(96, 232, 124),
		Hardness = 2500,
		SandValue = 16000,
		TreasureChance = 0.02,
		LootTable = {
			{ TreasureId = "alien_goo", Weight = 66 },
			{ TreasureId = "ufo_part", Weight = 24 },
			{ TreasureId = "alien_artifact", Weight = 9 },
			{ TreasureId = "alien_egg", Weight = 1 },
		},
		RewardScale = 700000,
		FlavorText = "A crashed spaceship grew into a glowing green hive. The aliens were looking for the Core too.",
		AmbientColor = rgb(110, 240, 140),
	},
	{
		Id = "the_core",
		Name = "The Core",
		DepthStart = 885,
		DepthEnd = 1000,
		Material = Enum.Material.Pavement,
		Color = rgb(255, 200, 60),
		Hardness = 4500,
		SandValue = 40000,
		TreasureChance = 0.02,
		LootTable = {
			{ TreasureId = "core_fragment", Weight = 75 },
			{ TreasureId = "molten_gold", Weight = 22 },
			{ TreasureId = "heart_of_the_earth", Weight = 2.9 },
			{ TreasureId = "beach_ball_of_creation", Weight = 0.1 },
		},
		RewardScale = 1800000,
		FlavorText = "The golden heart of the planet. Legends say the very first beach ball was made here.",
		AmbientColor = rgb(255, 210, 90),
	},
}

return Layers

```

## src/shared/Config/Monetization.luau

Original SHA-256: `c39f69d8b962f5492e11b59cc9d585d9fd478971742d904867a964710b4f3cd4`

```lua
--!strict
--[[
	Monetization — game passes, developer products, Premium perks.

	==========================================================================================
	  OWNER ACTION REQUIRED: every `Id = 0` below is a PLACEHOLDER.
	  1. Publish the experience, then open Creator Hub -> Creations -> (this experience) ->
	     Monetization -> Passes: create one pass per entry in GamePasses (name, icon, price).
	     Monetization -> Developer Products: create one product per entry in Products.
	  2. Copy each numeric id from Creator Hub and paste it into the matching `Id = ...` field.
	  3. Republish. While an Id is 0 the server must treat the pass as NOT owned and the shop
	     must hide / disable the buy button (prompting id 0 errors).
	  Prices are suggestions in Robux; the price set in Creator Hub is what players pay. Once an
	  Id is set, the store reads the live price (MarketplaceService:GetProductInfo, see
	  PurchaseController.GetPrice) and only falls back to `Price` below when that fails.
	  v2.3: suggested prices moved up to the competitor band (comparable passes 175-750 R$).
	  After launch, turn on Roblox Managed Pricing (Creator Hub -> Monetization) for the dev
	  products so Roblox tunes regional prices; passes keep the prices set here.
	==========================================================================================

	Pass effects are expressed as optional multiplier fields so the server can fold them in
	generically. Keys are stable API: server and UI reference passes by key, e.g.
	Config.Monetization.GamePasses.SellAnywhere.
	Design rule: everything a pass gives can be approximated by playing (boosts from quests,
	pets, rebirths). Passes make it faster/comfier, never exclusive power walls.

	v2.2 compliance:
	- PaidRandom = true marks a currency that buys random outcomes (Coins buy eggs and crates;
	  Skip Rebirth grants Rebirth Tokens, which buy the Rebirth and Golden Eggs). Players whose
	  PolicyService:GetPolicyInfoForPlayerAsync says ArePaidRandomItemsRestricted never see them
	  and the server refuses to prompt them (Services/PolicyService). Completed purchases are
	  always honoured. Every random outcome shows its true odds incl. luck (Stats.GetHatchOdds).
	- The Cooler Pack product was removed: it sold relief from heat friction we designed.

	v2.3 paid randomness simplification (owner decision):
	- No Robux item buys a random outcome or a luck modifier any more. Removed: the Golden Egg and
	  3 Golden Eggs products (the Golden Egg now costs Rebirth Tokens, Config/Eggs), the 2x Luck
	  (15 min) product and the Lucky Shovel pass. VIP lost its +25% luck and gained +10% sell
	  coins (CoinMultiplier) instead. Turbo Shovel (+25% dig speed) takes the Lucky pass's slot.
	- Luck stays earnable for free: Luck events, the Lucky Digger perk, 2x Luck from quests,
	  daily rewards and codes. Config's require-time checks reject any pass with LuckMultiplier,
	  any product that grants luck or an egg, and any egg sold for Robux.
	- Paid random items now exist only indirectly: coin packs and Skip Rebirth buy currency
	  that can buy eggs, so they stay PaidRandom (hidden for policy-restricted players).
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Monetization: Types.MonetizationConfig = {
	GamePasses = {
		VIP = {
			Id = 2018534367,
			Name = "VIP",
			Price = 349,
			-- v2.3: the +25% luck was removed (luck sold for Robux is a paid probability modifier);
			-- +10% sell coins replaces it. "2 shades" = Heat.ShadeSlotsVip (SurvivalShades).
			Description = "+25% sand, +10% coins when you sell, place 2 shades at once and a gold VIP tag on your nameplate.",
			Color = rgb(255, 200, 40),
			SandMultiplier = 1.25,
			CoinMultiplier = 1.1,
		},
		DoubleSand = {
			Id = 2019326377,
			Name = "2x Sand",
			Price = 399,
			Description = "Double sand from every single dig. Forever!",
			Color = rgb(255, 170, 40),
			SandMultiplier = 2,
		},
		SellAnywhere = {
			Id = 2019386387,
			Name = "Sell Anywhere",
			Price = 249,
			-- v2.2: also earnable for free with the Sell Anywhere rebirth perk (Config.RebirthPerks)
			Description = "Sell your sand from anywhere with one tap - even at the bottom of the hole. Get it now, or unlock it for free later with Rebirth Perks!",
			Color = rgb(60, 200, 110),
		},
		AutoDig = {
			Id = 2017796369,
			Name = "Auto Dig",
			Price = 299,
			Description = "+1 Pet slot & auto-swing: your character keeps digging by itself.",
			Color = rgb(60, 170, 255),
			ExtraPetSlots = 1, -- v2.1: was +1 digger slot (diggers are pets now)
		},
		-- v2.3: replaces the Lucky Shovel pass (removed: paid luck). Deterministic speed only.
		FastDig = {
			Id = 2019320389,
			Name = "Turbo Shovel",
			Price = 249,
			Description = "Dig 25% faster with every shovel. Forever!",
			Color = rgb(60, 190, 255),
			SpeedMultiplier = 1.25,
		},
		TripleHatch = {
			Id = 2019608364,
			Name = "Triple Hatch",
			Price = 249,
			Description = "Hatch 3 eggs at once.",
			Color = rgb(255, 120, 200),
		},
		ExtraPets = {
			Id = 2018012384,
			Name = "+2 Pet Slots",
			Price = 349,
			Description = "Equip 2 more pets at the same time.",
			Color = rgb(180, 100, 255),
			ExtraPetSlots = 2,
		},
		MegaBackpack = {
			Id = 2017934384,
			Name = "Mega Backpack",
			Price = 299,
			Description = "2x backpack capacity on every backpack. Fewer trips, more digging!",
			Color = rgb(255, 120, 60),
			CapacityMultiplier = 2,
		},
	},

	Products = {
		CoinsSmall = {
			Id = 3717251713,
			Name = "Pile of Coins",
			Price = 49,
			Description = "5 minutes worth of coins at your deepest layer.",
			Grant = { ScaledCoins = 300, Coins = 500 },
			PaidRandom = true,
		},
		CoinsMedium = {
			Id = 3717251822,
			Name = "Bag of Coins",
			Price = 149,
			Description = "25 minutes worth of coins at your deepest layer.",
			Grant = { ScaledCoins = 1500, Coins = 2500 },
			PaidRandom = true,
		},
		CoinsLarge = {
			Id = 3717251873,
			Name = "Chest of Coins",
			Price = 399,
			Description = "2 hours worth of coins at your deepest layer.",
			Grant = { ScaledCoins = 7200, Coins = 12000 },
			PaidRandom = true,
		},
		CoinsHuge = {
			Id = 3717251948,
			Name = "Sunken Ship of Coins",
			Price = 999,
			Description = "6 hours worth of coins at your deepest layer!",
			Grant = { ScaledCoins = 21600, Coins = 40000 },
			PaidRandom = true,
		},
		SandBoost15 = {
			Id = 3717252005,
			Name = "2x Sand (15 min)",
			Price = 49,
			Description = "Double sand for 15 minutes. Stacks time.",
			Grant = { Boost = "SandBoost", BoostSeconds = 900 },
		},
		SkipRebirth = {
			Id = 3717252052,
			Name = "Skip Rebirth",
			Price = 199,
			Description = "Rebirth right now without paying the coin cost.",
			Grant = { Rebirth = true },
			PaidRandom = true,
		},
	},

	-- Roblox Premium: payouts are driven by Premium members' engagement time, so we give them a
	-- small, visible thank-you (no paywall). Server listens to Players.PlayerMembershipChanged.
	Premium = {
		SandMultiplier = 1.1,
		DailyRewardMultiplier = 1.5,
		ChatTag = "[PREMIUM]",
	},
}

return Monetization

```

## src/shared/Config/Pets.luau

Original SHA-256: `57c3c5e990b3e96adf0e23610dc5cfbc15725d4c3cea128a62e58e91ff515f5b`

```lua
--!strict
--[[
	Pets — follow you and multiply sand. Bonuses combine ADDITIVELY:
	total = 1 + sum(Multiplier - 1) over equipped pets (Config.PetMultiplier).
	So three 1.5x pets = 2.5x, not 3.375x. Keeps late game from exploding.
	Exclusive pets are not in any egg (daily streak / codes / events).

	v2.1 companions (docs/design/Companions.md):
	- Dig = Types.PetDigDef: the pet also digs its own spot on a ring around the owner
	  (Services/PetDigService). Power gates layers like a shovel, SandMultiplier replaces the
	  shovel factor for that dig (every other multiplier still applies), Interval = seconds per dig.
	  Each digging pet makes ~8-20% of the active sand/second of the shovel with the same Power, so
	  even 6 slots of the best diggers stay under active shovel digging.
	- Vehicle pets (VehicleKind = a Models/Diggers builder) hatch from Construction Crates
	  (Config/Eggs.luau, Kind = "Crate"). Their sand Multiplier is smaller than creature pets of
	  the same tier: you trade multiplier for digging.
	- Rideable = true: the player can ride it (Ride agent, Services/RideService).
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Pets: { Types.PetDef } = {
	{
		Id = "sandy_crab",
		Name = "Sandy Crab",
		Rarity = "Common",
		Multiplier = 1.05,
		Dig = { Power = 4, Interval = 4, Radius = 2, SandMultiplier = 1 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 110, 80),
			AccentColor = rgb(255, 220, 180),
			Shape = "Crab",
			Size = 1,
			Glow = false,
		},
	},
	{
		Id = "seagull",
		Name = "Seagull",
		Rarity = "Common",
		Multiplier = 1.08,
		Exclusive = false,
		Look = {
			BodyColor = rgb(250, 250, 250),
			AccentColor = rgb(255, 190, 40),
			Shape = "Bird",
			Size = 1,
			Glow = false,
		},
	},
	{
		Id = "starfish",
		Name = "Starfish",
		Rarity = "Uncommon",
		Multiplier = 1.12,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 150, 60),
			AccentColor = rgb(255, 230, 120),
			Shape = "Star",
			Size = 1,
			Glow = false,
		},
	},
	{
		Id = "baby_turtle",
		Name = "Baby Turtle",
		Rarity = "Rare",
		Multiplier = 1.2,
		Exclusive = false,
		Look = {
			BodyColor = rgb(110, 200, 90),
			AccentColor = rgb(190, 140, 80),
			Shape = "Turtle",
			Size = 0.9,
			Glow = false,
		},
	},
	{
		Id = "golden_crab",
		Name = "Golden Crab",
		Rarity = "Legendary",
		Multiplier = 1.5,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 210, 40),
			AccentColor = rgb(255, 255, 200),
			Shape = "Crab",
			Size = 1.2,
			Glow = true,
		},
	},
	{
		Id = "clownfish",
		Name = "Clownfish",
		Rarity = "Common",
		Multiplier = 1.15,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 130, 30),
			AccentColor = rgb(255, 255, 255),
			Shape = "Fish",
			Size = 1,
			Glow = false,
		},
	},
	{
		Id = "pufferfish",
		Name = "Pufferfish",
		Rarity = "Uncommon",
		Multiplier = 1.22,
		Exclusive = false,
		Look = {
			BodyColor = rgb(250, 220, 100),
			AccentColor = rgb(120, 90, 60),
			Shape = "Blob",
			Size = 1,
			Glow = false,
		},
	},
	{
		Id = "octopus",
		Name = "Octopus",
		Rarity = "Rare",
		Multiplier = 1.3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(240, 90, 170),
			AccentColor = rgb(255, 200, 230),
			Shape = "Squid",
			Size = 1.1,
			Glow = false,
		},
	},
	{
		Id = "sea_turtle",
		Name = "Sea Turtle",
		Rarity = "Epic",
		Multiplier = 1.45,
		Exclusive = false,
		Look = {
			BodyColor = rgb(40, 170, 140),
			AccentColor = rgb(220, 190, 120),
			Shape = "Turtle",
			Size = 1.2,
			Glow = false,
		},
	},
	{
		Id = "rainbow_starfish",
		Name = "Rainbow Starfish",
		Rarity = "Legendary",
		Multiplier = 1.8,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 90, 200),
			AccentColor = rgb(90, 220, 255),
			Shape = "Star",
			Size = 1.3,
			Glow = true,
		},
	},
	{
		Id = "parrot",
		Name = "Pirate Parrot",
		Rarity = "Common",
		Multiplier = 1.3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(230, 40, 40),
			AccentColor = rgb(40, 120, 255),
			Shape = "Bird",
			Size = 1,
			Glow = false,
		},
	},
	{
		Id = "pirate_crab",
		Name = "Pirate Crab",
		Rarity = "Uncommon",
		Multiplier = 1.4,
		Dig = { Power = 25, Interval = 3.5, Radius = 2.2, SandMultiplier = 3 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(200, 50, 40),
			AccentColor = rgb(30, 30, 30),
			Shape = "Crab",
			Size = 1.1,
			Glow = false,
		},
	},
	{
		Id = "ghost_blob",
		Name = "Ghost Blob",
		Rarity = "Rare",
		Multiplier = 1.55,
		Exclusive = false,
		Look = {
			BodyColor = rgb(200, 255, 230),
			AccentColor = rgb(120, 220, 200),
			Shape = "Blob",
			Size = 1.1,
			Glow = true,
		},
	},
	{
		Id = "skeleton_shark",
		Name = "Skeleton Shark",
		Rarity = "Epic",
		Multiplier = 1.75,
		Exclusive = false,
		Look = {
			BodyColor = rgb(240, 235, 220),
			AccentColor = rgb(80, 80, 90),
			Shape = "Fish",
			Size = 1.3,
			Glow = false,
		},
	},
	{
		Id = "kraken",
		Name = "Kraken",
		Rarity = "Legendary",
		Multiplier = 2.3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(120, 40, 160),
			AccentColor = rgb(255, 120, 200),
			Shape = "Squid",
			Size = 1.5,
			Glow = true,
		},
	},
	{
		Id = "mole",
		Name = "Mole",
		Rarity = "Common",
		Multiplier = 1.5,
		Dig = { Power = 45, Interval = 3, Radius = 2.2, SandMultiplier = 4.2 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(110, 80, 70),
			AccentColor = rgb(255, 170, 180),
			Shape = "Mole",
			Size = 1,
			Glow = false,
		},
	},
	{
		Id = "baby_raptor",
		Name = "Baby Raptor",
		Rarity = "Uncommon",
		Multiplier = 1.7,
		Exclusive = false,
		Look = {
			BodyColor = rgb(120, 180, 80),
			AccentColor = rgb(230, 200, 120),
			Shape = "Dino",
			Size = 1,
			Glow = false,
		},
	},
	{
		Id = "stegosaurus",
		Name = "Stegosaurus",
		Rarity = "Rare",
		Multiplier = 1.9,
		Exclusive = false,
		Look = {
			BodyColor = rgb(90, 150, 200),
			AccentColor = rgb(255, 140, 60),
			Shape = "Dino",
			Size = 1.2,
			Glow = false,
		},
	},
	{
		Id = "trex",
		Name = "T-Rex",
		Rarity = "Epic",
		Multiplier = 2.2,
		Dig = { Power = 80, Interval = 2.8, Radius = 2.4, SandMultiplier = 7.2 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(70, 140, 70),
			AccentColor = rgb(250, 240, 220),
			Shape = "Dino",
			Size = 1.4,
			Glow = false,
		},
	},
	{
		Id = "bone_dragon",
		Name = "Bone Dragon",
		Rarity = "Legendary",
		Multiplier = 3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(245, 240, 225),
			AccentColor = rgb(120, 255, 180),
			Shape = "Dragon",
			Size = 1.5,
			Glow = true,
		},
	},
	{
		Id = "crystal_bat",
		Name = "Crystal Bat",
		Rarity = "Common",
		Multiplier = 1.8,
		Exclusive = false,
		Look = {
			BodyColor = rgb(120, 70, 200),
			AccentColor = rgb(220, 170, 255),
			Shape = "Bird",
			Size = 1,
			Glow = false,
		},
	},
	{
		Id = "gem_blob",
		Name = "Gem Blob",
		Rarity = "Uncommon",
		Multiplier = 2.1,
		Exclusive = false,
		Look = {
			BodyColor = rgb(80, 200, 255),
			AccentColor = rgb(255, 255, 255),
			Shape = "Blob",
			Size = 1,
			Glow = true,
		},
	},
	{
		Id = "crystal_golem",
		Name = "Crystal Golem",
		Rarity = "Rare",
		Multiplier = 2.5,
		Dig = { Power = 140, Interval = 3, Radius = 2.4, SandMultiplier = 12 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(180, 110, 255),
			AccentColor = rgb(240, 220, 255),
			Shape = "Golem",
			Size = 1.3,
			Glow = true,
		},
	},
	{
		Id = "frost_seal",
		Name = "Frost Seal",
		Rarity = "Epic",
		Multiplier = 3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(200, 240, 255),
			AccentColor = rgb(80, 160, 255),
			Shape = "Seal",
			Size = 1.2,
			Glow = true,
		},
	},
	{
		Id = "diamond_dragon",
		Name = "Diamond Dragon",
		Rarity = "Legendary",
		Multiplier = 4,
		Exclusive = false,
		Look = {
			BodyColor = rgb(200, 250, 255),
			AccentColor = rgb(150, 120, 255),
			Shape = "Dragon",
			Size = 1.5,
			Glow = true,
		},
	},
	{
		Id = "lava_salamander",
		Name = "Lava Salamander",
		Rarity = "Common",
		Multiplier = 2.5,
		Dig = { Power = 800, Interval = 3, Radius = 2.4, SandMultiplier = 34 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 110, 30),
			AccentColor = rgb(60, 30, 30),
			Shape = "Dino",
			Size = 1,
			Glow = true,
		},
	},
	{
		Id = "magma_golem",
		Name = "Magma Golem",
		Rarity = "Uncommon",
		Multiplier = 3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(100, 65, 60),
			AccentColor = rgb(255, 120, 30),
			Shape = "Golem",
			Size = 1.3,
			Glow = true,
		},
	},
	{
		Id = "fire_bird",
		Name = "Fire Bird",
		Rarity = "Rare",
		Multiplier = 3.5,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 80, 30),
			AccentColor = rgb(255, 220, 60),
			Shape = "Bird",
			Size = 1.1,
			Glow = true,
		},
	},
	{
		Id = "lava_kraken",
		Name = "Lava Kraken",
		Rarity = "Epic",
		Multiplier = 4.5,
		Exclusive = false,
		Look = {
			BodyColor = rgb(200, 40, 20),
			AccentColor = rgb(255, 200, 40),
			Shape = "Squid",
			Size = 1.4,
			Glow = true,
		},
	},
	{
		Id = "phoenix",
		Name = "Phoenix",
		Rarity = "Legendary",
		Multiplier = 6,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 170, 30),
			AccentColor = rgb(255, 60, 40),
			Shape = "Bird",
			Size = 1.5,
			Glow = true,
		},
	},
	{
		Id = "core_dragon",
		Name = "Core Dragon",
		Rarity = "Mythic",
		Multiplier = 10,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 210, 60),
			AccentColor = rgb(255, 90, 20),
			Shape = "Dragon",
			Size = 1.6,
			Glow = true,
		},
	},
	{
		Id = "alien_blob",
		Name = "Alien Blob",
		Rarity = "Common",
		Multiplier = 3.5,
		Exclusive = false,
		Look = {
			BodyColor = rgb(110, 255, 120),
			AccentColor = rgb(40, 120, 60),
			Shape = "Blob",
			Size = 1,
			Glow = true,
		},
	},
	{
		Id = "cosmic_turtle",
		Name = "Cosmic Turtle",
		Rarity = "Rare",
		Multiplier = 5,
		Exclusive = false,
		Look = {
			BodyColor = rgb(60, 40, 140),
			AccentColor = rgb(150, 220, 255),
			Shape = "Turtle",
			Size = 1.3,
			Glow = true,
		},
	},
	{
		Id = "star_golem",
		Name = "Star Golem",
		Rarity = "Epic",
		Multiplier = 7,
		Dig = { Power = 2500, Interval = 2.8, Radius = 2.6, SandMultiplier = 104 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(65, 65, 110),
			AccentColor = rgb(255, 240, 120),
			Shape = "Golem",
			Size = 1.4,
			Glow = true,
		},
	},
	{
		Id = "galaxy_dragon",
		Name = "Galaxy Dragon",
		Rarity = "Mythic",
		Multiplier = 15,
		Exclusive = false,
		Look = {
			BodyColor = rgb(90, 40, 200),
			AccentColor = rgb(255, 120, 255),
			Shape = "Dragon",
			Size = 1.6,
			Glow = true,
		},
	},
	{
		Id = "tide_spirit",
		Name = "Tide Spirit",
		Rarity = "Rare",
		Multiplier = 1.6,
		Exclusive = false,
		Look = {
			BodyColor = rgb(120, 220, 255),
			AccentColor = rgb(255, 255, 255),
			Shape = "Blob",
			Size = 1.1,
			Glow = true,
		},
	},
	{
		Id = "rebirth_phoenix",
		Name = "Rebirth Phoenix",
		Rarity = "Epic",
		Multiplier = 2,
		Exclusive = false,
		Look = {
			BodyColor = rgb(120, 255, 200),
			AccentColor = rgb(255, 255, 140),
			Shape = "Bird",
			Size = 1.3,
			Glow = true,
		},
	},
	{
		Id = "sandlantis_guardian",
		Name = "Sandlantis Guardian",
		Rarity = "Legendary",
		Multiplier = 3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(230, 190, 100),
			AccentColor = rgb(60, 200, 200),
			Shape = "Golem",
			Size = 1.5,
			Glow = true,
		},
	},
	{
		Id = "golden_seagull",
		Name = "Golden Seagull",
		Rarity = "Epic",
		Multiplier = 1.8,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 215, 60),
			AccentColor = rgb(255, 255, 255),
			Shape = "Bird",
			Size = 1.2,
			Glow = true,
		},
	},
	{
		Id = "golden_turtle",
		Name = "Golden Turtle",
		Rarity = "Legendary",
		Multiplier = 2.6,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 200, 40),
			AccentColor = rgb(255, 240, 170),
			Shape = "Turtle",
			Size = 1.4,
			Glow = true,
		},
	},
	{
		Id = "sun_dragon",
		Name = "Sun Dragon",
		Rarity = "Mythic",
		Multiplier = 4.5,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 180, 30),
			AccentColor = rgb(255, 255, 180),
			Shape = "Dragon",
			Size = 1.6,
			Glow = true,
		},
	},
	{
		Id = "sunny_seal",
		Name = "Sunny Seal",
		Rarity = "Epic",
		Multiplier = 1.5,
		Exclusive = true,
		Look = {
			BodyColor = rgb(250, 250, 255),
			AccentColor = rgb(255, 190, 60),
			Shape = "Seal",
			Size = 1.1,
			Glow = false,
		},
	},
	{
		Id = "launch_crab",
		Name = "Launch Party Crab",
		Rarity = "Rare",
		Multiplier = 1.25,
		Exclusive = true,
		Look = {
			BodyColor = rgb(60, 200, 255),
			AccentColor = rgb(255, 230, 60),
			Shape = "Crab",
			Size = 1,
			Glow = true,
		},
	},

	-- v2.1 vehicle pets (Construction Crates). Dig % = share of the same-Power shovel's active
	-- sand/second (see docs/design/Companions.md). Ex-Garage diggers keep their ids (save migration).
	{
		Id = "toy_truck",
		Name = "Toy Sand Truck",
		Rarity = "Common",
		Multiplier = 1.05,
		Exclusive = false,
		VehicleKind = "ToyTruck",
		Dig = { Power = 15, Interval = 3, Radius = 2.2, SandMultiplier = 2.25 },
		Look = {
			BodyColor = rgb(255, 210, 50),
			AccentColor = rgb(240, 70, 70),
			Shape = "Vehicle",
			Size = 0.95,
			Glow = false,
		},
	},
	{
		Id = "dump_truck",
		Name = "Little Dump Truck",
		Rarity = "Uncommon",
		Multiplier = 1.08,
		Exclusive = false,
		VehicleKind = "DumpTruck",
		Dig = { Power = 25, Interval = 2.8, Radius = 2.2, SandMultiplier = 3.6 },
		Look = {
			BodyColor = rgb(255, 150, 40),
			AccentColor = rgb(70, 80, 95),
			Shape = "Vehicle",
			Size = 0.85,
			Glow = false,
		},
	},
	{
		Id = "mini_excavator",
		Name = "Mini Excavator",
		Rarity = "Rare",
		Multiplier = 1.12,
		Exclusive = false,
		VehicleKind = "Excavator",
		Dig = { Power = 45, Interval = 2.6, Radius = 2.4, SandMultiplier = 6.4 },
		Look = {
			BodyColor = rgb(255, 200, 30),
			AccentColor = rgb(55, 55, 65),
			Shape = "Vehicle",
			Size = 0.85,
			Glow = false,
		},
	},
	{
		Id = "skid_steer",
		Name = "Skid Steer",
		Rarity = "Common",
		Multiplier = 1.15,
		Exclusive = false,
		VehicleKind = "SkidSteer",
		Dig = { Power = 80, Interval = 2.4, Radius = 2.4, SandMultiplier = 6.2 },
		Look = {
			BodyColor = rgb(80, 200, 90),
			AccentColor = rgb(45, 50, 60),
			Shape = "Vehicle",
			Size = 0.85,
			Glow = false,
		},
	},
	{
		Id = "bulldozer",
		Name = "Bulldozer",
		Rarity = "Uncommon",
		Multiplier = 1.2,
		Exclusive = false,
		VehicleKind = "Bulldozer",
		Dig = { Power = 140, Interval = 2.3, Radius = 2.6, SandMultiplier = 10.8 },
		Look = {
			BodyColor = rgb(255, 185, 20),
			AccentColor = rgb(60, 60, 70),
			Shape = "Vehicle",
			Size = 0.8,
			Glow = false,
		},
	},
	{
		Id = "backhoe",
		Name = "Backhoe Loader",
		Rarity = "Rare",
		Multiplier = 1.3,
		Exclusive = false,
		VehicleKind = "Backhoe",
		Dig = { Power = 250, Interval = 2.2, Radius = 2.6, SandMultiplier = 18.5 },
		Look = {
			BodyColor = rgb(90, 170, 255),
			AccentColor = rgb(40, 60, 110),
			Shape = "Vehicle",
			Size = 0.8,
			Glow = false,
		},
	},
	{
		Id = "drill_rig",
		Name = "Drill Rig",
		Rarity = "Common",
		Multiplier = 1.4,
		Exclusive = false,
		VehicleKind = "DrillRig",
		Dig = { Power = 450, Interval = 2, Radius = 2.8, SandMultiplier = 18 },
		Look = {
			BodyColor = rgb(230, 60, 60),
			AccentColor = rgb(200, 205, 215),
			Shape = "Vehicle",
			Size = 0.8,
			Glow = false,
		},
	},
	{
		Id = "mining_drill",
		Name = "Mining Cart Drill",
		Rarity = "Uncommon",
		Multiplier = 1.55,
		Exclusive = false,
		VehicleKind = "MiningDrill",
		Dig = { Power = 800, Interval = 1.9, Radius = 2.8, SandMultiplier = 32 },
		Look = {
			BodyColor = rgb(150, 100, 60),
			AccentColor = rgb(255, 120, 30),
			Shape = "Vehicle",
			Size = 0.8,
			Glow = false,
		},
	},
	{
		Id = "tunnel_borer",
		Name = "Tunnel Borer",
		Rarity = "Rare",
		Multiplier = 1.75,
		Exclusive = false,
		VehicleKind = "TunnelBorer",
		Dig = { Power = 1400, Interval = 1.8, Radius = 2.8, SandMultiplier = 56 },
		Look = {
			BodyColor = rgb(120, 70, 200),
			AccentColor = rgb(60, 40, 90),
			Shape = "Vehicle",
			Size = 0.75,
			Glow = true,
		},
	},
	{
		Id = "mole_machine",
		Name = "Mole Machine",
		Rarity = "Common",
		Multiplier = 2,
		Exclusive = false,
		VehicleKind = "Mole",
		Dig = { Power = 2500, Interval = 1.7, Radius = 2.8, SandMultiplier = 63 },
		Look = {
			BodyColor = rgb(140, 110, 95),
			AccentColor = rgb(90, 255, 140),
			Shape = "Vehicle",
			Size = 0.75,
			Glow = true,
		},
	},
	{
		Id = "lava_drill",
		Name = "Lava Drill",
		Rarity = "Rare",
		Multiplier = 2.4,
		Exclusive = false,
		VehicleKind = "LavaDrill",
		Dig = { Power = 2500, Interval = 1.6, Radius = 2.8, SandMultiplier = 77 },
		Look = {
			BodyColor = rgb(50, 35, 35),
			AccentColor = rgb(255, 100, 20),
			Shape = "Vehicle",
			Size = 0.75,
			Glow = true,
		},
	},
	{
		Id = "core_driller",
		Name = "Core Driller",
		Rarity = "Legendary",
		Multiplier = 3,
		Exclusive = false,
		VehicleKind = "CoreDriller",
		Dig = { Power = 4500, Interval = 1.5, Radius = 3.2, SandMultiplier = 140 },
		Look = {
			BodyColor = rgb(255, 210, 60),
			AccentColor = rgb(255, 120, 40),
			Shape = "Vehicle",
			Size = 0.75,
			Glow = true,
		},
	},
	{
		Id = "mega_excavator",
		Name = "Mega Excavator",
		Rarity = "Mythic",
		Multiplier = 4,
		Exclusive = false,
		VehicleKind = "Excavator",
		Dig = { Power = 4500, Interval = 1.4, Radius = 3.6, SandMultiplier = 140 },
		Rideable = true,
		Look = {
			BodyColor = rgb(255, 190, 20),
			AccentColor = rgb(255, 90, 160),
			Shape = "Vehicle",
			Size = 1.25,
			Glow = true,
		},
	},
}

return Pets

```

## src/shared/Config/Quests.luau

Original SHA-256: `1f939191ac12234c557fe0c53608c472bca1d5dd6aec7b1a2b4463f746f3953a`

```lua
--!strict
--[[
	Quests — Daily quests reset at 00:00 UTC (QuestProgress.Day != today -> reset progress/claim).
	Once quests are milestones (claim once, ever).
	Rewards use ScaledCoins ("seconds of income" x RewardScale of the player's deepest layer) so
	they stay worth it at every stage. Resolve with Config.ResolveCoins(reward, data.MaxDepth).
	Progress hooks (server): Dig -> DigTimes; Sell -> SellTimes; treasure -> FindTreasures /
	FindRarity (Rarity or rarer); hatch -> HatchEggs (+count); every minute -> PlayMinutes;
	shovel/backpack purchase -> BuyUpgrade; MaxDepth -> ReachDepth (set Progress = MaxDepth);
	rebirth -> Rebirth.
]]

local Types = require(script.Parent.Parent.Types)

local Quests: { Types.QuestDef } = {
	-- Daily ---------------------------------------------------------------------------------
	{
		Id = "daily_dig_100",
		Name = "Busy Beaver",
		Description = "Dig 100 times",
		Kind = "DigTimes",
		Target = 100,
		Reset = "Daily",
		Reward = { ScaledCoins = 60 },
	},
	{
		Id = "daily_dig_1000",
		Name = "Dig Machine",
		Description = "Dig 1,000 times",
		Kind = "DigTimes",
		Target = 1000,
		Reset = "Daily",
		Reward = { ScaledCoins = 240, Boost = "SandBoost", BoostSeconds = 600 },
	},
	{
		Id = "daily_sell_10",
		Name = "Sand Salesman",
		Description = "Sell your sand 10 times",
		Kind = "SellTimes",
		Target = 10,
		Reset = "Daily",
		Reward = { ScaledCoins = 120 },
	},
	{
		Id = "daily_treasure_10",
		Name = "Treasure Hunter",
		Description = "Find 10 treasures",
		Kind = "FindTreasures",
		Target = 10,
		Reset = "Daily",
		Reward = { ScaledCoins = 120, Boost = "LuckBoost", BoostSeconds = 600 },
	},
	{
		Id = "daily_rare_1",
		Name = "Lucky Find",
		Description = "Find a Rare (or better) treasure",
		Kind = "FindRarity",
		Target = 1,
		Rarity = "Rare",
		Reset = "Daily",
		Reward = { ScaledCoins = 180 },
	},
	{
		Id = "daily_hatch_5",
		Name = "Egg-cellent",
		Description = "Hatch 5 eggs",
		Kind = "HatchEggs",
		Target = 5,
		Reset = "Daily",
		Reward = { ScaledCoins = 150 },
	},
	{
		Id = "daily_play_20",
		Name = "Beach Day",
		Description = "Play for 20 minutes",
		Kind = "PlayMinutes",
		Target = 20,
		Reset = "Daily",
		Reward = { ScaledCoins = 120, Boost = "CoinBoost", BoostSeconds = 600 },
	},
	-- Milestones ----------------------------------------------------------------------------
	{
		Id = "reach_pirate_cove",
		Name = "Yo Ho Ho!",
		Description = "Reach the Pirate Cove (110m)",
		Kind = "ReachDepth",
		Target = 110,
		Reset = "Once",
		Reward = { Coins = 1500 },
	},
	{
		Id = "reach_fossil_bed",
		Name = "Jurassic Beach",
		Description = "Reach the Fossil Bed (200m)",
		Kind = "ReachDepth",
		Target = 200,
		Reset = "Once",
		Reward = { Coins = 25000, Egg = "beach_egg", EggCount = 3 },
	},
	{
		Id = "reach_crystal_caverns",
		Name = "Shiny!",
		Description = "Reach the Crystal Caverns (330m)",
		Kind = "ReachDepth",
		Target = 330,
		Reset = "Once",
		Reward = { Coins = 250000, Boost = "LuckBoost", BoostSeconds = 900 },
	},
	{
		Id = "first_rebirth",
		Name = "Born Again Digger",
		Description = "Rebirth for the first time",
		Kind = "Rebirth",
		Target = 1,
		Reset = "Once",
		Reward = { RebirthTokens = 2 },
	},
	{
		Id = "reach_the_core",
		Name = "Journey to the Center",
		Description = "Reach THE CORE (885m)",
		Kind = "ReachDepth",
		Target = 885,
		Reset = "Once",
		Reward = { RebirthTokens = 10, ScaledCoins = 1800 },
	},
}

return Quests

```

## src/shared/Config/Rarities.luau

Original SHA-256: `e360cb3f646a1e3b515ad2a59c01826a89c84008c217db89231ab372db9a6f96`

```lua
--!strict
--[[
	Rarities — display data for treasure & pet rarities. Ordered array (Order 1..7; 7 = Relic, v3 finds only) plus the
	lookup helper Config.GetRarity(name). Gradient is meant for a UIGradient on rarity cards.
	Announce = broadcast a server-wide toast/chat message when anyone finds or hatches one.
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Rarities: { Types.RarityDef } = {
	{
		Name = "Common",
		Order = 1,
		Color = rgb(200, 205, 215),
		Gradient = { rgb(230, 232, 238), rgb(170, 176, 190) },
		Announce = false,
	},
	{
		Name = "Uncommon",
		Order = 2,
		Color = rgb(90, 220, 100),
		Gradient = { rgb(150, 255, 150), rgb(40, 180, 80) },
		Announce = false,
	},
	{
		Name = "Rare",
		Order = 3,
		Color = rgb(60, 160, 255),
		Gradient = { rgb(120, 210, 255), rgb(30, 100, 240) },
		Announce = false,
	},
	{
		Name = "Epic",
		Order = 4,
		Color = rgb(180, 90, 255),
		Gradient = { rgb(220, 150, 255), rgb(130, 50, 230) },
		Announce = false,
	},
	{
		Name = "Legendary",
		Order = 5,
		Color = rgb(255, 190, 30),
		Gradient = { rgb(255, 235, 100), rgb(255, 130, 20) },
		Announce = true,
	},
	{
		Name = "Mythic",
		Order = 6,
		Color = rgb(255, 70, 140),
		Gradient = { rgb(255, 90, 90), rgb(255, 210, 60), rgb(90, 220, 255), rgb(200, 90, 255) },
		Announce = true,
	},
	-- v3 discovery slice: above Mythic, only from buried finds (Config.Discovery.RELIC_CHANCE).
	{
		Name = "Relic",
		Order = 7,
		Color = rgb(120, 255, 230),
		Gradient = { rgb(255, 255, 255), rgb(120, 255, 230), rgb(255, 120, 230), rgb(255, 230, 120) },
		Announce = true,
	},
}

return Rarities

```

## src/shared/Config/RebirthPerks.luau

Original SHA-256: `e0ec198da96f6693f68cde005f5bbfb7d720751ccba4a419675b85a3737580ad`

```lua
--!strict
--[[
	RebirthPerks — permanent upgrades bought with Rebirth Tokens (docs/design/Rebirth.md).

	PlayerData.RebirthPerks = { [perkId] = level } (missing = level 0). Perks are never reset.
	Costs[i] = tokens for level i, so #Costs is the max level. Effect values per level live in
	`Levels` (index = level, 0 = not bought) so the UI can show "current -> next".

	Tuned against Config.Rebirths.Tokens (2, 2, 3, 3, 4, 4, 5 ... tokens per rebirth): the first
	rebirth (2 tokens) buys two level-1 perks (e.g. Head Start + Golden Touch); Sell Anywhere (5) is
	the big mid-term goal, reached around rebirth 3 (tools/sim/economy.luau: it is a ~3x speed-up).
	The Rebirth Egg (3 tokens) competes for the same tokens on purpose: a real choice each time.

	Effects (where they are applied):
	  HeadStart     start each rebirth with shovel Shovels[ShovelIndex] + Coins  (RebirthService)
	  KeepBackpack  keep your backpack on rebirth, up to Backpacks[KeepIndex]     (RebirthService)
	  SellAnywhere  same as the Sell Anywhere game pass                             (EconomyService)
	  DeepPockets   +x backpack capacity                                            (Stats.GetCapacity)
	  LuckyDigger   x treasure chance per dig (NOT egg luck: egg odds stay as shown) (Stats.GetTreasureChance)
	  LongNap       +hours offline cap and +offline efficiency                      (OfflineService)
	  PetDen        +pet equip slots                                                (Stats.GetPetSlots)
	  GoldenTouch   +x coins from selling (and offline earnings)                    (Stats.GetCoinFactors)
]]

export type PerkId =
	"HeadStart"
	| "KeepBackpack"
	| "SellAnywhere"
	| "DeepPockets"
	| "LuckyDigger"
	| "LongNap"
	| "PetDen"
	| "GoldenTouch"

export type PerkLevel = {
	ShovelIndex: number?, -- HeadStart
	Coins: number?, -- HeadStart
	KeepIndex: number?, -- KeepBackpack: highest backpack index kept
	Unlocked: boolean?, -- SellAnywhere
	Capacity: number?, -- DeepPockets: capacity factor
	TreasureChance: number?, -- LuckyDigger: treasure chance factor
	OfflineHours: number?, -- LongNap: extra cap hours
	OfflineEfficiency: number?, -- LongNap: extra efficiency (0..1)
	PetSlots: number?, -- PetDen
	Coin: number?, -- GoldenTouch: sell factor
}

export type PerkDef = {
	Id: PerkId,
	Name: string,
	Icon: string, -- AtlasIcon key ("atlas_name|emoji")
	Description: string,
	Costs: { number }, -- tokens for level 1, 2, ...
	Levels: { PerkLevel }, -- effect at level 1, 2, ... (same length as Costs)
	Order: number,
}

local Perks: { PerkDef } = {
	{
		Id = "SellAnywhere",
		Name = "Sell Anywhere",
		Icon = "sell|💸",
		Description = "Sell from anywhere with one tap, like the game pass.",
		Costs = { 5 },
		Levels = { { Unlocked = true } },
		Order = 1,
	},
	{
		Id = "HeadStart",
		Name = "Head Start",
		Icon = "shovel|⛏️",
		Description = "Start every rebirth with a better shovel and some coins.",
		Costs = { 1, 2, 3, 5, 8 },
		Levels = {
			{ ShovelIndex = 4, Coins = 500 }, -- Lifeguard Shovel
			{ ShovelIndex = 5, Coins = 5_000 }, -- Pirate Shovel
			{ ShovelIndex = 6, Coins = 25_000 }, -- Bone Claw
			{ ShovelIndex = 7, Coins = 100_000 }, -- Steel Pickaxe
			{ ShovelIndex = 8, Coins = 400_000 }, -- Crystal Spade
		},
		Order = 2,
	},
	{
		Id = "GoldenTouch",
		Name = "Golden Touch",
		Icon = "boost_coins|💰",
		Description = "More coins every time you sell.",
		Costs = { 1, 2, 3, 4, 5 },
		Levels = { { Coin = 1.1 }, { Coin = 1.2 }, { Coin = 1.3 }, { Coin = 1.4 }, { Coin = 1.5 } },
		Order = 3,
	},
	{
		Id = "KeepBackpack",
		Name = "Keep Backpack",
		Icon = "backpack|🎒",
		Description = "Keep your backpack when you rebirth.",
		Costs = { 1, 3, 6 },
		Levels = {
			{ KeepIndex = 5 }, -- up to Treasure Sack
			{ KeepIndex = 8 }, -- up to Wheelbarrow
			{ KeepIndex = 99 }, -- any backpack
		},
		Order = 4,
	},
	{
		Id = "DeepPockets",
		Name = "Deep Pockets",
		Icon = "sand|⏳",
		Description = "Your backpack holds more sand.",
		Costs = { 1, 1, 2, 3, 4 },
		Levels = {
			{ Capacity = 1.1 },
			{ Capacity = 1.2 },
			{ Capacity = 1.3 },
			{ Capacity = 1.4 },
			{ Capacity = 1.5 },
		},
		Order = 5,
	},
	{
		Id = "LuckyDigger",
		Name = "Lucky Digger",
		Icon = "boost_luck|🍀",
		Description = "Find treasure more often while digging.",
		Costs = { 1, 2, 2, 3, 4 },
		Levels = {
			{ TreasureChance = 1.1 },
			{ TreasureChance = 1.2 },
			{ TreasureChance = 1.3 },
			{ TreasureChance = 1.4 },
			{ TreasureChance = 1.5 },
		},
		Order = 6,
	},
	{
		Id = "LongNap",
		Name = "Long Nap",
		Icon = "hourglass|⏳",
		Description = "Your pets dig longer and harder while you are away.",
		Costs = { 1, 2, 3, 4 },
		Levels = {
			{ OfflineHours = 1, OfflineEfficiency = 0.1 },
			{ OfflineHours = 2, OfflineEfficiency = 0.2 },
			{ OfflineHours = 3, OfflineEfficiency = 0.3 },
			{ OfflineHours = 4, OfflineEfficiency = 0.4 },
		},
		Order = 7,
	},
	{
		Id = "PetDen",
		Name = "Pet Den",
		Icon = "pets|🐾",
		Description = "+1 pet slot.",
		Costs = { 3, 6 },
		Levels = { { PetSlots = 1 }, { PetSlots = 2 } },
		Order = 8,
	},
}

local byId: { [string]: PerkDef } = {}
for _, perk in Perks do
	assert(byId[perk.Id] == nil, "RebirthPerks: duplicate id " .. perk.Id)
	assert(#perk.Costs == #perk.Levels, "RebirthPerks: Costs/Levels length mismatch on " .. perk.Id)
	byId[perk.Id] = perk
end
table.sort(Perks, function(a: PerkDef, b: PerkDef): boolean
	return a.Order < b.Order
end)

local RebirthPerks = {
	List = Perks,
	-- Offline earnings (OfflineService): base values before Long Nap.
	OFFLINE_MIN_SECONDS = 5 * 60, -- shorter absences grant nothing
	OFFLINE_CAP_HOURS = 2,
	OFFLINE_EFFICIENCY = 0.4, -- pets dig at 40% without their owner around
	OFFLINE_MAX_GAP_SECONDS = 365 * 86400, -- larger gaps are treated as a broken clock: ignored
}

function RebirthPerks.Get(id: string): PerkDef?
	return byId[id]
end

function RebirthPerks.MaxLevel(id: string): number
	local def = byId[id]
	return if def then #def.Costs else 0
end

-- Level of a perk in a RebirthPerks table (tolerates nil / junk from old saves). Clamped.
function RebirthPerks.Level(perks: { [string]: number }?, id: string): number
	if type(perks) ~= "table" then
		return 0
	end
	local value = (perks :: any)[id]
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, RebirthPerks.MaxLevel(id))
end

-- Token cost of the NEXT level, or nil when maxed / unknown.
function RebirthPerks.NextCost(perks: { [string]: number }?, id: string): number?
	local def = byId[id]
	if not def then
		return nil
	end
	return def.Costs[RebirthPerks.Level(perks, id) + 1]
end

-- Effect table at the current level (empty table at level 0).
function RebirthPerks.Effect(perks: { [string]: number }?, id: string): PerkLevel
	local def = byId[id]
	local level = RebirthPerks.Level(perks, id)
	if not def or level == 0 then
		return {}
	end
	return def.Levels[level]
end

-- Convenience accessors used by Stats / services / UI ------------------------------------------

function RebirthPerks.CapacityFactor(perks: { [string]: number }?): number
	return RebirthPerks.Effect(perks, "DeepPockets").Capacity or 1
end

function RebirthPerks.TreasureFactor(perks: { [string]: number }?): number
	return RebirthPerks.Effect(perks, "LuckyDigger").TreasureChance or 1
end

function RebirthPerks.CoinFactor(perks: { [string]: number }?): number
	return RebirthPerks.Effect(perks, "GoldenTouch").Coin or 1
end

function RebirthPerks.ExtraPetSlots(perks: { [string]: number }?): number
	return RebirthPerks.Effect(perks, "PetDen").PetSlots or 0
end

function RebirthPerks.HasSellAnywhere(perks: { [string]: number }?): boolean
	return RebirthPerks.Effect(perks, "SellAnywhere").Unlocked == true
end

function RebirthPerks.OfflineCapSeconds(perks: { [string]: number }?): number
	return (RebirthPerks.OFFLINE_CAP_HOURS + (RebirthPerks.Effect(perks, "LongNap").OfflineHours or 0)) * 3600
end

function RebirthPerks.OfflineEfficiency(perks: { [string]: number }?): number
	return RebirthPerks.OFFLINE_EFFICIENCY + (RebirthPerks.Effect(perks, "LongNap").OfflineEfficiency or 0)
end

-- Total tokens spent (for UI / analytics).
function RebirthPerks.Spent(perks: { [string]: number }?): number
	local total = 0
	for _, def in Perks do
		for i = 1, RebirthPerks.Level(perks, def.Id) do
			total += def.Costs[i]
		end
	end
	return total
end

return RebirthPerks

```

## src/shared/Config/Rebirths.luau

Original SHA-256: `7de0a9ab47f4fee63a49dde8d4cccade8505bf6034e9ee443eaa3ad8a0dbfc78`

```lua
--!strict
--[[
	Rebirths — reset for a permanent multiplier.

	Cost(n)       = coins for the NEXT rebirth (n = rebirths already done), rounded to 2
	                significant digits. v2.2: the first rebirths are cheaper (first rebirth ~35 min
	                instead of ~56-70) and climb faster, rejoining the old 4M x 3.3^n curve at
	                n = EARLY_REBIRTHS, so the late game (Core Breaker at 10 rebirths) is unchanged:
	                  n < 4 : BaseCost * EARLY_GROWTH^n      500K, 2.8M, 15M, 85M  (EARLY_GROWTH ~5.55)
	                  n >= 4: Cost(4) * CostGrowth^(n - 4)   470M, 1.6B, 5.2B, 17B, 56B, 190B ...
	                (tools/sim/economy.luau simulates it; docs/design/Rebirth.md has the numbers.)
	Multiplier(n) = 1 + MultiplierPerRebirth * n   (applies to sand per dig AND backpack capacity)
	Tokens(n)     = BaseTokens + floor(n / 2)      (tokens for the NEXT rebirth: 2, 2, 3, 3, 4 ...;
	                spent on Rebirth Perks (Config/RebirthPerks.luau) and the Rebirth Egg)

	Resets: Coins, Sand, Shovel/OwnedShovels (back to toy shovel), Backpack/OwnedBackpacks (back to
	bucket), unsold Treasures. MaxDepth is kept as a record (your hole is refilled anyway when you
	rebirth: the server teleports you to the surface; the tide refills old holes).
	Perks (RebirthService): Head Start gives a better starting shovel + coins, Keep Backpack keeps
	the backpack. RebirthPerks are never reset.
]]

local Types = require(script.Parent.Parent.Types)

local function roundSig(x: number, digits: number): number
	if x <= 0 then
		return 0
	end
	local magnitude = 10 ^ (math.floor(math.log10(x)) - digits + 1)
	return math.floor(x / magnitude + 0.5) * magnitude
end

local BASE_COST = 500_000
local EARLY_REBIRTHS = 4
local COST_GROWTH = 3.3
local LATE_BASE = 4_000_000 -- the pre-v2.2 curve (4M x 3.3^n) that rebirth 5+ still follows
local EARLY_GROWTH = (LATE_BASE * COST_GROWTH ^ EARLY_REBIRTHS / BASE_COST) ^ (1 / EARLY_REBIRTHS)
local MULTIPLIER_PER_REBIRTH = 0.5
local BASE_TOKENS = 2

local Rebirths: Types.RebirthConfig = {
	BaseCost = BASE_COST,
	CostGrowth = COST_GROWTH,
	MultiplierPerRebirth = MULTIPLIER_PER_REBIRTH,
	BaseTokens = BASE_TOKENS,
	Resets = { "Coins", "Sand", "Shovel", "OwnedShovels", "Backpack", "OwnedBackpacks", "Treasures", "Finds" },
	Keeps = {
		"Rebirths",
		"RebirthTokens",
		"MaxDepth",
		"TotalSandDug",
		"Pets",
		"PetSlots",
		"Index",
		"FindVariants",
		"DailyStreak",
		"LastDailyClaim",
		"Quests",
		"RedeemedCodes",
		"Settings",
		"Boosts",
		"PlayTime",
		"FirstJoin",
		"RebirthPerks",
		"LastOnline",
	},
	Cost = function(rebirths: number): number
		local n = math.max(rebirths, 0)
		local early = math.min(n, EARLY_REBIRTHS)
		return roundSig(BASE_COST * EARLY_GROWTH ^ early * COST_GROWTH ^ (n - early), 2)
	end,
	Multiplier = function(rebirths: number): number
		return 1 + MULTIPLIER_PER_REBIRTH * math.max(rebirths, 0)
	end,
	Tokens = function(rebirths: number): number
		return BASE_TOKENS + math.floor(math.max(rebirths, 0) / 2)
	end,
}

return Rebirths

```

## src/shared/Config/Ride.luau

Original SHA-256: `d335f6127322b3ef741fb81ef87eae83957a6b29b56d2d4f33d35952046eb466`

```lua
--!strict
--[[
	Ride — tuning for the ride-on excavator (v2.1, Ride agent). A player who owns a pet with
	PetDef.Rideable = true can press Ride (V / DPadUp / the Ride button) to spawn a full-size
	vehicle (Models/Rides.luau), sit in it, drive it around the beach and dig big chunks in front
	of it. Server: Services/RideService.luau. Client: Controllers/RideController.luau,
	UI/RideButton.luau. Physics and hole handling: see the RideService header.

	All distances in studs, speeds in studs/s, angles in radians. Expect to tune in Studio.
]]

local Ride = {
	-- Driving (client, applied through AlignPosition / AlignOrientation on the rider's machine)
	MaxSpeed = 18, -- forward top speed
	ReverseFactor = 0.6, -- reverse top speed = MaxSpeed * this
	Acceleration = 26, -- studs/s^2 towards the target speed (also braking)
	TurnRate = 1.6, -- yaw rate at full stick (~92 degrees/s)
	HoverHeight = 0.15, -- pivot (bottom of the tracks) above the ground under the tracks
	Responsiveness = 35, -- AlignPosition / AlignOrientation responsiveness
	ForceGravities = 6, -- AlignPosition MaxForce = assembly weight x this (enough to climb the deck)

	-- Area: the dig zone plus the boardwalk. The vehicle centre is clamped to
	-- x in [zone min + EdgeMargin, zone max - EdgeMargin], z in [zone sea edge + EdgeMargin, InlandMaxZ].
	EdgeMargin = 7,
	InlandMaxZ = 4, -- boardwalk deck is z -4..12; the vehicle's back stays on the deck
	SpawnMaxDistance = 40, -- the player must be this close to the ride area to call the vehicle
	-- Ground (mirrors World/Layout: BOARDWALK_Z0 = -4, DECK_TOP = SURFACE_Y + 3). On the sand the
	-- tracks follow the terrain (raycast) but never sink below SURFACE_Y: holes are bridged.
	DeckSeaEdgeZ = -4,
	DeckTop = 3, -- above Config.SURFACE_Y (visible sand + 1)
	TrackSamples = { -- model-space (x, z) points under the tracks sampled for the ground height
		Vector2.new(-3.5, -5.5),
		Vector2.new(3.5, -5.5),
		Vector2.new(-3.5, 5.5),
		Vector2.new(3.5, 5.5),
		Vector2.new(0, 0),
	},

	-- Digging
	DigAhead = 11, -- studs in front of the vehicle pivot where the bucket scoops
	MaxDigDepth = 40, -- the bucket only reaches this far below the surface (drive on to dig more)
	MinRadius = 6, -- dig radius at least this (12-stud cube, like a top shovel)
	IntervalLeniency = 0.85, -- server accepts RideDig after Dig.Interval * this (latency slack)

	-- Server anti-cheat (position checks every ValidateInterval seconds)
	ValidateInterval = 0.5,
	SpeedTolerance = 1.6, -- allowed horizontal speed = MaxSpeed * this + SpeedSlack
	SpeedSlack = 8,
	MinY = -6, -- relative to Config.SURFACE_Y (the vehicle never drives into holes)
	MaxY = 14,
	MaxStrikes = 3, -- resets in a row before the vehicle is despawned
	SeatTimeout = 3, -- despawn when the rider was never seated after this many seconds
}

return Ride

```

## src/shared/Config/Shades.luau

Original SHA-256: `c2e1ad473345b953fbc37b5e9857a253ea8a42a5c01db67aa0221e4520365884`

```lua
--!strict
--[[
	Shades — placeable shade items (owner: Survival), ordered by price. Bought once with coins
	(PlayerData.OwnedShades), placed on the beach sand, cools ANYONE standing under it.

	Radius  = horizontal studs of shade around the pole.
	Cooling = multiplier on Config.Heat.ShadeFallPerSecond (3/s): 1 -> 100..40 heat in 20 s.
	Height  = studs from the ground to the underside of the canopy (models are built to match).
	Prices sit next to the shovel ladder (GDD §4): the umbrella is the first "extra" purchase
	(~3-5 min, after the trowel / pail / spade); each tier costs ~7-10x the last.
	Look.Style picks the model builder in Models/Shades.luau.
]]
local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Shades: { Types.ShadeDef } = {
	{
		Id = "beach_umbrella",
		Name = "Beach Umbrella",
		Price = 120,
		Radius = 6,
		Cooling = 1,
		Height = 7.5,
		Description = "A trusty umbrella. Shade for you and a friend.",
		Look = { Style = "Umbrella", Color = rgb(255, 80, 90), Accent = rgb(255, 255, 255) },
	},
	{
		Id = "striped_umbrella",
		Name = "Striped Umbrella",
		Price = 1200,
		Radius = 8,
		Cooling = 1.4,
		Height = 8,
		Description = "Extra-wide rainbow stripes. Cools faster!",
		Look = { Style = "Striped", Color = rgb(40, 170, 255), Accent = rgb(255, 225, 60) },
	},
	{
		Id = "palm_tarp",
		Name = "Palm Tarp",
		Price = 12000,
		Radius = 10,
		Cooling = 1.8,
		Height = 8.5,
		Description = "A big tarp tied between palm-wood poles. Room for the squad.",
		Look = { Style = "Tarp", Color = rgb(255, 150, 40), Accent = rgb(176, 120, 72) },
	},
	{
		Id = "party_canopy",
		Name = "Party Canopy",
		Price = 100000,
		Radius = 12,
		Cooling = 2.3,
		Height = 9,
		Description = "A pop-up party tent with bunting. Very cool. Literally.",
		Look = { Style = "Canopy", Color = rgb(90, 210, 120), Accent = rgb(255, 255, 255) },
	},
	{
		Id = "tiki_cabana",
		Name = "Tiki Cabana",
		Price = 750000,
		Radius = 14,
		Cooling = 2.8,
		Height = 9,
		Description = "A thatched tiki hut with curtains. Island vibes.",
		Look = { Style = "Cabana", Color = rgb(225, 190, 110), Accent = rgb(255, 120, 150) },
	},
	{
		Id = "luxury_tent",
		Name = "Luxury Beach Tent",
		Price = 6000000,
		RebirthsRequired = 1,
		Radius = 17,
		Cooling = 3.5,
		Height = 9.5,
		Description = "Silk walls and gold poles. Requires 1 Rebirth.",
		Look = { Style = "Tent", Color = rgb(250, 245, 235), Accent = rgb(255, 200, 40) },
	},
	{
		Id = "royal_pavilion",
		Name = "Royal Sand Pavilion",
		Price = 80000000,
		RebirthsRequired = 3,
		Radius = 21,
		Cooling = 4.5,
		Height = 10,
		Description = "Fit for the King of Sandlantis. Shade for the whole beach! Requires 3 Rebirths.",
		Look = { Style = "Pavilion", Color = rgb(150, 90, 255), Accent = rgb(255, 205, 40) },
	},
}

return Shades

```

## src/shared/Config/Shovels.luau

Original SHA-256: `948350c4fc51962c91c1763da7247f9e0ae645d073c9241d9f46c5400d442890`

```lua
--!strict
--[[
	Shovels — ordered by price. Shovel N+1 always unlocks the next layer (Power == that layer's
	Hardness), so depth == progress. The starter Hand Spade (Power 2) digs Dry + Wet Sand.
	Cooldown 0.5s -> 0.12s, SandMultiplier 1x -> 75x.
	Radius = half the edge of the voxel-aligned cube a dig removes (DigService rounds the edge
	Radius * 2 to whole 4-stud voxels): 2-2.8 -> 4x4x4 (starters), 3.2-4.4 -> 8x8x8,
	5-6.6 -> 12x12x12, 7.2-8 -> 16x16x16 (Core Breaker).
	Late shovels need rebirths so rebirthing is the only way to reach the Core.
	Look.Size: the first two tiers (Hand Spade, Garden Trowel) are small one-handed hand tools
	("Hand"); from the Metal Spade on every shovel is a full-size tool held with both hands.
	Balance sheet: docs/GDD.md "Economy sanity check".
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Shovels: { Types.ShovelDef } = {
	{
		Id = "toy_shovel", -- id kept from v1 ("Plastic Toy Shovel") so saves keep working
		Name = "Hand Spade",
		Price = 0,
		Power = 2,
		Cooldown = 0.5,
		Radius = 2,
		SandMultiplier = 1,
		RebirthsRequired = 0,
		Description = "A little plastic beach spade. Everyone starts somewhere! Digs Dry and Wet Sand.",
		Look = {
			HeadColor = rgb(255, 70, 70),
			HandleColor = rgb(255, 210, 50),
			HeadShape = "Scoop",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
			Size = "Hand",
		},
	},
	{
		Id = "garden_trowel",
		Name = "Garden Trowel",
		Price = 30,
		Power = 4,
		Cooldown = 0.46,
		Radius = 2.2,
		SandMultiplier = 1.5,
		RebirthsRequired = 0,
		Description = "Borrowed from Grandma's garden. Breaks into the Shell Bed!",
		Look = {
			HeadColor = rgb(190, 195, 205),
			HandleColor = rgb(70, 200, 90),
			HeadShape = "Trowel",
			Material = Enum.Material.Metal,
			Glow = false,
			Size = "Hand",
		},
	},
	{
		Id = "metal_spade",
		Name = "Metal Spade",
		Price = 150,
		Power = 8,
		Cooldown = 0.43,
		Radius = 2.5,
		SandMultiplier = 2,
		RebirthsRequired = 0,
		Description = "A real grown-up shovel. Cuts through sticky Tidal Clay.",
		Look = {
			HeadColor = rgb(170, 175, 185),
			HandleColor = rgb(140, 95, 55),
			HeadShape = "Spade",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	},
	{
		Id = "lifeguard_shovel",
		Name = "Lifeguard Shovel",
		Price = 600,
		Power = 15,
		Cooldown = 0.4,
		Radius = 2.8,
		SandMultiplier = 3,
		RebirthsRequired = 0,
		Description = "Red, white and ready for rescue digs. Reaches Pirate Cove.",
		Look = {
			HeadColor = rgb(235, 40, 40),
			HandleColor = rgb(255, 255, 255),
			HeadShape = "Spade",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	},
	{
		Id = "pirate_shovel",
		Name = "Pirate Shovel",
		Price = 2500,
		Power = 25,
		Cooldown = 0.37,
		Radius = 3.2,
		SandMultiplier = 4,
		RebirthsRequired = 0,
		Description = "Captain Sandbeard's own. Smashes through shipwreck planks.",
		Look = {
			HeadColor = rgb(255, 200, 40),
			HandleColor = rgb(90, 55, 30),
			HeadShape = "Spade",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	},
	{
		Id = "bone_claw",
		Name = "Bone Claw",
		Price = 9000,
		Power = 45,
		Cooldown = 0.34,
		Radius = 3.5,
		SandMultiplier = 6,
		RebirthsRequired = 0,
		Description = "Made from a raptor claw. Perfect for fossil hunting.",
		Look = {
			HeadColor = rgb(245, 238, 215),
			HandleColor = rgb(160, 120, 80),
			HeadShape = "Claw",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	},
	{
		Id = "steel_pickaxe",
		Name = "Steel Pickaxe",
		Price = 35000,
		Power = 80,
		Cooldown = 0.31,
		Radius = 3.8,
		SandMultiplier = 8,
		RebirthsRequired = 0,
		Description = "Miner-grade steel. Cracks Bedrock like a cookie.",
		Look = {
			HeadColor = rgb(165, 180, 195),
			HandleColor = rgb(60, 60, 70),
			HeadShape = "Pick",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	},
	{
		Id = "crystal_spade",
		Name = "Crystal Spade",
		Price = 140000,
		Power = 140,
		Cooldown = 0.28,
		Radius = 4.4,
		SandMultiplier = 11,
		RebirthsRequired = 0,
		Description = "Carved from a single giant amethyst. Opens the Crystal Caverns.",
		Look = {
			HeadColor = rgb(180, 110, 255),
			HandleColor = rgb(240, 220, 255),
			HeadShape = "Spade",
			Material = Enum.Material.Glass,
			Glow = true,
		},
	},
	{
		Id = "frostbite_pick",
		Name = "Frostbite Pick",
		Price = 600000,
		Power = 250,
		Cooldown = 0.25,
		Radius = 5,
		SandMultiplier = 15,
		RebirthsRequired = 0,
		Description = "So cold it freezes the ice before it breaks it.",
		Look = {
			HeadColor = rgb(150, 230, 255),
			HandleColor = rgb(40, 90, 160),
			HeadShape = "Pick",
			Material = Enum.Material.Ice,
			Glow = true,
		},
	},
	{
		Id = "ancient_trident",
		Name = "Ancient Trident",
		Price = 2500000,
		Power = 450,
		Cooldown = 0.22,
		Radius = 5.5,
		SandMultiplier = 20,
		RebirthsRequired = 1,
		Description = "The royal digging fork of Sandlantis. Requires 1 Rebirth.",
		Look = {
			HeadColor = rgb(255, 205, 60),
			HandleColor = rgb(30, 160, 170),
			HeadShape = "Trident",
			Material = Enum.Material.Metal,
			Glow = true,
		},
	},
	{
		Id = "magma_pick",
		Name = "Magma Pick",
		Price = 12000000,
		Power = 800,
		Cooldown = 0.2,
		Radius = 6,
		SandMultiplier = 28,
		RebirthsRequired = 2,
		Description = "Forged in lava, cooled in a dragon's sneeze. Requires 2 Rebirths.",
		Look = {
			HeadColor = rgb(255, 90, 20),
			HandleColor = rgb(50, 30, 30),
			HeadShape = "Pick",
			Material = Enum.Material.CrackedLava,
			Glow = true,
		},
	},
	{
		Id = "obsidian_drill",
		Name = "Obsidian Drill",
		Price = 60000000,
		Power = 1400,
		Cooldown = 0.17,
		Radius = 6.6,
		SandMultiplier = 38,
		RebirthsRequired = 4,
		Description = "A spinning drill of black volcanic glass. Requires 4 Rebirths.",
		Look = {
			HeadColor = rgb(60, 40, 90),
			HandleColor = rgb(180, 70, 255),
			HeadShape = "Drill",
			Material = Enum.Material.Glass,
			Glow = true,
		},
	},
	{
		Id = "plasma_drill",
		Name = "Plasma Drill",
		Price = 350000000,
		Power = 2500,
		Cooldown = 0.14,
		Radius = 7.2,
		SandMultiplier = 52,
		RebirthsRequired = 6,
		Description = "Alien tech that melts through anything. Requires 6 Rebirths.",
		Look = {
			HeadColor = rgb(90, 255, 140),
			HandleColor = rgb(200, 210, 220),
			HeadShape = "Drill",
			Material = Enum.Material.Neon,
			Glow = true,
		},
	},
	{
		Id = "core_breaker",
		Name = "Core Breaker",
		Price = 2500000000,
		Power = 4500,
		Cooldown = 0.12,
		Radius = 8,
		SandMultiplier = 75,
		RebirthsRequired = 10,
		Description = "The legendary shovel that can touch the Core. Requires 10 Rebirths.",
		Look = {
			HeadColor = rgb(255, 215, 70),
			HandleColor = rgb(255, 120, 40),
			HeadShape = "Claw",
			Material = Enum.Material.Neon,
			Glow = true,
		},
	},
}

return Shovels

```

## src/shared/Config/Social.luau

Original SHA-256: `c47c3301d817da7fa9daa4bc0048376391a3704abc9a68cdc470a611cbcef051`

```lua
--!strict
--[[
	Social — tuning for status & social features (v2.2, Status & Social agent):
	nameplates, rare-find announcements, leaderboard scopes and the server dig goal.
	Read-only at runtime.
]]

export type SocialConfig = {
	Nameplate: {
		MaxDistance: number, -- studs; BillboardGui.MaxDistance
		StarsInline: number, -- up to this many rebirths show as "★★★", above it "★x12"
	},
	Announce: {
		Duration: number, -- seconds each banner stays on screen
		Gap: number, -- seconds between two banners (rate limit)
		MaxQueued: number, -- older queued announcements are dropped beyond this
	},
	Leaderboard: {
		CycleSeconds: number, -- each board flips scope this often
		WeeklyPrefix: { Coins: string, Depth: string }, -- + "_W<ISO year>_<ISO week>"
		WriteBackoffMax: number, -- seconds; a failing store is skipped for up to this long
	},
	-- Goal = round_up(max(MinSand, sum over players of max(PerPlayerSand,
	--        RewardScale(layer at the player's MaxDepth) * DigSeconds)), Round).
	-- So it grows with the player count AND with how deep the server is (a late-game digger
	-- earns ~1000x more sand per dig than a beginner, so a flat number would be trivial or
	-- impossible). Recomputed while counting; progress never resets mid-round.
	ServerGoal: {
		MinSand: number,
		PerPlayerSand: number, -- a beginner's share (~10-15 min of Dry/Wet Sand digging)
		DigSeconds: number, -- seconds of "typical" income at each player's deepest layer
		Round: number, -- goal is rounded up to a multiple of this
		EventId: string, -- event started early for everyone when the goal is reached
		EventSeconds: number, -- how long that event runs
		CooldownSeconds: number, -- after the event ends, wait this long before counting again
	},
}

local Social: SocialConfig = {
	Nameplate = {
		MaxDistance = 60,
		StarsInline = 5,
	},
	Announce = {
		Duration = 4,
		Gap = 0.6,
		MaxQueued = 4,
	},
	Leaderboard = {
		CycleSeconds = 10,
		WeeklyPrefix = { Coins = "Leaderboard_Sand", Depth = "Leaderboard_Depth" },
		WriteBackoffMax = 600,
	},
	ServerGoal = {
		MinSand = 5000,
		PerPlayerSand = 3000,
		DigSeconds = 480,
		Round = 1000,
		EventId = "GoldenHour",
		EventSeconds = 5 * 60,
		CooldownSeconds = 60,
	},
}

return Social

```

## src/shared/Config/Sounds.luau

Original SHA-256: `2479f427acb5bbb1a10d4698fce088833f2adc4c727ac2b1f7ecf2e01647135c`

```lua
--!strict
--[[
	Sounds — SOUND_IDS. Only `rbxasset://` built-ins (shipped with every Roblox client) are used;
	"" means "not set yet": skip playing it. To upgrade, upload or pick licensed audio from the
	Creator Store and paste "rbxassetid://<id>" here. Never paste ids we don't have rights to.
	Built-ins below exist in the client content folder; verify by ear in Studio.
	(swoosh.wav was removed: Studio reports it "not approved for the requester".)
]]

local Types = require(script.Parent.Parent.Types)

local function sound(id: string, volume: number, speed: number?, looped: boolean?): Types.SoundDef
	return {
		Id = id,
		Volume = volume,
		PlaybackSpeed = speed or 1,
		Looped = looped or false,
	}
end

local Sounds: { [string]: Types.SoundDef } = {
	Dig = sound("rbxasset://sounds/action_footsteps_plastic.mp3", 0.6, 0.8),
	DigBlocked = sound("rbxasset://sounds/clickfast.wav", 0.5, 0.6),
	Sell = sound("rbxasset://sounds/electronicpingshort.wav", 0.7, 1.2),
	Coin = sound("rbxasset://sounds/electronicpingshort.wav", 0.5, 1.6),
	Treasure = sound("rbxasset://sounds/electronicpingshort.wav", 0.8, 0.9),
	RareTreasure = sound("rbxasset://sounds/electronicpingshort.wav", 1, 0.7),
	Purchase = sound("rbxasset://sounds/electronicpingshort.wav", 0.8, 1.4),
	Error = sound("rbxasset://sounds/clickfast.wav", 0.6, 0.5),
	Click = sound("rbxasset://sounds/clickfast.wav", 0.5, 1),
	Whoosh = sound("rbxasset://sounds/action_jump.mp3", 0.5, 1.2),
	EggShake = sound("rbxasset://sounds/clickfast.wav", 0.5, 0.8),
	Hatch = sound("rbxasset://sounds/electronicpingshort.wav", 0.8, 0.8),
	NewLayer = sound("rbxasset://sounds/electronicpingshort.wav", 0.9, 0.6),
	Rebirth = sound("rbxasset://sounds/electronicpingshort.wav", 1, 0.5),
	Splash = sound("rbxasset://sounds/impact_water.mp3", 0.7, 1),
	Teleport = sound("rbxasset://sounds/action_jump.mp3", 0.6, 1.4),
	-- v3 discovery (detector beep, excavation taps, find stings)
	DetectorBeep = sound("rbxasset://sounds/electronicpingshort.wav", 0.35, 2.2),
	ExcavateHit = sound("rbxasset://sounds/clickfast.wav", 0.7, 1.3),
	ExcavatePerfect = sound("rbxasset://sounds/electronicpingshort.wav", 0.7, 1.8),
	FindEmerge = sound("rbxasset://sounds/action_footsteps_plastic.mp3", 0.9, 0.55),
	-- Placeholders: paste licensed rbxassetid:// ids (music is not shipped as a built-in).
	MusicBeach = sound("", 0.3, 1, true),
	MusicDeep = sound("", 0.3, 1, true),
	Ambience = sound("", 0.25, 1, true),
}

return Sounds

```

## src/shared/Config/Theme.luau

Original SHA-256: `1a3e106a77704a3107beab41d7b757d7d31b8ed93362a4fdf8c84908d8f915dc`

```lua
--!strict
--[[
	Theme — v3 "chunky simulator" palette in beach colours (docs/UI_STYLE.md, binding).
	- Outlines everywhere: Stroke (#1b1b24) 3-4 px on panels/buttons, 2-3 px on text.
	- Panels: ocean-navy body (Navy -> NavyDark) with one saturated header bar; inner cards are
	  NavyCard with a dark outline. Cream Panel/PanelAlt stay for world boards (server) only.
	- Text colour carries meaning: Money green for coins, Time sky-blue for boosts/timers, Gold
	  for rare, white for neutral.
	World boards (server) share Sand..Gold/Purple/Panel/Text/Stroke, so keep those stable.
	Mobile-first: every tappable button >= MinTouchSize design px (44 real px at UI scale 0.6).
	Fonts: FredokaOne for titles/buttons/big numbers, GothamBlack for small numbers, Gotham body.
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Theme: Types.ThemeDef = {
	Colors = {
		Sand = rgb(255, 222, 140),
		SandDark = rgb(222, 176, 92),
		Ocean = rgb(40, 190, 245),
		OceanDark = rgb(20, 110, 200),
		Sky = rgb(150, 225, 255),
		Sunset = rgb(255, 140, 60),
		Coral = rgb(255, 95, 125),
		Palm = rgb(70, 210, 120),
		Gold = rgb(255, 205, 40),
		Purple = rgb(170, 100, 255),
		Panel = rgb(255, 248, 230),
		PanelAlt = rgb(255, 236, 196),
		Text = rgb(255, 255, 255),
		TextDark = rgb(45, 40, 70),
		Stroke = rgb(27, 27, 36),
		Success = rgb(70, 210, 90),
		Danger = rgb(235, 60, 70),
		Warning = rgb(255, 190, 40),
		Disabled = rgb(140, 145, 160),
		Coins = rgb(255, 205, 40),
		Tokens = rgb(120, 255, 200),
		Robux = rgb(80, 205, 110),
		Navy = rgb(29, 42, 68),
		NavyDark = rgb(22, 32, 58),
		NavyCard = rgb(44, 62, 100),
		NavyCardDark = rgb(34, 49, 82),
		Money = rgb(92, 230, 92),
		Time = rgb(110, 205, 255),
		Highlight = rgb(255, 150, 40),
	},
	Fonts = {
		Title = Enum.Font.FredokaOne,
		Body = Enum.Font.GothamBold,
		Number = Enum.Font.GothamBlack,
	},
	CornerSmall = UDim.new(0, 8),
	CornerMedium = UDim.new(0, 12),
	CornerLarge = UDim.new(0, 18),
	CornerPill = UDim.new(1, 0),
	StrokeThickness = 3,
	MinTouchSize = 74, -- design px: 74 x UI scale 0.6 = 44 real px
	TweenTime = 0.18,
}

return Theme

```

## src/shared/Config/Titles.luau

Original SHA-256: `7335fa55a454ac1a1faf069dd9431216124391083c63001f7cfb023e67120ae1`

```lua
--!strict
--[[
	Titles — overhead nameplate title earned by the deepest layer a player has ever reached
	(PlayerData.MaxDepth, kept through rebirths). Index i = Config.Layers[i]; one title per layer.
	Color: the layer colour, except where that is too dark to read over the world with a dark
	outline (then a lighter tint of the same hue). Status & Social agent (v2.2 B6a).
]]

local rgb = Color3.fromRGB

export type TitleDef = {
	LayerId: string, -- must match Config.Layers[i].Id (checked in Config/init)
	Title: string,
	Color: Color3?, -- nil: use the layer colour
}

local Titles: { TitleDef } = {
	{ LayerId = "dry_sand", Title = "Sandcastle Rookie" },
	{ LayerId = "wet_sand", Title = "Bucket Brigade" },
	{ LayerId = "shell_bed", Title = "Shell Seeker" },
	{ LayerId = "tidal_clay", Title = "Clay Crawler", Color = rgb(214, 160, 126) },
	{ LayerId = "pirate_cove", Title = "Pirate Plunderer", Color = rgb(222, 168, 110) },
	{ LayerId = "shipwreck", Title = "Wreck Diver", Color = rgb(214, 156, 104) },
	{ LayerId = "fossil_bed", Title = "Fossil Hunter" },
	{ LayerId = "bedrock", Title = "Rock Breaker", Color = rgb(184, 188, 204) },
	{ LayerId = "crystal_caverns", Title = "Crystal Miner" },
	{ LayerId = "frozen_abyss", Title = "Ice Tunneler" },
	{ LayerId = "ancient_ruins", Title = "Ruin Raider" },
	{ LayerId = "magma_chamber", Title = "Magma Diver" },
	{ LayerId = "obsidian_depths", Title = "Obsidian Delver", Color = rgb(170, 130, 240) },
	{ LayerId = "alien_hive", Title = "Hive Invader" },
	{ LayerId = "the_core", Title = "Core Breaker" },
}

return Titles

```

## src/shared/Config/Treasures.luau

Original SHA-256: `a18e66674874b9d16d96d89b6de8f46fdb6a649e67aa12701f5e360f862b1aac`

```lua
--!strict
--[[
	Treasures — found while digging. Each belongs to one layer (Layer = index in Layers.luau)
	and appears in that layer's LootTable. SellValue ~= layerBase x rarityFactor where
	layerBase = SandValue x typical shovel SandMultiplier for that layer and rarityFactor =
	Common 8, Uncommon 20, Rare 60, Epic 200, Legendary 800, Mythic 3000 (digs-worth of sand).
	Every first find is added to PlayerData.Index (the collection book).
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Treasures: { Types.TreasureDef } = {
	{
		Id = "bottle_cap",
		Name = "Bottle Cap",
		Layer = 1,
		Rarity = "Common",
		SellValue = 8,
		FlavorText = "Somebody's soda. Gross, but it's a start!",
		Look = { Color = rgb(220, 60, 60), Shape = "Cap", Material = Enum.Material.Metal, Glow = false },
	},
	{
		Id = "lost_flip_flop",
		Name = "Lost Flip-Flop",
		Layer = 1,
		Rarity = "Uncommon",
		SellValue = 20,
		FlavorText = "Every beach has one. Where is the other one?!",
		Look = { Color = rgb(60, 190, 255), Shape = "Box", Material = Enum.Material.SmoothPlastic, Glow = false },
	},
	{
		Id = "cool_sunglasses",
		Name = "Cool Sunglasses",
		Layer = 1,
		Rarity = "Rare",
		SellValue = 60,
		FlavorText = "Instantly 200% cooler.",
		Look = { Color = rgb(30, 30, 40), Shape = "Box", Material = Enum.Material.SmoothPlastic, Glow = false },
	},
	{
		Id = "seashell",
		Name = "Seashell",
		Layer = 2,
		Rarity = "Common",
		SellValue = 16,
		FlavorText = "A classic. Smells like the ocean.",
		Look = { Color = rgb(255, 200, 170), Shape = "Shell", Material = Enum.Material.SmoothPlastic, Glow = false },
	},
	{
		Id = "sand_dollar",
		Name = "Sand Dollar",
		Layer = 2,
		Rarity = "Uncommon",
		SellValue = 40,
		FlavorText = "Sadly, shops won't accept it. The sell stand will!",
		Look = { Color = rgb(240, 230, 200), Shape = "Coin", Material = Enum.Material.SmoothPlastic, Glow = false },
	},
	{
		Id = "message_in_a_bottle",
		Name = "Message in a Bottle",
		Layer = 2,
		Rarity = "Rare",
		SellValue = 120,
		FlavorText = "'Dig deeper. The Core is real.' - A.D.",
		Look = { Color = rgb(120, 220, 180), Shape = "Bottle", Material = Enum.Material.Glass, Glow = false },
	},
	{
		Id = "conch_shell",
		Name = "Conch Shell",
		Layer = 3,
		Rarity = "Common",
		SellValue = 50,
		FlavorText = "Blow it to call the seagulls.",
		Look = { Color = rgb(255, 170, 150), Shape = "Shell", Material = Enum.Material.SmoothPlastic, Glow = false },
	},
	{
		Id = "glowing_pearl",
		Name = "Glowing Pearl",
		Layer = 3,
		Rarity = "Uncommon",
		SellValue = 120,
		FlavorText = "It glows a little brighter the deeper you go.",
		Look = { Color = rgb(255, 245, 255), Shape = "Orb", Material = Enum.Material.Glass, Glow = true },
	},
	{
		Id = "giant_clam",
		Name = "Giant Clam",
		Layer = 3,
		Rarity = "Rare",
		SellValue = 360,
		FlavorText = "It's still a little grumpy about being dug up.",
		Look = { Color = rgb(170, 140, 255), Shape = "Shell", Material = Enum.Material.SmoothPlastic, Glow = false },
	},
	{
		Id = "rusty_anchor",
		Name = "Rusty Anchor",
		Layer = 4,
		Rarity = "Common",
		SellValue = 130,
		FlavorText = "From a boat that got stuck in the mud.",
		Look = { Color = rgb(150, 90, 60), Shape = "Anchor", Material = Enum.Material.CorrodedMetal, Glow = false },
	},
	{
		Id = "pocket_watch",
		Name = "Old Pocket Watch",
		Layer = 4,
		Rarity = "Uncommon",
		SellValue = 320,
		FlavorText = "Stopped at exactly high tide.",
		Look = { Color = rgb(220, 190, 80), Shape = "Coin", Material = Enum.Material.Metal, Glow = false },
	},
	{
		Id = "mermaid_comb",
		Name = "Mermaid's Comb",
		Layer = 4,
		Rarity = "Rare",
		SellValue = 960,
		FlavorText = "Mermaids lose these ALL the time.",
		Look = { Color = rgb(120, 240, 230), Shape = "Shard", Material = Enum.Material.Glass, Glow = true },
	},
	{
		Id = "gold_doubloon",
		Name = "Gold Doubloon",
		Layer = 5,
		Rarity = "Common",
		SellValue = 360,
		FlavorText = "Pirate money! Arrr.",
		Look = { Color = rgb(255, 205, 40), Shape = "Coin", Material = Enum.Material.Metal, Glow = false },
	},
	{
		Id = "pirate_hook",
		Name = "Pirate Hook",
		Layer = 5,
		Rarity = "Uncommon",
		SellValue = 900,
		FlavorText = "Captain Sandbeard's spare.",
		Look = { Color = rgb(190, 190, 200), Shape = "Anchor", Material = Enum.Material.Metal, Glow = false },
	},
	{
		Id = "treasure_map",
		Name = "Treasure Map",
		Layer = 5,
		Rarity = "Rare",
		SellValue = 2700,
		FlavorText = "The X is... below you. Way below.",
		Look = { Color = rgb(230, 200, 140), Shape = "Tablet", Material = Enum.Material.Fabric, Glow = false },
	},
	{
		Id = "pirate_chest",
		Name = "Pirate Chest",
		Layer = 5,
		Rarity = "Legendary",
		SellValue = 36000,
		FlavorText = "Sandbeard's legendary loot chest!",
		Look = { Color = rgb(150, 95, 45), Shape = "Chest", Material = Enum.Material.Wood, Glow = false },
	},
	{
		Id = "ships_wheel",
		Name = "Ship's Wheel",
		Layer = 6,
		Rarity = "Common",
		SellValue = 960,
		FlavorText = "Steer the ship! Oh wait, it sank.",
		Look = { Color = rgb(140, 90, 50), Shape = "Wheel", Material = Enum.Material.Wood, Glow = false },
	},
	{
		Id = "captains_spyglass",
		Name = "Captain's Spyglass",
		Layer = 6,
		Rarity = "Uncommon",
		SellValue = 2400,
		FlavorText = "Spot treasure from a mile away.",
		Look = { Color = rgb(200, 160, 60), Shape = "Bottle", Material = Enum.Material.Metal, Glow = false },
	},
	{
		Id = "cursed_skull",
		Name = "Cursed Skull",
		Layer = 6,
		Rarity = "Epic",
		SellValue = 24000,
		FlavorText = "It winks at you when nobody is looking.",
		Look = { Color = rgb(120, 255, 140), Shape = "Skull", Material = Enum.Material.SmoothPlastic, Glow = true },
	},
	{
		Id = "trilobite",
		Name = "Trilobite",
		Layer = 7,
		Rarity = "Common",
		SellValue = 2900,
		FlavorText = "A 500-million-year-old bug. Cute!",
		Look = { Color = rgb(140, 130, 110), Shape = "Shell", Material = Enum.Material.Slate, Glow = false },
	},
	{
		Id = "ammonite",
		Name = "Ammonite",
		Layer = 7,
		Rarity = "Uncommon",
		SellValue = 7200,
		FlavorText = "A spiral shell from the age of sea monsters.",
		Look = { Color = rgb(210, 170, 120), Shape = "Shell", Material = Enum.Material.Marble, Glow = false },
	},
	{
		Id = "trex_tooth",
		Name = "T-Rex Tooth",
		Layer = 7,
		Rarity = "Rare",
		SellValue = 22000,
		FlavorText = "Bigger than your hand. Imagine the smile.",
		Look = { Color = rgb(250, 245, 225), Shape = "Bone", Material = Enum.Material.SmoothPlastic, Glow = false },
	},
	{
		Id = "dino_skull",
		Name = "Dino Skull",
		Layer = 7,
		Rarity = "Legendary",
		SellValue = 290000,
		FlavorText = "The museum would pay a fortune for this.",
		Look = { Color = rgb(245, 235, 210), Shape = "Skull", Material = Enum.Material.SmoothPlastic, Glow = false },
	},
	{
		Id = "geode",
		Name = "Geode",
		Layer = 8,
		Rarity = "Common",
		SellValue = 7700,
		FlavorText = "Boring outside, sparkly inside.",
		Look = { Color = rgb(120, 110, 130), Shape = "Orb", Material = Enum.Material.Rock, Glow = false },
	},
	{
		Id = "iron_nugget",
		Name = "Iron Nugget",
		Layer = 8,
		Rarity = "Uncommon",
		SellValue = 19000,
		FlavorText = "Heavy, shiny, and useful for shovels.",
		Look = { Color = rgb(160, 160, 170), Shape = "Shard", Material = Enum.Material.Metal, Glow = false },
	},
	{
		Id = "ancient_arrowhead",
		Name = "Ancient Arrowhead",
		Layer = 8,
		Rarity = "Rare",
		SellValue = 58000,
		FlavorText = "Somebody explored down here before you.",
		Look = { Color = rgb(90, 90, 100), Shape = "Shard", Material = Enum.Material.Slate, Glow = false },
	},
	{
		Id = "amethyst",
		Name = "Amethyst",
		Layer = 9,
		Rarity = "Common",
		SellValue = 22000,
		FlavorText = "Purple and sparkly.",
		Look = { Color = rgb(170, 90, 255), Shape = "Gem", Material = Enum.Material.Glass, Glow = true },
	},
	{
		Id = "sapphire",
		Name = "Sapphire",
		Layer = 9,
		Rarity = "Uncommon",
		SellValue = 55000,
		FlavorText = "Deep blue, like the ocean far above.",
		Look = { Color = rgb(40, 110, 255), Shape = "Gem", Material = Enum.Material.Glass, Glow = true },
	},
	{
		Id = "glow_crystal",
		Name = "Glow Crystal",
		Layer = 9,
		Rarity = "Rare",
		SellValue = 160000,
		FlavorText = "This is what lights the caverns.",
		Look = { Color = rgb(140, 255, 250), Shape = "Shard", Material = Enum.Material.Neon, Glow = true },
	},
	{
		Id = "rainbow_diamond",
		Name = "Rainbow Diamond",
		Layer = 9,
		Rarity = "Legendary",
		SellValue = 2200000,
		FlavorText = "Every colour at once!",
		Look = { Color = rgb(255, 140, 220), Shape = "Gem", Material = Enum.Material.Glass, Glow = true },
	},
	{
		Id = "frozen_fish",
		Name = "Frozen Fish",
		Layer = 10,
		Rarity = "Common",
		SellValue = 66000,
		FlavorText = "It's been chilling for 10,000 years.",
		Look = { Color = rgb(150, 210, 255), Shape = "Box", Material = Enum.Material.Ice, Glow = false },
	},
	{
		Id = "mammoth_tusk",
		Name = "Mammoth Tusk",
		Layer = 10,
		Rarity = "Uncommon",
		SellValue = 160000,
		FlavorText = "The mammoth wants it back.",
		Look = { Color = rgb(245, 240, 220), Shape = "Bone", Material = Enum.Material.SmoothPlastic, Glow = false },
	},
	{
		Id = "ice_crown",
		Name = "Ice Crown",
		Layer = 10,
		Rarity = "Epic",
		SellValue = 1600000,
		FlavorText = "Crown of the Frost King. Never melts.",
		Look = { Color = rgb(190, 240, 255), Shape = "Crown", Material = Enum.Material.Ice, Glow = true },
	},
	{
		Id = "stone_tablet",
		Name = "Stone Tablet",
		Layer = 11,
		Rarity = "Common",
		SellValue = 190000,
		FlavorText = "Instructions for a giant shovel?",
		Look = { Color = rgb(170, 160, 140), Shape = "Tablet", Material = Enum.Material.Slate, Glow = false },
	},
	{
		Id = "golden_idol",
		Name = "Golden Idol",
		Layer = 11,
		Rarity = "Uncommon",
		SellValue = 480000,
		FlavorText = "Don't swap it with a bag of sand...",
		Look = { Color = rgb(255, 200, 50), Shape = "Skull", Material = Enum.Material.Metal, Glow = false },
	},
	{
		Id = "sun_mask",
		Name = "Sun Mask",
		Layer = 11,
		Rarity = "Rare",
		SellValue = 1400000,
		FlavorText = "The Sandlantis people worshipped the beach sun.",
		Look = { Color = rgb(255, 170, 40), Shape = "Coin", Material = Enum.Material.Metal, Glow = true },
	},
	{
		Id = "atlantis_crown",
		Name = "Crown of Sandlantis",
		Layer = 11,
		Rarity = "Legendary",
		SellValue = 19000000,
		FlavorText = "The crown of the lost underground city.",
		Look = { Color = rgb(255, 215, 80), Shape = "Crown", Material = Enum.Material.Metal, Glow = true },
	},
	{
		Id = "obsidian_shard",
		Name = "Obsidian Shard",
		Layer = 12,
		Rarity = "Common",
		SellValue = 630000,
		FlavorText = "Volcanic glass. Sharp!",
		Look = { Color = rgb(40, 30, 50), Shape = "Shard", Material = Enum.Material.Glass, Glow = false },
	},
	{
		Id = "fire_ruby",
		Name = "Fire Ruby",
		Layer = 12,
		Rarity = "Uncommon",
		SellValue = 1600000,
		FlavorText = "Warm to the touch. Very warm. OUCH.",
		Look = { Color = rgb(255, 40, 40), Shape = "Gem", Material = Enum.Material.Glass, Glow = true },
	},
	{
		Id = "dragon_egg",
		Name = "Dragon Egg",
		Layer = 12,
		Rarity = "Legendary",
		SellValue = 63000000,
		FlavorText = "Something inside is moving...",
		Look = { Color = rgb(200, 50, 30), Shape = "Egg", Material = Enum.Material.Slate, Glow = true },
	},
	{
		Id = "shadow_gem",
		Name = "Shadow Gem",
		Layer = 13,
		Rarity = "Common",
		SellValue = 2000000,
		FlavorText = "Absorbs all light around it.",
		Look = { Color = rgb(80, 40, 120), Shape = "Gem", Material = Enum.Material.Glass, Glow = false },
	},
	{
		Id = "void_pearl",
		Name = "Void Pearl",
		Layer = 13,
		Rarity = "Uncommon",
		SellValue = 4900000,
		FlavorText = "Look inside and you see stars.",
		Look = { Color = rgb(40, 20, 80), Shape = "Orb", Material = Enum.Material.Glass, Glow = true },
	},
	{
		Id = "dragon_scale",
		Name = "Ancient Dragon Scale",
		Layer = 13,
		Rarity = "Epic",
		SellValue = 49000000,
		FlavorText = "Harder than any shovel... almost.",
		Look = { Color = rgb(150, 30, 200), Shape = "Shard", Material = Enum.Material.Metal, Glow = true },
	},
	{
		Id = "alien_goo",
		Name = "Alien Goo",
		Layer = 14,
		Rarity = "Common",
		SellValue = 6700000,
		FlavorText = "Squishy. Do NOT eat it.",
		Look = { Color = rgb(110, 255, 120), Shape = "Orb", Material = Enum.Material.Neon, Glow = true },
	},
	{
		Id = "ufo_part",
		Name = "UFO Part",
		Layer = 14,
		Rarity = "Uncommon",
		SellValue = 17000000,
		FlavorText = "Looks important. Probably from the engine.",
		Look = { Color = rgb(180, 190, 200), Shape = "Wheel", Material = Enum.Material.Metal, Glow = true },
	},
	{
		Id = "alien_artifact",
		Name = "Alien Artifact",
		Layer = 14,
		Rarity = "Rare",
		SellValue = 50000000,
		FlavorText = "It hums a song about the Core.",
		Look = { Color = rgb(90, 255, 200), Shape = "Tablet", Material = Enum.Material.Neon, Glow = true },
	},
	{
		Id = "alien_egg",
		Name = "Alien Egg",
		Layer = 14,
		Rarity = "Legendary",
		SellValue = 670000000,
		FlavorText = "Not a chicken egg. Definitely not.",
		Look = { Color = rgb(150, 255, 90), Shape = "Egg", Material = Enum.Material.Neon, Glow = true },
	},
	{
		Id = "core_fragment",
		Name = "Core Fragment",
		Layer = 15,
		Rarity = "Common",
		SellValue = 24000000,
		FlavorText = "A piece of the planet's golden heart.",
		Look = { Color = rgb(255, 190, 40), Shape = "Shard", Material = Enum.Material.Neon, Glow = true },
	},
	{
		Id = "molten_gold",
		Name = "Molten Gold",
		Layer = 15,
		Rarity = "Uncommon",
		SellValue = 60000000,
		FlavorText = "Liquid gold that never cools.",
		Look = { Color = rgb(255, 170, 0), Shape = "Orb", Material = Enum.Material.Neon, Glow = true },
	},
	{
		Id = "heart_of_the_earth",
		Name = "Heart of the Earth",
		Layer = 15,
		Rarity = "Legendary",
		SellValue = 2400000000,
		FlavorText = "It beats once every hour.",
		Look = { Color = rgb(255, 90, 60), Shape = "Gem", Material = Enum.Material.Neon, Glow = true },
	},
	{
		Id = "beach_ball_of_creation",
		Name = "Beach Ball of Creation",
		Layer = 15,
		Rarity = "Mythic",
		SellValue = 9000000000,
		FlavorText = "The FIRST beach ball. Every beach began with this.",
		Look = { Color = rgb(255, 255, 255), Shape = "Orb", Material = Enum.Material.Neon, Glow = true },
	},
	-- v3 discovery slice: Relics (rarity "Relic"). Not in any LootTable: any deposit of layer >=
	-- Layer has Config.Discovery.RELIC_CHANCE to hold one. Value = ScaledValue seconds of income.
	{
		Id = "sun_compass",
		Name = "A.D.'s Sun Compass",
		Layer = 1,
		Rarity = "Relic",
		SellValue = 0,
		ScaledValue = 1800,
		FlavorText = "Signed 'A.D.' on the back. The needle doesn't point north. It points DOWN.",
		Look = { Color = rgb(255, 215, 90), Shape = "Coin", Material = Enum.Material.Neon, Glow = true },
	},
	{
		Id = "tide_heart",
		Name = "Heart of the Tide",
		Layer = 3,
		Rarity = "Relic",
		SellValue = 0,
		ScaledValue = 2400,
		FlavorText = "A shell that beats like a heart. Hold it to your ear: the Core is calling.",
		Look = { Color = rgb(120, 255, 230), Shape = "Orb", Material = Enum.Material.Neon, Glow = true },
	},
}

return Treasures

```
