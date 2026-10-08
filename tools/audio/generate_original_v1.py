"""Generate original procedural audition sounds, without external samples or dependencies.

Run from anywhere: python tools/audio/generate_original_v1.py
These are editable synthesis sketches, not listening-approved production assets.
"""
from pathlib import Path
import json
import math
import random
import struct
import wave

RATE = 48000
OUT = Path(__file__).resolve().parents[2] / "assets/audio/original-v1"
TAU = math.tau
rng = random.Random(8102026)
manifest = []


def noise(n, alpha=0.17, periodic=False):
    raw = [rng.uniform(-1, 1) for _ in range(n)]
    state = 0.0
    if periodic:
        for x in raw[-min(n, 4096):]:
            state += alpha * (x - state)
    result = []
    for x in raw:
        state += alpha * (x - state)
        result.append(state)
    return result


def env(t, attack, decay):
    return (1 - math.exp(-t / attack)) * math.exp(-t / decay)


def write(name, samples, peak, role, loop=False):
    maximum = max(abs(x) for x in samples) or 1
    data = [max(-32767, min(32767, round(x / maximum * peak * 32767))) for x in samples]
    with wave.open(str(OUT / (name + ".wav")), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(struct.pack("<" + "h" * len(data), *data))
    p = max(abs(x) for x in data) / 32768
    rms = math.sqrt(sum((x / 32768) ** 2 for x in data) / len(data))
    item = {"file": name + ".wav", "role": role, "seconds": len(data) / RATE,
            "peak_dbfs": round(20 * math.log10(p), 2),
            "rms_dbfs": round(20 * math.log10(rms), 2), "loop": loop}
    if loop:
        steps = [abs(data[i] - data[i-1]) for i in range(1, len(data))]
        item.update(loop_boundary_step_pcm=abs(data[0] - data[-1]),
                    maximum_interior_step_pcm=max(steps),
                    boundary_under_maximum_interior=abs(data[0] - data[-1]) <= max(steps))
    manifest.append(item)


def tactile(name, duration, tone, decay, grain, role, peak=0.36):
    n = round(duration * RATE)
    bed = noise(n, 0.2)
    grains = [0.0] * n
    # Rounded granular contacts, rather than sharp impulses.
    for _ in range(grain):
        start = rng.randrange(max(1, n // 2))
        length = rng.randrange(120, 550)
        level = rng.uniform(-0.13, 0.13)
        for j in range(min(length, n - start)):
            grains[start+j] += level * math.sin(math.pi * j / length) ** 2
    samples = []
    for i in range(n):
        t = i / RATE
        tail = min(1, (n - 1 - i) / (RATE * 0.02))
        contact = 0.28 * math.sin(TAU * tone * t) * env(t, 0.002, decay * 0.6)
        scrape = (bed[i] + grains[i]) * env(t, 0.014, decay)
        samples.append((contact + scrape) * tail)
    write(name, samples, peak, role)


def notes(name, events, duration, role, peak=0.30):
    samples = [0.0] * round(duration * RATE)
    for start, hz, level, decay in events:
        for i in range(round(start * RATE), len(samples)):
            t = i / RATE - start
            carrier = math.sin(TAU * hz * t) + 0.14 * math.sin(TAU * hz * 2 * t)
            samples[i] += level * carrier * env(t, 0.004, decay)
    fade = round(0.035 * RATE)
    for i in range(fade):
        samples[-1-i] *= i / fade
    write(name, samples, peak, role)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for i, hz in enumerate((105, 117, 96), 1):
        tactile(f"shovel_sand_{i:02}", .39, hz, .085, 25,
                "Soft sand shovel contact variation; audition with visible impact")
    tactile("excavate_tap", .20, 280, .032, 5, "Short tactile excavation hit", .28)
    tactile("ui_click", .075, 420, .012, 0, "Restrained UI click", .20)
    notes("blocked_clank", [(0, 620, .55, .055), (0, 937, .24, .035), (0, 1310, .1, .025)],
          .30, "Short blocked tool contact; deliberately distinct from rewards", .28)
    notes("detector_tick", [(0, 1100, .7, .012)], .09,
          "Quiet detector tick; proximity pitch can still be applied", .21)
    notes("excavate_perfect", [(0, 660, .7, .04), (.038, 880, .5, .06)], .30,
          "Two-note excavation timing confirmation", .28)
    notes("find_reveal", [(0, 392, .7, .18), (.10, 494, .65, .20), (.20, 587, .6, .22),
                           (.32, 784, .65, .28)], 1.20,
          "Original rising discovery motif; reserve for finds", .34)
    notes("sell", [(0, 523, .7, .065), (.055, 659, .6, .085)], .40,
          "Brief sell confirmation, quieter than reveal", .26)
    # Integer cycles over the loop period preserve oscillator phase at wrap.
    duration = 4
    n = duration * RATE
    engine_noise = noise(n, .045, periodic=True)
    engine = []
    for i in range(n):
        t = i / RATE
        motor = sum(level * math.sin(TAU * hz * t) for hz, level in ((48,.45),(96,.20),(144,.08)))
        pulse = .82 + .18 * math.sin(TAU * 6 * t)
        engine.append(pulse * motor + .12 * engine_noise[i])
    write("engine_soft_loop", engine, .20, "Soft synthesized motor audition; 4 second cyclic loop", True)
    duration = 12
    n = duration * RATE
    surf_noise = noise(n, .055, periodic=True)
    surf = []
    for i in range(n):
        t = i / RATE
        swell = .40 + .30 * math.sin(TAU * t / 6) + .12 * math.sin(TAU * t / 12 + .7)
        surf.append(surf_noise[i] * swell)
    write("beach_surf_loop", surf, .15,
          "Filtered noise surf-bed sketch; does not contain gulls, wind recordings, or music", True)
    (OUT / "manifest.json").write_text(json.dumps({
        "status": "AUDITION ONLY — generated and measured, not listened to or Roblox-uploaded",
        "origin": "Original deterministic procedural synthesis; no third-party samples",
        "generator": "tools/audio/generate_original_v1.py", "seed": 8102026,
        "format": "48 kHz 16-bit PCM mono WAV", "sounds": manifest}, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(manifest)} original audition WAVs in {OUT}")
    for item in manifest:
        print(item["file"], item["peak_dbfs"], item["rms_dbfs"],
              f'loop boundary {item["loop_boundary_step_pcm"]}' if item["loop"] else "")


if __name__ == "__main__":
    main()
