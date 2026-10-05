--!strict
--[[
	Config — single entry point for ALL balance & presentation data.
	ReplicatedStorage.Shared.Config (owner: Game design). Read-only at runtime: never mutate.

	Fields:   Layers, Shovels, Backpacks, Pets, Eggs, Treasures, Rarities, Rebirths, Quests,
	          DailyRewards, Codes, Monetization, Boosts, Events, Sounds, Theme
	Helpers:  see function list below; all lookups are O(1) via maps built at require time.

	Depth unit: studs below the beach surface (positive). 1 stud = 1 "meter" in the UI.
	Sand -> Coins at SELL_RATE. Sand per dig =
	    layer.SandValue * shovel.SandMultiplier * RebirthMultiplier * PetMultiplier
	    * (pass/premium/group/friend/boost/event multipliers, all multiplicative)
	Capacity = backpack.Capacity * RebirthMultiplier * (MegaBackpack ? 2 : 1)
]]

local Types = require(script.Parent.Types)

local Layers = require(script.Layers)
local Shovels = require(script.Shovels)
local Backpacks = require(script.Backpacks)
local Pets = require(script.Pets)
local Eggs = require(script.Eggs)
local Treasures = require(script.Treasures)
local Rarities = require(script.Rarities)
local Rebirths = require(script.Rebirths)
local Quests = require(script.Quests)
local DailyRewards = require(script.DailyRewards)
local Codes = require(script.Codes)
local Badges = require(script.Badges)
local Monetization = require(script.Monetization)
local Boosts = require(script.Boosts)
local Events = require(script.Events)
local Sounds = require(script.Sounds)
local Theme = require(script.Theme)
local Heat = require(script.Heat)
local Shades = require(script.Shades)
local Consumables = require(script.Consumables)
local Diggers = require(script.Diggers)

