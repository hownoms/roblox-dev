# Audio review — 8 October 2026

Source review establishes routing and configured assets. The candidate audit below adds PCM measurements; it does not establish listening quality. No listening, published-experience permission verification, or physical-device check was performed. Audio cannot yet be called publication quality.

## Current state

- `Config/Sounds.luau` contains 20 short SFX roles backed by five distinct Roblox client built-in files. `MusicBeach`, `MusicDeep`, and `Ambience` are empty and silent.
- Sell, coin, treasure, rare treasure, purchase, hatch, new layer, rebirth, detector, and perfect excavation reuse `electronicpingshort.wav` at different speeds. Their events are implemented, but a distinct discovery identity has not been authored.
- Digging uses slowed plastic footsteps, emergence uses an even slower version, and the ride engine loops that same plastic footstep asset. These are functional placeholders whose appropriateness needs actual listening.
- Tool heft already lowers dig pitch and raises volume; ordinary swings have pitch variation. Detector pitch changes with proximity. These are useful gameplay feedback mechanisms to preserve.
- Sale sound duplication is deliberately avoided in Toasts, and coin flight calls its arrival sound once. Pet swings are quieter than player digs. Those safeguards already exist.
- SoundController separates Music and SFX switches. Beach ambience follows SFX and stops below 20 m. The ride engine previously bypassed the SFX setting; the accompanying change mutes it on entry and while riding, and restores volume when SFX is enabled.
- Short effects are local and global rather than attached to digging points. Ride engine is spatial and local to the rider. Nearby players do not currently create an audible shared digging scene.

## Priority creative work

1. Give the core action a satisfying shovel contact: brief scrape, granular sand release, low soft impact. Prepare at least three subtle variations. Author a harder stone contact for deep layers and a separate blocked clank. Match impact to the visible shovel contact, then listen for whether continuous digging remains comfortable for five minutes.
2. Give discovery an unmistakable identity: restrained detector tick, tactile excavation taps, and a short rising reveal motif. Make rare finds richer rather than merely slower and louder. Reserve the strongest musical resolution for rare discovery or rebirth, so routine purchases do not sound equally important.
3. Replace the footstep engine loop with a seamless excavator motor idle/run loop; retain speed-responsive pitch. Keep the engine underneath excavation and discovery feedback.
4. Add a subtle beach bed (surf, light wind, sparse gulls) and an underground bed. Surface audio should fall away with depth. Start with ambience before committing to constant music; discovery should still feel quiet, curious, and tactile.
5. Use distinct low-profile UI click/error, sell/coin, hatch, and progression stings. Avoid inventing twenty elaborate sounds just because twenty keys exist. A small coherent family is preferable.

## Implementation follow-up after assets exist

- Keep repeated digs/pet sounds below discovery cues; review cumulative loudness with multiple pets and a vehicle. Config Volume values alone do not prove a balanced mix because source loudness and spectral content differ.
- Add music/ambience crossfades and a small boundary hysteresis once those assets are configured. Current depth changes abruptly stop/start tracks at 20 m; repeated crossing could restart them repeatedly.
- Preload the small high-priority contact/UI/reveal palette asynchronously, with graceful missing-asset behavior. Do not block joining on an entire music library.
- Consider capped, distance-attenuated remote digging/rare discovery effects only after crowded-server listening. Social sound must add awareness without a constant wall of pings.
- If continuous effects accumulate, add an explicit voice limit per category; test this with actual asset durations before choosing limits. No arbitrary cooldown has been introduced in this review.

## Asset and listening acceptance

Record each chosen audio asset's source/creator, usage permission, experience access, duration, and intended role. Do not paste arbitrary public asset IDs. Twelve original audition WAVs now exist in `assets/audio/original-v1`; their manifest records deterministic procedural synthesis without third-party samples. No new IDs or uploads were made, and these files are not integrated into gameplay.

Listen in fresh Studio and the authorized private experience: first spawn, five minutes of digging, scan bands, early/perfect/late excavation, common/rare reveals, sell, upgrade, hatch, rebirth, surface/deep transitions, full backpack, three pets, moving vehicle, and a populated server. Check SFX and Music toggles before/while loops play, respawn, and ride dismount. Verify headphones and a phone speaker at moderate volume. Listen for clipping, piercing detector tones, abrupt loop seams, excessive repeated rewards, and audible action/animation mismatch. Save actual listening notes before closing the audio release gate.

## Follow-up source and PCM audit — 8 October 2026

`python tools/audio/audit_candidates.py` independently decoded all twelve committed WAVs and passed. It checks the inventory, 48 kHz mono 16-bit PCM format, durations, peak/RMS values against the manifest, nonzero energy, absence of full-scale samples, and zero endpoints for one-shots. It prints SHA-256 hashes for identifying the exact audition bytes. No candidate bytes were changed.

- Three 0.39-second sand contacts peak at -8.87 dBFS; RMS spans -24.89 to -26.05 dBFS. Their generator uses the same filtered-noise/granular recipe with 96–117 Hz contact tones.
- Detector is a 0.09-second 1100 Hz tone before gameplay proximity pitch. Perfect timing is a short 660/880 Hz pair. Reveal rises through 392/494/587/784 Hz over 1.2 seconds. Sell uses 523/659 Hz over 0.4 seconds. This supports a proposed restrained contact/tick/reveal hierarchy, but sustained detector comfort and repeated tonal rewards still require listening.
- The engine's 4-second loop has a 101 PCM-unit wrap step versus a 145-unit maximum interior step; surf's 12-second loop has 187 versus 956. Neither wraps with a larger step than its largest interior transition. That is a numerical seam check, **not proof of an inaudible seam**.
- Engine RMS (-20.43 dBFS) exceeds reveal RMS (-21.13 dBFS) before runtime gain. Do not normalize these together or assume peak headroom means a comfortable mix. Audition the engine quietly beneath contact/reveal; three simultaneous pets and driving remain mix acceptance cases.

Keep this candidate family small: sand variations, excavation tap, quiet detector, timing confirmation, distinctive reveal, modest sell/UI feedback, engine, and surf. A deep stone contact, underground bed, and rare reveal are still missing. Do not substitute louder/slower routine rewards for those roles without audition evidence. The current built-in IDs remain placeholders until authorized uploads and experience permission checks exist.

Source review found a mute edge case: ride audio refreshed only after obtaining dig-zone bounds. If those bounds were unavailable, toggling SFX while seated could leave the previous engine gain in place. `RideController` now refreshes gain before the bounds early return. The client suite passed 1,401 assertions with zero failures using repository `.tools` Luau and definitions. Ride regressions cover muted boarding, restoring configured gain and muting while bounds are unavailable, and destruction of the loop on dismount. This establishes volume assignment and loop cleanup; it cannot establish what a player actually hears.

