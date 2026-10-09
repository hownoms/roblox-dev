# First expansion visual kit — integration handoff

Prepared 8 October 2026. Scope: Sunshine mini-vault slice only. Existing models, UI atlas,
approved bacon-v3 marketing files, saves and shipped gameplay are preserved. Nothing was
uploaded or published. These are new art assets; the expansion event and persistent rewards
are not implemented by this kit.

## Deliverables and readiness

- `concepts/`: generated full-body Mara/Pip design references. Concept artwork, not 3D models.
- `ui/`: transparent generated portraits (64/120/240), six house-rendered icons (32/120/240),
  a separate 720×480 atlas and exact cell rectangles. Local delivery-ready images; Roblox
  image upload/moderation and owned IDs remain pending. Original portrait masters are retained.
- `../../src/shared/Models/Expansion1.luau`: real Roblox primitive factories, strict typed,
  Rojo compatible, with welded held-tool metadata. Gameplay integration candidates awaiting
  Studio contact/movement/device review, not a claim that gameplay is ready to ship.
- `models/Expansion1Review.rbxlx`: open locally in Studio, then Play to construct the assets
  in an isolated review scene. It loads no production services or DataStores. The review tool
  can be equipped for basic grip inspection; the shipped scoop controller is deliberately
  absent, so full two-hand strike testing belongs in a private integrated test build.
- `previews/`: UI size checks and offline renders of actual factory transforms. These are
  geometry previews, not Roblox screenshots. Sphere tessellation/lighting in the offline
  renderer differ from Studio. Portraits are visual interpretations of simpler primitive NPCs.
- `manifest.json`: every deliverable's entity, purpose, readiness, source, integration home
  and hash. Derived ball/trophy/UI names are asset variants, not new save/reward IDs.

## Factory API

Require `ReplicatedStorage.Shared.Models.Expansion1` directly; the existing Models facade
and production boot path are unchanged. Every call creates a fresh unparented Model.

```lua
local Kit = require(game.ReplicatedStorage.Shared.Models.Expansion1)
local mara = Kit.NPC("npc_mara", "Idle") -- also Point / Celebrate
local pip = Kit.NPC("npc_pip", "Point")
local shovel = Kit.Broadwave()
local vault = Kit.SpringVault("Covered") -- Partial / Opened
local ball = Kit.BeachBall()
local stand = Kit.TrophyStand()
local replica = Kit.TrophyReplica()
local charge = Kit.ChargeEffect(0.5)
local wave = Kit.AbilityEffect(0.5, false)
local bounce = Kit.BallEffect(false)
Kit.SetAnchorProgress(vault:FindFirstChild("vault_anchor_1"), 0.25)
```

Scenery pivot is bottom-center, front is -Z, up is +Y. NPCs are roughly 5.2 studs tall,
anchored and noncolliding. Place on protected pads; range 10 studs. Idle/Point/Celebrate
are authored static dialogue poses, not uploaded animation clips. Preserve player avatars.
Pip's apron/pencil and Mara's collar/whistle carry identity without costume replacement.

The Broadwave uses existing full-shovel tool space (+Y shaft toward blade, +Z cup) and
Handle attributes `GripOffset`, `TwoHanded`, `ShaftAxis`, `CupAxis`, `LeftHand`, `BladePoint`.
Copy GripOffset to Tool.Grip, move parts into Tool, unanchor them and retain the welds.
Its blade is 2.25 studs wide; this is a held model, not the 12-stud ability footprint.
Do not insert `tool_broadwave` into the ordinary fourteen-shovel ownership list implicitly.
Trial is q_pip; permanent license cert_explorer, proposed price 1,500 coins.

Vault stays within the catalog's 12×10×8 envelope, including the raised open lid. The three
anchor assets use triangle/square/circle silhouettes plus cream-on-navy markers. Partial
clears the first and shows half-height covers on the other two. Quarter progress API updates
the cover only; services must whitelist/tag protected geometry separately. Attributes are
integration hints, not security enforcement. Work: solo 6 / crew 8 per anchor, range 12,
0.5-second per-player cooldown. Latch then three validated ball gates belong to event_vault.
The ball emerges after opening; do not instantiate the full-size ball inside the closed
chest. Its spring compression is a comic reveal, not a physics storage simulation.

The ball is a 7.6-stud contact sphere with slightly larger noncolliding colored ellipsoid
panels, following the existing Props.BeachBall construction. Leave anchored, move it through
a server-controlled bounded route and reset to a safe checkpoint. No unrestricted rolling
physics, velocity impulse against players or possession dropping is included. Animate a
small visual squash on decorative panels only, leaving contact radius unchanged. Reuse at
0.18 scale for the roughly 1.4-stud trophy. The cream stand is 2×2, top at Y=1.75; attach
the replica to TrophySlot. All replica parts are noncolliding/nonqueryable/nontouching.
Use landmark_spring_vault as the entitlement source, event_vault as completion context;
do not add sale value or fabricate a persistent trophy receipt in this art layer.

