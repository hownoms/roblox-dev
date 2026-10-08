# Publishing artwork kit — 8 October 2026

Created with the built-in image generation tool. These are promotional illustrations, not native screenshots. Existing marketing originals are preserved. Exact prompts are in `PROMPTS.json`; dimensions, file sizes and hashes are in `manifest.json`.

| File | Use |
|---|---|
| `icon-512.png` | Square experience icon, 512×512 |
| `thumbnail-01-dig.jpg` | Primary thumbnail, 1920×1080; digging and physical discovery |
| `thumbnail-02-find.jpg` | Alternative thumbnail, 1920×1080; unusual Golden find |
| `thumbnail-03-deep.jpg` | Additional thumbnail, 1920×1080; Crystal Caverns exploration |
| `social-header-1500x500.jpg` | Wide social header |
| `social-banner-960x540.jpg` | Landscape social banner |
| `contact-sheet.jpg` | Preview only, not an upload asset |
| `preview-icon-64.png`, `preview-icon-150.png` | Small-scale icon checks, not upload assets |

All upload exports are below 3 MB. Exported dimensions were checked. The contact sheet and 64-pixel icon were visually inspected: subject/action remain recognizable and thumbnail headlines remain readable. This is not audience click-through testing.

Repository branding is **Dig to the Core!**; the live experience title has not been renamed by this work. The latest default branch supplies fifteen badge images and fourteen store images. Five badges and all passes/products have configured IDs; the other ten badge IDs remain zero. This kit preserves that work and does not upload or approve those assets.

## Fidelity limits

Art depicts implemented activity and item/environment families: shovel digging, chest discovery, Golden variants, Ammonite, and crystal side alcoves. It excludes unreleased cooperation, fake rewards and update claims. Illustration rendering is more detailed than the primitive production models: wood/sand texture, avatar hair and lighting are stylized. Background coast/buildings are compositions, not exact map views. The square chest icon has a plain keyhole rather than the production chest's red gem. Before uploading, compare the art with fresh native gameplay captures; favor the hero/discovery images and add at least one real screenshot. Do not describe these illustrations as footage of the actual game.

No assets were uploaded, no publication or audience changes occurred, and no moderation/rights approval or launch readiness is claimed.

## Re-export

From repository root, run `python tools/marketing/export_publish_kit.py`. Preserve `originals/`. The exporter only converts sizes/encoding; it does not regenerate or creatively edit images.

Roblox sources:

- https://create.roblox.com/docs/production/publishing/experience-icons
- https://create.roblox.com/docs/production/publishing/thumbnails
