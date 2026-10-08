# Published-build verification and second-minute playtest — 8 October 2026 (afternoon)

Started from clean `9cb8f9d` (merged PR #28) after fetching; no intervening source changes since `faa5d8e`. Evidence screenshots: `marketing/playtest-evidence-2026-10-08-pm/`.

## Studio state found, and one unintended closure

Bringing Studio forward via the desktop launcher ran the Roblox Studio installer (update to `version-9b554450a0fc4e65`), which closed both open Studio windows: the owner Team Create window still reporting "Applying script changes" and the separate fresh-build window. This was not a forced kill by us, but it is the closure the brief asked to avoid. The owner log at 18:26 had recorded "Failed to close place as commit is still in progress". Work was already published and saved (see below), and the fresh cloud copy matches source, so no loss is evident. Future sessions: do not launch "Roblox Studio" from the Start menu while windows are open; focus existing windows instead.

## 1. Published scripts match merged source (verified)

- Studio Version History: **v15 Published** ("Discovery verification - source faa5d8e (PR 26)"). A later **v16 Saved** (2:41 PM, not published) appeared around the time "Download a Copy" was used on the cloud place; a save does not change what players get.
- Used Version History → v15 → **Open local copy**, saved it to file and parsed every Script/LocalScript/ModuleScript with a binary `.rbxl` reader. Compared with `rojo build` of `9cb8f9d` (identical `src` to `faa5d8e`): **157 / 157 scripts byte-identical** (CRLF-normalised SHA-256), none empty, none missing. `DataService` hash `2440fe7b…7447` matches `src/server/Services/DataService.luau`, so the live handle-failure refusal is published. The current Team Create copy also matches 157/157.
- The live server joined below reported `game.PlaceVersion = 15`.

## Real save → leave → rejoin (live DataStore, existing owner save, verified)

Owner account, ordinary Roblox Player join of place `135511260983800`; read-only snapshots via the owner server console (`DataService.Get`, `IsMock() = false`). No wipe, no dev grants. Ordinary play changed the save: HUD Sell (owned pass) and digging.

| Field | On join | Before leave | After rejoin (new server, 14:52:05) |
|---|---|---|---|
| Coins | 19,884 | 19,930 | 19,930 |
| Sand | 40 | 40 | 40 |
| Shovel (equipped) | garden_trowel | garden_trowel | garden_trowel |
| Backpack | bucket | bucket | bucket |
| Unsold finds | 1 | 0 | 0 |
| Index / variants | 4 / 10 | 4 / 10 | 4 / 10 |
| Max depth | 49 | 49 | 49 |
| Tutorial | 7 | 7 | 7 |

The rejoin landed on a different server, so values came from the DataStore rather than server memory. A later idle disconnect (20 min) also ended the session normally. Lock contention, interrupted writes and shutdown deadlines remain untested in live.

## 2. Second minute: fresh no-pass playtest (Studio local server + client, in-memory data)

`Test → Server and Clients` with one client (Player1, no passes: "Sell R$" / "Auto R$", 20-slot bucket, 0 coins). Ordinary mouse/keyboard input through computer use; my screenshot round-trips (~4–5 s) are much slower than a human, so excavation grades are not representative.

Observed friction before fixes:

1. **Detector pointed sideways at a find below.** Scans repeatedly read "Cool · DOWN" while the compass dot/arrow changed direction as I walked; digging straight down at the spot reached the find at ~5 m. Cause: band uses 3D distance; a deep find under the player still has a tiny, noisy horizontal sector.
2. **Direction cues were hard to see.** The radar dot hid under the DOWN pill when the find was ahead and under the cursor/thumb after pressing Scan. The world arrow lay at foot level, where the bottom action row covers it in the default camera, and was white at up to 44 % transparency on pale sand.
3. **Full bag → Sell took ~75 s.** The camera faced the sea when the bucket filled; beam and edge badge existed but I walked past the pad around the side of the stand and ended up behind it with the camera under the awning.
4. **First upgrade unaffordable.** First bucket sold for 28 coins (20 sand + damaged finds) and the tutorial immediately sent me to buy the 30-coin Garden Trowel.

Fixes (this change):

- `Finds.Overhead` / `DetectorPing.Overhead` (coarse boolean; whitelist test updated, still no positions): find is below/above with horizontal offset ≤ max(3, |dy|×0.5). Client hides the compass dot, the pill says **DIG DOWN HERE!**, and the world arrow stands up in front of the character pointing down.
- World arrow larger (0.7×3 shaft), dark `SelectionBox` outline, transparency ≤ 0.28, at hip height instead of the feet. HUD pill raised clear of the dot and widened.
- Tutorial "shop" step: while the next coin shovel is unaffordable the banner reads "Dig & sell more for the Garden Trowel! (22/30)" (or "Bucket full! Sell it…") and the guide points to sand / the sell stand; numbered progress unchanged.
- Onboarding-only camera turn (`GuideController.TurnCameraToward`): when the sell moment begins and the stand is > 60° off view, the default camera swings once (0.7 s, instant with Reduced Motion) to face it.

Retest after fixes (fresh Player1): full bucket → camera turned to the hub → walked straight onto the pad in under 4 s of walking (+22 coins); banner showed 22/30 and guided back to sand; second bucket → +15 (37) → banner returned to the shop → Shovel hut → **Garden Trowel bought** ("Now digs Shell Bed · +50 % sand · +9 % speed"), tutorial 6/7. Detector showed the hip-height outlined arrow and, near a find below, "Warm · DIG DOWN HERE!" with a vertical arrow. Readable named reveal cards observed naturally: "Large Bottle Cap" (NEW VARIANT, Damaged, 9 coins) and "Tiny Bottle Cap" (NEW, 2 coins). Repeat common finds only float their name for ~1.25 s; not changed (not observed directly).

Not certified: excavation timing comfort for real players (my input latency), independent newcomer behaviour, existing-save loop in Studio (covered live above and by resume tests). Chat covering the menu in the Studio test client is a test-place artefact (legacy chat); the published place uses TextChatService and docked chat bottom-left in the live session.

## 5. Multiplayer (local Studio replication only)

Two local clients on one Studio server: both saw each other, shared server goal scaled (3/5K → 3/6K), Player2 uncovered a find near Player1's signal and owned it; Player1's bag/coins were unaffected. This is Studio replication, **not** real-service multiplayer; tide/recovery with real clients and populated profiling remain open.

## 3. Audio (measured, not listened)

No listening occurred; nothing was integrated or uploaded. Engine-mute through mount/drive/toggle/dismount was **not** verified live: the Studio-only pet grant could not be confirmed in the test place (legacy chat ignored `/pet`; command-bar output not visible). Existing ride regressions still cover volume assignment.

EBU R128 loudness (one-shots padded to one 400 ms window, so comparable with each other, not absolute):

| File | LUFS (window) | True peak |
|---|---|---|
| find_reveal | −20.7 | −9.4 dBTP |
| sell | −24.5 | −11.7 |
| engine_soft_loop (integrated) | −24.6 | −14.0 |
| shovel_sand_01/02/03 | −24.6 / −25.6 / −25.8 | −8.9 |
| excavate_perfect | −24.9 | −11.0 |
| blocked_clank | −27.5 | −11.0 |
| excavate_tap | −29.6 | −11.1 |
| detector_tick | −31.7 | −13.6 |
| beach_surf_loop (integrated) | −32.3 | −16.5 |
| ui_click | −35.3 | −13.8 |

Measurement-based mix notes for the listening pass: the engine loop is ~5 dB louder than excavation taps and ~7 dB louder than the detector tick, so at equal runtime gain it would mask both while riding; routine shovel contacts sit level with the sell reward. Start the engine ≥ 8 dB under taps and digs ~4 dB under sell, then judge by ear.

## Remaining gates

Listening and cue selection; owned/uploaded audio IDs; live engine-mute check; real multi-account multiplayer, natural tide/recovery and populated profiling; independent newcomer playtest; animated shovel/pet contact and underground discovery review; full-resolution native launch media; Max Players still 50 (intended 16) — unchanged, needs authorization. Superseded below: the fixes were published as v17 on owner request.

## Publication v17 and store artwork (owner-authorized, 8 Oct ~15:37 local)

Owner asked to update the game images from `marketing/` and publish everything for a playtest with a friend.

- Rojo (this checkout, merged `375625c`) synced into the existing owner Team Create place; published with notes **"Second-minute fixes - source 375625c"**. Studio Output: "Published new changes… Place published. Playtesters can now play this place." Version History shows **v17 Published**.
- Verified like v15: v17 → Open local copy → saved `build/v17-published-2026-10-08.rbxl` → **157/157 scripts byte-identical** to a fresh `rojo build` of `375625c`.
- Creator Hub (owner's signed-in Chrome): **icon** replaced with `publish-kit-2026-10-08/icon-512.png` (saved; shown in the dashboard sidebar). **Thumbnails** (Experience Detail Page list): `thumbnail-01-dig.jpg` (first), `thumbnail-03-deep.jpg`, `thumbnail-02-find.jpg` uploaded and order saved; they persisted after reload. Roblox moderation status not confirmed; Home Page personalised thumbnails were not set. These are illustrations, not gameplay captures.
- Not changed: access (Limited; dashboard shows "Ages 16+ and trusted friends"), Max Players (50), title, prices, badges, audio. A friend can join only if they are permitted under the current Limited/playtester setup; adding them needs the owner's decision.
