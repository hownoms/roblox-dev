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
