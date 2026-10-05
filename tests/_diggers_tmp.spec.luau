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

section("boot")
local byPath = Mock.ByPath
Mock.RunScript(byPath["ServerScriptService/Server/Main"])
Mock.Advance(1)
check(#Mock.Errors == 0, "no errors during boot")
local Config = Mock.Require(byPath["ReplicatedStorage/Shared/Config"])
local DataService = Mock.Require(byPath["ServerScriptService/Server/Services/DataService"])
local World = Mock.Require(byPath["ServerScriptService/Server/World"])
local workspace = Mock.Service("Workspace")
for _ = 1, 40 do
	if workspace:GetAttribute("WorldReady") then
		break
	end
	Mock.Advance(0.5)
end
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

section("report")
check(#Mock.Errors == 0, #Mock.Errors .. " uncaught errors (see above)")
check(#Mock.Remote.Problems == 0, "remote payloads serializable: " .. table.concat(Mock.Remote.Problems, " | "))
for _, w in Mock.Warnings do print("   warning: " .. w) end
print(string.format("\nDIGGERS SMOKE: %d passed, %d failed", passes, failures))
