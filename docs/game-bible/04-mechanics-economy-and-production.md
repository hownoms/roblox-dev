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
