--!nocheck
--[[
	Headless end-to-end smoke test of the SERVER (Main.server.luau + Services + World + Shared)
	against tests/mock/Roblox.luau. Run with tests/run.sh (it generates build/test/generated.luau).

	Scripted session: boot -> join -> spawn at plot with shovel tool -> dig x20 -> sell at the
	SellZone -> buy + equip a shovel -> hatch an egg -> quests/daily/code -> purchase prompts with
	id 0 -> die deep in the hole + respawn -> ReturnToSurface -> rebirth -> leave (save, plot
	reset, sign cleared) -> rejoin (data persisted). Fails on any uncaught error, unexpected
	warning, unsendable remote payload or non-JSON DataStore value.
]]

local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")

local ARGS = { ... }
Mock.Verbose = table.find(ARGS, "verbose") ~= nil -- luau tests/smoke.spec.luau -a verbose
-- "studio": Studio without API access (DataStores throw) -> in-memory fallback paths.
local STUDIO_NO_API = table.find(ARGS, "studio") ~= nil
Mock.Init(Generated)
if STUDIO_NO_API then
	Mock.IsStudio = true
	Mock.DataStoreFail = true
	print("(mode: Studio without DataStore access)")
end

local Vector3 = Mock.Vector3
local CFrame = Mock.CFrame
local Enum = Mock.Enum

local failures = 0
local passes = 0
local function check(cond, message)
	if cond then
		passes += 1
	else
		failures += 1
		print("FAIL: " .. message)
	end
	return cond
end
local function section(name)
	print("== " .. name)
