--!strict
--[[
	RebirthPerks — permanent upgrades bought with Rebirth Tokens (docs/design/Rebirth.md).

	PlayerData.RebirthPerks = { [perkId] = level } (missing = level 0). Perks are never reset.
	Costs[i] = tokens for level i, so #Costs is the max level. Effect values per level live in
	`Levels` (index = level, 0 = not bought) so the UI can show "current -> next".

	Tuned against Config.Rebirths.Tokens (2, 2, 3, 3, 4, 4, 5 ... tokens per rebirth): the first
	rebirth (2 tokens) buys two level-1 perks (e.g. Head Start + Golden Touch); Sell Anywhere (5) is
	the big mid-term goal, reached around rebirth 3 (tools/sim/economy.luau: it is a ~3x speed-up).
	The Rebirth Egg (3 tokens) competes for the same tokens on purpose: a real choice each time.

	Effects (where they are applied):
	  HeadStart     start each rebirth with shovel Shovels[ShovelIndex] + Coins  (RebirthService)
	  KeepBackpack  keep your backpack on rebirth, up to Backpacks[KeepIndex]     (RebirthService)
	  SellAnywhere  same as the Sell Anywhere game pass                             (EconomyService)
	  DeepPockets   +x backpack capacity                                            (Stats.GetCapacity)
	  LuckyDigger   x treasure chance per dig (NOT egg luck: egg odds stay as shown) (Stats.GetTreasureChance)
	  LongNap       +hours offline cap and +offline efficiency                      (OfflineService)
	  PetDen        +pet equip slots                                                (Stats.GetPetSlots)
	  GoldenTouch   +x coins from selling (and offline earnings)                    (Stats.GetCoinFactors)
]]

export type PerkId =
	"HeadStart"
	| "KeepBackpack"
	| "SellAnywhere"
	| "DeepPockets"
	| "LuckyDigger"
	| "LongNap"
	| "PetDen"
	| "GoldenTouch"

export type PerkLevel = {
	ShovelIndex: number?, -- HeadStart
	Coins: number?, -- HeadStart
	KeepIndex: number?, -- KeepBackpack: highest backpack index kept
	Unlocked: boolean?, -- SellAnywhere
	Capacity: number?, -- DeepPockets: capacity factor
	TreasureChance: number?, -- LuckyDigger: treasure chance factor
	OfflineHours: number?, -- LongNap: extra cap hours
	OfflineEfficiency: number?, -- LongNap: extra efficiency (0..1)
	PetSlots: number?, -- PetDen
	Coin: number?, -- GoldenTouch: sell factor
}

export type PerkDef = {
	Id: PerkId,
	Name: string,
	Icon: string, -- AtlasIcon key ("atlas_name|emoji")
	Description: string,
	Costs: { number }, -- tokens for level 1, 2, ...
	Levels: { PerkLevel }, -- effect at level 1, 2, ... (same length as Costs)
	Order: number,
}

local Perks: { PerkDef } = {
	{
		Id = "SellAnywhere",
		Name = "Sell Anywhere",
		Icon = "sell|💸",
		Description = "Sell from anywhere with one tap, like the game pass.",
		Costs = { 5 },
		Levels = { { Unlocked = true } },
		Order = 1,
	},
	{
		Id = "HeadStart",
		Name = "Head Start",
		Icon = "shovel|⛏️",
		Description = "Start every rebirth with a better shovel and some coins.",
		Costs = { 1, 2, 3, 5, 8 },
		Levels = {
			{ ShovelIndex = 4, Coins = 500 }, -- Lifeguard Shovel
			{ ShovelIndex = 5, Coins = 5_000 }, -- Pirate Shovel
			{ ShovelIndex = 6, Coins = 25_000 }, -- Bone Claw
			{ ShovelIndex = 7, Coins = 100_000 }, -- Steel Pickaxe
			{ ShovelIndex = 8, Coins = 400_000 }, -- Crystal Spade
		},
		Order = 2,
	},
	{
		Id = "GoldenTouch",
		Name = "Golden Touch",
		Icon = "boost_coins|💰",
		Description = "More coins every time you sell.",
		Costs = { 1, 2, 3, 4, 5 },
		Levels = { { Coin = 1.1 }, { Coin = 1.2 }, { Coin = 1.3 }, { Coin = 1.4 }, { Coin = 1.5 } },
		Order = 3,
	},
	{
		Id = "KeepBackpack",
		Name = "Keep Backpack",
		Icon = "backpack|🎒",
		Description = "Keep your backpack when you rebirth.",
		Costs = { 1, 3, 6 },
		Levels = {
			{ KeepIndex = 5 }, -- up to Treasure Sack
			{ KeepIndex = 8 }, -- up to Wheelbarrow
			{ KeepIndex = 99 }, -- any backpack
		},
		Order = 4,
	},
	{
		Id = "DeepPockets",
		Name = "Deep Pockets",
		Icon = "sand|⏳",
		Description = "Your backpack holds more sand.",
		Costs = { 1, 1, 2, 3, 4 },
		Levels = {
			{ Capacity = 1.1 },
			{ Capacity = 1.2 },
			{ Capacity = 1.3 },
			{ Capacity = 1.4 },
			{ Capacity = 1.5 },
		},
		Order = 5,
	},
	{
		Id = "LuckyDigger",
		Name = "Lucky Digger",
		Icon = "boost_luck|🍀",
		Description = "Find treasure more often while digging.",
		Costs = { 1, 2, 2, 3, 4 },
		Levels = {
			{ TreasureChance = 1.1 },
			{ TreasureChance = 1.2 },
			{ TreasureChance = 1.3 },
			{ TreasureChance = 1.4 },
			{ TreasureChance = 1.5 },
		},
		Order = 6,
	},
	{
		Id = "LongNap",
		Name = "Long Nap",
		Icon = "hourglass|⏳",
		Description = "Your pets dig longer and harder while you are away.",
		Costs = { 1, 2, 3, 4 },
		Levels = {
			{ OfflineHours = 1, OfflineEfficiency = 0.1 },
			{ OfflineHours = 2, OfflineEfficiency = 0.2 },
			{ OfflineHours = 3, OfflineEfficiency = 0.3 },
			{ OfflineHours = 4, OfflineEfficiency = 0.4 },
		},
		Order = 7,
	},
	{
		Id = "PetDen",
		Name = "Pet Den",
		Icon = "pets|🐾",
		Description = "+1 pet slot.",
		Costs = { 3, 6 },
		Levels = { { PetSlots = 1 }, { PetSlots = 2 } },
		Order = 8,
	},
}

