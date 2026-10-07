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
| [`docs/LAUNCH.md`](docs/LAUNCH.md) | Ordered go-live runbook; `tools/preflight.sh` lists every id and asset still to fill in |
| [`docs/V2.md`](docs/V2.md) | v2/v2.1 contract: open beach, survival, companions, ride |
| [`docs/UI_STYLE.md`](docs/UI_STYLE.md) | UI style guide and layout map |
| [`docs/GDD.md`](docs/GDD.md) | Original game design: loop, layers, economy, retention, monetization, roadmap, launch checklist |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Code layout, remotes, data schema, module ownership |
| [`docs/MAP.md`](docs/MAP.md) | Map layout, coordinates, thumbnail camera positions |
| [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md) | Streaming settings, budgets, the `/stress` load test, MicroProfiler on desktop and Android |
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
   `src/shared/Config/Monetization.luau`. Prices are v2.3 suggestions in the competitor band
   (comparable passes sell for 175–750 R$):

   | Key | Name | What it gives | Suggested price (Robux) |
   |---|---|---|---|
   | VIP | VIP | +25% sand, +10% sell coins, 2 shades at once, gold nameplate tag | 349 |
   | DoubleSand | 2x Sand | x2 sand per dig | 399 |
   | SellAnywhere | Sell Anywhere | Sell from anywhere (also a free rebirth perk) | 249 |
   | AutoDig | Auto Dig | Auto-swing + 1 pet slot | 299 |
   | FastDig | Turbo Shovel | +25% dig speed | 249 |
   | TripleHatch | Triple Hatch | Hatch 3 eggs at once | 249 |
   | ExtraPets | +2 Pet Slots | +2 equipped pets | 349 |
   | MegaBackpack | Mega Backpack | x2 backpack capacity | 299 |

3. **Developer products.** Create these (Monetization → Developer Products) and paste the ids
   into the same file:

   | Key | Name | Price |
   |---|---|---|
   | CoinsSmall | Pile of Coins | 49 |
   | CoinsMedium | Bag of Coins | 149 |
   | CoinsLarge | Chest of Coins | 399 |
   | CoinsHuge | Sunken Ship of Coins | 999 |
   | SandBoost15 | 2x Sand (15 min) | 49 |
   | SkipRebirth | Skip Rebirth | 199 |

   An id left at `0` means "not configured". The store hides or disables that item and never
   prompts a purchase for it, so you can launch with only some of them set up. Once an id is
   set, the store shows the **real price from Creator Hub** (`MarketplaceService:GetProductInfo`)
   and only falls back to the suggested price if that lookup fails.
   **After launch, turn on Roblox Managed Pricing** for the developer products (Creator Hub →
   Monetization → Developer Products). Roblox then tests regional prices for you.

   **v2.3: no Robux item sells a random outcome or luck.** The Golden Egg costs Rebirth Tokens,
   and the Lucky pass, 2x Luck and the Golden Egg products are gone. Coin packs and Skip Rebirth
   are still marked "paid random" (`PaidRandom = true`), because they buy currency that buys
   eggs. Players whose Roblox policy restricts paid random items never see them
   (`Services/PolicyService.luau`).
4. **Badges.** Create the 10 badges listed in `src/shared/Config/Badges.luau` (the art is in
   `marketing/badges/`) and paste their ids there.
5. **Group.** Create a Roblox group and put its id in `GROUP_ID` in
   `src/shared/Config/init.luau`. That turns on the group sand bonus and the group-only code
   `DIGDEEP`.
6. **Icon and thumbnails.** Upload `marketing/icon.png` and `marketing/thumbnails/thumb_1..4.png`.
7. **Experience settings.** Genre is Simulation. Fill in the Experience Questionnaire; the
   expected maturity is *Minimal*. Paid random items: answer as described in
   `marketing/STORE_PAGE.md`. Since v2.3 they exist only indirectly, through coin packs and Skip
   Rebirth, which buy currency that can hatch eggs. Enable Phone, Tablet, Computer and Console. Paste in the description from
   `marketing/STORE_PAGE.md`.
8. **Music (optional).** `src/shared/Config/Sounds.luau` has empty music and ambience slots.
   Upload audio you own (or audio from the Creator Store) and paste in the ids.

## 3. Development

Tools: Rojo, StyLua, luau-lsp (strict type check against the Roblox API).

```sh
stylua src            # format
./tools/check.sh      # format check + strict type check + rojo build (must say ALL CHECKS PASSED)
./tests/run.sh        # headless unit, server smoke and client tests (must say ALL TESTS PASSED)
./tools/preflight.sh  # launch checklist: placeholder ids/assets still to fill in
```

CI (`.github/workflows/ci.yml`) runs all of these on every push and pull request.

`tools/check.sh` expects `rojo`, `stylua` and `luau-lsp` on `PATH` (or in `~/bin`), and the
Roblox type definitions at `~/luau-defs/globalTypes.d.luau`, which come from the luau-lsp repo's
`scripts/globalTypes.d.luau`. On Linux (CI, cloud sessions) `tools/setup_toolchain.sh` installs
the pinned versions of all of them. Keep the definitions pinned: the test mock is generated from
them, and newer upstream definitions drop enum items the mock relies on.

Balance numbers are all in `src/shared/Config/`. Change prices, layers, pets and drop rates
there, and the rest of the game picks them up.

To regenerate the marketing art: `pip install pillow && python3 tools/marketing/generate.py`.
