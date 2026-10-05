--!strict
--[[
	Stats — the ONE place the multiplier stack is computed. Pure functions of a Context, used by
	the server (authoritative) and safe for the client to mirror for UI ("x12.5 sand", odds...).

	Building a Context on the client:
		{
			Data = <PlayerData from DataChanged/GetData>,
			Passes = <GetOwnedPasses() result>,
			IsPremium = player.MembershipType == Enum.MembershipType.Premium,
			InGroup = player:GetAttribute("InGroup") == true,
			FriendsInServer = player:GetAttribute("FriendsInServer") or 0,
			ActiveEvents = <EventChanged ids>,
			Now = os.time(),
		}
	(The server also publishes the results as Player attributes — see MultiplierService.)

	Sand per dig = layer.SandValue x shovel x rebirth x pets x passes x premium x group x friends
	               x index x Sand boosts x Sand events
	Capacity     = backpack.Capacity x rebirth x pass CapacityMultiplier (Mega Backpack)
	Luck         = pass LuckMultiplier (VIP, Lucky) x Luck boosts x Luck events
	Coins (sell) = Coins boosts x Coins events
	Speed        = pass SpeedMultiplier x Speed boosts x Speed events (cooldown is divided by it)
]]

local Shared = script.Parent.Parent
local Config = require(Shared.Config)
local Types = require(Shared.Types)

export type Context = {
	Data: Types.PlayerData,
	Passes: { [string]: boolean },
	IsPremium: boolean,
	InGroup: boolean,
	FriendsInServer: number,
	ActiveEvents: { string },
	Now: number,
}

export type Factor = {
	Name: string, -- short label for UI breakdowns ("Shovel", "Rebirth", "2x Sand"...)
	Value: number,
}

local Stats = {}

local PASS_KEYS: { string } = {}
for key in Config.Monetization.GamePasses do
	table.insert(PASS_KEYS, key)
end
table.sort(PASS_KEYS)

function Stats.Product(factors: { Factor }): number
	local total = 1
	for _, factor in factors do
		total *= factor.Value
	end
	return total
end

function Stats.GetShovel(data: Types.PlayerData): Types.ShovelDef
	return Config.GetShovel(data.Shovel) or Config.Shovels[1]
end

function Stats.GetBackpack(data: Types.PlayerData): Types.BackpackDef
	return Config.GetBackpack(data.Backpack) or Config.Backpacks[1]
end

-- Equip slots: PlayerData.PetSlots + ExtraPets pass.
function Stats.GetPetSlots(ctx: Context): number
	local slots = ctx.Data.PetSlots
	for _, key in PASS_KEYS do
		local pass = Config.Monetization.GamePasses[key]
		if ctx.Passes[key] and pass.ExtraPetSlots then
			slots += pass.ExtraPetSlots
		end
	end
	return slots
end

-- Equipped pet ids, capped at `maxSlots` (sorted by uid so the cap is deterministic).
function Stats.GetEquippedPetIds(data: Types.PlayerData, maxSlots: number): { string }
	local uids = {}
	for uid, pet in data.Pets do
		if pet.Equipped then
			table.insert(uids, uid)
		end
	end
	table.sort(uids)
	local ids = {}
	for i, uid in uids do
		if i > maxSlots then
			break
		end
		table.insert(ids, data.Pets[uid].Id)
	end
	return ids
end

function Stats.IsBoostActive(data: Types.PlayerData, boostId: string, now: number): boolean
	local expires = data.Boosts[boostId]
	return expires ~= nil and expires > now
end

-- Seconds left on a boost (0 when inactive).
function Stats.GetBoostRemaining(data: Types.PlayerData, boostId: string, now: number): number
	local expires = data.Boosts[boostId]
	if expires == nil then
		return 0
	end
	return math.max(0, expires - now)
end

-- Appends boost + event factors of a given kind.
local function addTimed(ctx: Context, kind: Types.BoostKind, factors: { Factor })
	local boostIds = {}
	for boostId, expires in ctx.Data.Boosts do
		if expires > ctx.Now then
			table.insert(boostIds, boostId)
		end
	end
	table.sort(boostIds)
	for _, boostId in boostIds do
		local def = Config.GetBoost(boostId)
		if def and def.Kind == kind then
			table.insert(factors, { Name = def.Name, Value = def.Multiplier })
		end
	end
	for _, eventId in ctx.ActiveEvents do
		local event = Config.GetEvent(eventId)
		if event and event.Kind == kind then
			table.insert(factors, { Name = event.Name, Value = event.Multiplier })
		end
	end
end

local function addPasses(ctx: Context, field: string, factors: { Factor })
	for _, key in PASS_KEYS do
		if ctx.Passes[key] then
			local pass = Config.Monetization.GamePasses[key] :: any
			local value = pass[field]
			if type(value) == "number" and value ~= 1 then
				table.insert(factors, { Name = pass.Name, Value = value })
			end
		end
	end
