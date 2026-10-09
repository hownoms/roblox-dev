--!nocheck
-- Integration across the real pure adventure context and Claude's real trophy service in
-- the API-aware mock. No production boot patch or real DataStore is used by this fixture.
local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")
local State = require("../src/server/Adventure/SpringVaultState")
local AdventureConfig = require("../src/shared/Adventure/SpringVaultConfig")
Mock.Init(Generated)
local Data = Mock.Require(Mock.ByPath["ServerScriptService/Server/Services/DataService"])
local Trophy = Mock.Require(Mock.ByPath["ServerScriptService/Server/Services/TrophyService"])
local Config = Mock.Require(Mock.ByPath["ReplicatedStorage/Shared/Config"])
local passed = 0
local function check(value, message)
	assert(value, message)
	passed += 1
end
Data.Init()
Trophy.Init()
local players = {}
for id = 9401, 9404 do
	local save = Config.NewPlayerData()
	save.Coins = 4242
	save.Sand = 7
	save.Rebirths = 3
	Mock.DataStores[Config.DATASTORE_NAME] = Mock.DataStores[Config.DATASTORE_NAME] or {}
	Mock.DataStores[Config.DATASTORE_NAME]["Player_" .. id] = { Data = save, SavedAt = 1 }
	local p = Mock.AddPlayer(id, "Contract" .. id)
	Data.OnPlayerAdded(p)
	Trophy.OnPlayerAdded(p)
	Mock.Advance(0.5)
	players[id] = p
	check(Data.IsLoaded(p), "legacy save loaded")
end
local s = State.new(AdventureConfig, "joint-boundary:1", 9401, 0)
assert(s:start(9401, 5))
assert(s:ready(9401, 5))
s:tick(5)
local now = 6
for _, anchor in AdventureConfig.AnchorIds do
	for _ = 1, 6 do
		assert(s:hitAnchor(9401, anchor, now))
		now += 0.5
	end
end
assert(s:openVault(9401, now))
for id = 9402, 9404 do
	assert(s:join(id, now))
	assert(s:ready(id, now))
end
for _, id in { 9401, 9402, 9404 } do
	assert(s:latch(id, true, now))
end
assert(s:advanceBallGate(AdventureConfig.GateIds[1], now, { [9401] = 1, [9402] = 1, [9404] = 2 }))
assert(s:leave(9404, now + 0.1, true))
assert(s:advanceBallGate(AdventureConfig.GateIds[2], now + 1, { [9401] = 1, [9402] = 1 }))
assert(s:advanceBallGate(AdventureConfig.GateIds[3], now + 2, { [9402] = 1 }))
local context = s:completionContext(now + 2)
check(context.Participants[2].Eligible, "meaningful late helper qualifies")
check(not context.Participants[3].Eligible, "spectator does not qualify")
check(not context.Participants[4].Eligible, "disconnected contributor vetoed")
local function settle()
	local report
	Mock.Env.task.spawn(function()
		report = Trophy.SettleCompletionContext(context)
	end)
	Mock.Advance(1)
	assert(report, "settlement completed")
	return report
end
local report = settle()
check(report.Ok, "real service accepts real context")
check(report.ByUserId[9401].Status == "Granted", "solo starter trophy granted")
check(report.ByUserId[9402].Status == "Granted", "late helper trophy granted")
check(report.ByUserId[9403].Status == "Ineligible", "spectator rejected")
check(report.ByUserId[9404].Status == "Ineligible", "disconnected contributor rejected")
for _, id in { 9401, 9402 } do
	check(Trophy.OwnsStand(players[id]), "stand accompanies first trophy")
	local data = Data.Get(players[id])
	check(data.Coins == 4242 and data.Sand == 7 and data.Rebirths == 3, "legacy possessions/economy unchanged")
	check(data.TrophyRecords.landmark_spring_vault.Source == "event_vault", "stable source retained")
	check(data.RewardReceipts[data.TrophyRecords.landmark_spring_vault.ReceiptId] ~= nil, "trophy receipt accepted")
end
local repeated = settle()
check(
	repeated.ByUserId[9401].Status == "Duplicate" and repeated.ByUserId[9402].Status == "Duplicate",
	"duplicate context grants once"
)
check(Trophy.Owns(players[9403], "landmark_spring_vault") == false, "spectator owns nothing")
check(Trophy.Owns(players[9404], "landmark_spring_vault") == false, "disconnected owns nothing")
check(#Mock.Errors == 0, "no uncaught integration errors")
print("ADVENTURE TROPHY CONTRACT: " .. passed .. " checks passed")
