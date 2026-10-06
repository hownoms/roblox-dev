# Dig to the Core — visual audit and production direction

Audited 6 October 2026 against repository revision `9cc921e`, existing icon artwork, and a Studio baseline playtest. This is a production checklist, not a claim that every model has passed close-up visual review.

## The direction

Make a collectible beach expedition: warm cream sand, coral and turquoise equipment, navy interface panels, big readable silhouettes, and increasingly strange finds underground. Preserve the toy-like character. Realistic imported meshes, glossy flat UI and neon on every object would fragment this identity. Quality comes from consistent proportions, intentional composition, responsive feedback and excellent small-screen readability.

## Keep, refine, replace

| Category | Keep | Change / completion criteria |
|---|---|---|
| UI icons | Existing 64-icon atlas: coherent outlines and readable 32px silhouettes | Upload the atlas, connect the **image** ID, verify every crop in Studio. Add scan/excavate/relic icons in the same style when those actions outgrow generic icons. |
| UI style | Navy panels, chunky borders, coral/gold calls to action, large numbers | Reduce simultaneous HUD demands. Dig, bag capacity, sell/surface and depth have priority; secondary systems should expand on demand. Review at phone, tablet, desktop and gamepad sizes. Use focus outlines and sufficient labels beyond color. |
| Item previews | Actual 3D model ViewportFrames | Stop hidden spinning previews; respect reduced motion. Check camera framing on the tallest shovel, largest vehicle and smallest treasure. Avoid clipping or excessive perspective. |
| Shovels / pickaxes | Procedural silhouette progression and recognizable functional heads | Review in-hand grip, strike pose and hit registration together. Higher tiers must change head silhouette and construction, not only color. Keep metal/glow accents subordinate to the visible cutting edge. |
| Backpacks / buckets | Beach-specific worn buckets, rims, sand fills and bags | Check back attachment on several avatar body types and animations. Preserve straps and rim contrast. No floating or torso-intersecting buckets. |
| Pets | Recognizable digging creatures and vehicle companions | Review full collection together for a consistent face/eye language and progression. High rarity needs silhouette/animation distinction. Reduce sparkles if they obscure eyes or digging targets. |
| Rideable machinery | Existing construction vehicle identity | Review boarding, seat position, track contact, bucket motion and camera clearance. A premium excavator needs weight and believable movement, not extra bloom. |
| Common treasures | Shells, fossils, coins and beach finds | Ensure silhouette distinction at actual pickup size and in inventory. Discovery material variants must retain readable shape and accent contrast. |
| Relics | Sun Compass and Tide Heart concepts | Added dedicated brass compass and shell-heart geometry; visually inspect both reveal and inventory framing. Avoid generic coin/orb fallbacks for milestone rewards. |
| Surface props | Existing palms, umbrella/towel pairs, lifeguard towers, stalls and shells | Towel stripe depth separation fixed. Replace repetitive rows with deliberate clusters and empty sightlines where needed. Never anchor props above diggable ground. |
| Coastal skyline | Beach/pier layout and strong sea-facing sightline | Added low-part-count lighthouse headland and offshore rock arch. Verify streaming visibility, fog, silhouette at spawn, and no obstruction of functional stations. |
| Underground | Fifteen-layer progression and authoritative buried-find loop | Highest remaining environment priority: authored fossil, pirate, crystal, ice, magma and alien accents with distinct shapes. Fixed scenery must stay in protected pockets outside refill/carve volumes; buried finds remain owned by DiscoveryService. Tint alone is insufficient. |
| Lighting | Warm daylight, restrained bloom and existing glare fixes | Check every depth and sunset for face/terrain readability. Avoid changing exposure globally to solve one shiny asset. Prefer dark-to-light value separation and small emissive accents. |
| VFX | Dig feedback, treasure reveals, reward feedback | Reduced Motion now suppresses camera shake/reveal camera movement, spinning previews, reward flights, flashes and confetti. Further review looping UI pulses and hatch transitions. Never hide the digging cursor or reward name. |
| Audio | Configured interaction cues and setting controls | Beach/deep music and ambience IDs are empty. Produce or source licensed/owned wave ambience, depth beds, shovel material impacts and relic cues; upload and set permissions. Do not invent IDs. |
| Marketing / badges | Existing icon, thumbnails and themed badge set | Compare against the actual final game. Replace images that imply scenes or equipment the game cannot deliver. Use real gameplay framing with the same palette and silhouettes; inspect title-safe crops. |

