# Studio review — 9 October 2026 UTC

Checked the isolated Expansion1Review.rbxlx through Roblox Studio MCP. DigTheBeach
was not modified. No uploads or publication. Returned the review session to Edit mode.

## Confirmed in Studio

- Play constructs all 15 displayed models without script errors; 4–51 BaseParts per asset.
- Mara and Pip: Idle, Point and Celebrate poses visually inspected in actual lighting.
- Vault bounds: Covered 12×7.63×8, Partial 12×6.73×8, Opened 12×9.736×8 studs.
  Open lid and spring are readable from the front and elevated approach.
- Anchor progress 0/25/50/75/100% updates successfully on a translated, rotated vault.
  Covers decrease 1.8/1.35/0.9/0.45/0.05 studs; completed cover is transparent.
- Beach ball contact sphere is exactly 7.6 studs in diameter.
- Trophy replica has collision, touch and query disabled on every part.
- Broadwave equips on the current R15 avatar and a temporary R6 dummy, creating
  a RightGrip weld on both. R15 held appearance visually inspected; player avatar retained.
- Ground placement has a deliberate approximately 0.1-stud decorative overlap;
  trophy bottom is 1.725 over the stand's 1.75-stud top.

## Review-scene fixes

Raised the static shovel display to Y=2 because held-tool space is grip-centered.
Reduced label range to 20 studs, size and height to prevent distant labels hiding assets.
Smoothed the sand review floor. Changes saved in Review.server.luau and rebuilt into
the local review place; the open Studio script was updated too.

## Remaining limits

The ball's inherited intersecting ellipsoid panels produce jagged seams up close in
Studio. Further panel polish is recommended before final marketing closeups.
Basic tool equip is verified; two-hand scoop animation, moving/custom-avatar contact,
ball routing/bounce, effect timing and cleanup, streaming, crowded events, real devices,
uploaded UI images and authoritative objectives/rewards remain unverified or unimplemented.
Screenshots were inspected and displayed during the MCP session; they are not saved as
repo image artifacts. Existing offline previews remain explicitly labeled offline renders.
