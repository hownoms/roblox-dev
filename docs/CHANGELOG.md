# Changelog and Decision Log: Dig to the Core! Beach Simulator

This file records what we built, what we changed after playtesting, and **why**. Read it
before changing a system, because most "weird" choices have a reason written down here.
Branch: `claude/pensive-meitner-6jx4u4`.

Related docs: `README.md` (setup), `docs/GDD.md` (original design),
`docs/ARCHITECTURE.md` (code contract), `docs/V2.md` (v2 and v2.1 contract),
`docs/design/Survival.md` and `docs/design/Companions.md`, `docs/UI_STYLE.md`, `docs/MAP.md`,
`marketing/STORE_PAGE.md`.

---

## v1: first playable (initial build)
**Built by parallel agents (design, server, client/UI, map, models, marketing, QA).**
- **Toolchain:**
  - A Rojo project with all code in `--!strict` Luau.
  - `tools/check.sh` runs StyLua, the luau-lsp strict typecheck against the Roblox API, and the Rojo build.
  - Headless tests (`tests/run.sh`) run the real server and client code against a strict mock of the Roblox API.
- **Design:** 15 layers from Dry Sand to The Core, 14 shovels, 13 backpacks, pets and eggs, 51 treasures, rebirths, daily streak, quests, codes, Index, High Tide and Golden Hour events, 8 game passes and 9 dev products (ids are placeholders).
- **Server:**
  - Session-locked DataStore saves.
  - Server-authoritative digging, selling, shops, pets, rebirth, receipts, rewards, events, leaderboards and badges.
- **Client:** dig controls for mouse, touch and gamepad, HUD, every panel, hatch animation, tutorial.
- **Map:** built procedurally; 12 plots, hub, boardwalk, pier.
- **Models:** every model is built from parts (no mesh assets).
- **Marketing:** icon, 4 thumbnails, badges, store page.

## v1 playtest fixes (first Studio session)

| Problem seen in Studio | Cause | Fix |
|---|---|---|
| Clicking sand did nothing | Terrain uses 4-stud voxels, and a 2-stud `FillBall` barely changed them | Carve voxel-aligned cubes |
| Digs still ignored ("no solid terrain") | The visible smooth-terrain surface is about 2 studs **above** the voxel grid, so the click point sat in the empty voxel | The server re-raycasts from the player and steps into the surface along the normal |
| Sell pad did nothing | The thin pad was buried under the visible surface | Raise the pad, and the server checks players standing over it (no reliance on `Touched`) |
| Every popup appeared twice and eggs hatched twice | A duplicate `Client` folder was left in the saved place | Remove the duplicate; `shared` guards in both Main scripts now refuse to start a second copy |
| Backpack number hidden | Roblox's tool hotbar covered it | Hide the default Backpack CoreGui (the shovel auto-equips) |
| Plot looked unchanged after digging | The dig removed only the partial surface voxel | Dig one voxel deeper and clear the voxel above |

Also added: Studio-only dev chat commands (`/coins /max /dig /rebirths /wipe /surface`, later
`/tide /pet`).

> **Lesson recorded:** smooth terrain's visible surface sits about 2 studs above layout or voxel
> heights. Anything placed "on the ground" must raycast for the real surface. This bit us four
> times: digs, the sell pad, egg pedestals, and the fountain and towels.

## v2: owner redesign after playtest 2
**Owner decisions:**
- **Map:** no plots. The whole beach is diggable along a longer coastline, and all digging happens on the water side.
- **Tide refill:** holes refill after about 4 minutes idle. High Tide lifts players out of holes first, then smooths the beach.
- **Heat:** a soft slowdown: Sunburnt means slower digging, never damage. It comes with shade players can place, a water fountain and snacks.
- **Diggers:** digger companions, at first a separate Garage system.
- **Max players:** 16.
- **Smaller beginner digs.**

**Polish from feedback:**
- Glow was painful to look at, so lighting is softer and neon is clamped.
- The shovel looked like "a stick out of the arm", so it gets a diagonal grip.
- Tiny icons, so items are framed to fill their viewports.
- The "backpack full" message appeared twice, so duplicates were removed.

