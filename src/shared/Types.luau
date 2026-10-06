--!strict
--[[
	Types — shared exported Luau types for Dig the Beach.
	Owner: Game design. Other areas code against these; do not change field names without
	updating docs/ARCHITECTURE.md.

	Units:
	- Depth is always in STUDS BELOW THE SURFACE (positive number, 0 = beach surface).
	- Prices / values are in Coins unless stated otherwise. Robux prices are suggestions only.
	- Multipliers are plain factors (1 = no bonus). Pet multipliers combine ADDITIVELY:
	  total = 1 + sum(pet.Multiplier - 1) (see Config.PetMultiplier).
]]

-- Rarity ---------------------------------------------------------------------------------

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type RarityDef = {
	Name: Rarity,
	Order: number, -- 1 = Common ... 6 = Mythic
	Color: Color3, -- main text / frame colour
	Gradient: { Color3 }, -- 2+ colours for UIGradient on cards
	Announce: boolean, -- server-wide chat/toast when someone finds/hatches this rarity
}

-- Rewards (quests, daily, codes, products) -------------------------------------------------

export type Reward = {
	Coins: number?, -- flat coins
	-- "seconds of income": multiplied by the RewardScale of the layer at the player's MaxDepth,
	-- so rewards stay meaningful all game. Resolve with Config.ResolveCoins(reward, maxDepth).
	ScaledCoins: number?,
	RebirthTokens: number?,
	Boost: string?, -- BoostDef.Id
	BoostSeconds: number?,
	Pet: string?, -- PetDef.Id granted directly
	Egg: string?, -- EggDef.Id hatched for free
	EggCount: number?, -- default 1
	Rebirth: boolean?, -- grant one rebirth without paying its coin cost (Skip Rebirth product)
	Consumables: { [string]: number }?, -- v2 survival: consumable id -> count (granted by SurvivalService)
}

-- World ------------------------------------------------------------------------------------

export type LootEntry = {
	TreasureId: string,
	Weight: number,
}

export type LayerDef = {
	Id: string,
	Name: string,
	DepthStart: number, -- studs below surface (inclusive)
	DepthEnd: number, -- studs below surface (exclusive)
	Material: Enum.Material, -- terrain material; unique per layer (colour override is global per material)
	Color: Color3, -- Terrain:SetMaterialColor(Material, Color)
	Hardness: number, -- equipped shovel Power must be >= Hardness
	SandValue: number, -- sand per dig before multipliers
	TreasureChance: number, -- 0..1 chance per successful dig to roll LootTable (before luck)
	LootTable: { LootEntry },
	RewardScale: number, -- ~coins/second a typical player earns here; scales ScaledCoins rewards
	FlavorText: string,
	AmbientColor: Color3, -- suggested Lighting tint / fog colour while the camera is in this layer
}

-- Equipment --------------------------------------------------------------------------------

export type ShovelShape = "Scoop" | "Trowel" | "Spade" | "Pick" | "Claw" | "Trident" | "Drill"

-- "Hand": small one-handed hand tool (~2 studs). "Full" (default when nil): full-size tool held
-- with both hands (client ShovelPoseController).
export type ShovelSize = "Hand" | "Full"

export type ShovelLook = {
	HeadColor: Color3,
	HandleColor: Color3,
	HeadShape: ShovelShape,
	Material: Enum.Material, -- Part material for the head
	Glow: boolean, -- add PointLight / Neon accents
	Size: ShovelSize?, -- nil = "Full"
}

export type ShovelDef = {
	Id: string,
	Name: string,
	Price: number, -- coins
	Power: number, -- compared against LayerDef.Hardness
	Cooldown: number, -- seconds between digs
	Radius: number, -- dig size: half the edge of the voxel cube a dig removes (see Shovels.luau)
	SandMultiplier: number,
	RebirthsRequired: number,
	Description: string,
	Look: ShovelLook,
}

export type BackpackShape = "Bucket" | "Bag" | "Box" | "Barrel" | "Cart" | "Vehicle" | "Orb"

export type BackpackLook = {
	Color: Color3,
	AccentColor: Color3,
	Shape: BackpackShape,
	Material: Enum.Material,
	Glow: boolean,
}

export type BackpackDef = {
	Id: string,
	Name: string,
	Price: number,
	Capacity: number, -- sand (multiplied by rebirth multiplier & Mega Backpack pass)
	RebirthsRequired: number,
	Description: string,
	Look: BackpackLook,
}

-- Pets & eggs ------------------------------------------------------------------------------

