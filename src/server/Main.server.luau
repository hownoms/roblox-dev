--!strict
--[[
	Server entry point — Dig to the Core! Beach Simulator.

	Boot order:
	  1. Remotes.CreateAll()  (every remote exists before clients look for them)
	  2. World.Build()        (map, plots, tagged parts)
	  3. Service Init() in dependency order (connect remotes, read config), then Start() (loops)
	  4. Player lifecycle: OnPlayerAdded in service order, OnPlayerRemoving in reverse order (so
	     DataService saves last, after every other service is done with the player's data).
	  5. Players who joined before this script finished (Studio Play Solo) are handled too.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
Remotes.CreateAll()

local World = require(script.Parent.World)
local okWorld, worldErr = pcall(function(): any
	World.Build()
	return nil
end)
if not okWorld then
	warn("[Main] World.Build failed: " .. tostring(worldErr))
end

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local MonetizationService = require(Services.MonetizationService)
local EventService = require(Services.EventService)
local MultiplierService = require(Services.MultiplierService)
local SettingsService = require(Services.SettingsService)
local PlotService = require(Services.PlotService)
local ShopService = require(Services.ShopService)
local PetService = require(Services.PetService)
local EconomyService = require(Services.EconomyService)
local DigService = require(Services.DigService)
local RebirthService = require(Services.RebirthService)
local RewardsService = require(Services.RewardsService)
local LeaderboardService = require(Services.LeaderboardService)
local BadgeAwardService = require(Services.BadgeAwardService)
local DevCommands = require(Services.DevCommands)
local Net = require(Services.Net)

type Service = {
	Init: (() -> ())?,
	Start: (() -> ())?,
	OnPlayerAdded: ((Player) -> ())?,
	OnPlayerRemoving: ((Player) -> ())?,
}

-- Dependency order (each service only requires services listed before it).
local ordered: { { Name: string, Module: Service } } = {
	{ Name = "DataService", Module = DataService :: any },
	{ Name = "MonetizationService", Module = MonetizationService :: any },
	{ Name = "EventService", Module = EventService :: any },
	{ Name = "MultiplierService", Module = MultiplierService :: any },
	{ Name = "SettingsService", Module = SettingsService :: any },
	{ Name = "PlotService", Module = PlotService :: any },
	{ Name = "ShopService", Module = ShopService :: any },
	{ Name = "PetService", Module = PetService :: any },
	{ Name = "EconomyService", Module = EconomyService :: any },
	{ Name = "DigService", Module = DigService :: any },
	{ Name = "RebirthService", Module = RebirthService :: any },
	{ Name = "RewardsService", Module = RewardsService :: any },
	{ Name = "LeaderboardService", Module = LeaderboardService :: any },
	{ Name = "BadgeAwardService", Module = BadgeAwardService :: any },
	{ Name = "DevCommands", Module = DevCommands :: any },
}

local function run(name: string, phase: string, fn: (...any) -> ...any, ...: any)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn(string.format("[Main] %s.%s failed: %s", name, phase, tostring(err)))
	end
end

for _, entry in ordered do
	local init = entry.Module.Init
	if init then
		run(entry.Name, "Init", init)
	end
end

-- Developer products are granted through RewardsService (coins, boosts, eggs, skip rebirth).
MonetizationService.SetGrantHandler(function(player: Player, reward, source: string): boolean
	return RewardsService.Grant(player, reward, source)
end)

for _, entry in ordered do
	local start = entry.Module.Start
	if start then
		run(entry.Name, "Start", start)
	end
end

local handled: { [Player]: boolean } = {}

local function onPlayerAdded(player: Player)
	if handled[player] then
		return
	end
	handled[player] = true
	for _, entry in ordered do
		local fn = entry.Module.OnPlayerAdded
		if fn then
			run(entry.Name, "OnPlayerAdded", fn, player)
		end
	end
end

local function onPlayerRemoving(player: Player)
	for i = #ordered, 1, -1 do
		local entry = ordered[i]
		local fn = entry.Module.OnPlayerRemoving
		if fn then
			run(entry.Name, "OnPlayerRemoving", fn, player)
		end
	end
	Net.OnPlayerRemoving(player)
	handled[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
