--!strict
--[[
	PetService — eggs and pets.

	HatchEgg(eggId, count): count 1, or Config.TRIPLE_HATCH_COUNT with the TripleHatch pass.
	Coins/Tokens eggs only (Robux eggs are granted through their developer product; asking to
	hatch one prompts the product). Egg must be unlocked (Config.IsEggUnlocked by MaxDepth),
	inventory must have room (Config.PET_INVENTORY_LIMIT). Luck (Lucky pass, VIP, LuckBoost,
	High Tide) multiplies the weight of non-Common pets. New pets auto-equip while slots are free.
	Fires EggHatched({petId...}) to the hatcher; Legendary/Mythic hatches are announced.

	Equip/Unequip/Delete by uid; equip slots = PlayerData.PetSlots + ExtraPets pass.

	Public API:
		PetService.GrantPet(player, petId, autoEquip?): string?  (uid)
		PetService.HatchFree(player, eggId, count): { string }   (rewards/products; no cost/unlock/limit)
		PetService.GetSlots(player): number
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Format = require(Shared.Util.Format)
local Stats = require(Shared.Util.Stats)
local TableUtil = require(Shared.Util.TableUtil)
local Weighted = require(Shared.Util.Weighted)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local MultiplierService = require(script.Parent.MultiplierService)
local Net = require(script.Parent.Net)
local ServerSignals = require(script.Parent.ServerSignals)

local PetService = {}

local rng = Random.new()

function PetService.GetSlots(player: Player): number
	local ctx = MultiplierService.GetContext(player)
	return if ctx then Stats.GetPetSlots(ctx) else Config.MAX_EQUIPPED_PETS
end

local function countEquipped(data: Types.PlayerData): number
	local n = 0
	for _, pet in data.Pets do
		if pet.Equipped then
			n += 1
		end
	end
	return n
end

local function roll(egg: Types.EggDef, luck: number): string?
	local entry = Weighted.Pick(egg.Pets, function(e: Types.EggEntry): number
		local pet = Config.GetPet(e.PetId)
		return Stats.LuckWeight(e.Weight, if pet then pet.Rarity else nil, luck)
	end, rng:NextNumber())
	return if entry then entry.PetId else nil
end

local function announce(player: Player, petId: string)
	local pet = Config.GetPet(petId)
	local rarity = pet and Config.GetRarity(pet.Rarity)
	if pet and rarity and rarity.Announce then
		Net.NotifyAll(
			"Announce",
			string.format("%s hatched a %s %s!", player.DisplayName, string.upper(pet.Rarity), pet.Name)
		)
	end
end

function PetService.GrantPet(player: Player, petId: string, autoEquip: boolean?): string?
	local data = DataService.Get(player)
	if not data or not Config.GetPet(petId) then
		return nil
	end
	local uid = HttpService:GenerateGUID(false)
	local equip = autoEquip ~= false and countEquipped(data) < PetService.GetSlots(player)
	data.Pets[uid] = { Id = petId, Equipped = equip }
	DataService.MarkDirty(player, "Pets")
	return uid
end

-- Rolls `count` pets from an egg and grants them. No cost / unlock / inventory checks.
local function hatch(player: Player, egg: Types.EggDef, count: number): { string }
	local ctx = MultiplierService.GetContext(player)
	local luck = if ctx then Stats.GetLuck(ctx) else 1
	local results = {}
	for _ = 1, count do
		local petId = roll(egg, luck)
		if petId and PetService.GrantPet(player, petId) then
			table.insert(results, petId)
		end
	end
	if #results > 0 then
		Net.FireClient("EggHatched", player, results)
		for _, petId in results do
			announce(player, petId)
		end
		ServerSignals.Hatched:Fire(player, #results, egg.Id)
		Analytics.Funnel(player, Analytics.Steps.FirstEgg)
	end
	return results
end

function PetService.HatchFree(player: Player, eggId: string, count: number): { string }
	local egg = Config.GetEgg(eggId)
	if not egg or not DataService.Get(player) then
		return {}
	end
	return hatch(player, egg, math.clamp(math.floor(count), 1, 10))
end

local function onHatchEgg(player: Player, eggId: any, count: any)
	if not Net.IsString(eggId, 64) then
		return
	end
	if count == nil then
		count = 1
	end
	if count ~= 1 and count ~= Config.TRIPLE_HATCH_COUNT then
		return
	end
	local data = DataService.Get(player)
	local egg = Config.GetEgg(eggId)
	if not data or not egg then
		return
	end
	if count > 1 and not MonetizationService.OwnsPass(player, "TripleHatch") then
		Net.Notify(player, "Error", "Get Triple Hatch to open 3 at once!")
		return
	end
	if egg.Currency == "Robux" then
		if egg.ProductKey then
			MonetizationService.PromptProduct(player, egg.ProductKey)
		end
		return
	end
	if not Config.IsEggUnlocked(egg.Id, data.MaxDepth) then
		local layer = Config.Layers[egg.UnlockLayer]
		Net.Notify(player, "Error", "Dig to " .. (if layer then layer.Name else "deeper") .. " to unlock this egg!")
		return
	end
	if TableUtil.Count(data.Pets) + count > Config.PET_INVENTORY_LIMIT then
		Net.Notify(player, "Error", "Your pet inventory is full! Delete some pets.")
		return
	end

	local cost = egg.Price * count
	local isTokens = egg.Currency == "Tokens"
	local balance = if isTokens then data.RebirthTokens else data.Coins
	if balance < cost then
		Net.Notify(
			player,
			"Error",
			if isTokens
				then "Not enough Rebirth Tokens!"
				else "Not enough coins! Need " .. Format.Abbreviate(cost - balance) .. " more."
		)
		return
	end

	local currencyKey = if isTokens then "RebirthTokens" else "Coins"
	DataService.Increment(player, currencyKey, -cost)
	Analytics.Sink(
		player,
		if isTokens then "Tokens" else "Coins",
		cost,
		(data :: any)[currencyKey],
		Enum.AnalyticsEconomyTransactionType.Shop,
		"Egg:" .. egg.Id
	)
	hatch(player, egg, count)
end

local function findPet(player: Player, uid: any): (Types.PlayerData?, Types.PetInstance?)
	if not Net.IsString(uid, 64) then
		return nil, nil
	end
	local data = DataService.Get(player)
	if not data then
		return nil, nil
	end
	return data, data.Pets[uid]
end

local function onEquip(player: Player, uid: any)
	local data, pet = findPet(player, uid)
	if not data or not pet or pet.Equipped then
		return
	end
	if countEquipped(data) >= PetService.GetSlots(player) then
		Net.Notify(player, "Error", "All pet slots are full! Unequip a pet first.")
		return
	end
	pet.Equipped = true
	DataService.MarkDirty(player, "Pets")
end

local function onUnequip(player: Player, uid: any)
	local data, pet = findPet(player, uid)
	if not data or not pet or not pet.Equipped then
		return
	end
	pet.Equipped = false
	DataService.MarkDirty(player, "Pets")
end

local function onDelete(player: Player, uid: any)
	local data, pet = findPet(player, uid)
	if not data or not pet then
		return
	end
	data.Pets[uid :: string] = nil
	DataService.MarkDirty(player, "Pets")
end

-- If slots shrank (e.g. pass refunded), unequip extras so the stored state matches the stats.
local function trimEquipped(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local slots = PetService.GetSlots(player)
	local equipped = {}
	for uid, pet in data.Pets do
		if pet.Equipped then
			table.insert(equipped, uid)
		end
	end
	if #equipped <= slots then
		return
	end
	table.sort(equipped)
	for i = slots + 1, #equipped do
		data.Pets[equipped[i]].Equipped = false
	end
	DataService.MarkDirty(player, "Pets")
end

function PetService.Init()
	Net.On("HatchEgg", onHatchEgg, { Rate = 3, Window = 1 })
	Net.On("EquipPet", onEquip, { Rate = 10, Window = 1 })
	Net.On("UnequipPet", onUnequip, { Rate = 10, Window = 1 })
	Net.On("DeletePet", onDelete, { Rate = 10, Window = 1 })
end

function PetService.Start()
	-- Pass ownership arrives asynchronously after load; trim only once it settled.
	MonetizationService.PassesChanged:Connect(function(player: Player)
		trimEquipped(player)
	end)
end

return PetService
