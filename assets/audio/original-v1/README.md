# Original audio auditions v1

Twelve original procedural sound candidates, generated locally without external samples, libraries, services, or audio asset IDs. These are synthesis sketches for audition, not approved production sounds. Nobody listened to them as part of this generation pass.

All files are mono 48 kHz, 16-bit PCM WAV. `manifest.json` records durations, sample peak/RMS, and loop boundary measurements. Peaks are deliberately below full scale, but RMS measurements are not a substitute for perceived-loudness matching or listening.

| Files | Candidate role |
|---|---|
| shovel_sand_01/02/03.wav | Three soft sand contact variations |
| blocked_clank.wav | Tool cannot dig this material |
| detector_tick.wav | Quiet scan cue, pitchable for proximity |
| excavate_tap.wav / excavate_perfect.wav | Ordinary and perfect timing feedback |
| find_reveal.wav | Original rising discovery motif |
| sell.wav / ui_click.wav | Routine transaction and UI confirmation |
| engine_soft_loop.wav | Soft synthesized vehicle motor, 4-second loop |
| beach_surf_loop.wav | Filtered-noise surf sketch, 12-second loop |

The engine and surf generators use periodic modulation, phase-aligned oscillators, and filter warm-up from the preceding loop tail. Their wrap steps are below the maximum interior sample step. This verifies numerical boundary continuity relative to the interior, not an inaudible loop. Listen across at least five repetitions before accepting either.

Reproduce from the repository root: `python tools/audio/generate_original_v1.py`. The fixed seed reproduces the same pack. Edit synthesis parameters there instead of repeatedly processing the WAVs.

Audition first with headphones at moderate volume, then in a phone-speaker gameplay mix. In particular, the surf is noise synthesis rather than a field recording, and the engine is a motor tone rather than a recorded excavator. Discard them if they sound artificial in context. Compare repeated digging comfort, detector harshness, timing clarity, and whether reveal sounds distinct from selling. See `docs/AUDIO_REVIEW.md` for the fuller acceptance checklist.

These are ordinary local WAVs, not Roblox sound IDs. No game config changes, audio uploads, experience permissions, or publication occurred. Upload only selected listening-approved candidates into the appropriate Roblox owner account and grant the experience access before wiring the returned IDs.
