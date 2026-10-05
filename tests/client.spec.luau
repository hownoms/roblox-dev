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

local plots = World.GetPlots()
local plot = plots[1]
local data = Config.NewPlayerData()
data.Coins = 5000
Mock.ServerFunctions.GetData = function()
	return data
end
Mock.ServerFunctions.GetPlot = function()
	return plot
end
Mock.ServerFunctions.GetOwnedPasses = function()
	local passes = {}
	for key in Config.Monetization.GamePasses do
		passes[key] = false
	end
	return passes
end

local player = Mock.AddLocalPlayer(1001, "Tester")
local character = Mock.SpawnCharacter(player, plot.SpawnCFrame.Position + Vector3.new(0, 3, 0))

-- Client boot ---------------------------------------------------------------------------------------
section("client boot")
Mock.RunScript(byPath["StarterPlayer/StarterPlayerScripts/Client/Main"])
Mock.Advance(2)
check(#Mock.Errors == 0, "no errors during client boot")
local playerGui = player:FindFirstChild("PlayerGui")
check(#playerGui:GetChildren() >= 4, "ScreenGuis created")

Mock.FireClientEvent("DataChanged", data)
Mock.FireClientEvent("PlotAssigned", plot)
Mock.FireClientEvent("EventChanged", {})
Mock.Advance(1)
local State = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/State"])
check(State.Loaded and State.Data.Coins == 5000, "State has the snapshot")
check(State.Plot ~= nil and State.Plot.Id == plot.Id, "State has the plot")

-- Deltas
Mock.FireClientEvent("DataChanged", { Coins = 6000, Sand = 5 })
Mock.Advance(0.5)
check(State.Data.Coins == 6000 and State.Data.Sand == 5, "delta applied")

-- Panels ------------------------------------------------------------------------------------------
section("panels")
local Panel = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/Components/Panel"])
local panelArgs = {
	Shop = { { Tab = "Shovels" }, { Tab = "Backpacks" } },
	Eggs = { { EggId = Config.Eggs[1].Id }, { EggId = Config.Eggs[#Config.Eggs].Id }, {} },
	Pets = { {} },
	Index = { {} },
	Quests = { {} },
	Daily = { {} },
	Rebirth = { {} },
	Store = { {} },
	Settings = { {} },
}
for name, argList in panelArgs do
	check(Panel.Get(name) ~= nil, "panel registered: " .. name)
	for _, args in argList do
		local e0 = #Mock.Errors
		Panel.Open(name, args)
		Mock.Advance(1)
		check(#Mock.Errors == e0, "open panel " .. name)
		check(Panel.Current() == name, "panel " .. name .. " is current")
	end
	Panel.CloseAll()
	Mock.Advance(0.5)
end

-- Data with pets / quests / treasures to render richer panels
local uid = "{00000001-0000-4000-8000-000000000001}"
Mock.FireClientEvent("DataChanged", {
	Pets = { [uid] = { Id = Config.Pets[1].Id, Equipped = true } },
	Treasures = { [Config.Treasures[1].Id] = 2 },
	Index = { [Config.Treasures[1].Id] = true },
	Quests = { [Config.Quests[1].Id] = { Progress = Config.Quests[1].Target, Claimed = false } },
	MaxDepth = 120,
	Boosts = { SandBoost = os.time() + 1000000000 },
})
player:SetAttribute("EquippedPets", Config.Pets[1].Id)
Mock.Advance(1)
for name in panelArgs do
	Panel.Open(name, {})
	Mock.Advance(0.6)
end
Panel.CloseAll()
Mock.Advance(0.5)

-- Click every button in every panel / HUD -----------------------------------------------------------
section("buttons")
local function clickAll(label)
	local clicked = 0
	for _, d in playerGui:GetDescendants() do
		if d:IsA("GuiButton") then
			local e0 = #Mock.Errors
			Mock.FireEvent(d, "Activated", Mock.Input(Enum.UserInputType.MouseButton1), 1)
			Mock.FireEvent(d, "MouseButton1Click")
			Mock.Advance(0.1)
			clicked += 1
			if #Mock.Errors > e0 then
				print("   (button " .. d:GetFullName() .. " errored)")
			end
		end
	end
	print(string.format("   clicked %d buttons (%s)", clicked, label))
end
clickAll("HUD")
for name in panelArgs do
	Panel.CloseAll()
	Mock.Advance(0.3)
	Panel.Open(name, {})
	Mock.Advance(0.6)
	clickAll(name)
end
Panel.CloseAll()
Mock.Advance(1)
check(#Mock.Prompts == 0, "no MarketplaceService prompt for unconfigured ids (" .. #Mock.Prompts .. ")")

-- World prompts -----------------------------------------------------------------------------------
section("prompts")
for _, t in { "ShovelShop", "BackpackShop", "EggShop", "RebirthStatue" } do
	local part = Mock.Tagged(t)[1]
	local prompt = part and part:FindFirstChildWhichIsA("ProximityPrompt", true)
	if check(prompt ~= nil, t .. " prompt exists") then
		Panel.CloseAll()
		Mock.Advance(0.2)
		Mock.FireEvent(prompt, "Triggered", player)
		Mock.Advance(0.5)
		check(Panel.Current() ~= nil, t .. " prompt opens a panel")
	end
end
Panel.CloseAll()
Mock.Advance(0.5)

-- Dig ---------------------------------------------------------------------------------------------
section("dig")
local c = plot.Origin.Position
character:PivotTo(CFrame.new(c + Vector3.new(0, 3, 6)))
local camera = Mock.Service("Workspace").CurrentCamera
camera.CFrame = CFrame.lookAt(c + Vector3.new(0, 14, 16), c)
Mock.Advance(0.5)
local s0 = #Mock.Remote.ToServer
local UIS = Mock.Service("UserInputService")
local click = Mock.Input(Enum.UserInputType.MouseButton1)
Mock.FireEvent(UIS, "InputBegan", click, false)
Mock.Advance(0.1)
Mock.FireEvent(UIS, "InputEnded", click, false)
Mock.Advance(0.5)
local digs = sent("Dig", s0)
check(#digs >= 1, "mouse click sends Dig")
if digs[1] then
	local pos = digs[1][1]
	check(Mock.typeof(pos) == "Vector3", "Dig argument is a Vector3")
	check(
		math.abs(pos.Y - Config.SURFACE_Y) < 1 and (Vector3.new(pos.X, c.Y, pos.Z) - c).Magnitude < 14,
		"Dig hit point is on our plot's surface"
	)
end

-- touch (hold) and gamepad R2
local s1 = #Mock.Remote.ToServer
local touch = Mock.Input(Enum.UserInputType.Touch, nil, Vector3.new(640, 302, 0))
Mock.FireEvent(UIS, "InputBegan", touch, false)
Mock.Advance(1.2)
Mock.FireEvent(UIS, "InputEnded", touch, false)
Mock.Advance(0.6)
check(#sent("Dig", s1) >= 2, "holding a touch keeps digging (" .. #sent("Dig", s1) .. ")")
local s2 = #Mock.Remote.ToServer
local pad = Mock.Input(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2)
Mock.FireEvent(UIS, "InputBegan", pad, false)
Mock.Advance(0.2)
Mock.FireEvent(UIS, "InputEnded", pad, false)
Mock.Advance(0.6)
check(#sent("Dig", s2) >= 1, "gamepad R2 digs")

local function digResult(overrides)
	local r = {
		Success = true,
		Position = c,
		Radius = 2,
		SandGained = 1,
		Sand = 6,
		Capacity = 20,
		Depth = 1,
		LayerIndex = 1,
		NewMaxDepth = true,
		NewLayer = false,
	}
	for k, v in overrides do
		r[k] = v
	end
	return r
end
Mock.FireClientEvent("DigResult", digResult({}))
Mock.FireClientEvent("DigResult", digResult({ NewLayer = true, LayerIndex = 2, Depth = 21 }))
Mock.FireClientEvent("DigResult", digResult({ Sand = 20 }))
for _, reason in { "TooHard", "BackpackFull", "OutOfPlot", "TooFar", "NoPlot", "Bottom", "Cooldown" } do
	Mock.FireClientEvent("DigResult", digResult({ Success = false, Reason = reason, SandGained = 0 }))
end
Mock.Advance(2)
Mock.FireClientEvent("TreasureFound", Config.Treasures[1].Id, Config.Treasures[1].Rarity)
Mock.FireClientEvent(
	"TreasureFound",
	Config.Treasures[#Config.Treasures].Id,
	Config.Treasures[#Config.Treasures].Rarity
)
Mock.Advance(6)
Mock.FireClientEvent("EggHatched", { Config.Pets[1].Id })
Mock.Advance(8)
Mock.FireClientEvent("EggHatched", { Config.Pets[1].Id, Config.Pets[2].Id, Config.Pets[#Config.Pets].Id })
Mock.Advance(10)
for _, kind in { "Info", "Success", "Error", "Reward", "Sell", "Announce", "Event", "Weird" } do
	Mock.FireClientEvent("Notify", kind, "Test " .. kind)
end
Mock.Advance(1)
Mock.FireClientEvent("DataChanged", { Sand = 0, Coins = 9000 })
Mock.Advance(2)
Mock.FireClientEvent("EventChanged", { "HighTide", "GoldenHour" })
Mock.Service("Workspace"):SetAttribute("ActiveEvents", "HighTide,GoldenHour")
Mock.Advance(2)

-- Descend into the hole (layer banner / tint) and respawn
section("hole + respawn")
character:PivotTo(CFrame.new(c - Vector3.new(0, 80, 0)))
Mock.Advance(2)
local LayerController = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/LayerController"])
check(LayerController.LayerIndex == Config.GetLayerIndexAtDepth(80 - 3), "LayerController tracks depth")
character:PivotTo(CFrame.new(0, Config.SURFACE_Y - 10, -100)) -- lower beach slope, outside any plot
Mock.Advance(1)
check(LayerController.Depth == 0, "beach slope / ocean is not 'underground' (depth " .. LayerController.Depth .. ")")
character = Mock.SpawnCharacter(player, plot.SpawnCFrame.Position + Vector3.new(0, 3, 0))
Mock.Advance(2)
-- keyboard shortcuts
for name, action in Mock.Actions do
	Mock.Env.task.spawn(action.Fn, name, Enum.UserInputState.Begin, Mock.Input(Enum.UserInputType.Keyboard))
	Mock.Advance(0.3)
end
Panel.CloseAll()
Mock.Advance(30)

-- Report ------------------------------------------------------------------------------------------
section("report")
check(#Mock.Errors == 0, #Mock.Errors .. " uncaught errors (see above)")
check(#Mock.Remote.Problems == 0, "remote payloads serializable: " .. table.concat(Mock.Remote.Problems, " | "))
for _, w in Mock.Warnings do
	print("   warning: " .. w)
end
check(#Mock.Warnings == 0, #Mock.Warnings .. " warnings")
local remoteNames = {}
for _, e in Mock.Remote.ToServer do
	remoteNames[e.Name] = (remoteNames[e.Name] or 0) + 1
end
local list = {}
for k, v in remoteNames do
	table.insert(list, k .. "=" .. v)
end
table.sort(list)
print("   client -> server: " .. table.concat(list, ", "))

print(string.format("\nCLIENT: %d passed, %d failed", passes, failures))
if failures > 0 then
	error("CLIENT SMOKE TEST FAILED", 0)
end
print("CLIENT SMOKE TEST PASSED")
