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

export type PlotInfo = {
	Id: number,
	Origin: CFrame, -- centre of the plot surface, Y = surface height
	Size: Vector3, -- X,Z footprint and total depth Y
	SpawnCFrame: CFrame,
}

-- Equipment --------------------------------------------------------------------------------

export type ShovelShape = "Scoop" | "Trowel" | "Spade" | "Pick" | "Claw" | "Trident" | "Drill"

export type ShovelLook = {
	HeadColor: Color3,
	HandleColor: Color3,
	HeadShape: ShovelShape,
	Material: Enum.Material, -- Part material for the head
	Glow: boolean, -- add PointLight / Neon accents
}

export type ShovelDef = {
	Id: string,
	Name: string,
	Price: number, -- coins
	Power: number, -- compared against LayerDef.Hardness
	Cooldown: number, -- seconds between digs
	Radius: number, -- FillBall radius in studs
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
	Target: string?, -- CollectionService tag the 3D arrow / beam points at ("Plot" = own plot)
	Complete: string, -- event that completes the step (see Config.TUTORIAL_STEPS)
}

-- Persistence & networking -----------------------------------------------------------------

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
	PlayTime: number, -- seconds
	FirstJoin: number, -- unix
	Version: number,
}

export type DigFailReason = "Cooldown" | "TooHard" | "BackpackFull" | "OutOfPlot" | "TooFar" | "NoPlot" | "Bottom"

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
