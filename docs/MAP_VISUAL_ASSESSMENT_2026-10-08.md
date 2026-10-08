# Map and visual assessment — 8 October 2026

Source baseline: `b6844f3`. This assessment reads the current world builders, layout, UI style and saved review evidence. No new Studio session, player observation or hardware measurement was performed. Desktop input remains paused in the latest playtest record.

## Verdict

Keep the existing beach expedition identity and compact central hub. The game has a coherent visual foundation and substantial recorded static inspection. There is no evidence that rebuilding the map, replacing all procedural models or adding more scenery would improve retention. It is also too early to call the experience visually finished: moving contact, populated play, audio and ordinary underground traversal have unresolved checks.

## What is already established

- All 199 collection entries received primary native views and actual 48/120/240-pixel static detail review. All 13 backpacks and 14 tools received static R15 worn/idle-grip checks. Do not restart those sweeps.
- Central scenery families received assisted actual-depth inspection at all 15 layers. Shipwreck barrel and Ancient Ruins lintel support fixes passed native retests. This covers central families, not every angle or all 45 pockets.
- The icon atlas passed 192/192 loaded-slot inspection. Navy UI, cream sand, coral/turquoise equipment and restrained gold are a consistent established palette.
- Shovel/backpack huts already combine distinct accent colors, functional equipment displays and readable signs. Sell has its own striped awning; the crate yard, egg arc and rebirth shrine provide different silhouettes.
- Protected underground scenery totals 45 atomic groups, with 798 BaseParts in the recorded implementation. Adding geometry requires profiling, not an assumed spare budget.

## Highest-value next decisions

1. **Make the return route obvious before moving stations.** Spawn and Surface return face the sand toward -Z. Sell is behind the player at Z=28; shovel/backpack huts are at X=±36, Z=34. The route is short, but requires turning. Check the full-bag moment with default camera and no coaching. If players search, strengthen persistent world direction and station silhouette visibility first; relocate only after a repeatable path/sightline problem. Existing guidance already has partial ordinary-play evidence, so avoid duplicating it blindly.
2. **Make the shared beach feel shared.** The dig area is 768×56 studs, while the functional hub occupies the central area. At 16 players, independently distributed digging can feel solitary. Trial a small clearly marked focal excavation near spawn using existing discovery/shared-goal systems; observe whether players converge and react to one another. Preserve the full beach and server carve bounds. Avoid designing rewards or a new cooperative system before that trial.
3. **Polish what moves in the first two minutes.** Verify shovel contact and scoop timing, visible bucket fill, starter creature slope/ground contact and first-upgrade feedback in ordinary play. Static gallery quality does not establish these. Follow the latest source changes and record concrete clipping/floating issues before editing factories.
4. **Check composition with fresh gameplay captures.** Surface decoration still uses repeated palm spacing (~34 studs) and umbrella spacing (~46 studs). A restrained cluster/empty-space pass may improve the long coast, but the current lighthouse/arch already add skyline identity. Do not move props into mutable digging terrain or spend a large part budget on invisible details.
5. **Judge deep areas by discoverability.** Protected wall pockets have distinct themes, but assisted inspection does not prove players encounter them naturally. Record a normal shaft, transition and return. A beautiful scene that sits out of the player's route does not strengthen the depth journey.
6. **Keep gameplay readable when crowded.** Individually readable models can become obscured by companions, rare glow, guide billboards, toasts and expanded chat. The recorded chat/bag and reveal/toast overlaps need focused current-build checks. Hardware and multiplayer gates remain open.

## Concrete map documentation mismatch

`MAP.md` still describes a Garage and a Garage prompt, although `Hub.luau` builds the four-crate yard at the legacy `Layout.GARAGE` coordinate. It also lists boardwalk spawn/deck heights from an older offset: current `DECK_TOP` is 1027, and `GetSurfacePoint` uses 1030.5 for the standing root pivot. The nine non-crate eggs are current. Update this reference before using its camera/coordinate notes for artwork or layout changes.

## Acceptance evidence still needed

A new player should identify dig → discovery → sell → first upgrade without coaching, explain one memorable moment to a friend, and want another dig after buying the first upgrade. Observe actual behavior and ask afterward; additional model polish or source tests cannot answer this. Complete normal underground/tide/streaming and dynamic contact checks selectively during that run, then profile populated sessions. Independent feedback and physical device checks remain separate from Studio automation.
