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
	Capacity     = backpack.Capacity x rebirth x pass CapacityMultiplier (Mega Backpack) x Deep Pockets perk
	Luck         = Luck boosts x Luck events (v2.3: no pass sells luck; LuckMultiplier stays
	               supported but Config rejects it on passes)
	Coins (sell) = Golden Touch perk x pass CoinMultiplier (VIP, v2.3) x Coins boosts x Coins events
	(v2.2 Rebirth perks, Config.RebirthPerks: Pet Den adds pet slots, Lucky Digger multiplies the
	treasure chance only.)
	Speed        = pass SpeedMultiplier x Speed boosts x Speed events (cooldown is divided by it)

	v2.2 TRUE ODDS (Roblox policy: paid random items show their real, modified odds):
	Stats.GetHatchOdds(egg, luck, pityCount?) -> ({ [petId]: probability }, pityActive)
	Stats.GetHatchOddsList(egg, luck, pityCount?) -> ({ { PetId, Chance } } in egg order, pityActive)
	Stats.RollHatch(egg, luck, pityCount, roll) -> petId?
	The server rolls with RollHatch (= Weighted.Pick over GetHatchOddsList) and the egg panel
	displays GetHatchOddsList with the same luck (Stats.GetLuck) and pity counter
	(PlayerData.Pity[egg.Id]), so what players see is exactly what the server rolls.
]]

local Shared = script.Parent.Parent
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Finds = require(script.Parent.Finds) -- v3 discovery slice
local Weighted = require(script.Parent.Weighted)

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
	local slots = ctx.Data.PetSlots + Config.RebirthPerks.ExtraPetSlots(ctx.Data.RebirthPerks) -- v2.2 Pet Den
	for _, key in PASS_KEYS do
		local pass = Config.Monetization.GamePasses[key]
		if ctx.Passes[key] and pass.ExtraPetSlots then
			slots += pass.ExtraPetSlots
		end
	end
	return slots
end

