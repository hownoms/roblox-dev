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
	local menuNames = { "Shop", "Beach", "Eggs", "Pets", "Index", "Quests", "Daily", "Rebirth", "Store", "Settings" }
	local menuPanels = { Beach = "BeachShop" }
	for _, name in menuNames do
		check(HUD.Buttons[name] ~= nil, "HUD menu button " .. name)
	end
	check(HUD.Buttons.Garage == nil, "no Garage menu button (v2.1)")
	do
		local menuFrame = playerGui:FindFirstChild("Dig_HUD"):FindFirstChild("Canvas"):FindFirstChild("Menu")
		local buttons = 0
		for _, child in menuFrame:GetChildren() do
			if child:IsA("GuiObject") then
				buttons += 1
			end
		end
		check(buttons == 10, "HUD menu has 10 buttons (" .. buttons .. ")")
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

-- Companions (v2.1): crates in the egg panel, dig badges, digging pets, crate yard prompt ------------
section("companions")
do
	local PetFollowController =
		Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/PetFollowController"])
	local HatchAnimation = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/HatchAnimation"])
	local e0 = #Mock.Errors
	check(Panel.Get("Garage") == nil, "Garage panel is gone")
	local crate, topCrate
	for _, egg in Config.Eggs do
		if egg.Kind == "Crate" then
			crate = crate or egg
			topCrate = egg
		end
	end
	Mock.FireClientEvent("DataChanged", { Coins = 1e12, MaxDepth = Config.TOTAL_DEPTH })
	Mock.Advance(0.5)

	-- Egg panel: crates are listed, drawn as crates, with dig stats in the odds
	Panel.CloseAll()
	Mock.Advance(0.3)
	Panel.Open("Eggs", { EggId = topCrate.Id })
	Mock.Advance(1)
	local window = Panel.Get("Eggs").Window
	check(Panel.Current() == "Eggs" and #Mock.Errors == e0, "egg panel opens on a crate")
	local kind = window:FindFirstChild("Kind", true)
	check(kind ~= nil and string.find(kind.Text, "Construction Crate", 1, true) ~= nil, "crate detail says Construction Crate")
	local digRows, rideRow = 0, false
	for _, d in window:GetDescendants() do
		if d:IsA("TextLabel") and d.Name == "Dig" and string.find(d.Text, "digs", 1, true) then
			digRows += 1
			if string.find(d.Text, "Rideable", 1, true) then
				rideRow = true
			end
		end
	end
	check(digRows == #topCrate.Pets, "every crate odds row shows dig stats (" .. digRows .. ")")
	check(rideRow, "the rideable Mythic is marked in the odds")
	local view = window:FindFirstChild("Detail", true)
	local vp = view and view:FindFirstChildWhichIsA("ViewportFrame", true)
	local crateModel = vp and vp:FindFirstChildWhichIsA("Model")
	check(crateModel ~= nil and crateModel:GetAttribute("Crate") == true and crateModel:FindFirstChild("Lid") ~= nil, "crate art (with a lid) in the preview")
	local s0 = #Mock.Remote.ToServer
	for _, d in window:GetDescendants() do
		if d:IsA("GuiButton") and d:IsDescendantOf(window:FindFirstChild("Detail", true)) then
			for _, label in d:GetDescendants() do
				if label:IsA("TextLabel") and string.find(label.Text, "Open 1", 1, true) then
					Mock.FireEvent(d, "Activated", Mock.Input(Enum.UserInputType.MouseButton1), 1)
					break
				end
			end
		end
	end
	Mock.Advance(0.5)
	local hatches = sent("HatchEgg", s0)
	check(#hatches >= 1 and hatches[1][1] == topCrate.Id, "Open 1 sends HatchEgg(crateId)")
	Panel.CloseAll()
	Mock.Advance(0.5)

	-- Crate hatch animation: lid pops off, no errors
	HatchAnimation.SetPendingEgg(crate.Id)
	HatchAnimation.Play({ crate.Pets[1].PetId })
	Mock.Advance(5)
	check(#Mock.Errors == e0, "crate opening animation runs without errors")

	-- Pets panel: dig + ride badges and dig stats
	local vuid, muid = "{00000002-0000-4000-8000-000000000002}", "{00000003-0000-4000-8000-000000000003}"
	Mock.FireClientEvent("DataChanged", {
		Pets = {
			[vuid] = { Id = "mini_excavator", Equipped = true },
			[muid] = { Id = "mega_excavator", Equipped = false },
		},
	})
	Mock.Advance(0.5)
	Panel.Open("Pets", {})
	Mock.Advance(1)
	local petsWindow = Panel.Get("Pets").Window
	local digBadges, rideBadges = 0, 0
	for _, d in petsWindow:GetDescendants() do
		if d:IsA("TextLabel") and d.Name == "Badges" then
			if string.find(d.Text, "⛏", 1, true) then
				digBadges += 1
			end
			if string.find(d.Text, "🚜", 1, true) then
				rideBadges += 1
			end
		end
	end
	check(digBadges == 2 and rideBadges == 1, "⛏ badge on digging pets, 🚜 on rideable (" .. digBadges .. "/" .. rideBadges .. ")")
	local digInfo = petsWindow:FindFirstChild("DigInfo", true)
	check(digInfo ~= nil and string.find(digInfo.Text, "digs to", 1, true) ~= nil, "selected digging pet shows its dig stats")
	Panel.CloseAll()
	Mock.Advance(0.5)

	-- Digging pets: vehicle follows on the ground, drives (no teleport) to its spot, digs, parks
	local root = player.Character.HumanoidRootPart
	player.Character:PivotTo(CFrame.new(zone.CFrame.Position + Vector3.new(-40, 3, 0)))
	Mock.Advance(0.5)
	player:SetAttribute("EquippedPets", "mini_excavator,sandy_crab")
	Mock.Advance(4)
	local visuals = PetFollowController.GetVisuals(player)
	check(#visuals == 2, "two pets rendered (" .. #visuals .. ")")
	local vehicle
	for _, v in visuals do
		if v.Vehicle then
			vehicle = v
		end
	end
	if check(vehicle ~= nil and vehicle.Id == "mini_excavator", "vehicle pet flagged as a vehicle") then
		local model = vehicle.Model
		check(model.Parent ~= nil and model.Parent.Name == "ClientPets", "vehicle pet in ClientPets")
		local size = model:GetExtentsSize()
		check(math.max(size.X, size.Z) >= 2.5 and math.max(size.X, size.Z) <= 6, "vehicle at pet scale (" .. tostring(size) .. ")")
		local offset = model:GetPivot().Position - root.Position
		check(Vector3.new(offset.X, 0, offset.Z).Magnitude < 16, "vehicle follows its owner")
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and (part.CanCollide or part.CanQuery) then
				check(false, "pet parts never collide / block raycasts: " .. part.Name)
				break
			end
		end
		local target = root.Position + Vector3.new(9, -3, 0)
		local before = model:GetPivot().Position
		Mock.FireClientEvent("PetDug", player, vehicle.Slot, vehicle.Id, target, 12)
		Mock.Advance(0.05)
		local step = (model:GetPivot().Position - before).Magnitude
		check(step < 3, string.format("no teleport: the vehicle drives (moved %.2f in one frame)", step))
		Mock.Advance(1.8)
		local p = model:GetPivot().Position
		check((Vector3.new(p.X, target.Y, p.Z) - target).Magnitude < 4.5, "vehicle drove to its dig spot")
		local now = PetFollowController.GetVisuals(player)
		local still
		for _, v in now do
			if v.Vehicle then
				still = v
			end
		end
		check(still ~= nil and (still.Digging or still.Parked), "vehicle digs / stays at its spot")
		local ownerFlat = Vector3.new(root.Position.X, 0, root.Position.Z)
		check((Vector3.new(p.X, 0, p.Z) - ownerFlat).Magnitude >= 5, "the vehicle parks away from the owner")
		-- owner walks off: the pet follows again
		player.Character:PivotTo(player.Character:GetPivot() + Vector3.new(-14, 0, 0))
		Mock.Advance(2)
		for _, v in PetFollowController.GetVisuals(player) do
			if v.Vehicle then
				check(not v.Parked and not v.Digging, "vehicle stops parking when the owner leaves")
			end
		end
		check(#Mock.Errors == e0, "PetDug animation runs without errors")
	end
	Mock.FireClientEvent("PetDug", player, 9, "unknown", root.Position, 1)
	Mock.FireClientEvent("PetDug", "junk")
	Mock.Advance(0.5)
	check(#Mock.Errors == e0, "bad PetDug payloads are ignored")
	player:SetAttribute("EquippedPets", "")
	Mock.Advance(0.5)
	check(#PetFollowController.GetVisuals(player) == 0, "pets removed when unequipped")

	-- Crate yard pallet prompt opens the egg panel on that crate
	local pallet = Mock.Tagged("CrateShop")[1]
	if not pallet then
		pallet = Mock.Env.Instance.new("Part")
		pallet.Name = "CratePallet"
		pallet:SetAttribute("EggId", crate.Id)
		local prompt = Mock.Env.Instance.new("ProximityPrompt")
		prompt:SetAttribute("EggId", crate.Id)
		prompt.Parent = pallet
		pallet.Parent = Mock.Service("Workspace")
		Mock.Service("CollectionService"):AddTag(pallet, "CrateShop")
		Mock.Advance(0.2)
	end
	local prompt = pallet:FindFirstChildWhichIsA("ProximityPrompt", true)
	if check(prompt ~= nil, "crate pallet has a ProximityPrompt") then
		Panel.CloseAll()
		Mock.Advance(0.3)
		Mock.FireEvent(prompt, "Triggered", player)
		Mock.Advance(0.5)
		check(Panel.Current() == "Eggs", "crate pallet prompt opens the egg panel")
	end
	Panel.CloseAll()
	Mock.Advance(0.5)
	check(#Mock.Errors == e0, "companions client section ran without errors")
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
	-- the Buy clicks above were pending: the purchase confirmation jumps straight into placing
	check(PlacementController.Active and Panel.Current() == nil, "buying a shade starts placing it")
	PlacementController.Cancel()
	Mock.Advance(0.2)
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
	check(not PlacementController.Active and DigController.Enabled == false, "digging stays paused while the click is held")
	Mock.FireEvent(Mock.Service("UserInputService"), "InputEnded", click, false)
	Mock.Advance(0.3)
	check(#sent("Dig", s2) == 0 and DigController.Enabled == true, "digging resumes after release, no stray dig")
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

-- Shovel pose: two-handed IK hold, scoop on click / remote, one-handed scoop, R6 skip -------------
section("shovel pose")
do
	local Models = Mock.Require(byPath["ReplicatedStorage/Shared/Models"])
	local Pose = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/ShovelPoseController"])
	local e0 = #Mock.Errors
	local Instance = Mock.Env.Instance

	-- the Tool exactly like ShopService builds it
	local function makeTool(id)
		local model = Models.Shovel(id)
		local handle = model.PrimaryPart
		local tool = Instance.new("Tool")
		tool.Name = id
		tool:SetAttribute("ShovelId", id)
		tool.Grip = handle:GetAttribute("GripOffset")
		tool:SetAttribute("TwoHanded", handle:GetAttribute("TwoHanded") == true)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
			end
		end
		handle.Name = "Handle"
		handle.Parent = tool
		model.PrimaryPart = nil
		model.Parent = tool
		return tool
	end

	-- model attributes
	local hand, full = Config.Shovels[1], Config.Shovels[3]
	check(hand.Look.Size == "Hand" and full.Look.Size == nil, "tier 1 is a hand tool, tier 3 is full size")
	for _, def in Config.Shovels do
		local h = Models.Shovel(def.Id).PrimaryPart
		local two = h:GetAttribute("TwoHanded")
		check(
			Mock.typeof(h:GetAttribute("GripOffset")) == "CFrame"
				and Mock.typeof(h:GetAttribute("ShaftAxis")) == "Vector3"
				and Mock.typeof(h:GetAttribute("CupAxis")) == "Vector3"
				and Mock.typeof(h:GetAttribute("BladePoint")) == "Vector3"
				and two == (def.Look.Size ~= "Hand")
				and (Mock.typeof(h:GetAttribute("LeftHand")) == "Vector3") == two,
			"shovel model pose attributes: " .. def.Id
		)
	end

	-- forward kinematics of the mock rig (UpperTorso space), like the engine solves Motor6Ds
	local function chain(rig, s)
		local sh, el, wr = rig[s .. "Shoulder"], rig[s .. "Elbow"], rig[s .. "Wrist"]
		local a1 = sh.C0 * sh.Transform * sh.C1:Inverse()
		local a2 = a1 * el.C0 * el.Transform * el.C1:Inverse()
		local a3 = a2 * wr.C0 * wr.Transform * wr.C1:Inverse()
		return a3, { sh, el, wr }
	end
	local function poseReport(rig, tool)
		local r = {}
		local rightHand, rightJoints = chain(rig, "Right")
		local leftHand, leftJoints = chain(rig, "Left")
		local handle = rightHand * rig.RightGripAttachment.CFrame * tool.Grip:Inverse()
		local h = tool.Handle
		local palm = handle * tool.Grip.Position
		local axis = handle:VectorToWorldSpace(h:GetAttribute("ShaftAxis"))
		local leftPalm = leftHand * rig.LeftGripAttachment.Position
		local rel = leftPalm - palm
		r.LeftOffShaft = (rel - axis * rel:Dot(axis)).Magnitude
		r.LeftAlong = rel:Dot(axis)
		r.MaxJointSlip = 0
		for _, m in { rightJoints[1], rightJoints[2], rightJoints[3], leftJoints[1], leftJoints[2], leftJoints[3] } do
			r.MaxJointSlip = math.max(r.MaxJointSlip, m.Transform.Position.Magnitude)
		end
		r.ElbowHinge = rig.RightElbow.Transform.RightVector:Dot(Vector3.xAxis)
		r.Blade = handle * h:GetAttribute("BladePoint")
		r.Palm = palm
		r.Shoulder = rig.RightShoulder.C0.Position
		return r
	end

	-- two-handed hold on the local R15 character
	local char = player.Character
	local rig = Mock.MakeR15(char)
	local tool = makeTool(full.Id)
	tool.Parent = char
	Mock.Advance(0.5)
	local dbg = Pose.GetDebug(char)
	check(dbg ~= nil and dbg.Posed and dbg.TwoHanded and dbg.Weight == 1, "two-handed shovel posed on an R15 character")
	local r = poseReport(rig, tool)
	check(r.LeftOffShaft < 0.05, "left palm grips the shaft (" .. r.LeftOffShaft .. " studs off)")
	check(r.LeftAlong > 0.4 and r.LeftAlong < 1.6, "left hand below the right on the shaft (" .. r.LeftAlong .. ")")
	check(r.MaxJointSlip < 1e-3, "arm joints stay connected (" .. r.MaxJointSlip .. ")")
	check(r.ElbowHinge > 0.999, "right elbow bends as a hinge about its X axis")
	check(r.Blade.Y < r.Palm.Y - 1 and r.Blade.Z < r.Palm.Z - 1, "blade rests down and in front of the hands")
	check(rig.Waist.Transform ~= CFrame.identity, "waist twists into the digging stance")
	check(not Pose.IsScooping(char), "no scoop at rest")

	-- the scoop plays on click, before any server reply
	local c = zone.CFrame.Position
	char:PivotTo(CFrame.new(c + Vector3.new(0, 3, 6)))
	local cam = Mock.Service("Workspace").CurrentCamera
	cam.CFrame = CFrame.lookAt(c + Vector3.new(0, 14, 16), c)
	Mock.Advance(1)
	local rest = rig.RightShoulder.Transform
	local restBlade = r.Blade
	local s0 = #Mock.Remote.ToServer
	local UIS = Mock.Service("UserInputService")
	local click = Mock.Input(Enum.UserInputType.MouseButton1)
	Mock.FireEvent(UIS, "InputBegan", click, false)
	Mock.FireEvent(UIS, "InputEnded", click, false)
	check(#sent("Dig", s0) == 1, "click digs")
	check(Pose.IsScooping(char), "scoop starts on the click")
	local lowest, highest, clump, moved = math.huge, -math.huge, false, false
	for _ = 1, 14 do
		Mock.Advance(1 / 30)
		local rr = poseReport(rig, tool)
		lowest = math.min(lowest, rr.Blade.Y)
		highest = math.max(highest, rr.Blade.Y)
		check(rr.LeftOffShaft < 0.05 and rr.MaxJointSlip < 1e-3, "hands stay on the shaft during the scoop")
		local fx = Mock.Service("Workspace"):FindFirstChild("ShovelEffects")
		clump = clump or (fx ~= nil and fx:FindFirstChild("SandClump") ~= nil)
		moved = moved or rig.RightShoulder.Transform ~= rest
	end
	check(lowest < restBlade.Y - 0.3, "scoop thrusts the blade down (" .. lowest - restBlade.Y .. ")")
	check(highest > restBlade.Y + 0.5, "scoop lifts the blade up (" .. highest - restBlade.Y .. ")")
	check(clump, "a sand clump rides the blade")
	check(moved, "arms move during the scoop")
	Mock.Advance(1)
	check(not Pose.IsScooping(char), "scoop finishes")
	-- remote scoop (server AutoDig digs come back to the digger too)
	Mock.FireClientEvent("Scoop", player)
	Mock.Advance(0.05)
	check(Pose.IsScooping(char), "Scoop remote plays the scoop")
	Mock.FireClientEvent("Scoop", "junk")
	Mock.Advance(1)

	-- another player: one-handed hand spade, scoop broadcast from the server
	local other = Mock.AddPlayer(2002, "Other")
	local otherChar = Mock.SpawnCharacter(other, c + Vector3.new(6, 3, 6))
	local otherRig = Mock.MakeR15(otherChar)
	local spade = makeTool(hand.Id)
	spade.Parent = otherChar
	Mock.Advance(0.3)
	check(not Pose.GetDebug(otherChar).Posed, "hand spade at rest keeps the hold animation")
	Mock.FireClientEvent("Scoop", other)
	Mock.Advance(0.2)
	local od = Pose.GetDebug(otherChar)
	check(od.Scooping and od.Posed and not od.TwoHanded, "other player's one-handed scoop plays")
	check(otherRig.LeftShoulder.Transform == CFrame.identity, "one-handed scoop leaves the left arm alone")
	Mock.Advance(1)
	check(not Pose.GetDebug(otherChar).Posed, "one-handed scoop blends back out")
	check(otherRig.RightShoulder.Transform == CFrame.identity, "joints reset after the scoop")

	-- R6 characters are skipped
	otherChar:FindFirstChildOfClass("Humanoid").RigType = Enum.HumanoidRigType.R6
	Mock.SpawnCharacter(other, c + Vector3.new(6, 3, 6))
	makeTool(full.Id).Parent = other.Character
	Mock.Advance(1.5)
	check(Pose.PlayScoop(other.Character) == false, "R6 rig: no procedural scoop")
	check(not Pose.GetDebug(other.Character) or not Pose.GetDebug(other.Character).Posed, "R6 rig is not posed")

	-- unequip resets the local rig
	tool.Parent = player:FindFirstChildOfClass("Backpack")
	Mock.Advance(0.2)
	check(rig.RightShoulder.Transform == CFrame.identity and rig.Waist.Transform == CFrame.identity, "unequip resets joints")
	check(#Mock.Errors == e0, "shovel pose without errors")
	Mock.RemovePlayer(other)
	Mock.Advance(0.5)
end

-- Ride-on excavator (Ride agent): Ride button, toggle, driving, ride digs ---------------------------
section("ride")
do
	local e0 = #Mock.Errors
	local RideController =
		Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/RideController"])
	local RideButton = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/RideButton"])
	local DigController = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/DigController"])
	local Models = Mock.Require(byPath["ReplicatedStorage/Shared/Models"])
	local Panel2 = Panel
	Panel2.CloseAll()
	Mock.Advance(0.3)
	local gui = playerGui:FindFirstChild("Dig_Ride")
	check(gui ~= nil and gui:IsA("ScreenGui"), "Ride ScreenGui Dig_Ride")
	local ride = RideButton.Ride
	check(ride ~= nil and ride.Holder.Name == "RideButton", "Ride button built")

	-- hidden without a rideable pet
	Mock.FireClientEvent("DataChanged", { Pets = {} })
	Mock.Advance(0.5)
	check(ride.Holder.Visible == false, "Ride button hidden without a rideable pet")
	local s0 = #Mock.Remote.ToServer
	Mock.Actions.RideToggle.Fn("RideToggle", Enum.UserInputState.Begin, Mock.Input(Enum.UserInputType.Keyboard, Enum.KeyCode.V))
	Mock.Advance(0.2)
	check(#sent("ToggleRide", s0) == 0, "V does nothing without a rideable pet")

	local def
	for _, p in Config.Pets do
		if p.Rideable == true then
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
				BodyColor = Mock.Env.Color3.fromRGB(255, 190, 20),
				AccentColor = Mock.Env.Color3.fromRGB(255, 90, 160),
				Shape = "Blob",
				Size = 1,
				Glow = false,
			},
		}
		table.insert(Config.Pets, def)
		injected = true
	end
	Mock.FireClientEvent("DataChanged", { Pets = { r1 = { Id = def.Id, Equipped = false } } })
	Mock.Advance(0.5)
	check(ride.Holder.Visible == true, "Ride button appears with a rideable pet")
	check(ride.Label.Text == "Ride", "Ride button says Ride")
	s0 = #Mock.Remote.ToServer
	Mock.FireEvent(ride.Face, "Activated", Mock.Input(Enum.UserInputType.MouseButton1), 1)
	Mock.Advance(0.2)
	check(#sent("ToggleRide", s0) == 1, "Ride button fires ToggleRide")
	Mock.Actions.RideToggle.Fn("RideToggle", Enum.UserInputState.Begin, Mock.Input(Enum.UserInputType.Keyboard, Enum.KeyCode.V))
	Mock.Advance(0.2)
	check(#sent("ToggleRide", s0) == 2, "V fires ToggleRide")

	-- the "server" spawns the vehicle and seats us
	local workspace = Mock.Service("Workspace")
	local folder = Mock.Env.Instance.new("Folder")
	folder.Name = "Rides"
	folder.Parent = workspace
	local vehicle = Models.RideVehicle(def.Id)
	vehicle.Name = "Ride_" .. player.UserId
	vehicle:SetAttribute("OwnerUserId", player.UserId)
	vehicle:SetAttribute("DigInterval", 0.5)
	local start = CFrame.new(40, Config.SURFACE_Y + Config.Ride.HoverHeight, zone.CFrame.Position.Z)
	vehicle:PivotTo(start)
	vehicle.Parent = folder
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	local digWasEnabled = DigController.Enabled
	vehicle.RideSeat:Sit(humanoid)
	Mock.Advance(0.3)
	check(RideController.Riding == true, "riding detected from the seat")
	check(ride.Label.Text == "Exit", "button turns into Exit while riding")
	check(DigController.Enabled == false, "shovel digging paused while riding")

	-- hold dig -> RideDig at the vehicle's DigInterval
	s0 = #Mock.Remote.ToServer
	RideController.SetDigHeld(true)
	Mock.Advance(1.2)
	RideController.SetDigHeld(false)
	local digs = #sent("RideDig", s0)
	check(digs >= 2 and digs <= 3, "holding Dig sends RideDig every DigInterval (" .. digs .. ")")
	Mock.Advance(1)
	check(#sent("RideDig", s0) == digs, "releasing Dig stops RideDig")

	-- drive forward (towards the sea): the target moves, stays on the surface and in the area
	local ap = vehicle.PrimaryPart.RideAlignPosition
	local ao = vehicle.PrimaryPart.RideAlignOrientation
	-- stand-in for physics: the assembly follows its constraint targets
	local follow = Mock.Service("RunService").Heartbeat:Connect(function()
		if vehicle.Parent then
			vehicle:PivotTo(CFrame.new(ap.Position) * ao.CFrame.Rotation)
		end
	end)
	Mock.AllowRestricted = { MoveDirection = true }
	humanoid.MoveDirection = Vector3.new(0, 0, -1)
	Mock.Advance(1)
	check(ap.Position.Z < start.Position.Z - 4, "driving forward moves the AlignPosition target (" .. tostring(ap.Position) .. ")")
	check(math.abs(ap.Position.Y - start.Position.Y) < 0.6, "target stays on the surface")
	Mock.Advance(6)
	local minZ = zone.CFrame.Position.Z - zone.Size.Z / 2 + Config.Ride.EdgeMargin
	check(ap.Position.Z >= minZ - 0.01 and ap.Position.Z < minZ + 1, "target clamped to the ride area (" .. ap.Position.Z .. ")")
	humanoid.MoveDirection = Vector3.new(1, 0, 0)
	Mock.Advance(0.5)
	check(ao.CFrame.LookVector:Dot(Vector3.new(0, 0, -1)) < 0.99, "steering turns the vehicle")
	humanoid.MoveDirection = Vector3.zero
	Mock.AllowRestricted = nil
	follow:Disconnect()

	-- RideDug: bucket scoop + burst on every client
	Mock.FireClientEvent("RideDug", player, start.Position + Vector3.new(0, 0, -11), true, 1)
	Mock.Advance(0.4)
	local boom = vehicle:FindFirstChild("BoomMotor", true)
	check(boom ~= nil and boom.Transform ~= CFrame.identity, "bucket scoop animates the arm")
	Mock.Advance(1.2)
	Mock.FireClientEvent("RideDug", "junk")
	Mock.FireClientEvent("RideDug", player, start.Position, false, 99)
	Mock.Advance(1.5)

	-- jump out
	Mock.LeaveSeat(humanoid)
	Mock.Advance(0.3)
	check(RideController.Riding == false, "leaving the seat stops riding")
	check(ride.Label.Text == "Ride", "button back to Ride")
	check(DigController.Enabled == digWasEnabled, "shovel digging restored")
	vehicle:Destroy()
	folder:Destroy()
	Mock.FireClientEvent("DataChanged", { Pets = {} })
	Mock.Advance(0.3)
	check(ride.Holder.Visible == false, "Ride button hides when the pet is gone")
	if injected then
		table.remove(Config.Pets, table.find(Config.Pets, def))
	end
	check(#Mock.Errors == e0, "ride client flow without errors")
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
