# Map art direction: "turn it up to 11"

Owner brief (8 Oct 2026): the surface map feels copy-pasted, empty, minimal and unexciting. Upgrade
the lamps, huts, beach layout, background environment, everything visual. Gameplay, coordinates of
functional stations and the dig zone stay as they are.

Everything stays code-built from parts, terrain, lighting, beams and particles. No uploaded meshes,
textures or catalog assets (uploads need the owner's approval).

## The picture we are building

You spawn on the boardwalk facing the sea. Straight ahead, past the dig strip and down the pier, a
**carnival pier end with a big Ferris wheel** turns slowly against a hazy horizon dotted with islands
and a crossing sailboat. On the left a **rocky headland with a sea arch** closes the beach. On the
right, the **striped lighthouse** on its headland sweeps a beam. The boardwalk behind you is a lively
promenade: curved-arm lamps that glow, sagging string lights and bunting, snack carts, signposts
pointing to every station. The hub is a ring of distinct, readable buildings you can name by silhouette.
Up and down the coast, things sit in deliberate clusters with open sand between them: cabana rows, a
volleyball court, a bonfire ring with log benches, tide pools, rowboats pulled up on the sand, a swim
line of buoys. Things move: the wheel, boats bobbing, gulls circling, flags, kites, foam at the water.

## Rules for every builder

1. **No copy-paste.** Never place a prop at a fixed spacing with one variant. Use a seeded
   `Random.new(<own constant>)` (do not consume the shared World rng in new code), and jitter position
   (±20-35% of spacing), yaw, scale (0.85-1.25) and variant. Group in odd numbers (1 big + 2 small).
2. **Clusters plus negative space.** Busy pockets, then open sand. The dig strip stays visually open.
3. **Silhouette first.** Each landmark/station must be identifiable at 100 studs by shape alone.
4. **Trim and layering.** Premium primitive builds use base plinths, corner trim, eave boards, roof
   overhangs, two-tone colour, and a darker tone on undersides. Avoid single flat boxes.
5. **Scale.** Avatar is ~5 studs. Palms should be 18-34 studs tall, not 11. Landmarks 50-90 studs.
6. **Palette.** Keep `Config.Theme` colours as the accent set (Coral, Ocean, Palm, Gold, Sunset,
   Purple, Sand, Panel). Wood (176,122,76)/(124,84,52), white trim (250,246,236), navy (31,55,73).
   Saturated accents on interactables and landmarks, softer pastels on background buildings.
7. **Decor parts** are anchored, `CanCollide/CanQuery/CanTouch = false`, `CastShadow = false` when
   smaller than ~4 studs or far away. Only things players should stand on or bump into collide.
8. **Neon** only via `Build.neonSafe` colours (never near-white Neon). Glow comes from Neon + Bloom;
   real `PointLight`s are rare, `Shadows = false`, `Range <= 16`.

## Off-limits areas (gameplay)

- Dig zone x -384..384, z -64..-8, and the solid layered walls x ±392, z -72..0. Nothing in or above.
- Underground alcove pockets in the inland wall: z -8..0 at x ∈ {-288,-192,-96,0,96,192} ±16. Do
  not fill terrain there.
- Invisible boundary: x ±400, z +130, z -232. Playable props go inside; backdrop goes outside.
- Terrain material changes on walkable ground change heat (Sand/Sandstone = sun, anything else = cool).
  Do not pave large new walkable areas without noting it.
- Tagged station parts, prompts, attributes, and the names pinned by `tests/smoke.spec.luau` must
  survive (see the audit notes in each workstream brief).

## Workstreams and file ownership

| Stream | Owns | Area |
|---|---|---|
| A Skyline | `World/Vistas.luau`, `World/Terrain.luau` (backdrop only), `World/Lighting.luau` | Everything outside the boundary: headlands, cliffs, islands, far water, sky, clouds, gulls, horizon boats, lighthouse |
| B Boardwalk + pier | `World/Boardwalk.luau` (+ new `World/Promenade*.luau` if wanted) | Deck z -4..12 (except stall spots), pier, pier-end carnival + Ferris wheel, title sign |
| C Hub | `World/Hub.luau` (+ new `World/HubKit.luau` if wanted) | x -110..110, z 12..125: every station building, plaza, hub landscaping |
| D Beach + dressing | `World/Decor.luau`, `World/Util.luau`, `src/shared/Models/Props.luau` | Wet sand / shoreline / shallows z -68..-110, inland sand x \|>110\|, z 12..125, all palms, boardwalk stalls |
| E Motion | new `src/client/Controllers/AmbientController.luau`, `src/client/Main.client.luau` | Client-side ambient animation for tagged models |

Boardwalk stalls stay `Map.Decor` direct children named `BoardwalkStall` (test-pinned) at deck
x ±130, ±250, ±350, z ≈ 7. Stream B keeps a 12x8 footprint free at those spots.

## Budgets (surface, `Workspace.Map` excluding `Underground`)

| Stream | BaseParts | PointLights | ParticleEmitters |
|---|---|---|---|
| A | 900 | 4 | 4 |
| B | 2,400 | 18 | 6 |
| C | 1,800 | 10 | 6 |
| D | 5,000 | 6 | 8 |
| **Total cap** | **10,500** | **40** | **24** |

Was ~4,800 parts before the overhaul. Streaming (TargetRadius 320) keeps a single view well under this.

## Ambient motion contract (built server-side, animated by stream E on the client)

Anchored, non-colliding models tagged with CollectionService. Tag the **Model** (with PrimaryPart or a
sensible pivot). Attributes are on the tagged instance. The client only moves things within ~450 studs
of the camera (Drift/Orbit always).

| Tag | Attributes | Behaviour |
|---|---|---|
| `AmbientSpin` | `SpinRPM` (number), `SpinAxis` (Vector3, pivot-local, default `(0,1,0)`) | Rotates the model about its pivot |
| `AmbientFerrisWheel` | `SpinRPM` | Model containing a child Model `Wheel` (pivot at the hub, rotation axis = Wheel pivot's local Z), and direct-child Models named `Gondola`, each with attribute `HangOffset` (Vector3, offset of its hang point from the hub in Wheel-pivot local space at build time). Wheel rotates; gondolas follow their hang points and stay upright |
| `AmbientBob` | `BobHeight` (studs), `BobPeriod` (s), `BobRoll` (degrees) | Bob up/down plus gentle roll, phase from position |
| `AmbientSway` | `SwayDegrees`, `SwayPeriod` | Rocks about the pivot's X and Z (flags, kites, lanterns) |
| `AmbientDrift` | `DriftFrom`, `DriftTo` (Vector3), `DriftSeconds` | Moves from -> to, faces travel, loops (horizon boats, banner plane) |
| `AmbientOrbit` | `OrbitCenter` (Vector3), `OrbitRadius`, `OrbitSeconds`, `OrbitBob` (studs) | Circles the centre facing travel (gulls) |
| `AmbientPulse` | `PulseMin`, `PulseMax` (Transparency), `PulsePeriod` | Fades a BasePart's (or all of a model's) transparency (foam, sparkle) |
| `AmbientNightLight` | — (on a Light or a Neon BasePart, or a Model of them) | Lights enabled / Neon shown only when `Lighting.ClockTime >= 17.3` or `< 6.5` (Golden Hour turns them on) |

Phase offsets come from each instance's position, so neighbours never move in lockstep.
