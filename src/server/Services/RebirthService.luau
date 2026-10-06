--!strict
--[[
	RebirthService — reset for a permanent multiplier (Config.Rebirths) + the Rebirth Perk shop
	(Config.RebirthPerks, docs/design/Rebirth.md).

	Rebirth(): costs Config.RebirthCost(Rebirths) coins. Resets every key in
	Config.Rebirths.Resets to its Config.NewPlayerData() default, Rebirths += 1,
	RebirthTokens += Config.RebirthTokens(previous rebirths). Then the perks apply:
	  - Head Start: start with Shovels[ShovelIndex] (owned + equipped) and +Coins,
	  - Keep Backpack: the backpack you had stays (owned + equipped) up to Backpacks[KeepIndex].
	The player is sent to the surface and the shovel tool is given back. (No plot to reset any
	more: the tide refills holes.)

	Perk shop: remote BuyRebirthPerk(perkId) buys the next level for RebirthTokens. Perks are
	permanent (PlayerData.RebirthPerks, never reset). On load and on purchase the Head Start
	shovel is made owned (and equipped if it beats the current one), so a perk bought mid-run is
	felt right away. Capacity / coins / luck / pet slots come from Stats; Sell Anywhere from
	EconomyService; Long Nap from OfflineService.

	Public API:
		RebirthService.DoRebirth(player, free): boolean   (free = Skip Rebirth product)
		RebirthService.BuyPerk(player, perkId): boolean
		RebirthService.HasSellAnywhere(player): boolean  (the Sell Anywhere perk)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local TableUtil = require(Shared.Util.TableUtil)
local Types = require(Shared.Types)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local BeachService = require(script.Parent.BeachService)
local ServerSignals = require(script.Parent.ServerSignals)
local ShopService = require(script.Parent.ShopService)

local Perks = Config.RebirthPerks

local RebirthService = {}

local busy: { [Player]: boolean } = {}

-- Drop unknown perk ids and clamp levels (old / edited saves).
local function sanitizePerks(data: Types.PlayerData)
	local raw = (data :: any).RebirthPerks
	local clean: { [string]: number } = {}
	if type(raw) == "table" then
		for id, level in raw do
			if type(id) == "string" and Perks.Get(id) then
				local l = Perks.Level(raw, id)
				if l > 0 then
					clean[id] = l
				end
			end
		end
	end
	data.RebirthPerks = clean
end

-- Head Start shovel: owned, and equipped when it is better than the equipped one.
-- Returns true when the equipped shovel changed.
local function applyHeadStartShovel(player: Player, data: Types.PlayerData): boolean
	local index = Perks.Effect(data.RebirthPerks, "HeadStart").ShovelIndex
	local def = if index then Config.Shovels[index] else nil
	if not def or def.RebirthsRequired > data.Rebirths then
		return false
	end
	assert(def) -- refine for the type checker (guarded above)
	local current = Config.GetShovel(data.Shovel)
	local equip = current == nil or (current :: Types.ShovelDef).Power < def.Power
	if data.OwnedShovels[def.Id] and not equip then
		return false
	end
	DataService.Mutate(player, { "OwnedShovels", "Shovel" }, function(d)
		d.OwnedShovels[def.Id] = true
		if equip then
			d.Shovel = def.Id
		end
	end)
	return equip
end

function RebirthService.HasSellAnywhere(player: Player): boolean
	local data = DataService.Get(player)
	return data ~= nil and Perks.HasSellAnywhere((data :: Types.PlayerData).RebirthPerks)
end

function RebirthService.DoRebirth(player: Player, free: boolean): boolean
	local data = DataService.Get(player)
	if not data or busy[player] then
		return false
	end
	assert(data) -- refine for the type checker (guarded above)
	local previous = data.Rebirths
	local cost = Config.RebirthCost(previous)
	if not free and data.Coins < cost then
		Net.Notify(player, "Error", "You need " .. Format.Abbreviate(cost) .. " coins to rebirth!")
		return false
	end
	busy[player] = true

	local tokens = Config.RebirthTokens(previous)
	local template = Config.NewPlayerData() :: any
	local oldBackpack = data.Backpack
	DataService.Mutate(player, { "Rebirths", "RebirthTokens" }, function(d)
		local raw = d :: any
		for _, key in Config.Rebirths.Resets do
			raw[key] = TableUtil.DeepCopy(template[key])
		end
		d.Rebirths = previous + 1
		d.RebirthTokens += tokens

		-- Perks (v2.2): Head Start coins, Keep Backpack. (The shovel is applied below.)
		local head = Perks.Effect(d.RebirthPerks, "HeadStart")
		d.Coins += head.Coins or 0
		local keepIndex = Perks.Effect(d.RebirthPerks, "KeepBackpack").KeepIndex or 0
		local oldIndex = Config.GetBackpackIndex(oldBackpack)
		if oldIndex and oldIndex > 1 and oldIndex <= keepIndex then
			d.Backpack = oldBackpack
			d.OwnedBackpacks[oldBackpack] = true
		end
	end)
	DataService.MarkDirty(player, table.unpack(Config.Rebirths.Resets))
	applyHeadStartShovel(player, data)

	if not free then
		Analytics.Sink(player, "Coins", cost, 0, Enum.AnalyticsEconomyTransactionType.Gameplay, "Rebirth")
	end
	Analytics.Source(
		player,
		"Tokens",
		tokens,
		data.RebirthTokens,
		Enum.AnalyticsEconomyTransactionType.Gameplay,
		"Rebirth"
	)
	Analytics.Funnel(player, Analytics.Steps.FirstRebirth)

	BeachService.TeleportToSurface(player)
	ShopService.GiveShovelTool(player)
	Net.Notify(
		player,
		"Reward",
		string.format(
			"REBIRTH %d! x%s sand forever, +%d Rebirth Token%s!",
			data.Rebirths,
			tostring(Config.RebirthMultiplier(data.Rebirths)),
			tokens,
			if tokens == 1 then "" else "s"
		)
	)
	ServerSignals.Rebirthed:Fire(player, data.Rebirths)
	busy[player] = nil
	return true
end

function RebirthService.BuyPerk(player: Player, perkId: string): boolean
	local data = DataService.Get(player)
	local def = Perks.Get(perkId)
	if not data or not def then
		return false
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(def) -- refine for the type checker (guarded above)
	local cost = Perks.NextCost(data.RebirthPerks, perkId)
	if not cost then
		Net.Notify(player, "Info", def.Name .. " is already maxed!")
		return false
	end
	assert(cost) -- refine for the type checker (guarded above)
	if data.RebirthTokens < cost then
		Net.Notify(
			player,
			"Error",
			string.format("You need %d Rebirth Token%s for %s!", cost, if cost == 1 then "" else "s", def.Name)
		)
		return false
	end
	local level = Perks.Level(data.RebirthPerks, perkId) + 1
	DataService.Mutate(player, { "RebirthTokens", "RebirthPerks" }, function(d)
		d.RebirthTokens -= cost
		local perks = table.clone(d.RebirthPerks)
		perks[perkId] = level
		d.RebirthPerks = perks
	end)
	Analytics.Sink(
		player,
		"Tokens",
		cost,
		data.RebirthTokens,
		Enum.AnalyticsEconomyTransactionType.Shop,
		"Perk:" .. perkId .. ":" .. level
	)
	if perkId == "HeadStart" and applyHeadStartShovel(player, data) then
		ShopService.GiveShovelTool(player)
	end
	Net.Notify(
		player,
		"Success",
		if #def.Costs == 1 then def.Name .. " unlocked!" else string.format("%s level %d!", def.Name, level)
	)
	return true
end

function RebirthService.Init()
	Net.On("Rebirth", function(player: Player)
		RebirthService.DoRebirth(player, false)
	end, { Rate = 1, Window = 2 })
	Net.On("BuyRebirthPerk", function(player: Player, perkId: any)
		if not Net.IsString(perkId, 40) then
			return
		end
		RebirthService.BuyPerk(player, perkId)
	end, { Rate = 4, Window = 2 })
end

function RebirthService.Start()
	-- Apply perks on load: clean the table, make sure the Head Start shovel is owned.
	DataService.PlayerLoaded:Connect(function(player: Player, data: Types.PlayerData)
		sanitizePerks(data)
		if applyHeadStartShovel(player, data) then
			ShopService.GiveShovelTool(player)
		end
	end)
end

function RebirthService.OnPlayerRemoving(player: Player)
	busy[player] = nil
end

return RebirthService