## Asset production rules

- Three reads: silhouette at a distance, color/material family at medium range, selective detail close up. Spend geometry where the player looks.
- Environment kits: shared sand/rock/wood/painted-metal palette, a small family of rounded/beveled shapes, reusable modular pieces. Hero landmarks deserve bespoke geometry; repeated background props need fewer pieces.
- UI artwork: transparent square masters, safe internal padding, consistent outline weight, inspect at 24/32/48px. Use native GUI/vector geometry for frames and controls. Do not bake labels into bitmaps.
- Imported meshes: author pivot, scale, normals, UVs, collision hulls and texture budgets deliberately. Merge static decorative pieces where profiling supports it. Keep editability and reuse; avoid unrelated free-model packs.
- Texture detail should support shape. No noisy realistic textures pasted onto otherwise clean toy props. Use PBR selectively on hero surfaces and inspect on low graphics.
- Keep decorative scenery non-queryable/non-colliding. Streaming groups should correspond to a landmark, not the entire map. Profile a full 16-player session with pets, rides and discoveries before setting budgets.

## Finish gates

1. Atlas loads in a real client under the intended owner's permissions and moderation state; all icons are correctly cropped.
2. First minute: spawn composition, sign/wayfinding, shovel equip, first dig, first buried find, full bag and sell all look cohesive.
3. Inventory gallery: all tools, backpacks, creatures, vehicles, shade, consumables and treasures reviewed at close-up and thumbnail size. Record specific replacements, not a blanket rebuild.
4. All fifteen depths: readable dig target, distinctive landmark language, no floating scenery after holes or tide refill, readable relic reveal.
5. Input/device review: phone touch targets and safe areas, tablet spacing, desktop hierarchy, visible gamepad selection, reduced-motion preferences.
6. Performance: real device frame/memory/network measurements and `/stress` full-population scenarios. Headless tests confirm behavior but do not certify frame rate or visual quality.
7. Owned audio, faithful store media, final screenshots and client permissions verified. Publish only after these gates pass.

## Implemented in this pass

Fixed destroyed text-constraint callbacks observed in Studio; separated towel/stripe surfaces; added gamepad focus outlines; added reduced-motion preference and effects guards; stopped hidden preview rotation; gave both v3 relics dedicated models; added coastal landmark silhouettes. A pre-existing strict-type mismatch in announcement parsing was also corrected. Changes are in the workspace clone, with an isolated `build/VisualPolish.rbxlx` for review; the original Studio project is separate.

Research rationale and official Roblox references are in the workspace's `VISUAL_DESIGN_RESEARCH.md`. Source inspection establishes implementation intent; Studio and real-device review establish appearance and performance. The underground art pass, authored audio and complete collection/device review remain substantial work.

## Review artifacts and atlas status

- `gallery.project.json` builds `build/AssetGallery.rbxlx`: an isolated native-scale gallery of every configured tool, backpack, pet, egg, treasure, shade, consumable and prop. Production services and player data are excluded. Press Play to populate the collection; labels identify each asset.
- Atlas uploaded to `xxLoyalAcExx`: decal `73587184593339`; generated **image** `97869519007106`, verified in Creator Hub's Images library and connected in `IconAtlas.luau`.
- Studio review reported 40 configured image slots and **0 loaded**, alongside failures fetching avatar mesh assets. Crop appearance remains unverified. AtlasIcon now keeps emoji visible until ImageLabel.IsLoaded and switches automatically when the image arrives. This prevents blank control icons during loading or asset-delivery failures.
- The first offshore arch prototype read as a block bridge in Studio. It was revised to rounded, overlapping rock masses; its overall silhouette was reviewed in the next build. The small skyline kit is Persistent so it remains visible beyond the map's streaming radius; account for these parts in real-device profiling.

## Pre-push review, 6 October 2026