export type PetShape =
	"Crab"
	| "Bird"
	| "Star"
	| "Turtle"
	| "Fish"
	| "Squid"
	| "Blob"
	| "Mole"
	| "Dino"
	| "Dragon"
	| "Golem"
	| "Seal"
	| "Vehicle" -- v2.1: vehicle pet, drawn by Models/Diggers (PetDef.VehicleKind)

export type PetLook = {
	BodyColor: Color3,
	AccentColor: Color3,
	Shape: PetShape,
	Size: number, -- overall scale factor, ~1 (Common) .. 1.6 (Mythic)
	Glow: boolean,
}

export type PetDef = {
	Id: string,
	Name: string,
	Rarity: Rarity,
	Multiplier: number, -- sand multiplier (additive with other pets, see Config.PetMultiplier)
	Exclusive: boolean, -- not in any egg (daily reward / code / event)
	Look: PetLook,
	-- v2.1: digging companions (vehicles from Construction Crates, some creatures).
	Dig: PetDigDef?,
	Rideable: boolean?, -- v2.1: the player can ride it (see Services/RideService)
	VehicleKind: string?, -- v2.1: Models/Diggers builder kind for vehicle pets (e.g. "Excavator")
}

export type PetDigDef = {
	Power: number, -- digs layers with Hardness <= Power
	Interval: number, -- seconds between digs
	Radius: number, -- same scale as shovel Radius
	SandMultiplier: number, -- replaces the shovel factor for this pet's digs
}

export type PetInstance = {
	Id: string, -- PetDef.Id
	Equipped: boolean,
}

export type EggCurrency = "Coins" | "Tokens" | "Robux"

export type EggEntry = {
	PetId: string,
	Weight: number,
}

export type EggLook = {
	ShellColor: Color3,
	SpotColor: Color3,
	Glow: boolean,
}

export type EggDef = {
	Id: string,
	Name: string,
	Currency: EggCurrency,
	Price: number, -- coins / tokens per hatch; for Robux eggs the Robux suggestion (see ProductKey)
	ProductKey: string?, -- Robux eggs: key into Config.Monetization.Products for a single hatch
	UnlockLayer: number, -- index into Config.Layers; requires MaxDepth >= that layer's DepthStart
	Pets: { EggEntry },
	Look: EggLook,
	Kind: ("Egg" | "Crate")?, -- v2.1: Construction Crates hatch vehicle pets; default "Egg"
}

-- Treasure ---------------------------------------------------------------------------------

export type TreasureShape =
	"Coin"
	| "Cap"
	| "Shell"
	| "Bottle"
	| "Chest"
	| "Gem"
	| "Bone"
	| "Skull"
	| "Orb"
	| "Crown"
	| "Tablet"
	| "Egg"
	| "Anchor"
	| "Wheel"
	| "Shard"
	| "Box"

export type TreasureLook = {
	Color: Color3,
	Shape: TreasureShape,
	Material: Enum.Material,
	Glow: boolean,
}

export type TreasureDef = {
	Id: string,
	Name: string,
	Layer: number, -- index into Config.Layers where it is found
	Rarity: Rarity,
	SellValue: number, -- coins when sold
	FlavorText: string,
	Look: TreasureLook,
}

-- Progression ------------------------------------------------------------------------------

export type RebirthConfig = {
	BaseCost: number,
	CostGrowth: number,
	MultiplierPerRebirth: number,
	BaseTokens: number,
	Resets: { string }, -- PlayerData keys reset on rebirth
	Keeps: { string }, -- PlayerData keys explicitly kept (documentation)
	Cost: (rebirths: number) -> number, -- coins for the NEXT rebirth when you have `rebirths`
	Multiplier: (rebirths: number) -> number, -- permanent sand & capacity multiplier
	Tokens: (rebirths: number) -> number, -- tokens granted for the NEXT rebirth
}

export type QuestKind =
	"DigTimes"
	| "SellTimes"
	| "FindTreasures"
	| "FindRarity" -- Target treasures of Rarity or rarer
	| "HatchEggs"
	| "PlayMinutes"
	| "BuyUpgrade" -- buy any shovel or backpack
	| "ReachDepth" -- Target = studs below surface (compare with MaxDepth)
	| "Rebirth"

export type QuestReset = "Daily" | "Once"

export type QuestDef = {
	Id: string,
	Name: string,
	Description: string,
	Kind: QuestKind,
	Target: number,
	Rarity: Rarity?, -- FindRarity only
	Reset: QuestReset,
	Reward: Reward,
}

