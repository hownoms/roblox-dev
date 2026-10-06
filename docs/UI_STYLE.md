# UI Style Guide (v3 restyle)

This guide comes from the owner's reference screenshots, which were top simulator games. We
take the **style**, never the content. The look is the reference's chunky, outlined simulator
style in our beach palette.

## Visual language
- **Outlines everywhere.** Panels, buttons, cards, icons and big text all get a thick near-black
  outline (`#1b1b24`): 3–4 px on panels and buttons, and 2–3 px `UIStroke` on text. Nothing is
  outline-less except small body text on dark panels.
- **Font.** Use a chunky rounded display font (FredokaOne/GothamBlack class) for titles,
  buttons and numbers, always with the dark text stroke. Text colour carries meaning: green
  `#5CE65C` for coins/money, sky-blue for boosts/time, gold for rare, white for neutral.
- **Toy buttons.** A bright fill, a lighter strip along the top third (`UIGradient`), a darker
  base "lip" 4–6 px below (the shadow frame), a dark outline and rounded corners of 8–12 px.
  Pressing one moves the face down onto the lip.
- **Panels.** The body is deep ocean navy (`#1d2a44` → `#16203a`), optionally with a very
  subtle repeating texture. Each panel has one **header bar** in a saturated colour (sunset
  orange, ocean blue, coral, palm green, chosen per panel) holding the panel icon, a big
  outlined title and a **red square ✕** close button on the right. Inner cards are slightly
  lighter navy with a dark outline.
- **States.**
  - Selected / current: a gold outline (3 px) and a slight glow.
  - Affordable price: a green button.
  - Unaffordable: a grey button.
  - Locked: dim, with a lock icon.
- **Icons** come from the image atlas (`Config/IconAtlas.luau`), with emoji as the fallback
  when `AssetId == ""`. Icons are big: on buttons they fill about 70% of the face and may
  overflow the top edge a little.
- **Beach flavour stays in the colours**: sand, ocean, coral, palm and sunset. Don't add busy
  decoration.

## Layout
- **Top-right: currency counters.** Coins (biggest, green number) and Tokens, each a pill with
  its icon overlapping the left end.
- **Top-right, beside the currencies: small round buttons** for Daily (with a "!" badge when a
  reward is claimable) and Settings.
- **Left-centre: menu**
  - Big square buttons in **2 columns**. Each button has its own bright colour and an
    oversized icon, with the label in outlined text across the bottom edge.
  - A red "!" badge sits on the top-right corner when something is waiting: a claimable quest,
    a free daily reward, an affordable upgrade, or a rebirth ready.
  - Entries: Shop, Beach, Eggs, Pets, Index, Quests, Rebirth, Store. Daily and Settings move to
    the top-right.
- **Top-centre: tutorial or objective banner.** A slim dark pill with an icon on the left and a
  short bold line ("Dig the sand!", "Sell your sand!"), plus an optional bouncing arrow beside
  it.
- Keep the bottom-centre (backpack bar plus Surface/Sell/Auto/Ride buttons), the depth meter and
  the right-edge SurvivalHUD where they are, restyled to match.

## Panels
- **Shop (shovels, backpacks, shade): upgrade rows.** One row per item:
  - icon
  - a "current stat" box
  - a ➜ arrow
  - a "next stat" box in an orange highlight
  - a big price button on the right: green if affordable, grey if not
  - for owned items, "Equip" / "Equipped"

  The row text spells out the gain, e.g. "Dig 4×4 → 8×8", "Holds 50 → 120",
  "Shade 6 → 8 studs". Coins only: no Robux button per row.
- **Daily rewards.** A horizontal row of 7 day cards:
  - Each card shows "DAY N" at the top, a big icon, and the amount at the bottom coloured by
    type.
  - The current day has a gold outline; claimed days get a check overlay.
  - Day 7 is a wider jackpot card.
  - A big green **CLAIM** button sits below the row.
- **Reveal popup** for hatches, crates, treasure finds and new shovels:
  - The rarity word in huge outlined letters in the rarity colour ("LEGENDARY!") at the top, with
    a pop-in and wobble.
  - Below it, a dark card with the name in big outlined text, the 3D model in a viewport on the
    left, and stat rows on the right (RARITY, SAND BONUS, DIGS: <layer>, RIDEABLE).
  - Sparkles. Tap anywhere to close.
- **Eggs and crates.** Cards in the same style, showing the odds list with rarity-coloured
  names and big Hatch ×1 / ×3 buttons.
- **Toasts.** Short dark pills with an icon, stacked under the top-centre banner.

## Rules
- **Phone first.** Every touch target is at least 44 px, and the layout is checked at about
  800×360.
- No emoji inside `TextScaled` labels. Use the icon atlas, or emoji through `Style.Icon`, which
  has the fixed sizing.
- No Robux logo art. Show Robux prices as "R$ 99" text only.
