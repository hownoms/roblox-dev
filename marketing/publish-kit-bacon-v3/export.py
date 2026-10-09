from pathlib import Path
from PIL import Image, ImageOps
import json

KIT = Path(__file__).resolve().parent
SOURCES = Path('C:/Users/howar/.codex/generated_images/01a11dd6-fdab-74b3-938f-65bcfce402d4')
FILES = {
    'icon': 'exec-5744b4f6-c840-40ab-92fe-f468ed86a2b1.png',
    'hero': 'exec-6abf42d5-2b1d-40be-b83a-89b1c311f5fd.png',
    'find': 'exec-ea15d27c-cae7-4bbb-8704-8dd48965f6f3.png',
    'deep': 'exec-9c474554-c5bb-4f97-a1a3-e864f0d1726a.png',
}
EXPORTS = [
    ('icon', 'icon-512.png', (512, 512)),
    ('hero', 'thumbnail-01-dig.jpg', (1920, 1080)),
    ('find', 'thumbnail-02-find.jpg', (1920, 1080)),
    ('deep', 'thumbnail-03-deep.jpg', (1920, 1080)),
    ('hero', 'social-banner-960x540.jpg', (960, 540)),
]

(KIT / 'originals').mkdir(exist_ok=True)
for key, source in FILES.items():
    (KIT / 'originals' / f'{key}.png').write_bytes((SOURCES / source).read_bytes())
manifest = []
sheet = Image.new('RGB', (960, 540), '#152638')
for i, (key, name, size) in enumerate(EXPORTS):
    with Image.open(KIT / 'originals' / f'{key}.png') as raw:
        image = raw.convert('RGB').resize(size, Image.Resampling.LANCZOS)
        path = KIT / name
        if path.suffix == '.jpg':
            image.save(path, quality=94, optimize=True)
        else:
            image.save(path, optimize=True)
        with Image.open(path) as check:
            assert check.size == size
        assert path.stat().st_size < 3_000_000
        manifest.append({'file': name, 'size': size, 'bytes': path.stat().st_size})
        if i < 4:
            sheet.paste(ImageOps.pad(image, (480, 270), color='#152638'), ((i % 2)*480, (i // 2)*270))
        if key == 'icon':
            image.resize((64, 64), Image.Resampling.LANCZOS).save(KIT / 'preview-icon-64.png')
sheet.save(KIT / 'contact-sheet.jpg', quality=94)
(KIT / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(json.dumps(manifest))