- Reviewed the complete commit diff against `9cc921e`; no production economy, loot odds, discovery authority or purchase behavior changed. The remote target branch still points at that base revision.
- Opened a fresh `build/PrePushReview.rbxlx` generated from the committed sources. Confirmed the beach landmark silhouette and readable fallback icons in the real client. Atlas delivery remained unavailable: the diagnostic reported 39 configured slots, zero loaded, with avatar mesh fetch failures too. Final atlas crop/loading approval remains pending.
- Rendered both relics using the production Viewport component and production models. Both fit within their preview frames; the compass needle/dial and Tide Heart spiral/pearl remain recognizable. A native preview diagnostic confirmed the model pivot stays unchanged with ReducedMotion enabled.
- Studio iPhone XR landscape emulator, 896x414: checked HUD notch/safe-area placement, thumbstick and jump clearance, Settings panel fit and scrolling, and a touch toggle of Reduced Motion from OFF to ON. These are layout/input checks, not hardware performance measurements or portrait certification.
- Studio controller emulator: observed selected Settings button highlighting and explicitly exercised native GuiService selection. Physical-controller traversal/activation across every panel remains unverified; physical-controller hardware was not used for these checks.
- Validation: 1,250 client checks; 969 normal server smoke checks; 956 Studio-mode smoke checks; 8 utility checks. Strict Luau analysis succeeds with two existing API deprecation warnings in RewardsService. Changed production files and the gallery pass StyLua; the full checkout format check is affected by Windows CRLF differences on untouched files. Rojo builds both game and gallery successfully; diff whitespace check passes.
- Keep the PR in draft until the atlas visibly loads/crops correctly and the remaining hardware/input checks are complete. This is the first polish pass; underground environment kits, audio and collection-wide hardware review are later work.

## Continuation: atlas verification, 6 October 2026

- Added `atlas-review.project.json` and `tools/icons/AtlasReview.client.luau`. Build with `rojo build atlas-review.project.json -o build/AtlasReview.rbxlx`, open in Studio and press Play. This isolated place uses the production AtlasIcon component, displays all 64 cells in atlas order at 24/32/48 px, and reports loaded slots out of 192. It excludes production services and player data. The final diagnostic preloads ImageLabel instances, not just an asset URI.
- Fetched the remote before continuing. PR #1 and the subsequent playtest fixes are already merged; the continuation baseline is `bf547f0`. The earlier draft-PR recommendation is historical. Preserve the newer shovel/Avatar Joint Upgrade, crate-tab and ground-placement fixes. Fetch and inspect the remote at the beginning of future sessions because the owner also develops between sessions.
- Creator Hub's authenticated Images library confirms atlas image `97869519007106`, owned by `xxLoyalAcExx`; its configuration says **Open Use**. No permissions change or re-upload was needed. The anonymous delivery endpoint's authentication error was not proof of a permission problem.
- Resolved a loading deadlock: AtlasIcon hid ImageLabels until IsLoaded, preventing the renderer from requesting them. Keep configured images visible while their transparent background leaves the emoji readable. A shared 0.25-second check clears the fallback when cached images finish loading without a property-change notification; loaded/destroyed icons leave that check set.
- Actual final Studio review: **192/192 image slots loaded** after scrolling the gallery. Visually inspected all 64 crops at 24/32/48 px; offsets match their labels, silhouettes remain readable, and no cell-edge clipping or fallback overlap remained. The independent review preloads instances, but the production fix does not depend on the diagnostic preload. Evidence: `build/review/atlas-loaded.png`.
- Connected the owner's existing `build/DigTest.rbxl` to `rojo serve default.project.json` on localhost:34872 and pressed Play. Production HUD icons visibly load and the world reaches ready. This follows the owner's normal DigTest/Rojo workflow; isolated builds are diagnostics only.
- Inspected the complete source atlas and existing `assets/icons/preview_32.png` on navy and cream backgrounds. All 64 source silhouettes are coherent; no visible cell-edge clipping was found. This source-art inspection does not verify Roblox image delivery or engine resampling.
- Validation: 1,280 client checks, including cached image completion without a notification and switching back to a raw fallback; 976 server smoke checks; 963 Studio-mode smoke checks; 8 utility checks. Strict analysis passes with the two existing RewardsService deprecation warnings. Production component/diagnostic formatting, Rojo builds and diff whitespace checks pass.
- **Physical phone/controller checks remain pending.** On a real phone, verify atlas loads, HUD safe areas, dig/scan/excavate/sell controls and shop/settings scrolling. With a physical controller, verify visible selection, traversal, activation, dismissal and return of focus across every panel. Record device, orientation, controller and observed failures. Emulator/source/headless checks do not close this gate.
- Next ordered work after hardware verification: the spawn/dig/discover/sell/upgrade sequence, Pirate Cove and Crystal Caverns, collection review, and crowded gameplay/audio/badge/store checks. None of these later stages is claimed complete by this atlas fix.