-- Equipped pet ids, capped at `maxSlots` (sorted by uid so the cap is deterministic).
-- v2.2: second result golden[i] = true when ids[i] is a Golden pet (Config.PetMultiplier).
function Stats.GetEquippedPetIds(data: Types.PlayerData, maxSlots: number): ({ string }, { [number]: boolean })
	local uids = {}
	for uid, pet in data.Pets do
		if pet.Equipped then
			table.insert(uids, uid)
		end
	end
	table.sort(uids)
	local ids = {}
	local golden: { [number]: boolean } = {}
	for i, uid in uids do
		if i > maxSlots then
			break
		end
		table.insert(ids, data.Pets[uid].Id)
		if data.Pets[uid].Golden == true then
			golden[#ids] = true
		end
	end
	return ids, golden
end

-- v2.2: equipped pets (valid ids) in the order of the "EquippedPets" attribute: by Id, normal
-- before Golden. PetService (attributes), PetDigService (slots) and the client all use this.
function Stats.SortEquipped(pets: { [string]: Types.PetInstance }): { Types.PetInstance }
	local list: { Types.PetInstance } = {}
	for _, pet in pets do
		if pet.Equipped and Config.GetPet(pet.Id) then
			table.insert(list, pet)
		end
	end
	table.sort(list, function(a: Types.PetInstance, b: Types.PetInstance): boolean
		if a.Id ~= b.Id then
			return a.Id < b.Id
		end
		return a.Golden ~= true and b.Golden == true
	end)
	return list
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

-- Additive pet bonus of the equipped pets (Golden pets count x GOLDEN_SAND_BONUS).
function Stats.GetPetMultiplier(ctx: Context): number
	local ids, golden = Stats.GetEquippedPetIds(ctx.Data, Stats.GetPetSlots(ctx))
	return Config.PetMultiplier(ids, golden)
end

function Stats.GetSandFactors(ctx: Context): { Factor }
	local data = ctx.Data
	local factors: { Factor } = {
		{ Name = "Shovel", Value = Stats.GetShovel(data).SandMultiplier },
		{ Name = "Rebirth", Value = Config.RebirthMultiplier(data.Rebirths) },
		{ Name = "Pets", Value = Stats.GetPetMultiplier(ctx) },
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
	local pockets = Config.RebirthPerks.CapacityFactor(ctx.Data.RebirthPerks) -- v2.2 Deep Pockets perk
	if pockets ~= 1 then
		table.insert(factors, { Name = "Deep Pockets", Value = pockets })
	end
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
	-- v2.2 Lucky Digger perk: treasure chance only (egg odds are untouched by it)
	local perk = Config.RebirthPerks.TreasureFactor(ctx.Data.RebirthPerks)
	return math.min(layer.TreasureChance * Stats.GetLuck(ctx) * perk, Config.MAX_TREASURE_CHANCE)
end

-- Luck multiplies the weight of every non-Common entry (loot tables and eggs).
function Stats.LuckWeight(baseWeight: number, rarity: Types.Rarity?, luck: number): number
	if rarity == nil or rarity == "Common" then
		return baseWeight
	end
	return baseWeight * luck
end

-- Hatch odds + pity (v2.2) -----------------------------------------------------------------------

export type HatchOdd = { PetId: string, Chance: number }

local function rarityOrderOf(petId: string): number
	local pet = Config.GetPet(petId)
	local rarity = if pet then Config.GetRarity(pet.Rarity) else nil
	return if rarity then rarity.Order else 0
end

-- Does this pet count as "Rare or better" for pity?
function Stats.IsPityRarity(petId: string): boolean
	return rarityOrderOf(petId) >= Config.PITY_MIN_RARITY_ORDER
end

-- Pity is active (the next hatch is guaranteed Rare+) after egg.PityAt hatches without one.
function Stats.IsPityActive(egg: Types.EggDef, pityCount: number?): boolean
	local at = egg.PityAt
	return at ~= nil and (pityCount or 0) >= at
end

-- Which upcoming hatch is guaranteed Rare+: 1 = the next one. nil when the egg has no pity.
function Stats.HatchesUntilPity(egg: Types.EggDef, pityCount: number?): number?
	local at = egg.PityAt
	if at == nil then
		return nil
	end
	return math.max(1, (at :: number) + 1 - (pityCount or 0))
end

-- The pity counter after hatching petId (reset by a Rare+ pet, otherwise +1).
function Stats.NextPityCount(egg: Types.EggDef, pityCount: number?, petId: string): number
	if egg.PityAt == nil or Stats.IsPityRarity(petId) then
		return 0
	end
	return (pityCount or 0) + 1
end

local function sanitizeLuck(luck: number): number
	if luck ~= luck or luck <= 0 or luck == math.huge then
		return 1
	end
	return luck
end

-- THE odds function. Probability of each pet for ONE hatch of `egg` with this luck (Stats.GetLuck)
-- and pity counter (PlayerData.Pity[egg.Id]); in egg order. Luck multiplies the weight of every
-- non-Common pet (Stats.LuckWeight). When pity is active only Rare+ pets keep their (luck)
-- weight. Returns (list, pityActive). Chances sum to 1.
function Stats.GetHatchOddsList(egg: Types.EggDef, luck: number, pityCount: number?): ({ HatchOdd }, boolean)
	local l = sanitizeLuck(luck)
	local pity = Stats.IsPityActive(egg, pityCount)
	local weights: { number } = {}
	for i, entry in egg.Pets do
		local pet = Config.GetPet(entry.PetId)
		local w = Stats.LuckWeight(entry.Weight, if pet then pet.Rarity else nil, l)
		if pity and not Stats.IsPityRarity(entry.PetId) then
			w = 0
		end
		weights[i] = w
	end
	local indices: { number } = {}
	for i in egg.Pets do
		indices[i] = i
	end
	local probabilities = Weighted.Odds(indices, function(i: number): number
		return weights[i]
	end)
	local list: { HatchOdd } = {}
	for i, entry in egg.Pets do
		list[i] = { PetId = entry.PetId, Chance = probabilities[i] }
	end
	return list, pity
end

-- Same odds keyed by pet id (an egg lists each pet once).
function Stats.GetHatchOdds(egg: Types.EggDef, luck: number, pityCount: number?): ({ [string]: number }, boolean)
	local list, pity = Stats.GetHatchOddsList(egg, luck, pityCount)
	local map: { [string]: number } = {}
	for _, odd in list do
		map[odd.PetId] = (map[odd.PetId] or 0) + odd.Chance
	end
	return map, pity
end

-- Server roll: `roll` in [0, 1) (Random:NextNumber()). Picks from GetHatchOddsList, so the
-- shown odds and the real roll can never diverge.
function Stats.RollHatch(egg: Types.EggDef, luck: number, pityCount: number?, roll: number): string?
	local list = Stats.GetHatchOddsList(egg, luck, pityCount)
	local odd = Weighted.Pick(list, function(o: HatchOdd): number
		return o.Chance
	end, roll)
	return if odd then odd.PetId else nil
end

-- Coins & speed -------------------------------------------------------------------------------

function Stats.GetCoinFactors(ctx: Context): { Factor }
	local factors: { Factor } = {}
	local touch = Config.RebirthPerks.CoinFactor(ctx.Data.RebirthPerks) -- v2.2 Golden Touch perk
	if touch ~= 1 then
		table.insert(factors, { Name = "Golden Touch", Value = touch })
	end
	addPasses(ctx, "CoinMultiplier", factors) -- v2.3: VIP +10% sell coins
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

-- Coins a full sell would pay right now (sand + unsold treasures + v3 finds, coin multipliers
-- applied). Finds: Util/Finds.TotalValue (base x size x material x quality).
function Stats.GetSellValue(ctx: Context): number
	local data = ctx.Data
	local total = math.max(data.Sand, 0) * Config.SELL_RATE
	for treasureId, count in data.Treasures do
		local def = Config.GetTreasure(treasureId)
		if def and count > 0 then
			total += def.SellValue * count
		end
	end
	total += Finds.TotalValue(data.Finds, data.MaxDepth)
	return math.floor(total * Stats.GetCoinMultiplier(ctx))
end

return Stats
