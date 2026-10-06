# Dig to the Core! Beach Simulator

A Roblox digging simulator. Players dig anywhere along a shared beach, down through 15
layers, from Dry Sand to Pirate Cove, Fossil Bed, Crystal Caverns, Magma and The Core. Sand gets
sold for coins, coins buy better shovels and backpacks, eggs hatch pets, and rebirths give a
permanent multiplier.

Everything is code. The map, models and UI are all built by scripts at runtime, so the whole
game lives in this repo and syncs into Studio with [Rojo](https://rojo.space).

| Doc | What it covers |
|---|---|
| [`docs/CHANGELOG.md`](docs/CHANGELOG.md) | **Start here:** what changed in each version, playtest fixes, decisions and standing rules |
| [`docs/V2.md`](docs/V2.md) | v2/v2.1 contract: open beach, survival, companions, ride |
| [`docs/UI_STYLE.md`](docs/UI_STYLE.md) | UI style guide and layout map |
| [`docs/GDD.md`](docs/GDD.md) | Original game design: loop, layers, economy, retention, monetization, roadmap, launch checklist |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Code layout, remotes, data schema, module ownership |
| [`docs/MAP.md`](docs/MAP.md) | Map layout, coordinates, thumbnail camera positions |
| [`marketing/STORE_PAGE.md`](marketing/STORE_PAGE.md) | Store description, keywords, badges, launch marketing plan |
| [`marketing/README.md`](marketing/README.md) | Icon, thumbnails, badge art, and how to upload them |

## 1. Run it in Studio

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/): the CLI
   (`aftman add rojo-rbx/rojo` or from GitHub releases) and the **Rojo Studio plugin**.
2. Open Roblox Studio and create a new **Baseplate** place. Delete the `Baseplate` part and the
   default `SpawnLocation`, because the map builds its own. Save it outside the repo and reuse it.
3. In this folder run `rojo serve`, then click **Connect** in the Rojo plugin.
4. Press **Play**. The server builds the beach in a few seconds. The deep layers keep filling in
   the background, and `workspace` gets the attribute `WorldReady = true` once they're done.

Another option is `rojo build default.project.json -o DigToTheCore.rbxlx`, then open that file.

### Saving data in Studio
Go to **Game Settings → Security → Enable Studio Access to API Services** to test real
DataStores. When that's off, the game uses an in-memory store and prints a warning.

### Testing paid features in Studio
In `src/server/Services/MonetizationService.luau`, set `STUDIO_GRANT_ALL_PASSES = true` to try
every game pass for free. It only works in Studio.

## 2. Before you publish (needs your account)

1. **Publish** the place (File → Publish to Roblox). Set **Max Players = 16** (one shared dig beach).
2. **Game passes.** Create these in Creator Hub (Monetization → Passes), then paste each id into
   `src/shared/Config/Monetization.luau`:

   | Key | Name | Suggested price (Robux) |
   |---|---|---|
   | VIP | VIP | 249 |
   | DoubleSand | 2x Sand | 299 |
   | SellAnywhere | Sell Anywhere | 149 |
   | AutoDig | Auto Dig | 199 |
   | Lucky | Lucky Shovel | 149 |
   | TripleHatch | Triple Hatch | 99 |
   | ExtraPets | +2 Pet Slots | 199 |
   | MegaBackpack | Mega Backpack | 129 |

3. **Developer products.** Create these (Monetization → Developer Products) and paste the ids
   into the same file:

   | Key | Name | Price |
   |---|---|---|
   | CoinsSmall | Pile of Coins | 25 |
   | CoinsMedium | Bag of Coins | 99 |
   | CoinsLarge | Chest of Coins | 299 |
   | CoinsHuge | Sunken Ship of Coins | 799 |
   | SandBoost15 | 2x Sand (15 min) | 35 |
   | LuckBoost15 | 2x Luck (15 min) | 35 |
   | SkipRebirth | Skip Rebirth | 199 |
   | GoldenEgg | Golden Egg | 79 |
   | GoldenEgg3 | 3 Golden Eggs | 199 |
   | CoolerPack | Cooler Pack (snacks) | 29 |

   An id left at `0` means "not configured". The store hides or disables that item and never
   prompts a purchase for it, so you can launch with only some of them set up.
4. **Badges.** Create the 10 badges listed in `src/shared/Config/Badges.luau` (the art is in
   `marketing/badges/`) and paste their ids there.
5. **Group.** Create a Roblox group and put its id in `GROUP_ID` in
   `src/shared/Config/init.luau`. That turns on the group sand bonus and the group-only code
   `DIGDEEP`.
6. **Icon and thumbnails.** Upload `marketing/icon.png` and `marketing/thumbnails/thumb_1..4.png`.
7. **Experience settings.** Genre is Simulation. Fill in the Experience Questionnaire; the
   expected maturity is *Minimal*, and you must disclose that there are paid random items (the
   Golden Egg). Enable Phone, Tablet, Computer and Console. Paste in the description from
   `marketing/STORE_PAGE.md`.
8. **Music (optional).** `src/shared/Config/Sounds.luau` has empty music and ambience slots.
   Upload audio you own (or audio from the Creator Store) and paste in the ids.

## 3. Development

Tools: Rojo, StyLua, luau-lsp (strict type check against the Roblox API).

```sh
stylua src          # format
./tools/check.sh    # format check + strict type check + rojo build (must say ALL CHECKS PASSED)
luau tests/util.spec.luau
```

`tools/check.sh` expects `rojo`, `stylua` and `luau-lsp` on `PATH` (or in `~/bin`), and the
Roblox type definitions at `~/luau-defs/globalTypes.d.luau`, which come from the luau-lsp repo's
`scripts/globalTypes.d.luau`.

Balance numbers are all in `src/shared/Config/`. Change prices, layers, pets and drop rates
there, and the rest of the game picks them up.

To regenerate the marketing art: `pip install pillow && python3 tools/marketing/generate.py`.
