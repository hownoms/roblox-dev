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

local zone = World.GetDigZone()
local spawnCF = World.GetSpawnCFrame(1)
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

local player = Mock.AddLocalPlayer(1001, "Tester")
local character = Mock.SpawnCharacter(player, spawnCF.Position)

-- Client boot ---------------------------------------------------------------------------------------
section("client boot")
Mock.RunScript(byPath["StarterPlayer/StarterPlayerScripts/Client/Main"])
Mock.Advance(2)
check(#Mock.Errors == 0, "no errors during client boot")
local playerGui = player:FindFirstChild("PlayerGui")
check(#playerGui:GetChildren() >= 4, "ScreenGuis created")

Mock.FireClientEvent("DataChanged", data)
Mock.FireClientEvent("EventChanged", {})
Mock.Advance(1)
local State = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/State"])
check(State.Loaded and State.Data.Coins == 5000, "State has the snapshot")
local zcf, zsize = State.GetDigZone()
check(zcf ~= nil and zsize == zone.Size, "State reads the dig zone from workspace attributes")
check(State.InDigZone(zone.CFrame.Position) and not State.InDigZone(Vector3.new(0, Config.SURFACE_Y, 40)), "State.InDigZone")
local sand = State.NearestSand(spawnCF.Position, 8)
check(sand ~= nil and State.InDigZone(sand) and (sand - spawnCF.Position).Magnitude < 40, "NearestSand is close to the spawn")

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

-- HUD layout, menu, toasts, viewport framing (Polish) ---------------------------------------------
section("hud polish")
do
	local HUD = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/HUD"])
	local menuNames = { "Shop", "Beach", "Garage", "Eggs", "Pets", "Index", "Quests", "Daily", "Rebirth", "Store", "Settings" }
	local menuPanels = { Beach = "BeachShop", Garage = "Garage" }
	for _, name in menuNames do
		check(HUD.Buttons[name] ~= nil, "HUD menu button " .. name)
	end
	for buttonName, panelName in menuPanels do
		local button = HUD.Buttons[buttonName]
		if button then
			Panel.CloseAll()
			Mock.Advance(0.3)
			local e0 = #Mock.Errors
			Mock.FireEvent(button.Face, "Activated", Mock.Input(Enum.UserInputType.MouseButton1), 1)
			Mock.Advance(0.5)
			check(#Mock.Errors == e0, "HUD " .. buttonName .. " click has no errors")
			if Panel.Get(panelName) then
				check(Panel.Current() == panelName, "HUD " .. buttonName .. " opens panel " .. panelName)
			end
		end
	end
	Panel.CloseAll()
	Mock.Advance(0.5)

	-- Layout: menu sits below the stat pills, depth meter stays out of the right-centre band.
	local hudCanvas = playerGui:FindFirstChild("Dig_HUD"):FindFirstChild("Canvas")
	local stats = hudCanvas:FindFirstChild("Stats")
	local menu = hudCanvas:FindFirstChild("Menu")
	local depth = hudCanvas:FindFirstChild("Depth")
	check(
		menu.Position.Y.Offset >= stats.Position.Y.Offset + stats.Size.Y.Offset,
		"menu does not overlap the stat pills"
	)
	check(depth.Position.Y.Offset + depth.Size.Y.Offset <= 180, "depth meter leaves the right-centre edge free")
	local grid = menu:FindFirstChildWhichIsA("UIGridLayout")
	check(grid ~= nil and grid.CellSize.X.Offset >= 74, "menu cells >= 74 design px (44 px on phones)")

	-- Toasts: the same notice twice (server + client wording) shows once.
	local Toasts = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/Toasts"])
	Mock.Advance(6)
	local toastRoot = playerGui:FindFirstChild("Dig_Toasts"):FindFirstChild("Canvas"):FindFirstChild("Toasts")
	local function countToasts()
		local n = 0
		for _, child in toastRoot:GetChildren() do
			if child.Name == "Toast" then
				n += 1
			end
		end
		return n
	end
	local before = countToasts()
	Toasts.Show("Backpack full! Go sell!", "Error")
	Toasts.Show("Backpack full! Go SELL your sand 💰", "Warning")
	Toasts.Show("Backpack full! Go sell!", "Error")
	Mock.Advance(0.5)
	check(countToasts() == before + 1, "duplicate backpack-full notices dedupe to one toast")
	Mock.Advance(6)

	-- Viewport: a 1 x 6 x 1 stick fills ~75% of a square frame's height.
	local Viewport = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/Components/Viewport"])
	local model = Mock.Env.Instance.new("Model")
	local part = Mock.Env.Instance.new("Part")
	part.Size = Vector3.new(1, 6, 1)
	part.CFrame = CFrame.new(10, 3, 0)
	part.Parent = model
	local hidden = Mock.Env.Instance.new("Part") -- invisible root must not count
	hidden.Size = Vector3.new(40, 40, 40)
	hidden.Transparency = 1
	hidden.Parent = model
	model.PrimaryPart = part
	local camera = Mock.Env.Instance.new("Camera")
	Viewport.Fit(camera, model, { Fill = 0.75, Yaw = 0, Pitch = 0 })
	local top = camera.CFrame:PointToObjectSpace(Vector3.new(0, 3, -0.5))
	local tanHalf = math.tan(math.rad(camera.FieldOfView / 2))
	local fill = (top.Y / -top.Z) / tanHalf
	check(math.abs(fill - 0.75) < 0.05, "Viewport.Fit frames the visible model at ~75% (" .. fill .. ")")
	check(camera.CFrame.Position.Z < 0, "Viewport camera looks at the model's front (-Z)")
end

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
local c = zone.CFrame.Position
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
		"Dig hit point is on the dig zone surface"
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
-- clicking the hub plaza (outside the dig zone) never reaches the server
do
	local hubPoint = Vector3.new(0, Config.SURFACE_Y, 34)
	character:PivotTo(CFrame.new(hubPoint + Vector3.new(0, 3, -6)))
	camera.CFrame = CFrame.lookAt(hubPoint + Vector3.new(0, 14, -16), hubPoint)
	Mock.Advance(0.6)
	local s3 = #Mock.Remote.ToServer
	Mock.FireEvent(UIS, "InputBegan", click, false)
	Mock.Advance(0.1)
	Mock.FireEvent(UIS, "InputEnded", click, false)
	Mock.Advance(0.5)
	check(#sent("Dig", s3) == 0, "click outside the dig zone sends no Dig")
	character:PivotTo(CFrame.new(c + Vector3.new(0, 3, 6)))
	camera.CFrame = CFrame.lookAt(c + Vector3.new(0, 14, 16), c)
	Mock.Advance(0.5)
end

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
for _, reason in { "TooHard", "BackpackFull", "OutOfZone", "TooFar", "Bottom", "Cooldown" } do
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
character:PivotTo(CFrame.new(0, Config.SURFACE_Y - 10, -100)) -- lower beach slope, outside the dig zone
Mock.Advance(1)
check(LayerController.Depth == 0, "beach slope / ocean is not 'underground' (depth " .. LayerController.Depth .. ")")
character = Mock.SpawnCharacter(player, spawnCF.Position)
Mock.Advance(2)
-- keyboard shortcuts
for name, action in Mock.Actions do
	Mock.Env.task.spawn(action.Fn, name, Enum.UserInputState.Begin, Mock.Input(Enum.UserInputType.Keyboard))
	Mock.Advance(0.3)
end
Panel.CloseAll()
Mock.Advance(30)

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

-- Survival: heat HUD, quick-slots, Beach Shop panel, shade placement, prompts (Survival agent) --------
section("survival")
do
	local SurvivalController =
		Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/SurvivalController"])
	local PlacementController =
		Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/PlacementController"])
	local DigController = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/DigController"])
	local e0 = #Mock.Errors
	local function findText(root, pattern)
		for _, d in root:GetDescendants() do
			if d:IsA("TextLabel") and string.find(d.Text, pattern, 1, true) then
				return d
			end
		end
		return nil
	end

	-- Beach Shop panel
	Panel.CloseAll()
	Mock.Advance(0.3)
	check(Panel.Get("BeachShop") ~= nil, "panel registered: BeachShop")
	for _, tab in { "Shade", "Snacks" } do
		Panel.Open("BeachShop", { Tab = tab })
		Mock.Advance(0.6)
		check(Panel.Current() == "BeachShop", "BeachShop opens on tab " .. tab)
	end
	local window = Panel.Get("BeachShop").Window
	for tab, list in { Shade = Config.Shades, Snacks = Config.Consumables } do
		local scroller = window:FindFirstChild(tab, true)
		local cards, viewports = 0, 0
		if check(scroller ~= nil, "BeachShop has a " .. tab .. " list") then
			for _, child in scroller:GetChildren() do
				if child:IsA("Frame") then
					cards += 1
					local vp = child:FindFirstChildWhichIsA("ViewportFrame", true)
					if vp and vp:FindFirstChildWhichIsA("Model") then
						viewports += 1
					end
				end
			end
		end
		check(cards == #list, tab .. ": one card per item (" .. cards .. ")")
		check(viewports == #list, tab .. ": every card has a model preview (" .. viewports .. ")")
	end
	local s0 = #Mock.Remote.ToServer
	Mock.FireClientEvent("DataChanged", { Coins = 1e9, Rebirths = 0, OwnedShades = {}, Consumables = {} })
	Mock.Advance(0.3)
	for _, d in window:GetDescendants() do
		if d:IsA("GuiButton") then
			Mock.FireEvent(d, "Activated", Mock.Input(Enum.UserInputType.MouseButton1), 1)
			Mock.Advance(0.05)
		end
	end
	Mock.Advance(0.5)
	check(#sent("BuyShade", s0) >= 1, "Shade cards send BuyShade")
	check(#sent("BuyConsumable", s0) >= 2, "Snack cards send BuyConsumable")
	Panel.CloseAll()
	Mock.Advance(0.5)

	-- HUD: heat meter, zone, sunburnt toast, warm tint
	local survivalGui = playerGui:FindFirstChild("Dig_Survival")
	check(survivalGui ~= nil and survivalGui:FindFirstChild("SurvivalHUD", true) ~= nil, "SurvivalHUD gui built")
	player:SetAttribute("HeatZone", "Sun")
	player:SetAttribute("Heat", 80)
	Mock.Advance(0.5)
	local fill = survivalGui:FindFirstChild("Fill", true)
	check(fill ~= nil and math.abs(fill.Size.Y.Scale - 0.8) < 0.05, "thermometer fill follows Heat")
	check(findText(playerGui, "Getting hot") ~= nil, "'getting hot' hint at WarningAt")
	player:SetAttribute("Heat", 100)
	player:SetAttribute("Sunburnt", true)
	Mock.Advance(0.5)
	check(findText(playerGui, "Sunburnt! Find shade or drink water") ~= nil, "Sunburnt toast shown")
	check(findText(survivalGui, "BURNT") ~= nil, "zone chip shows BURNT")
	local tint = Mock.Service("Lighting"):FindFirstChild("HeatTint")
	check(tint ~= nil and tint:IsA("ColorCorrectionEffect") and tint.TintColor ~= Mock.Env.Color3.new(1, 1, 1), "HeatTint warms the screen")
	player:SetAttribute("Sunburnt", false)
	player:SetAttribute("Heat", 10)
	player:SetAttribute("HeatZone", "Shade")
	Mock.Advance(0.5)
	check(tint.TintColor == Mock.Env.Color3.new(1, 1, 1), "HeatTint clears when cool")

	-- quick-slots: best owned snacks, cheapest first; keys 1/2/3
	Mock.FireClientEvent("DataChanged", {
		Consumables = { lemonade = 2, popsicle = 1, giant_watermelon = 1, coconut_water = 4 },
	})
	Mock.Advance(0.5)
	local slots = SurvivalController.GetQuickSlots()
	check(
		#slots == 3 and slots[1] == "coconut_water" and slots[3] == "giant_watermelon",
		"quick-slots = 3 best snacks, cheapest first (" .. table.concat(slots, ",") .. ")"
	)
	local s1 = #Mock.Remote.ToServer
	Mock.Env.task.spawn(Mock.Actions.SurvivalSlot1.Fn, "SurvivalSlot1", Enum.UserInputState.Begin, Mock.Input(Enum.UserInputType.Keyboard, Enum.KeyCode.One))
	Mock.Advance(0.3)
	local used = sent("UseConsumable", s1)
	check(#used == 1 and used[1][1] == "coconut_water", "key 1 uses quick-slot 1")

	-- shade placement: ghost on the sand, rotate, place
	local zc = zone.CFrame.Position
	local standAt = Vector3.new(zc.X + 10, Config.SURFACE_Y + 3, zc.Z)
	character = player.Character
	character:PivotTo(CFrame.new(standAt))
	local camera = Mock.Service("Workspace").CurrentCamera
	local target = Vector3.new(zc.X + 10, Config.SURFACE_Y, zc.Z - 8)
	camera.CFrame = CFrame.lookAt(target + Vector3.new(0, 14, 16), target)
	Mock.MouseLocation = Mock.Env.Vector2.new(640, 360)
	PlacementController.Begin()
	Mock.Advance(0.2)
	check(not PlacementController.Active, "no shade owned -> placement does not start")
	Mock.FireClientEvent("DataChanged", { OwnedShades = { [Config.Shades[1].Id] = true } })
	Mock.Advance(0.3)
	local s2 = #Mock.Remote.ToServer
	Mock.Env.task.spawn(Mock.Actions.SurvivalPlaceShade.Fn, "SurvivalPlaceShade", Enum.UserInputState.Begin, Mock.Input(Enum.UserInputType.Keyboard, Enum.KeyCode.F))
	Mock.Advance(0.3)
	check(PlacementController.Active and PlacementController.ShadeId == Config.Shades[1].Id, "F starts placing the best shade")
	check(DigController.Enabled == false, "digging paused while placing")
	local bar = survivalGui:FindFirstChild("PlacementBar", true)
	check(bar ~= nil and bar.Visible, "placement bar (Turn / Place / Cancel) visible")
	PlacementController.Update()
	check(PlacementController.Valid, "ghost on the sand is valid (" .. tostring(PlacementController.Reason) .. ")")
	local ghostPos = PlacementController.Position
	check(ghostPos ~= nil and math.abs(ghostPos.Y - Config.SURFACE_Y) < 3, "ghost sits on the visible surface")
	PlacementController.Rotate()
	check(PlacementController.Yaw > 0, "R rotates the ghost")
	local click = Mock.Input(Enum.UserInputType.MouseButton1)
	Mock.FireEvent(Mock.Service("UserInputService"), "InputBegan", click, false)
	Mock.Advance(0.3)
	local placedArgs = sent("PlaceShade", s2)
	check(#placedArgs == 1 and placedArgs[1][1] == Config.Shades[1].Id and Mock.typeof(placedArgs[1][2]) == "Vector3", "click sends PlaceShade(id, position, yaw)")
	check(#sent("Dig", s2) == 0, "placing a shade does not dig")
	check(not PlacementController.Active and DigController.Enabled == true, "placement ends, digging resumes")
	-- invalid spot (sky) and cancel
	PlacementController.Begin(Config.Shades[1].Id)
	camera.CFrame = CFrame.lookAt(target + Vector3.new(0, 14, 16), target + Vector3.new(0, 40, 0))
	PlacementController.Update()
	local s3 = #Mock.Remote.ToServer
	check(not PlacementController.Confirm(), "pointing at the sky can't place")
	check(#sent("PlaceShade", s3) == 0, "invalid placement sends nothing")
	Mock.Env.task.spawn(Mock.Actions.SurvivalPlaceCancel.Fn, "SurvivalPlaceCancel", Enum.UserInputState.Begin, Mock.Input(Enum.UserInputType.Keyboard, Enum.KeyCode.B))
	Mock.Advance(0.3)
	check(not PlacementController.Active and Mock.Actions.SurvivalPlaceCancel == nil, "B cancels placement")

	-- world prompts: fountain drinks, stall opens the shop
	for tag, expect in { WaterFountain = "DrinkFountain", BeachShop = "BeachShop" } do
		local part = Mock.Tagged(tag)[1]
		local prompt = part and part:FindFirstChildWhichIsA("ProximityPrompt", true)
		if check(prompt ~= nil, tag .. " has a ProximityPrompt") then
			Panel.CloseAll()
			Mock.Advance(0.3)
			local s4 = #Mock.Remote.ToServer
			Mock.FireEvent(prompt, "Triggered", player)
			Mock.Advance(0.5)
			if expect == "DrinkFountain" then
				check(#sent("DrinkFountain", s4) == 1, "fountain prompt sends DrinkFountain")
			else
				check(Panel.Current() == "BeachShop", "BeachShop prompt opens the Beach Shop")
			end
		end
	end
	Panel.CloseAll()
	Mock.Advance(0.5)
	check(#Mock.Errors == e0, "survival client flow without errors")
end

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
