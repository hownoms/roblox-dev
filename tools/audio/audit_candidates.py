"""Read-only PCM/manifest verification. Measurements do not establish listening quality."""
from pathlib import Path
import hashlib
import json
import math
import struct
import wave

ROOT = Path(__file__).resolve().parents[2] / "assets/audio/original-v1"


def main():
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    expected = {item["file"] for item in manifest["sounds"]}
    assert len(expected) == len(manifest["sounds"]), "Duplicate manifest entries"
    assert expected == {path.name for path in ROOT.glob("*.wav")}, "WAV inventory mismatch"
    for item in manifest["sounds"]:
        path = ROOT / item["file"]
        assert path.parent == ROOT and path.suffix == ".wav", "Invalid candidate path"
        with wave.open(str(path), "rb") as wav:
            assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate(), wav.getcomptype()) == (
                1, 2, 48000, "NONE"
            ), f"Unexpected format: {path.name}"
            frames = wav.getnframes()
            data = struct.unpack(f"<{frames}h", wav.readframes(frames))
        assert frames > 0 and len(data) == frames, f"Empty/truncated: {path.name}"
        peak = max(abs(x) for x in data)
        assert 0 < peak < 32767, f"Silent/full-scale candidate: {path.name}"
        rms = math.sqrt(sum(x * x for x in data) / frames) / 32768
        measured = {
            "seconds": frames / 48000,
            "peak_dbfs": round(20 * math.log10(peak / 32768), 2),
            "rms_dbfs": round(20 * math.log10(rms), 2),
        }
        boundary = abs(data[0] - data[-1])
        if item["loop"]:
            interior = max(abs(b - a) for a, b in zip(data, data[1:]))
            measured.update(
                loop_boundary_step_pcm=boundary,
                maximum_interior_step_pcm=interior,
                boundary_under_maximum_interior=boundary <= interior,
            )
        else:
            assert data[0] == data[-1] == 0, f"Nonzero one-shot endpoint: {path.name}"
        for key, value in measured.items():
            assert item[key] == value, f"Manifest mismatch: {path.name} {key}"
        print(json.dumps({"file": path.name, **measured,
                          "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}))
    print(f"PASS: {len(expected)} PCM candidates match the manifest; listening remains pending.")


if __name__ == "__main__":
    main()
