--!nocheck
--[[
	Headless end-to-end smoke test of the SERVER (Main.server.luau + Services + World + Shared)
	against tests/mock/Roblox.luau. Run with tests/run.sh (it generates build/test/generated.luau).

	Scripted session: boot -> join -> spawn on the boardwalk with shovel tool -> dig x24 on the
	shared beach -> sell at the
	SellZone -> buy + equip a shovel -> hatch an egg -> quests/daily/code -> purchase prompts with
	id 0 -> die deep in the hole + respawn -> ReturnToSurface -> rebirth -> leave (save) -> rejoin
	(data persisted) -> 16 players -> beach (DigAt, tide refill, High Tide, Sunburnt, depth). Fails on any uncaught error, unexpected
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
local BeachService = Mock.Require(byPath["ServerScriptService/Server/Services/BeachService"])
local DigService = Mock.Require(byPath["ServerScriptService/Server/Services/DigService"])
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
		"WaterFountain",
		"Garage",
		"BeachShop",
	}
do
	check(#Mock.Tagged(t) > 0, "map places tag " .. t)
end
for t, action in { WaterFountain = "Drink", Garage = "Garage", BeachShop = "Shop" } do
	local part = Mock.Tagged(t)[1]
	local prompt = part and part:FindFirstChildWhichIsA("ProximityPrompt", true)
	check(prompt ~= nil and prompt.ActionText == action, t .. " has a '" .. action .. "' ProximityPrompt")
end
for _, egg in Mock.Tagged("EggShop") do
	check(type(egg:GetAttribute("EggId")) == "string", "EggShop part has EggId attribute")
	check(egg:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil, "EggShop part has a ProximityPrompt")
end
for _, t in { "ShovelShop", "BackpackShop", "RebirthStatue" } do
	local part = Mock.Tagged(t)[1]
	check(part and part:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil, t .. " has a ProximityPrompt")
end

-- Dig zone: one long strip on the water side, exposed to clients as workspace attributes.
local zone = World.GetDigZone()
local zoneCenter, zoneSize = zone.CFrame.Position, zone.Size
check(zoneSize.X >= 600 and zoneSize.Y == Config.TOTAL_DEPTH, "dig zone: long coastline, full depth")
check(math.abs(zoneCenter.Y - Config.SURFACE_Y) < 0.01, "dig zone CFrame sits at the surface")
check(zoneCenter.Z + zoneSize.Z / 2 <= 0, "dig zone is on the water side (-Z)")
check(
	workspace:GetAttribute("DigZoneCFrame") == zone.CFrame and workspace:GetAttribute("DigZoneSize") == zoneSize,
	"DigZoneCFrame / DigZoneSize workspace attributes"
)
check(World.IsInDigZone(zoneCenter - Vector3.new(0, 5, 0)), "IsInDigZone inside")
check(not World.IsInDigZone(Vector3.new(0, Config.SURFACE_Y, 40)), "hub is not in the dig zone")
check(not World.IsInDigZone(zoneCenter - Vector3.new(0, Config.TOTAL_DEPTH + 10, 0)), "below the world is not in the zone")
for _, sp in Mock.Tagged("SpawnLocation") do
	check(
		not World.IsInDigZone(sp.Position) and sp.Position.Y > Config.SURFACE_Y,
		"SpawnLocation on the boardwalk, outside the dig zone"
	)
end

-- Terrain under the strip: layered from the surface to the bottom (both ends and the middle).
section("terrain")
for _, fx in { -0.49, 0, 0.49 } do
	local x = zoneCenter.X + zoneSize.X * fx + 1
	local z = zoneCenter.Z + 1
	local topY, topMat = Mock.TerrainSurfaceBelow(x, z, Config.SURFACE_Y + 8)
	check(
		topY ~= nil and math.abs(topY - Config.SURFACE_Y) < 0.01,
		"dig zone surface at SURFACE_Y at x " .. math.floor(x) .. " (got " .. tostring(topY) .. ")"
	)
	check(topMat == Config.Layers[1].Material, "dig zone top material is layer 1")
	for i, layer in Config.Layers do
		local depth = (layer.DepthStart + layer.DepthEnd) / 2
		local v = Mock.GetVoxel(Vector3.new(x, Config.SURFACE_Y - depth, z))
		if
			not check(
				v ~= nil and v.Material == layer.Material,
				string.format("x %d layer %d (%s) material at depth %d", math.floor(x), i, layer.Id, depth)
			)
		then
			break
		end
	end
end
-- Solid layered walls around the zone (never dug: carving is clamped to the zone).
for _, p in
	{
		Vector3.new(1, Config.SURFACE_Y - 300, zoneCenter.Z - zoneSize.Z / 2 - 2),
		Vector3.new(1, Config.SURFACE_Y - 300, zoneCenter.Z + zoneSize.Z / 2 + 2),
		Vector3.new(zoneCenter.X + zoneSize.X / 2 + 2, Config.SURFACE_Y - 300, zoneCenter.Z),
	}
do
	check(Mock.GetVoxel(p) ~= nil, "solid wall around the dig zone at " .. tostring(p))
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
local remotesFolder = byPath["ReplicatedStorage/Shared/Remotes"]:FindFirstChild("Net")
check(
	remotesFolder ~= nil
		and remotesFolder:FindFirstChild("PlotAssigned") == nil
		and remotesFolder:FindFirstChild("GetPlot") == nil,
	"no PlotAssigned / GetPlot remotes"
)
local root = player.Character.HumanoidRootPart
local function onBoardwalk(pos)
	return pos.Y > Config.SURFACE_Y + 1
		and pos.Z > zoneCenter.Z + zoneSize.Z / 2
		and pos.Z < 14
		and not World.IsInDigZone(pos)
end
check(onBoardwalk(root.Position), "character spawned on the boardwalk (" .. tostring(root.Position) .. ")")
check(player:GetAttribute("Depth") == 0, "Depth attribute 0 on the boardwalk")
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
local c = Vector3.new(0, Config.SURFACE_Y, zoneCenter.Z)
standAt(Vector3.new(c.X, Config.SURFACE_Y + 3, c.Z))
local results = {}
local cooldown = Config.Shovels[1].Cooldown + 0.02
local since = #Mock.Remote.ToClient
for i = 1, 24 do
	-- client: raycast from the camera onto the terrain near the feet, on the sand
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
-- outside the dig zone (hub plaza in reach) -> OutOfZone; no server Notify for dig failures
data.Sand = 0
standAt(Vector3.new(44, Config.SURFACE_Y + 4, 18))
local n1 = #Mock.Remote.ToClient
Mock.FireServer("Dig", player, Vector3.new(44, Config.SURFACE_Y, 26))
Mock.Advance(0.6)
check(lastToClient(player, "DigResult")[1].Reason == "OutOfZone", "dig at the hub -> OutOfZone")
check(#notifies(player, n1) == 0, "dig failures send no Notify (client hints only): " .. table.concat(notifies(player, n1), " / "))
data.Sand = capacity
standAt(Vector3.new(c.X, Config.SURFACE_Y + 3, c.Z))
local n2 = #Mock.Remote.ToClient
Mock.FireServer("Dig", player, Vector3.new(c.X + 8, Config.SURFACE_Y, c.Z))
Mock.Advance(0.6)
check(lastToClient(player, "DigResult")[1].Reason == "BackpackFull", "full backpack -> BackpackFull result")
check(#notifies(player, n2) == 0, "backpack full: no duplicate server Notify")

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
check((player:GetAttribute("Depth") or 0) >= 55, "Depth attribute in a hole (" .. tostring(player:GetAttribute("Depth")) .. ")")
Mock.FireServer("ReturnToSurface", player)
Mock.Advance(0.2)
root = player.Character.HumanoidRootPart
check(root.Position.Y > Config.SURFACE_Y, "ReturnToSurface teleports to the surface")
check(
	onBoardwalk(root.Position) and math.abs(root.Position.X - c.X) < 1,
	"ReturnToSurface lands on the boardwalk nearby"
)
standAt(Vector3.new(0, Config.SURFACE_Y - 10, -110)) -- beach slope / sea, outside the dig zone
Mock.Advance(1)
check(player:GetAttribute("Depth") == 0, "Depth is 0 outside the dig zone")
standAt(Vector3.new(c.X, Config.SURFACE_Y - 60, c.Z))
player.Character.Humanoid.Health = 0
Mock.SpawnCharacter(player, Vector3.new(0, Config.SURFACE_Y + 3, 4))
Mock.Advance(1)
root = player.Character.HumanoidRootPart
check(onBoardwalk(root.Position), "respawn on the boardwalk")
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
check(onBoardwalk(player.Character.HumanoidRootPart.Position), "rebirth sends you to the surface")

-- Leave + rejoin ------------------------------------------------------------------------------------
section("leave")
DataService.Set(player, "Coins", 4242)
Mock.Advance(0.1)
standAt(Vector3.new(c.X, Config.SURFACE_Y + 3, c.Z))
Mock.FireServer("Dig", player, Vector3.new(c.X, Config.SURFACE_Y, c.Z))
Mock.Advance(1)
Mock.RemovePlayer(player)
Mock.Advance(3)
if not STUDIO_NO_API then
	local saved = Mock.DataStores[Config.DATASTORE_NAME] and Mock.DataStores[Config.DATASTORE_NAME]["Player_1001"]
	check(saved ~= nil and saved.Data ~= nil and saved.Data.Coins == 4242, "data saved on leave")
	check(saved ~= nil and saved.Lock == nil, "session lock released on leave")
end
check(not DataService.IsLoaded(player), "session cleared")

section("rejoin")
local player2 = Mock.AddPlayer(1001, "Tester")
Mock.Advance(0.5)
Mock.SpawnCharacter(player2)
Mock.Advance(2)
local data2 = DataService.Get(player2)
check(data2 ~= nil and data2.Coins == 4242 and data2.Rebirths == 1, "data persisted across sessions")
check(onBoardwalk(player2.Character.HumanoidRootPart.Position), "rejoin spawns on the boardwalk")

section("full server")
local crowd = {}
for i = 1, Config.MAX_PLAYERS - 1 do
	local p = Mock.AddPlayer(2000 + i, "Crowd" .. i)
	Mock.SpawnCharacter(p)
	crowd[i] = p
end
Mock.Advance(3)
local onDeck = if onBoardwalk(player2.Character.HumanoidRootPart.Position) then 1 else 0
for _, p in crowd do
	if p.Character and onBoardwalk(p.Character.HumanoidRootPart.Position) then
		onDeck += 1
	end
end
check(onDeck == Config.MAX_PLAYERS, Config.MAX_PLAYERS .. " players all spawn on the boardwalk (" .. onDeck .. ")")
-- everyone digs side by side on the shared beach
for i, p in crowd do
	local x = -300 + i * 36
	p.Character:PivotTo(CFrame.new(x, Config.SURFACE_Y + 3, zoneCenter.Z + 4))
end
Mock.Advance(0.2)
for i, p in crowd do
	local x = -300 + i * 36
	Mock.FireServer("Dig", p, Vector3.new(x, Mock.TerrainSurfaceBelow(x, zoneCenter.Z, Config.SURFACE_Y + 8), zoneCenter.Z))
end
Mock.Advance(0.5)
local crowdDigs = 0
for _, p in crowd do
	local r = lastToClient(p, "DigResult")
	if r and r[1].Success then
		crowdDigs += 1
	end
end
check(crowdDigs == #crowd, "every player digs on the shared beach (" .. crowdDigs .. "/" .. #crowd .. ")")
for i = 1, #crowd do
	Mock.RemovePlayer(crowd[i])
end
Mock.Advance(5)

-- Beach: dig size, DigAt (Digger), Sunburnt, depth anti-cheat, tide refill, High Tide ------------
section("beach")
step("beach", function()
	local S = Config.SURFACE_Y
	local p, d = player2, data2
	local MultiplierService = Mock.Require(byPath["ServerScriptService/Server/Services/MultiplierService"])
	local Stats = Mock.Require(byPath["ReplicatedStorage/Shared/Util/Stats"])
	local function stand(pos)
		p.Character:PivotTo(CFrame.new(pos))
	end
	local function solid(x, y, z)
		local v = Mock.GetVoxel(Vector3.new(x, y, z))
		return v ~= nil and v.Occupancy > 0
	end
	-- Skip ahead so the real High Tide schedule (EventService) can't start during the waits below.
	local highTide = Config.GetEvent("HighTide")
	if highTide then
		for _ = 1, 10 do
			local untilStart = Config.GetSecondsUntilEvent("HighTide", Mock.Env.os.time())
			if untilStart > Config.TIDE_REFILL_SECONDS * 2 + 60 then
				break
			end
			Mock.Advance(untilStart + highTide.DurationSeconds + 2)
		end
	end
	d.Sand = 0
	check(d.Shovel == Config.Shovels[1].Id, "starter shovel equipped for the beach tests")

	-- starter dig: one 4x4x4 voxel + the surface voxel above it, nothing more
	local zDig = zoneCenter.Z + 2
	stand(Vector3.new(302, S + 3, zDig + 4))
	local since = #Mock.Remote.ToClient
	Mock.FireServer("Dig", p, Vector3.new(302, S, zDig))
	Mock.Advance(0.6)
	local r = lastToClient(p, "DigResult")
	check(r ~= nil and r[1].Success, "surface dig on the beach succeeds")
	check(not solid(302, S - 2, zDig), "surface dig removes terrain")
	check(solid(302, S - 6, zDig) and solid(306, S - 2, zDig), "starter dig stays small (one voxel) " .. tostring(solid(302, S - 6, zDig)) .. tostring(solid(306, S - 2, zDig)))
	check(BeachService.GetDugDepthAt(Vector3.new(302, S, zDig)) >= 4, "dug cell recorded for the tide")
	check(countToClient(p, "DigResult", since) == 1, "one DigResult per dig")

	-- DigAt with a Digger source: own stats, no cooldown, range check, Silent, zone clamp
	stand(Vector3.new(332, S + 3, zDig + 4))
	local opts = { Power = 1e6, Radius = 4, SandMultiplier = 3, Source = "Digger", Silent = true }
	local s0 = #Mock.Remote.ToClient
	local r1 = DigService.DigAt(p, Vector3.new(334, S, zDig - 4), opts)
	local r2 = DigService.DigAt(p, Vector3.new(326, S, zDig - 4), opts)
	check(r1 ~= nil and r1.Success and r2 ~= nil and r2.Success, "Digger DigAt succeeds twice in a row (no cooldown)")
	check(not solid(334, S - 6, zDig - 4), "Digger radius 4 carves a bigger (8-stud) cube")
	check(countToClient(p, "DigResult", s0) == 0, "Silent digger digs send no DigResult")
	check(d.Sand > 0, "digger sand goes into the backpack")
	local far = DigService.DigAt(p, Vector3.new(374, S, zDig), opts)
	check(far ~= nil and far.Reason == "TooFar", "Digger dig far from the owner -> TooFar")
	local out = DigService.DigAt(p, Vector3.new(334, S, zoneCenter.Z - zoneSize.Z / 2 - 6), opts)
	check(out ~= nil and out.Reason == "OutOfZone", "Digger dig outside the zone -> OutOfZone")
	local weak = DigService.DigAt(p, Vector3.new(330, S - 400, zDig), {
		Power = 1,
		Radius = 2,
		SandMultiplier = 1,
		Source = "Digger",
		Silent = true,
	})
	check(weak == nil or weak.Reason ~= nil, "weak digger cannot dig deep")
	d.Sand = d.Sand -- (keep)

	-- Sunburnt multiplies the shovel cooldown
	d.Sand = 0
	stand(Vector3.new(358, S + 3, zDig + 4))
	local cd = Stats.GetCooldown(MultiplierService.GetContext(p))
	local mult = Config.Heat.SunburntCooldownMultiplier
	Mock.Advance(cd * 2)
	p:SetAttribute("Sunburnt", true)
	local a1 = DigService.TryDig(p, Vector3.new(358, S, zDig), false)
	check(a1 ~= nil and a1.Success, "sunburnt dig succeeds after the cooldown")
	Mock.Advance(cd * 1.1)
	p:SetAttribute("Sunburnt", true)
	local a2 = DigService.TryDig(p, Vector3.new(362, S, zDig), false)
	if mult * Config.COOLDOWN_LENIENCY > 1.2 then
		check(a2 ~= nil and a2.Reason == "Cooldown", "Sunburnt: cooldown x" .. mult .. " blocks the next dig")
	end
	p:SetAttribute("Sunburnt", false)
	local a3 = DigService.TryDig(p, Vector3.new(362, S, zDig), false)
	check(a3 ~= nil and a3.Success, "normal cooldown once no longer sunburnt")

	-- Depth attribute + MaxDepth only counts dug terrain
	local maxBefore = d.MaxDepth
	stand(Vector3.new(-330, S - 300, zoneCenter.Z))
	Mock.Advance(1.2)
	check((p:GetAttribute("Depth") or 0) >= 290, "Depth attribute deep inside the zone")
	check(d.MaxDepth == maxBefore, "standing in undug terrain does not raise MaxDepth")

	-- Tide: holes refill once nobody was near for TIDE_REFILL_SECONDS
	p.Character:PivotTo(World.GetSurfacePoint(Vector3.new(-330, S, 0)))
	Mock.Advance(Config.TIDE_REFILL_SECONDS * 0.5)
	check(not solid(302, S - 2, zDig), "hole stays open before the tide timer runs out")
	Mock.Advance(Config.TIDE_REFILL_SECONDS * 0.5 + 6)
	local v = Mock.GetVoxel(Vector3.new(302, S - 2, zDig))
	check(
		v ~= nil and v.Occupancy == 1 and v.Material == Config.Layers[1].Material,
		"tide refilled the hole with the layer material"
	)
	check(solid(334, S - 6, zDig - 4), "tide refilled the digger hole")
	check(BeachService.CountDugCells() == 0, "every idle dug cell refilled (" .. BeachService.CountDugCells() .. ")")

	-- ...but not while someone stays near
	d.Sand = 0
	stand(Vector3.new(-98, S + 3, zDig + 4))
	Mock.Advance(cd * 2)
	Mock.FireServer("Dig", p, Vector3.new(-98, S, zDig))
	Mock.Advance(0.6)
	check(not solid(-98, S - 2, zDig), "new hole dug")
	Mock.Advance(Config.TIDE_REFILL_SECONDS + 6)
	check(not solid(-98, S - 2, zDig), "tide waits while a player is near the hole")

	-- High Tide: lift the player out of the hole first, then smooth every hole
	stand(Vector3.new(-98, S - 2, zDig))
	local previous = workspace:GetAttribute("ActiveEvents")
	workspace:SetAttribute("ActiveEvents", "")
	workspace:SetAttribute("ActiveEvents", "HighTide")
	Mock.Advance(2.5)
	local pos = p.Character.HumanoidRootPart.Position
	check(pos.Y > S + 1 and not World.IsInDigZone(pos), "High Tide lifts the player out of the hole first")
	check(solid(-98, S - 2, zDig), "High Tide refills the hole")
	check(BeachService.CountDugCells() == 0, "High Tide smooths every dug cell")
	workspace:SetAttribute("ActiveEvents", previous or "")
	Mock.Advance(0.5)
end)

-- Diggers (Diggers agent) ---------------------------------------------------------------------------
section("diggers")
step("diggers", function()
	local DiggerService = Mock.Require(byPath["ServerScriptService/Server/Services/DiggerService"])
	local digPlayer = Mock.AddPlayer(3001, "DiggerTester")
	Mock.Advance(0.5)
	local zone = World.GetDigZone()
	local zc = zone.CFrame.Position
	local function surfaceAt(x, z)
		return Mock.TerrainSurfaceBelow(x, z, Config.SURFACE_Y + 8) or Config.SURFACE_Y
	end
	local function standOnSand(dx, dz)
		local x, z = zc.X + dx, zc.Z + dz
		digPlayer.Character:PivotTo(CFrame.new(x, surfaceAt(x, z) + 3, z))
	end
	Mock.SpawnCharacter(digPlayer)
	Mock.Advance(2)
	local d = DataService.Get(digPlayer)
	check(d ~= nil and type(d.Diggers) == "table", "digger player data loaded with Diggers table")
	check(digPlayer:GetAttribute("EquippedDiggers") == "", "EquippedDiggers empty for a new player")
	check(digPlayer:GetAttribute("DiggerSlots") == 1, "1 digger slot by default")

	local first, second = Config.Diggers[1], Config.Diggers[2]
	-- buy: not enough coins, then OK (auto-equips into the free slot)
	DataService.Set(digPlayer, "Coins", 0)
	Mock.FireServer("BuyDigger", digPlayer, first.Id)
	Mock.Advance(0.3)
	check(d.Diggers[first.Id] == nil, "BuyDigger refused without coins")
	DataService.Set(digPlayer, "Coins", 1e12)
	Mock.Advance(0.1)
	Mock.FireServer("BuyDigger", digPlayer, first.Id)
	Mock.Advance(0.3)
	check(d.Diggers[first.Id] ~= nil and d.Diggers[first.Id].Equipped == true, "bought + auto-equipped digger 1")
	check(d.Coins == 1e12 - first.Price, "digger price charged")
	check(digPlayer:GetAttribute("EquippedDiggers") == first.Id .. ":1", "EquippedDiggers = id:level")
	Mock.FireServer("BuyDigger", digPlayer, first.Id)
	Mock.FireServer("BuyDigger", digPlayer, "nope")
	Mock.FireServer("BuyDigger", digPlayer, 42)
	Mock.Advance(0.3)
	check(d.Coins == 1e12 - first.Price, "buying an owned / unknown digger costs nothing")
	-- slot limit
	Mock.FireServer("BuyDigger", digPlayer, second.Id)
	Mock.Advance(0.3)
	check(d.Diggers[second.Id] ~= nil and d.Diggers[second.Id].Equipped == false, "2nd digger owned, not equipped (1 slot)")
	Mock.FireServer("EquipDigger", digPlayer, second.Id)
	Mock.Advance(0.3)
	check(d.Diggers[second.Id].Equipped == false, "equip refused when slots are full")
	Mock.FireServer("UnequipDigger", digPlayer, first.Id)
	Mock.Advance(0.3)
	Mock.FireServer("EquipDigger", digPlayer, second.Id)
	Mock.Advance(0.3)
	check(d.Diggers[second.Id].Equipped and not d.Diggers[first.Id].Equipped, "swap equipped digger")
	check(digPlayer:GetAttribute("EquippedDiggers") == second.Id .. ":1", "EquippedDiggers follows equip")
	-- upgrades
	local coins0 = d.Coins
	Mock.FireServer("UpgradeDigger", digPlayer, second.Id)
	Mock.Advance(0.3)
	check(d.Diggers[second.Id].Level == 2, "upgrade to level 2")
	check(d.Coins == coins0 - Config.GetDiggerUpgradeCost(second, 1), "upgrade cost charged")
	check(digPlayer:GetAttribute("EquippedDiggers") == second.Id .. ":2", "EquippedDiggers carries the level")
	for _ = 1, second.MaxLevel + 2 do
		Mock.FireServer("UpgradeDigger", digPlayer, second.Id)
		Mock.Advance(0.3)
	end
	check(d.Diggers[second.Id].Level == second.MaxLevel, "upgrades stop at MaxLevel")
	local s1 = Config.GetDiggerStats(second, 1)
	local sMax = Config.GetDiggerStats(second, second.MaxLevel)
	check(sMax.Interval < s1.Interval and sMax.SandMultiplier > s1.SandMultiplier, "levels improve speed + sand")
	-- rebirth gate + rebirth slot milestone
	local last = Config.Diggers[#Config.Diggers]
	Mock.FireServer("BuyDigger", digPlayer, last.Id)
	Mock.Advance(0.3)
	check(d.Diggers[last.Id] == nil, "rebirth-locked digger refused")
	DataService.Set(digPlayer, "Rebirths", Config.DIGGER_REBIRTH_SLOTS[1])
	Mock.Advance(0.5)
	check(digPlayer:GetAttribute("DiggerSlots") == 2, "+1 digger slot at rebirth " .. Config.DIGGER_REBIRTH_SLOTS[1])
	Mock.FireServer("EquipDigger", digPlayer, first.Id)
	Mock.Advance(0.3)
	check(
		digPlayer:GetAttribute("EquippedDiggers") == first.Id .. ":1," .. second.Id .. ":" .. second.MaxLevel,
		"two diggers equipped with 2 slots (" .. tostring(digPlayer:GetAttribute("EquippedDiggers")) .. ")"
	)
	check(Config.GetDiggerSlots(5, true) == 4, "slot helper: 1 base + pass + rebirth 2 + rebirth 5")

	-- dig loop: owner on the sand -> diggers dig near them and fill the backpack
	Mock.ServerTerrainRaycast = true
	standOnSand(-20, 0)
	d.Sand = 0
	local since = #Mock.Remote.ToClient
	Mock.Advance(8)
	local dugEvents = 0
	local dugPos
	for i = since + 1, #Mock.Remote.ToClient do
		local e = Mock.Remote.ToClient[i]
		if e.Name == "DiggerDug" and e.Player == digPlayer then
			dugEvents += 1
			dugPos = e.Args[3]
			check(e.Args[1] == digPlayer and type(e.Args[2]) == "string", "DiggerDug(player, diggerId, position)")
		end
	end
	check(dugEvents >= 2, "diggers dig on their own (" .. dugEvents .. " DiggerDug events)")
	check(d.Sand > 0, "digger digs put sand in the backpack (" .. tostring(d.Sand) .. ")")
	if dugPos then
		local feet = digPlayer.Character.HumanoidRootPart.Position
		check((Vector3.new(dugPos.X, feet.Y, dugPos.Z) - feet).Magnitude < 8, "digger digs near its owner")
	end
	-- full backpack: diggers rest, one gentle notice per fill
	d.Sand = 0
	Mock.Advance(0.3)
	d.Sand = digPlayer:GetAttribute("Capacity") or 1e9
	local full0 = #Mock.Remote.ToClient
	Mock.Advance(5)
	check(countToClient(digPlayer, "DiggerDug", full0) == 0, "diggers stop when the backpack is full")
	local resting = 0
	for _, n in notifies(digPlayer, full0) do
		if string.find(n, "resting", 1, true) then
			resting += 1
		end
	end
	check(resting == 1, "one 'diggers resting' notice per full backpack (" .. resting .. ")")
	-- outside the dig zone (hub / boardwalk): idle
	d.Sand = 0
	digPlayer.Character:PivotTo(World.GetSurfacePoint(zc))
	local hub0 = #Mock.Remote.ToClient
	Mock.Advance(5)
	check(countToClient(digPlayer, "DiggerDug", hub0) == 0, "diggers idle outside the dig zone")
	Mock.ServerTerrainRaycast = false
	check(DiggerService.GetSlots(digPlayer) == 2, "DiggerService.GetSlots")
	Mock.RemovePlayer(digPlayer)
	Mock.Advance(3)
end)

-- Survival (Survival agent): heat, shade, snacks -------------------------------------------------------
section("survival")
step("survival", function()
	local SurvivalService = Mock.Require(byPath["ServerScriptService/Server/Services/SurvivalService"])
	local Heat = Config.Heat
	local sp = Mock.AddPlayer(3101, "SunnyTester")
	Mock.Advance(0.5)
	Mock.SpawnCharacter(sp)
	Mock.Advance(2)
	local d = DataService.Get(sp)
	check(d ~= nil and type(d.OwnedShades) == "table" and type(d.Consumables) == "table", "survival data fields")
	check(sp:GetAttribute("Heat") == 0 and sp:GetAttribute("Sunburnt") == false, "Heat / Sunburnt attributes on join")
	local humanoid = sp.Character:FindFirstChildOfClass("Humanoid")
	Mock.Internal(humanoid).props.FloorMaterial = Enum.Material.Sand -- read-only in Roblox
	local zone = World.GetDigZone()
	local zc = zone.CFrame.Position
	local function surfaceAt(x, z)
		return Mock.TerrainSurfaceBelow(x, z, Config.SURFACE_Y + 8)
	end
	-- an undug patch of sand in the dig zone, away from other tests' holes
	local spot
	for _, dx in { 40, -40, 60, -60, 80, -80, 20, -20 } do
		local x, z = zc.X + dx, zc.Z
		local ok = true
		for _, o in { Vector3.new(0, 0, 0), Vector3.new(6, 0, 0), Vector3.new(-6, 0, 0), Vector3.new(0, 0, 6) } do
			local y = surfaceAt(x + o.X, z + o.Z)
			if y == nil or math.abs(y - Config.SURFACE_Y) > 0.01 then
				ok = false
			end
		end
		if ok then
			spot = Vector3.new(x, Config.SURFACE_Y, z)
			break
		end
	end
	if not check(spot ~= nil, "found an undug sand spot in the dig zone") then
		return
	end
	local function stand(pos)
		sp.Character:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
	end
	stand(spot)
	sp:SetAttribute("Depth", 0)

	-- Heat in the sun (grace first)
	Mock.Advance(4)
	check(sp:GetAttribute("HeatZone") == "Sun", "standing on the dig sand = Sun zone")
	check(sp:GetAttribute("HeatGrace") == true and SurvivalService.GetHeat(sp) == 0, "new-player grace: no heat")
	d.PlayTime = Heat.NewPlayerGraceSeconds + 60
	Mock.Advance(10)
	local h1 = SurvivalService.GetHeat(sp)
	check(h1 > 2 and h1 < 8, string.format("heat rises in the sun (%.2f after 10s)", h1))
	check(sp:GetAttribute("Heat") == math.floor(h1 * 10 + 0.5) / 10, "Heat attribute mirrors server heat")
	-- digs add capped heat
	local ServerSignals = Mock.Require(byPath["ServerScriptService/Server/Services/ServerSignals"])
	local before = SurvivalService.GetHeat(sp)
	for _ = 1, 30 do
		ServerSignals.Dug:Fire(sp, 1, 1, "Digger") -- diggers never heat their owner
	end
	Mock.Advance(1)
	check(SurvivalService.GetHeat(sp) - before < Heat.SunRisePerSecond * 2, "digger digs add no heat")
	before = SurvivalService.GetHeat(sp)
	for _ = 1, 30 do
		ServerSignals.Dug:Fire(sp, 1, 1, "Shovel")
	end
	Mock.Advance(1)
	local gained = SurvivalService.GetHeat(sp) - before
	local sun = 1
	for _, id in Mock.Service("Workspace"):GetAttribute("ActiveEvents"):split(",") do
		sun *= Heat.EventSunMultipliers[id] or 1
	end
	check(
		gained > Heat.SunRisePerSecond * sun * 0.9 and gained <= (Heat.SunRisePerSecond + Heat.DigRiseMaxPerSecond) * sun * 1.3 + 0.05,
		string.format("dig heat added but capped (+%.2f in 1s)", gained)
	)
	-- Sunburnt toggles
	SurvivalService.SetHeat(sp, Heat.SunburntAt - 0.2)
	Mock.Advance(2)
	check(sp:GetAttribute("Sunburnt") == true, "Sunburnt at SunburntAt")
	SurvivalService.SetHeat(sp, Heat.RecoverAt + 5)
	Mock.Advance(0.5)
	check(sp:GetAttribute("Sunburnt") == true, "still Sunburnt above RecoverAt")

	-- Shades: buy
	DataService.Set(sp, "Coins", 0)
	Mock.Advance(0.1)
	local umbrella = Config.Shades[1]
	Mock.FireServer("BuyShade", sp, umbrella.Id)
	Mock.Advance(0.3)
	check(d.OwnedShades[umbrella.Id] == nil, "BuyShade refused without coins")
	DataService.Set(sp, "Coins", 1e9)
	Mock.Advance(0.1)
	Mock.FireServer("BuyShade", sp, umbrella.Id)
	Mock.Advance(0.3)
	check(d.OwnedShades[umbrella.Id] == true and d.Coins == 1e9 - umbrella.Price, "bought the umbrella")
	local locked = Config.Shades[#Config.Shades]
	Mock.FireServer("BuyShade", sp, locked.Id)
	Mock.FireServer("BuyShade", sp, 42)
	Mock.Advance(0.3)
	check(d.OwnedShades[locked.Id] == nil, "rebirth-locked shade refused")

	-- Shades: place (validation failures first)
	local Shades = SurvivalService.Shades
	local function placeCount()
		return #Shades.GetPlaced(sp)
	end
	local ok, reason = Shades.Place(sp, Config.Shades[2].Id, spot, 0)
	check(not ok and placeCount() == 0, "can't place an unowned shade (" .. tostring(reason) .. ")")
	ok, reason = Shades.Place(sp, umbrella.Id, spot + Vector3.new(Heat.ShadePlaceRange + 20, 0, 0), 0)
	check(not ok, "can't place too far away (" .. tostring(reason) .. ")")
	ok, reason = Shades.Place(sp, umbrella.Id, spot - Vector3.new(0, 30, 0), 0)
	check(not ok, "can't place down a hole (" .. tostring(reason) .. ")")
	ok, reason = Shades.Place(sp, umbrella.Id, spot + Vector3.new(0, 12, 0), 0)
	check(not ok, "can't place floating in the air (" .. tostring(reason) .. ")")
	-- dig a pit next to us and try to place over it
	local pit = spot + Vector3.new(8, 0, 0)
	workspace.Terrain:FillBlock(CFrame.new(pit.X, Config.SURFACE_Y - 8, pit.Z), Vector3.new(8, 16, 8), Enum.Material.Air)
	ok, reason = Shades.Place(sp, umbrella.Id, pit, 0)
	check(not ok, "can't place over a hole (" .. tostring(reason) .. ")")
	local fountain = Mock.Tagged("WaterFountain")[1]
	if fountain then
		local fp = fountain.Position
		local saved = sp.Character.HumanoidRootPart.Position
		stand(Vector3.new(fp.X, Config.SURFACE_Y, fp.Z + 6))
		ok, reason = Shades.Place(sp, umbrella.Id, Vector3.new(fp.X + 3, fp.Y, fp.Z + 3), 0)
		check(not ok, "can't place on the hub fountain (" .. tostring(reason) .. ")")
		stand(saved - Vector3.new(0, 3, 0))
	end
	ok, reason = Shades.Place(sp, umbrella.Id, spot, math.pi / 2)
	check(ok and placeCount() == 1, "placed the umbrella (" .. tostring(reason) .. ")")
	local placed = Shades.GetPlaced(sp)[1]
	local model = placed and placed.Model
	check(model ~= nil and model.Parent ~= nil and model.Parent.Name == "Shades", "shade model in Workspace.Shades")
	check(model and model:GetAttribute("OwnerUserId") == sp.UserId, "shade has OwnerUserId")
	check(model and #Mock.Tagged("PlacedShade") >= 1, "shade tagged PlacedShade")
	check(model and math.abs(model:GetPivot().Position.Y - Config.SURFACE_Y) < 3.5, "shade sits on the sand surface")
	-- remote path + spacing rule
	local n0 = #Mock.Remote.ToClient
	Mock.FireServer("PlaceShade", sp, umbrella.Id, spot + Vector3.new(0, 0, 40), 0)
	Mock.FireServer("PlaceShade", sp, "nope", spot, 0)
	Mock.FireServer("PlaceShade", sp, umbrella.Id, "garbage", 0)
	Mock.Advance(0.5)
	check(#notifies(sp, n0) >= 1 and placeCount() == 1, "bad PlaceShade remotes are refused with a toast")

	-- Shade cools anyone under it
	Mock.Advance(1)
	check(sp:GetAttribute("InShade") == true and sp:GetAttribute("HeatZone") == "Shade", "InShade under own shade")
	local other = Mock.AddPlayer(3102, "ShadeGuest")
	Mock.Advance(0.5)
	Mock.SpawnCharacter(other)
	Mock.Advance(2)
	other.Character:PivotTo(CFrame.new(spot + Vector3.new(3, 3, 2)))
	Mock.Advance(1)
	check(other:GetAttribute("InShade") == true, "other players are shaded too")
	local burnt0 = SurvivalService.GetHeat(sp)
	Mock.Advance(2)
	check(SurvivalService.GetHeat(sp) < burnt0 - 4, "heat falls in the shade")
	Mock.Advance((Heat.RecoverAt + 5) / (Heat.ShadeFallPerSecond * umbrella.Cooling) + 2)
	check(sp:GetAttribute("Sunburnt") == false, "Sunburnt clears after cooling to RecoverAt")
	Mock.RemovePlayer(other)
	Mock.Advance(0.5)

	-- move it (same shade) and pick it up
	ok = Shades.Place(sp, umbrella.Id, spot + Vector3.new(0, 0, 6), 0)
	check(ok and placeCount() == 1, "placing again moves the shade (still 1)")
	Mock.FireServer("PickUpShade", sp)
	Mock.Advance(0.5)
	check(placeCount() == 0 and #Mock.Tagged("PlacedShade") == 0, "PickUpShade removes it")

	-- Consumables
	local lemonade = Config.GetConsumable("lemonade")
	DataService.Set(sp, "Coins", 1e9)
	Mock.Advance(0.1)
	Mock.FireServer("BuyConsumable", sp, "lemonade", 3)
	Mock.Advance(0.3)
	check(d.Consumables.lemonade == 3 and d.Coins == 1e9 - lemonade.Price * 3, "bought 3 lemonades")
	Mock.FireServer("BuyConsumable", sp, "water", 1)
	Mock.FireServer("BuyConsumable", sp, "lemonade", -5)
	Mock.FireServer("BuyConsumable", sp, "lemonade", 1e9)
	Mock.Advance(0.5)
	check(d.Consumables.water == nil, "water is not for sale")
	check(d.Consumables.lemonade == 3, "bad counts are ignored")
	SurvivalService.SetHeat(sp, 80)
	Mock.FireServer("UseConsumable", sp, "lemonade")
	Mock.Advance(0.3)
	check(d.Consumables.lemonade == 2, "UseConsumable spends one")
	check(math.abs(SurvivalService.GetHeat(sp) - (80 - lemonade.Cooling)) < 3, "lemonade cools")
	Mock.FireServer("UseConsumable", sp, "popsicle")
	Mock.Advance(0.3)
	check(d.Consumables.popsicle == nil, "can't use what you don't have")
	Mock.FireServer("BuyConsumable", sp, "popsicle", 1)
	Mock.Advance(0.3)
	Mock.FireServer("UseConsumable", sp, "popsicle")
	Mock.Advance(0.3)
	check(d.Consumables.popsicle == nil and (d.Boosts.SugarRush or 0) > Mock.Env.os.time(), "popsicle grants Sugar Rush")
	check((sp:GetAttribute("SpeedMultiplier") or 1) > 1, "Sugar Rush speeds up digging")

	-- Fountain
	if check(fountain ~= nil, "map has a WaterFountain") then
		SurvivalService.SetHeat(sp, 95)
		Mock.FireServer("DrinkFountain", sp) -- far away: nothing
		Mock.Advance(0.6)
		check(SurvivalService.GetHeat(sp) > 90, "can't drink from far away")
		local fp = fountain.Position
		stand(Vector3.new(fp.X, fp.Y + 1, fp.Z + 9))
		Mock.Internal(humanoid).props.FloorMaterial = Enum.Material.Marble
		Mock.FireServer("DrinkFountain", sp)
		Mock.Advance(0.6)
		local afterDrink = SurvivalService.GetHeat(sp)
		check(afterDrink < 95 - 60 and sp:GetAttribute("Sunburnt") == false, "fountain water cools fast")
		SurvivalService.SetHeat(sp, 90)
		Mock.FireServer("DrinkFountain", sp)
		Mock.Advance(0.6)
		check(SurvivalService.GetHeat(sp) > 85, "fountain has a short cooldown")
		Mock.Advance(Heat.FountainCooldownSeconds)
		check(sp:GetAttribute("HeatZone") == "Cool", "off the hot sand (hub) = Cool zone")
	end

	-- Underground
	SurvivalService.SetHeat(sp, 50)
	stand(Vector3.new(spot.X, Config.SURFACE_Y - 40, spot.Z))
	sp:SetAttribute("Depth", 40)
	Mock.Advance(1)
	check(sp:GetAttribute("HeatZone") == "Underground" and SurvivalService.GetHeat(sp) < 50, "underground cools")

	-- Cooler Pack product (configured id) through ProcessReceipt
	local marketplace = Mock.Service("MarketplaceService")
	Config.Monetization.Products.CoolerPack.Id = 9300
	local decision
	Mock.Env.task.spawn(function()
		decision = marketplace.ProcessReceipt({ PlayerId = 3101, ProductId = 9300, PurchaseId = "cooler-1" })
	end)
	Mock.Advance(1)
	check(decision == Enum.ProductPurchaseDecision.PurchaseGranted, "Cooler Pack receipt granted")
	check((d.Consumables.shaved_ice or 0) >= 5, "Cooler Pack grants consumables")
	Config.Monetization.Products.CoolerPack.Id = 0

	-- leaving despawns shades
	stand(spot)
	sp:SetAttribute("Depth", 0)
	Shades.Place(sp, umbrella.Id, spot, 0)
	check(placeCount() == 1, "placed before leaving")
	Mock.RemovePlayer(sp)
	Mock.Advance(3)
	check(#Mock.Tagged("PlacedShade") == 0, "shades despawn when the owner leaves")
end)

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