end
local function step(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		failures += 1
		print("FAIL (error) in " .. name .. ": " .. tostring(err))
	end
end

local function lastToClient(player, name)
	for i = #Mock.Remote.ToClient, 1, -1 do
		local e = Mock.Remote.ToClient[i]
		if e.Player == player and e.Name == name then
			return e.Args, i
		end
	end
	return nil
end
local function countToClient(player, name, since)
	local n = 0
	for i = (since or 0) + 1, #Mock.Remote.ToClient do
		local e = Mock.Remote.ToClient[i]
		if e.Player == player and e.Name == name then
			n += 1
		end
	end
	return n
end
local function notifies(player, since)
	local list = {}
	for i = (since or 0) + 1, #Mock.Remote.ToClient do
		local e = Mock.Remote.ToClient[i]
		if e.Player == player and e.Name == "Notify" then
			table.insert(list, tostring(e.Args[1]) .. ": " .. tostring(e.Args[2]))
		end
	end
	return list
end

-- Boot --------------------------------------------------------------------------------------------
section("boot")
local byPath = Mock.ByPath
local main = byPath["ServerScriptService/Server/Main"]
assert(main, "Main script missing")
Mock.RunScript(main)
Mock.Advance(1)
check(#Mock.Errors == 0, "no errors during boot")

local Shared = byPath["ReplicatedStorage/Shared"]
local Config = Mock.Require(byPath["ReplicatedStorage/Shared/Config"])
local DataService = Mock.Require(byPath["ServerScriptService/Server/Services/DataService"])
local PlotService = Mock.Require(byPath["ServerScriptService/Server/Services/PlotService"])
local World = Mock.Require(byPath["ServerScriptService/Server/World"])
local _ = Shared

local workspace = Mock.Service("Workspace")
-- deep terrain fills in the background
for _ = 1, 40 do
	if workspace:GetAttribute("WorldReady") then
		break
	end
	Mock.Advance(0.5)
end
check(workspace:GetAttribute("WorldReady") == true, "WorldReady attribute set")

for _, t in
	{
		"SellZone",
		"ShovelShop",
		"BackpackShop",
		"EggShop",
		"RebirthStatue",
		"LeaderboardCoins",
		"LeaderboardDepth",
		"SpawnLocation",
	}
do
	check(#Mock.Tagged(t) > 0, "map places tag " .. t)
end
for _, egg in Mock.Tagged("EggShop") do
	check(type(egg:GetAttribute("EggId")) == "string", "EggShop part has EggId attribute")
	check(egg:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil, "EggShop part has a ProximityPrompt")
end
for _, t in { "ShovelShop", "BackpackShop", "RebirthStatue" } do
	local part = Mock.Tagged(t)[1]
	check(part and part:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil, t .. " has a ProximityPrompt")
end

local plots = World.GetPlots()
check(#plots == Config.PLOT_COUNT, "World.GetPlots returns 12 plots")

-- Terrain inside every plot: layered from the surface to the bottom.
section("terrain")
for _, plot in plots do
	local c = plot.Origin.Position
	local topY, topMat = Mock.TerrainSurfaceBelow(c.X + 1, c.Z + 1, Config.SURFACE_Y + 8)
	check(
		topY ~= nil and math.abs(topY - Config.SURFACE_Y) < 0.01,
		"plot " .. plot.Id .. " surface at SURFACE_Y (got " .. tostring(topY) .. ")"
	)
	check(topMat == Config.Layers[1].Material, "plot " .. plot.Id .. " top material is layer 1")
	for i, layer in Config.Layers do
		local depth = (layer.DepthStart + layer.DepthEnd) / 2
		local v = Mock.GetVoxel(Vector3.new(c.X + 1, Config.SURFACE_Y - depth, c.Z + 1))
		if
			not check(
				v ~= nil and v.Material == layer.Material,
				string.format("plot %d layer %d (%s) material at depth %d", plot.Id, i, layer.Id, depth)
			)
		then
			break
		end
	end
end
for _, layer in Config.Layers do
	check(Mock.MaterialColors[layer.Material.Name] ~= nil, "material colour set for " .. layer.Material.Name)
end

-- Join --------------------------------------------------------------------------------------------
section("join")
local player = Mock.AddPlayer(1001, "Tester")
Mock.Advance(0.5)
Mock.SpawnCharacter(player, Vector3.new(0, Config.SURFACE_Y + 3, 4)) -- hub SpawnLocation
Mock.Advance(2)
check(DataService.IsLoaded(player), "data loaded")
local data = DataService.Get(player)
local snapshot
for _, e in Mock.Remote.ToClient do
	if e.Player == player and e.Name == "DataChanged" then
		snapshot = e.Args
		break
	end
end
check(
	snapshot ~= nil and type(snapshot[1]) == "table" and snapshot[1].Version ~= nil and snapshot[1].Coins ~= nil,
	"first DataChanged is the full snapshot"
)
local plotArgs = lastToClient(player, "PlotAssigned")
check(plotArgs ~= nil and type(plotArgs[1]) == "table", "client got PlotAssigned")
local plot = PlotService.GetPlot(player)
check(plot ~= nil, "plot assigned")
check(player:GetAttribute("PlotId") == plot.Id, "Player attribute PlotId")
local root = player.Character.HumanoidRootPart
check(
	(root.Position - (plot.SpawnCFrame.Position + Vector3.new(0, 3, 0))).Magnitude < 0.1,
	"character moved to plot spawn"
)
check(Mock.InvokeServer("GetPlot", player) ~= nil, "GetPlot remote function returns the plot")
local passes0 = Mock.InvokeServer("GetOwnedPasses", player)
check(type(passes0) == "table", "GetOwnedPasses returns a table")
local got = Mock.InvokeServer("GetData", player)
check(type(got) == "table" and got.Coins ~= nil, "GetData returns PlayerData")
local leaderstats = player:FindFirstChild("leaderstats")
check(leaderstats ~= nil, "leaderstats created")

-- Shovel tool
local function equippedTool()
	return player.Character:FindFirstChildOfClass("Tool")
end
local tool = equippedTool()
check(tool ~= nil, "shovel tool auto-equipped on spawn")
if tool then
	check(tool:GetAttribute("ShovelId") == data.Shovel, "tool ShovelId matches data")
	local handle = tool:FindFirstChild("Handle")
	check(handle ~= nil and handle:IsA("BasePart"), "tool has a Handle part")
	check(tool.Grip ~= CFrame.identity, "Tool.Grip set from Handle GripOffset")
	local problems = Mock.ToolProblems[tool] or {}
	check(#problems == 0, "tool assembly OK: " .. table.concat(problems, "; "))
end

-- Dig ---------------------------------------------------------------------------------------------
section("dig")
local function standAt(pos)
	player.Character:PivotTo(CFrame.new(pos))
end
local c = plot.Origin.Position
standAt(Vector3.new(c.X, Config.SURFACE_Y + 3, c.Z))
local results = {}
local cooldown = Config.Shovels[1].Cooldown + 0.02
local since = #Mock.Remote.ToClient
for i = 1, 24 do
	-- client: raycast from the camera onto the terrain near the feet, inside the plot
	local x = c.X + ((i % 5) - 2) * 3
	local z = c.Z + ((i // 5) - 2) * 3
	local y = Mock.TerrainSurfaceBelow(x, z, Config.SURFACE_Y + 8)
	local hit = Vector3.new(x, y, z)
	Mock.FireServer("Dig", player, hit)
	Mock.Advance(cooldown)
	local args = lastToClient(player, "DigResult")
	results[i] = args and args[1]
end
local first = results[1]
check(
	first ~= nil and first.Success == true,
	"first dig at the surface succeeds (" .. tostring(first and first.Reason) .. ")"
)
local successes, reasons = 0, {}
for _, r in results do
	if r.Success then
		successes += 1
	else
		reasons[r.Reason] = (reasons[r.Reason] or 0) + 1
	end
end
print(string.format(
	"   digs: %d ok, fails: %s",
	successes,
	(function()
		local s = {}
		for k, v in reasons do
			table.insert(s, k .. "=" .. v)
		end
		return table.concat(s, ",")
	end)()
))
local capacity = player:GetAttribute("Capacity")
check(capacity == Config.Backpacks[1].Capacity, "Capacity attribute = bucket capacity (" .. tostring(capacity) .. ")")
check(data.Sand == capacity, "backpack filled to capacity after 24 digs (sand " .. tostring(data.Sand) .. ")")
check(reasons.BackpackFull ~= nil, "BackpackFull reported once full")
check(data.TotalSandDug > 0, "TotalSandDug increased")
local carved = Mock.GetVoxel(Vector3.new(c.X, Config.SURFACE_Y - 2, c.Z))
check(carved == nil or carved.Occupancy < 1, "terrain was carved at the dig point")
check(countToClient(player, "DataChanged", since) > 0, "DataChanged deltas sent while digging")
-- out of plot / too far
local other = plots[2].Origin.Position
Mock.FireServer("Dig", player, Vector3.new(other.X, Config.SURFACE_Y, other.Z))
Mock.Advance(0.3)
check(lastToClient(player, "DigResult")[1].Reason == "OutOfPlot", "dig in another plot -> OutOfPlot")

-- Sell --------------------------------------------------------------------------------------------
section("sell")
local zone = Mock.Tagged("SellZone")[1]
standAt(zone.Position + Vector3.new(0, 3, 0))
local coinsBefore = data.Coins
Mock.FireTouched(zone, player.Character.HumanoidRootPart)
Mock.Advance(0.5)
check(data.Sand == 0, "sand emptied at SellZone")
check(data.Coins > coinsBefore, "coins earned at SellZone")
-- touch from far away (exploit) does nothing
data.Sand = 5
standAt(Vector3.new(c.X, Config.SURFACE_Y + 3, c.Z))
Mock.FireTouched(zone, player.Character.HumanoidRootPart)
Mock.Advance(1.5)
check(data.Sand == 5, "far-away SellZone touch rejected")
data.Sand = 0
-- SellNow without the pass
local n0 = #Mock.Remote.ToClient
Mock.FireServer("SetSetting", player, "SellNow", true)
Mock.Advance(0.2)
check(#notifies(player, n0) > 0, "SellNow without pass notifies")

-- Shop --------------------------------------------------------------------------------------------
section("shop")
DataService.Set(player, "Coins", 1_000_000)
Mock.Advance(0.1)
local second = Config.Shovels[2]
Mock.FireServer("BuyShovel", player, second.Id)
Mock.Advance(0.5)
check(data.Shovel == second.Id and data.OwnedShovels[second.Id] == true, "bought + equipped shovel 2")
tool = equippedTool()
check(tool ~= nil and tool:GetAttribute("ShovelId") == second.Id, "new shovel tool equipped")
check(#player.Backpack:GetChildren() + #(function()
	local l = {}
	for _, ch in player.Character:GetChildren() do
		if ch:IsA("Tool") then
			table.insert(l, ch)
		end
	end
	return l
end)() == 1, "exactly one shovel tool")
Mock.FireServer("EquipShovel", player, Config.Shovels[1].Id)
Mock.Advance(0.3)
check(data.Shovel == Config.Shovels[1].Id, "re-equip owned shovel 1")
Mock.FireServer("EquipShovel", player, Config.Shovels[3].Id)
Mock.Advance(0.3)
check(data.Shovel == Config.Shovels[1].Id, "cannot equip unowned shovel")
Mock.FireServer("BuyBackpack", player, Config.Backpacks[2].Id)
Mock.Advance(1.2)
check(data.Backpack == Config.Backpacks[2].Id, "bought backpack 2")
check(player:GetAttribute("Capacity") == Config.Backpacks[2].Capacity, "Capacity attribute follows backpack")
Mock.FireServer("BuyShovel", player, "nope")
Mock.FireServer("BuyShovel", player, 123)
Mock.Advance(1.2)

-- Eggs / pets --------------------------------------------------------------------------------------
section("eggs")
local egg = Config.Eggs[1]
local s0 = #Mock.Remote.ToClient
Mock.FireServer("HatchEgg", player, egg.Id, 1)
Mock.Advance(0.5)
local hatched = lastToClient(player, "EggHatched")
check(hatched ~= nil and type(hatched[1]) == "table" and #hatched[1] == 1, "EggHatched({petId}) sent")
local petCount = 0
local uid
for id, pet in data.Pets do
	petCount += 1
	uid = id
	check(pet.Equipped == true, "first pet auto-equipped")
end
check(petCount == 1, "one pet granted")
Mock.Advance(0.2)
local attr = player:GetAttribute("EquippedPets")
check(type(attr) == "string" and attr ~= "", "EquippedPets attribute published (" .. tostring(attr) .. ")")
Mock.FireServer("HatchEgg", player, egg.Id, 3)
Mock.Advance(0.5)
check(countToClient(player, "EggHatched", s0) == 1, "triple hatch refused without pass")
Mock.FireServer("UnequipPet", player, uid)
Mock.Advance(0.2)
check(data.Pets[uid].Equipped == false, "unequip pet")
Mock.Advance(0.1)
check(player:GetAttribute("EquippedPets") == "", "EquippedPets cleared")
Mock.FireServer("EquipPet", player, uid)
Mock.Advance(0.2)
check(data.Pets[uid].Equipped == true, "equip pet")
for _, e in Config.Eggs do
	if e.Currency == "Robux" then
		local p0 = #Mock.Prompts
		Mock.FireServer("HatchEgg", player, e.Id, 1)
		Mock.Advance(0.5)
		check(#Mock.Prompts == p0, "Robux egg with product id 0 never prompts")
		break
	end
end

-- Rewards -----------------------------------------------------------------------------------------
section("rewards")
local coins0 = data.Coins
Mock.FireServer("ClaimDailyReward", player)
Mock.Advance(0.5)
check(data.DailyStreak == 1 and data.LastDailyClaim > 0, "daily reward claimed")
Mock.FireServer("ClaimDailyReward", player)
Mock.Advance(2.5)
check(data.DailyStreak == 1, "daily reward not claimable twice")
Mock.FireServer("RedeemCode", player, "release")
Mock.Advance(0.5)
check(data.RedeemedCodes.RELEASE == true and data.Coins > coins0, "code RELEASE redeemed")
Mock.FireServer("RedeemCode", player, "RELEASE")
Mock.Advance(5.5)
Mock.FireServer("RedeemCode", player, "DIGDEEP")
Mock.Advance(0.5)
check(data.RedeemedCodes.DIGDEEP == nil, "group-only code refused outside the group")
-- finish a daily quest through the normal signal path (100 dig events)
local ServerSignals = Mock.Require(byPath["ServerScriptService/Server/Services/ServerSignals"])
for _ = 1, 100 do
	ServerSignals.Dug:Fire(player, 1, 1)
end
Mock.Advance(0.5)
local quest
for qid, q in data.Quests do
	local def = Config.GetQuest(qid)
	if def and q.Progress >= def.Target and not q.Claimed then
		quest = qid
	end
end
check(next(data.Quests) ~= nil, "quest progress tracked")
if quest then
	Mock.FireServer("ClaimQuest", player, quest)
	Mock.Advance(0.5)
	check(data.Quests[quest].Claimed == true, "quest " .. quest .. " claimed")
	local coinsBeforeQuest = data.Coins
	Mock.FireServer("ClaimQuest", player, quest)
	Mock.Advance(1.5)
	check(data.Coins == coinsBeforeQuest, "quest reward not granted twice")
else
	check(false, "a quest should be complete after 100 digs")
end

-- Monetization: ids are 0 -> never prompt
section("monetization")
local p0 = #Mock.Prompts
for key in Config.Monetization.GamePasses do
	Mock.FireServer("PromptPurchase", player, "GamePass", key)
	Mock.Advance(0.7)
end
for key in Config.Monetization.Products do
	Mock.FireServer("PromptPurchase", player, "Product", key)
	Mock.Advance(0.7)
end
check(#Mock.Prompts == p0, "no MarketplaceService prompt for id 0")
Mock.FireServer("SetSetting", player, "AutoDig", true)
Mock.FireServer("SetSetting", player, "Music", false)
Mock.FireServer("SetSetting", player, "FTUE_Joined", false)
Mock.Advance(0.3)
check(data.Settings.AutoDig ~= true, "AutoDig refused without pass")
check(data.Settings.Music == false, "generic setting stored")
check(data.Settings.FTUE_Joined == true, "reserved FTUE_ setting not writable by client")

-- Configured ids (owner pasted real ids): receipts + pass purchases
section("purchases")
local marketplace = Mock.Service("MarketplaceService")
Config.Monetization.Products.CoinsSmall.Id = 9001
local coinsBeforeReceipt = data.Coins
local receipt = { PlayerId = 1001, ProductId = 9001, PurchaseId = "purchase-1", CurrencySpent = 25 }
local decision
Mock.Env.task.spawn(function()
	decision = marketplace.ProcessReceipt(receipt)
end)
Mock.Advance(1)
check(decision == Enum.ProductPurchaseDecision.PurchaseGranted, "ProcessReceipt grants a configured product")
local granted = data.Coins - coinsBeforeReceipt
check(granted > 0, "product coins granted")
Mock.Env.task.spawn(function()
	decision = marketplace.ProcessReceipt(receipt)
end)
Mock.Advance(1)
check(
	decision == Enum.ProductPurchaseDecision.PurchaseGranted and data.Coins == coinsBeforeReceipt + granted,
	"receipt is idempotent"
)
Mock.Env.task.spawn(function()
	decision = marketplace.ProcessReceipt({ PlayerId = 1001, ProductId = 4242, PurchaseId = "purchase-2" })
end)
Mock.Advance(1)
check(decision == Enum.ProductPurchaseDecision.NotProcessedYet, "unknown product id not granted")
Config.Monetization.GamePasses.AutoDig.Id = 7001
Config.Monetization.GamePasses.SellAnywhere.Id = 7002
Config.Monetization.GamePasses.Lucky.Id = 7003
local p1 = #Mock.Prompts
Mock.FireServer("PromptPurchase", player, "GamePass", "Lucky")
Mock.Advance(1)
check(#Mock.Prompts == p1 + 1 and Mock.Prompts[#Mock.Prompts].Id == 7003, "configured pass prompts")
Mock.FireEvent(marketplace, "PromptGamePassPurchaseFinished", player, 7001, true)
Mock.FireEvent(marketplace, "PromptGamePassPurchaseFinished", player, 7002, true)
Mock.Advance(0.5)
check(player:GetAttribute("Pass_AutoDig") == true, "Pass_AutoDig attribute after purchase")
local ownedNow = Mock.InvokeServer("GetOwnedPasses", player)
check(ownedNow.AutoDig == true and ownedNow.SellAnywhere == true, "GetOwnedPasses reflects purchase")
standAt(Vector3.new(c.X + 6, Config.SURFACE_Y + 3, c.Z + 6))
data.Sand = 0
Mock.FireServer("SetSetting", player, "AutoDig", true)
Mock.Advance(3)
check(data.Settings.AutoDig == true, "AutoDig setting on with pass")
check(data.Sand > 0, "server auto dig digs below the character (sand " .. tostring(data.Sand) .. ")")
Mock.FireServer("SetSetting", player, "AutoDig", false)
Mock.Advance(0.5)
local coinsBeforeSell = data.Coins
Mock.FireServer("SetSetting", player, "SellNow", true)
Mock.Advance(0.5)
check(data.Sand == 0 and data.Coins > coinsBeforeSell, "SellNow sells with the Sell Anywhere pass")

-- Events attribute
check(type(workspace:GetAttribute("ActiveEvents")) == "string", "ActiveEvents attribute is a string")

-- Deep hole: fall, die, respawn ---------------------------------------------------------------------
section("hole")
standAt(Vector3.new(c.X, Config.SURFACE_Y - 60, c.Z))
Mock.Advance(1)
check(player:GetAttribute("Depth") ~= nil, "Depth attribute published")
Mock.FireServer("ReturnToSurface", player)
Mock.Advance(0.2)
root = player.Character.HumanoidRootPart
check(root.Position.Y > Config.SURFACE_Y, "ReturnToSurface teleports to the surface")
standAt(Vector3.new(c.X, Config.SURFACE_Y - 60, c.Z))
player.Character.Humanoid.Health = 0
Mock.SpawnCharacter(player, Vector3.new(0, Config.SURFACE_Y + 3, 4))
Mock.Advance(1)
root = player.Character.HumanoidRootPart
check((root.Position - (plot.SpawnCFrame.Position + Vector3.new(0, 3, 0))).Magnitude < 0.1, "respawn at own plot")
check(equippedTool() ~= nil, "shovel tool given again after respawn")

-- Rebirth -----------------------------------------------------------------------------------------
section("rebirth")
DataService.Set(player, "Coins", Config.RebirthCost(0))
Mock.Advance(0.1)
Mock.FireServer("Rebirth", player)
Mock.Advance(2)
check(data.Rebirths == 1, "rebirth done")
check(data.Coins == 0 and data.Shovel == Config.Shovels[1].Id, "rebirth resets coins + shovel")
check(data.RebirthTokens >= 1, "rebirth tokens granted")
check(petCount == 1 and next(data.Pets) ~= nil, "pets kept after rebirth")
check(
	equippedTool() and equippedTool():GetAttribute("ShovelId") == Config.Shovels[1].Id,
	"starter shovel tool after rebirth"
)
local refill = Mock.GetVoxel(Vector3.new(c.X, Config.SURFACE_Y - 2, c.Z))
check(refill ~= nil and refill.Occupancy == 1, "plot refilled after rebirth")

-- Leave + rejoin ------------------------------------------------------------------------------------
section("leave")
DataService.Set(player, "Coins", 4242)
Mock.Advance(0.1)
-- dig a bit so the reset has something to refill
standAt(Vector3.new(c.X, Config.SURFACE_Y + 3, c.Z))
Mock.FireServer("Dig", player, Vector3.new(c.X, Config.SURFACE_Y, c.Z))
Mock.Advance(1)
local plotId = plot.Id
Mock.RemovePlayer(player)
Mock.Advance(3)
if not STUDIO_NO_API then
	local saved = Mock.DataStores[Config.DATASTORE_NAME] and Mock.DataStores[Config.DATASTORE_NAME]["Player_1001"]
	check(saved ~= nil and saved.Data ~= nil and saved.Data.Coins == 4242, "data saved on leave")
	check(saved ~= nil and saved.Lock == nil, "session lock released on leave")
end
check(workspace:GetAttribute("PlotOwner_" .. plotId) == 0, "plot freed")
local sign
for _, d in workspace:GetDescendants() do
	if d.Name == "PlotSign" and d:GetAttribute("PlotId") == plotId then
		sign = d
	end
end
check(sign ~= nil and sign:GetAttribute("OwnerName") == "", "plot sign cleared")
local afterReset = Mock.GetVoxel(Vector3.new(c.X, Config.SURFACE_Y - 2, c.Z))
check(afterReset ~= nil and afterReset.Occupancy == 1, "plot terrain refilled after leave")
check(not DataService.IsLoaded(player), "session cleared")

section("rejoin")
local player2 = Mock.AddPlayer(1001, "Tester")
Mock.Advance(0.5)
Mock.SpawnCharacter(player2)
Mock.Advance(2)
local data2 = DataService.Get(player2)
check(data2 ~= nil and data2.Coins == 4242 and data2.Rebirths == 1, "data persisted across sessions")
check(PlotService.GetPlot(player2) ~= nil, "plot assigned on rejoin")

section("full server")
local crowd = {}
for i = 1, 12 do
	local p = Mock.AddPlayer(2000 + i, "Crowd" .. i)
	Mock.SpawnCharacter(p)
	crowd[i] = p
end
Mock.Advance(3)
local seen = { [PlotService.GetPlot(player2).Id] = true }
local assigned = 1
for i = 1, 11 do
	local pl = PlotService.GetPlot(crowd[i])
	if check(pl ~= nil, "crowd player " .. i .. " got a plot") then
		check(not seen[pl.Id], "plots are unique")
		seen[pl.Id] = true
		assigned += 1
	end
end
check(PlotService.GetPlot(crowd[12]) == nil, "13th player waits in the queue")
Mock.RemovePlayer(crowd[1])
Mock.Advance(3)
check(PlotService.GetPlot(crowd[12]) ~= nil, "queued player gets the freed plot")
for i = 2, 12 do
	Mock.RemovePlayer(crowd[i])
end
Mock.Advance(5)

section("shutdown")
Mock.RunBindToClose()
Mock.Advance(3)
if not STUDIO_NO_API then
	local saved2 = Mock.DataStores[Config.DATASTORE_NAME]["Player_1001"]
	check(saved2.Lock == nil, "BindToClose saves + releases lock")
end

-- Long idle run: autosave, leaderboards, events, quests timers
Mock.Advance(1)

-- Report ------------------------------------------------------------------------------------------
section("report")
check(#Mock.Errors == 0, #Mock.Errors .. " uncaught errors (see above)")
check(#Mock.Remote.Problems == 0, "remote payloads serializable: " .. table.concat(Mock.Remote.Problems, " | "))
local unexpected = {}
local EXPECTED_WARNINGS = {
	"receipt for unknown product id 4242", -- provoked above
	"Studio has no DataStore access", -- studio mode only
}
for _, w in Mock.Warnings do
	local ok = false
	for _, pattern in EXPECTED_WARNINGS do
		if string.find(w, pattern, 1, true) then
			ok = true
		end
	end
	if not ok then
		table.insert(unexpected, w)
	end
end
for _, w in unexpected do
	print("   warning: " .. w)
end
check(#unexpected == 0, #unexpected .. " unexpected warnings")
check(#Mock.Kicked == 0, "nobody was kicked")

print(string.format("\nSMOKE: %d passed, %d failed", passes, failures))
if failures > 0 then
	error("SMOKE TEST FAILED", 0)
end
print("SMOKE TEST PASSED")
