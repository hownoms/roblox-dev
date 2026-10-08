# Game direction and publishing review — 8 October 2026

Integration update: `NEXT_STEPS.md` is the current continuation checkpoint. Latest default branch `a5f99b2` adds live pass/product IDs, five configured badges, playtester access records and corrected egg-label anchors; those changes are preserved. Earlier baseline observations remain historical. Repository-facing title/copy now adopts **Dig to the Core!**; the live experience is unchanged by this work. The saved artwork kit includes five originals and six upload-sized exports.

The supplied essays argue for a memorable core interaction and player-generated variety. Our game already has a promising core: follow a signal, carve actual terrain, uncover a surprising object, and descend toward the Core. Feature breadth alone does not establish fun or retention.

## Recommended direction

Position the game as **Dig to the Core!**. Keep “beach treasure hunting” in the opening description, rather than “Beach Simulator” in the title. This is a recommendation, not a deployed rename or a proven audience winner. No title availability or trademark clearance is claimed.

Suggested opening copy:

> What's buried under the beach? Follow signals, uncover strange treasures, and dig through 15 layers toward the Core. Share a beach with other diggers, upgrade your shovel, and see what you find next.

Lead artwork with digging and discovery. Pets and rebirth are supporting progression. Do not advertise cooperative excavation: the present game shares terrain, but first uncoverer owns the find and other players cannot contribute to its excavation.

## Priority order

1. Teach Scan in the first session, then observe whether a newcomer can intentionally hunt another find. Preserve existing tutorial save compatibility. The guaranteed sixth-dig find is an introduction to reward, not proof players understand hunting.
2. Test the second minute with independent newcomers. Observe whether they choose a dig location, follow detector direction/depth, and want another find. Ask “What would you tell a friend this game is?” Record confusion and voluntary behavior before adding retention rewards.
3. Test one opt-in cooperative oversized excavation as a future prototype. Preserve the discoverer's normal reward, grant capped helper rewards, allow solo completion, and prevent stealing. Measure actual cooperation rather than total server sand. This needs design, server validation, regression coverage and ordinary multiplayer playtests before shipping.
4. Consider one favorite-find display near the hub later. Current collections are primarily checkmarks and sold inventory; the reveal models disappear. Test whether a visible personal find creates conversation before building a full museum.
5. Keep the central hub and existing visual identity. Test the return-to-sell navigation and beach social density before moving buildings or shrinking the terrain.

## Current verdict

The game has substantial cohesive static polish, but dynamic visual quality and audio quality are not fully verified. Completed asset/scenery reviews should not be restarted. The remaining work is focused first-session clarity, animated contact, multiplayer interaction, actual sound design/listening, real persistence, and performance attribution.

See `MAP_VISUAL_ASSESSMENT_2026-10-08.md` and `AUDIO_REVIEW.md` for the focused reviews. This review does not certify publication readiness. No Roblox publication, asset upload, spending, audience change, or tester contact was performed.

## Publishing artwork

New artwork belongs in a separate `marketing/publish-kit-2026-10-08/` folder so the existing deterministic art remains intact. Generated promotional illustrations must be labeled as illustrations in our internal manifest and checked against the actual models and world before upload. They are not evidence of native gameplay appearance. Favor short, truthful headlines; exclude unreleased cooperative mechanics, update badges, fabricated UI and guaranteed rare rewards.

Roblox recommends square icons at least 512×512 and landscape thumbnails at 16:9, ideally 1920×1080. Export sizes and small-scale legibility must be verified. No click-through or retention improvement is claimed without an experiment.

Sources consulted:

- https://create.roblox.com/docs/discovery
- https://create.roblox.com/docs/production/publishing/experience-icons
- https://create.roblox.com/docs/production/publishing/thumbnails

## Changes and validation in this review

- TutorialController introduces Scan inside the existing fill-bucket/new-layer objective after the first indexed find, until a server detector response confirms Scan use. It clears the competing sand guide during the hint. Numeric tutorial steps remain unchanged; Scan is optional and full-bag selling/progression still take precedence. `TutorialScanUsed` is a generic persisted preference accepted by SettingsService.
- RideController honours SFX both when creating the engine and while riding, restoring volume when SFX is re-enabled.
- Client checks: 1,398 passed; server checks: 2,174 passed; Studio-mode server checks: 2,153 passed; utility checks: 8 passed. Zero failures. Fresh source bundle regenerated with the pinned Roblox definitions.
- Both changed controllers passed focused strict analysis and formatting checks; `git diff --check` passed. Rojo build produced `build/DirectionReview.rbxlx`.
- Twelve original procedural WAV auditions were generated and measured, with generator/manifest in the repo. They are not integrated or listened to. Five generated image originals yielded a square icon, three thumbnails and two social exports; sizes and small previews were checked.

No fresh Studio session was run. These fixes still need ordinary live readability/mute checks. Changes are now committed for the user-requested push/merge; no live experience rename, publication or upload was performed.
