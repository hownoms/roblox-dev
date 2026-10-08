# Publish and next-chat handoff — 8 October 2026

## Latest outcome — publication confirmed

Owner explicitly approved saving pending edits, closing the session and publishing. Normal save was accepted. Studio continued reporting “Applying script changes” on closure, so no forced termination was used. Reconnected the existing owner place to the current Rojo repository, then published directly from that session. Studio Output at 14:25:36 confirmed “Published new changes” and “Place published. Playtesters can now play this place in Roblox.” Version History shows **v15 Published**, titled **Discovery verification - source faa5d8e (PR 26)**. Evidence: `marketing/publication-evidence-2026-10-08/`.

This confirms successful publication of the owner session. It is not a byte-for-byte comparison of the cloud scripts against the generated build. The separate fresh-build replacement failed earlier and was not completed. Before relying on the persistence fixes live, verify the actual published scripts/version and real Player behavior. Version History displays the v15 original autosave time 1:42 PM; publication occurred later. Do not infer script equivalence solely from the release-note title or Rojo connection.

Studio Play is stopped and Rojo was disconnected after publication. The owner window still reports applying script changes when asked to close; it was left open after dismissing that notice. The separate fresh-build window also remains open. Access was not changed, and no public-release, audio/art upload, listening, real save/rejoin or multiplayer result is claimed. Earlier blocked-attempt entries below are history, not a pending approval request. No further approval is needed for the already approved save/close/publish scope.

## Current checkpoint

Fetched origin; working tree clean, local/default remote both `faa5d8e170c8c28c1567e9999512bef1b4a14996` (merged PR #26). CI `37821149887` passed. No intervening remote work. Validation and native evidence: `VERIFICATION_2026-10-08.md`.

Owner now authorizes publication. Built merged source using `rojo build default.project.json -o build/Publish-faa5d8e.rbxlx`; succeeded. SHA-256 `3c733d2e8bb4cd61c98d55142e32eb30f94784cb9b519820f4b9cebfc34db260`. Ignored build can be regenerated from this source.

## Publication attempt — blocked, not successful

Desktop available. Opened fresh build in separate Studio window, chose Publish to Roblox As, selected existing **Dig to the Core! Beach Simulator** Limited experience and its existing same-named place. Roblox refused replacement because an active Team Create session listed owner `xxLoyalAcExx`; publish dialog displayed **Save failed**. No success/new place version claimed.

Asked the existing owner window to close. Studio displayed “Applying script changes. Studio will close automatically when complete.” Automatic approval review initially rejected acknowledging it because closing the active session could affect unsaved work. Owner explicitly approved closing and publishing; acknowledged the dialog, but the session remained open. Disconnected Rojo to prevent further sync and attempted normal save to preserve pending edits. Automatic approval review rejected that separate save as an external persistent change requiring specific permission. Save/close/publish approval is now pending. No workaround was attempted. Preserve session work before retrying; re-observe windows rather than reuse coordinates.

No access change, public release, title change, currency spending, tester contact or asset upload occurred. Publishing code does not make the experience Public. Previously verified: universe `10769863381`, start place `135511260983800`, Limited → Playtesters, eight passes, six products, five badges, Max Players **50**. Recheck before changing configuration.

Audio remains unlistened candidate sketches, without selected integrated cues or owned IDs. Artwork is illustrated; native captures are evidence rather than finished publishing media. These drafts are not completed gameplay/audio, and no moderation success is claimed. Complete review/integration and report actual uploads individually.

## Next chat: work in this order

1. **Verify published source and the player build.** Confirm v15 scripts match merged source, especially DataService's live acquisition-failure refusal. Resolve the applying-script-changes state safely and use the fresh built artifact if a replacement is needed. Publication is already confirmed; avoid duplicate universes. Keep Limited access while checks remain incomplete. Ordinary save → leave → rejoin must preserve coins, bag, equipped shovel, finds and tutorial. Never wipe existing saves.
2. **Make the second minute memorable.** Test a no-pass fresh-player loop and existing-save loop with normal inputs: first hint → readable Scan direction → deliberately uncovered second treasure → readable named reveal → full bag → world Sell → meaningful upgrade. Measure hesitations/time-to-second-find. Fix detector direction/depth, timed excavation feedback and offscreen Sell guidance from observed friction. Independent newcomer feedback remains needed; contact requires authorization.
3. **Finish comfortable sound.** Listen to twelve WAVs alongside several minutes of play. Select/refine cues, repetition and perceived loudness. Verify SFX OFF before mounting, during driving, after re-enabling and on dismount/respawn. Upload selected cues, use real owned/permitted IDs, and verify playback; no invented IDs/listening claims. Deep stone/underground/rare cues remain missing.
4. **Check moving contact and underground discovery.** Observe shovel strike contact and pet follow/dig/park over slopes, holes and height changes. Verify deep clues/finds and crowded readability. Keep completed static asset/scenery reviews closed. Prioritize treasure hunting over more simulator systems.
5. **Prove multiplayer reliability/performance.** Real permitted clients must test shared holes, natural tides, recovery and reward isolation. Profile populated servers with existing labels and attribute spikes before optimizing. Test real save/rejoin first; scoped disposable profiles for lock/interruption/shutdown diagnostics. Mocks do not pass these gates. Review live 50 players versus intended 16 before release.
6. **Finish faithful launch media.** Capture clean full-resolution native beach, successful named reveal and underground gameplay. Finalize icon/thumbnails with truthful illustration labeling; upload approved exports and verify moderation. Complete remaining badges/product artwork/configuration as needed. Cooperative excavation remains a future prototype, never a current-feature claim.

Start with Git status/fetch preserving new work. Read this, `NEXT_STEPS.md`, `VERIFICATION_2026-10-08.md`, `AUDIO_REVIEW.md` and `RELIABILITY_REVIEW_2026-10-08.md`. Prefer current source/fresh live evidence over history. Commit/push/merge justified changes after CI, documenting exactly what is published and still open.
