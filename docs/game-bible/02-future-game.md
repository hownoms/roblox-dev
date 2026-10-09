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