end

-- Sand ----------------------------------------------------------------------------------------

function Stats.GetSandFactors(ctx: Context): { Factor }
	local data = ctx.Data
	local factors: { Factor } = {
		{ Name = "Shovel", Value = Stats.GetShovel(data).SandMultiplier },
		{ Name = "Rebirth", Value = Config.RebirthMultiplier(data.Rebirths) },
		{ Name = "Pets", Value = Config.PetMultiplier(Stats.GetEquippedPetIds(data, Stats.GetPetSlots(ctx))) },
	}
	addPasses(ctx, "SandMultiplier", factors)
	if ctx.IsPremium then
		table.insert(factors, { Name = "Premium", Value = Config.Monetization.Premium.SandMultiplier })
	end
	if ctx.InGroup and Config.GROUP_ID ~= 0 then
		table.insert(factors, { Name = "Group", Value = Config.GROUP_SAND_MULTIPLIER })
	end
	local friends = math.max(0, math.floor(ctx.FriendsInServer))
	if friends > 0 then
		local bonus = math.min(friends * Config.FRIEND_BONUS_PER_FRIEND, Config.FRIEND_BONUS_MAX)
		table.insert(factors, { Name = "Friends", Value = 1 + bonus })
	end
	local completed = Config.CountCompletedIndexLayers(data.Index)
	if completed > 0 then
		table.insert(factors, { Name = "Index", Value = 1 + completed * Config.INDEX_LAYER_BONUS })
	end
	addTimed(ctx, "Sand", factors)
	return factors
end

function Stats.GetSandMultiplier(ctx: Context): number
	return Stats.Product(Stats.GetSandFactors(ctx))
end

function Stats.GetSandPerDig(ctx: Context, layerIndex: number): number
	local layer = Config.Layers[math.clamp(layerIndex, 1, #Config.Layers)]
	return layer.SandValue * Stats.GetSandMultiplier(ctx)
end

-- Capacity ------------------------------------------------------------------------------------

function Stats.GetCapacity(ctx: Context): number
	local factors: { Factor } = {
		{ Name = "Rebirth", Value = Config.RebirthMultiplier(ctx.Data.Rebirths) },
	}
	addPasses(ctx, "CapacityMultiplier", factors)
	return math.floor(Stats.GetBackpack(ctx.Data).Capacity * Stats.Product(factors))
end

-- Luck ----------------------------------------------------------------------------------------

function Stats.GetLuckFactors(ctx: Context): { Factor }
	local factors: { Factor } = {}
	addPasses(ctx, "LuckMultiplier", factors)
	addTimed(ctx, "Luck", factors)
	return factors
end

function Stats.GetLuck(ctx: Context): number
	return Stats.Product(Stats.GetLuckFactors(ctx))
end

-- Chance (0..MAX_TREASURE_CHANCE) that a successful dig in this layer finds a treasure.
function Stats.GetTreasureChance(ctx: Context, layerIndex: number): number
	local layer = Config.Layers[math.clamp(layerIndex, 1, #Config.Layers)]
	return math.min(layer.TreasureChance * Stats.GetLuck(ctx), Config.MAX_TREASURE_CHANCE)
end

-- Luck multiplies the weight of every non-Common entry (loot tables and eggs).
function Stats.LuckWeight(baseWeight: number, rarity: Types.Rarity?, luck: number): number
	if rarity == nil or rarity == "Common" then
		return baseWeight
	end
	return baseWeight * luck
end

-- Coins & speed -------------------------------------------------------------------------------

function Stats.GetCoinFactors(ctx: Context): { Factor }
	local factors: { Factor } = {}
	addTimed(ctx, "Coins", factors)
	return factors
end

function Stats.GetCoinMultiplier(ctx: Context): number
	return Stats.Product(Stats.GetCoinFactors(ctx))
end

function Stats.GetSpeedMultiplier(ctx: Context): number
	local factors: { Factor } = {}
	addPasses(ctx, "SpeedMultiplier", factors)
	addTimed(ctx, "Speed", factors)
	return math.max(Stats.Product(factors), 0.01)
end

-- Seconds between digs with the equipped shovel (before server latency leniency).
function Stats.GetCooldown(ctx: Context): number
	return Stats.GetShovel(ctx.Data).Cooldown / Stats.GetSpeedMultiplier(ctx)
end

-- Coins a full sell would pay right now (sand + unsold treasures, coin multipliers applied).
function Stats.GetSellValue(ctx: Context): number
	local data = ctx.Data
	local total = math.max(data.Sand, 0) * Config.SELL_RATE
	for treasureId, count in data.Treasures do
		local def = Config.GetTreasure(treasureId)
		if def and count > 0 then
			total += def.SellValue * count
		end
	end
	return math.floor(total * Stats.GetCoinMultiplier(ctx))
end

return Stats
