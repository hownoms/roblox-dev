# Audio review — 8 October 2026

Source review establishes routing and configured assets. No listening, waveform inspection, published-experience permission verification, or physical-device check was performed in this review. Audio cannot yet be called publication quality.

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

Record each chosen audio asset's source/creator, usage permission, experience access, duration, and intended role. Do not paste arbitrary public asset IDs. No audio files were found in the repository, and no new IDs or uploads were made.

Listen in fresh Studio and the authorized private experience: first spawn, five minutes of digging, scan bands, early/perfect/late excavation, common/rare reveals, sell, upgrade, hatch, rebirth, surface/deep transitions, full backpack, three pets, moving vehicle, and a populated server. Check SFX and Music toggles before/while loops play, respawn, and ride dismount. Verify headphones and a phone speaker at moderate volume. Listen for clipping, piercing detector tones, abrupt loop seams, excessive repeated rewards, and audible action/animation mismatch. Save actual listening notes before closing the audio release gate.

