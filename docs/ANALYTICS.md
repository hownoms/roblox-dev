# Analytics: events and dashboards (v2.2, A11)

Every call goes through `src/server/Services/Analytics.luau`. Each one is pcall'd, runs in its
own thread, and is retried once, so analytics can never break gameplay.

We use only the AnalyticsService methods present in our typed API defs
(`~/luau-defs/globalTypes.d.luau`):
- `LogOnboardingFunnelStepEvent`
- `LogFunnelStepEvent`
- `LogProgressionStartEvent` / `LogProgressionCompleteEvent`
- `LogEconomyEvent`

`LogCustomEvent` is not in those defs, so **"custom events" are logged as single-step recurring
funnels**: `LogFunnelStepEvent(player, <EventName>, <unique session id>, 1, <EventName>, fields)`.
They appear under **Funnels** in Creator Analytics. When the defs gain `LogCustomEvent`, switch
over by changing only the body of `Analytics.Custom`.

Custom fields use `CustomField01..03`. Values are short strings with few distinct values, as
Roblox limits field cardinality.

## Optimisation order (from the research): what to look at, in order

| # | Goal | Dashboard (Creator Hub → Analytics) | Events that feed it | Read it as |
|---|---|---|---|---|
| 1 | **FTUE completion** | Onboarding funnel | Funnel steps 1–18 | The biggest drop between two steps is the next fix. Target: FirstSell > 90% of Joined; any step losing more than 15% is a bug or a design problem |
| 2 | **D1 retention** | Retention (D1), split by funnel step reached | Funnel + engagement | Do players who reach FirstEgg / Layer3 come back more? Pull those steps earlier |
| 3 | **Session length** | Engagement (session time) + Progression | Layers, MenuUnlocked, PanelOpened | Which layer or menu unlock players stop at; long sessions with no Layer3 point to a depth wall |
| 4 | **D7 retention** | Retention (D7) + Progression "Rebirth" | Rebirth progression, FirstRebirth, FirstQuestClaim | Rebirth reach rate and time to the first rebirth |
| 5 | **Economy** | Economy (sources/sinks by SKU, ending balances) | Economy events | Inflation (sources far above sinks), dead sinks (an SKU nobody buys), walls (balance piles up before a price) |
| 6 | **Social** | Custom events / Funnels | (Friends and announcements: STATUS & SOCIAL agent) | |
| 7 | **Monetization** | Monetization + the "Shop" funnel | Shop funnel: Opened → Prompted → Purchased; PurchaseCompleted | Store open → prompt rate (offer relevance), prompt → purchase rate (price) |

## 1. Onboarding funnel (`LogOnboardingFunnelStepEvent`)

Each step is logged **once per player, ever**. The flag `Settings.FTUE_<Name>` is persisted, and
clients cannot write `FTUE_` keys. Step numbers only ever grow: **never renumber a shipped step**.
Append new steps or retire old ones instead.

Players may reach some steps out of order (shade before Layer 3, for example). The dashboard
counts unique players per step, so a value above the previous step's is expected there.

| # | Step | Fires when | Where |
|---|---|---|---|
| 1 | Joined | Data loaded on join | BeachService |
| 2 | AtSand | Standing in the dig zone (3 s poll), or the first dig | Analytics poll + Dug |
| 3 | FirstDig | First successful dig (any source) | `ServerSignals.Dug` |
| 4 | BackpackFull | Sand reaches capacity | `ServerSignals.BackpackFull` |
| 5 | FirstSell | First sell (pad or Sell Anywhere) | EconomyService + `Sold` |
| 6 | FirstShovel | First shovel bought | ShopService + `UpgradeBought` |
| 7 | SecondShovel | Owns 3 shovels (2nd upgrade) | `UpgradeBought` |
| 8 | FirstBackpack | First backpack bought | `UpgradeBought` |
| 9 | Layer2 | Max depth enters layer 2 (Wet Sand) | `DepthReached` |
| 10 | FirstEgg | First egg hatched (Kind ≠ Crate) | `Analytics.Hatched` (PetService) |
| 11 | FirstPet | Has an equipped pet (poll) | Analytics poll |
| 12 | Layer3 | Max depth enters layer 3 | `DepthReached` |
| 13 | FirstShadeOrSnack | First shade or consumable bought (or owns a shade) | `Analytics.Sink` SKU `Shade:` / `Consumable:` + poll |
| 14 | FirstQuestClaim | First quest reward claimed | `Analytics.Source` SKU `Quest:` + poll |
| 15 | FirstCrate | First Construction Crate opened | `Analytics.Hatched` |
| 16 | FirstPetDig | A pet dug for the player | `Dug` with source "Pet" |
| 17 | Layer5 | Max depth enters layer 5 | `DepthReached` |
| 18 | FirstRebirth | First rebirth | RebirthService + `Rebirthed` |

The tutorial (`Config.TUTORIAL_STEPS`) covers steps 2–6 and 10. The rest are the "first hour" milestones.

