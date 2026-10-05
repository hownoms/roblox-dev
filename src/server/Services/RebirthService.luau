--!strict
--[[
	RebirthService — reset for a permanent multiplier (Config.Rebirths).

	Rebirth(): costs Config.RebirthCost(Rebirths) coins. Resets every key in
	Config.Rebirths.Resets to its Config.NewPlayerData() default, Rebirths += 1,
	RebirthTokens += Config.RebirthTokens(previous rebirths). The player is sent to the surface,
	the plot is refilled and the starter shovel tool is given back.

	Public API:
		RebirthService.DoRebirth(player, free): boolean   (free = Skip Rebirth product)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local TableUtil = require(Shared.Util.TableUtil)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local ServerSignals = require(script.Parent.ServerSignals)
local ShopService = require(script.Parent.ShopService)

local RebirthService = {}

local busy: { [Player]: boolean } = {}

function RebirthService.DoRebirth(player: Player, free: boolean): boolean
	local data = DataService.Get(player)
	if not data or busy[player] then
		return false
	end
	local previous = data.Rebirths
	local cost = Config.RebirthCost(previous)
	if not free and data.Coins < cost then
		Net.Notify(player, "Error", "You need " .. Format.Abbreviate(cost) .. " coins to rebirth!")
		return false
	end
	busy[player] = true

	local tokens = Config.RebirthTokens(previous)
	local template = Config.NewPlayerData() :: any
	DataService.Mutate(player, { "Rebirths", "RebirthTokens" }, function(d)
		local raw = d :: any
		for _, key in Config.Rebirths.Resets do
			raw[key] = TableUtil.DeepCopy(template[key])
		end
		d.Rebirths = previous + 1
		d.RebirthTokens += tokens
	end)
	DataService.MarkDirty(player, table.unpack(Config.Rebirths.Resets))

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

	PlotService.ResetPlayerPlot(player)
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

function RebirthService.Init()
	Net.On("Rebirth", function(player: Player)
		RebirthService.DoRebirth(player, false)
	end, { Rate = 1, Window = 2 })
end

function RebirthService.Start() end

function RebirthService.OnPlayerRemoving(player: Player)
	busy[player] = nil
end

return RebirthService
