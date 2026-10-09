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
check(TrophyService.OwnsStand(player) == true, "stand granted with the trophy")

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

-- Adventure completion bridge, booted by Main ----------------------------------------------
local Settlement = Mock.Require(byPath["ServerScriptService/Server/Services/AdventureSettlement"])
local CREW = 9202
local crew = Mock.AddPlayer(CREW, "Crew")
Mock.Advance(2)
local coins0 = DataService.Get(crew).Coins
local function participants(stageId)
	return {
		BoundaryVersion = 1,
		EventInstanceId = "wired-guid:2",
		EventId = "event_vault",
		LandmarkId = TROPHY,
		RegionId = "sunshine_shore",
		StageId = stageId,
		CompletedStages = { "excavation" },
		Participants = { { UserId = CREW, Points = 10, ObjectiveIds = {}, Connected = true, Left = false } },
	}
end
local since = #Mock.Remote.ToClient
Settlement.OnStage(participants("excavation"))
local accepted = Settlement.OnCompletion({
	BoundaryVersion = 1,
	EventInstanceId = "wired-guid:2",
	EventId = "event_vault",
	LandmarkId = TROPHY,
	RegionId = "sunshine_shore",
	Success = true,
	ObjectiveIds = { "vault_anchor_1" },
	CompletedStages = { "excavation", "vault_open", "ball_return" },
	Participants = {
		{ UserId = CREW, Points = 30, Eligible = true, ActiveSeconds = 90, ObjectiveIds = { "vault_anchor_1" } },
	},
})
Mock.Advance(2)
check(accepted == true, "bridge accepted the completion through Main's boot")
check(DataService.Get(crew).Coins == coins0 + 60, "+60 coins")
check(TrophyService.Owns(crew, TROPHY) == true and TrophyService.OwnsStand(crew) == true, "trophy + stand")
check(Settlement.HasCertification(crew, "cert_crew") == true, "cert_crew")
local notified, outcomes = 0, {}
for i = since + 1, #Mock.Remote.ToClient do
	local e = Mock.Remote.ToClient[i]
	if e.Player == crew and e.Name == "Notify" and e.Args[1] == "Reward" then
		notified += 1
	elseif e.Player == crew and e.Name == "AdventureOutcome" then
		table.insert(outcomes, e.Args[1])
	end
