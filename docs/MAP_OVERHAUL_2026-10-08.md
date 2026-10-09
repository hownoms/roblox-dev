# Map art overhaul: session record, 8 October 2026

Owner request: the surface map felt "copy pasted, very empty, very minimal" and should go to
"a 10, maybe an 11". This records how the overhaul was done, what changed, how it was checked and
what is still open. The rules and contracts live in [MAP_ART_DIRECTION.md](MAP_ART_DIRECTION.md).
Coordinates are in [MAP.md](MAP.md). The version summary is in [CHANGELOG.md](CHANGELOG.md)
("Unreleased: surface map art overhaul").

**State:** merged to the default branch. **Not published** to Roblox; live is still place v17.

## How it was done

1. **Research (agents).**
   - A design brief on what top Roblox simulator hubs and stylized beach environments do: landmarks, three depth layers, clusters with negative space, silhouettes, motion and colour.
   - An audit of the world code.
   - A tooling survey: EditableMesh, Blender, Creator Store, Studio AI and built-in effects.
2. **Root causes found by the audit:**
   - `Util.Prop` never passed a variant, so every palm, umbrella, tower and stall was identical.
   - Palms were 11 studs tall next to a 5-stud avatar.
   - Lamps never lit, there were no clouds, and the terrain ended at a hard edge at x ±520 / z +170.
   - The surface had ~4,800 parts.
3. **Five parallel build streams**, each in its own worktree with separate file ownership:
   - A, skyline: `Vistas`, `Headlands`, `Skyline`, `Terrain`, `Lighting`.
   - B, boardwalk and pier: `Boardwalk`, `Promenade`, `PromenadeKit`, `PierCarnival`.
   - C, hub: `Hub`, `HubKit`, `HubShops`, `HubAttractions`, `HubPlaza`.
   - D, beach: `Decor`, `Util`, `Props`, `PropsBeach`.
   - E, client motion: `AmbientController`.

   The streams shared a tag contract for animated scenery and per-stream part, light and emitter budgets.
4. **Merge and guard.** The streams were merged one by one with the full suite after each. A new smoke check enforces the budgets: 10,500 surface parts, 40 lights and 24 emitters. It also fails if any scenery stands over the dig strip.
5. **Studio review.** This used the Roblox Studio MCP: Play mode on `build/DigTheBeach.rbxlx`, a scripted camera and screen captures. Fixes were pushed into the open place and re-captured.

## What changed (player view)

- **First view from spawn:** the pier leads straight to a carnival deck with a 48-stud Ferris wheel, framed by two tall palms. Rock headlands with grass tops close the beach on both sides.
- **Skyline:**
  - A striped lighthouse on the east point, with a spinning beam and a keeper's cottage.
  - A west sea arch and rock-pillar sea stacks.
  - Five islands and a smoking volcano on the horizon, and hills behind the dunes.
  - Gulls, horizon sailboats and a "DIG TO THE CORE!" banner plane.
  - Clouds and a tropical lighting pass. Golden Hour was retuned.
- **Boardwalk:**
  - 27 vintage lamps in three styles at an irregular rhythm, glowing from Golden Hour on.
  - String lights and bunting over the hub stretch.
  - A "Welcome to Sunny Sands Beach" arch.
  - Ice-cream and lemonade carts, signposts, benches, planters, bins, lifebuoys and foot showers.
- **Pier:** viewing bulges with fishing rods. The carnival has the wheel, a carousel, a ticket booth, a strength tester and the Sunset Pier arch.
- **Hub:** each station is its own building:
  - Sand Exchange with a spinning coin (Sell)
  - Digger's Hardware (Shovels)
  - Surf & Pack Outfitters (Backpacks)
  - a tiki bar (Beach Shop)
  - a hatchery with a giant cracked egg (Eggs)
  - a crane construction yard (Crates)
  - a column temple with a portal ring (Rebirth)
  - a Hall of Fame (leaderboards)
  - a three-tier dolphin fountain on a sun-mosaic plaza

  Positions, tags, prompts and pinned names are unchanged.
- **Beach:**
  - Palms are 18-34 studs in three classes. Umbrellas come in 3 styles and 8 colourways, and towers in 5 colours.
  - Coast scenes from west to east: Tide Pool Point, Kite Field, Rowboat Landing, Picnic & Castles, two umbrella villages with a buoy swim zone, Surf School, Snorkel Cove and Bonfire Cove.
  - Inland: cabana rows, a volleyball court, a sandcastle contest, beach games, a sun deck, palm groves with hammocks, and dune fences. A pulsing foam line runs along the water.
- **Motion (client only):** the Ferris wheel, carousel, lighthouse beam, coin and portal spin. Boats and buoys bob, flags and kites sway, gulls circle, and boats and the plane drift. Night lights switch on with the evening light. All of it respects Reduced Motion and low graphics quality.

## Studio review findings and fixes

| Seen in Studio | Fix |
|---|---|
| Sea stacks looked like stacked snowballs | One tapered pillar of overlapping rock blobs |
| Headland cliffs blotchy cream/navy (Limestone shares the Fossil Bed layer colour) | All cliff, arch and stack terrain uses Rock, with grass caps |
| Dark straight band in the far sea (deep stand-in plane showing the far-sea slab edge) | Beyond z -300 the stand-in plane sits at the water line |
| Bunting at eye height across the spawn view (boardwalk twin lamps, hub gateway) | Both spans removed; the rest of the festoons kept |
| Arrow signs looked reversed | Not a bug: the camera faced north, so east was on the left |

Captures are in [`marketing/map-overhaul-2026-10-08/`](../marketing/map-overhaul-2026-10-08/): the final spawn view, before/after sea stacks, hub, boardwalk, carnival, lighthouse and Golden Hour. Shots marked "before-fixes" show the cream headlands and old stacks.

## Validation

All of the following pass:
- smoke 2,199 (Studio mode 2,166)
- client 1,464, including 51 new motion checks
- all seven tutorial scenarios
- persistence boot (live and Studio)
- utility 8

The strict typecheck shows only the two existing RewardsService deprecated-API warnings, and the Rojo build works. Budget: 9,699 surface parts, 34 lights, 14 emitters.

## Still open

- **Motion** was only seen in still frames, never watched moving.
- **Mobile frame time** with the doubled part count: profile on a real phone before publishing (see [PERFORMANCE.md](PERFORMANCE.md)).
- **Optional next step:** smooth meshes generated in code with EditableMesh (palm fronds, canopies, rocks). This needs no uploads, but the live game needs the owner ID-verified with "Allow Mesh / Image APIs" on.
- **Publishing** is the owner's call (new place version, then re-verify the published scripts as for v17).
