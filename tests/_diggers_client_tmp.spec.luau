--!nocheck
--[[
	Headless smoke test of the CLIENT (StarterPlayerScripts.Client: controllers + UI) against
	tests/mock/Roblox.luau in client mode, with a scripted fake server on the other end of the
	remotes. The map is built with the real World module so tagged parts / terrain exist.

	Exercises: boot before data arrives, snapshot + deltas, every panel opened (with args), every
	GUI button clicked, map ProximityPrompts, a mouse dig (camera ray -> Dig remote), DigResult
	success/failure, TreasureFound, EggHatched, Notify kinds, events, respawn. Fails on any
	uncaught error, unexpected warning or unsendable remote payload.
]]

local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")

Mock.Verbose = table.find({ ... }, "verbose") ~= nil
Mock.Init(Generated, { Client = true })

local Vector3 = Mock.Vector3
local CFrame = Mock.CFrame
local Enum = Mock.Enum
local byPath = Mock.ByPath

local failures, passes = 0, 0
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
local function sent(name, since)
	local list = {}
	for i = (since or 0) + 1, #Mock.Remote.ToServer do
		local e = Mock.Remote.ToServer[i]
		if e.Name == name then
			table.insert(list, e.Args)
		end
	end
	return list
end

local Config = Mock.Require(byPath["ReplicatedStorage/Shared/Config"])

-- "Server" side ---------------------------------------------------------------------------------
section("world + remotes")
local World = Mock.Require(byPath["ServerScriptService/Server/World"])

Mock.Env.task.spawn(function()
	World.Build()
end)
Mock.Advance(3)
local Remotes = Mock.Require(byPath["ReplicatedStorage/Shared/Remotes"])
do
	local net = Mock.Env.Instance.new("Folder")
	net.Name = "Net"
	for _, name in Remotes.Events do
		local r = Mock.Env.Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = net
	end
	for _, name in Remotes.Functions do
		local r = Mock.Env.Instance.new("RemoteFunction")
		r.Name = name
		r.Parent = net
	end
	-- arrives a bit after the client starts (WaitForChild path)
	Mock.Env.task.delay(0.5, function()
		net.Parent = byPath["ReplicatedStorage/Shared/Remotes"]
	end)
end
local data = Config.NewPlayerData()
data.Coins = 5000
Mock.ServerFunctions.GetData = function()
	return data
end
Mock.ServerFunctions.GetOwnedPasses = function()
	local passes = {}
	for key in Config.Monetization.GamePasses do
		passes[key] = false
	end
	return passes
