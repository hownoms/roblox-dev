# Verification record — 8 October 2026

Local art production and headless/build checks, not ordinary gameplay evidence.

| Check | Result |
|---|---|
| New Luau source formatting | Pass, explicit repo StyLua config |
| Production regression suite before sharing | Pass: utility, live/Studio server smoke, live/Studio persistence boot, client and seven tutorial scenarios (13 invocations) |
| Full source strict analysis | Pass; only existing IsInGroup / IsFriendsWith deprecation warnings |
| Isolated review script strict analysis | Pass |
| Main Rojo project build | Pass; local ProductionBuildCheck.rbxlx |
| Isolated expansion Rojo build | Pass; local Expansion1Review.rbxlx |
| Real-factory construction in existing API-aware mock | Pass, 18 variants, 4–51 BaseParts each |
| Held-tool grip metadata and rigid weld coverage | Pass, headless |
| Trophy no collision/query/touch; stand 2×2 footprint | Pass, headless |
| Anchor 0/25/50/75/100% visual stages, translated/rotated vault | Pass, headless |
| Catalog vault 12×10×8 envelope | Pass, conservative rotated-part bounds |
| PNG sizes and alpha | Pass, 42 PNGs audited in image-audit.json |
| UI icon 32/120px review against navy and cream | Visually inspected; distinct main silhouettes |
| Portrait 64/120px review | Visually inspected; clear faces and outfit identity |
| Geometry and trophy/stand scale previews | Visually inspected; offline renderer, not Studio |
| Full repository formatting gate | Not clean: pre-existing checkout-wide line-ending/style differences |
| Default branch fetch | Initial sandbox attempt failed; authorized fetch before sharing passed, default at 7589ff6 |
| Studio construction, vault extents, anchor stages, lighting and basic R6/R15 equip | Pass; see STUDIO_REVIEW.md for evidence and limits |
| Moving scoop/custom-avatar contact, ball route and effect cleanup | Pending integrated gameplay review |
| Crowded event, real phone/controller, streaming and cleanup | Pending |
| Server objectives, yield, protected geometry and reward persistence | Integration pending; visual kit only |
| Roblox uploads / publication | None |

Headless extents and part counts: model-audit.json. Full factory part transforms:
model-geometry.tsv. Main/review source analysis: source-typecheck.txt and
review-typecheck.txt. Read INTEGRATION.md for repeatable checks and integration boundaries.