local byId: { [string]: PerkDef } = {}
for _, perk in Perks do
	assert(byId[perk.Id] == nil, "RebirthPerks: duplicate id " .. perk.Id)
	assert(#perk.Costs == #perk.Levels, "RebirthPerks: Costs/Levels length mismatch on " .. perk.Id)
	byId[perk.Id] = perk
end
table.sort(Perks, function(a: PerkDef, b: PerkDef): boolean
	return a.Order < b.Order
end)

local RebirthPerks = {
	List = Perks,
	-- Offline earnings (OfflineService): base values before Long Nap.
	OFFLINE_MIN_SECONDS = 5 * 60, -- shorter absences grant nothing
	OFFLINE_CAP_HOURS = 2,
	OFFLINE_EFFICIENCY = 0.4, -- pets dig at 40% without their owner around
	OFFLINE_MAX_GAP_SECONDS = 365 * 86400, -- larger gaps are treated as a broken clock: ignored
}

function RebirthPerks.Get(id: string): PerkDef?
	return byId[id]
end

function RebirthPerks.MaxLevel(id: string): number
	local def = byId[id]
	return if def then #def.Costs else 0
end

-- Level of a perk in a RebirthPerks table (tolerates nil / junk from old saves). Clamped.
function RebirthPerks.Level(perks: { [string]: number }?, id: string): number
	if type(perks) ~= "table" then
		return 0
	end
	local value = (perks :: any)[id]
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, RebirthPerks.MaxLevel(id))
end

-- Token cost of the NEXT level, or nil when maxed / unknown.
function RebirthPerks.NextCost(perks: { [string]: number }?, id: string): number?
	local def = byId[id]
	if not def then
		return nil
	end
	return def.Costs[RebirthPerks.Level(perks, id) + 1]
end

-- Effect table at the current level (empty table at level 0).
function RebirthPerks.Effect(perks: { [string]: number }?, id: string): PerkLevel
	local def = byId[id]
	local level = RebirthPerks.Level(perks, id)
	if not def or level == 0 then
		return {}
	end
	return def.Levels[level]
end

-- Convenience accessors used by Stats / services / UI ------------------------------------------

function RebirthPerks.CapacityFactor(perks: { [string]: number }?): number
	return RebirthPerks.Effect(perks, "DeepPockets").Capacity or 1
end

function RebirthPerks.TreasureFactor(perks: { [string]: number }?): number
	return RebirthPerks.Effect(perks, "LuckyDigger").TreasureChance or 1
end

function RebirthPerks.CoinFactor(perks: { [string]: number }?): number
	return RebirthPerks.Effect(perks, "GoldenTouch").Coin or 1
end

function RebirthPerks.ExtraPetSlots(perks: { [string]: number }?): number
	return RebirthPerks.Effect(perks, "PetDen").PetSlots or 0
end

function RebirthPerks.HasSellAnywhere(perks: { [string]: number }?): boolean
	return RebirthPerks.Effect(perks, "SellAnywhere").Unlocked == true
end

function RebirthPerks.OfflineCapSeconds(perks: { [string]: number }?): number
	return (RebirthPerks.OFFLINE_CAP_HOURS + (RebirthPerks.Effect(perks, "LongNap").OfflineHours or 0)) * 3600
end

function RebirthPerks.OfflineEfficiency(perks: { [string]: number }?): number
	return RebirthPerks.OFFLINE_EFFICIENCY + (RebirthPerks.Effect(perks, "LongNap").OfflineEfficiency or 0)
end

-- Total tokens spent (for UI / analytics).
function RebirthPerks.Spent(perks: { [string]: number }?): number
	local total = 0
	for _, def in Perks do
		for i = 1, RebirthPerks.Level(perks, def.Id) do
			total += def.Costs[i]
		end
	end
	return total
end

return RebirthPerks