## v2 playtest fixes
- **Tiny text and icons:** the real cause was that **emoji inside `TextScaled` labels shrink the whole label** (emoji have tall line metrics). Labels containing emoji now get an explicit, fitted `TextSize`.
- **Egg labels and pedestals sunk into the sand:** raised to the visible surface. The fountain and props now raycast for the ground.
- **`rbxasset://sounds/swoosh.wav` "not approved":** replaced with other built-in sounds.
- **Starter dig:** a hand-spade dent (rounded `FillBall`) instead of a full voxel. A true 2×2×2 dig is impossible on 4-stud terrain.

## v2.1: companions merge, shovel feel, ride-on, UI restyle
**Owner decisions:**
- Diggers become **pets** from **Construction Crates**. Some creature pets dig too, and the Garage is removed.
- A **rideable Mythic excavator** drops from the top crate at 0.5%.
- Existing digger saves are converted to pets.
- The starter tool is a **Hand Spade**, full shovels are held **two-handed**, and the dig is an **upward scoop**.
- The UI restyle follows the owner's reference screenshots (chunky outlined toy style in a beach palette), and icons are picture icons from a generated atlas.

**What was built:**
- **Shovels:** Hand Spade and Garden Trowel are one-handed, and the rest are full-size.
  - `ShovelPoseController` poses both arms with client-side IK for every player.
  - The scoop animation tosses a sand clump, and the `Scoop` remote shows other players' scoops.
- **Companions:**
  - 12 vehicle pets and 7 digging creatures, plus 4 crates in a crate yard.
  - `PetDigService`: each pet digs its own spot on a 6–12 stud ring around the owner, never underneath them.
  - The `PetDug` remote, and a save migration from Diggers to pets (`DATA_VERSION` 2).
- **Ride:** `RideService` and `RideController`.
  - A constraint-driven vehicle with network ownership given to the rider.
  - Server-validated: anti-teleport with 3 strikes.
  - Digs ahead of itself (minimum 12-stud cube), and the ridden pet stops pet-digging.
- **UI:**
  - Components: `AtlasIcon` (atlas image with emoji fallback), toy buttons, navy panels with colour header bars.
  - Layout: currency counters top-right with round Daily and Settings buttons, a 2-column menu, and a `Layout` module tested at 12 screen sizes.
  - Panels and popups: upgrade-row shops, daily reward cards, the unified `Reveal` popup, and the objective banner.
- **Icons:** 64-icon atlas `assets/icons/atlas.png`. **The owner must upload it and paste the image id** into `src/shared/Config/IconAtlas.luau` (`ASSET_ID`).

## v2.2: research-driven (in progress)
Based on the owner's research on top Roblox simulators and tycoons. The plan:
- **Batch A, compliance and fundamentals:**
  - True modified odds whenever luck is active.
  - `PolicyService` gating of paid random items.
  - Remove the Cooler Pack, since it was paid relief from heat friction we created.
  - Show menu items only once they're relevant.
  - Server and weekly leaderboards.
  - A detailed analytics funnel.
- **Batch B, retention:**
  - Pets keep digging while you're offline, capped.
  - A rebirth token perk shop, with a recovery preview and a faster first rebirth.
  - Overhead titles and rebirth stars, a worn backpack, and rare-find announcements.
  - Hatch pity and duplicate fusion.
  - Free Sell Anywhere through a rebirth perk.

---

## Standing rules (learned the hard way)
1. **Ground placement:** raycast for the visible terrain surface. Never place things at grid height.
2. **Untrusted clicks:** never trust a client position to be inside solid terrain; resolve it on the server.
3. **Emoji in text:** never put emoji in `TextScaled` labels; use `AtlasIcon` or `Style.Icon`.
4. **Sounds:** only built-ins we've verified load, plus owned audio.
5. **Paid randomness:** show true odds including every active modifier, and check `PolicyService`.
6. **Studio check:** every gameplay change needs a playtest. Headless tests catch logic errors, not feel or visuals.
7. **Agent edits:** agents edit only the files they own, plus small additive edits to shared files.
