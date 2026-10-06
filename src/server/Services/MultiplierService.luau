--!strict
--[[
	MultiplierService — builds the authoritative Stats.Context for a player and publishes the
	results as Player attributes so the UI never has to re-derive them:
		"SandMultiplier"   number  total sand multiplier (Stats.GetSandMultiplier)
		"Capacity"         number  effective backpack capacity
		"Luck"             number  luck multiplier
		"CoinMultiplier"   number  sell multiplier (Coin boosts / Golden Hour)
		"SpeedMultiplier"  number  dig speed multiplier (cooldown divided by this)
		"PetSlots"         number  equip slots incl. ExtraPets pass
	(Player attributes "InGroup" / "FriendsInServer" are set by RewardsService, "Premium" and
	"Pass_<Key>" by MonetizationService.)

	Public API:
		MultiplierService.GetContext(player): Stats.Context?
		MultiplierService.Refresh(player)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Stats = require(Shared.Util.Stats)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local EventService = require(script.Parent.EventService)
local MonetizationService = require(script.Parent.MonetizationService)

local MultiplierService = {}

function MultiplierService.GetContext(player: Player): Stats.Context?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local loaded = data :: Types.PlayerData
	local friends = player:GetAttribute("FriendsInServer")
	return {
		Data = loaded,
		Passes = MonetizationService.GetOwnedPasses(player),
		IsPremium = MonetizationService.IsPremium(player),
		InGroup = player:GetAttribute("InGroup") == true,
		FriendsInServer = if type(friends) == "number" then friends else 0,
		ActiveEvents = EventService.GetActiveIds(),
		Now = os.time(),
	}
end

local function setIfChanged(player: Player, name: string, value: number)
	-- Round for display stability (avoids attribute churn from float noise).
	local rounded = math.floor(value * 1000 + 0.5) / 1000
	if player:GetAttribute(name) ~= rounded then
		player:SetAttribute(name, rounded)
	end
end

function MultiplierService.Refresh(player: Player)
	local maybeCtx = MultiplierService.GetContext(player)
	if not maybeCtx or player.Parent == nil then
		return
	end
	local ctx = maybeCtx :: Stats.Context
	setIfChanged(player, "SandMultiplier", Stats.GetSandMultiplier(ctx))
	setIfChanged(player, "Capacity", Stats.GetCapacity(ctx))
	setIfChanged(player, "Luck", Stats.GetLuck(ctx))
	setIfChanged(player, "CoinMultiplier", Stats.GetCoinMultiplier(ctx))
	setIfChanged(player, "SpeedMultiplier", Stats.GetSpeedMultiplier(ctx))
	setIfChanged(player, "PetSlots", Stats.GetPetSlots(ctx))
end

local RELEVANT_KEYS = {
	Shovel = true,
	Backpack = true,
	Pets = true,
	PetSlots = true,
	Rebirths = true,
	Boosts = true,
	Index = true,
	RebirthPerks = true, -- v2.2 perks change capacity, coins and pet slots
}

function MultiplierService.Init() end

function MultiplierService.Start()
	DataService.PlayerLoaded:Connect(function(player: Player)
		MultiplierService.Refresh(player)
	end)
	DataService.Changed:Connect(function(player: Player, keys: { string })
		for _, key in keys do
			if RELEVANT_KEYS[key] then
				MultiplierService.Refresh(player)
				return
			end
		end
	end)
	MonetizationService.PassesChanged:Connect(function(player: Player)
		MultiplierService.Refresh(player)
	end)
	EventService.Changed:Connect(function()
		for _, player in DataService.GetLoadedPlayers() do
			MultiplierService.Refresh(player)
		end
	end)
	-- Boost expiry and social attribute changes: cheap periodic refresh.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in DataService.GetLoadedPlayers() do
				MultiplierService.Refresh(player)
			end
		end
	end)
end

return MultiplierService