## 2. Progression (`LogProgressionStart/CompleteEvent`)

| Path | Event | Level | Fields |
|---|---|---|---|
| `Layers` | Reaching a new max layer *i*: **Complete** for layer *i−1* and **Start** for layer *i* (each skipped layer too) | Layer index (1–15), level name = layer name | F01 = rebirths so far |
| `Rebirth` | **Complete** on every rebirth | Total rebirths after it, name "Rebirth N" | none |

`MaxDepth` survives rebirths, so layer events are lifetime "deepest ever" milestones.

## 3. Economy (`LogEconomyEvent`)

The currency is `Coins` or `Tokens`. The SKU is `<Kind>:<id>`, or a bare word.

| Flow | Currency | SKU | Transaction type | Source file |
|---|---|---|---|---|
| Source | Coins | `Sell:<Pad\|Anywhere…>` | Gameplay | EconomyService |
| Source | Coins/Tokens | `Quest:<questId>` | Gameplay | RewardsService |
| Source | Coins/Tokens | `Daily` | TimedReward | RewardsService |
| Source | Coins/Tokens | `Code:<code>` | Gameplay | RewardsService |
| Source | Coins/Tokens | `Product:<productKey>` | IAP | RewardsService (receipt grant) |
| Source | Coins | `Offline` | TimedReward | OfflineService |
| Source | Tokens | `Rebirth` | Gameplay | RebirthService |
| Sink | Coins | `Shovel:<id>`, `Backpack:<id>` | Shop | ShopService |
| Sink | Coins/Tokens | `Egg:<eggId>` (crates too, with the crate id) | Shop | PetService |
| Sink | Coins | `Shade:<id>` | Shop | SurvivalShades |
| Sink | Coins | `Consumable:<id>` | Shop | SurvivalService |
| Sink | Coins | `Rebirth` | Gameplay | RebirthService |
| Sink | Tokens | `Perk:<perkId>:<level>` | Shop | RebirthService |

**Known gap:** the HeadStart perk's starting coins on rebirth (RebirthService) are not yet logged
as a Source. Add `Source(Coins, "Perk:HeadStart")` there. The Rebirth sink also reports an ending
balance of 0 even when HeadStart adds coins.

## 4. Custom events (single-step funnels, see the top of this page)

| Event | Fires when | F01 | F02 | F03 |
|---|---|---|---|---|
| `PanelOpened` | Any panel opens (client Track) | panel name | | |
| `MenuUnlocked` | A HUD menu button unlocks (client Track) | button | | |
| `Hatch` | Each pet rolled from an egg or crate | eggId | rarity | petId |
| `PurchaseCompleted` | Robux purchase confirmed by the server | `Pass:<key>` / `Product:<key>` | | |
| `Sunburnt` | Player attribute `Sunburnt` turns true | layer index at that moment | | |
| `RideStarted` | Player attribute `Riding` set (RideService) | pet id | | |

`tide_refill_caught` (optional in the brief) is not implemented.

## 5. "Shop" funnel (`LogFunnelStepEvent`, recurring)

A session starts when a selling panel opens (Shop, BeachShop, Eggs, Store, Rebirth) and lasts 10
minutes.

| Step | Name | Fires when | F01 | F02 |
|---|---|---|---|---|
| 1 | Opened | Selling panel opened (client Track `panel_opened`) | panel | |
| 2 | Prompted | Robux prompt shown: client Track `purchase_prompted` (`PurchaseController`) or server `MonetizationService.PromptPass/PromptProduct` | panel | `Pass:<key>` / `Product:<key>` |
| 3 | Purchased | Server-confirmed: `ProcessReceipt` granted, or `PromptGamePassPurchaseFinished` purchased | panel | key |

Coin purchases are measured through Economy sinks, not this funnel.

## 6. The `Track` remote (client → server)

`Remotes` event `"Track"(name, a?, b?)`. The handler is `Analytics.OnTrack`, behind `Net.On`. It
requires loaded data and is limited to **8 events per 5 s per player**. The client
(`src/client/Util/Track.luau`) also limits itself to 6 per 5 s.

**Strict whitelist.** Anything else is dropped silently:

| name | a | b |
|---|---|---|
| `panel_opened` | a panel in `Analytics.TRACK_PANELS` | none |
| `purchase_prompted` | `"GamePass"` or `"Product"` | a key that exists in `Config.Monetization` |
| `menu_unlocked` | a button in `Analytics.TRACK_MENU` | none |

**Client-originated events are untrusted.** Use them for UI behaviour only, never for anything
the economy or anti-cheat depends on.

## Tests
`tests/smoke.spec.luau`, section "analytics", covers:
- step numbering
- once-only logging and core-step order
- economy SKUs on every exercised sink
- layer and rebirth progression
- the Hatch fields
- Track whitelist, validation and rate limit
- the attribute-driven events

The mock (`tests/mock/Roblox.luau`) validates the argument types of every AnalyticsService
method we use.