end
if table.find(Remotes.Events, "AdventureOutcome") then
	-- docs/integration/settlement-outcomes.patch applied: one outcome per stage/final, no text
	check(#outcomes == 2, "stage and final outcomes reach the client (" .. #outcomes .. ")")
	check(notified == 0, "no duplicate reward text while outcomes are wired (" .. notified .. ")")
	local stageOutcome, final = outcomes[1], outcomes[2]
	check(
		stageOutcome
			and stageOutcome.Kind == "Stage"
			and stageOutcome.StageId == "excavation"
			and stageOutcome.State == "Accepted"
			and stageOutcome.Coins == 6,
		"stage outcome accepted"
	)
	check(
		final
			and final.Kind == "Final"
			and final.State == "Accepted"
			and final.Status == "Saved"
			and final.Coins == 54
			and final.Trophy == true
			and final.Stand == true
			and final.Certification == "cert_crew"
			and final.InstanceId == "wired-guid:2",
		"final outcome: +54, trophy, stand, cert"
	)
	check(#Mock.Remote.Problems == 0, "outcome payloads are remote-safe")
else
	check(notified == 2, "stage and final reward notifications reach the client (" .. notified .. ")")
end
local crewSaved = Mock.DataStores[Config.DATASTORE_NAME]["Player_" .. CREW].Data
check(crewSaved.Certifications.cert_crew ~= nil and crewSaved.TrophyRecords[TROPHY] ~= nil, "saved immediately")

-- Camp display action, wired by Main (docs/integration/camp-display-action.patch) -----------
TrophyService.SetCampPads(nil) -- back to the authored pad Main's World built
local CampAction = Mock.Require(byPath["ReplicatedStorage/Shared/Trophies/CampAction"])
local map = Mock.Service("Workspace"):FindFirstChild("Map")
local hub = map and map:FindFirstChild("Hub")
local padModel = hub and hub:FindFirstChild("TrophyCampPad1")
local deck = padModel and padModel:FindFirstChild("Deck")
local show = deck and deck:FindFirstChild(CampAction.DISPLAY_PROMPT)
local put = deck and deck:FindFirstChild(CampAction.REMOVE_PROMPT)
check(show ~= nil and put ~= nil, "Main hangs both camp prompts on the authored deck")
check(crew:GetAttribute(CampAction.STATUS_ATTR) == "Ready", "crew status Ready after the bridge grant")
if show and put then
	local before = #Mock.Remote.ToClient
	Mock.FireEvent(show, "Triggered", crew)
	Mock.Advance(0.5)
	check(TrophyService.GetCampPadOwner(1) == CREW, "display prompt puts the crew's trophy on the pad")
	check(crew:GetAttribute(CampAction.STATUS_ATTR) == "Displayed", "status Displayed")
	local told = false
	for i = before + 1, #Mock.Remote.ToClient do
		local e = Mock.Remote.ToClient[i]
		if e.Player == crew and e.Name == "Notify" and e.Args[2] == "Trophy on display!" then
			told = true
		end
	end
	check(told, "result toast reaches the client through Net")
	Mock.FireEvent(put, "Triggered", crew)
	Mock.Advance(0.5)
	check(TrophyService.GetCampPadOwner(1) == nil, "put-away prompt frees the pad")
	check(TrophyService.Owns(crew, TROPHY) == true, "put away keeps the trophy")
end

-- Camp lifecycle and ownership through the real wiring (docs/integration/camp-lifecycle.md) --
local function promptCount(part)
	local n = 0
	for _, c in part:GetChildren() do
		if c:IsA("ProximityPrompt") then
			n += 1
		end
	end
	return n
end
if show and put then
	-- the crew's camp goes up through the Main-wired prompt
	Mock.Advance(1.5)
	Mock.FireEvent(show, "Triggered", crew)
	Mock.Advance(0.5)
	check(TrophyService.GetCampPadOwner(1) == CREW, "crew displayed again")
	local crewLayout = TrophyService.GetCampLayout(crew)
	local crewId = crewLayout.Placements[1].Id

	-- another player forges camp remotes: nothing of the crew's changes, nothing bad is saved
	local forged = {
		{ TROPHY, 0 / 0, 0, 0 },
		{ TROPHY, math.huge, 0, 0 },
		{ TROPHY, -math.huge, 0, 0 },
		{ TROPHY, 2 ^ 40, 0, 0 },
		{ TROPHY, -1, 0, 0 },
		{ TROPHY, 1.5, 0, 0 },
		{ TROPHY, "5", "5", "90" },
		{ TROPHY, { 5 }, 5, 90 },
		{ TROPHY, 5, 5, 45 },
		{ TROPHY, 5, 5, 0 / 0 },
		{ "", 5, 5, 90 },
		{ string.rep("x", 65), 5, 5, 90 },
		{ "unknown_trophy", 5, 5, 90 },
		{ 42, 5, 5, 90 },
		{ nil, 5, 5, 90 },
	}
	for _, args in forged do
		Mock.FireServer("PlaceCampItem", again, args[1], args[2], args[3], args[4])
		Mock.Advance(0.3) -- stay under the remote rate limit
	end
	for _, id in { crewId, 0 / 0, math.huge, -1, 0, 1.5, "1", { 1 }, 2 ^ 53 } do
		Mock.FireServer("RemoveCampItem", again, id)
		Mock.Advance(0.3)
	end
	check(#TrophyService.GetCampLayout(again).Placements == 0, "forged place requests saved nothing")
	local same = TrophyService.GetCampLayout(crew)
	check(
		#same.Placements == 1 and same.Placements[1].Id == crewId and same.NextId == crewLayout.NextId,
		"another player's forged ids never reach the crew's layout"
	)
	check(TrophyService.GetCampPadOwner(1) == CREW, "pad still the crew's")
	-- another player's valid place only saves their own layout and queues them
	Mock.FireServer("PlaceCampItem", again, TROPHY, 3, 3, 0)
	Mock.Advance(0.5)
	check(#TrophyService.GetCampLayout(again).Placements == 1, "their own valid placement is saved")
	check(TrophyService.GetCampPadOwner(1) == CREW, "and does not take the pad")
	check(again:GetAttribute(CampAction.STATUS_ATTR) == "Queued", "they are queued")
	-- remote spam is rate limited (4 per second per remote)
	Mock.Advance(2)
	local changes = 0
	local conn = TrophyService.CampChanged:Connect(function(pl)
		if pl == again then
			changes += 1
		end
	end)
	local againId = TrophyService.GetCampLayout(again).Placements[1].Id
	for i = 1, 20 do
		Mock.FireServer("RemoveCampItem", again, againId + i - 1)
		Mock.FireServer("PlaceCampItem", again, TROPHY, 3, 3, 0)
	end
	Mock.Advance(0.1)
	conn:Disconnect()
	check(changes <= 8, "remote spam limited (" .. changes .. " camp changes from 40 requests)")

	-- the authored pad is destroyed and rebuilt by the world: prompts reattach once, the camp
	-- follows the new deck
	local CampPad = Mock.Require(byPath["ServerScriptService/Server/World/CampPad"])
	padModel:Destroy()
	Mock.Advance(0.2)
	check(TrophyService.GetCampPadCount() == 0, "pad gone")
	local folder = Mock.Service("Workspace"):FindFirstChild("TrophyCamps")
	check(folder == nil or #folder:GetChildren() == 0, "no camp model left floating")
	check(crew:GetAttribute(CampAction.STATUS_ATTR) == "NoPad", "crew told there is no pad")
	local newDeck = CampPad.Build(hub)[1]
	Mock.Advance(0.2)
	check(promptCount(newDeck) == 2, "rebuilt deck: exactly two prompts from Main's wiring")
	check(TrophyService.GetCampPadOwner(1) == CREW, "the crew's camp is back first")
	check(newDeck:GetAttribute("OwnerUserId") == CREW, "rebuilt deck shows the owner")
	check(again:GetAttribute(CampAction.STATUS_ATTR) == "Queued", "the other player still waits")
	show = newDeck:FindFirstChild(CampAction.DISPLAY_PROMPT)
	put = newDeck:FindFirstChild(CampAction.REMOVE_PROMPT)

	-- kill switch through the live wiring
	TrophyService.SetEnabled(false)
	folder = Mock.Service("Workspace"):FindFirstChild("TrophyCamps")
	check(folder == nil or #folder:GetChildren() == 0, "off: camps taken down")
	check(show.Enabled == false and put.Enabled == false, "off: prompts disabled")
	Mock.Advance(1.5)
	Mock.FireEvent(show, "Triggered", again)
	Mock.Advance(0.2)
	check(TrophyService.GetCampPadOwner(1) == nil, "off: a prompt trigger claims nothing")
	TrophyService.SetEnabled(true)
	check(TrophyService.GetCampPadOwner(1) == CREW, "on: crew's camp restored")
	check(again:GetAttribute(CampAction.STATUS_ATTR) == "Queued", "on: other player queued again")
end

-- Digging can never reach under a camp pad, Broadwave included (World.IsProtected is XZ-only)
do
	local World = Mock.Require(byPath["ServerScriptService/Server/World"])
	local WorldLayout = Mock.Require(byPath["ServerScriptService/Server/World/Layout"])
	local Dig = Mock.Require(byPath["ServerScriptService/Server/Services/DigService"])
	local V = Mock.Vector3
	local zone = World.GetDigZone()
	local point = V.new(300, Config.SURFACE_Y, zone.CFrame.Position.Z)
	local digger = Mock.AddPlayer(9203, "Digger")
	Mock.Advance(2)
	Mock.SpawnCharacter(digger, point + V.new(0, 3, 4))
	Mock.Advance(1)
	check(World.IsProtected(V.new(80 + 12, -5000, 76 - 12)), "authored pad footprint protected at any depth")
	table.insert(WorldLayout.CAMP_PADS, V.new(point.X, Config.SURFACE_Y, point.Z + 14)) -- test-only pad
	local function stand()
		DataService.Get(digger).Sand = 0
		digger.Character:PivotTo(Mock.CFrame.new(point + V.new(0, 3, 4)))
	end
	stand()
	local blocked = Dig.DigBroadwave(digger, point)
	check(blocked ~= nil and blocked.Reason == "OutOfZone", "Broadwave dig reaching a pad footprint refused")
	stand()
	local plain = Dig.DigAt(digger, point, Dig.ShovelOptions(digger, "Shovel"))
	check(plain ~= nil and plain.Reason == "OutOfZone", "ordinary shovel dig there refused too")
	table.remove(WorldLayout.CAMP_PADS)
	Mock.Advance(2)
	stand()
	local free = Dig.DigBroadwave(digger, point)
	check(free ~= nil and free.Success == true, "same Broadwave dig succeeds without the pad")
end

-- Shutdown: BindToClose saves the camp layout with everything else
if show then
	Mock.RunBindToClose()
	Mock.Advance(5)
	local saved = Mock.DataStores[Config.DATASTORE_NAME]["Player_" .. CREW].Data
	check(
		saved and #saved.CampLayout.Placements == 1 and saved.TrophyRecords[TROPHY] ~= nil,
		"shutdown saves the layout"
	)
end

check(#Mock.Errors == 0, "no uncaught errors")
for _, e in Mock.Errors do
	print("  error: " .. tostring(e))
end
print(string.format("TROPHY WIRED: %d passed, %d failed", passes, failures))
if failures > 0 then
	error("TROPHY WIRED SPEC FAILED")
end
