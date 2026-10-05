--!strict
--[[
	EconomyService — selling sand (and unsold treasures) for Coins.

	Sources of a sell:
	  - touching any part tagged "SellZone" (CollectionService; debounced per player, distance
	    checked against the part so spoofed touches from far away are ignored),
	  - SetSetting("SellNow", true) — the Sell Anywhere pass.
	Coins = floor((Sand * SELL_RATE + sum(treasure SellValue * count)) * coin multiplier)
	(coin multiplier = CoinBoost x Golden Hour, see Stats.GetCoinMultiplier).
	Client feedback: Notify("Sell", "+1.2K Coins!") + DataChanged.

	Public API:
		EconomyService.Sell(player, source): number   (coins earned; source "Zone" | "Anywhere")
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local Stats = require(Shared.Util.Stats)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local MultiplierService = require(script.Parent.MultiplierService)
local Net = require(script.Parent.Net)
local ServerSignals = require(script.Parent.ServerSignals)
local SettingsService = require(script.Parent.SettingsService)

local ZONE_DEBOUNCE = 1
local SELL_ANYWHERE_COOLDOWN = 1
local ZONE_DISTANCE_SLACK = 12

local EconomyService = {}

local lastZoneSell: { [Player]: number } = {}
local lastAnywhereSell: { [Player]: number } = {}
local connectedZones: { [BasePart]: boolean } = {}

function EconomyService.Sell(player: Player, source: string): number
	local data = DataService.Get(player)
	local ctx = MultiplierService.GetContext(player)
	if not data or not ctx then
		return 0
	end
	local hasTreasure = false
	for _, count in data.Treasures do
		if count > 0 then
			hasTreasure = true
			break
		end
	end
	if data.Sand <= 0 and not hasTreasure then
		return 0
	end

	local coins = Stats.GetSellValue(ctx)
	local sand = data.Sand
	DataService.Mutate(player, { "Coins", "Sand", "Treasures" }, function(d)
		d.Coins += coins
		d.Sand = 0
		d.Treasures = {}
	end)

	Net.Notify(player, "Sell", "+" .. Format.Abbreviate(coins) .. " Coins!")
	Analytics.Source(
		player,
		"Coins",
		coins,
		data.Coins,
		Enum.AnalyticsEconomyTransactionType.Gameplay,
		"Sell:" .. source
	)
	Analytics.Funnel(player, Analytics.Steps.FirstSell)
	ServerSignals.Sold:Fire(player, coins, sand)
	return coins
end

local function onZoneTouched(zone: BasePart, hit: BasePart)
	local player = Net.GetPlayerFromPart(hit)
	if not player then
		return
	end
	local now = os.clock()
	local last = lastZoneSell[player]
	if last and now - last < ZONE_DEBOUNCE then
		return
	end
	local root = Net.GetRoot(player)
	if not root then
		return
	end
	-- Reject touches reported far from the zone (exploit: firetouchinterest from anywhere).
	local maxDistance = zone.Size.Magnitude / 2 + ZONE_DISTANCE_SLACK
	if (root.Position - zone.Position).Magnitude > maxDistance then
		return
	end
	lastZoneSell[player] = now
	EconomyService.Sell(player, "Zone")
end

local function connectZone(instance: Instance)
	if not instance:IsA("BasePart") or connectedZones[instance] then
		return
	end
	local zone = instance :: BasePart
	connectedZones[zone] = true
	zone.Touched:Connect(function(hit: BasePart)
		onZoneTouched(zone, hit)
	end)
	zone.Destroying:Connect(function()
		connectedZones[zone] = nil
	end)
end

local function onSellNow(player: Player, _value: any)
	if not MonetizationService.OwnsPass(player, "SellAnywhere") then
		Net.NotifyThrottled(player, "Error", "Get Sell Anywhere to sell from here!", "SellAnywhere", 2)
		return
	end
	local now = os.clock()
	local last = lastAnywhereSell[player]
	if last and now - last < SELL_ANYWHERE_COOLDOWN then
		return
	end
	lastAnywhereSell[player] = now
	if EconomyService.Sell(player, "Anywhere") == 0 then
		Net.NotifyThrottled(player, "Info", "Nothing to sell yet - go dig!", "NothingToSell", 2)
	end
end

function EconomyService.Init()
	SettingsService.RegisterAction("SellNow", onSellNow)
end

function EconomyService.Start()
	for _, instance in CollectionService:GetTagged("SellZone") do
		connectZone(instance)
	end
	CollectionService:GetInstanceAddedSignal("SellZone"):Connect(connectZone)
end

function EconomyService.OnPlayerRemoving(player: Player)
	lastZoneSell[player] = nil
	lastAnywhereSell[player] = nil
end

return EconomyService
