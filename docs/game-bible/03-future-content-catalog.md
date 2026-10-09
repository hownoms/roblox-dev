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
