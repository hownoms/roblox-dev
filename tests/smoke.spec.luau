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
		"CrateShop",
		"BeachShop",
	}
do
	check(#Mock.Tagged(t) > 0, "map places tag " .. t)
end
check(#Mock.Tagged("Garage") == 0, "the Garage is gone (v2.1: vehicles are pets from crates)")
for t, action in { WaterFountain = "Drink", CrateShop = "Open", BeachShop = "Shop" } do
	local part = Mock.Tagged(t)[1]
	local prompt = part and part:FindFirstChildWhichIsA("ProximityPrompt", true)
	check(prompt ~= nil and prompt.ActionText == action, t .. " has a '" .. action .. "' ProximityPrompt")
end
for _, egg in Mock.Tagged("EggShop") do
	check(type(egg:GetAttribute("EggId")) == "string", "EggShop part has EggId attribute")
	check(egg:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil, "EggShop part has a ProximityPrompt")
end
do
	local crateCount, pedestals = 0, 0
	for _, e in Config.Eggs do
		if e.Kind == "Crate" then
			crateCount += 1
		end
	end
	for _, pallet in Mock.Tagged("CrateShop") do
		local id = pallet:GetAttribute("EggId")
		if type(id) == "string" and Config.IsCrate(id) and pallet:FindFirstChildWhichIsA("ProximityPrompt", true) then
			pedestals += 1
		end
	end
	check(pedestals == crateCount, "one crate pallet (EggId + prompt) per Construction Crate")
	check(#Mock.Tagged("EggShop") + pedestals == #Config.Eggs, "every egg and crate has a pedestal")
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

-- Companions (v2.1): Construction Crates, digging pets, digger save migration -------------------------
section("companions")
step("companions", function()
	local PetDigService = Mock.Require(byPath["ServerScriptService/Server/Services/PetDigService"])
	local PetService = Mock.Require(byPath["ServerScriptService/Server/Services/PetService"])
	local Remotes = Mock.Require(byPath["ReplicatedStorage/Shared/Remotes"])

	-- Config: crates, vehicle pets, the rideable Mythic, economy bounds
	check(Config.Diggers == nil and Config.GetDigger == nil, "Config.Diggers folded into Config.Pets")
	local crates = {}
	for _, e in Config.Eggs do
		if e.Kind == "Crate" then
			table.insert(crates, e)
		end
	end
	check(#crates >= 3 and #crates <= 4, "3-4 Construction Crates (" .. #crates .. ")")
	for i, c in crates do
		check(c.Currency == "Coins", c.Id .. " costs coins")
		if i > 1 then
			check(c.Price > crates[i - 1].Price and c.UnlockLayer > crates[i - 1].UnlockLayer, c.Id .. " later + pricier")
		end
		for _, entry in c.Pets do
			local pet = Config.GetPet(entry.PetId)
			check(pet ~= nil and pet.VehicleKind ~= nil and pet.Dig ~= nil, entry.PetId .. " is a digging vehicle pet")
		end
	end
	local mega = Config.GetPet("mega_excavator")
	check(
		mega ~= nil and mega.Rideable == true and mega.Rarity == "Mythic" and mega.VehicleKind == "Excavator" and mega.Dig ~= nil,
		"mega_excavator: Mythic, Rideable, Excavator, digs"
	)
	local top = crates[#crates]
	local total, megaWeight = 0, 0
	for _, entry in top.Pets do
		total += entry.Weight
		if entry.PetId == "mega_excavator" then
			megaWeight = entry.Weight
		end
	end
	check(megaWeight / total > 0.004 and megaWeight / total < 0.006, "mega_excavator ~0.5% of the top crate")
	local creatureDiggers = 0
	local worst = 0
	for _, pet in Config.Pets do
		local dig = pet.Dig
		if dig then
			if not pet.VehicleKind then
				creatureDiggers += 1
			end
			-- compare with the best shovel whose Power <= the pet's Power
			local shovel = Config.Shovels[1]
			for _, sh in Config.Shovels do
				if sh.Power <= dig.Power then
					shovel = sh
				end
			end
			local ratio = (dig.SandMultiplier / dig.Interval) / (shovel.SandMultiplier / shovel.Cooldown)
			worst = math.max(worst, ratio)
			check(ratio <= 0.25, string.format("%s digs %.0f%% of the same-power shovel (<= 25%%)", pet.Id, ratio * 100))
		end
	end
	check(creatureDiggers >= 4, "some creature pets dig too (" .. creatureDiggers .. ")")
	check(worst * 6 < 1, "6 slots of the best digging pets stay under active shovel digging")
	check(Config.Monetization.GamePasses.AutoDig.ExtraPetSlots == 1, "AutoDig pass = +1 pet slot")
	check(not table.find(Remotes.Events, "BuyDigger") and not table.find(Remotes.Events, "EquipDigger"), "digger remotes removed")
	check(
		not table.find(Remotes.Events, "UpgradeDigger") and not table.find(Remotes.Events, "UnequipDigger"),
		"digger upgrade / unequip remotes removed"
	)
	check(table.find(Remotes.Events, "PetDug") ~= nil and not table.find(Remotes.Events, "DiggerDug"), "DiggerDug -> PetDug")

	-- Crate hatch gives a vehicle pet
	local cp = Mock.AddPlayer(3001, "PetDigTester")
	Mock.Advance(0.5)
	local zone = World.GetDigZone()
	local zc = zone.CFrame.Position
	local S = Config.SURFACE_Y
	local function surfaceAt(x, z)
		return Mock.TerrainSurfaceBelow(x, z, S + 8) or S
	end
	local function standOnSand(who, dx, dz)
		local x, z = zc.X + dx, zc.Z + dz
		who.Character:PivotTo(CFrame.new(x, surfaceAt(x, z) + 3, z))
	end
	Mock.SpawnCharacter(cp)
	Mock.Advance(2)
	local d = DataService.Get(cp)
	check(d ~= nil and type(d.Diggers) == "table" and next(d.Diggers) == nil, "new save: empty legacy Diggers")
	DataService.Set(cp, "Coins", 1e13)
	DataService.Set(cp, "MaxDepth", 0)
	Mock.Advance(0.2)
	local crate = crates[1]
	Mock.FireServer("HatchEgg", cp, crate.Id, 1)
	Mock.Advance(0.5)
	check(next(d.Pets) == nil, "locked crate refused")
	DataService.Set(cp, "MaxDepth", Config.Layers[top.UnlockLayer].DepthStart + 1)
	Mock.Advance(0.2)
	local h0 = #Mock.Remote.ToClient
	Mock.FireServer("HatchEgg", cp, crate.Id, 1)
	Mock.Advance(0.5)
	local hatchedId
	for _, pet in d.Pets do
		hatchedId = pet.Id
	end
	local hatchedDef = hatchedId and Config.GetPet(hatchedId)
	check(hatchedDef ~= nil and hatchedDef.VehicleKind ~= nil and hatchedDef.Dig ~= nil, "crate hatch gives a digging vehicle pet (" .. tostring(hatchedId) .. ")")
	check(countToClient(cp, "EggHatched", h0) == 1, "crate hatch fires EggHatched")
	check(d.Coins == 1e13 - crate.Price, "crate price charged")

	-- Digging pets dig their own spots on a ring around the owner, never under them
	for uid in d.Pets do
		d.Pets[uid] = nil
	end
	DataService.MarkDirty(cp, "Pets")
	Mock.Advance(0.2)
	for _, id in { "mini_excavator", "bulldozer", "core_driller" } do
		PetService.GrantPet(cp, id)
	end
	Mock.Advance(0.3)
	check(#PetDigService.GetDiggers(cp) == 3, "3 equipped digging pets")
	Mock.ServerTerrainRaycast = true
	standOnSand(cp, -60, 0)
	d.Sand = 0
	local root = cp.Character.HumanoidRootPart
	local owner = root.Position
	local since = #Mock.Remote.ToClient
	local sandTotal = 0
	for _ = 1, 20 do
		Mock.Advance(0.5)
		sandTotal += d.Sand
		d.Sand = 0 -- keep the starter bucket empty so the pets never stop
	end
	local events, slots, minDist = 0, {}, math.huge
	for i = since + 1, #Mock.Remote.ToClient do
		local e = Mock.Remote.ToClient[i]
		if e.Name == "PetDug" and e.Player == cp then
			events += 1
			local a = e.Args
			if events == 1 then
				check(
					a[1] == cp and type(a[2]) == "number" and type(a[3]) == "string" and a[4] ~= nil and a[4].X ~= nil,
					"PetDug(player, slot, petId, position, sand)"
				)
			end
			slots[a[2]] = true
			local pos = a[4]
			minDist = math.min(minDist, (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(owner.X, 0, owner.Z)).Magnitude)
		end
	end
	local slotCount = 0
	for _ in slots do
		slotCount += 1
	end
	check(events >= 4, "digging pets dig on their own (" .. events .. " PetDug events)")
	check(slotCount >= 2, "several pets dig (" .. slotCount .. " slots)")
	check(minDist >= 5, string.format("pets never dig under the owner (closest dig %.1f studs >= 5)", minDist))
	check(sandTotal > 0, "pet digs put sand in the backpack")
	local underFeet = true
	for _, o in { Vector3.new(0, 0, 0), Vector3.new(1.5, 0, 0), Vector3.new(-1.5, 0, 0), Vector3.new(0, 0, 1.5), Vector3.new(0, 0, -1.5) } do
		local v = Mock.GetVoxel(Vector3.new(owner.X + o.X, surfaceAt(owner.X, owner.Z) - 2, owner.Z + o.Z))
		if not (v and v.Occupancy > 0) then
			underFeet = false
		end
	end
	check(underFeet, "the sand under the owner's feet is untouched")
	local spot1 = PetDigService.GetSpot(cp, 1)
	check(spot1 ~= nil, "pet 1 has its own spot")

	-- another player nearby: pets keep 5 studs away from them
	local other = Mock.AddPlayer(3003, "Neighbour")
	Mock.Advance(0.5)
	Mock.SpawnCharacter(other)
	Mock.Advance(1)
	standOnSand(other, -51, 0)
	local otherPos = other.Character.HumanoidRootPart.Position
	local n0 = #Mock.Remote.ToClient
	for _ = 1, 16 do
		Mock.Advance(0.5)
		d.Sand = 0
	end
	local nearOther = math.huge
	for i = n0 + 1, #Mock.Remote.ToClient do
		local e = Mock.Remote.ToClient[i]
		if e.Name == "PetDug" and e.Player == cp then
			local pos = e.Args[4]
			nearOther = math.min(nearOther, (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(otherPos.X, 0, otherPos.Z)).Magnitude)
		end
	end
	check(nearOther >= 5, string.format("pets keep >= 5 studs from other players (%.1f)", nearOther))
	Mock.RemovePlayer(other)
	Mock.Advance(1)

	-- full backpack: pets rest, one gentle notice per fill
	d.Sand = cp:GetAttribute("Capacity") or 1e9
	local full0 = #Mock.Remote.ToClient
	Mock.Advance(5)
	check(countToClient(cp, "PetDug", full0) == 0, "pets stop digging when the backpack is full")
	local resting = 0
	for _, n in notifies(cp, full0) do
		if string.find(n, "stopped digging", 1, true) then
			resting += 1
		end
	end
	check(resting == 1, "one 'pets stopped digging' notice per full backpack (" .. resting .. ")")
	-- outside the dig zone (hub / boardwalk): idle
	d.Sand = 0
	cp.Character:PivotTo(World.GetSurfacePoint(zc))
	local hub0 = #Mock.Remote.ToClient
	Mock.Advance(5)
	check(countToClient(cp, "PetDug", hub0) == 0, "pets idle outside the dig zone")
	-- unequipped pets don't dig
	for _, pet in d.Pets do
		pet.Equipped = false
	end
	DataService.MarkDirty(cp, "Pets")
	Mock.Advance(0.3)
	check(#PetDigService.GetDiggers(cp) == 0 and cp:GetAttribute("EquippedPets") == "", "unequipped pets stop digging")
	Mock.ServerTerrainRaycast = false
	Mock.RemovePlayer(cp)
	Mock.Advance(3)

	-- Save migration: data.Diggers -> vehicle pets (one per owned digger), then emptied
	local migrate = DataService._MigrateDiggersToPets
	local raw = {
		Version = 1,
		PetSlots = 3,
		Pets = { crab = { Id = "sandy_crab", Equipped = true } },
		Diggers = {
			toy_truck = { Level = 5, Equipped = true },
			dump_truck = { Level = 1, Equipped = true },
			mini_excavator = { Level = 3, Equipped = false },
			gone_digger = { Level = 1, Equipped = true },
		},
	}
	migrate(raw)
	local byId, equippedIds = {}, {}
	local count = 0
	for _, pet in raw.Pets do
		count += 1
		byId[pet.Id] = (byId[pet.Id] or 0) + 1
		if pet.Equipped then
			table.insert(equippedIds, pet.Id)
		end
	end
	check(count == 4 and byId.toy_truck == 1 and byId.dump_truck == 1 and byId.mini_excavator == 1, "one pet per owned digger")
	check(next(raw.Diggers) == nil, "data.Diggers emptied")
	check(#equippedIds == 3 and table.find(equippedIds, "dump_truck") and table.find(equippedIds, "toy_truck"), "equipped diggers stay equipped (slots allow)")
	local tight = {
		PetSlots = 2,
		Pets = { crab = { Id = "sandy_crab", Equipped = true } },
		Diggers = { toy_truck = { Level = 1, Equipped = true }, dump_truck = { Level = 1, Equipped = true } },
	}
	migrate(tight)
	local eq = {}
	for _, pet in tight.Pets do
		if pet.Equipped then
			eq[pet.Id] = true
		end
	end
	check(eq.dump_truck and not eq.toy_truck, "slot-limited migration equips the most valuable vehicle")
	if not STUDIO_NO_API then
		Mock.DataStores[Config.DATASTORE_NAME] = Mock.DataStores[Config.DATASTORE_NAME] or {}
		Mock.DataStores[Config.DATASTORE_NAME]["Player_3002"] = {
			Data = {
				Version = 1,
				Coins = 77,
				Pets = {},
				PetSlots = 3,
				Diggers = { bulldozer = { Level = 2, Equipped = true }, skid_steer = { Level = 1, Equipped = false } },
			},
			SavedAt = 0,
		}
		local old = Mock.AddPlayer(3002, "OldSave")
		Mock.Advance(2)
		local od = DataService.Get(old)
		local vehicles = {}
		if od then
			for _, pet in od.Pets do
				vehicles[pet.Id] = pet.Equipped
			end
		end
		check(od ~= nil and od.Coins == 77 and od.Version == Config.DATA_VERSION, "old v2 save loads at the new version")
		check(vehicles.bulldozer == true and vehicles.skid_steer == false, "old Garage diggers arrive as vehicle pets")
		check(od ~= nil and next(od.Diggers) == nil, "old save's Diggers emptied")
		Mock.RemovePlayer(old)
		Mock.Advance(3)
	end
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
	for i = 1, 30 do
		-- digger / pet / ride-on digs never heat their owner
		ServerSignals.Dug:Fire(sp, 1, 1, ({ "Digger", "Pet", "Ride" })[i % 3 + 1])
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

-- Ride-on excavator (Ride agent) -------------------------------------------------------------------
section("ride")
step("ride", function()
	local S = Config.SURFACE_Y
	local R = Config.Ride
	local zc = World.GetDigZone().CFrame.Position
	local Color3 = Mock.Env.Color3
	local rp = Mock.AddPlayer(4001, "RideTester")
	Mock.Advance(0.5)
	Mock.SpawnCharacter(rp)
	Mock.Advance(2)
	local d = DataService.Get(rp)
	local hum = rp.Character:FindFirstChildOfClass("Humanoid")
	local function vehicle()
		local f = workspace:FindFirstChild("Rides")
		return f and f:FindFirstChild("Ride_4001")
	end
	local function solid(x, y, z)
		local v = Mock.GetVoxel(Vector3.new(x, y, z))
		return v ~= nil and v.Occupancy > 0
	end
	local function rideDugSince(since)
		local list = {}
		for i = since + 1, #Mock.Remote.ToClient do
			local e = Mock.Remote.ToClient[i]
			if e.Name == "RideDug" and e.Player == rp and e.Args[1] == rp then
				table.insert(list, e.Args)
			end
		end
		return list
	end
	local function toggle()
		Mock.Advance(1) -- toggle debounce
		Mock.FireServer("ToggleRide", rp)
		Mock.Advance(0.5)
	end
	local x0 = 100
	rp.Character:PivotTo(CFrame.new(x0, S + 3, zc.Z))
	Mock.Advance(0.2)

	-- no rideable pet: nothing spawns
	toggle()
	check(vehicle() == nil, "ToggleRide without a rideable pet spawns nothing")

	-- a rideable pet ("mega_excavator" from Companions; a test def until it exists)
	local def
	for _, p in Config.Pets do
		if p.Rideable == true and p.Dig then
			def = p
			break
		end
	end
	local injected = false
	if not def then
		def = {
			Id = "test_ride_excavator",
			Name = "Test Excavator",
			Rarity = "Mythic",
			Multiplier = 1,
			Exclusive = true,
			VehicleKind = "Excavator",
			Rideable = true,
			Dig = { Power = 1e6, Interval = 0.8, Radius = 6, SandMultiplier = 50 },
			Look = {
				BodyColor = Color3.fromRGB(255, 190, 20),
				AccentColor = Color3.fromRGB(255, 90, 160),
				Shape = "Blob",
				Size = 1,
				Glow = false,
			},
		}
		table.insert(Config.Pets, def)
		injected = true
	end
	check(Config.FindRideablePet({ a = { Id = def.Id, Equipped = false } }) == def, "Config.FindRideablePet finds it")
	check(Config.FindRideablePet({ a = { Id = Config.Pets[1].Id, Equipped = true } }) == nil, "non-rideable pets don't count")
	d.Pets["ride_uid"] = { Id = def.Id, Equipped = false }

	-- too far from the beach (hub plaza): refused
	rp.Character:PivotTo(CFrame.new(x0, S + 3, 80))
	toggle()
	check(vehicle() == nil, "ToggleRide far from the beach spawns nothing")
	rp.Character:PivotTo(CFrame.new(x0, S + 3, zc.Z))
	Mock.Advance(0.2)

	-- spawn + seat
	toggle()
	local v = vehicle()
	if not check(v ~= nil, "ToggleRide with a rideable pet spawns the vehicle") then
		return
	end
	local seat = v:FindFirstChild("RideSeat")
	check(seat ~= nil and seat:IsA("Seat") and seat.Occupant == hum, "rider seated (Seat:Sit)")
	check(hum.SeatPart == seat, "Humanoid.SeatPart is the ride seat")
	check(v:GetAttribute("OwnerUserId") == 4001 and v:GetAttribute("PetId") == def.Id, "vehicle attributes")
	check(rp:GetAttribute("Riding") == def.Id, "Riding attribute set")
	local pivot = v:GetPivot()
	check(
		math.abs(pivot.Position.X - x0) < 1 and math.abs(pivot.Position.Z - zc.Z) < 1,
		"vehicle spawns where the player stands on the sand"
	)
	check(math.abs(pivot.Position.Y - (S + R.HoverHeight)) < 0.5, "vehicle sits on the surface (" .. pivot.Position.Y .. ")")
	local colliders, anchored, extent = {}, 0, v:GetExtentsSize()
	for _, part in v:GetDescendants() do
		if part:IsA("BasePart") then
			if part.CanCollide then
				table.insert(colliders, part.Name)
			end
			if part.Anchored then
				anchored += 1
			end
		end
	end
	check(#colliders == 1 and colliders[1] == "Chassis", "only the Chassis collides (" .. table.concat(colliders, ",") .. ")")
	check(anchored == 0, "vehicle is an unanchored assembly")
	check(seat.CanTouch == false, "seat never seats passers-by")
	check(math.max(extent.X, extent.Z) >= 10 and math.max(extent.X, extent.Z) <= 22, "full-size vehicle (" .. tostring(extent) .. ")")
	local ap = v.PrimaryPart:FindFirstChild("RideAlignPosition")
	local ao = v.PrimaryPart:FindFirstChild("RideAlignOrientation")
	check(ap ~= nil and ao ~= nil and ap.Attachment0 ~= nil, "AlignPosition / AlignOrientation drive constraints")
	for _, name in { "BoomMotor", "StickMotor", "BucketMotor" } do
		check(v:FindFirstChild(name, true) ~= nil, "arm joint " .. name)
	end
	check(#workspace.Rides:GetChildren() == 1, "one vehicle")

	-- RideDig: scoops in front of the vehicle, server-chosen point
	Mock.ServerTerrainRaycast = true
	d.Sand = 0
	local look = pivot.LookVector
	local since = #Mock.Remote.ToClient
	Mock.FireServer("RideDig", rp)
	Mock.Advance(0.3)
	local dug = rideDugSince(since)
	check(#dug == 1 and dug[1][3] == true, "RideDig digs (RideDug broadcast, success)")
	check(d.Sand > 0, "ride digs fill the backpack (" .. tostring(d.Sand) .. ")")
	if dug[1] then
		local p = dug[1][2]
		local rel = Vector3.new(p.X - pivot.Position.X, 0, p.Z - pivot.Position.Z)
		check(math.abs(rel.Magnitude - R.DigAhead) < 1.5 and rel.Unit:Dot(look) > 0.9, "dig point is in front of the vehicle")
		check(not solid(p.X, S - 2, p.Z) and not solid(p.X, S - 10, p.Z), "a big chunk is carved (12-stud cube)")
	end
	check(countToClient(rp, "DigResult", since) == 1, "ride dig sends a DigResult (+sand float text)")
	-- rate limit: Dig.Interval
	local s1 = #Mock.Remote.ToClient
	for _ = 1, 5 do
		Mock.FireServer("RideDig", rp)
	end
	Mock.Advance(0.1)
	check(#rideDugSince(s1) == 0, "RideDig is rate-limited to the pet's Dig.Interval")
	Mock.Advance(def.Dig.Interval)
	Mock.FireServer("RideDig", rp)
	Mock.Advance(0.2)
	check(#rideDugSince(s1) == 1, "RideDig works again after the interval")
	-- capacity
	local capacity = rp:GetAttribute("Capacity")
	d.Sand = capacity
	Mock.Advance(def.Dig.Interval)
	local s2 = #Mock.Remote.ToClient
	Mock.FireServer("RideDig", rp)
	Mock.Advance(0.2)
	local full = rideDugSince(s2)
	check(#full == 1 and full[1][3] == false and d.Sand == capacity, "full backpack: no sand, failed scoop")
	local fullNotes = 0
	for _, n in notifies(rp, s2) do
		if string.find(n, "Backpack full", 1, true) then
			fullNotes += 1
		end
	end
	check(fullNotes == 1, "gentle 'backpack full' notify (" .. table.concat(notifies(rp, s2), " / ") .. ")")
	d.Sand = 0

	-- anti-teleport: impossible speed / outside the area -> put back; repeated -> parked
	local good = v:GetPivot()
	v:PivotTo(good + Vector3.new(200, 0, 0))
	Mock.Advance(R.ValidateInterval + 0.1)
	check(vehicle() == v and (v:GetPivot().Position - good.Position).Magnitude < 2, "teleported vehicle is put back")
	Mock.Advance(R.ValidateInterval + 0.1) -- a valid sample clears the strikes
	v:PivotTo(CFrame.new(x0, S, 90))
	Mock.Advance(R.ValidateInterval + 0.1)
	check(vehicle() == v and v:GetPivot().Position.Z < 10, "vehicle outside the ride area is put back")
	Mock.Advance(R.ValidateInterval + 0.1)
	v:PivotTo(good + Vector3.new(0, -40, 0))
	Mock.Advance(R.ValidateInterval + 0.1)
	check(vehicle() == v and v:GetPivot().Position.Y > S - 2, "vehicle sunk into a hole is put back")
	for _ = 1, R.MaxStrikes do
		v:PivotTo(CFrame.new(x0, S, 90))
		Mock.Advance(R.ValidateInterval + 0.05)
	end
	check(vehicle() == nil, "repeated invalid positions despawn the vehicle")
	check(rp:GetAttribute("Riding") == nil, "Riding attribute cleared")
	Mock.FireServer("RideDig", rp)
	Mock.Advance(0.2)

	-- despawn paths: ToggleRide again, jump out, death, leave
	rp.Character:PivotTo(CFrame.new(x0, S + 3, zc.Z))
	toggle()
	check(vehicle() ~= nil, "respawned")
	toggle()
	check(vehicle() == nil, "ToggleRide again despawns")
	toggle()
	check(vehicle() ~= nil, "respawned")
	Mock.LeaveSeat(hum)
	Mock.Advance(0.2)
	check(vehicle() == nil, "jumping out despawns")
	toggle()
	check(vehicle() ~= nil, "respawned")
	Mock.FireEvent(hum, "Died")
	Mock.Advance(0.2)
	check(vehicle() == nil, "death despawns")
	toggle()
	check(vehicle() ~= nil, "respawned")
	Mock.ServerTerrainRaycast = false
	Mock.RemovePlayer(rp)
	Mock.Advance(1)
	check(vehicle() == nil, "leaving despawns")
	if injected then
		table.remove(Config.Pets, table.find(Config.Pets, def))
	end
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
