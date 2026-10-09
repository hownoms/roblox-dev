--!nocheck
--[[
	Post-integration trophy check: boots the real Main.server.luau with the wiring from
	docs/TROPHY_INTEGRATION.md applied (TrophyService in Main's service list, "PlaceCampItem" /
	"RemoveCampItem" in Remotes.Events) and drives the camp remotes like a client would.

	NOT registered in tests/run.sh until that patch is merged: before the patch the camp
	remotes do not exist and this spec stops with "integration patch not applied".
	MOCK COVERAGE ONLY (in-memory DataStore through the real DataService).
]]

local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")
Mock.Init(Generated)

local failures, passes = 0, 0
local function check(cond, message)
	if cond then
		passes += 1
	else
		failures += 1
		print("FAIL: " .. message)
	end
end

local byPath = Mock.ByPath
local Config = Mock.Require(byPath["ReplicatedStorage/Shared/Config"])
local Remotes = Mock.Require(byPath["ReplicatedStorage/Shared/Remotes"])
assert(
	table.find(Remotes.Events, "PlaceCampItem") and table.find(Remotes.Events, "RemoveCampItem"),
	"integration patch not applied (see docs/TROPHY_INTEGRATION.md)"
)
for _, pass in Config.Monetization.GamePasses do
	pass.Id = 0
end
for _, product in Config.Monetization.Products do
	product.Id = 0
end
for _, badge in Config.Badges do
	badge.Id = 0
end

local TROPHY = "landmark_spring_vault"
local USER = 9201
-- existing live-schema save, no trophy fields
local legacy = Config.NewPlayerData()
legacy.Coins = 4242
legacy.Version = 3
Mock.DataStores[Config.DATASTORE_NAME] = { ["Player_" .. USER] = { Data = legacy, SavedAt = 1 } }

Mock.RunScript(byPath["ServerScriptService/Server/Main"])
Mock.Advance(1)
check(#Mock.Errors == 0, "Main boots with TrophyService wired")

local DataService = Mock.Require(byPath["ServerScriptService/Server/Services/DataService"])
local TrophyService = Mock.Require(byPath["ServerScriptService/Server/Services/TrophyService"])
TrophyService.SetCampPads({ Mock.CFrame.new(0, Config.SURFACE_Y, 400) })

local player = Mock.AddPlayer(USER, "Wired")
Mock.Advance(2)
check(DataService.IsLoaded(player), "loaded through Main")
check(DataService.Get(player).Coins == 4242, "legacy save loaded")
check(TrophyService.Owns(player, TROPHY) == false, "legacy save owns no trophy")

Mock.FireServer("PlaceCampItem", player, TROPHY, 0, 0, 0)
Mock.Advance(0.5)
check(TrophyService.Owns(player, TROPHY) == false, "client place request cannot grant")
check(#TrophyService.GetCampLayout(player).Placements == 0, "nothing placed without ownership")

local report = TrophyService.SettleAdventureCompletion({
	EventId = "event_vault",
	LandmarkId = TROPHY,
	InstanceId = "wired:1",
	Outcome = "Completed",
	Participants = {
		{ UserId = USER, Points = 10, ActiveSeconds = 60, ObjectiveCompletions = 1, PresentForObjective = true },
	},
})
check(report.Ok and report.ByUserId[USER].Status == "Granted", "settled through the server API")

Mock.FireServer("PlaceCampItem", player, TROPHY, 5, 6, 180)
Mock.Advance(0.5)
local layout = TrophyService.GetCampLayout(player)
check(#layout.Placements == 1 and layout.Placements[1].X == 5, "placed through the remote")
local camps = Mock.Service("Workspace"):FindFirstChild("TrophyCamps")
check(camps and camps:FindFirstChild("Camp_" .. USER) ~= nil, "camp display built")

-- Rebirth (existing system) must keep trophies and the camp
DataService.Set(player, "Coins", Config.RebirthCost(0))
Mock.Advance(0.5)
Mock.FireServer("Rebirth", player)
Mock.Advance(1)
check(DataService.Get(player).Rebirths == 1, "rebirth ran")
check(TrophyService.Owns(player, TROPHY) == true, "rebirth keeps the trophy")
check(#TrophyService.GetCampLayout(player).Placements == 1, "rebirth keeps the camp layout")

Mock.FireServer("RemoveCampItem", player, layout.Placements[1].Id)
Mock.Advance(0.5)
check(#TrophyService.GetCampLayout(player).Placements == 0, "removed through the remote")
check(TrophyService.Owns(player, TROPHY) == true, "removal keeps ownership")

Mock.RemovePlayer(player)
Mock.Advance(2)
local saved = Mock.DataStores[Config.DATASTORE_NAME]["Player_" .. USER].Data
check(saved.TrophyRecords[TROPHY] ~= nil and saved.Coins == 0 and saved.Rebirths == 1, "saved on leave via Main")
local again = Mock.AddPlayer(USER, "Wired")
Mock.Advance(2)
check(TrophyService.Owns(again, TROPHY) == true, "owned after rejoin")

check(#Mock.Errors == 0, "no uncaught errors")
for _, e in Mock.Errors do
	print("  error: " .. tostring(e))
end
print(string.format("TROPHY WIRED: %d passed, %d failed", passes, failures))
if failures > 0 then
	error("TROPHY WIRED SPEC FAILED")
end
