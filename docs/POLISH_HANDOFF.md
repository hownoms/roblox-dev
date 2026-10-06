# Visual polish handoff — 6 October 2026

Read this first when continuing in another chat, then read `docs/VISUAL_POLISH.md` for the design direction and historical reviews.

## Repository and saved work

- Local repository: `C:\Users\howar\Documents\ChatGPT\Roblox UEFN Dev\roblox-dev`.
- Remote: https://github.com/hownoms/roblox-dev.git.
- Current branch: `codex/atlas-loading-fix`.
- Implementation commit: `bcdb8a6688f7f45fbc6c1e8c0bed9ca12ad9fb77` — Fix atlas loading and verify all icon crops in Studio.
- Pushed draft PR: https://github.com/hownoms/roblox-dev/pull/7. It has not been merged by this chat.
- Base branch: `claude/pensive-meitner-6jx4u4`, last checked at `bf547f0c6bf39c684e3f8551a1d6055e15254cdc`. PR #1 and PR #2–6 were already merged when this work started.
- Fetch and inspect remote changes before starting further work: Howard develops between chats. Preserve newer shovel poses/Avatar Joint Upgrade support, crate-tab work and ground-placement fixes. Do not blindly reset or overwrite local changes.

## Completed and verified

Atlas image `97869519007106` (decal `73587184593339`) belongs to `xxLoyalAcExx`; authenticated Creator Hub showed Open Use. No re-upload or permission change was needed. An anonymous asset-delivery authentication error was misleading.

Fixed `src/client/UI/Components/AtlasIcon.luau`: previously the image was hidden until IsLoaded, preventing the renderer from requesting it. Configured images now remain visible, with the emoji fallback until loading finishes. A shared 0.25-second pending check removes fallback overlap when cached completion does not fire a property signal. Loaded or destroyed icons leave the pending set.

Added `atlas-review.project.json` and `tools/icons/AtlasReview.client.luau`. In the actual Studio client, inspected all 64 crops at 24/32/48 px: **192/192 slots loaded**, labels/crops matched, no cell clipping or lingering fallback overlap. Production HUD icons also visibly loaded in Howard's DigTest place connected through Rojo.

Validation passed: **1,280 client checks; 976 normal server smoke checks; 963 Studio-mode smoke checks; 8 utility checks**. Strict Luau analysis passed with two existing RewardsService API deprecation warnings. Changed production/diagnostic files passed formatting; Rojo builds and diff whitespace checks passed. Regression coverage includes cached image completion without notification and switching back to a raw fallback.

Local review evidence: `build/review/atlas-loaded.png`. Diagnostic place: `build/AtlasReview.rbxlx`. Full game diagnostic build: `build/AtlasFixGame.rbxlx`. Build artifacts are ignored/local and can be regenerated; implementation and diagnostic sources are pushed.

## Testing workflow and tools

Howard normally uses the existing `build/DigTest.rbxl`: pull updates, start/restart `rojo serve default.project.json`, connect the Studio Rojo plugin to localhost:34872, then Play. Keep this workflow. Separate generated places are diagnostics.

A Rojo server was left running during the session; Studio DigTest may still be in Play. Recheck current processes and Studio state rather than assuming either survived. Studio DataStores-unavailable/in-memory warnings were expected in the local test.

Rojo executable: `D:\Tools\rojo.exe`. Luau, luau-lsp, StyLua and Roblox definitions are under repository `.tools`. For Windows test bundling set `ROBLOX_DEFS` to the absolute `.tools/globalTypes.d.luau` path and run `python -X utf8 tests/tools/bundle.py`. Type analysis uses the Rojo sourcemap and that definitions file. GitHub CLI was unavailable; PR #7 was created with the GitHub connector. The commit used per-command author `Codex <codex@localhost>` without changing global Git identity.

## Remaining work in the requested order

1. **Finish verification:** atlas loading/crop review is complete, but **real phone and physical controller checks remain pending**. On phone: image loading, safe areas, dig/scan/excavate/sell controls, shop/settings scrolling. On controller: visible selection, traversal, activation, dismissal and restored focus across panels. Record hardware, orientation and failures. Earlier emulator checks do not close this gate.
2. **Polish one complete sequence:** spawn → dig → discover → sell → upgrade, including animation, sound and HUD clarity.
3. **Underground scenery:** Pirate Cove and Crystal Caverns first. Protected scenery pockets must stay outside carve/refill volumes; verify digging and tide refills leave no floating props.
4. **Complete gallery review:** review tools, backpacks, pets, vehicles and treasures at native and thumbnail scale; refine specific weak assets. `gallery.project.json` builds the isolated gallery.
5. **Crowded gameplay:** real-device/full-population profiling, then owned audio, badges and faithful store imagery. Do not invent audio IDs or claim unperformed hardware/performance checks.

Stages 2–5 have not been completed in this continuation. Do not describe the entire polish plan as finished. The hardware gate needs Howard's equipment; continue useful authorized work without repeating unnecessary permission requests.

## Suggested opening message in the next chat

“Continue the Roblox polish in `roblox-dev`. Read `docs/POLISH_HANDOFF.md` and `docs/VISUAL_POLISH.md`, check local and remote updates first, and preserve my intervening work. Atlas fix is in draft PR #7 on `codex/atlas-loading-fix`; real phone/controller verification is still pending. Use my existing DigTest place with git pull and Rojo for testing, and continue the remaining steps in the documented order.”
