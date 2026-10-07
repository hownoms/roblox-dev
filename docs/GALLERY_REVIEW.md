# Collection review diagnostic — 6 October 2026

Build `gallery.project.json` into `build/AssetGalleryReview.rbxlx`, open that isolated place in Studio, and press Play. Keep the owner's DigTest place for gameplay work.

The native-size rows cover all configured tools, backpacks, pets, eggs, treasures, shades, consumables and listed props. Added rows separately cover every vehicle pet at full digger scale and every rideable pet using its actual ride builder. Both the world and preview interface read the same catalog so selection cannot drift from a separately maintained list.

The diagnostic opens in contact-sheet mode: a four-column, three-row page of **production Viewport** previews at 96 px with names and IDs. Previous/Next category and page buttons expose clear counts. Only the current page is rendered; changing pages destroys its models and frames. Click any card to open the selected asset at 48, 120 and 240 px. Previous/Next traverse the full catalog; Visit native moves the character beside the corresponding labeled pad and fits an inspection camera to the actual model bounds, hiding the preview panels. Return to previews restores the previous camera; Contact sheet returns to the current category and page. This inspection camera is diagnostic, not the gameplay camera. Switching modes also destroys the inactive previews. Previews are static and use production default framing and lighting. The interface scales down to fit smaller Studio viewports (the stated preview pixel sizes are at scale 1).

Source-derived catalog counts: tools 14 (2 pages), backpacks 13 (2), pets 56 (5), vehicles 13 (2), rides 1 (1), eggs 13 (2), treasures 53 (5), shade 7 (1), consumables 7 (1), props 22 (2): **199 entries across 23 category pages**. The runtime panel reports the actual catalog count.

The only substituted client dependency is `tools/gallery/ReviewState.luau`: it supplies the Viewport's `GetSetting` call with Reduced Motion enabled. The production State store, remotes, gameplay services and player-data initialization do not run. This verifies collection geometry and default Viewport rendering, not inventory interactions, physics, attachments, animation or live setting changes.

## Evidence and remaining review

- Source inspection found the previous gallery omitted the distinct full-size digger and ride builders. That concrete coverage gap is corrected.
- Initial Studio startup exposed a sibling-replication race (`UI` was not yet present in PlayerScripts). The client now waits for `Controllers.State` and the `UI.Components.Viewport` chain before requiring the production component; catalog/server shared dependencies also wait for their modules.
- Rojo sourcemap and isolated place build pass. Strict analysis of every gallery script and the production Viewport passes; gallery StyLua and diff whitespace checks pass.
- No production models were modified based solely on source appearance. Dedicated relic geometry and the existing primitive-based families remain available for comparative review.
- Studio contact-sheet review covered **199/199 entries across all 23 pages**. Every page populated with matching names/IDs; no blank models or frame-edge clipping was observed. Tools have distinct heads, backpacks retain their container families, pet faces and vehicle silhouettes read consistently, and the compass/Tide Heart remain distinct. The 900×678 Studio viewport scaled the nominal 96 px previews to about 78 px, so this is not certification at every stated physical pixel size.
- Thin/dark props have limited small-size contrast: the Lamp's dark pole is weak at its nominal 48 px detail preview, and Steel Pickaxe/Obsidian Shard/Lava Drill need their close/native material review. The lamp's luminous head remains visible; no global lighting/model recolor was applied from this observation.
- The live gameplay Lost Flip-Flop reveal became edge-on during rotation. Its static contact-sheet silhouette is readable; source audit traced the change to forced continuous reveal yaw rather than broken initial model orientation. The specific reveal gets a static presentation while other assets keep their existing spin.
- A complete native-scale and 48/120/240 detail review of every entry is **still pending**. The first native Visit revealed that teleport alone leaves the default camera facing away and the detail panel can cover the model; the rebuilt diagnostic fits an inspection camera and hides the panels. Live Steel Pickaxe inspection verified framing and visible metal geometry, then Return restored the previous camera and detail panel. Default chat intercepted the old upper-left Return control; disabling chat in that diagnostic run confirmed restoration. The latest source disables diagnostic chat and places Return at the bottom left; that final placement is built and source-checked but has not had a separate live run. A contact-sheet pass does not certify worn fit, movement or every material at close range.
- Worn backpack fit across avatar bodies, shovel grip/contact, ride seat/ground contact and animated pet motion require the live DigTest workflow. Hardware and crowded-performance gates remain separate and open.

Commands (repository root):

```powershell
D:/Tools/rojo.exe sourcemap gallery.project.json -o build/gallery-review-sourcemap.json
.tools/luau-lsp.exe analyze --definitions=.tools/globalTypes.d.luau --sourcemap=build/gallery-review-sourcemap.json --no-strict-dm-types tools/gallery src/client/UI/Components/Viewport.luau
.tools/stylua.exe --check tools/gallery
D:/Tools/rojo.exe build gallery.project.json -o build/AssetGalleryReview.rbxlx
```
