--!strict
--[[
	ServerSignals — server-internal gameplay events. Producers (Dig/Economy/Pet/Shop/Rebirth/Plot
	services) fire; consumers (quests, analytics, leaderboards) subscribe. Keeps services
	decoupled and the require graph acyclic.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local ServerSignals = {
	-- player, dig depth (studs), sand gained
	Dug = Signal.new() :: Signal.Signal<Player, number, number>,
	-- player, coins earned, sand sold
	Sold = Signal.new() :: Signal.Signal<Player, number, number>,
	-- player, treasureId
	TreasureFound = Signal.new() :: Signal.Signal<Player, string>,
	-- player, number of eggs hatched, eggId
	Hatched = Signal.new() :: Signal.Signal<Player, number, string>,
	-- player, "Shovel" | "Backpack", item id
	UpgradeBought = Signal.new() :: Signal.Signal<Player, string, string>,
	-- player, new MaxDepth (studs)
	DepthReached = Signal.new() :: Signal.Signal<Player, number>,
	-- player, total rebirths after this one
	Rebirthed = Signal.new() :: Signal.Signal<Player, number>,
	-- player
	BackpackFull = Signal.new() :: Signal.Signal<Player>,
}

return ServerSignals