export type QuestProgress = {
	Progress: number,
	Claimed: boolean,
	Day: number?, -- UTC day number (os.time() // 86400) this progress belongs to (Daily quests)
}

export type DailyRewardDef = {
	Day: number, -- 1..7
	Label: string,
	Reward: Reward,
}

export type CodeDef = {
	Code: string, -- matched case-insensitively
	Reward: Reward,
	Enabled: boolean,
	Expires: number?, -- unix time; nil = never
	GroupOnly: boolean?, -- requires membership of Config.GROUP_ID
	Note: string,
}

-- Boosts & events --------------------------------------------------------------------------

export type BoostKind = "Sand" | "Luck" | "Coins" | "Speed"

export type BoostDef = {
	Id: string,
	Name: string,
	Kind: BoostKind,
	Multiplier: number, -- Speed: cooldown is divided by this
	Description: string,
	Color: Color3,
}

export type EventDef = {
	Id: string,
	Name: string,
	Description: string,
	Kind: BoostKind,
	Multiplier: number,
	IntervalSeconds: number, -- event is active while (os.time() + OffsetSeconds) % IntervalSeconds < DurationSeconds
	DurationSeconds: number,
	OffsetSeconds: number,
	Color: Color3,
}

-- Monetization -----------------------------------------------------------------------------

export type GamePassDef = {
	Id: number, -- 0 = not created yet (owner pastes Creator Hub id)
	Name: string,
	Price: number, -- suggested Robux
	Description: string,
	Color: Color3,
	SandMultiplier: number?,
	LuckMultiplier: number?,
	CapacityMultiplier: number?,
	ExtraPetSlots: number?,
	SpeedMultiplier: number?,
}

export type ProductDef = {
	Id: number, -- 0 = not created yet
	Name: string,
	Price: number, -- suggested Robux
	Description: string,
	Grant: Reward,
}

export type PremiumPerks = {
	SandMultiplier: number,
	DailyRewardMultiplier: number,
	ChatTag: string,
}

export type MonetizationConfig = {
	GamePasses: { [string]: GamePassDef },
	Products: { [string]: ProductDef },
	Premium: PremiumPerks,
}

-- Presentation -----------------------------------------------------------------------------

export type SoundDef = {
	Id: string, -- "rbxasset://..." built-in, or "" = not set yet (skip playing)
	Volume: number,
	PlaybackSpeed: number,
	Looped: boolean,
}

export type ThemeColors = {
	Sand: Color3,
	SandDark: Color3,
	Ocean: Color3,
	OceanDark: Color3,
	Sky: Color3,
	Sunset: Color3,
	Coral: Color3,
	Palm: Color3,
	Gold: Color3,
	Purple: Color3,
	Panel: Color3,
	PanelAlt: Color3,
	Text: Color3,
	TextDark: Color3,
	Stroke: Color3,
	Success: Color3,
	Danger: Color3,
	Warning: Color3,
	Disabled: Color3,
	Coins: Color3,
	Tokens: Color3,
	Robux: Color3,
}

export type ThemeFonts = {
	Title: Enum.Font,
	Body: Enum.Font,
	Number: Enum.Font,
}

export type ThemeDef = {
	Colors: ThemeColors,
	Fonts: ThemeFonts,
	CornerSmall: UDim,
	CornerMedium: UDim,
	CornerLarge: UDim,
	CornerPill: UDim,
	StrokeThickness: number,
	MinTouchSize: number, -- px; never make a tappable button smaller than this
	TweenTime: number,
}

export type TutorialStep = {
	Id: string,
	Text: string, -- short, kid-friendly, big font
	Target: string?, -- CollectionService tag the 3D arrow / beam points at ("Sand" = nearest dig-zone sand)
	Complete: string, -- event that completes the step (see Config.TUTORIAL_STEPS)
}

-- Persistence & networking -----------------------------------------------------------------

-- v2: survival (heat / shade / consumables) ---------------------------------------------------
-- Owned by the Survival agent; may add fields, must keep these.

export type HeatConfig = {
	Max: number, -- heat meter range 0..Max
	SunRisePerSecond: number, -- standing in the sun on the surface
	DigRisePerDig: number, -- extra heat per dig while in the sun
	ShadeFallPerSecond: number, -- base cooling while in shade (scaled by the shade's Cooling)
	UndergroundDepth: number, -- studs below surface where it counts as underground (cool)
	UndergroundFallPerSecond: number,
	SunburntAt: number, -- heat at which the player becomes Sunburnt
	RecoverAt: number, -- Sunburnt clears when heat drops to this
	SunburntCooldownMultiplier: number, -- dig cooldown multiplier while Sunburnt (e.g. 2)
	NewPlayerGraceSeconds: number, -- no heat gain for brand-new players' first minutes
	-- Survival agent additions
	TickSeconds: number, -- server heat tick interval
	DigRiseMaxPerSecond: number, -- cap on dig heat per second (fast shovels / diggers)
	OffSandFallPerSecond: number, -- cooling anywhere off the hot sand (boardwalk, hub, sea)
	WarningAt: number, -- "getting hot" hint threshold
	EventSunMultipliers: { [string]: number }, -- Config.Events id -> multiplier on sun heat
	FountainCooldownSeconds: number,
	ConsumableMaxStack: number, -- max count of one consumable in PlayerData.Consumables
	ConsumableBoostCapSeconds: number, -- consumable boosts stack time up to this many seconds
	ShadeSlots: number, -- placed shades per player
	ShadeSlotsVip: number, -- placed shades with the VIP pass
	ShadePlaceRange: number, -- max horizontal studs from the player to the placement point
	ShadeMinSpacing: number, -- min studs between two shade poles
	ShadeHubClearance: number, -- min studs from hub stations (tagged parts)
}

export type ShadeDef = {
	Id: string,
	Name: string,
	Price: number,
	RebirthsRequired: number?,
	Radius: number, -- studs (horizontal) of shade
	Cooling: number, -- multiplier on HeatConfig.ShadeFallPerSecond
	Height: number, -- studs from the ground to the underside of the canopy (shade check + model)
	Description: string,
	Look: { [string]: any },
}

export type ConsumableDef = {
	Id: string,
	Name: string,
	Price: number, -- coins; 0 = free (e.g. water fountain only)
	Cooling: number, -- heat removed instantly
	Boost: string?, -- Config.Boosts id granted on use
	BoostSeconds: number?,
	Icon: string, -- emoji/text icon
	Description: string,
	Look: { [string]: any },
}

-- v2 digger companions were folded into pets in v2.1 (vehicle pets from Construction Crates).
-- DiggerInstance stays only so old saves' PlayerData.Diggers can be read by the DataService
-- migration (v1 -> v2), which converts them to pets and leaves the table empty.
export type DiggerInstance = {
	Level: number,
	Equipped: boolean,
}

export type PlayerData = {
	Coins: number,
	Sand: number, -- sand currently in backpack
	TotalSandDug: number,
	Rebirths: number,
	RebirthTokens: number,
	MaxDepth: number, -- studs below surface
	Shovel: string,
	OwnedShovels: { [string]: boolean },
	Backpack: string,
	OwnedBackpacks: { [string]: boolean },
	Pets: { [string]: PetInstance }, -- key = uid
	PetSlots: number,
	Treasures: { [string]: number }, -- unsold treasures by id
	Index: { [string]: boolean }, -- discovered treasures (collection), never reset
	DailyStreak: number,
	LastDailyClaim: number, -- unix
	Quests: { [string]: QuestProgress },
	RedeemedCodes: { [string]: boolean },
	Settings: { [string]: any },
	Boosts: { [string]: number }, -- boostId -> expires unix
	Consumables: { [string]: number }, -- v2: consumable id -> count
	OwnedShades: { [string]: boolean }, -- v2
	Diggers: { [string]: DiggerInstance }, -- v2 (legacy): emptied by the v2.1 migration, never written
	PlayTime: number, -- seconds
	FirstJoin: number, -- unix
	Version: number,
}

-- v2 (Beach): DigService.DigAt(player, position, opts). Shovel/Auto digs use the equipped
-- shovel's stats; Digger / Pet (PetDigService) / Ride digs pass their own.
export type DigSource = "Shovel" | "Digger" | "Auto" | "Pet" | "Ride"

export type DigOptions = {
	Power: number, -- compared against LayerDef.Hardness
	Radius: number, -- same scale as ShovelDef.Radius
	SandMultiplier: number, -- replaces the shovel's SandMultiplier in Stats
	Source: DigSource,
	Silent: boolean?, -- true: no DigResult is sent to the player
	Origin: Vector3?, -- "Ride": server-side vehicle position the range check measures from
}

export type DigFailReason = "Cooldown" | "TooHard" | "BackpackFull" | "OutOfZone" | "TooFar" | "Bottom"

export type DigResult = {
	Success: boolean,
	Reason: DigFailReason?,
	Position: Vector3,
	Radius: number,
	SandGained: number,
	Sand: number, -- backpack total after the dig
	Capacity: number, -- effective backpack capacity
	Depth: number, -- studs below surface of the dig point
	LayerIndex: number,
	NewMaxDepth: boolean, -- true if this dig set a personal record
	NewLayer: boolean, -- true if this is the first time the player reached this layer
	TreasureId: string?,
}

return {}
