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

	v2.2:
	  - TRUE ODDS: every roll is Stats.RollHatch(egg, Stats.GetLuck(ctx), data.Pity[egg.Id], r),
	    which picks from Stats.GetHatchOddsList, the same function the egg panel displays.
	    EggHatched(results, { EggId, Chances = {probability of each result}, Pity = {bool} }).
	  - PITY: data.Pity[eggId] counts hatches in a row without a Rare+ pet; at EggDef.PityAt the
	    next hatch rolls only among the Rare+ pets. Every hatch of the egg counts (paid, free,
	    rewards).
	  - FUSION: FusePets(uid) turns Config.GOLDEN_FUSE_COUNT (5) identical non-golden copies (the
	    selected one + unequipped copies first) into ONE Golden pet (PetInstance.Golden), which
	    stays equipped if any fused copy was. Golden: sand bonus x GOLDEN_SAND_BONUS, digs
	    GOLDEN_DIG_SPEED x as often. Golden pets can't be fused again.
	  - Attributes: "EquippedPets" (ids in Stats.SortEquipped order) and "EquippedGolden"
	    (comma-separated 1-based slots of Golden pets in that list).

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

local function roll(egg: Types.EggDef, luck: number, pityCount: number?): string?
	return Stats.RollHatch(egg, luck, pityCount, rng:NextNumber())
end

-- Tests: the exact server roll (same rng path as a real hatch).
PetService._Roll = roll

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
	assert(data) -- refine for the type checker (guarded above)
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
	local data = DataService.Get(player)
	local pityTable: { [string]: number } = if data then data.Pity else {}
	local results = {}
	local chances = {}
	local pityHits = {}
	for _ = 1, count do
		local pityCount = pityTable[egg.Id] or 0
		local odds, pityActive = Stats.GetHatchOdds(egg, luck, pityCount)
		local petId = roll(egg, luck, pityCount)
		if petId and PetService.GrantPet(player, petId) then
			table.insert(results, petId)
			table.insert(chances, odds[petId] or 0)
			table.insert(pityHits, pityActive)
			if egg.PityAt then
				pityTable[egg.Id] = Stats.NextPityCount(egg, pityCount, petId)
			end
		end
	end
	if data and egg.PityAt and #results > 0 then
		DataService.MarkDirty(player, "Pity")
	end
	if #results > 0 then
		Net.FireClient("EggHatched", player, results, { EggId = egg.Id, Chances = chances, Pity = pityHits })
		for _, petId in results do
			announce(player, petId)
		end
		ServerSignals.Hatched:Fire(player, #results, egg.Id)
		Analytics.Hatched(player, egg.Id, results)
	end
	return results
end

function PetService.HatchFree(player: Player, eggId: string, count: number): { string }
	local egg = Config.GetEgg(eggId)
	if not egg or not DataService.Get(player) then
		return {}
	end
	assert(egg) -- refine for the type checker (guarded above)
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
	assert(data) -- refine for the type checker (guarded above)
	assert(egg) -- refine for the type checker (guarded above)
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
	assert(data) -- refine for the type checker (guarded above)
	return data, data.Pets[uid]
end

local function onEquip(player: Player, uid: any)
	local data, pet = findPet(player, uid)
	if not data or not pet or pet.Equipped then
		return
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(pet) -- refine for the type checker (guarded above)
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
	assert(data) -- refine for the type checker (guarded above)
	assert(pet) -- refine for the type checker (guarded above)
	pet.Equipped = false
	DataService.MarkDirty(player, "Pets")
end

local function onDelete(player: Player, uid: any)
	local data, pet = findPet(player, uid)
	if not data or not pet then
		return
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(pet) -- refine for the type checker (guarded above)
	data.Pets[uid :: string] = nil
	DataService.MarkDirty(player, "Pets")
end

-- v2.2 duplicate fusion: GOLDEN_FUSE_COUNT identical non-golden copies -> one Golden pet.
local function onFuse(player: Player, uid: any)
	local data, pet = findPet(player, uid)
	if not data or not pet then
		return
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(pet) -- refine for the type checker (guarded above)
	local maybeDef = Config.GetPet(pet.Id)
	if not maybeDef or pet.Golden == true then
		Net.Notify(player, "Error", "Golden pets can't be fused again.")
		return
	end
	local def = maybeDef :: Types.PetDef
	-- the selected pet first, then unequipped copies, then equipped ones (stable by uid)
	local copies: { string } = {}
	for otherUid, other in data.Pets do
		if otherUid ~= uid and other.Id == pet.Id and other.Golden ~= true then
			table.insert(copies, otherUid)
		end
	end
	if #copies + 1 < Config.GOLDEN_FUSE_COUNT then
		Net.Notify(
			player,
			"Error",
			string.format("You need %d %s to fuse a Golden one!", Config.GOLDEN_FUSE_COUNT, def.Name)
		)
		return
	end
	table.sort(copies, function(a: string, b: string): boolean
		local ea, eb = data.Pets[a].Equipped, data.Pets[b].Equipped
		if ea ~= eb then
			return not ea
		end
		return a < b
	end)
	local fused: { string } = { uid :: string }
	for i = 1, Config.GOLDEN_FUSE_COUNT - 1 do
		table.insert(fused, copies[i])
	end
	local wasEquipped = false
	for _, fusedUid in fused do
		wasEquipped = wasEquipped or data.Pets[fusedUid].Equipped
		data.Pets[fusedUid] = nil
	end
	local newUid = HttpService:GenerateGUID(false)
	data.Pets[newUid] = { Id = def.Id, Equipped = wasEquipped, Golden = true }
	DataService.MarkDirty(player, "Pets")
	Net.Notify(player, "Success", string.format("Fused %d %s into a GOLDEN %s!", #fused, def.Name, def.Name))
end

-- If slots shrank (e.g. pass refunded), unequip extras so the stored state matches the stats.
local function trimEquipped(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	assert(data) -- refine for the type checker (guarded above)
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
	Net.On("FusePets", onFuse, { Rate = 4, Window = 1 })
end

-- Mirror equipped pet ids onto a Player attribute so every client can render followers
-- (PetFollowController reads "EquippedPets" as comma-separated PetDef ids).
local function publishEquipped(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	assert(data) -- refine for the type checker (guarded above)
	local ids = {}
	local golden = {}
	for i, pet in Stats.SortEquipped(data.Pets) do
		table.insert(ids, pet.Id)
		if pet.Golden == true then
			table.insert(golden, tostring(i))
		end
	end
	player:SetAttribute("EquippedPets", table.concat(ids, ","))
	player:SetAttribute("EquippedGolden", table.concat(golden, ","))
end

function PetService.Start()
	DataService.PlayerLoaded:Connect(function(player: Player)
		publishEquipped(player)
	end)
	DataService.Changed:Connect(function(player: Player, keys: { string })
		if table.find(keys, "Pets") then
			publishEquipped(player)
		end
	end)
	for _, player in DataService.GetLoadedPlayers() do
		publishEquipped(player)
	end
	-- Pass ownership arrives asynchronously after load; trim only once it settled.
	MonetizationService.PassesChanged:Connect(function(player: Player)
		trimEquipped(player)
	end)
end

return PetService
