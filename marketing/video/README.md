# Launch videos

| File | Use | Notes |
|---|---|---|
| `gameplay-preview-v3.mp4` | Roblox game page video slot (Creator Dashboard → Places → Videos) | 53.5 s, 1080p60, silent, gameplay only; no promotional text, voiceover or music, per Roblox's guidance |
| `dig-to-the-core-trailer.mp4` | YouTube, Roblox video ads | 30 s, 1080p60, music "A Game" (Mixkit, see MUSIC_LICENSE.md) |
| `dig-to-the-core-vertical.mp4` | TikTok / YouTube Shorts / Reels | 30 s, 1080×1920, same edit |

All footage is real gameplay of the shipped build (source `ec75979`), recorded in Studio at 60 fps on 19 Oct 2026.
Recording helpers, used only in a throwaway local copy and not shipped: the tutorial skipped, coins and gear granted,
and finds spawned through the game's own DiscoveryService. A screen-watching tapper hit the excavation rings, which
is why every dig is "PERFECT".

Trailer and short source: `trailer/` (Remotion). The clips and music are not committed. `trailer/public/clips/*.mp4`
is cut from the raw takes (see `SECTIONS` in `trailer/src/timing.ts`), and `public/music.mp3` is 74.896 s to 105.4 s
of the Mixkit track. Re-render with `npm run render:trailer` / `npm run render:vertical`.
The mp4s themselves are not committed either; they're too large for git.
