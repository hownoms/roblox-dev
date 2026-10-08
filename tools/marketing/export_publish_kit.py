"""Export approved generated originals without changing their content.

Run after placing source images in marketing/publish-kit-2026-10-08/originals.
Only size conversion and JPEG encoding are performed; originals remain intact.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
KIT = ROOT / "marketing" / "publish-kit-2026-10-08"
EXPORTS = [
    ("icon.png", "icon-512.png", (512, 512)),
    ("hero.png", "thumbnail-01-dig.jpg", (1920, 1080)),
    ("find.png", "thumbnail-02-find.jpg", (1920, 1080)),
    ("deep.png", "thumbnail-03-deep.jpg", (1920, 1080)),
    ("social.png", "social-header-1500x500.jpg", (1500, 500)),
    ("hero.png", "social-banner-960x540.jpg", (960, 540)),
]

def main():
    entries = []
    previews = []
    for source, name, size in EXPORTS:
        with Image.open(KIT / "originals" / source) as raw:
            raw = raw.convert("RGB")
            # Tiny ratio rounding is resized; substantially different ratios are letterboxed.
            ratio = raw.width / raw.height
            desired = size[0] / size[1]
            if abs(ratio / desired - 1) < 0.02:
                output = raw.resize(size, Image.Resampling.LANCZOS)
            else:
                output = ImageOps.pad(raw, size, color=(20, 36, 56), method=Image.Resampling.LANCZOS)
            path = KIT / name
            if path.suffix == ".jpg":
                output.save(path, quality=94, optimize=True, subsampling=0)
            else:
                output.save(path, optimize=True)
            assert output.size == size
            assert path.stat().st_size < 3_000_000
            entries.append({"file": name, "width": size[0], "height": size[1],
                            "bytes": path.stat().st_size,
                            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
            previews.append(ImageOps.pad(output, (480, 270), color=(20, 36, 56)))
            if name == "icon-512.png":
                for edge in (64, 150):
                    output.resize((edge, edge), Image.Resampling.LANCZOS).save(KIT / f"preview-icon-{edge}.png")
    sheet = Image.new("RGB", (1440, 540), (20, 36, 56))
    for i, preview in enumerate(previews):
        sheet.paste(preview, ((i % 3) * 480, (i // 3) * 270))
    sheet.save(KIT / "contact-sheet.jpg", quality=92)
    (KIT / "manifest.json").write_text(json.dumps({
        "status": "Prepared illustrations; not uploaded or a native gameplay capture",
        "generation": "Built-in image_gen; exact prompts in PROMPTS.json",
        "recommended_title": "Dig to the Core!",
        "exports": entries,
    }, indent=2), encoding="utf-8")
    print(json.dumps(entries, indent=2))

if __name__ == "__main__":
    main()
