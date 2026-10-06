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
do
	-- playtest: fountain and towels sunk. Their raycast can miss terrain written in the same
	-- frame; the fallback must still sit on the visible surface (grid + 2), not the grid.
	local basin = Mock.Tagged("WaterFountain")[1]
	local bottom = basin and basin.Position.Y - basin.Size.X / 2 -- cylinder: height is Size.X
	check(bottom ~= nil and bottom >= Config.SURFACE_Y + 1.9, "fountain basin sits on the visible sand (" .. tostring(bottom) .. ")")
	local towels, sunk = 0, 0
	local decor = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Decor")
	for _, m in if decor then decor:GetChildren() else {} do
		if m:IsA("Model") and m.Name == "BeachTowel" then
			towels += 1
			local cf, size = m:GetBoundingBox()
			if cf.Position.Y - size.Y / 2 < Config.SURFACE_Y - 8 then
				sunk += 1 -- wet sand is on the slope; just catch "far below the beach"
			end
		end
	end
	check(towels > 0 and sunk == 0, "beach towels are placed (" .. towels .. ") and none are buried")
end
do
	-- playtest 2: spawn pads / boardwalk and the rebirth shrine steps were under the visible sand
	-- (smooth terrain shows the sand ~2 studs above the voxel grid at SURFACE_Y).
	local visible = Config.SURFACE_Y + 2
	local map = workspace:FindFirstChild("Map")
	local function lowest(root: Instance?, name: string): number
		local y = math.huge
		for _, d in if root then root:GetDescendants() else {} do
			if d:IsA("BasePart") and d.Name == name then
				y = math.min(y, d.Position.Y - d.Size.Y / 2)
			end
		end
		return y
	end
	local deckTop = -math.huge
	for _, d in if map then map:GetDescendants() else {} do
		if d:IsA("BasePart") and d.Name == "Deck" then
			deckTop = math.max(deckTop, d.Position.Y + d.Size.Y / 2)
		end
	end
	check(deckTop >= visible + 0.9, "boardwalk deck sits above the visible sand (" .. deckTop - visible .. ")")
	local pad = Mock.Tagged("SpawnLocation")[1]
	check(pad ~= nil and pad.Position.Y - pad.Size.Y / 2 >= deckTop - 0.01, "spawn pad stands on the deck")
	local step = lowest(map and map:FindFirstChild("RebirthShrine", true), "Step1")
	check(step >= visible - 0.1, "rebirth shrine steps sit on the visible sand (" .. step - visible .. ")")
	local sell = lowest(map and map:FindFirstChild("SellStand", true), "Counter")
	check(sell >= visible - 0.1, "sell counter sits on the visible sand (" .. sell - visible .. ")")
	local stallBottom = math.huge
	local decor = map and map:FindFirstChild("Decor")
	for _, m in if decor then decor:GetChildren() else {} do
		if m:IsA("Model") and (m.Name == "BoardwalkStall" or m.Name == "Boardwalk Stall") then
			local cf, size = m:GetBoundingBox()
			stallBottom = math.min(stallBottom, cf.Position.Y - size.Y / 2)
		end
	end
	check(math.abs(stallBottom - deckTop) < 0.05, "boardwalk stalls stand on the deck (" .. stallBottom - deckTop .. ")")
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
do
	-- v2.3: no egg is sold for Robux; the Golden Egg costs Rebirth Tokens and never prompts
	local robuxEggs = 0
	for _, e in Config.Eggs do
		robuxEggs += if e.Currency == "Robux" or e.ProductKey then 1 else 0
	end
	local golden = Config.GetEgg("golden_egg")
	check(robuxEggs == 0 and golden and golden.Currency == "Tokens", "v2.3: Golden Egg is earnable only (Rebirth Tokens)")
	local p0 = #Mock.Prompts
	local pets0 = 0
	for _ in data.Pets do
		pets0 += 1
	end
	Mock.FireServer("HatchEgg", player, "golden_egg", 1)
	Mock.Advance(0.5)
	local pets1 = 0
	for _ in data.Pets do
		pets1 += 1
	end
	check(#Mock.Prompts == p0 and (data.RebirthTokens >= golden.Price or pets1 == pets0), "Golden Egg without tokens: no prompt, no pet")
	for key, pass in Config.Monetization.GamePasses do
		check(pass.LuckMultiplier == nil, "v2.3: no pass sells luck: " .. key)
	end
	for _, key in { "GoldenEgg", "GoldenEgg3", "LuckBoost15" } do
		check(Config.Monetization.Products[key] == nil, "v2.3: product removed: " .. key)
	end
	check(Config.Monetization.GamePasses.Lucky == nil, "v2.3: Lucky pass removed")
	local StatsV23 = Mock.Require(byPath["ReplicatedStorage/Shared/Util/Stats"])
	local vipCtx = {
		Data = Config.NewPlayerData(),
		Passes = { VIP = true },
		IsPremium = false,
		InGroup = false,
		FriendsInServer = 0,
		ActiveEvents = {},
		Now = os.time(),
	}
	check(StatsV23.GetLuck(vipCtx) == 1, "v2.3: VIP gives no luck")
	check(math.abs(StatsV23.GetCoinMultiplier(vipCtx) - 1.1) < 1e-9, "v2.3: VIP gives +10% sell coins")
	vipCtx.Passes = { FastDig = true }
	check(math.abs(StatsV23.GetSpeedMultiplier(vipCtx) - 1.25) < 1e-9, "v2.3: Turbo Shovel +25% dig speed")
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
Config.Monetization.GamePasses.FastDig.Id = 7003
local p1 = #Mock.Prompts
Mock.FireServer("PromptPurchase", player, "GamePass", "FastDig")
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

-- Analytics (Onboarding & Analytics agent): funnel order / once-only, economy sinks, Track ------
section("analytics")
step("analytics", function()
	local Analytics = Mock.Require(byPath["ServerScriptService/Server/Services/Analytics"])
	local function events(kind, filter)
		local list = {}
		for _, e in Mock.Analytics do
			if e.Kind == kind and e.Player == player and (filter == nil or filter(e)) then
				table.insert(list, e)
			end
		end
		return list
	end

	-- Steps are numbered 1..N without gaps, in the documented order.
	local expected = {
		"Joined", "AtSand", "FirstDig", "BackpackFull", "FirstSell", "FirstShovel", "SecondShovel",
		"FirstBackpack", "Layer2", "FirstEgg", "FirstPet", "Layer3", "FirstShadeOrSnack",
		"FirstQuestClaim", "FirstCrate", "FirstPetDig", "Layer5", "FirstRebirth",
		"FirstFind", "FirstRareFind", "FirstPerfectExcavation",
	}
	local total = 0
	for _ in Analytics.Steps do
		total += 1
	end
	check(total == #expected and Analytics.StepCount == #expected, "funnel has " .. #expected .. " steps")
	for i, name in expected do
		check(Analytics.Steps[name] == i, "funnel step " .. i .. " is " .. name)
	end

	-- Every step this session's player reached was logged exactly once, with its own name.
	local funnel = events("Funnel")
	local seen, dupes = {}, 0
	for _, e in funnel do
		if seen[e.Step] then
			dupes += 1
		end
		seen[e.Step] = true
		check(expected[e.Step] == e.Name, "funnel step " .. e.Step .. " logged as " .. tostring(e.Name))
		check(data.Settings["FTUE_" .. e.Name] == true, "FTUE_" .. tostring(e.Name) .. " flag persisted")
	end
	check(dupes == 0, "no funnel step logged twice (" .. dupes .. ")")
	for _, name in { "Joined", "AtSand", "FirstDig", "FirstSell", "FirstShovel", "FirstBackpack", "FirstEgg", "FirstPet", "FirstRebirth" } do
		check(seen[Analytics.Steps[name]] == true, "funnel step reached: " .. name)
	end
	-- the core FTUE steps arrive in increasing order
	local lastIndex = 0
	for _, name in { "Joined", "FirstDig", "FirstSell", "FirstShovel", "FirstEgg", "FirstRebirth" } do
		local at
		for i, e in funnel do
			if e.Name == name then
				at = i
			end
		end
		check(at ~= nil and at > lastIndex, "funnel order: " .. name .. " after the previous core step")
		lastIndex = at or lastIndex
	end
	-- once per player ever: repeats are ignored
	local n0 = #events("Funnel")
	Analytics.Funnel(player, Analytics.Steps.FirstDig)
	Analytics.Funnel(player, Analytics.Steps.FirstSell)
	Mock.FireServer("SetSetting", player, "FTUE_FirstDig", false)
	Mock.Advance(0.2)
	check(#events("Funnel") == n0, "funnel steps are logged once only")
	check(data.Settings.FTUE_FirstDig == true, "FTUE_ flags not client-writable")
	-- server FTUE_ flags don't eat the client's 40-key settings budget
	for i = 1, 30 do
		data.Settings["FTUE_Pad" .. i] = true
	end
	Mock.FireServer("SetSetting", player, "MenuSeen", "Shop,Eggs")
	Mock.Advance(0.2)
	check(data.Settings.MenuSeen == "Shop,Eggs", "client keys still writable next to many FTUE_ flags")
	for i = 1, 30 do
		data.Settings["FTUE_Pad" .. i] = nil
	end
	Analytics.Funnel(player, 999)
	check(#events("Funnel") == n0, "unknown funnel step ignored")

	-- Economy: sources and sinks with consistent "<Kind>:<id>" SKUs
	local function economy(flow, prefix)
		return #events("Economy", function(e)
			return e.Flow == flow and type(e.Sku) == "string" and string.sub(e.Sku, 1, #prefix) == prefix
		end)
	end
	check(economy("Source", "Sell:") >= 1, "economy source: Sell:<where>")
	check(economy("Sink", "Shovel:" .. second.Id) == 1, "economy sink: Shovel:<id>")
	check(economy("Sink", "Backpack:" .. Config.Backpacks[2].Id) == 1, "economy sink: Backpack:<id>")
	check(economy("Sink", "Egg:" .. egg.Id) >= 1, "economy sink: Egg:<id>")
	check(economy("Sink", "Rebirth") == 1, "economy sink: Rebirth")
	check(economy("Source", "Rebirth") == 1, "economy source: Rebirth tokens")
	for _, e in events("Economy") do
		check(e.Amount > 0 and e.Ending >= 0, "economy amounts positive (" .. tostring(e.Sku) .. ")")
	end

	-- Progression: rebirths and layers
	check(#events("Progression", function(e)
		return e.Path == "Rebirth" and e.Status == "Complete" and e.Level == 1
	end) == 1, "progression: Rebirth 1 complete")
	local ServerSignals = Mock.Require(byPath["ServerScriptService/Server/Services/ServerSignals"])
	local layers0 = #events("Progression", function(e)
		return e.Path == "Layers"
	end)
	ServerSignals.DepthReached:Fire(player, Config.Layers[3].DepthStart + 1)
	Mock.Advance(0.1)
	ServerSignals.DepthReached:Fire(player, Config.Layers[3].DepthStart + 2) -- same layer: nothing new
	Mock.Advance(0.1)
	local layerEvents = events("Progression", function(e)
		return e.Path == "Layers"
	end)
	check(#layerEvents - layers0 == 4, "progression: layers 1-2 complete, 2-3 start (" .. (#layerEvents - layers0) .. ")")
	local lastLayerEvent = layerEvents[#layerEvents]
	check(lastLayerEvent and lastLayerEvent.Status == "Start" and lastLayerEvent.Level == 3 and lastLayerEvent.Name == Config.Layers[3].Name, "progression: Start layer 3 with its name")
	check(lastLayerEvent and lastLayerEvent.Fields.CustomField01 == "1", "progression: layer events carry the rebirth count")
	check(data.Settings.FTUE_Layer2 == true and data.Settings.FTUE_Layer3 == true, "funnel: Layer2 + Layer3 reached")

	-- Custom events: hatch (egg id + rarity + pet id)
	local hatches = events("FunnelStep", function(e)
		return e.Funnel == "Hatch"
	end)
	check(#hatches >= 1, "custom event Hatch logged")
	local h = hatches[1]
	check(h and h.Fields.CustomField01 == egg.Id and Config.GetRarity(h.Fields.CustomField02) ~= nil, "Hatch fields: egg id + rarity")

	-- Track remote: whitelist + argument validation
	local function custom(name)
		return #events("FunnelStep", function(e)
			return e.Funnel == name
		end)
	end
	Mock.Advance(6) -- fresh rate-limit window
	local opened0, shop0 = custom("PanelOpened"), custom("Shop")
	Mock.FireServer("Track", player, "panel_opened", "Store")
	Mock.Advance(0.2)
	check(custom("PanelOpened") == opened0 + 1, "Track panel_opened logged")
	check(custom("Shop") == shop0 + 1, "opening a selling panel starts a Shop funnel session")
	local passKey = next(Config.Monetization.GamePasses)
	Mock.FireServer("Track", player, "purchase_prompted", "GamePass", passKey)
	Mock.Advance(0.2)
	local shopSteps = events("FunnelStep", function(e)
		return e.Funnel == "Shop"
	end)
	local last = shopSteps[#shopSteps]
	check(last and last.Step == 2 and last.Fields.CustomField02 == "Pass:" .. passKey, "Track purchase_prompted -> Shop step 2")
	check(last and last.Session == shopSteps[#shopSteps - 1].Session, "prompt continues the open Shop session")
	Mock.Advance(6)
	local before = #Mock.Analytics
	for _, bad in {
		{ "panel_opened", "NotAPanel" },
		{ "panel_opened", 5 },
		{ "panel_opened", string.rep("x", 500) },
		{ "purchase_prompted", "GamePass", "NoSuchPass" },
		{ "purchase_prompted", "Robux", passKey },
		{ "menu_unlocked", "Garage" },
		{ "give_me_coins", "Shop" },
		{ 42 },
		{},
	} do
		check(Analytics.OnTrack(player, table.unpack(bad)) == false, "Track rejects " .. tostring(bad[1]) .. "/" .. tostring(bad[2]))
		Mock.FireServer("Track", player, table.unpack(bad))
	end
	Mock.Advance(0.2)
	check(#Mock.Analytics == before, "rejected Track calls log nothing")
	-- rate limit
	Mock.Advance(6)
	local o0 = custom("PanelOpened")
	for _ = 1, 30 do
		Mock.FireServer("Track", player, "panel_opened", "Pets")
	end
	Mock.Advance(0.2)
	local accepted = custom("PanelOpened") - o0
	check(accepted >= 1 and accepted <= Analytics.TRACK_RATE, "Track is rate limited (" .. accepted .. " of 30)")
	Mock.FireServer("Track", player, "menu_unlocked", "Eggs")
	Mock.Advance(6)
	Mock.FireServer("Track", player, "menu_unlocked", "Eggs")
	Mock.Advance(0.2)
	check(custom("MenuUnlocked") >= 1, "Track menu_unlocked logged")

	-- Sunburnt / ride start are picked up from player attributes
	local sun0 = custom("Sunburnt")
	player:SetAttribute("Sunburnt", true)
	Mock.Advance(0.1)
	player:SetAttribute("Sunburnt", false)
	Mock.Advance(0.1)
	check(custom("Sunburnt") == sun0 + 1, "custom event Sunburnt")
	local ride0 = custom("RideStarted")
	player:SetAttribute("Riding", "mega_excavator")
	Mock.Advance(0.1)
	player:SetAttribute("Riding", nil)
	Mock.Advance(0.1)
	check(custom("RideStarted") == ride0 + 1, "custom event RideStarted")
end)

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

	-- v2.2: the Cooler Pack product was removed (paid relief from heat friction we designed)
	check(Config.Monetization.Products.CoolerPack == nil, "no Cooler Pack product")

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
	d.Sand = 0
	local s1 = #Mock.Remote.ToClient
	for _ = 1, 5 do
		Mock.FireServer("RideDig", rp)
	end
	Mock.Advance(0.1)
	check(#rideDugSince(s1) == 0, "RideDig is rate-limited to the pet's Dig.Interval")
	Mock.Advance(def.Dig.Interval)
	Mock.FireServer("RideDig", rp)
	Mock.Advance(0.2)
	check(#rideDugSince(s1) == 1 and rideDugSince(s1)[1][3] == true, "RideDig works again after the interval")
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
	-- v2.3: wait for each validation tick instead of a fixed advance; a fixed
	-- ValidateInterval + 0.05 can hold two ticks depending on the clock phase, and the second one
	-- sees the put-back (valid) position and resets the strikes.
	local invalid = CFrame.new(x0, S, 90)
	for _ = 1, R.MaxStrikes do
		v:PivotTo(invalid)
		local waited = 0
		while vehicle() == v and (v:GetPivot().Position - invalid.Position).Magnitude < 1 and waited < R.ValidateInterval * 3 do
			Mock.Advance(0.02)
			waited += 0.02
		end
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

section("hatching + compliance")
step("hatching + compliance", function()
	local Stats = Mock.Require(byPath["ReplicatedStorage/Shared/Util/Stats"])
	local Format = Mock.Require(byPath["ReplicatedStorage/Shared/Util/Format"])
	local PetService = Mock.Require(byPath["ServerScriptService/Server/Services/PetService"])
	local PetDigService = Mock.Require(byPath["ServerScriptService/Server/Services/PetDigService"])
	local MultiplierService = Mock.Require(byPath["ServerScriptService/Server/Services/MultiplierService"])
	local PolicyService = Mock.Require(byPath["ServerScriptService/Server/Services/PolicyService"])
	local marketplace = Mock.Service("MarketplaceService")

	-- A1: the one odds function ----------------------------------------------------------------
	for _, e in Config.Eggs do
		for _, luck in { 1, 2.5, 0 / 0, -3 } do
			for _, pity in { 0, e.PityAt or 0 } do
				local list = Stats.GetHatchOddsList(e, luck, pity)
				local sum = 0
				for _, odd in list do
					sum += odd.Chance
				end
				check(math.abs(sum - 1) < 1e-9, "odds of " .. e.Id .. " sum to 1 (luck " .. tostring(luck) .. ", pity " .. pity .. ")")
			end
		end
	end
	local beach = Config.GetEgg("beach_egg")
	local base = Stats.GetHatchOdds(beach, 1, 0)
	check(math.abs(base.golden_crab - 0.001) < 1e-12 and math.abs(base.sandy_crab - 0.6) < 1e-12, "base odds = weights / total")
	local lucky = Stats.GetHatchOdds(beach, 2.5, 0)
	-- luck multiplies every non-Common weight: total = 60 + 28 + (10 + 1.9 + 0.1) * 2.5 = 118
	check(math.abs(lucky.golden_crab - 0.25 / 118) < 1e-12, "luck x2.5 -> golden_crab " .. lucky.golden_crab)
	check(math.abs(lucky.sandy_crab - 60 / 118) < 1e-12, "luck lowers Common odds")
	local pityOdds, pityActive = Stats.GetHatchOdds(beach, 1, beach.PityAt)
	check(pityActive and pityOdds.sandy_crab == 0 and pityOdds.starfish == 0, "pity: no Common / Uncommon on the guaranteed hatch")
	check(math.abs(pityOdds.baby_turtle - 0.95) < 1e-12 and math.abs(pityOdds.golden_crab - 0.05) < 1e-12, "pity: Rare+ by relative weights")
	check(not select(2, Stats.GetHatchOdds(beach, 1, beach.PityAt - 1)), "pity not active one hatch early")
	check(Stats.HatchesUntilPity(beach, 0) == beach.PityAt + 1 and Stats.HatchesUntilPity(beach, beach.PityAt) == 1, "HatchesUntilPity")
	check(Stats.HatchesUntilPity(Config.GetEgg("golden_egg"), 0) == nil, "all-Rare+ eggs have no pity")
	check(Format.Chance(0.005) == "0.5%" and Format.Chance(0.0005) == "0.05%" and Format.Chance(0.6) == "60%", "Format.Chance precision")

	-- statistical: the server's real roll matches the displayed odds (large N)
	local function distribution(egg, luck, pity, n)
		local counts = {}
		for _ = 1, n do
			local id = PetService._Roll(egg, luck, pity)
			counts[id] = (counts[id] or 0) + 1
		end
		local odds = Stats.GetHatchOdds(egg, luck, pity)
		local worst = 0
		for petId, p in odds do
			local f = (counts[petId] or 0) / n
			local sigma = math.sqrt(math.max(p * (1 - p), 1e-12) / n)
			worst = math.max(worst, math.abs(f - p) / (sigma + 1e-9))
			if p == 0 and (counts[petId] or 0) > 0 then
				worst = math.huge
			end
		end
		return worst
	end
	local N = 200000
	local z1 = distribution(beach, 2.5, 0, N)
	check(z1 < 5, string.format("server roll matches displayed odds with luck (worst %.2f sigma, N=%d)", z1, N))
	local tide = Config.GetEgg("tidepool_egg")
	local z2 = distribution(tide, 1.5, tide.PityAt, 50000)
	check(z2 < 5, string.format("server roll matches displayed PITY odds (worst %.2f sigma)", z2))
	local core = Config.GetEgg("core_crate")
	local z3 = distribution(core, 4, 0, 100000)
	check(z3 < 5, string.format("crate roll matches displayed odds (worst %.2f sigma)", z3))

	-- real hatch path: pity triggers, resets, counts; EggHatched carries the true chances ------
	local hp = Mock.AddPlayer(5101, "Hatcher")
	Mock.Advance(1)
	local hd = DataService.Get(hp)
	hd.Coins = 1e9
	hd.Boosts.LuckBoost = os.time() + 600
	DataService.MarkDirty(hp, "Boosts")
	Mock.Advance(1.2)
	local ctx = MultiplierService.GetContext(hp)
	local luck = Stats.GetLuck(ctx)
	check(luck == 2 and hp:GetAttribute("Luck") == 2, "LuckBoost: server luck x2 (attribute " .. tostring(hp:GetAttribute("Luck")) .. ")")
	hd.Pity[beach.Id] = beach.PityAt
	local before = #Mock.Remote.ToClient
	Mock.FireServer("HatchEgg", hp, beach.Id, 1)
	Mock.Advance(0.5)
	local args = lastToClient(hp, "EggHatched")
	local petId = args and args[1][1]
	local info = args and args[2]
	check(petId ~= nil and Stats.IsPityRarity(petId), "pity hatch is Rare+ (" .. tostring(petId) .. ")")
	check(hd.Pity[beach.Id] == 0, "pity counter reset by a Rare+ hatch")
	check(type(info) == "table" and info.EggId == beach.Id and info.Pity[1] == true, "EggHatched info: egg + pity flag")
	local shown = Stats.GetHatchOdds(beach, luck, beach.PityAt)
	check(info and math.abs(info.Chances[1] - shown[petId]) < 1e-12, "EggHatched chance == displayed odds with modifiers")
	check(countToClient(hp, "EggHatched", before) == 1, "one EggHatched")
	-- the counter moves exactly like Stats.NextPityCount
	for _ = 1, 3 do
		local c0 = hd.Pity[beach.Id] or 0
		Mock.FireServer("HatchEgg", hp, beach.Id, 1)
		Mock.Advance(0.4)
		local a = lastToClient(hp, "EggHatched")
		check(hd.Pity[beach.Id] == Stats.NextPityCount(beach, c0, a[1][1]), "pity counter follows the hatch result")
	end
	local golden = Config.GetEgg("golden_egg")
	PetService.HatchFree(hp, golden.Id, 1)
	check(hd.Pity[golden.Id] == nil, "eggs without PityAt keep no counter")

	-- B9 fusion --------------------------------------------------------------------------------
	for uidKey in hd.Pets do
		hd.Pets[uidKey] = nil
	end
	local crabUids = {}
	for i = 1, 5 do
		table.insert(crabUids, PetService.GrantPet(hp, "sandy_crab", i == 3))
	end
	local other = PetService.GrantPet(hp, "seagull", false)
	Mock.Advance(0.3)
	local function countPets(id, isGolden)
		local n = 0
		for _, pet in hd.Pets do
			if pet.Id == id and (pet.Golden == true) == isGolden then
				n += 1
			end
		end
		return n
	end
	-- not enough copies
	local spare = crabUids[5]
	hd.Pets[spare] = nil
	Mock.FireServer("FusePets", hp, crabUids[1])
	Mock.Advance(0.3)
	check(countPets("sandy_crab", false) == 4 and countPets("sandy_crab", true) == 0, "fusion refused with 4 copies")
	hd.Pets[spare] = { Id = "sandy_crab", Equipped = false }
	Mock.FireServer("FusePets", hp, "nonsense")
	Mock.FireServer("FusePets", hp, 42)
	Mock.FireServer("FusePets", hp, crabUids[1])
	Mock.Advance(0.4)
	check(countPets("sandy_crab", false) == 0 and countPets("sandy_crab", true) == 1, "Fuse 5 -> 1 Golden")
	check(hd.Pets[other] ~= nil, "other pets untouched by fusion")
	local goldenUid
	for u, pet in hd.Pets do
		if pet.Golden then
			goldenUid = u
		end
	end
	check(goldenUid and hd.Pets[goldenUid].Equipped == true, "Golden pet stays equipped (a fused copy was)")
	check(hp:GetAttribute("EquippedPets") == "sandy_crab" and hp:GetAttribute("EquippedGolden") == "1", "EquippedGolden attribute marks the golden slot")
	local crabDef = Config.GetPet("sandy_crab")
	local expected = 1 + (crabDef.Multiplier - 1) * Config.GOLDEN_SAND_BONUS
	check(math.abs(Stats.GetPetMultiplier(MultiplierService.GetContext(hp)) - expected) < 1e-9, "Golden pet: sand bonus x1.5")
	Mock.FireServer("FusePets", hp, goldenUid)
	Mock.Advance(0.4)
	check(hd.Pets[goldenUid] ~= nil and countPets("sandy_crab", true) == 1, "Golden pets can't be fused again")
	-- golden digging pet digs faster
	local truck = PetService.GrantPet(hp, "toy_truck", true)
	hd.Pets[truck].Golden = true
	DataService.MarkDirty(hp, "Pets")
	Mock.Advance(0.3)
	local diggers = PetDigService.GetDiggers(hp)
	local found = false
	for _, dg in diggers do
		if dg.Id == "toy_truck" and dg.Golden == true then
			found = true
		end
	end
	check(found, "PetDigService sees the Golden digging pet")
	local dig = Config.GetPetDig("toy_truck")
	check(math.abs(Config.GetPetDigInterval("toy_truck", true) - dig.Interval / 1.25) < 1e-9, "Golden digger: interval / 1.25")
	check(hp:GetAttribute("EquippedGolden") == "1,2", "golden slots follow Stats.SortEquipped (" .. tostring(hp:GetAttribute("EquippedGolden")) .. ")")

	-- A2 PolicyService ---------------------------------------------------------------------------
	check(hp:GetAttribute("PaidRandomRestricted") == false and hp:GetAttribute("PolicyLoaded") == true, "unrestricted policy published")
	Mock.Policy[5102] = { ArePaidRandomItemsRestricted = true, IsPaidItemTradingAllowed = false }
	local rp = Mock.AddPlayer(5102, "Restricted")
	Mock.Advance(1)
	check(rp:GetAttribute("PaidRandomRestricted") == true and PolicyService.IsPaidRandomRestricted(rp), "restricted policy published")
	local rd = DataService.Get(rp)
	Config.Monetization.Products.CoinsSmall.Id = 9001
	Config.Monetization.Products.SkipRebirth.Id = 9501
	Config.Monetization.Products.SandBoost15.Id = 9503
	Config.Monetization.GamePasses.FastDig.Id = 7003
	Config.Monetization.GamePasses.DoubleSand.Id = 7004
	local function promptsFor(p, since)
		local n = 0
		for i = since + 1, #Mock.Prompts do
			if Mock.Prompts[i].Player == p then
				n += 1
			end
		end
		return n
	end
	local p0 = #Mock.Prompts
	for _, key in { "CoinsSmall", "SkipRebirth" } do
		Mock.FireServer("PromptPurchase", rp, "Product", key)
		Mock.Advance(0.7)
	end
	Mock.FireServer("HatchEgg", rp, golden.Id, 1)
	Mock.Advance(0.7)
	check(promptsFor(rp, p0) == 0, "restricted: no prompt for coin packs / skip rebirth / golden egg")
	Mock.FireServer("PromptPurchase", rp, "Product", "SandBoost15")
	Mock.Advance(0.7)
	Mock.FireServer("PromptPurchase", rp, "GamePass", "DoubleSand")
	Mock.Advance(0.7)
	Mock.FireServer("PromptPurchase", rp, "GamePass", "FastDig")
	Mock.Advance(0.7)
	check(promptsFor(rp, p0) == 3, "restricted: non-random items (incl. Turbo Shovel) still prompt")
	local p1 = #Mock.Prompts
	Mock.FireServer("PromptPurchase", hp, "Product", "CoinsSmall")
	Mock.Advance(0.7)
	Mock.FireServer("PromptPurchase", hp, "GamePass", "FastDig")
	Mock.Advance(0.7)
	check(promptsFor(hp, p1) == 2, "unrestricted: coins + Turbo Shovel prompt")
	-- a purchase that already completed is honoured even for a restricted player
	local coins0 = rd.Coins
	local decision
	Mock.Env.task.spawn(function()
		decision = marketplace.ProcessReceipt({ PlayerId = 5102, ProductId = 9001, PurchaseId = "policy-1" })
	end)
	Mock.Advance(1)
	check(decision == Enum.ProductPurchaseDecision.PurchaseGranted and rd.Coins > coins0, "restricted: completed purchase still granted")
	Config.Monetization.Products.SkipRebirth.Id = 0
	Config.Monetization.Products.SandBoost15.Id = 0
	Config.Monetization.GamePasses.DoubleSand.Id = 0
	-- lookup failure: retries, then restricted-safe live / unrestricted in Studio
	Mock.PolicyFail = true
	local calls0 = Mock.PolicyCalls
	local fp = Mock.AddPlayer(5103, "PolicyDown")
	Mock.Advance(0.2)
	check(fp:GetAttribute("PaidRandomRestricted") == not STUDIO_NO_API, "pending lookup: safe default published at once")
	Mock.Advance(5)
	check(Mock.PolicyCalls - calls0 == 3, "policy lookup retried 3 times (" .. (Mock.PolicyCalls - calls0) .. ")")
	check(fp:GetAttribute("PolicyLoaded") == false, "PolicyLoaded false after failure")
	if STUDIO_NO_API then
		check(fp:GetAttribute("PaidRandomRestricted") == false, "Studio: failed lookup -> not restricted")
	else
		check(fp:GetAttribute("PaidRandomRestricted") == true, "live: failed lookup -> restricted (safe)")
	end
	Mock.PolicyFail = false
	Mock.Advance(61)
	if not STUDIO_NO_API then
		check(fp:GetAttribute("PaidRandomRestricted") == false and fp:GetAttribute("PolicyLoaded") == true, "live: late retry recovers")
	end
	Mock.Policy[5102] = nil
	for _, p in { hp, rp, fp } do
		Mock.RemovePlayer(p)
	end
	Mock.Advance(1)
end)

-- Status & Social (v2.2): nameplate attributes + titles, worn backpack weld, weekly / server
-- leaderboard scopes, server dig goal -> early Golden Hour ---------------------------------------
section("status & social")
step("status & social", function()
	local Week = Mock.Require(byPath["ReplicatedStorage/Shared/Util/Week"])
	local LeaderboardService = Mock.Require(byPath["ServerScriptService/Server/Services/LeaderboardService"])
	local ServerGoalService = Mock.Require(byPath["ServerScriptService/Server/Services/ServerGoalService"])
	local EventService = Mock.Require(byPath["ServerScriptService/Server/Services/EventService"])
	local StatusService = Mock.Require(byPath["ServerScriptService/Server/Services/StatusService"])
	local ServerSignals = Mock.Require(byPath["ServerScriptService/Server/Services/ServerSignals"])
	local e0 = #Mock.Errors

	-- titles: one per layer, unique, first / last as designed
	check(#Config.Titles == #Config.Layers, "one title per layer")
	local seenTitles = {}
	for i = 1, #Config.Layers do
		local title, color = Config.GetTitle(i)
		check(type(title) == "string" and title ~= "" and not seenTitles[title], "title " .. i .. " unique: " .. tostring(title))
		check(Mock.Env.typeof(color) == "Color3", "title " .. i .. " has a colour")
		seenTitles[title] = true
	end
	check(Config.GetTitle(1) == "Sandcastle Rookie" and Config.GetTitle(#Config.Layers) == "Core Breaker", "rookie .. core breaker")
	check(Config.GetTitle(0) == "Sandcastle Rookie" and Config.GetTitle(99) == "Core Breaker", "GetTitle clamps")

	-- ISO week keys (weekly leaderboards)
	local function utc(y, m, d)
		return Mock.Env.os.time({ year = y, month = m, day = d, hour = 12 })
	end
	check(Week.Key(utc(2026, 10, 6)) == "W2026_41", "2026-10-06 is ISO week 41 (" .. Week.Key(utc(2026, 10, 6)) .. ")")
	check(Week.Key(utc(2021, 1, 3)) == "W2020_53", "2021-01-03 belongs to 2020-W53")
	check(Week.Key(utc(2024, 12, 30)) == "W2025_01", "2024-12-30 belongs to 2025-W01")
	check(Week.Key(utc(2026, 1, 5)) == "W2026_02", "2026-01-05 (Monday) starts W02")
	local left = Week.SecondsLeft(utc(2026, 10, 6))
	check(left > 0 and left <= 7 * 86400, "seconds until the weekly reset")
	check(
		LeaderboardService.WeeklyStoreName("Depth", utc(2026, 10, 6)) == "Leaderboard_Depth_W2026_41"
			and LeaderboardService.WeeklyStoreName("Coins", utc(2026, 10, 6)) == "Leaderboard_Sand_W2026_41",
		"weekly store names keyed by ISO week"
	)

	-- a fresh player: attributes + worn backpack (torso arrives after CharacterAdded)
	local sp = Mock.AddPlayer(39001, "Shower")
	Mock.Advance(0.5)
	local character = Mock.SpawnCharacter(sp, Vector3.new(30, Config.SURFACE_Y + 3, 4))
	Mock.Advance(2)
	local sd = DataService.Get(sp)
	check(sd ~= nil, "status player loaded")
	check(sp:GetAttribute("TitleLayer") == 1, "new player: title layer 1 (" .. tostring(sp:GetAttribute("TitleLayer")) .. ", MaxDepth " .. tostring(sd and sd.MaxDepth) .. ")")
	check(sp:GetAttribute("RebirthCount") == 0, "new player: 0 rebirth stars")
	check(sp:GetAttribute("BackpackFill") == 0, "empty backpack fill 0")
	check(character:FindFirstChild("WornBackpack") == nil, "no worn pack before the torso exists")
	local rig = Mock.MakeR15(character)
	Mock.Advance(0.5)
	local function checkPack(char, id, label)
		local pack = char:FindFirstChild("WornBackpack")
		if not check(pack ~= nil, label .. ": backpack worn") then
			return nil
		end
		check(pack:GetAttribute("BackpackId") == id, label .. ": the equipped backpack (" .. tostring(pack:GetAttribute("BackpackId")) .. ")")
		local weld = pack.PrimaryPart and pack.PrimaryPart:FindFirstChild("BackpackWeld")
		local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
		check(weld ~= nil and weld.Part0 == torso and weld.Part1 == pack.PrimaryPart, label .. ": welded to the torso")
		check(weld ~= nil and math.abs(weld.C0.Position.Z - torso.Size.Z / 2) < 1e-6, label .. ": on the torso's back face (" .. tostring(weld and weld.C0.Position) .. " / " .. tostring(torso.Size) .. ")")
		local bad = 0
		for _, d in pack:GetDescendants() do
			if d:IsA("BasePart") and (d.Anchored or d.CanCollide or d.CanQuery or d.CanTouch or not d.Massless) then
				bad += 1
			end
		end
		check(bad == 0, label .. ": every part unanchored, massless, no collide/query/touch (" .. bad .. " bad)")
		return pack
	end
	checkPack(character, sd.Backpack, "spawn")
	local _ = rig

	-- progress shows up in the attributes
	DataService.Set(sp, "MaxDepth", Config.Layers[5].DepthStart + 1)
	DataService.Set(sp, "Rebirths", 7)
	Mock.Advance(0.5)
	check(sp:GetAttribute("TitleLayer") == 5, "title follows MaxDepth (layer 5)")
	check(sp:GetAttribute("RebirthCount") == 7, "rebirth stars follow Rebirths")
	local cap = sp:GetAttribute("Capacity")
	DataService.Set(sp, "Sand", math.floor((cap or 20) / 2))
	Mock.Advance(0.5)
	local fill = sp:GetAttribute("BackpackFill")
	check(type(fill) == "number" and fill >= 0.4 and fill <= 0.6, "half-full backpack fill ~0.5 (" .. tostring(fill) .. ")")

	-- equip another backpack -> re-welded; respawn -> worn again
	local otherPack = Config.Backpacks[2].Id
	DataService.Mutate(sp, { "OwnedBackpacks" }, function(d)
		d.OwnedBackpacks[otherPack] = true
	end)
	Mock.FireServer("EquipBackpack", sp, otherPack)
	Mock.Advance(0.5)
	checkPack(character, otherPack, "equip")
	local count = 0
	for _, c in character:GetChildren() do
		if c.Name == "WornBackpack" then
			count += 1
		end
	end
	check(count == 1, "only one worn pack after re-equip")
	local character2 = Mock.SpawnCharacter(sp, Vector3.new(30, Config.SURFACE_Y + 3, 4))
	Mock.MakeR15(character2)
	Mock.Advance(0.5)
	checkPack(character2, otherPack, "respawn")
	check(StatusService.AttachBackpack(sp) == character2:FindFirstChild("WornBackpack"), "AttachBackpack keeps an up-to-date pack")

	-- leaderboards: weekly + server counters from digs, weekly stores keyed by ISO week
	ServerSignals.Dug:Fire(sp, 37, 120, "Shovel")
	ServerSignals.Dug:Fire(sp, 12, 30, "Pet")
	local session = LeaderboardService.GetSession(sp)
	check(session ~= nil and session.WeekSand == 150 and session.SessionSand == 150, "weekly + session sand counted")
	check(session ~= nil and session.WeekDepth == 37 and session.SessionDepth == 37, "deepest dig this week / session")
	local serverRows = LeaderboardService.GetEntries("LeaderboardCoins", "Server")
	local mine = nil
	for _, row in serverRows do
		if row.UserId == 39001 then
			mine = row
		end
	end
	check(mine ~= nil and mine.Value == 150, "THIS SERVER scope is live from memory")
	Mock.Env.task.spawn(LeaderboardService.Refresh)
	Mock.Advance(3)
	local weekKey = Week.Key(Mock.Env.os.time())
	local sandStore = Mock.DataStores["ordered:Leaderboard_Sand_" .. weekKey]
	local depthStore = Mock.DataStores["ordered:Leaderboard_Depth_" .. weekKey]
	if STUDIO_NO_API then
		check(sandStore == nil or sandStore["39001"] == nil, "Studio without DataStores: no weekly writes")
		local weekRows = LeaderboardService.GetEntries("LeaderboardDepth", "Week")
		local found = false
		for _, row in weekRows do
			found = found or (row.UserId == 39001 and row.Value == 37)
		end
		check(found, "Studio: THIS WEEK falls back to this server")
	else
		check(sandStore ~= nil and sandStore["39001"] == 150, "weekly sand written to Leaderboard_Sand_" .. weekKey)
		check(depthStore ~= nil and depthStore["39001"] == 37, "weekly depth written to Leaderboard_Depth_" .. weekKey)
		-- more digs: sand increments by the delta, depth keeps the best
		ServerSignals.Dug:Fire(sp, 20, 50, "Shovel")
		Mock.Env.task.spawn(LeaderboardService.Refresh)
		Mock.Advance(3)
		check(sandStore["39001"] == 200, "weekly sand adds only the new delta (" .. tostring(sandStore["39001"]) .. ")")
		check(depthStore["39001"] == 37, "weekly depth keeps the best dig")
		local weekRows = LeaderboardService.GetEntries("LeaderboardDepth", "Week")
		check(#weekRows > 0 and weekRows[1].Value >= 37, "THIS WEEK read back from the weekly store")
		-- request budget exhausted: no writes this round
		Mock.DataStoreBudget = 0
		ServerSignals.Dug:Fire(sp, 20, 5, "Shovel")
		Mock.Env.task.spawn(LeaderboardService.Refresh)
		Mock.Advance(3)
		check(sandStore["39001"] == 200, "no writes without request budget")
		Mock.DataStoreBudget = nil
	end

	-- scope cycling: both boards flip ALL TIME -> THIS WEEK -> THIS SERVER, header shows it
	local boardPart = Mock.Tagged("LeaderboardDepth")[1]
	local function scopeShown()
		local gui = boardPart:FindFirstChild("LeaderboardGui")
		local bar = gui and gui:FindFirstChild("Scope", true)
		return bar and bar:GetAttribute("Scope"), bar and bar:FindFirstChild("Text") and bar.Text.Text
	end
	LeaderboardService.SetScope("AllTime")
	local s1, t1 = scopeShown()
	check(s1 == "AllTime" and string.find(t1 or "", "ALL TIME", 1, true) ~= nil, "header shows ALL TIME")
	Mock.Advance(Config.Social.Leaderboard.CycleSeconds + 0.5)
	local s2, t2 = scopeShown()
	check(s2 == "Week" and string.find(t2 or "", "THIS WEEK", 1, true) ~= nil, "cycles to THIS WEEK (" .. tostring(t2) .. ")")
	Mock.Advance(Config.Social.Leaderboard.CycleSeconds)
	local s3, t3 = scopeShown()
	check(s3 == "Server" and string.find(t3 or "", "THIS SERVER", 1, true) ~= nil, "cycles to THIS SERVER")
	local list = boardPart.LeaderboardGui:FindFirstChild("List", true)
	local listed = false
	for _, row in list:GetChildren() do
		local name = row:FindFirstChild("Name")
		if name and name.Text == sp.DisplayName then
			listed = true
		end
	end
	check(listed, "a new player appears on THIS SERVER")
	Mock.Advance(Config.Social.Leaderboard.CycleSeconds)
	check(LeaderboardService.GetScope() == "AllTime", "back to ALL TIME")

	-- server dig goal: scales with players / depth, triggers Golden Hour early + announcement
	check(Config.ServerGoalTarget({ 0 }) == Config.Social.ServerGoal.MinSand, "1 beginner: the minimum goal")
	check(
		Config.ServerGoalTarget({ 0, 0, 0, 0 }) == 4 * Config.Social.ServerGoal.PerPlayerSand,
		"4 beginners: 4 shares (" .. Config.ServerGoalTarget({ 0, 0, 0, 0 }) .. ")"
	)
	check(Config.ServerGoalTarget({ 950 }) > Config.ServerGoalTarget({ 0, 0, 0, 0, 0, 0 }), "deep players raise the goal")
	check(Config.ServerGoalTarget({ 1, 2, 3 }) % Config.Social.ServerGoal.Round == 0, "goal is rounded")
	ServerGoalService.Recompute()
	local state = ServerGoalService.GetState()
	check(workspace:GetAttribute("ServerGoalTarget") ~= nil, "goal replicated to workspace")
	check(state.Target >= Config.Social.ServerGoal.MinSand, "goal target set (" .. state.Target .. ")")
	check(EventService.StartEarly("NotAnEvent", 60) == false, "StartEarly rejects unknown ids")
	local mark = #Mock.Remote.ToClient
	local completedBefore = state.Completed
	ServerGoalService.Add(state.Target - state.Progress - 1)
	check(ServerGoalService.GetState().Completed == completedBefore, "one sand short: not yet")
	ServerSignals.Dug:Fire(sp, 5, 10, "Shovel") -- digs count via ServerSignals.Dug
	Mock.Advance(1.5)
	local after = ServerGoalService.GetState()
	check(after.Completed == completedBefore + 1, "goal reached by digging")
	check(EventService.IsActive(Config.Social.ServerGoal.EventId), "Golden Hour started early")
	local ends = workspace:GetAttribute("EventEnds_" .. Config.Social.ServerGoal.EventId)
	check(type(ends) == "number" and ends > Mock.Env.os.time(), "EventEnds attribute for the client countdown")
	check(EventService.GetSecondsLeft(Config.Social.ServerGoal.EventId) >= Config.Social.ServerGoal.EventSeconds - 2, "event lasts EventSeconds")
	check(after.Progress == 0 and after.ResumeAt > Mock.Env.os.time(), "goal resets and pauses during the event")
	local announced = false
	for i = mark + 1, #Mock.Remote.ToClient do
		local e = Mock.Remote.ToClient[i]
		if e.Name == "Notify" and e.Args[1] == "Announce" and string.find(tostring(e.Args[2]), "SERVER GOAL", 1, true) then
			announced = true
		end
	end
	check(announced, "server goal announced to everyone")
	ServerGoalService.Add(1000)
	check(ServerGoalService.GetState().Progress == 0, "no counting while the reward runs")
	check(workspace:GetAttribute("ServerGoalResumeAt") == after.ResumeAt, "ResumeAt replicated")

	Mock.RemovePlayer(sp)
	Mock.Advance(2)
	check(LeaderboardService.GetSession(sp) == nil, "session counters dropped on leave")
	check(#Mock.Errors == e0, "status & social: no errors")
end)

-- Rebirth & economy (v2.2): rebirth perk shop, Head Start / Keep Backpack on rebirth, perks in
-- Stats (capacity, coins, luck, slots), Sell Anywhere via perk, offline pet earnings ------------
section("rebirth & economy")
step("rebirth & economy", function()
	local Stats = Mock.Require(byPath["ReplicatedStorage/Shared/Util/Stats"])
	local OfflineService = Mock.Require(byPath["ServerScriptService/Server/Services/OfflineService"])
	local MultiplierService = Mock.Require(byPath["ServerScriptService/Server/Services/MultiplierService"])
	local Perks = Config.RebirthPerks
	local e0 = #Mock.Errors

	-- config sanity: costs tuned to the token rewards
	check(Config.RebirthTokens(0) >= 2, "first rebirth gives at least 2 tokens")
	local cheap = 0
	for _, def in Perks.List do
		check(#def.Costs == #def.Levels and #def.Costs >= 1, def.Id .. ": one cost per level")
		if def.Costs[1] <= Config.RebirthTokens(0) then
			cheap += 1
		end
	end
	check(cheap >= 3, "the first rebirth can afford several different level-1 perks")
	check(Perks.MaxLevel("PetDen") == 2, "Pet Den has 2 levels")
	check(Perks.Get("SellAnywhere") ~= nil and Perks.MaxLevel("SellAnywhere") == 1, "Sell Anywhere is a single unlock")
	check(Config.RebirthCost(0) < 4_000_000 and Config.RebirthCost(4) == 470_000_000, "cheaper first rebirths, same late curve")
	for n = 0, 12 do
		check(Config.RebirthCost(n + 1) > Config.RebirthCost(n) * 2, "rebirth cost keeps climbing at " .. n)
	end
	check(Perks.Level({ GoldenTouch = 99 }, "GoldenTouch") == 5, "Level clamps to max")
	check(Perks.Level({ GoldenTouch = "x" } :: any, "GoldenTouch") == 0, "Level ignores junk")
	check(Perks.Level(nil, "GoldenTouch") == 0, "Level of nil table")

	local p = Mock.AddPlayer(5005, "PerkTester")
	Mock.Advance(0.5)
	Mock.SpawnCharacter(p)
	Mock.Advance(2)
	local d = DataService.Get(p)
	check(d ~= nil and type(d.RebirthPerks) == "table" and next(d.RebirthPerks) == nil, "new save: no perks")
	check(type(d.LastOnline) == "number" and d.LastOnline > 0, "LastOnline stamped on join")

	-- buying
	local function buy(id)
		Mock.FireServer("BuyRebirthPerk", p, id)
		Mock.Advance(0.6)
	end
	buy("GoldenTouch")
	check(Perks.Level(d.RebirthPerks, "GoldenTouch") == 0, "no tokens: perk refused")
	DataService.Set(p, "RebirthTokens", 30)
	Mock.Advance(0.1)
	buy("nope")
	buy(123)
	buy(nil)
	check(d.RebirthTokens == 30 and next(d.RebirthPerks) == nil, "junk perk ids ignored")
	local capBefore = p:GetAttribute("Capacity")
	local slotsBefore = p:GetAttribute("PetSlots")
	buy("GoldenTouch")
	check(d.RebirthPerks.GoldenTouch == 1 and d.RebirthTokens == 29, "Golden Touch L1 bought for 1 token")
	buy("DeepPockets")
	buy("PetDen")
	buy("LuckyDigger")
	Mock.Advance(1.2)
	check(p:GetAttribute("Capacity") == math.floor(capBefore * 1.1), "Deep Pockets: +10% capacity attribute")
	check(p:GetAttribute("PetSlots") == slotsBefore + 1, "Pet Den: +1 pet slot attribute")
	local ctx = MultiplierService.GetContext(p)
	local hasTouch = false
	for _, f in Stats.GetCoinFactors(ctx) do
		hasTouch = hasTouch or (f.Name == "Golden Touch" and f.Value == 1.1)
	end
	check(hasTouch, "Golden Touch is a coin factor")
	local layer3 = Config.Layers[3]
	check(
		math.abs(Stats.GetTreasureChance(ctx, 3) - math.min(layer3.TreasureChance * Stats.GetLuck(ctx) * 1.1, Config.MAX_TREASURE_CHANCE)) < 1e-9,
		"Lucky Digger: x1.1 treasure chance"
	)
	-- max level
	buy("PetDen")
	local tokensAtMax = d.RebirthTokens
	buy("PetDen")
	check(d.RebirthPerks.PetDen == 2 and d.RebirthTokens == tokensAtMax, "Pet Den stops at level 2, no tokens taken")

	-- Sell Anywhere: refused without pass/perk, works with the perk
	local n0 = #Mock.Remote.ToClient
	DataService.Set(p, "Sand", 7)
	Mock.Advance(0.1)
	Mock.FireServer("SetSetting", p, "SellNow", true)
	Mock.Advance(1.2)
	check(d.Sand == 7 and #notifies(p, n0) > 0, "SellNow refused without pass or perk")
	buy("SellAnywhere")
	check(d.RebirthPerks.SellAnywhere == 1, "Sell Anywhere perk bought")
	local coins0 = d.Coins
	Mock.FireServer("SetSetting", p, "SellNow", true)
	Mock.Advance(1.2)
	check(d.Sand == 0 and d.Coins > coins0, "SellNow sells with the Sell Anywhere perk (" .. d.Sand .. ", " .. d.Coins - coins0 .. ")")

	-- Head Start: shovel owned + equipped right away (better than the starter)
	buy("HeadStart")
	local head = Config.Shovels[Perks.Get("HeadStart").Levels[1].ShovelIndex]
	check(d.OwnedShovels[head.Id] == true and d.Shovel == head.Id, "Head Start shovel owned + equipped on purchase")

	-- Keep Backpack + Head Start on rebirth
	buy("KeepBackpack")
	local keepPack = Config.Backpacks[3]
	DataService.Mutate(p, { "OwnedBackpacks", "Backpack", "Coins" }, function(dd)
		dd.OwnedBackpacks[keepPack.Id] = true
		dd.Backpack = keepPack.Id
		dd.Coins = Config.RebirthCost(0)
	end)
	Mock.Advance(0.2)
	local perksBefore = table.clone(d.RebirthPerks)
	local tokensBefore = d.RebirthTokens
	Mock.FireServer("Rebirth", p)
	Mock.Advance(2)
	check(d.Rebirths == 1, "perk tester rebirthed")
	check(d.Shovel == head.Id and d.OwnedShovels[head.Id] == true, "Head Start: rebirth starts with " .. head.Name)
	check(d.Coins == Perks.Get("HeadStart").Levels[1].Coins, "Head Start: rebirth starts with its coins")
	check(d.Backpack == keepPack.Id and d.OwnedBackpacks[keepPack.Id] == true, "Keep Backpack: backpack kept")
	check(d.RebirthTokens == tokensBefore + Config.RebirthTokens(0), "rebirth tokens added")
	local same = true
	for id, level in perksBefore do
		same = same and d.RebirthPerks[id] == level
	end
	check(same, "perks survive rebirth")
	-- Keep Backpack L1 does not keep a backpack above its limit
	DataService.Mutate(p, { "OwnedBackpacks", "Backpack", "Coins" }, function(dd)
		local big = Config.Backpacks[9]
		dd.OwnedBackpacks[big.Id] = true
		dd.Backpack = big.Id
		dd.Coins = Config.RebirthCost(1)
	end)
	Mock.Advance(0.2)
	Mock.FireServer("Rebirth", p)
	Mock.Advance(2.5)
	check(d.Rebirths == 2 and d.Backpack == Config.Backpacks[1].Id, "Keep Backpack L1 does not keep a big backpack")

	-- Offline earnings -----------------------------------------------------------------------------
	DataService.Mutate(p, { "Pets", "MaxDepth", "Rebirths", "RebirthPerks", "Boosts", "Index" }, function(dd)
		dd.Pets = { offline1 = { Id = "toy_truck", Equipped = true } }
		dd.MaxDepth = Config.Layers[6].DepthStart + 5 -- reached Shipwreck; toy truck digs Pirate Cove (15)
		dd.Rebirths = 0
		dd.RebirthPerks = {}
		dd.Boosts = {}
		dd.Index = {}
	end)
	Mock.Advance(1.2)
	ctx = MultiplierService.GetContext(p)
	local truck = Config.GetPet("toy_truck")
	local expectedRate = Config.Layers[5].SandValue * truck.Multiplier * truck.Dig.SandMultiplier / truck.Dig.Interval
	local hour = OfflineService.Estimate(ctx, 3600)
	check(math.abs(hour.SandPerSecond - expectedRate) < 1e-6, string.format("offline rate = live pet-dig formula (%.3f vs %.3f)", hour.SandPerSecond, expectedRate))
	check(hour.Efficiency == 0.4 and hour.Seconds == 3600 and not hour.Capped, "1 h: 40% efficiency, uncapped")
	check(hour.Coins == math.floor(expectedRate * 0.4 * 3600), "1 h coins = rate x 40% x seconds (" .. hour.Coins .. ")")
	check(hour.PetId == "toy_truck", "best digging pet reported")
	local long = OfflineService.Estimate(ctx, 10 * 3600)
	check(long.Seconds == 2 * 3600 and long.Capped and long.CapSeconds == 7200, "capped at 2 h without Long Nap")
	check(long.Coins == math.floor(expectedRate * 0.4 * 7200), "capped coins")
	d.RebirthPerks = { LongNap = 2, GoldenTouch = 1 }
	local napped = OfflineService.Estimate(ctx, 10 * 3600)
	check(napped.CapSeconds == 4 * 3600 and math.abs(napped.Efficiency - 0.6) < 1e-9, "Long Nap L2: 4 h cap, 60%")
	check(napped.Coins == math.floor(expectedRate * 0.6 * 4 * 3600 * 1.1), "Golden Touch applies to offline coins")
	d.RebirthPerks = {}
	-- boosts / events do not count while offline
	d.Boosts = { SandBoost = Mock.Env.os.time() + 9999 }
	check(OfflineService.Estimate(ctx, 3600).Coins == hour.Coins, "active boosts are ignored offline")
	d.Boosts = {}
	-- a non-digging pet earns nothing
	d.Pets = { offline2 = { Id = "seagull", Equipped = true } }
	check(OfflineService.Estimate(ctx, 3600).Coins == 0, "no digging pet: no offline coins")
	d.Pets = { offline1 = { Id = "toy_truck", Equipped = true } }

	-- grant + guards
	local now = Mock.Env.os.time()
	local function grantWith(last, firstJoin)
		d.LastOnline = last
		if firstJoin then
			d.FirstJoin = firstJoin
		end
		return OfflineService.Grant(p, now)
	end
	local firstJoin = now - 400 * 86400
	d.FirstJoin = firstJoin
	check(grantWith(0) == nil, "LastOnline 0: nothing")
	check(d.LastOnline == now, "LastOnline stamped by Grant")
	check(grantWith(now - 4 * 60) == nil, "away < 5 min: nothing")
	check(grantWith(now + 3600) == nil, "LastOnline in the future (clock skew): nothing")
	check(grantWith(now - 366 * 86400) == nil, "absurd gap: nothing")
	check(grantWith(now - 3600, now - 60) == nil, "LastOnline before FirstJoin: nothing")
	d.FirstJoin = firstJoin
	local coins1 = d.Coins
	local r0 = #Mock.Remote.ToClient
	local granted = grantWith(now - 3600)
	Mock.Advance(0.2)
	check(granted ~= nil and granted.Coins == hour.Coins and d.Coins == coins1 + hour.Coins, "1 h away grants the estimate")
	check(d.Sand == 0, "offline earnings go to coins, not the backpack")
	local popup = lastToClient(p, "OfflineEarnings")
	check(countToClient(p, "OfflineEarnings", r0) == 1 and popup[1].Coins == hour.Coins and popup[1].Seconds == 3600, "OfflineEarnings popup sent")
	check(grantWith(now) == nil, "granting again right away gives nothing")

	-- leave / rejoin: perks persist, LastOnline saved; a long absence pays on join
	local perksSaved = table.clone(d.RebirthPerks)
	DataService.Set(p, "RebirthPerks", { GoldenTouch = 2, SellAnywhere = 1 })
	Mock.Advance(0.2)
	Mock.RemovePlayer(p)
	Mock.Advance(3)
	local _ = perksSaved
	if not STUDIO_NO_API then
		local saved = Mock.DataStores[Config.DATASTORE_NAME]["Player_5005"]
		check(saved.Data.LastOnline >= Mock.Env.os.time() - 5, "LastOnline saved on leave (" .. saved.Data.LastOnline - Mock.Env.os.time() .. ")")
		check(saved.Data.RebirthPerks.GoldenTouch == 2, "perks saved")
		saved.Data.LastOnline = Mock.Env.os.time() - 2 * 3600 -- pretend the player left 2 hours ago
	end
	local p2 = Mock.AddPlayer(5005, "PerkTester")
	Mock.Advance(0.5)
	Mock.SpawnCharacter(p2)
	Mock.Advance(5)
	local d2 = DataService.Get(p2)
	check(d2 ~= nil and d2.RebirthPerks.GoldenTouch == 2 and d2.RebirthPerks.SellAnywhere == 1, "perks persist across sessions")
	if not STUDIO_NO_API then
		local info = lastToClient(p2, "OfflineEarnings")
		check(info ~= nil and info[1].Coins > 0 and info[1].Seconds == 2 * 3600, "rejoin after 2 h: offline earnings paid")
	else
		check(lastToClient(p2, "OfflineEarnings") == nil, "quick rejoin (studio): no offline earnings")
	end
	Mock.RemovePlayer(p2)
	Mock.Advance(1)
	check(#Mock.Errors == e0, "no errors in rebirth & economy")
end)

section("stress (v2.3 /stress)")
step("stress", function()
	local e0 = #Mock.Errors
	local DevCommands = Mock.Require(byPath["ServerScriptService/Server/Services/DevCommands"])
	local sp = Mock.AddPlayer(39501, "StressDev")
	Mock.Advance(1)
	local zc = World.GetDigZone().CFrame.Position
	Mock.SpawnCharacter(sp, zc + Vector3.new(0, 4, 0))
	Mock.Advance(1)
	local n = DevCommands.StartStress(sp, 3, true)
	Mock.Advance(0.1)
	local folder = workspace:FindFirstChild("StressBots")
	check(n == 3 and folder and #folder:GetChildren() == 3, "/stress spawns 3 bots")
	local bot = folder and folder:FindFirstChild("StressBot_1")
	check(bot and bot:IsA("Model") and bot.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, "bot is an Atomic model StressBot_1")
	local pets = 0
	if bot then
		for _, c in bot:GetChildren() do
			if string.sub(c.Name, 1, 3) == "Pet" then
				pets += 1
			end
		end
	end
	check(pets == 3, "each bot has 3 digging pets")
	check(bot and bot:FindFirstChild("DigBurst", true) ~= nil, "fx: particle stream on bots")
	Mock.Advance(3)
	local stats = DevCommands.GetStressStats()
	check(stats.Bots == 3 and stats.Attempts > 20, "bots dig at the shovel rate (" .. stats.Attempts .. " attempts in 3 s)")
	check(stats.Digs > 0, "bot digs go through DigService.DigAt (" .. stats.Digs .. " ok)")
	local d = DataService.Get(sp)
	check(d and d.TotalSandDug > 0, "bot digs add sand through the real dig path")
	Mock.Advance(10.5) -- one 10 s summary
	local summary = DevCommands.StopStress()
	check(summary ~= nil and string.find(summary, "digs/s", 1, true) ~= nil and string.find(summary, "heartbeat", 1, true) ~= nil, "summary line: " .. tostring(summary))
	check(workspace:FindFirstChild("StressBots") == nil, "/stress stop removes the bots")
	check(DevCommands.StopStress() == nil, "stop twice is harmless")
	Mock.RemovePlayer(sp)
	Mock.Advance(1)
	check(#Mock.Errors == e0, "no errors during /stress")
end)

-- Discovery (v3 slice): buried deposits, uncover via dig, ownership, excavation scoring +
-- clamping, variant odds, value math, Index variants, detector pings, migration --------------
section("discovery")
step("discovery", function()
	local Finds = Mock.Require(byPath["ReplicatedStorage/Shared/Util/Finds"])
	local Discovery = Mock.Require(byPath["ServerScriptService/Server/Services/DiscoveryService"])
	local D = Config.Discovery
	local e0 = #Mock.Errors
	local S = Config.SURFACE_Y
	Discovery.SetSeed(4242)

	-- config + pure math --------------------------------------------------------------------------
	check(Config.GetRarity("Relic") ~= nil and Config.GetRarity("Relic").Order == 7, "Relic rarity above Mythic")
	check(#Finds.Relics() >= 1 and #Finds.Relics() <= 2, "one or two Relic items (" .. #Finds.Relics() .. ")")
	for _, group in { "Size", "Material" } do
		for _, luck in { 1, 2, 5 } do
			local total = 0
			for _, o in Finds.VariantOdds(group, luck) do
				total += o.Chance
			end
			check(math.abs(total - 1) < 1e-9, group .. " odds sum to 1 at luck " .. luck)
		end
	end
	local base = Finds.VariantOdds("Size", 1)
	local lucky = Finds.VariantOdds("Size", 2)
	check(math.abs(base[4].Chance - 0.04) < 1e-9 and lucky[4].Chance > base[4].Chance, "Giant 4% at luck 1, more with luck")
	check(lucky[1].Chance < base[1].Chance or lucky[1].Chance == base[1].Chance * (100 / 118), "Tiny is not a lucky variant")
	check(Finds.VariantOdds("Material", 0 / 0)[1].Chance == 0.88, "junk luck -> base odds")
	-- variant roll distribution: stratified rolls reproduce the true odds exactly
	for _, group in { "Size", "Material" } do
		local N = 20000
		local counts = {}
		for i = 0, N - 1 do
			local id = Finds.RollVariant(group, 1, (i + 0.5) / N)
			counts[id] = (counts[id] or 0) + 1
		end
		for _, o in Finds.VariantOdds(group, 1) do
			check(math.abs((counts[o.Id] or 0) / N - o.Chance) < 0.001, string.format("%s roll distribution: %s %.4f vs %.4f", group, o.Id, (counts[o.Id] or 0) / N, o.Chance))
		end
	end
	-- random rolls are close too (sanity)
	local seed = 12345
	local function rnd()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local giant, golden = 0, 0
	for _ = 1, 20000 do
		if Finds.RollVariant("Size", 1, rnd()) == "Giant" then
			giant += 1
		end
		if Finds.RollVariant("Material", 1, rnd()) == "Golden" then
			golden += 1
		end
	end
	check(math.abs(giant / 20000 - 0.04) < 0.006 and math.abs(golden / 20000 - 0.07) < 0.008, "random variant rolls ~ odds (" .. giant .. ", " .. golden .. ")")
	-- scoring + clamping
	check(Finds.Grade(0.05) == "Perfect" and Finds.Grade(0.15) == "Good" and Finds.Grade(0.5) == "Miss", "ring grades")
	check(Finds.Grade(-1) == "Miss" and Finds.Grade(0 / 0) == "Miss" and Finds.Grade("x") == "Miss", "junk ring errors are misses")
	check(select(1, Finds.Score({ 0, 0, 0, 0, 0, 0, 0 })) == 6, "score clamps to RINGS entries")
	check(Finds.Score("nope") == 0 and Finds.Score(nil) == 0, "junk reports score 0")
	check(Finds.QualityForScore(6) == "Pristine" and Finds.QualityForScore(5) == "Pristine", "5+ points: Pristine")
	check(Finds.QualityForScore(3) == "Good" and Finds.QualityForScore(1) == "Damaged", "Good / Damaged thresholds")
	-- value math: base x size x material x quality
	check(Finds.Value("bottle_cap", "Giant", "Golden", "Pristine", 0) == math.floor(8 * 5 * 3 * 1.5), "value = base x size x material x quality")
	check(Finds.Value("bottle_cap", "Tiny", "None", "Damaged", 0) == math.max(1, math.floor(8 * 0.5 * 0.6)), "small values floor, at least 1")
	check(Finds.Value("sun_compass", "Normal", "None", "Good", 0) == 1800, "Relic = 1800 s of income at layer 1")
	check(Finds.Value("sun_compass", "Normal", "None", "Good", Config.Layers[5].DepthStart) == 1800 * Config.Layers[5].RewardScale, "Relic value scales with deepest layer")
	check(Finds.Key("seashell", "Large", "Crystal", "Good") == "seashell|Large|Crystal|Good", "find key format")
	check(select(1, Finds.ParseKey("seashell|Large|Crystal|Good")) == "seashell" and Finds.ParseKey("nope|Large|Crystal|Good") == nil, "find keys parse / reject")
	check(Finds.TotalValue({ ["bottle_cap|Normal|None|Good"] = 3, ["junk"] = 5 }, 0) == 24, "TotalValue ignores junk keys")
	-- tiers
	check(Finds.Tier("Common", "Normal", "None") == "Pop" and Finds.Tier("Common", "Giant", "None") == "Beam", "Pop, Giant bumps to Beam")
	check(Finds.Tier("Uncommon", "Normal", "Golden") == "Beam" and Finds.Tier("Rare") == "Beam", "material bumps to Beam; Rare = Beam")
	check(Finds.Tier("Legendary") == "Card" and Finds.Tier("Mythic") == "Server" and Finds.Tier("Relic") == "Spectacle", "Card / Server / Spectacle tiers")
	check(Finds.Signal("Common") == "White" and Finds.Signal("Epic") == "Gold" and Finds.Signal("Relic") == "Purple", "detector signal colours")
	-- detector math
	check(Finds.Band(3) == 1 and Finds.Band(10) == 2 and Finds.Band(17) == 3 and Finds.Band(23) == 4 and Finds.Band(30) == 0, "distance bands")
	check(Finds.Sector(0, 5) == 0 and Finds.Sector(5, 0) == 2 and Finds.Sector(0, -5) == 4 and Finds.Sector(-5, 0) == 6, "compass sectors")
	local dir = Finds.SectorDirection(2)
	check(math.abs(dir.X - 1) < 1e-6 and math.abs(dir.Z) < 1e-6, "SectorDirection inverts Sector")

	-- seeding: density, cap, positions -------------------------------------------------------------
	local digZone = World.GetDigZone()
	local zc, zs = digZone.CFrame.Position, digZone.Size
	local function inZone(p)
		return math.abs(p.X - zc.X) <= zs.X / 2 and math.abs(p.Z - zc.Z) <= zs.Z / 2 and p.Y <= S - D.MIN_DEPTH + 1e-6 and p.Y >= S - zs.Y
	end
	local counts, ok, n = {}, true, 0
	for i = 0, 9 do
		local probe = Vector3.new(zc.X - zs.X / 2 + 16 + i * 32, S - 16, zc.Z - zs.Z / 2 + 16)
		local c = Discovery.Seed(probe)
		table.insert(counts, c)
		check(c <= D.CHUNK_CAP, "chunk deposits <= CHUNK_CAP")
		for _, dep in Discovery.DepositsNear(probe, 30) do
			n += 1
			ok = ok and inZone(dep.Position) and Config.GetTreasure(dep.TreasureId) ~= nil
		end
	end
	local sum = 0
	for _, c in counts do
		sum += c
	end
	check(ok and n > 0, "deposits sit inside the zone, >= MIN_DEPTH down, with real treasures")
	check(sum / #counts >= 5 and sum / #counts <= 11, "layer-1 chunks hold ~DENSITY deposits (avg " .. sum / #counts .. ")")
	-- server cap: seed the whole zone
	for cy = 0, math.ceil(zs.Y / D.CHUNK_Y) - 1 do
		for cx = 0, math.ceil(zs.X / D.CHUNK) - 1 do
			for cz = 0, math.ceil(zs.Z / D.CHUNK) - 1 do
				Discovery.Seed(Vector3.new(zc.X - zs.X / 2 + cx * D.CHUNK + 1, S - cy * D.CHUNK_Y - 4, zc.Z - zs.Z / 2 + cz * D.CHUNK + 1))
			end
		end
	end
	check(Discovery.CountDeposits() <= D.SERVER_CAP, "never more than SERVER_CAP deposits (" .. Discovery.CountDeposits() .. ")")
	-- eviction: chunks nobody is near are forgotten after EVICT_SECONDS
	local chunksBefore = Discovery.ChunkCount()
	Discovery.Maintain(Mock.Env.os.clock() + D.EVICT_SECONDS + 1)
	check(Discovery.ChunkCount() < chunksBefore, "untouched chunks are evicted (" .. chunksBefore .. " -> " .. Discovery.ChunkCount() .. ")")

	-- uncover via dig + ownership ---------------------------------------------------------------------
	local p1 = Mock.AddPlayer(6101, "Digger")
	local p2 = Mock.AddPlayer(6102, "Watcher")
	Mock.Advance(0.5)
	local X, Z = -250, zc.Z
	Mock.SpawnCharacter(p1, Vector3.new(X, S + 3, Z))
	Mock.SpawnCharacter(p2, Vector3.new(X + 4, S + 3, Z))
	Mock.Advance(2)
	p1.Character:PivotTo(CFrame.new(X, S + 3, Z)) -- characters spawn on the boardwalk
	p2.Character:PivotTo(CFrame.new(X + 4, S + 3, Z))
	local d1, d2 = DataService.Get(p1), DataService.Get(p2)
	check(d1 ~= nil and d2 ~= nil and type(d1.Finds) == "table" and type(d1.FindVariants) == "table", "new saves have Finds + FindVariants")
	d1.Settings.FTUE_FirstDig = true
	d1.Index = { bottle_cap = true } -- not a brand-new player (no FTUE find)
	d2.Index = { bottle_cap = true }
	local function clearAround(x, z)
		for _, dep in Discovery.DepositsNear(Vector3.new(x, S - 8, z), 14) do
			Discovery.Uncover(p2, dep) -- remove stray seeded deposits
			local ex = Discovery.GetExcavation(p2)
			if ex then
				Discovery.Resolve(p2, ex.Id, nil)
			end
		end
	end
	local function dig(p, x, z)
		DataService.Get(p).Sand = 0
		local y = Mock.TerrainSurfaceBelow(x, z, S + 8) or S
		Mock.FireServer("Dig", p, Vector3.new(x, y, z))
		Mock.Advance(Config.Shovels[1].Cooldown + 0.05)
	end
	clearAround(X, Z)
	local before = #Mock.Remote.ToClient
	local deposit = Discovery.AddDeposit(Vector3.new(X, S - 5, Z), "cool_sunglasses")
	check(deposit ~= nil, "deposit added")
	dig(p1, X, Z)
	local start = lastToClient(p1, "ExcavationStart")
	check(countToClient(p1, "ExcavationStart", before) == 1 and start ~= nil, "a dig within UNCOVER_RADIUS uncovers the deposit")
	local info = start and start[1]
	check(info and type(info.Id) == "string" and info.Position ~= nil and info.Rings == D.RINGS and info.Timeout == D.EXCAVATION_TIMEOUT, "ExcavationStart info")
	check(info and info.Signal == "Gold", "Rare find signals gold")
	check(#Discovery.DepositsNear(Vector3.new(X, S - 5, Z), 1) == 0, "uncovered deposit leaves the hash")
	local ex = Discovery.GetExcavation(p1)
	check(ex ~= nil and ex.Player == p1 and ex.TreasureId == "cool_sunglasses", "the digger owns the excavation")
	local model
	for _, m in Mock.Tagged("DiscoveryFind") do
		if m:GetAttribute("FindId") == (info and info.Id) then
			model = m
		end
	end
	check(model ~= nil and model:GetAttribute("OwnerId") == p1.UserId and model:GetAttribute("Stage") == "Excavating", "find model spawned for everyone, owned by the digger")
	check(model ~= nil and model.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, "normal finds stream atomically")
	-- p2 digs right there: nothing to uncover (owned), no excavation for p2
	local b2 = #Mock.Remote.ToClient
	dig(p2, X + 2, Z)
	check(countToClient(p2, "ExcavationStart", b2) == 0 and Discovery.GetExcavation(p2) == nil, "others can't take an uncovered find")
	-- one excavation at a time: another deposit stays buried while p1 is excavating
	local second = Discovery.AddDeposit(Vector3.new(X - 3, S - 5, Z), "bottle_cap")
	local b3 = #Mock.Remote.ToClient
	dig(p1, X - 3, Z)
	check(countToClient(p1, "ExcavationStart", b3) == 0 and #Discovery.DepositsNear(second.Position, 0.5) == 1, "a second deposit waits while excavating")

	-- excavation scoring ------------------------------------------------------------------------------
	Mock.FireServer("Excavate", p1, "wrongid", { 0, 0, 0 })
	Mock.Advance(0.2)
	check(Discovery.GetExcavation(p1) ~= nil, "answers for another id are ignored")
	Mock.FireServer("Excavate", p2, info.Id, { 0, 0, 0 })
	Mock.Advance(0.2)
	check(Discovery.GetExcavation(p1) ~= nil, "other players can't answer your excavation")
	Mock.Advance(2)
	local r0 = #Mock.Remote.ToClient
	Mock.FireServer("Excavate", p1, info.Id, { 0.01, 0.03, 0.0 })
	Mock.Advance(0.3)
	local revealed = lastToClient(p1, "FindRevealed")
	local fi = revealed and revealed[1]
	check(countToClient(p1, "FindRevealed", r0) == 1 and fi ~= nil, "FindRevealed sent to the owner")
	check(fi and fi.Quality == "Pristine" and fi.Perfect == true, "three Perfect rings: Pristine + Perfect")
	check(fi and fi.Value == Finds.Value("cool_sunglasses", fi.Size, fi.Material, "Pristine", d1.MaxDepth), "revealed value = Finds.Value")
	check(fi and fi.Tier == Finds.Tier("Rare", fi.Size, fi.Material) and fi.IsNew == true, "tier + NEW flag")
	local key = fi and Finds.Key("cool_sunglasses", fi.Size, fi.Material, "Pristine")
	check(key and d1.Finds[key] == 1, "find stored in PlayerData.Finds")
	check(d1.Index.cool_sunglasses == true, "Index records the base item")
	check(fi and d1.FindVariants["cool_sunglasses/" .. fi.Size] and d1.FindVariants["cool_sunglasses/" .. fi.Material], "Index records the variants")
	check(fi and #fi.NewVariants == 2, "both variants new on the first find")
	check(model:GetAttribute("Stage") == "Revealed" and model:GetAttribute("Quality") == "Pristine", "model revealed for everyone")
	check(d1.Settings.FTUE_FirstFind and d1.Settings.FTUE_FirstRareFind and d1.Settings.FTUE_FirstPerfectExcavation, "FirstFind / FirstRareFind / FirstPerfectExcavation funnel steps")
	local findEvents = 0
	for _, e in Mock.Analytics do
		if e.Kind == "FunnelStep" and e.Player == p1 and e.Funnel == "Find" then
			findEvents += 1
			check(e.Fields.CustomField01 == "Rare" and string.find(e.Fields.CustomField02, "/", 1, true) ~= nil, "Find event: rarity + size/material")
		end
	end
	check(findEvents == 1, "one Find custom event")
	Mock.Advance(D.REVEAL_SECONDS + 0.5)
	check(model.Parent == nil, "find model cleaned up after the reveal")
	-- clamping: an impossibly fast perfect answer is capped at Good
	dig(p1, X - 3, Z)
	local fast = lastToClient(p1, "ExcavationStart")[1]
	check(fast.Id ~= info.Id and Discovery.GetExcavation(p1) ~= nil, "the waiting deposit is uncovered by the next dig")
	Mock.FireServer("Excavate", p1, fast.Id, { 0, 0, 0 })
	Mock.Advance(0.2)
	check(lastToClient(p1, "FindRevealed")[1].Quality == "Good", "too-fast answer: quality capped at Good")
	-- junk answers: never an error, scored as misses; timeout resolves as Damaged, never lost
	local third = Discovery.AddDeposit(Vector3.new(X + 6, S - 5, Z), "bottle_cap")
	Discovery.Uncover(p1, third)
	local tid = Discovery.GetExcavation(p1).Id
	Mock.FireServer("Excavate", p1, tid, "nope")
	Mock.FireServer("Excavate", p1, 123, {})
	Mock.FireServer("Excavate", p1, string.rep("x", 400), {})
	Mock.Advance(0.2)
	check(Discovery.GetExcavation(p1) ~= nil, "malformed answers are ignored")
	local finds0 = Finds.Count(d1.Finds)
	Mock.Advance(D.EXCAVATION_TIMEOUT + 0.5)
	check(Discovery.GetExcavation(p1) == nil and lastToClient(p1, "FindRevealed")[1].Quality == "Damaged", "no answer: resolved as Damaged")
	check(Finds.Count(d1.Finds) == finds0 + 1, "a timed-out find is still kept")

	-- selling uses value x size x material x quality ---------------------------------------------------
	local EconomyService = Mock.Require(byPath["ServerScriptService/Server/Services/EconomyService"])
	d1.Sand = 0
	local Stats = Mock.Require(byPath["ReplicatedStorage/Shared/Util/Stats"])
	local MultiplierService = Mock.Require(byPath["ServerScriptService/Server/Services/MultiplierService"])
	local expect = math.floor(Finds.TotalValue(d1.Finds, d1.MaxDepth) * Stats.GetCoinMultiplier(MultiplierService.GetContext(p1)))
	local coins0 = d1.Coins
	EconomyService.Sell(p1, "Zone")
	Mock.Advance(0.2)
	check(d1.Coins - coins0 == expect and next(d1.Finds) == nil, "sell pays Finds.TotalValue and empties Finds (" .. (d1.Coins - coins0) .. " vs " .. expect .. ")")
	check(d1.Index.cool_sunglasses == true and next(d1.FindVariants) ~= nil, "Index + variants survive selling")

	-- Mythic / Relic: persistent model, server announcement ------------------------------------------
	local a0 = #Mock.Remote.ToClient
	local relic = Discovery.AddDeposit(Vector3.new(X + 9, S - 5, Z), "sun_compass")
	Discovery.Uncover(p1, relic)
	local rx = Discovery.GetExcavation(p1)
	local relicModel
	for _, m in Mock.Tagged("DiscoveryFind") do
		if m:GetAttribute("FindId") == rx.Id then
			relicModel = m
		end
	end
	check(relicModel and relicModel.ModelStreamingMode == Enum.ModelStreamingMode.Persistent, "Relic model is streaming-persistent (beam for everyone)")
	check(lastToClient(p1, "ExcavationStart")[1].Signal == "Purple", "Relic signals purple")
	Mock.Advance(2)
	Mock.FireServer("Excavate", p1, rx.Id, { 0.1, 0.1, 0.5 })
	Mock.Advance(0.3)
	local announced = false
	for i = a0 + 1, #Mock.Remote.ToClient do
		local e = Mock.Remote.ToClient[i]
		if e.Name == "Notify" and e.Player == p2 and e.Args[1] == "Announce" and string.find(e.Args[2], "RELIC", 1, true) then
			announced = true
		end
	end
	check(announced, "Relic finds are announced to the whole server")
	check(lastToClient(p1, "FindRevealed")[1].Tier == "Spectacle", "Relic tier = Spectacle")

	-- companion / bot digs never find anything (pets, ride, /stress bots: Silent or companion source)
	do
		local DigService = Mock.Require(byPath["ServerScriptService/Server/Services/DigService"])
		check(Discovery.GetExcavation(p1) == nil, "no excavation before the companion check")
		p1.Character:PivotTo(CFrame.new(X + 60, S + 3, Z))
		Mock.Advance(0.1)
		local c0 = #Mock.Remote.ToClient
		for i, source in { "Pet", "Ride", "Digger" } do
			local at = Vector3.new(X + 60 + (i - 2) * 5, S, Z)
			Discovery.AddDeposit(at - Vector3.new(0, 4, 0), "bottle_cap")
			d1.Sand = 0
			DigService.DigAt(p1, at, { Power = 99, Radius = 4, SandMultiplier = 1, Source = source, Silent = source ~= "Ride", Origin = at })
			Mock.Advance(0.1)
		end
		check(countToClient(p1, "ExcavationStart", c0) == 0 and countToClient(p1, "FindRevealed", c0) == 0, "pet / ride / bot digs never uncover finds or pop UI")
		check(Discovery.GetExcavation(p1) == nil, "no excavation from companion digs")
	end

	-- detector: coarse pings only ----------------------------------------------------------------------
	clearAround(X + 30, Z)
	p1.Character:PivotTo(CFrame.new(X + 30, S + 3, Z))
	Mock.Advance(0.2)
	Discovery.AddDeposit(Vector3.new(X + 30 + 8, S - 2, Z), "seashell")
	local s0 = #Mock.Remote.ToClient
	Mock.FireServer("Scan", p1)
	Mock.Advance(0.1)
	local ping = lastToClient(p1, "DetectorPing")
	local pg = ping and ping[1]
	check(countToClient(p1, "DetectorPing", s0) == 1 and pg ~= nil, "Scan pings at once")
	check(pg and pg.Band == 2 and pg.Sector == 2 and pg.Vertical == "Down" and pg.Signal == "White", "ping: band / sector / vertical / signal (" .. tostring(pg and pg.Band) .. "," .. tostring(pg and pg.Sector) .. ")")
	local keys = 0
	for k, v in pg or {} do
		keys += 1
		check(typeof(v) ~= "Vector3", "ping field " .. k .. " is not a position")
	end
	check(keys == 5, "ping has exactly Band/Sector/Vertical/Signal/Remaining")
	Mock.Advance(1.2)
	check(countToClient(p1, "DetectorPing", s0) >= 3, "pings repeat during the scan")
	local s1 = #Mock.Remote.ToClient
	Mock.FireServer("Scan", p1)
	Mock.Advance(0.05)
	local n1 = countToClient(p1, "DetectorPing", s1)
	check(n1 <= 1, "Scan during cooldown does not start a new scan")
	Mock.Advance(D.SCAN_SECONDS + 1)
	local s2 = #Mock.Remote.ToClient
	Mock.Advance(2)
	check(countToClient(p1, "DetectorPing", s2) == 0, "pings stop after the scan")
	p1.Character:PivotTo(CFrame.new(0, S + 3, 40)) -- hub: nothing in range
	Mock.Advance(D.SCAN_COOLDOWN)
	Mock.FireServer("Scan", p1)
	Mock.Advance(0.1)
	check(lastToClient(p1, "DetectorPing")[1].Band == 0, "no deposits in range at the hub: band 0")

	-- FTUE: a brand-new player's early digs always produce a find --------------------------------------
	local p3 = Mock.AddPlayer(6103, "Newbie")
	Mock.Advance(0.5)
	Mock.SpawnCharacter(p3, Vector3.new(X - 60, S + 3, Z))
	Mock.Advance(2)
	p3.Character:PivotTo(CFrame.new(X - 60, S + 3, Z))
	local f0 = #Mock.Remote.ToClient
	for i = 1, D.FTUE_FIND_DIG do
		dig(p3, X - 60 + (i % 2) * 2, Z)
	end
	check(countToClient(p3, "ExcavationStart", f0) >= 1, "brand-new player: a find by dig " .. D.FTUE_FIND_DIG)

	-- find rate: standing still digging with the starter shovel finds something within ~45 s --------
	-- (8 fresh spots, 90 digs = 45 s each; the design target is one find per 30-60 s early on)
	local p4 = Mock.AddPlayer(6104, "Rate")
	Mock.Advance(0.5)
	Mock.SpawnCharacter(p4, Vector3.new(X + 120, S + 3, Z))
	Mock.Advance(2)
	DataService.Get(p4).Index = { bottle_cap = true }
	local found, spotsWithFind = 0, 0
	for spot = 1, 8 do
		local RX = X + 100 + spot * 40
		p4.Character:PivotTo(CFrame.new(RX, S + 3, Z))
		local here = 0
		for i = 1, 90 do
			local ox = ((i * 7) % 9) - 4
			local oz = ((i * 5) % 7) - 3
			dig(p4, RX + ox, Z + oz)
			local ex4 = Discovery.GetExcavation(p4)
			if ex4 then
				here += 1
				Discovery.Resolve(p4, ex4.Id, { 0.1, 0.1, 0.1 })
			end
		end
		found += here
		spotsWithFind += if here > 0 then 1 else 0
	end
	print(string.format("   find rate: %d finds in 8 x 45 s of digging (%d/8 spots found something)", found, spotsWithFind))
	check(found >= 6 and spotsWithFind >= 4, "starter shovel, standing still: ~1 find per 30-60 s (" .. found .. " / 6 min)")

	-- migration v2 -> v3 ----------------------------------------------------------------------------------
	local old = { Treasures = { bottle_cap = 3, nope = 2, seashell = 0 }, Index = { bottle_cap = true, x = true } }
	DataService._MigrateTreasuresToFinds(old)
	check(old.Finds["bottle_cap|Normal|None|Good"] == 3 and next(old.Treasures) == nil, "migration: unsold treasures -> plain finds")
	check(old.Finds["nope|Normal|None|Good"] == nil and old.Finds["seashell|Normal|None|Good"] == nil, "migration drops unknown / empty")
	check(old.FindVariants["bottle_cap/Normal"] and old.FindVariants["bottle_cap/None"] and not old.FindVariants["x/Normal"], "migration ticks default variants for Index items")
	check(Finds.TotalValue(old.Finds, 0) == 3 * 8, "migrated finds sell for exactly the old value")
	check(Config.DATA_VERSION == 3, "DATA_VERSION 3")

	for _, p in { p1, p2, p3, p4 } do
		Mock.RemovePlayer(p)
	end
	Mock.Advance(1)
	check(#Mock.Errors == e0, "no errors in discovery")
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
	"mock policy failure", -- PolicyService lookup failure, provoked in "hatching + compliance"
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