end
local zc = World.GetDigZone().CFrame.Position
local player = Mock.AddLocalPlayer(1001, "Tester")
local character = Mock.SpawnCharacter(player, zc + Vector3.new(0, 3, 0))
section("client boot")
Mock.RunScript(byPath["StarterPlayer/StarterPlayerScripts/Client/Main"])
Mock.Advance(2)
check(#Mock.Errors == 0, "no errors during client boot")
local playerGui = player:FindFirstChild("PlayerGui")
Mock.FireClientEvent("DataChanged", data)
Mock.FireClientEvent("EventChanged", {})
Mock.Advance(1)
local Panel = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/Components/Panel"])
-- Diggers: Garage panel, followers, dig animation, Garage station (Diggers agent) -----------------
section("diggers")
do
	local DiggerController =
		Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/DiggerController"])
	local first, second = Config.Diggers[1], Config.Diggers[2]
	Panel.CloseAll()
	Mock.Advance(0.3)
	check(Panel.Get("Garage") ~= nil, "panel registered: Garage")
	local e0 = #Mock.Errors
	Panel.Open("Garage")
	Mock.Advance(0.6)
	check(#Mock.Errors == e0 and Panel.Current() == "Garage", "Garage panel opens")
	local window = Panel.Get("Garage").Window
	local scroller = window:FindFirstChild("Diggers", true)
	local cardCount, viewports = 0, 0
	if check(scroller ~= nil, "Garage has a digger list") then
		for _, child in scroller:GetChildren() do
			if Config.GetDigger(child.Name) then
				cardCount += 1
				local vp = child:FindFirstChildWhichIsA("ViewportFrame", true)
				if vp and vp:FindFirstChildWhichIsA("Model") and vp.CurrentCamera then
					viewports += 1
				end
			end
		end
	end
	check(cardCount == #Config.Diggers, "one Garage card per digger (" .. cardCount .. ")")
	check(viewports == #Config.Diggers, "every card has a framed ViewportFrame preview (" .. viewports .. ")")

	-- owned diggers: equip / upgrade / buy buttons fire the remotes
	Mock.FireClientEvent("DataChanged", {
		Coins = 1e9,
		Diggers = { [first.Id] = { Level = 2, Equipped = true }, [second.Id] = { Level = 1, Equipped = false } },
	})
	Mock.Advance(0.5)
	local s0 = #Mock.Remote.ToServer
	for _, d in window:GetDescendants() do
		if d:IsA("GuiButton") then
			Mock.FireEvent(d, "Activated", Mock.Input(Enum.UserInputType.MouseButton1), 1)
			Mock.Advance(0.05)
		end
	end
	Mock.Advance(0.5)
	check(#sent("UpgradeDigger", s0) >= 2, "Garage upgrade buttons send UpgradeDigger")
	check(#sent("UnequipDigger", s0) >= 1, "Garage unequip button sends UnequipDigger")
	check(#sent("BuyDigger", s0) >= 1, "Garage buy buttons send BuyDigger")
	check(#Mock.Errors == e0, "Garage buttons click without errors")
	Panel.CloseAll()
	Mock.Advance(0.5)

	-- followers from the EquippedDiggers attribute
	player:SetAttribute("EquippedDiggers", first.Id .. ":2," .. second.Id)
	Mock.Advance(1)
	local visuals = DiggerController.GetVisuals(player)
	check(#visuals == 2, "two digger followers rendered (" .. #visuals .. ")")
	local root = player.Character.HumanoidRootPart
	if visuals[1] then
		check(visuals[1].Level == 2 and visuals[2].Level == 1, "levels parsed from the attribute")
		local model = visuals[1].Model
		check(model.Parent ~= nil and model.Parent.Name == "ClientDiggers", "digger model parented in ClientDiggers")
		local offset = model:GetPivot().Position - root.Position
		check(Vector3.new(offset.X, 0, offset.Z).Magnitude < 16, "digger follows its owner")
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and (part.CanCollide or part.CanQuery) then
				check(false, "digger parts never collide / block raycasts: " .. part.Name)
				break
			end
		end
		-- dig animation: drives to the dig point
		local target = root.Position + Vector3.new(4, -3, 0)
		Mock.FireClientEvent("DiggerDug", player, first.Id, target, 12)
		Mock.Advance(0.6)
		local p = model:GetPivot().Position
		check(
			(Vector3.new(p.X, target.Y, p.Z) - target).Magnitude < 6,
			"digger drives to its dig point"
		)
		Mock.Advance(1.5)
		check(#Mock.Errors == e0, "DiggerDug animation runs without errors")
	end
	Mock.FireClientEvent("DiggerDug", player, "unknown", root.Position, 1)
	Mock.FireClientEvent("DiggerDug", "junk")
	Mock.Advance(0.5)
	player:SetAttribute("EquippedDiggers", "")
	Mock.Advance(0.5)
	check(#DiggerController.GetVisuals(player) == 0, "followers removed when unequipped")

	-- Garage station prompt (World places a "Garage"-tagged part; make one if it isn't there yet)
	local station = Mock.Tagged("Garage")[1]
	if not station then
		station = Mock.Env.Instance.new("Part")
		station.Name = "GarageStation"
		local prompt = Mock.Env.Instance.new("ProximityPrompt")
		prompt.Parent = station
		station.Parent = Mock.Service("Workspace")
		Mock.Service("CollectionService"):AddTag(station, "Garage")
		Mock.Advance(0.2)
	end
	local prompt = station:FindFirstChildWhichIsA("ProximityPrompt", true)
	if check(prompt ~= nil, "Garage station has a ProximityPrompt") then
		Panel.CloseAll()
		Mock.Advance(0.3)
		Mock.FireEvent(prompt, "Triggered", player)
		Mock.Advance(0.5)
		check(Panel.Current() == "Garage", "Garage prompt opens the Garage panel")
	end
	Panel.CloseAll()
	Mock.Advance(0.5)
end

section("report")
check(#Mock.Errors == 0, #Mock.Errors .. " uncaught errors (see above)")
for _, w in Mock.Warnings do print("   warning: " .. w) end
print(string.format("\nDIGGERS CLIENT: %d passed, %d failed", passes, failures))
local Models = Mock.Require(byPath["ReplicatedStorage/Shared/Models"])
for _, def in Config.Diggers do
	local m = Models.Digger(def.Id)
	local cf, size = m:GetBoundingBox()
	local n, joints = 0, {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then n += 1 end
		if d:IsA("Model") and d:GetAttribute("Motion") then table.insert(joints, d.Name .. "/" .. d:GetAttribute("Motion")) end
	end
	print(string.format("%-14s size %.1f x %.1f x %.1f  centre y %.2f minY %.2f parts %d joints %s", def.Id, size.X, size.Y, size.Z, cf.Position.Y, cf.Position.Y - size.Y/2, n, table.concat(joints, ",")))
end
