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
local Ride = require(script.Ride) -- v2.1 ride-on excavator tuning (Ride agent)
local RebirthPerks = require(script.RebirthPerks) -- v2.2 rebirth token perk shop (Rebirth agent)
local Titles = require(script.Titles) -- v2.2 nameplate titles (Status & Social agent)
local Social = require(script.Social) -- v2.2 announcements / leaderboard scopes / server goal
local Discovery = require(script.Discovery) -- v3 buried finds / detector / excavation (Discovery agent)

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
	Ride = Ride,
	RebirthPerks = RebirthPerks,
	Titles = Titles,
	Social = Social,
	Discovery = Discovery,

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
	-- Base equip slots (PlayerData.PetSlots default). Passes add GamePasses[*].ExtraPetSlots:
	-- ExtraPets +2, AutoDig +1 (Stats.GetPetSlots).
	MAX_EQUIPPED_PETS = 3,
	PET_INVENTORY_LIMIT = 200,
	TRIPLE_HATCH_COUNT = 3,
	-- v2.2 hatch pity + duplicate fusion (docs/design/Companions.md "Pity and Golden pets").
	PITY_MIN_RARITY_ORDER = 3, -- "Rare or better" (RarityDef.Order); EggDef.PityAt per egg
	GOLDEN_FUSE_COUNT = 5, -- identical non-golden copies fused into one Golden pet
	GOLDEN_SAND_BONUS = 1.5, -- a Golden pet's sand bonus (Multiplier - 1) is x1.5
	GOLDEN_DIG_SPEED = 1.25, -- a Golden digging pet digs 1.25x as often (Interval / 1.25)

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
	-- 2: v2.1 converts data.Diggers into vehicle pets; 3: v3 moves unsold Treasures into Finds
	-- (DataService migrations)
	DATA_VERSION = 3,
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
		{ Id = "dig_deeper", Text = "New shovel! Dig DOWN into a new layer!", Target = "Sand", Complete = "NewLayer" },
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
-- v2.2: golden[i] = true marks petIds[i] as a Golden pet (bonus x GOLDEN_SAND_BONUS).
function Config.PetMultiplier(petIds: { string }, golden: { [number]: boolean }?): number
	local total = 1
	for i, id in petIds do
		local pet = petById[id]
		if pet then
			local bonus = pet.Multiplier - 1
			if golden and golden[i] then
				bonus *= Config.GOLDEN_SAND_BONUS
			end
			total += bonus
		end
	end
	return total
end

-- v2.2: one pet's own multiplier (1 + bonus), Golden included. Unknown id -> 1.
function Config.PetEffectiveMultiplier(petId: string, golden: boolean?): number
	return Config.PetMultiplier({ petId }, { golden == true })
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

-- Companions (v2.1) ---------------------------------------------------------------------------

-- Construction Crates are eggs with Kind = "Crate" (they hatch vehicle pets).
function Config.IsCrate(eggId: string): boolean
	local egg = eggById[eggId]
	return egg ~= nil and egg.Kind == "Crate"
end

-- The pet's dig ability (vehicles from crates, a few creatures), or nil.
function Config.GetPetDig(petId: string): Types.PetDigDef?
	local pet = petById[petId]
	return if pet then pet.Dig else nil
end

-- v2.2: seconds between digs for this pet; Golden pets dig GOLDEN_DIG_SPEED x as often.
function Config.GetPetDigInterval(petId: string, golden: boolean?): number?
	local dig = Config.GetPetDig(petId)
	if not dig then
		return nil
	end
	return (dig :: Types.PetDigDef).Interval / (if golden then Config.GOLDEN_DIG_SPEED else 1)
end

-- Compliance (v2.2) -----------------------------------------------------------------------------

-- Is this pass / product a paid random item, a paid luck modifier or currency that buys random
-- items (Monetization PaidRandom)? Those are hidden and refused for PolicyService-restricted
-- players (ArePaidRandomItemsRestricted). kind: "GamePass" | "Product".
function Config.IsPaidRandom(kind: string, key: string): boolean
	if kind == "GamePass" then
		local pass = Monetization.GamePasses[key]
		return pass ~= nil and pass.PaidRandom == true
	elseif kind == "Product" then
		local product = Monetization.Products[key]
		return product ~= nil and product.PaidRandom == true
	end
	return false
end

-- Ride (v2.1, Ride agent) ----------------------------------------------------------------------