## Effect timing and accessibility

Broadwave: show three cream charge dots filling over the specified 0.8 seconds. Cancellation
removes dots without a release cue. At release lock direction; transform the wave into the
validated corridor frame (12 wide X ×8 high Y ×8 forward Z), within 12-stud range. Advance
visual progress 0→1 over 0.35 seconds, then destroy; cooldown is 8 seconds. The low foam
crest is a readable ground cue, not an opaque 8-stud wall. Never imply it is a water hazard.
No camera shake, player knockback, carving, damage or yield logic lives in this factory.
The server enforces protected geometry, filled-voxel/capacity bounds and the bible's
ordinary-equivalent yield cap; event tools produce progress instead of duplicate sand.

Ball: spawn 8 cream ground puffs on a validated small bounce, fade over 0.25 seconds, at
most once per 0.6 seconds. On a gate, use the objective icon/check cue plus a small local
celebration; show trophy reward only after accepted completion/settlement. Reduced motion
uses the lower wave and four puffs, no squash or camera displacement. Particle reduction
may omit puffs entirely; gate shape, objective progress and completion state remain visible.
Effects should be client-local, pooled or destroyed promptly, culled beyond 80 studs,
maximum two visible wave effects and one ball puff group per viewer. No audio dependency;
owned sound selection is a separate integration task.

## UI wiring

Keep the existing atlas intact. `ui/atlas_rects.json` defines the six 240px cells in the
separate expansion atlas; AssetId remains unassigned. Bind icons to contextual ability,
opt-in shared invite, helper eligibility, objective delta and settled trophy reward.
Labels remain real localized UI text, not baked into the images. Display NPC portraits
at 120px in dialogue, 64px only in compact cards; use 240px for larger layouts. Controls
must remain at least 48 logical pixels even when their icon is 32px. A UI icon is never
proof of contribution or an accepted reward. Helping has crossed coral/blue sleeves,
shared discovery has two visitors over the vault, completion has clipboard/check, reward
has the miniature beach-ball trophy; the silhouettes differ without color dependence.

## Verification and remaining gates

Passed: new-file StyLua checks; full src strict analysis with only two existing deprecated
API warnings; isolated review script strict analysis; production and review Rojo builds;
18 factory construction variants in the API-aware headless mock; tool weld/grip checks,
replica collision checks, 2×2 stand footprint and quarter anchor stages. Model snapshots
and image dimensions/alpha/bounds are recorded under verification/. Full checkout format
check currently reports pre-existing Windows line-ending/style differences; no blanket
ALL CHECKS PASSED claim. The initial sandboxed fetch failed to resolve github.com; a later
authorized fetch succeeded before sharing, confirming the default branch at 7589ff6.
The owner's separate local drafts and marketing changes were preserved.

Visually checked: portraits at 64 and 120, action icons at 32 and 120 against navy/cream,
and offline model silhouettes. At 32 the main icon silhouettes read; internal foam/pencil
details are intentionally secondary. At 64 portrait faces read; names stay outside art.

Studio review completed: construction, true vault extents, quarter anchor stages,
replica collision flags and basic R6/R15 hand-weld equip. NPCs, vault and held R15 tool
were visually inspected in actual lighting. See verification/STUDIO_REVIEW.md.
Ball panel seams need polish for closeups.

Pending Studio: moving/custom-avatar grip and scoop,
NPC gestures, lid/anchor occlusion from approach, ball route clearance and small bounce,
stand/replica placement at 2-stud grid, effects in actual lighting, streaming and cleanup.
Pending gameplay: opt-in, solo and late-helper flows, authoritative objectives/yield/reward
receipts, protected geometry, rejoin, crowded event view, real phone and controller. None
can be established by static images or mock tests. No publication/upload is authorized.

Rebuild review: `rojo build expansion1.project.json -o assets/expansion1/models/Expansion1Review.rbxlx`.
Rebuild geometry evidence after source edits: set ROBLOX_DEFS to .tools/globalTypes.d.luau,
run `python -X utf8 tests/tools/bundle.py`, then `.tools/luau.exe tools/expansion1/audit.luau`
redirected to verification/model-geometry.tsv, then `python tools/expansion1/export_visuals.py`.
Exact raster prompts and the built-in generation source are recorded in PROMPTS.json.