local TOTAL_DEPTH = Layers[#Layers].DepthEnd

local Config = {
	-- Data ---------------------------------------------------------------------------------
	Layers = Layers,
	Shovels = Shovels,
	Backpacks = Backpacks,
	Pets = Pets,
	Eggs = Eggs,
	Treasures = Treasures,
	Rarities = Rarities,
	Rebirths = Rebirths,
	Quests = Quests,
	DailyRewards = DailyRewards,
	Codes = Codes,
	Badges = Badges,
	Monetization = Monetization,
	Boosts = Boosts,
	Events = Events,
	Sounds = Sounds,
	Theme = Theme,
	Heat = Heat,
	Shades = Shades,
	Consumables = Consumables,
	Diggers = Diggers,

	-- World --------------------------------------------------------------------------------
	-- One shared dig zone along the shoreline (World.GetDigZone); no plots.
	MAX_PLAYERS = 16, -- OWNER: set Game Settings > Places > Max Players to this
	TOTAL_DEPTH = TOTAL_DEPTH, -- studs from surface to the bottom of The Core
	-- Surface is high up so the bottom of the hole (SURFACE_Y - TOTAL_DEPTH = 24) stays well above
	-- Workspace.FallenPartsDestroyHeight (-500). Terrain must not be generated below Y = 0.
	SURFACE_Y = 1024,
	STUDS_PER_METER = 1,
	-- The tide refills a dug 8x8 column once no player was within TIDE_CLEAR_RADIUS studs
	-- (horizontally) for this long. High Tide smooths every hole at once.
	TIDE_REFILL_SECONDS = 240,
	TIDE_CLEAR_RADIUS = 12,

	-- Digging ------------------------------------------------------------------------------
	REACH = 20, -- max studs from HumanoidRootPart to the dig point
	COOLDOWN_LENIENCY = 0.85, -- server accepts a dig after Cooldown * this (latency slack)
	SELL_RATE = 1, -- coins per sand
	MAX_TREASURE_CHANCE = 0.5, -- cap after luck multipliers
	-- Collection bonus: +2% sand for every layer whose treasures are ALL in PlayerData.Index
	-- (computed from Index, nothing extra persisted). Max 15 layers = +30%.
	INDEX_LAYER_BONUS = 0.02,

	-- Pets ---------------------------------------------------------------------------------
	MAX_EQUIPPED_PETS = 3, -- base equip slots (PlayerData.PetSlots default); ExtraPets pass adds 2
	PET_INVENTORY_LIMIT = 200,
	TRIPLE_HATCH_COUNT = 3,

	-- Diggers (v2, Diggers agent; see docs/design/Diggers.md) ------------------------------
	DIGGER_BASE_SLOTS = 1, -- equip slots everyone has
	DIGGER_PASS_SLOTS = 1, -- extra slots from the AutoDig game pass
	DIGGER_REBIRTH_SLOTS = { 2, 5 }, -- +1 slot at each of these rebirth counts
	DIGGER_LEVEL_SPEED = 0.94, -- Interval x this per level above 1 (compounding)
	DIGGER_LEVEL_SAND = 0.15, -- SandMultiplier +15% of base per level above 1

	-- Social -------------------------------------------------------------------------------
	GROUP_ID = 0, -- OWNER: paste the Roblox group id; members get GROUP_SAND_MULTIPLIER
	GROUP_SAND_MULTIPLIER = 1.1,
	FRIEND_BONUS_PER_FRIEND = 0.05, -- +5% sand per friend in the same server...
	FRIEND_BONUS_MAX = 0.2, -- ...up to +20%
	LEADERBOARD_SIZE = 50,
	LEADERBOARD_REFRESH_SECONDS = 60,

	-- Retention ----------------------------------------------------------------------------
	DAILY_COOLDOWN_SECONDS = 20 * 3600,
	DAILY_STREAK_GRACE_SECONDS = 48 * 3600,

	-- Persistence --------------------------------------------------------------------------
	DATASTORE_NAME = "PlayerData_v1",
	LEADERBOARD_COINS_STORE = "Leaderboard_Coins",
	LEADERBOARD_DEPTH_STORE = "Leaderboard_Depth",
	DATA_VERSION = 1,
	AUTOSAVE_SECONDS = 120,
	SESSION_LOCK_SECONDS = 1800,

	-- Onboarding (FTUE) --------------------------------------------------------------------
	-- Complete events: "AtSand", "Dig", "BackpackFull", "Sell", "BuyShovel", "HatchEgg".
	-- Target "Sand" = the nearest point of the dig zone.
	TUTORIAL_STEPS = {
		{ Id = "go_sand", Text = "Follow the arrow to the sand!", Target = "Sand", Complete = "AtSand" },
		{ Id = "first_dig", Text = "Tap the sand to DIG!", Target = "Sand", Complete = "Dig" },
		{ Id = "fill_up", Text = "Keep digging until your bucket is full!", Complete = "BackpackFull" },
		{ Id = "sell", Text = "Bucket full! Run to the SELL stand.", Target = "SellZone", Complete = "Sell" },
		{ Id = "shop", Text = "Buy a better shovel to dig deeper!", Target = "ShovelShop", Complete = "BuyShovel" },
		{ Id = "egg", Text = "Hatch a pet - pets give you more sand!", Target = "EggShop", Complete = "HatchEgg" },
	} :: { Types.TutorialStep },
}

-- Lookup maps --------------------------------------------------------------------------------

local function indexById<T>(list: { T }, getId: (T) -> string): ({ [string]: T }, { [string]: number })
	local byId: { [string]: T } = {}
	local indexOf: { [string]: number } = {}
	for i, item in list do
		local id = getId(item)
		assert(byId[id] == nil, "Config: duplicate id " .. id)
		byId[id] = item
		indexOf[id] = i
	end
	return byId, indexOf
end

local shovelById, shovelIndex = indexById(Shovels, function(s: Types.ShovelDef)
	return s.Id
end)
local backpackById, backpackIndex = indexById(Backpacks, function(b: Types.BackpackDef)
	return b.Id
end)
local petById = indexById(Pets, function(p: Types.PetDef)
	return p.Id
end)
local eggById = indexById(Eggs, function(e: Types.EggDef)
	return e.Id
end)
local treasureById = indexById(Treasures, function(t: Types.TreasureDef)
	return t.Id
end)
local rarityByName = indexById(Rarities, function(r: Types.RarityDef)
	return r.Name
end)
local questById = indexById(Quests, function(q: Types.QuestDef)
	return q.Id
end)
local boostById = indexById(Boosts, function(b: Types.BoostDef)
	return b.Id
end)
local eventById = indexById(Events, function(e: Types.EventDef)
	return e.Id
end)
local codeByCode = indexById(Codes, function(c: Types.CodeDef)
	return string.upper(c.Code)
end)
local diggerById, diggerIndex = indexById(Diggers, function(d: Types.DiggerDef)
	return d.Id
end)

-- Helpers ------------------------------------------------------------------------------------

function Config.GetShovel(id: string): Types.ShovelDef?
	return shovelById[id]
end

function Config.GetShovelIndex(id: string): number?
	return shovelIndex[id]
end

function Config.GetBackpack(id: string): Types.BackpackDef?
	return backpackById[id]
end

function Config.GetBackpackIndex(id: string): number?
	return backpackIndex[id]
end

function Config.GetPet(id: string): Types.PetDef?
	return petById[id]
end

function Config.GetEgg(id: string): Types.EggDef?
	return eggById[id]
end

function Config.GetTreasure(id: string): Types.TreasureDef?
	return treasureById[id]
end

function Config.GetRarity(name: string): Types.RarityDef?
	return rarityByName[name]
end

function Config.GetQuest(id: string): Types.QuestDef?
	return questById[id]
end

function Config.GetBoost(id: string): Types.BoostDef?
	return boostById[id]
end

function Config.GetEvent(id: string): Types.EventDef?
	return eventById[id]
end

-- Case-insensitive, whitespace-trimmed. Returns nil for unknown codes (does NOT check Enabled/Expires).
function Config.GetCode(code: string): Types.CodeDef?
	local normalized = string.upper((string.gsub(code, "%s", "")))
	return codeByCode[normalized]
end

-- Index (1..#Layers) of the layer at `depth` studs below the surface. Clamped to the range.
function Config.GetLayerIndexAtDepth(depth: number): number
	if depth < 0 then
		return 1
	end
	for i, layer in Layers do
		if depth < layer.DepthEnd then
			return i
		end
	end
	return #Layers
end

function Config.GetLayerAtDepth(depth: number): Types.LayerDef
	return Layers[Config.GetLayerIndexAtDepth(depth)]
end

-- Deepest layer index this shovel power can dig (layers with Hardness <= power).
function Config.GetMaxLayerIndexForPower(power: number): number
	local best = 1
	for i, layer in Layers do
		if layer.Hardness <= power then
			best = i
		end
	end
	return best
end

function Config.DepthToMeters(depth: number): number
	return math.floor(math.max(depth, 0) / Config.STUDS_PER_METER)
end

-- Coins for the NEXT rebirth when the player has `rebirths` rebirths.
function Config.RebirthCost(rebirths: number): number
	return Rebirths.Cost(rebirths)
end

function Config.RebirthMultiplier(rebirths: number): number
	return Rebirths.Multiplier(rebirths)
end

function Config.RebirthTokens(rebirths: number): number
	return Rebirths.Tokens(rebirths)
end

-- Additive pet bonus: 1 + sum(Multiplier - 1). Unknown ids are ignored.
function Config.PetMultiplier(petIds: { string }): number
	local total = 1
	for _, id in petIds do
		local pet = petById[id]
		if pet then
			total += pet.Multiplier - 1
		end
	end
	return total
end

-- Flat Coins + ScaledCoins * RewardScale of the layer at maxDepth. Rounded down.
function Config.ResolveCoins(reward: Types.Reward, maxDepth: number): number
	local coins = reward.Coins or 0
	if reward.ScaledCoins then
		coins += reward.ScaledCoins * Config.GetLayerAtDepth(maxDepth).RewardScale
	end
	return math.floor(coins)
end

function Config.IsEggUnlocked(eggId: string, maxDepth: number): boolean
	local egg = eggById[eggId]
	if not egg then
		return false
	end
	local layer = Layers[egg.UnlockLayer]
	return layer ~= nil and maxDepth >= layer.DepthStart
end

-- Reward row for a streak value (1-based, cycles every #DailyRewards days).
function Config.GetDailyReward(streak: number): Types.DailyRewardDef
	local index = ((math.max(streak, 1) - 1) % #DailyRewards) + 1
	return DailyRewards[index]
end

-- Events active at unix time `now` (defaults to os.time()).
function Config.GetActiveEvents(now: number?): { Types.EventDef }
	local t = now or os.time()
	local active = {}
	for _, event in Events do
		if (t + event.OffsetSeconds) % event.IntervalSeconds < event.DurationSeconds then
			table.insert(active, event)
		end
	end
	return active
end

-- Seconds until the event next starts (0 if active now).
function Config.GetSecondsUntilEvent(eventId: string, now: number?): number
	local event = eventById[eventId]
	if not event then
		return math.huge
	end
	local phase = ((now or os.time()) + event.OffsetSeconds) % event.IntervalSeconds
	if phase < event.DurationSeconds then
		return 0
	end
	return event.IntervalSeconds - phase
end

function Config.GetGamePassKeyById(id: number): string?
	if id == 0 then
		return nil
	end
	for key, pass in Monetization.GamePasses do
		if pass.Id == id then
			return key
		end
	end
	return nil
end

function Config.GetProductKeyById(id: number): string?
	if id == 0 then
		return nil
	end
	for key, product in Monetization.Products do
		if product.Id == id then
			return key
		end
	end
	return nil
end

-- Diggers (v2) ---------------------------------------------------------------------------------

function Config.GetDigger(id: string): Types.DiggerDef?
	return diggerById[id]
end

function Config.GetDiggerIndex(id: string): number?
	return diggerIndex[id]
end

-- Effective stats at `level` (clamped to 1..MaxLevel). Power and Radius do not change with level.
function Config.GetDiggerStats(def: Types.DiggerDef, level: number): Types.DiggerStats
	local l = math.clamp(math.floor(level), 1, def.MaxLevel)
	return {
		Power = def.Power,
		Interval = def.Interval * Config.DIGGER_LEVEL_SPEED ^ (l - 1),
		Radius = def.Radius,
		SandMultiplier = def.SandMultiplier * (1 + Config.DIGGER_LEVEL_SAND * (l - 1)),
	}
end

-- Coins to upgrade from `level` to level + 1, or nil at max level.
function Config.GetDiggerUpgradeCost(def: Types.DiggerDef, level: number): number?
	if level >= def.MaxLevel then
		return nil
	end
	return def.UpgradeCosts[math.max(math.floor(level), 1)]
end

-- Digger equip slots: base + AutoDig pass + rebirth milestones.
function Config.GetDiggerSlots(rebirths: number, hasAutoDigPass: boolean): number
	local slots = Config.DIGGER_BASE_SLOTS
	if hasAutoDigPass then
		slots += Config.DIGGER_PASS_SLOTS
	end
	for _, needed in Config.DIGGER_REBIRTH_SLOTS do
		if rebirths >= needed then
			slots += 1
		end
	end
	return slots
end

-- Survival (v2) ---------------------------------------------------------------------------------

local shadeById, shadeIndex = indexById(Shades, function(d: Types.ShadeDef)
	return d.Id
end)
local consumableById = indexById(Consumables, function(d: Types.ConsumableDef)
	return d.Id
end)

function Config.GetShade(id: string): Types.ShadeDef?
	return shadeById[id]
end

function Config.GetShadeIndex(id: string): number?
	return shadeIndex[id]
end

function Config.GetConsumable(id: string): Types.ConsumableDef?
	return consumableById[id]
end

-- Number of layers whose every treasure is in `index` (collection book completion).
function Config.CountCompletedIndexLayers(index: { [string]: boolean }): number
	local complete = 0
	for _, layer in Layers do
		local all = true
		for _, entry in layer.LootTable do
			if not index[entry.TreasureId] then
				all = false
				break
			end
		end
		if all then
			complete += 1
		end
	end
	return complete
end

-- Fresh default save for a brand-new player.
function Config.NewPlayerData(): Types.PlayerData
	local firstShovel = Shovels[1].Id
	local firstBackpack = Backpacks[1].Id
	return {
		Coins = 0,
		Sand = 0,
		TotalSandDug = 0,
		Rebirths = 0,
		RebirthTokens = 0,
		MaxDepth = 0,
		Shovel = firstShovel,
		OwnedShovels = { [firstShovel] = true },
		Backpack = firstBackpack,
		OwnedBackpacks = { [firstBackpack] = true },
		Pets = {},
		PetSlots = Config.MAX_EQUIPPED_PETS,
		Treasures = {},
		Index = {},
		DailyStreak = 0,
		LastDailyClaim = 0,
		Quests = {},
		RedeemedCodes = {},
		Settings = {},
		Boosts = {},
		Consumables = {},
		OwnedShades = {},
		Diggers = {},
		PlayTime = 0,
		FirstJoin = os.time(),
		Version = Config.DATA_VERSION,
	}
end

-- Sanity checks on require (cheap; catches typos in ids when editing balance data) ----------

do
	for i, layer in Layers do
		assert(layer.DepthEnd > layer.DepthStart, "Config: bad depth band in layer " .. layer.Id)
		if i > 1 then
			assert(layer.DepthStart == Layers[i - 1].DepthEnd, "Config: gap before layer " .. layer.Id)
		end
		for _, entry in layer.LootTable do
			assert(treasureById[entry.TreasureId], "Config: unknown treasure " .. entry.TreasureId)
		end
	end
	for _, egg in Eggs do
		for _, entry in egg.Pets do
			assert(petById[entry.PetId], "Config: unknown pet " .. entry.PetId .. " in egg " .. egg.Id)
		end
		if egg.ProductKey then
			assert(Monetization.Products[egg.ProductKey], "Config: unknown product key " .. egg.ProductKey)
		end
	end
	for _, treasure in Treasures do
		assert(rarityByName[treasure.Rarity], "Config: unknown rarity on " .. treasure.Id)
	end
end

return Config