-- The best rideable pet (PetDef.Rideable) among an inventory (PlayerData.Pets), or nil. Scans
-- Config.Pets (not the id map) so every def counts. Best = highest Dig.Power, then SandMultiplier.
function Config.FindRideablePet(pets: { [string]: Types.PetInstance }?): Types.PetDef?
	if not pets then
		return nil
	end
	local owned: { [string]: boolean } = {}
	for _, pet in pets :: { [string]: Types.PetInstance } do
		if type(pet) == "table" and type(pet.Id) == "string" then
			owned[pet.Id] = true
		end
	end
	local best: Types.PetDef? = nil
	for _, def in Pets do
		if def.Rideable == true and owned[def.Id] then
			local current = best
			local power = if def.Dig then def.Dig.Power else 0
			local sand = if def.Dig then def.Dig.SandMultiplier else 0
			local bestPower = if current and current.Dig then current.Dig.Power else -1
			local bestSand = if current and current.Dig then current.Dig.SandMultiplier else -1
			if current == nil or power > bestPower or (power == bestPower and sand > bestSand) then
				best = def
			end
		end
	end
	return best
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

-- Status & Social (v2.2) ------------------------------------------------------------------------

-- Nameplate title for a layer index (clamped to 1..#Layers): (title, colour).
function Config.GetTitle(layerIndex: number): (string, Color3)
	local index = math.clamp(math.floor(layerIndex), 1, #Titles)
	local def = Titles[index]
	return def.Title, def.Color or Layers[index].Color
end

-- Server dig goal (sand) for a server whose players have these MaxDepth values. See Config/Social.
function Config.ServerGoalTarget(maxDepths: { number }): number
	local goal = Social.ServerGoal
	local total = 0
	for _, depth in maxDepths do
		local layer = Config.GetLayerAtDepth(depth)
		total += math.max(goal.PerPlayerSand, layer.RewardScale * goal.DigSeconds)
	end
	total = math.max(total, goal.MinSand)
	return math.ceil(total / goal.Round) * goal.Round
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
		Finds = {}, -- v3 discovery
		FindVariants = {}, -- v3 discovery
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
		LastOnline = 0,
		Pity = {},
		RebirthPerks = {},
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
		if egg.PityAt then
			local hasRarePlus = false
			for _, entry in egg.Pets do
				local rarity = rarityByName[petById[entry.PetId].Rarity]
				hasRarePlus = hasRarePlus or rarity.Order >= Config.PITY_MIN_RARITY_ORDER
			end
			assert(egg.PityAt >= 1 and hasRarePlus, "Config: PityAt needs a Rare+ pet in egg " .. egg.Id)
		end
	end
	for _, treasure in Treasures do
		assert(rarityByName[treasure.Rarity], "Config: unknown rarity on " .. treasure.Id)
		assert(not string.find(treasure.Id, "[|/]"), "Config: treasure ids may not contain | or / " .. treasure.Id)
		if treasure.Rarity == "Relic" then
			assert((treasure.ScaledValue or 0) > 0, "Config: Relic without ScaledValue " .. treasure.Id)
		end
	end
	assert(#Discovery.DENSITY == #Layers, "Config: one Discovery.DENSITY per layer")
	for _, group in { Discovery.SIZES, Discovery.MATERIALS } do
		local total = 0
		for _, v in group do
			total += v.Weight
		end
		assert(math.abs(total - 100) < 1e-6, "Config: Discovery variant weights must sum to 100")
	end
	-- v2.3 paid randomness rules (owner decision, docs/CHANGELOG.md v2.3): no Robux item sells
	-- a random outcome or a luck modifier.
	for _, egg in Eggs do
		assert(egg.Currency ~= "Robux" and egg.ProductKey == nil, "Config: eggs are never sold for Robux " .. egg.Id)
	end
	for key, pass in Monetization.GamePasses do
		assert(pass.LuckMultiplier == nil, "Config: no paid luck (pass " .. key .. ")")
	end
	for key, product in Monetization.Products do
		local boostDef: Types.BoostDef? = nil
		for _, b in Boosts do
			if b.Id == product.Grant.Boost then
				boostDef = b
			end
		end
		assert(product.Grant.Egg == nil, "Config: no paid eggs (product " .. key .. ")")
		assert(not (boostDef and boostDef.Kind == "Luck"), "Config: no paid luck (product " .. key .. ")")
	end
	assert(#Titles == #Layers, "Config: one title per layer")
	for i, title in Titles do
		assert(title.LayerId == Layers[i].Id, "Config: title " .. i .. " is not for layer " .. Layers[i].Id)
	end
	for _, pet in Pets do
		local dig = pet.Dig
		if dig then
			assert(dig.Power > 0 and dig.Interval > 0 and dig.Radius > 0, "Config: bad Dig stats on " .. pet.Id)
		end
	end
	for _, egg in Eggs do
		if egg.Kind == "Crate" then
			for _, entry in egg.Pets do
				assert(petById[entry.PetId].Dig, "Config: crate pet without Dig " .. entry.PetId)
			end
		end
	end
end

return Config
