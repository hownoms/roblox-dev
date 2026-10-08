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
local Vector2 = Mock.Vector2
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
-- v2.3 streaming: the server publishes station anchors + Atomic station models (StreamingService)
local StreamingService = Mock.Require(byPath["ServerScriptService/Server/Services/StreamingService"])
StreamingService.Init()
Mock.Advance(0.1)
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

-- A successful click can reach sand while the character still stands on the boardwalk.
check(not State.InDigZone(character.HumanoidRootPart.Position), "first-dig regression starts outside the sand footprint")
Mock.FireClientEvent("DigResult", { Success = true, Position = sand, LayerIndex = 1, SandGained = 1, Sand = 1, Capacity = 20 })
Mock.Advance(1)
check(State.GetSetting("Tutorial", 0) == 2, "confirmed boardwalk dig advances arrival and first-dig steps")

-- Discovery introduction uses the existing objective without renumbering saved steps.
do
	local objectiveText = playerGui:FindFirstChild("Objective", true):FindFirstChild("Text")
	check(not objectiveText.Text:find("SCAN"), "before first find the fill-bucket objective stays focused")
	Mock.FireClientEvent("DataChanged", { Index = { [Config.Treasures[1].Id] = true } })
	Mock.Advance(0.5)
	check(objectiveText.Text:find("SCAN") ~= nil, "first indexed find introduces Scan in existing objective")
	check(State.GetSetting("Tutorial", 0) == 2, "Scan introduction preserves numeric tutorial progress")
	Mock.FireClientEvent("DetectorPing", { Band = 0, Sector = -1, Vertical = "", Signal = "", Remaining = 0 })
	Mock.Advance(0.5)
	check(objectiveText.Text:find("SCAN") ~= nil, "expired detector ping does not acknowledge first scan")
	Mock.FireClientEvent("DetectorPing", { Band = 0, Sector = -1, Vertical = "", Signal = "", Remaining = 6 })
	Mock.Advance(0.5)
	check(
		State.GetSetting("TutorialScanUsed", false) == true,
		"server scan response persists introduction completion even without a find signal"
	)
	check(not objectiveText.Text:find("SCAN"), "acknowledged scan restores fill-bucket objective")
	check(State.GetSetting("Tutorial", 0) == 2, "first scan does not advance a numbered tutorial step")
	Mock.FireClientEvent("DataChanged", { Index = {} })
	Mock.FireClientEvent("DetectorPing", { Band = 0, Sector = -1, Vertical = "", Signal = "", Remaining = 0 })
end

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
	local menuNames = { "Shop", "Beach", "Eggs", "Pets", "Index", "Quests", "Rebirth", "Store" }
	local menuPanels = { Beach = "BeachShop", Daily = "Daily", Settings = "Settings", Shop = "Shop" }
	for _, name in menuNames do
		check(HUD.Buttons[name] ~= nil, "HUD menu button " .. name)
	end
	check(HUD.Buttons.Daily ~= nil and HUD.Buttons.Settings ~= nil, "Daily + Settings round buttons exist")
	check(HUD.Buttons.Garage == nil, "no Garage menu button (v2.1)")
	local hudCanvas = playerGui:FindFirstChild("Dig_HUD"):FindFirstChild("Canvas")
	local topRight = hudCanvas:FindFirstChild("TopRight")
	local menu = hudCanvas:FindFirstChild("Menu")
	local depth = hudCanvas:FindFirstChild("Depth")
	do
		local buttons = 0
		for _, child in menu:GetChildren() do
			if child:IsA("GuiObject") then
				buttons += 1
			end
		end
		check(buttons == #menuNames, "HUD menu has " .. #menuNames .. " buttons (" .. buttons .. ")")
		check(
			HUD.Buttons.Daily.Holder.Parent == topRight and HUD.Buttons.Settings.Holder.Parent == topRight,
			"Daily + Settings live in the top-right currency cluster"
		)
		check(topRight:FindFirstChild("Coins") ~= nil and topRight:FindFirstChild("Tokens") ~= nil, "currency pills top-right")
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

	-- Layout (UI/Layout.luau): no overlaps between the HUD regions at phone, tablet and PC sizes
	-- (design px = logical px / UI scale), phone thumbstick + jump zones kept clear.
	local Layout = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/Layout"])
	local current = Layout.Current()
	local function sameRect(inst, r)
		return inst.Position.X.Offset == r.X and inst.Position.Y.Offset == r.Y and inst.Size.X.Offset == r.W and inst.Size.Y.Offset == r.H
	end
	check(sameRect(topRight, current.TopRight), "TopRight cluster placed by Layout")
	check(sameRect(menu, current.Menu), "menu placed by Layout")
	check(sameRect(depth, current.Depth), "depth meter placed by Layout")
	local survivalHolder = playerGui:FindFirstChild("Dig_Survival"):FindFirstChild("SurvivalHUD", true)
	check(survivalHolder ~= nil and sameRect(survivalHolder, current.Survival), "SurvivalHUD placed by Layout")
	local sizes = {
		-- phones (landscape, after the top bar / notch insets) and the 800x360 reference phone
		{ 1187, 503, "phone" }, { 1200, 540, "phone" }, { 1219, 540, "phone" }, { 1333, 503, "phone" }, { 1333, 540, "phone" },
		-- tablet
		{ 1000, 750, "phone" }, { 1000, 768, "phone" },
		-- PC windows and 1920x1080 (scale 1.35)
		{ 1000, 540, "pc" }, { 1044, 540, "pc" }, { 1422, 757, "pc" }, { 1422, 800, "pc" }, { 1600, 900, "pc" },
	}
	local names = { "TopRight", "Menu", "Depth", "Centre", "Survival", "Social", "Bottom", "Ride", "RideDig" }
	for _, entry in sizes do
		local W, H, kind = entry[1], entry[2], entry[3]
		local r = Layout.Compute(Mock.Env.Vector2.new(W, H))
		local tag = W .. "x" .. H
		for i = 1, #names do
			local a = r[names[i]]
			check(a.X >= 0 and a.Y >= 0 and a.X + a.W <= W and a.Y + a.H <= H, tag .. ": " .. names[i] .. " on screen")
			for j = i + 1, #names do
				local b = r[names[j]]
				check(not Layout.Overlaps(a, b), tag .. ": " .. names[i] .. " does not overlap " .. names[j])
			end
		end
		check(r.Centre.W >= 340, tag .. ": top-centre column >= 340 wide (" .. r.Centre.W .. ")")
		if kind == "phone" then
			local thumb = { X = 0, Y = H - 190, W = 260, H = 190 }
			local jump = { X = W - 170, Y = H - 160, W = 170, H = 160 }
			for _, n in { "TopRight", "Menu", "Depth", "Centre", "Survival", "Social", "Ride", "RideDig", "Bottom" } do
				check(not Layout.Overlaps(r[n], thumb), tag .. ": " .. n .. " clear of the thumbstick")
				check(not Layout.Overlaps(r[n], jump), tag .. ": " .. n .. " clear of the jump button")
			end
		end
	end
	check(Layout.MENU_CELL >= 74, "menu cells >= 74 design px (44 px on phones at scale 0.6)")
	local round = HUD.Buttons.Daily.Holder
	local hit = round:FindFirstChild("HitArea")
	check(hit ~= nil and round.Size.X.Offset + hit.Size.X.Offset >= 74, "round Daily button has a >= 74 px touch area")
	for _, name in { "Surface", "Sell", "AutoDig" } do
		check(HUD.Buttons[name].Holder.Size.Y.Offset >= 74, name .. " button >= 74 design px")
	end

	-- Icons: atlas-driven component everywhere (emoji fallback while IconAtlas.AssetId == "")
	local AtlasIcon = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/Components/AtlasIcon"])
	local _, emoji = AtlasIcon.Resolve("Coins")
	check(emoji == "💰", "AtlasIcon falls back to the Icons.luau emoji")
	local _, shellEmoji = AtlasIcon.Resolve("Layers.shell_bed")
	check(shellEmoji == "🐚", "AtlasIcon resolves grouped keys")
	local _, rawEmoji = AtlasIcon.Resolve("🛒")
	check(rawEmoji == "🛒", "AtlasIcon keeps raw emoji")
	local loadingIcon = AtlasIcon.new({ Icon = "Coins", Parent = hudCanvas })
	local loadingImage = loadingIcon.Frame:FindFirstChild("Image")
	local loadingFallback = loadingIcon.Frame:FindFirstChild("Emoji")
	check(loadingImage ~= nil and loadingFallback ~= nil, "configured atlas retains a loading fallback")
	check(loadingFallback ~= nil and loadingFallback.Visible, "unavailable atlas leaves the control icon readable")
	check(loadingImage ~= nil and loadingImage.Visible, "loading atlas image stays renderable to start the texture request")
	Mock.LoadImage(loadingImage)
	Mock.Advance(0.3)
	check(loadingFallback ~= nil and not loadingFallback.Visible, "cached image completion clears fallback without a property signal")
	loadingIcon:Set("🛰️")
	check(loadingImage ~= nil and not loadingImage.Visible, "switching to a raw icon hides the atlas image")
	check(loadingFallback ~= nil and loadingFallback.Visible, "switching away from a loaded atlas restores the raw icon")
	loadingIcon.Frame:Destroy()
	local icons = 0
	for _, d in hudCanvas:GetDescendants() do
		if d:IsA("Frame") and d:GetAttribute("Icon") ~= nil then
			icons += 1
		end
	end
	check(icons >= 14, "HUD icons use AtlasIcon (" .. icons .. ")")

	-- Objective banner (tutorial) top-centre, inside the centre column
	local objective = hudCanvas:FindFirstChild("Objective")
	check(objective ~= nil and objective.Visible, "tutorial objective pill visible")
	check(objective ~= nil and sameRect(objective, current.Banner), "objective pill placed in the Banner region")
	local objectiveText = objective and objective:FindFirstChild("Text")
	check(objectiveText ~= nil and objectiveText.Text ~= "", "objective pill has a line (" .. tostring(objectiveText and objectiveText.Text) .. ")")
	check(playerGui:FindFirstChild("Tutorial", true) == nil, "old big tutorial bar is gone")
	local savedSand = State.Data.Sand
	local savedMotion = State.GetSetting("ReducedMotion", false)
	State.SetSetting("ReducedMotion", false)
	Mock.FireClientEvent("DataChanged", { Sand = State.GetCapacity() })
	Mock.Advance(0.1)
	local bag = hudCanvas:FindFirstChild("Backpack", true)
	local sellArrow = hudCanvas:FindFirstChild("SellArrow", true)
	check(sellArrow.Visible and bag:FindFirstChild("Pop").Scale > 1, "full bag draws attention with motion enabled")
	State.SetSetting("ReducedMotion", true)
	Mock.Advance(0.2)
	check(sellArrow.Visible and sellArrow.Position.Y.Offset == -52 and bag:FindFirstChild("Pop").Scale == 1, "reduced motion keeps full-bag warning visible and static")
	HUD.Flash("Settings", 1)
	check(HUD.Buttons.Settings.Holder:FindFirstChild("Pop") == nil or HUD.Buttons.Settings.Holder.Pop.Scale == 1, "reduced motion suppresses HUD attention pulse")
	State.SetSetting("ReducedMotion", false)
	Mock.Advance(0.1)
	check(sellArrow.Position.Y.Offset == -62 and bag:FindFirstChild("Pop").Scale > 1, "full-bag motion resumes after preference changes")
	Mock.FireClientEvent("DataChanged", { Sand = savedSand })
	State.SetSetting("ReducedMotion", savedMotion)
	Mock.Advance(0.2)

	-- Shop: upgrade rows (icon | current | arrow | next | price), one per item
	local ItemStats = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/ItemStats"])
	check(ItemStats.SandMult(1.5) == "x1.5", "first shovel upgrade retains its fractional sand bonus")
	check(ItemStats.SandMult(2) == "x2" and ItemStats.SandMult(1500) == "x1.5K", "sand bonus keeps compact whole and large values")
	Mock.FireClientEvent("DataChanged", { Coins = 1e9 })
	Mock.Advance(0.3)
	for tab, list in { Shovels = Config.Shovels, Backpacks = Config.Backpacks } do
		Panel.Open("Shop", { Tab = tab })
		Mock.Advance(0.6)
		local scroller = Panel.Get("Shop").Window:FindFirstChild(tab, true)
		local rows, complete, prefix = 0, 0, 0
		for _, row in scroller:GetChildren() do
			if row:IsA("Frame") then
				rows += 1
				local nextBox = row:FindFirstChild("Next", true)
				if row:FindFirstChild("Current", true) and nextBox and row:FindFirstChildWhichIsA("ViewportFrame", true) and row:FindFirstChild("Action", true) then
					complete += 1
				end
				local main = nextBox and nextBox:FindFirstChild("Main")
				if main and string.sub(main.Text, 1, if tab == "Shovels" then 4 else 6) == (if tab == "Shovels" then "Dig " else "Holds ") then
					prefix += 1
				end
			end
		end
		check(rows == #list and complete == #list, tab .. ": one upgrade row per item (" .. rows .. "/" .. complete .. ")")
		check(prefix == #list, tab .. ": next-stat boxes spell out the gain (" .. prefix .. ")")
	end
	-- buying a new shovel shows the Reveal popup
	local popups = playerGui:FindFirstChild("Dig_Popups"):FindFirstChild("Canvas")
	Panel.Open("Shop", { Tab = "Shovels" })
	Mock.Advance(0.6)
	local target = Config.Shovels[2]
	local row = Panel.Get("Shop").Window:FindFirstChild(target.Id, true)
	local s0 = #Mock.Remote.ToServer
	Mock.FireEvent(row:FindFirstChild("Action", true):FindFirstChild("Face"), "Activated", Mock.Input(Enum.UserInputType.MouseButton1), 1)
	Mock.Advance(0.3)
	check(#sent("BuyShovel", s0) == 1, "upgrade row price button sends BuyShovel")
	local owned = {}
	for id in State.Data.OwnedShovels do
		owned[id] = true
	end
	owned[target.Id] = true
	Mock.FireClientEvent("DataChanged", { OwnedShovels = owned })
	Mock.Advance(0.6)
	local reveal = popups:FindFirstChild("Reveal")
	local headline = reveal and reveal:FindFirstChild("Headline", true)
	check(headline ~= nil and headline.Text == "NEW SHOVEL!", "new shovel opens the Reveal popup")
	check(reveal ~= nil and reveal:FindFirstChildWhichIsA("ViewportFrame", true) ~= nil and reveal:FindFirstChild("Stats", true) ~= nil, "reveal card has a model + stat rows")
	Mock.FireEvent(reveal, "Activated", Mock.Input(Enum.UserInputType.MouseButton1), 1)
	Mock.Advance(1)
	check(popups:FindFirstChild("Reveal") == nil, "tap closes the reveal")
	Panel.CloseAll()
	Mock.Advance(0.5)

	-- Daily: 7 day cards in a row, wider jackpot, big CLAIM button
	Panel.Open("Daily", {})
	Mock.Advance(0.6)
	local days = Panel.Get("Daily").Window:FindFirstChild("Days", true)
	local dayCards = {}
	for _, child in days:GetChildren() do
		if child:IsA("Frame") then
			dayCards[child.Name] = child
		end
	end
	check(dayCards.Day1 ~= nil and dayCards.Day7 ~= nil and dayCards.Day7.Size.X.Offset > dayCards.Day1.Size.X.Offset, "7 day cards, Day 7 is the wide jackpot")
	local claim = Panel.Get("Daily").Window:FindFirstChild("Claim", true)
	check(claim ~= nil and claim.Size.Y.Offset >= 74, "big CLAIM button")
	Panel.CloseAll()
	Mock.Advance(0.5)

	-- Treasure finds: compact, non-blocking reveal (no full-screen tap catcher)
	Mock.FireClientEvent("TreasureFound", Config.Treasures[1].Id, Config.Treasures[1].Rarity)
	Mock.Advance(0.5)
	local compact = popups:FindFirstChild("Reveal")
	check(compact ~= nil and compact.ClassName == "Frame", "common treasure uses the compact reveal")
	Mock.Advance(4)
	check(popups:FindFirstChild("Reveal") == nil, "compact reveal auto-closes")

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

	-- Toasts wait while a reveal is on screen (never cover its headline); urgent ones do not.
	do
		local function hasToast(text: string): boolean
			for _, child in toastRoot:GetChildren() do
				if child.Name == "Toast" then
					for _, d in child:GetDescendants() do
						if d:IsA("TextLabel") and string.find(d.Text, text, 1, true) then
							return true
						end
					end
				end
			end
			return false
		end
		Toasts.Show("Index collection notice", "Info", 4)
		check(hasToast("Index collection"), "notice visible before excavation")
		Toasts.SetExcavating(true)
		check(not hasToast("Index collection"), "excavation removes already visible notice")
		Toasts.Show("Excavation warning", "Warning", 12)
		check(hasToast("Excavation warning"), "urgent warning visible during excavation")
		Toasts.Show("Quest excavation notice", "Success")
		Mock.Advance(8)
		check(not hasToast("Quest excavation"), "excavation holds incoming notice beyond reveal cap")
		Toasts.SetExcavating(false)
		Mock.Advance(0.1)
		check(hasToast("Index collection") and hasToast("Quest excavation"), "visible and incoming notices resume after excavation")
		Mock.Advance(6)
		Toasts.SetExcavating(true)
		for i = 1, 20 do
			Toasts.Show("Bounded excavation notice " .. i, "Info")
		end
		Toasts.SetExcavating(false)
		Mock.Advance(0.1)
		check(not hasToast("Bounded excavation notice 1"), "excavation queue discards oldest overflow")
		check(countToasts() <= 3, "resumed queue respects visible limit")
		Mock.Advance(15)
		local RevealUI = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/Reveal"])
		local base = countToasts()
		RevealUI.Show({ Headline = "RARE!", Color = Mock.Env.Color3.new(0, 0, 1), Items = { { Name = "Shell", Rows = {} } }, Hold = 3 })
		Mock.Advance(0.3)
		check(RevealUI.IsShowing(), "reveal is showing for the toast hold test")
		Toasts.Show("You can afford the Garden Trowel!", "Success")
		Mock.Advance(0.5)
		check(countToasts() == base, "non-urgent toast waits while a reveal is showing")
		Toasts.Show("Too hard! Upgrade your shovel", "Warning")
		Mock.Advance(0.5)
		check(countToasts() == base + 1, "warning toasts still show during a reveal")
		Mock.Advance(3)
		check(not RevealUI.IsShowing() and hasToast("Garden Trowel"), "held toast appears once the reveal closes")
		Mock.Advance(6)
		-- chained reveals cannot hold a toast forever
		for _ = 1, 4 do
			RevealUI.Show({ Headline = "COMMON!", Color = Mock.Env.Color3.new(1, 1, 1), Items = { { Name = "Cap", Rows = {} } }, Hold = 3 })
		end
		Mock.Advance(0.3)
		Toasts.Show("Quest complete!", "Success")
		Mock.Advance(5)
		check(RevealUI.IsShowing() and not hasToast("Quest complete"), "toast still waits early in a reveal chain")
		Mock.Advance(2.5)
		check(RevealUI.IsShowing() and hasToast("Quest complete"), "a toast held behind chained reveals shows after the cap")
		Mock.Advance(15)
	end

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

-- Streaming (v2.3) --------------------------------------------------------------------------------
section("streaming")
do
	local e0 = #Mock.Errors
	local Tagged = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Util/Tagged"])
	local Anchors = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Util/Anchors"])
	local GuideController = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/GuideController"])
	local StatusController = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/StatusController"])

	-- the mock shares one instance tree with the "server": keep its anchors while we stream parts
	StreamingService._Freeze(true)
	-- anchors: every station tag has positions that survive streaming
	for _, tag in StreamingService.ANCHOR_TAGS do
		check(#Anchors.Get(tag) == #Mock.Tagged(tag) and #Anchors.Get(tag) > 0, "anchors published for " .. tag)
	end
	local sellPart = Mock.Tagged("SellZone")[1]
	local sellTop = sellPart.Position + Vector3.new(0, sellPart.Size.Y / 2, 0)
	check((Anchors.Nearest("SellZone") - sellTop).Magnitude < 1e-6, "SellZone anchor = top of the pad")
	local shopModel = Mock.Tagged("ShovelShop")[1]:FindFirstAncestorWhichIsA("Model")
	check(shopModel and shopModel.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, "station models stream atomically")

	-- Tagged.Watch: added + removed, cleanup runs on stream-out, new instance on stream-in
	local added, cleaned = 0, 0
	local stop = Tagged.Watch("ShovelShop", function()
		added += 1
		return function()
			cleaned += 1
		end
	end)
	Mock.Advance(0.1)
	local count = #Mock.Tagged("ShovelShop")
	check(added == count, "Tagged.Watch sees existing instances (" .. added .. ")")
	local shopPart = Mock.Tagged("ShovelShop")[1]
	local token = Mock.StreamOut(shopPart)
	Mock.Advance(0.1)
	check(cleaned == 1 and #Mock.Tagged("ShovelShop") == count - 1, "stream-out runs the cleanup")
	local fresh = Mock.StreamIn(token)
	Mock.Advance(0.1)
	check(added == count + 1 and fresh ~= shopPart, "stream-in arrives as a new instance and is watched")

	-- prompts still work after a stream-out / stream-in cycle (and the old one is not hooked)
	local prompt = fresh:FindFirstChildWhichIsA("ProximityPrompt", true)
	if check(prompt ~= nil, "streamed-in station has its prompt") then
		Panel.CloseAll()
		Mock.Advance(0.2)
		Mock.FireEvent(prompt, "Triggered", player)
		Mock.Advance(0.5)
		check(Panel.Current() ~= nil, "prompt on a streamed-in station opens its panel")
		Panel.CloseAll()
		Mock.Advance(0.3)
	end
	-- a prompt that streams in AFTER its part is hooked too
	local eggPart = Mock.Tagged("EggShop")[1]
	local eggPrompt = eggPart:FindFirstChildWhichIsA("ProximityPrompt", true)
	local promptToken = Mock.StreamOut(eggPrompt)
	Mock.Advance(0.1)
	local lateprompt = Mock.StreamIn(promptToken)
	Mock.Advance(0.1)
	Mock.FireEvent(lateprompt, "Triggered", player)
	Mock.Advance(0.5)
	check(Panel.Current() ~= nil, "prompt that streams in after its part still opens the panel")
	Panel.CloseAll()
	Mock.Advance(0.3)
	stop()
	check(cleaned == added, "stop() cleans every watched instance")

	-- guide beams: target streamed out -> anchor position; streamed back in -> the new part
	local root = character:FindFirstChild("HumanoidRootPart")
	local sellToken = Mock.StreamOut(sellPart)
	Mock.Advance(0.1)
	local target = GuideController.FindTagged("SellZone", root.Position)
	check(target ~= nil, "FindTagged works while the station is streamed out")
	local resolved = target and GuideController.Resolve(target, root.Position)
	check(resolved and (resolved - sellTop).Magnitude < 1e-6, "guide falls back to the published anchor")
	GuideController.Set("StreamTest", target, 99, "S")
	Mock.Advance(0.3)
	local beam = Mock.Service("Workspace").Terrain:FindFirstChild("GuideBeam")
	local to = Mock.Service("Workspace").Terrain:FindFirstChild("GuideTo")
	check(beam and beam.Enabled and to and (to.WorldPosition - sellTop).Magnitude < 1e-6, "beam points at a streamed-out station")
	local sellBack = Mock.StreamIn(sellToken)
	Mock.Advance(0.3)
	check(sellBack ~= sellPart and (GuideController.Resolve(target, root.Position) - sellTop).Magnitude < 1e-6, "guide locks onto the streamed-in part")
	local savedMotion = State.GetSetting("ReducedMotion", false)
	State.SetSetting("ReducedMotion", true)
	Mock.Advance(0.2)
	local marker = to:FindFirstChild("GuideMarker")
	check(beam.TextureSpeed == 0 and marker.StudsOffsetWorldSpace.Y == 4, "reduced motion keeps a static world guide")
	Mock.Advance(0.3)
	check(marker.StudsOffsetWorldSpace.Y == 4 and marker.Enabled, "static guide remains visible without bouncing")
	GuideController.Set("StreamTest", root.Position, 99, "S")
	Mock.Advance(0.2)
	check(not marker.Enabled and not beam.Enabled, "guide at the player's feet does not obscure the avatar")
	GuideController.Set("StreamTest", target, 99, "S")
	Mock.Advance(0.2)
	check(marker.Enabled and beam.Enabled, "guide reappears when the target is distant again")
	local markerIcon = marker:FindFirstChild("MarkerIcon")
	check(markerIcon ~= nil and markerIcon:GetAttribute("Icon") == "S", "world marker draws through AtlasIcon")

	-- first upgrade: the reveal says what changed, and better shovels hit visibly harder
	do
		local ItemStats = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/ItemStats"])
		local SharedConfig = Mock.Require(byPath["ReplicatedStorage/Shared/Config"])
		local spade, trowel = SharedConfig.Shovels[1], SharedConfig.Shovels[2]
		local summary = ItemStats.UpgradeSummary(spade, trowel)
		check(summary ~= nil and string.find(summary, "NOW DIGS " .. string.upper(SharedConfig.Layers[3].Name), 1, true) ~= nil, "trowel reveal names the new layer it digs (" .. tostring(summary) .. ")")
		check(summary ~= nil and string.find(summary, "+50% SAND", 1, true) ~= nil, "trowel reveal shows +50% sand")
		check(summary ~= nil and string.find(summary, "BIGGER DIGS", 1, true) == nil, "no 'bigger digs' claim when the dig cube is the same size")
		check(ItemStats.UpgradeSummary(nil, trowel) == nil and ItemStats.UpgradeSummary(trowel, trowel) == nil, "no summary without a real upgrade")
		check(ItemStats.Heft(spade.Id) == 1 and ItemStats.Heft(trowel.Id) > 1, "trowel hits harder than the spade")
		check(ItemStats.Heft(SharedConfig.Shovels[#SharedConfig.Shovels].Id) == 2, "heft is capped at 2")
		local MenuGateUI = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/MenuGate"])
		local steps = SharedConfig.TUTORIAL_STEPS
		check(steps[MenuGateUI.TUTORIAL_SHOP + 1].Id == "shop" and steps[MenuGateUI.TUTORIAL_EGGS + 1].Id == "egg", "menu unlocks follow the tutorial step ids")
		local shopIndex = MenuGateUI.TUTORIAL_SHOP + 1
		check(steps[shopIndex + 1].Id == "dig_deeper" and steps[shopIndex + 1].Complete == "NewLayer", "after buying a shovel the tutorial sends you down to the new layer")
	end

	-- chat window: docked bottom-left on keyboard screens (the menu's Shop row is top-left)
	do
		local ChatLayout = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/ChatLayoutController"])
		local pc = ChatLayout.DockFor(false, true)
		check(pc and pc.Horizontal == Enum.HorizontalAlignment.Left and pc.Vertical == Enum.VerticalAlignment.Bottom, "chat docks bottom-left on PC")
		check(ChatLayout.DockFor(true, false) == nil, "phones keep the default chat position (thumbstick is bottom-left)")
		check(ChatLayout.DockFor(true, true) ~= nil, "touch laptops with a keyboard dock like PC")
	end

	-- ambience: loops near the surface when an id is configured, follows the SFX setting
	do
		local SoundController = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/SoundController"])
		local SharedConfig = Mock.Require(byPath["ReplicatedStorage/Shared/Config"])
		check(not SoundController.Playing().Ambience, "no ambience while its id is empty")
		local savedSfx = State.GetSetting("SFX", true)
		SharedConfig.Sounds.Ambience.Id = "rbxassetid://1"
		SoundController.SetAmbience(true)
		check(SoundController.Playing().Ambience, "configured ambience plays at the surface")
		State.SetSetting("SFX", false)
		Mock.Advance(0.3)
		check(not SoundController.Playing().Ambience, "ambience stops when sound effects are off")
		State.SetSetting("SFX", true)
		Mock.Advance(0.3)
		check(SoundController.Playing().Ambience, "ambience resumes when sound effects are back on")
		SoundController.SetAmbience(false)
		check(not SoundController.Playing().Ambience, "ambience stops underground")
		State.SetSetting("SFX", savedSfx)
		SharedConfig.Sounds.Ambience.Id = ""
		Mock.Advance(0.3)
	end

	-- off-screen edge indicator: pure placement math
	do
		local size = Vector2.new(1280, 720)
		local onScreen, at = GuideController.EdgePlacement(Vector3.new(0, 0, -10), Vector3.new(640, 360, 10), size, 50)
		check(onScreen and at == Vector2.new(640, 360), "edge: target in view needs no edge arrow")
		local off, right, rotRight = GuideController.EdgePlacement(Vector3.new(50, 0, -10), Vector3.new(4000, 360, 10), size, 50)
		check(not off and math.abs(right.X - 1230) < 1e-6 and math.abs(right.Y - 360) < 1e-6, "edge: off to the right pins to the right margin")
		check(math.abs(rotRight + 90) < 1e-6, "edge: right-pointing rotation is -90 (down arrow turned anticlockwise)")
		local _, left = GuideController.EdgePlacement(Vector3.new(-50, 0, -10), Vector3.new(-4000, 360, 10), size, 50)
		check(math.abs(left.X - 50) < 1e-6, "edge: off to the left pins to the left margin")
		local _, up, rotUp = GuideController.EdgePlacement(Vector3.new(0, 50, -10), Vector3.new(640, -4000, 10), size, 50)
		check(math.abs(up.Y - 50) < 1e-6 and math.abs(math.abs(rotUp) - 180) < 1e-6, "edge: above the view pins to the top and points up")
		local behindOn, behind, rotBehind = GuideController.EdgePlacement(Vector3.new(30, 0, 20), Vector3.new(640, 360, -20), size, 50)
		check(not behindOn and math.abs(behind.X - 1230) < 1e-6 and math.abs(rotBehind + 90) < 1e-6, "edge: behind and to the right uses the right edge")
		local _, straight, rotStraight = GuideController.EdgePlacement(Vector3.new(0, 0, 20), Vector3.new(640, 360, -20), size, 50)
		check(math.abs(straight.Y - 670) < 1e-6 and math.abs(rotStraight) < 1e-6, "edge: directly behind points down (turn around)")
		local _, corner = GuideController.EdgePlacement(Vector3.new(80, 80, -10), Vector3.new(9000, -9000, 10), size, 50)
		check(corner.X <= 1230 + 1e-6 and corner.Y >= 50 - 1e-6, "edge: diagonal targets stay inside the margin box")
	end

	-- off-screen edge indicator: live, target behind the camera
	do
		local camera = Mock.Service("Workspace").CurrentCamera
		local savedCF = camera.CFrame
		local edgeGui = player.PlayerGui:FindFirstChild("Dig_GuideEdge")
		local edge = edgeGui and edgeGui:FindFirstChild("EdgeArrow")
		local behindPoint = root.Position + Vector3.new(0, 0, 60)
		camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 10, -15), root.Position + Vector3.new(0, 0, -100))
		GuideController.Set("StreamTest", behindPoint, 99, "Coins")
		Mock.Advance(0.2)
		edgeGui = player.PlayerGui:FindFirstChild("Dig_GuideEdge")
		edge = edgeGui and edgeGui:FindFirstChild("EdgeArrow")
		check(edge ~= nil and edge.Visible, "edge arrow shows for a target behind the camera")
		check(edge and edge:FindFirstChild("MarkerIcon") and edge.MarkerIcon:GetAttribute("Icon") == "Coins", "edge arrow carries the guide's marker icon")
		camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 10, 15), behindPoint)
		Mock.Advance(0.2)
		check(edge and not edge.Visible, "edge arrow hides once the target is in view")
		camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 10, -15), root.Position + Vector3.new(0, 0, -100))
		Mock.Advance(0.2)
		check(edge and edge.Visible, "edge arrow returns when the camera turns away again")
		local savedReduced = State.GetSetting("ReducedMotion", false)
		State.SetSetting("ReducedMotion", true)
		Mock.Advance(0.2)
		local s1 = edge.Size.X.Offset
		Mock.Advance(0.13)
		check(edge.Size.X.Offset == s1, "reduced motion: edge arrow does not pulse")
		State.SetSetting("ReducedMotion", savedReduced)
		GuideController.Set("StreamTest", root.Position, 99, "Coins")
		Mock.Advance(0.2)
		check(edge and not edge.Visible, "edge arrow hides when the player is at the target")
		camera.CFrame = savedCF
		GuideController.Set("StreamTest", target, 99, "S")
		Mock.Advance(0.2)
	end
	State.SetSetting("ReducedMotion", false)
	Mock.Advance(0.2)
	check(
		beam.TextureSpeed == 2 and marker.StudsOffsetWorldSpace.Y > 4,
		"world guide motion resumes when preference is disabled"
	)
	local ObjectiveBanner = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/ObjectiveBanner"])
	ObjectiveBanner.Show("Sell your sand!", "Sell", { Arrow = true })
	local arrow = ObjectiveBanner.Get():FindFirstChild("Arrow")
	State.SetSetting("ReducedMotion", true)
	Mock.Advance(0.6)
	check(arrow.Visible and arrow.Position.Y.Offset == -2, "enabling reduced motion stops an active objective arrow")
	ObjectiveBanner.Hide()
	State.SetSetting("ReducedMotion", false)
	Mock.Advance(0.6)
	check(
		not ObjectiveBanner.Get().Visible and arrow.Position.Y.Offset == -2,
		"hidden objective arrow stays stopped when settings change"
	)
	State.SetSetting("ReducedMotion", savedMotion)
	GuideController.Clear("StreamTest")
	Mock.Advance(0.2)

	-- far player's character streams out and back in: nameplate follows the new Head
	local far = Mock.AddPlayer(3003, "FarAway")
	local farChar = Mock.SpawnCharacter(far, spawnCF.Position + Vector3.new(30, 0, 0))
	Mock.Advance(0.8)
	local plate = StatusController.GetPlate(far)
	check(plate ~= nil and plate.Adornee == farChar:FindFirstChild("Head"), "far player has a nameplate")
	local headToken = Mock.StreamOut(farChar:FindFirstChild("Head"))
	Mock.Advance(0.8)
	local newHead = Mock.StreamIn(headToken)
	Mock.Advance(0.8)
	plate = StatusController.GetPlate(far)
	check(plate ~= nil and plate.Adornee == newHead, "nameplate re-adorns the streamed-in Head")
	Mock.RemovePlayer(far)
	Mock.Advance(0.3)
	StreamingService._Freeze(false)
	check(#Mock.Errors == e0, "no errors while streaming parts out and in")
end

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
State.SetSetting("ReducedMotion", true)
Mock.FireClientEvent("EggHatched", { Config.Pets[1].Id })
Mock.Advance(0.1)
local hatch = playerGui:FindFirstChild("Hatch", true)
local hatchEgg = hatch and hatch:FindFirstChild("Egg", true)
check(hatchEgg ~= nil and (hatchEgg.Rotation or 0) == 0 and hatchEgg.Size.X.Offset == 180, "reduced-motion hatch keeps egg still at its original size")
Mock.Advance(8)
State.SetSetting("ReducedMotion", false)
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
	do
		-- playtest: crates were mixed into the egg list. Crates tab shows only crates; Eggs tab only eggs.
		local EggPanelMod = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/Panels/EggPanel"])
		local function shownCards(): { [string]: boolean }
			local shown = {}
			for _, egg in Config.Eggs do
				local holder = window:FindFirstChild(egg.Id, true)
				while holder and holder.Parent and not holder.Parent:IsA("ScrollingFrame") do
					holder = holder.Parent
				end
				if holder and holder:IsA("GuiObject") and holder.Visible then
					shown[egg.Id] = true
				end
			end
			return shown
		end
		local function onlyKind(crates: boolean): boolean
			local shown, any = shownCards(), false
			for _, egg in Config.Eggs do
				if shown[egg.Id] then
					any = true
					if (egg.Kind == "Crate") ~= crates then
						return false
					end
				end
			end
			return any
		end
		check(EggPanelMod.GetTab() == "Crates", "a crate EggId opens the Crates tab")
		check(onlyKind(true), "Crates tab lists only crates")
		local title = window:FindFirstChild("Title", true)
		check(title ~= nil and title.Text == "Construction Crates", "Crates tab is titled Construction Crates")
		Panel.CloseAll()
		Mock.Advance(0.3)
		Panel.Open("Eggs")
		Mock.Advance(0.5)
		check(EggPanelMod.GetTab() == "Eggs" and onlyKind(false), "the menu opens the Eggs tab with eggs only")
		check(title ~= nil and title.Text == "Eggs", "Eggs tab is titled Eggs")
		EggPanelMod.SelectTab("Crates")
		Mock.Advance(0.3)
		check(onlyKind(true), "switching to the Crates tab shows crates")
		Panel.CloseAll()
		Mock.Advance(0.3)
		Panel.Open("Eggs", { EggId = topCrate.Id })
		Mock.Advance(1)
	end
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
		if d.Name == "Badges" then
			for _, icon in d:GetChildren() do
				if icon:GetAttribute("Icon") == "Dig" then
					digBadges += 1
				elseif icon:GetAttribute("Icon") == "Ride" then
					rideBadges += 1
				end
			end
		end
	end
	check(digBadges == 2 and rideBadges == 1, "Dig badge (atlas icon) on digging pets, Ride on rideable (" .. digBadges .. "/" .. rideBadges .. ")")
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
	-- Decorative pet motion stops on a live setting toggle; follow and digging still work.
	local savedPetMotion = State.GetSetting("ReducedMotion", false)
	State.SetSetting("ReducedMotion", true)
	player:SetAttribute("EquippedPets", "")
	root.CFrame = CFrame.new(root.Position)
	player:SetAttribute("EquippedPets", "mining_drill,seagull,sandy_crab")
	Mock.Advance(0.05)
	local motionPets = PetFollowController.GetVisuals(player)
	local drillPet, flyingPet, walkingPet
	for _, v in motionPets do
		if v.Id == "mining_drill" then
			drillPet = v
		elseif v.Id == "seagull" then
			flyingPet = v
		else
			walkingPet = v
		end
	end
	local drillJoint
	for _, d in drillPet.Model:GetDescendants() do
		if d:IsA("Model") and (d:GetAttribute("Motion") == "Drill" or d:GetAttribute("Motion") == "Spin") then
			drillJoint = d
			break
		end
	end
	local function jointPose()
		return drillPet.Model:GetPivot():ToObjectSpace(drillJoint:GetPivot())
	end
	State.SetSetting("ReducedMotion", true)
	Mock.Advance(0.05)
	local flyStill, walkStill, vehicleStill =
		flyingPet.Model:GetPivot(), walkingPet.Model:GetPivot(), drillPet.Model:GetPivot()
	local drillStill = jointPose()
	Mock.Advance(0.1)
	check(
		(flyingPet.Model:GetPivot().Position - flyStill.Position).Magnitude < 0.001
			and flyingPet.Model:GetPivot().UpVector:Dot(flyStill.UpVector) > 0.99999,
		"reduced motion stops pet flight bob and roll"
	)
	check(
		(walkingPet.Model:GetPivot().Position - walkStill.Position).Magnitude < 0.001,
		"reduced motion stops ground creature idle bob"
	)
	check(
		(drillPet.Model:GetPivot().Position - vehicleStill.Position).Magnitude < 0.001,
		"reduced motion stops vehicle idle engine bob"
	)
	check(jointPose().RightVector:Dot(drillStill.RightVector) > 0.99999, "reduced motion freezes idle drill rotation")
	Mock.Advance(3)
	local groundedY = walkingPet.Model:GetPivot().Position.Y
	local ownerBeforeJump = root.CFrame
	root.CFrame = root.CFrame + Vector3.new(0, 2, 0)
	Mock.Advance(2)
	check(math.abs(walkingPet.Model:GetPivot().Position.Y - groundedY) < 0.05, "walking pet stays on terrain when its owner rises above it")
	check(flyingPet.Model:GetPivot().Position.Y > flyStill.Position.Y + 1.5, "flying pet keeps following the owner's height")
	root.CFrame = ownerBeforeJump
	Mock.Advance(2)
	Mock.Advance(0.05)
	State.SetSetting("ReducedMotion", false)
	local resumePose = jointPose()
	local resumeFly = flyingPet.Model:GetPivot()
	Mock.Advance(0.1)
	check(
		jointPose().RightVector:Dot(resumePose.RightVector) < 0.999,
		"idle drill rotation resumes after disabling reduced motion"
	)
	check(
		(flyingPet.Model:GetPivot().Position - resumeFly.Position).Magnitude > 0.01,
		"pet flight bob resumes after disabling reduced motion"
	)
	State.SetSetting("ReducedMotion", true)
	Mock.Advance(0.02)
	local toggledDrill = jointPose()
	Mock.Advance(0.02)
	check(
		jointPose().RightVector:Dot(toggledDrill.RightVector) > 0.99999
			and flyingPet.Model:GetPivot().UpVector.Y > 0.99999,
		"enabling reduced motion immediately stops active idle drill spin and flight roll"
	)
	root.CFrame = CFrame.new(root.Position + Vector3.new(-8, 0, 0))
	Mock.Advance(0.15)
	check(
		(drillPet.Model:GetPivot().Position - vehicleStill.Position).Magnitude > 0.1
			and (flyingPet.Model:GetPivot().Position - flyStill.Position).Magnitude > 0.1,
		"reduced motion preserves pet follow locomotion"
	)
	local actionPose = jointPose()
	Mock.FireClientEvent(
		"PetDug",
		player,
		drillPet.Slot,
		drillPet.Id,
		drillPet.Model:GetPivot().Position - Vector3.new(0, 1, 0) + Vector3.new(0, 0, -2.4),
		12
	)
	Mock.Advance(0.25)
	check(
		jointPose().RightVector:Dot(actionPose.RightVector) < 0.999
			or (jointPose().Position - actionPose.Position).Magnitude > 0.01,
		"reduced motion preserves active drill feedback"
	)
	State.SetSetting("ReducedMotion", savedPetMotion)
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
		local EggPanelMod = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/Panels/EggPanel"])
		check(EggPanelMod.GetTab() == "Crates", "crate pallet prompt opens the Crates tab")
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
	-- v2.2 playtest: the spade rests with the arm down at the side (not held out in front), so
	-- the scoop swings forward and UP instead of first dropping the arm.
	local sd = Pose.GetDebug(otherChar)
	check(sd.Posed and not sd.TwoHanded, "hand spade is posed at rest")
	local sr = poseReport(otherRig, spade)
	check(sr.Palm.Y < sr.Shoulder.Y - 1.2, "spade arm hangs at the side (" .. sr.Palm.Y - sr.Shoulder.Y .. ")")
	check(sr.Blade.Z < sr.Palm.Z - 0.3, "spade points forward at rest")
	check(sr.MaxJointSlip < 1e-3, "spade arm joints stay connected")
	local restPalm = sr.Palm
	Mock.FireClientEvent("Scoop", other)
	local lowPalm, highPalm, scooped = math.huge, -math.huge, false
	for _ = 1, 30 do
		Mock.Advance(1 / 30)
		local od = Pose.GetDebug(otherChar)
		scooped = scooped or (od.Scooping and od.Posed and not od.TwoHanded)
		local rr = poseReport(otherRig, spade)
		lowPalm = math.min(lowPalm, rr.Palm.Y)
		highPalm = math.max(highPalm, rr.Palm.Y)
	end
	check(scooped, "other player's one-handed scoop plays")
	check(otherRig.LeftShoulder.Transform == CFrame.identity, "one-handed scoop leaves the left arm alone")
	check(lowPalm > restPalm.Y - 0.1, "spade scoop never drops the hand first (" .. lowPalm - restPalm.Y .. ")")
	check(highPalm > restPalm.Y + 0.8, "spade scoop lifts the hand up (" .. highPalm - restPalm.Y .. ")")
	Mock.Advance(0.5)
	check(not Pose.IsScooping(otherChar), "one-handed scoop finishes")
	check((poseReport(otherRig, spade).Palm - restPalm).Magnitude < 0.05, "spade arm returns to the side")
	spade.Parent = nil
	Mock.Advance(0.2)
	check(otherRig.RightShoulder.Transform == CFrame.identity, "putting the spade away resets the arm")

	-- R6 characters are skipped
	otherChar:FindFirstChildOfClass("Humanoid").RigType = Enum.HumanoidRigType.R6
	Mock.SpawnCharacter(other, c + Vector3.new(6, 3, 6))
	makeTool(full.Id).Parent = other.Character
	Mock.Advance(1.5)
	check(Pose.PlayScoop(other.Character) == false, "R6 rig: no procedural scoop")
	check(not Pose.GetDebug(other.Character) or not Pose.GetDebug(other.Character).Posed, "R6 rig + full shovel keeps the plain grip")

	-- R6 + hand spade (playtest 2: the spade still stuck out on a blocky R6 avatar). The arm hangs
	-- low and the grip weld is re-aimed so the spade points forward / down, not backwards.
	do
		local r6Char = Mock.SpawnCharacter(other, c + Vector3.new(6, 3, 6))
		r6Char:FindFirstChildOfClass("Humanoid").RigType = Enum.HumanoidRigType.R6
		local function r6Part(name, size)
			local p = r6Char:FindFirstChild(name) or Instance.new("Part")
			p.Name = name
			p.Size = size
			p.Parent = r6Char
			return p
		end
		local torso = r6Part("Torso", Vector3.new(2, 2, 1))
		local arm = r6Part("Right Arm", Vector3.new(1, 2, 1))
		local shoulder = Instance.new("Motor6D")
		shoulder.Name = "Right Shoulder"
		shoulder.Part0 = torso
		shoulder.Part1 = arm
		shoulder.C0 = CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0)
		shoulder.C1 = CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0)
		shoulder.Parent = torso
		local spade6 = makeTool(hand.Id)
		spade6.Parent = r6Char
		local gripWeld = Instance.new("Weld")
		gripWeld.Name = "RightGrip"
		gripWeld.Part0 = arm
		gripWeld.Part1 = spade6.Handle
		gripWeld.C0 = CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
		gripWeld.C1 = spade6.Grip
		gripWeld.Parent = arm
		local function r6Report()
			local armCF = shoulder.C0 * shoulder.Transform * shoulder.C1:Inverse()
			local palm = armCF * gripWeld.C0
			local handle = palm * gripWeld.C1:Inverse()
			local h = spade6.Handle
			return {
				Palm = palm.Position,
				Shaft = handle:VectorToWorldSpace(h:GetAttribute("ShaftAxis")).Unit,
				Blade = handle * h:GetAttribute("BladePoint"),
				Grip = (handle * spade6.Grip.Position - palm.Position).Magnitude,
			}
		end
		Mock.Advance(1.5)
		local d6 = Pose.GetDebug(r6Char)
		check(d6 ~= nil and d6.Posed and not d6.TwoHanded, "R6 hand spade is posed")
		local r = r6Report()
		check(r.Palm.Y < shoulder.C0.Position.Y - 1.3, "R6 spade arm hangs low (" .. r.Palm.Y .. ")")
		check(r.Shaft.Z < -0.5 and r.Shaft.Y < 0, "R6 spade points forward and down (" .. tostring(r.Shaft) .. ")")
		check(r.Blade.Z < r.Palm.Z - 0.3, "R6 spade blade is in front of the hand")
		check(r.Grip < 1e-3, "R6 spade stays in the fist")
		local restY = r.Palm.Y
		check(Pose.PlayScoop(r6Char) == true, "R6 hand spade plays the procedural scoop")
		local high = -math.huge
		for _ = 1, 30 do
			Mock.Advance(1 / 30)
			high = math.max(high, r6Report().Palm.Y)
		end
		check(high > restY + 0.5, "R6 scoop lifts the spade up (" .. high - restY .. ")")
		spade6.Parent = nil
		Mock.Advance(0.2)
		check(shoulder.Transform == CFrame.identity and gripWeld.C1 == spade6.Grip, "putting the R6 spade away restores the arm and grip")
	end

	-- Studio diagnostics (playtest: the spade kept the default hold and nothing said why)
	do
		local wasStudio = Mock.IsStudio
		Mock.IsStudio = true
		local p0, w0 = #Mock.Prints, #Mock.Warnings
		local diag = Mock.AddPlayer(2003, "Diag")
		local diagChar = Mock.SpawnCharacter(diag, c + Vector3.new(-6, 3, 6))
		local diagRig = Mock.MakeR15(diagChar)
		makeTool(hand.Id).Parent = diagChar
		Mock.Advance(0.3)
		local said = false
		for i = p0 + 1, #Mock.Prints do
			said = said or string.find(Mock.Prints[i], "[ShovelPose] Diag: posing one-handed (R15)", 1, true) ~= nil
		end
		check(said, "Studio Output says the spade is being posed")
		-- a rig without an elbow joint: Output names what is missing
		diagRig.RightElbow:Destroy()
		Mock.Advance(1.5)
		local missing = false
		for i = w0 + 1, #Mock.Warnings do
			missing = missing or string.find(Mock.Warnings[i], "missing RightElbow", 1, true) ~= nil
		end
		check(missing, "Studio Output names the missing joint")
		for i = #Mock.Warnings, w0 + 1, -1 do -- expected diagnostics, not failures
			if string.find(Mock.Warnings[i], "[ShovelPose] Diag:", 1, true) then
				table.remove(Mock.Warnings, i)
			end
		end
		Mock.RemovePlayer(diag)
		Mock.IsStudio = wasStudio
		Mock.Advance(0.2)
	end

	-- Avatar Joint Upgrade (playtest: the owner's R15 avatar had AnimationConstraints, no
	-- Motor6Ds, and Output said every joint was missing). Same rig, joints converted.
	do
		local up = Mock.AddPlayer(2004, "Upgraded")
		local upChar = Mock.SpawnCharacter(up, c + Vector3.new(-10, 3, 6))
		Mock.MakeR15(upChar)
		local joints = {}
		for _, d in upChar:GetDescendants() do
			if d:IsA("Motor6D") then
				table.insert(joints, d)
			end
		end
		local ac = {}
		for _, m in joints do
			local a0 = Instance.new("Attachment")
			a0.Name = m.Name .. "RigAttachment"
			a0.CFrame = m.C0
			a0.Parent = m.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = m.Name .. "RigAttachment"
			a1.CFrame = m.C1
			a1.Parent = m.Part1
			local con = Instance.new("AnimationConstraint")
			con.Name = m.Name
			con.Attachment0 = a0
			con.Attachment1 = a1
			con.Parent = m.Part1
			ac[m.Name] = con
			m:Destroy()
		end
		check(ac.RightShoulder ~= nil and ac.RightElbow ~= nil and ac.Waist ~= nil, "test rig converted to AnimationConstraints")
		local upSpade = makeTool(hand.Id)
		upSpade.Parent = upChar
		Mock.Advance(1.5)
		local ud = Pose.GetDebug(upChar)
		check(ud ~= nil and ud.Posed and not ud.TwoHanded, "spade is posed on an Avatar Joint Upgrade rig")
		local function link(j)
			return j.Attachment0.CFrame * j.Transform * j.Attachment1.CFrame:Inverse()
		end
		local handCF = link(ac.RightShoulder) * link(ac.RightElbow) * link(ac.RightWrist)
		local palmY = (handCF * upChar.RightHand.RightGripAttachment.Position).Y
		check(palmY < ac.RightShoulder.Attachment0.CFrame.Position.Y - 1.2, "upgraded rig: spade arm hangs at the side (" .. palmY .. ")")
		upSpade.Parent = nil
		Mock.Advance(0.2)
		check(ac.RightShoulder.Transform == CFrame.identity, "upgraded rig: putting the spade away resets the arm")
		Mock.RemovePlayer(up)
		Mock.Advance(0.2)
	end

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
	local rideEngine = vehicle.PrimaryPart:FindFirstChild("RideEngine")
	local savedRideSfx = State.GetSetting("SFX", true)
	check(rideEngine ~= nil, "ride engine is created")
	State.SetSetting("SFX", false)
	Mock.Advance(0.3)
	check(rideEngine.Volume == 0, "SFX off mutes the engine while seated")
	State.SetSetting("SFX", true)
	Mock.Advance(0.3)
	check(rideEngine.Volume > 0, "SFX on restores the engine while seated")
	State.SetSetting("SFX", savedRideSfx)

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

-- Menu gating: progressive disclosure (Onboarding & Analytics agent) -----------------------------
section("menu gating")
do
	local e0 = #Mock.Errors
	local HUD = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/HUD"])
	local MenuGate = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/MenuGate"])
	local Layout = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/Layout"])

	-- Pure rules ----------------------------------------------------------------------------------
	local function fresh(patch)
		local d = Config.NewPlayerData()
		d.FirstJoin = 0
		for k, v in patch or {} do
			d[k] = v
		end
		return d
	end
	local function visibleSet(d, heat)
		return MenuGate.Evaluate({ Data = d, Heat = heat })
	end
	local none = visibleSet(fresh())
	for _, name in MenuGate.ALL do
		check(none[name] == false, "fresh player: " .. name .. " hidden")
	end
	local starter = Config.Shovels[1].Id
	local function shovels(n)
		local t = {}
		for i = 1, n do
			t[Config.Shovels[i].Id] = true
		end
		return t
	end
	local cases = {
		{ "Shop", fresh({ Settings = { FTUE_FirstSell = true } }), "after the first sell" },
		{ "Shop", fresh({ Settings = { Tutorial = MenuGate.TUTORIAL_SHOP } }), "at the tutorial shop step" },
		{ "Eggs", fresh({ Settings = { Tutorial = MenuGate.TUTORIAL_EGGS } }), "at the tutorial egg step" },
		{ "Eggs", fresh({ OwnedShovels = shovels(3) }), "after 2 shovel upgrades" },
		{ "Pets", fresh({ Pets = { a = { Id = Config.Pets[1].Id, Equipped = false } } }), "with a pet" },
		{ "Beach", fresh({ PlayTime = MenuGate.BEACH_PLAYTIME }), "after 4 min" },
		{ "Index", fresh({ Index = { [Config.Treasures[1].Id] = true } }), "after the first treasure" },
		{ "Quests", fresh({ OwnedShovels = shovels(2) }), "after the first shovel" },
		{ "Rebirth", fresh({ Coins = math.ceil(Config.RebirthCost(0) * MenuGate.REBIRTH_FRACTION) }), "at 60% of the rebirth cost" },
		{ "Store", fresh({ PlayTime = MenuGate.STORE_PLAYTIME }), "after 8 min" },
		{ "Daily", fresh({ PlayTime = MenuGate.DAILY_PLAYTIME }), "after the first minute" },
	}
	for _, case in cases do
		local v = visibleSet(case[2])
		check(v[case[1]] == true, case[1] .. " unlocks " .. case[3])
	end
	check(visibleSet(fresh(), MenuGate.BEACH_HEAT)["Beach"] == true, "Beach unlocks when heat reaches 50")
	check(visibleSet(fresh(), MenuGate.BEACH_HEAT - 1)["Beach"] == false, "Beach stays hidden below 50 heat")
	check(visibleSet(fresh({ PlayTime = MenuGate.BEACH_PLAYTIME - 1 }))["Beach"] == false, "Beach hidden before 4 min")
	check(visibleSet(fresh({ PlayTime = MenuGate.STORE_PLAYTIME - 1 }))["Store"] == false, "Store hidden before 8 min")
	check(visibleSet(fresh({ Coins = Config.RebirthCost(0) * 0.5 }))["Rebirth"] == false, "Rebirth hidden at 50% of the cost")
	check(visibleSet(fresh({ OwnedShovels = { [starter] = true } }))["Quests"] == false, "Quests hidden with only the starter shovel")
	-- persistence: transient triggers stay unlocked
	local persisted = fresh({ Settings = { MenuUnlocked = "Rebirth,Beach" } })
	local pv = visibleSet(persisted)
	check(pv.Rebirth and pv.Beach and not pv.Shop, "persisted unlocks stay visible after the trigger is gone")
	check(MenuGate.ParseList("Shop,Garage,,Eggs").Garage == nil, "unknown names ignored in the persisted list")
	local allSet = {}
	for _, name in MenuGate.ALL do
		allSet[name] = true
	end
	local full = MenuGate.FormatList(allSet)
	check(#full <= 64, "persisted list fits a SetSetting string (" .. #full .. " chars)")
	check(MenuGate.FormatList(MenuGate.ParseList(full)) == full, "persisted list round-trips")
	-- returning players see everything
	for _, d in { fresh({ PlayTime = MenuGate.RETURNING_PLAYTIME + 1 }), fresh({ Rebirths = 1 }) } do
		local v = visibleSet(d)
		local all = true
		for _, name in MenuGate.ALL do
			all = all and v[name] == true
		end
		check(all and MenuGate.IsReturning(d), "returning player sees every button")
	end
	-- re-flow: any number of visible buttons packs into 2 columns inside the Menu region, no
	-- overlaps, at every tested screen size
	local sizes = {
		{ 1187, 503 }, { 1200, 540 }, { 1219, 540 }, { 1333, 503 }, { 1333, 540 }, { 1000, 750 },
		{ 1000, 768 }, { 1000, 540 }, { 1044, 540 }, { 1422, 757 }, { 1422, 800 }, { 1600, 900 },
	}
	local cell = Layout.MENU_CELL
	for _, size in sizes do
		local r = Layout.Compute(Mock.Env.Vector2.new(size[1], size[2]))
		local ok = true
		for count = 1, #MenuGate.MENU do
			local rects = {}
			for k = 1, count do
				local p = MenuGate.CellPosition(k, cell, Layout.MENU_GAP_X, Layout.MENU_GAP_Y, Layout.MENU_COLUMNS)
				local rect = { X = r.Menu.X + p.X, Y = r.Menu.Y + p.Y, W = cell, H = cell }
				ok = ok and rect.X + rect.W <= r.Menu.X + r.Menu.W and rect.Y + rect.H <= r.Menu.Y + r.Menu.H
				for _, other in rects do
					ok = ok and not Layout.Overlaps(rect, other)
				end
				table.insert(rects, rect)
			end
		end
		check(ok, size[1] .. "x" .. size[2] .. ": re-flowed menu cells fit the Menu region without overlaps")
	end

	-- HUD integration -----------------------------------------------------------------------------
	local function shown(name)
		return HUD.Buttons[name].Holder.Visible == true
	end
	local function newTag(name)
		return HUD.Buttons[name].Holder:FindFirstChild("NewTag") ~= nil
	end
	local function toastWith(text)
		for _, d in playerGui:GetDescendants() do
			if d:IsA("TextLabel") and string.find(d.Text, text, 1, true) then
				return true
			end
		end
		return false
	end
	local function setData(patch)
		Mock.FireClientEvent("DataChanged", patch)
		Mock.Advance(0.4)
	end
	local function settingsWith(patch)
		local t = table.clone(State.Data.Settings or {})
		for k, v in patch do
			t[k] = v
		end
		return t
	end
	local function checkPacked(tag)
		local k = 0
		local ok = true
		for _, name in MenuGate.MENU do
			local holder = HUD.Buttons[name].Holder
			if holder.Visible then
				k += 1
				local p = MenuGate.CellPosition(k, cell, Layout.MENU_GAP_X, Layout.MENU_GAP_Y, Layout.MENU_COLUMNS)
				ok = ok and holder.Position.X.Offset == p.X and holder.Position.Y.Offset == p.Y
				ok = ok and holder.Size.X.Offset == cell and holder.Size.Y.Offset == cell
			end
		end
		check(ok, "menu re-flows without gaps (" .. tag .. ", " .. k .. " visible)")
	end

	Panel.CloseAll()
	player:SetAttribute("Heat", 0)
	setData({
		Coins = 0,
		Rebirths = 0,
		PlayTime = 0,
		Pets = {},
		Index = {},
		Quests = {},
		OwnedShades = {},
		LastDailyClaim = 0,
		OwnedShovels = { [starter] = true },
		Settings = { Tutorial = 0 },
	})
	local hiddenAll = true
	for _, name in MenuGate.ALL do
		hiddenAll = hiddenAll and not shown(name)
	end
	check(hiddenAll, "new player: every gated button hidden")
	check(shown("Settings"), "Settings button always visible")
	check(HUD.IsUnlocked("Surface") and HUD.IsUnlocked("Settings"), "ungated buttons count as unlocked")
	HUD.Flash("Store", 1)
	Mock.Advance(0.2)
	local storePop = HUD.Buttons.Store.Holder:FindFirstChild("Pop")
	check(not shown("Store") and (storePop == nil or storePop.Scale == 1), "Flash never points at a hidden button")

	local s0 = #Mock.Remote.ToServer
	setData({ Settings = settingsWith({ FTUE_FirstSell = true }) })
	Mock.Advance(0.6)
	check(shown("Shop"), "Shop appears after the first sell")
	check(newTag("Shop"), "Shop gets a NEW! tag")
	check(toastWith("Shop unlocked"), "unlock toast shown")
	local unlockedSent, trackSent = false, false
	for _, args in sent("SetSetting", s0) do
		if args[1] == "MenuUnlocked" and string.find(args[2], "Shop", 1, true) then
			unlockedSent = true
		end
	end
	for _, args in sent("Track", s0) do
		if args[1] == "menu_unlocked" and args[2] == "Shop" then
			trackSent = true
		end
	end
	check(unlockedSent, "unlock persisted with SetSetting(MenuUnlocked)")
	check(trackSent, "unlock tracked (Track menu_unlocked)")
	checkPacked("Shop only")

	-- tutorial egg step -> Eggs; first pet -> Pets; packed in MENU order
	setData({ Settings = settingsWith({ Tutorial = MenuGate.TUTORIAL_EGGS }) })
	check(shown("Eggs"), "Eggs appears at the tutorial egg step")
	setData({ Pets = { p1 = { Id = Config.Pets[1].Id, Equipped = true } } })
	check(shown("Pets"), "Pets appears with the first pet")
	Mock.Advance(1)
	checkPacked("Shop, Eggs, Pets")
	check(not shown("Beach") and not shown("Index"), "unrelated buttons stay hidden")

	-- transient triggers persist: heat, coins
	player:SetAttribute("Heat", MenuGate.BEACH_HEAT + 5)
	Mock.Advance(0.4)
	check(shown("Beach"), "Beach appears when the player first gets hot")
	player:SetAttribute("Heat", 0)
	Mock.Advance(0.4)
	setData({ Coins = Config.RebirthCost(0) })
	check(shown("Rebirth"), "Rebirth appears near the rebirth cost")
	setData({ Coins = 0 })
	Mock.Advance(6)
	check(shown("Beach") and shown("Rebirth"), "transient unlocks never disappear again")
	local persistedNow = MenuGate.ParseList(State.GetSetting("MenuUnlocked", nil))
	check(persistedNow.Beach and persistedNow.Rebirth and persistedNow.Shop, "unlocks stored in Settings.MenuUnlocked")
	Mock.Advance(1)
	checkPacked("after transient unlocks")

	-- NEW tag cleared on first open (HUD click or any other route), persisted in MenuSeen
	local s1 = #Mock.Remote.ToServer
	Mock.FireEvent(HUD.Buttons.Shop.Face, "Activated", Mock.Input(Enum.UserInputType.MouseButton1), 1)
	Mock.Advance(0.5)
	check(Panel.Current() == "Shop", "Shop button opens the Shop")
	check(not newTag("Shop"), "NEW! tag gone after the first open")
	check(MenuGate.ParseList(State.GetSetting("MenuSeen", nil)).Shop == true, "seen state persisted (MenuSeen)")
	local panelTracked = false
	for _, args in sent("Track", s1) do
		panelTracked = panelTracked or (args[1] == "panel_opened" and args[2] == "Shop")
	end
	check(panelTracked, "panel open tracked (Track panel_opened)")
	Panel.CloseAll()
	Mock.Advance(0.3)
	Panel.Open("BeachShop", {})
	Mock.Advance(0.5)
	check(not newTag("Beach"), "opening BeachShop elsewhere clears the Beach NEW! tag")
	Panel.CloseAll()
	Mock.Advance(0.3)
	check(newTag("Eggs") and newTag("Pets"), "unopened unlocks keep their NEW! tag")

	-- a Flash right after the unlocking change (tutorial step advanced this frame) re-checks
	-- the rules first, so the highlighted button is already there
	check(not shown("Index"), "Index hidden before the first treasure")
	State.Data.Index = { [Config.Treasures[1].Id] = true } -- not yet signalled
	HUD.Flash("Index", 0.5)
	check(shown("Index"), "Flash re-evaluates the rules before highlighting")
	Mock.Advance(1)
	setData({ Settings = settingsWith({ FTUE_FirstSell = false }) })
	check(HUD.IsUnlocked("Shop"), "Shop stays unlocked (persisted)")

	-- returning players: everything
	setData({ PlayTime = MenuGate.RETURNING_PLAYTIME + 60 })
	Mock.Advance(1)
	local allShown = true
	for _, name in MenuGate.ALL do
		allShown = allShown and shown(name)
	end
	check(allShown, "returning player: every button visible")
	checkPacked("all 8")
	check(HUD.FirstMenuButton() == HUD.Buttons.Shop, "gamepad menu focus starts on the first visible button")
	check(#Mock.Errors == e0, "menu gating without errors")
end

-- Report ------------------------------------------------------------------------------------------
section("hatching + compliance")
do
	local Stats = Mock.Require(byPath["ReplicatedStorage/Shared/Util/Stats"])
	local Format = Mock.Require(byPath["ReplicatedStorage/Shared/Util/Format"])
	local EggPanel = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/Panels/EggPanel"])
	local PurchaseController =
		Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/PurchaseController"])
	local PetFollowController =
		Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/PetFollowController"])
	local HatchAnimation = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/HatchAnimation"])
	local e0 = #Mock.Errors
	local function click(button)
		local face = if button:IsA("GuiButton") then button else button:FindFirstChildWhichIsA("GuiButton", true)
		Mock.FireEvent(face, "Activated", Mock.Input(Enum.UserInputType.MouseButton1), 1)
	end

	-- A2 policy on the client: nothing PaidRandom shows until the server says "not restricted"
	player:SetAttribute("PaidRandomRestricted", false)
	Mock.Advance(0.3)
	check(State.IsPaidRandomRestricted() == false and State.CanBuy("Product", "CoinsSmall"), "unrestricted: paid random items allowed")
	Panel.CloseAll()
	Panel.Open("Store", { Tab = "Boosts & Coins" })
	Mock.Advance(1)
	local store = Panel.Get("Store").Window
	local function storeCard(key)
		return store:FindFirstChild(key, true)
	end
	check(storeCard("CoinsSmall") and storeCard("CoinsSmall").Visible, "store shows coins when unrestricted")
	check(storeCard("FastDig") and storeCard("FastDig").Visible, "store shows the Turbo Shovel pass (v2.3)")
	for _, key in { "Lucky", "GoldenEgg", "GoldenEgg3", "LuckBoost15" } do
		check(storeCard(key) == nil, "v2.3: no paid luck / paid egg item in the store: " .. key)
	end
	-- v2.3 prices: config suggestion until an Id is set, then the live Creator Hub price
	local vipButton = storeCard("VIP"):FindFirstChildWhichIsA("TextButton", true)
	check(PurchaseController.GetPrice("GamePass", "VIP") == 349, "VIP suggested price is 349")
	Config.Monetization.GamePasses.VIP.Id = 7101
	Mock.ProductPrices[7101] = 379
	check(PurchaseController.GetPrice("GamePass", "VIP") == 349, "price falls back to config while the lookup runs")
	Mock.Advance(0.5)
	check(PurchaseController.GetPrice("GamePass", "VIP") == 379, "live price from GetProductInfo")
	local liveShown = false
	for _, d in storeCard("VIP"):GetDescendants() do
		if d:IsA("TextLabel") and d.Text == "R$ 379" then
			liveShown = true
		end
	end
	check(liveShown, "store button shows the live price")
	local _ = vipButton
	Config.Monetization.GamePasses.VIP.Id = 0
	Config.Monetization.Products.CoinsMedium.Id = 9102 -- GetProductInfo answers 0: keep the config price
	check(PurchaseController.GetPrice("Product", "CoinsMedium") == 149, "coin pack price before lookup")
	Mock.Advance(0.5)
	check(PurchaseController.GetPrice("Product", "CoinsMedium") == 149, "off-sale / unknown live price falls back to config")
	Config.Monetization.Products.CoinsMedium.Id = 0
	check(storeCard("CoolerPack") == nil, "no Cooler Pack in the store")
	player:SetAttribute("PaidRandomRestricted", true)
	Mock.Advance(0.5)
	for _, key in { "CoinsSmall", "CoinsMedium", "CoinsLarge", "CoinsHuge", "SkipRebirth" } do
		check(storeCard(key) and storeCard(key).Visible == false, "restricted: store hides " .. key)
	end
	check(storeCard("SandBoost15").Visible and storeCard("DoubleSand").Visible and storeCard("FastDig").Visible, "restricted: other items still shown")
	Config.Monetization.Products.CoinsSmall.Id = 9001
	local p0 = #Mock.Prompts
	check(PurchaseController.PromptProduct("CoinsSmall") == false, "restricted: PurchaseController refuses")
	check(#Mock.Prompts == p0, "restricted: no MarketplaceService prompt")
	Config.Monetization.Products.CoinsSmall.Id = 0
	Panel.CloseAll()
	Mock.Advance(0.3)
	Panel.Open("Eggs", { EggId = "golden_egg" })
	Mock.Advance(1)
	local eggs = Panel.Get("Eggs").Window
	local goldenTile = eggs:FindFirstChild("golden_egg", true)
	check(goldenTile and goldenTile.Visible == true, "v2.3: the Golden Egg is a token egg, listed even when restricted")
	local kindLabel = eggs:FindFirstChild("Kind", true)
	check(eggs:FindFirstChild("Detail", true) and #Mock.Errors == e0, "restricted: egg panel still works")
	player:SetAttribute("PaidRandomRestricted", false)
	Mock.Advance(0.5)
	check(goldenTile.Visible == true, "unrestricted: Golden Egg listed")

	-- A1 true odds: 2x Luck boost + pity, live (v2.3: no pass changes luck, VIP included)
	local beach = Config.GetEgg("beach_egg")
	State.SetPassOwned("VIP", true)
	Mock.FireClientEvent("DataChanged", { Boosts = { LuckBoost = os.time() + 3600 }, Pity = { beach_egg = 5 }, MaxDepth = Config.TOTAL_DEPTH })
	Mock.Advance(0.5)
	Panel.Open("Eggs", { EggId = beach.Id })
	Mock.Advance(1.2)
	local luck = Stats.GetLuck(State.GetStatsContext())
	-- events may also be active (an earlier section left High Tide on): they count too
	local eventLuck = 1
	for _, id in State.ActiveEvents do
		local ev = Config.GetEvent(id)
		if ev and ev.Kind == "Luck" then
			eventLuck *= ev.Multiplier
		end
	end
	check(luck == 2 * eventLuck, "client luck = 2x Luck x2 * events, VIP adds none (" .. luck .. ")")
	local function shownRows()
		local rows = {}
		for _, entry in beach.Pets do
			local row = eggs:FindFirstChild(entry.PetId, true)
			local label = row and row:FindFirstChild("Chance", true)
			rows[entry.PetId] = label and label.Text
		end
		return rows
	end
	local function matches(pity)
		local rows = shownRows()
		local list = Stats.GetHatchOddsList(beach, luck, pity)
		for _, odd in list do
			if rows[odd.PetId] ~= Format.Chance(odd.Chance) then
				return false, odd.PetId .. " shows " .. tostring(rows[odd.PetId]) .. " want " .. Format.Chance(odd.Chance)
			end
		end
		return true, ""
	end
	local ok, why = matches(5)
	check(ok, "egg panel shows Stats.GetHatchOddsList with luck + pity " .. why)
	check(kindLabel.Text == "Your odds per hatch:", "odds header no longer says 'before luck boosts'")
	local note = eggs:FindFirstChild("LuckNote", true)
	check(note and string.find(note.Text, "x" .. luck, 1, true) and not string.find(note.Text, "VIP", 1, true) and string.find(note.Text, "2x Luck", 1, true), "luck note lists the modifiers: " .. (note and note.Text or "nil"))
	check(note and string.find(note.Text, "Rare+ guaranteed in " .. (beach.PityAt + 1 - 5) .. " hatches", 1, true), "pity countdown in the detail")
	local beachTile = eggs:FindFirstChild(beach.Id, true)
	local pityLabel = beachTile and beachTile:FindFirstChild("Pity", true)
	check(pityLabel and pityLabel.Text == "Rare+ in " .. (beach.PityAt + 1 - 5), "egg card shows the pity countdown")
	local texts = EggPanel.GetDisplayedOdds(beach.Id)
	local direct = Stats.GetHatchOdds(beach, luck, 5)
	check(texts.golden_crab == Format.Chance(direct.golden_crab), "GetDisplayedOdds == Stats.GetHatchOdds")
	-- boost expires -> odds update without reopening
	Mock.FireClientEvent("DataChanged", { Boosts = {} })
	Mock.Advance(1.2)
	luck = Stats.GetLuck(State.GetStatsContext())
	ok, why = matches(5)
	check(luck == eventLuck and ok, "odds update live when a boost ends " .. why)
	-- pity reached: the guaranteed hatch shows the Rare+ distribution
	Mock.FireClientEvent("DataChanged", { Pity = { beach_egg = beach.PityAt } })
	Mock.Advance(0.6)
	ok, why = matches(beach.PityAt)
	check(ok and shownRows().sandy_crab == "0%", "pity hatch shows Rare+ odds " .. why)
	check(string.find(note.Text, "PITY", 1, true) ~= nil and pityLabel.Text == "Rare+ next hatch!", "pity active is announced")
	State.SetPassOwned("VIP", false)
	Panel.CloseAll()
	Mock.Advance(0.5)

	-- Reveal shows the true chance of the hatched pet
	local popups = playerGui:FindFirstChild("Dig_Popups"):FindFirstChild("Canvas")
	Mock.FireClientEvent("EggHatched", { "golden_crab" }, { EggId = beach.Id, Chances = { 0.0025 }, Pity = { false } })
	Mock.Advance(4)
	local chanceRow = false
	for _, d in popups:GetDescendants() do
		if d:IsA("TextLabel") and d.Text == "0.25%" then
			chanceRow = true
		end
	end
	check(chanceRow, "hatch reveal shows the CHANCE row (0.25%)")
	Mock.Advance(6)

	-- B9 fusion UI
	local pets = {}
	for i = 1, 5 do
		pets[string.format("{F0000000-0000-4000-8000-00000000000%d}", i)] = { Id = "sandy_crab", Equipped = i == 1 }
	end
	pets["{F0000000-0000-4000-8000-000000000009}"] = { Id = "toy_truck", Equipped = true, Golden = true }
	Mock.FireClientEvent("DataChanged", { Pets = pets })
	Mock.Advance(0.5)
	Panel.Open("Pets", {})
	Mock.Advance(1)
	local petsWindow = Panel.Get("Pets").Window
	local crabTile = petsWindow:FindFirstChild("{F0000000-0000-4000-8000-000000000002}", true)
	click(crabTile:FindFirstChild("Face", true))
	Mock.Advance(0.5)
	local fuse = petsWindow:FindFirstChild("Fuse", true)
	local fuseText = fuse and fuse:FindFirstChildWhichIsA("TextLabel", true)
	check(fuse and fuse.Visible and fuseText and string.find(fuseText.Text, "Fuse 5", 1, true), "Fuse 5 -> Golden offered with 5 copies")
	local s0 = #Mock.Remote.ToServer
	click(fuse)
	Mock.Advance(0.5)
	local fuses = sent("FusePets", s0)
	check(#fuses == 1 and fuses[1][1] == "{F0000000-0000-4000-8000-000000000002}", "Fuse sends FusePets(uid)")
	local goldenTile2 = petsWindow:FindFirstChild("{F0000000-0000-4000-8000-000000000009}", true)
	check(goldenTile2 and goldenTile2:FindFirstChild("GoldenTag", true) ~= nil, "Golden pet tile is tagged GOLDEN")
	click(goldenTile2:FindFirstChild("Face", true))
	Mock.Advance(0.5)
	check(not fuse.Visible, "no Fuse button on a Golden pet")
	local viewport = petsWindow:FindFirstChild("Detail", true):FindFirstChildWhichIsA("ViewportFrame", true)
	local model = viewport and viewport:FindFirstChildWhichIsA("Model", true)
	check(model and model:GetAttribute("Golden") == true, "Golden pet preview is gold-tinted")
	Panel.CloseAll()
	-- followers: EquippedGolden marks the slot
	player:SetAttribute("EquippedPets", "sandy_crab,toy_truck")
	player:SetAttribute("EquippedGolden", "2")
	Mock.Advance(0.5)
	local visuals = PetFollowController.GetVisuals(player)
	local goldenOk = #visuals == 2
	for _, v in visuals do
		local want = v.Id == "toy_truck"
		goldenOk = goldenOk and v.Golden == want and (v.Model:GetAttribute("Golden") == true) == want
	end
	check(goldenOk, "Golden follower rendered gold (and only it)")
	check(visuals[2] and visuals[2].Model:FindFirstChild("GoldenSparkles", true) ~= nil, "Golden follower sparkles")
	player:SetAttribute("EquippedGolden", "")
	player:SetAttribute("EquippedPets", "")
	Mock.Advance(0.3)
	local _ = HatchAnimation
	check(#Mock.Errors == e0, "hatching + compliance client section: no errors")
end

section("status & social")
do
	local e0 = #Mock.Errors
	local StatusController = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/StatusController"])
	local Announcements = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/Announcements"])
	local SocialHUD = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/SocialHUD"])
	local Toasts = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/Toasts"])
	local Layout = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/Layout"])
	local Models = Mock.Require(byPath["ReplicatedStorage/Shared/Models"])
	local State = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/State"])
	local workspace = Mock.Service("Workspace")

	-- stars
	check(StatusController.StarsText(0) == "", "no rebirths: no stars")
	check(StatusController.StarsText(3) == "★★★", "3 rebirths: 3 stars")
	check(StatusController.StarsText(Config.Social.Nameplate.StarsInline) == string.rep("★", Config.Social.Nameplate.StarsInline), "inline stars up to the cap")
	check(StatusController.StarsText(12) == "★x12", "12 rebirths: ★x12")

	-- nameplates for every player (local + another), from attributes
	local me = Mock.Service("Players").LocalPlayer
	if not me.Character or not me.Character:FindFirstChild("Head") then
		Mock.SpawnCharacter(me, spawnCF.Position)
	end
	Mock.Advance(0.5)
	me:SetAttribute("TitleLayer", 5)
	me:SetAttribute("RebirthCount", 3)
	me:SetAttribute("VIP", true)
	Mock.Advance(0.2)
	local plate = StatusController.GetPlate(me)
	check(plate ~= nil and plate:IsA("BillboardGui"), "local player has a nameplate")
	if plate then
		local title5, color5 = Config.GetTitle(5)
		check(plate.MaxDistance == Config.Social.Nameplate.MaxDistance and plate.AlwaysOnTop == false, "nameplate: short MaxDistance, not always on top")
		check(plate.Adornee == me.Character.Head, "nameplate on the head")
		check(plate.Title.Text == title5 and plate.Title.TextColor3 == color5, "title + layer colour (" .. plate.Title.Text .. ")")
		check(plate.Stars.Text == "★★★" and plate.Stars.Visible, "rebirth stars shown")
		check(plate.Tag.Visible and plate.Tag.Text == "VIP", "VIP tag")
		check(plate.PlayerName.Text == me.DisplayName, "display name")
		local strokes = 0
		for _, d in plate:GetDescendants() do
			if d:IsA("UIStroke") then
				strokes += 1
			end
		end
		check(strokes >= 4, "nameplate text is outlined")
		me:SetAttribute("VIP", false)
		me:SetAttribute("Premium", true)
		me:SetAttribute("RebirthCount", 12)
		Mock.Advance(0.1)
		check(plate.Tag.Text == "PREMIUM" and plate.Stars.Text == "★x12", "Premium tag, ★x12")
		me:SetAttribute("Premium", false)
		Mock.Advance(0.1)
		check(not plate.Tag.Visible, "no tag without VIP / Premium")
		-- settings toggle
		local humanoid = me.Character:FindFirstChildOfClass("Humanoid")
		check(humanoid.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.None, "default name hidden while nameplates show")
		State.SetSetting("ShowNameplates", false)
		Mock.Advance(0.1)
		check(plate.Enabled == false and humanoid.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.Viewer, "Nameplates OFF: hidden, default names back")
		State.SetSetting("ShowNameplates", true)
		Mock.Advance(0.1)
		check(plate.Enabled == true, "Nameplates ON again")
	end
	local other = Mock.AddPlayer(1002, "Buddy")
	other:SetAttribute("TitleLayer", #Config.Layers)
	Mock.SpawnCharacter(other, spawnCF.Position + Vector3.new(6, 0, 0))
	Mock.Advance(0.3)
	local otherPlate = StatusController.GetPlate(other)
	check(otherPlate ~= nil and otherPlate.Title.Text == "Core Breaker", "other players get nameplates too")
	local d = StatusController.Describe(other)
	check(d.Title == "Core Breaker" and d.Stars == "" and d.Tag == nil, "Describe(other)")

	-- a reveal headline sits where your own plate floats: it hides only yours, only meanwhile
	do
		local RevealUI = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/Reveal"])
		local mine = StatusController.GetPlate(me)
		Mock.Advance(15)
		check(mine ~= nil and mine.Enabled, "own nameplate shown before the reveal")
		RevealUI.Show({ Headline = "EPIC!", Color = Mock.Env.Color3.new(1, 0, 1), Items = { { Name = "Shell", Rows = {} } }, Hold = 2 })
		Mock.Advance(0.3)
		check(mine ~= nil and not mine.Enabled, "own nameplate hidden while a reveal is showing")
		check(otherPlate ~= nil and otherPlate.Enabled, "other players' nameplates stay visible")
		Mock.Advance(3)
		check(not RevealUI.IsShowing() and mine ~= nil and mine.Enabled, "own nameplate returns after the reveal")
	end

	-- worn backpack sand level (client-side visual)
	local pack = Models.Backpack(Config.Backpacks[1].Id)
	pack.Name = "WornBackpack"
	pack.Parent = other.Character
	local sandFill = pack:FindFirstChild("SandFill", true)
	check(sandFill ~= nil, "bucket has a SandFill part")
	if sandFill then
		local fullY = sandFill.Size.Y
		local color0 = sandFill.Color
		other:SetAttribute("BackpackFill", 1)
		Mock.Advance(0.1)
		check(math.abs(sandFill.Size.Y - fullY) < 1e-6 and sandFill.Color == Config.Theme.Colors.Gold, "full pack: full height, gold")
		other:SetAttribute("BackpackFill", 0.5)
		Mock.Advance(0.1)
		check(sandFill.Size.Y < fullY and sandFill.Color == color0, "half pack: lower sand")
		other:SetAttribute("BackpackFill", 0)
		Mock.Advance(0.1)
		check(sandFill.Transparency == 1, "empty pack: no sand")
	end
	Mock.RemovePlayer(other)
	Mock.Advance(0.2)
	check(StatusController.GetPlate(other) == nil, "nameplate removed when the player leaves")

	-- announcements: parse, banner, queue + rate limit, not a toast
	local parsed = Announcements.Parse("Sandy found a LEGENDARY Golden Idol!")
	check(parsed and parsed.Player == "Sandy" and parsed.Rarity == "Legendary" and parsed.Item == "Golden Idol" and parsed.Verb == "found", "parse a find")
	local hatch = Announcements.Parse("Max hatched a MYTHIC Mega Excavator!")
	check(hatch and hatch.Rarity == "Mythic" and hatch.Verb == "hatched", "parse a hatch")
	check(Announcements.Parse("SERVER GOAL REACHED! 5K sand dug together: GOLDEN HOUR for everyone!") == nil, "other text: plain banner")
	Mock.Advance(Config.Social.Announce.Duration + 2)
	local popups = playerGui:FindFirstChild("Dig_Popups")
	local toastLayer = playerGui:FindFirstChild("Dig_Toasts")
	Mock.FireClientEvent("Notify", "Announce", "Sandy found a LEGENDARY Golden Idol!")
	Mock.Advance(0.2)
	check(Announcements.IsShowing(), "announcement banner showing")
	local banner = popups and popups:FindFirstChild("Announcement", true)
	check(banner ~= nil, "gold banner in the popup layer")
	if banner then
		local tag = banner:FindFirstChild("Tag")
		check(tag and tag.Text == "LEGENDARY!" and tag.BackgroundColor3 == Config.GetRarity("Legendary").Color, "rarity pill in the rarity colour")
		local text = banner:FindFirstChild("Text", true)
		check(text and string.find(text.Text, "Golden Idol", 1, true) ~= nil and string.find(text.Text, "Sandy", 1, true) ~= nil, "banner names player + item")
	end
	local toastHit = false
	for _, dsc in toastLayer:GetDescendants() do
		if dsc:IsA("TextLabel") and string.find(dsc.Text, "Golden Idol", 1, true) then
			toastHit = true
		end
	end
	check(not toastHit, "Announce goes to the banner, not a toast")
	for i = 1, 8 do
		Mock.FireClientEvent("Notify", "Announce", "Player" .. i .. " hatched a MYTHIC Mega Excavator!")
	end
	Mock.Advance(0.1)
	check(Announcements.QueueLength() <= Config.Social.Announce.MaxQueued, "queue capped (" .. Announcements.QueueLength() .. ")")
	Mock.Advance(1)
	local visible = 0
	for _, dsc in popups:GetDescendants() do
		if dsc.Name == "Announcement" then
			visible += 1
		end
	end
	check(visible == 1, "one banner at a time")
	Mock.Advance((Config.Social.Announce.Duration + Config.Social.Announce.Gap + 1) * (Config.Social.Announce.MaxQueued + 2))
	check(Announcements.QueueLength() == 0 and not Announcements.IsShowing(), "queue drains")
	check(Toasts ~= nil, "toasts still loaded")

	-- social HUD: server goal bar + friends chip, in the Layout "Social" region
	local holder = SocialHUD.Holder
	check(holder ~= nil, "social HUD built")
	if holder then
		local r = Layout.Current().Social
		check(holder.Position.X.Offset == r.X and holder.Position.Y.Offset == r.Y, "social HUD placed by Layout")
		workspace:SetAttribute("ServerGoalTarget", 5000)
		workspace:SetAttribute("ServerGoalProgress", 2500)
		workspace:SetAttribute("ServerGoalResumeAt", 0)
		Mock.Advance(0.2)
		local bar = holder:FindFirstChild("GoalBar")
		local label = bar and bar:FindFirstChildWhichIsA("TextLabel", true)
		local barText = ""
		for _, dsc in bar:GetDescendants() do
			if dsc:IsA("TextLabel") and string.find(dsc.Text, "Server goal", 1, true) then
				barText = dsc.Text
			end
		end
		check(bar ~= nil and bar.Visible and barText == SocialHUD.GoalText(2500, 5000, 0), "goal bar: " .. barText)
		local _ = label
		workspace:SetAttribute("ServerGoalResumeAt", workspace:GetServerTimeNow() + 120)
		Mock.Advance(1.2)
		local reachedText = ""
		for _, dsc in bar:GetDescendants() do
			if dsc:IsA("TextLabel") and string.find(dsc.Text, "Goal reached", 1, true) then
				reachedText = dsc.Text
			end
		end
		check(reachedText ~= "", "goal bar shows the cooldown after a goal")
		workspace:SetAttribute("ServerGoalResumeAt", 0)
		local chip = holder:FindFirstChild("FriendsChip")
		check(chip and not chip.Visible, "no friends: chip hidden")
		check(SocialHUD.FriendBonusText(0) == nil and SocialHUD.FriendBonusText(2) == "Friends +10%", "friend bonus text")
		local maxPct = math.floor(Config.FRIEND_BONUS_MAX * 100 + 0.5)
		check(SocialHUD.FriendBonusText(99) == "Friends +" .. maxPct .. "%", "friend bonus capped")
		me:SetAttribute("FriendsInServer", 2)
		Mock.Advance(0.2)
		check(chip and chip.Visible and chip.Text.Text == "Friends +10%", "friends chip visible with friends here")
		me:SetAttribute("FriendsInServer", 0)
	end

	-- invite: every SocialService call is pcall'd
	local invites0 = #Mock.Invites
	local ok1, why1 = SocialHUD.PromptInvite()
	check(ok1 and why1 == "Opened" and #Mock.Invites == invites0 + 1, "invite dialog opened")
	Mock.CanInvite = false
	local ok2, why2 = SocialHUD.PromptInvite()
	check(not ok2 and why2 == "NotAllowed", "CanSendGameInviteAsync false: no prompt")
	Mock.CanInvite = true
	Mock.InviteFail = true
	local ok3, why3 = SocialHUD.PromptInvite()
	check(not ok3 and why3 == "Error", "SocialService error is caught")
	Mock.InviteFail = false
	-- the Settings card button
	local Panel = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/Components/Panel"])
	Panel.Open("Settings", {})
	Mock.Advance(0.5)
	local inviteButton = nil
	for _, dsc in playerGui:GetDescendants() do
		if dsc.Name == "InviteButton" then
			inviteButton = dsc
		end
	end
	check(inviteButton ~= nil, "Settings has an Invite button")
	if inviteButton then
		local face = inviteButton:FindFirstChild("Face")
		local before = #Mock.Invites
		Mock.FireEvent(face, "Activated", Mock.Input(Enum.UserInputType.MouseButton1), 1)
		Mock.Advance(0.3)
		check(#Mock.Invites == before + 1, "Invite button opens the invite dialog")
	end
	Panel.CloseAll()
	Mock.Advance(0.5)
	check(#Mock.Errors == e0, "status & social client section: no errors")
end

-- Rebirth & economy (v2.2): Rebirth panel tabs + recovery preview, perk rows, Sell Anywhere via
-- perk on the HUD, offline earnings popup ---------------------------------------------------------
section("rebirth & economy")
do
	local e0 = #Mock.Errors
	local Panel = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/Components/Panel"])
	local HUD = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/HUD"])
	local State = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/State"])
	local RebirthPanel = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/Panels/RebirthPanel"])
	local OfflinePopup = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/OfflinePopup"])
	local Perks = Config.RebirthPerks
	local function click(button)
		Mock.FireEvent(button, "Activated", Mock.Input(Enum.UserInputType.MouseButton1), 1)
		Mock.Advance(0.3)
	end

	-- recovery preview text (pure)
	local text, ratio = RebirthPanel.RecoveryText(0, Config.Layers[9].DepthStart + 1)
	check(
		string.find(text, Config.Layers[9].Name, 1, true) ~= nil and string.find(text, "1.5", 1, true) ~= nil and ratio == 1.5,
		"recovery preview: " .. text
	)
	check(select(2, RebirthPanel.RecoveryText(3, 0)) == Config.RebirthMultiplier(4) / Config.RebirthMultiplier(3), "recovery ratio = multiplier ratio")
	check(string.find(RebirthPanel.PerkStartText({ HeadStart = 1 }), Config.Shovels[Perks.Get("HeadStart").Levels[1].ShovelIndex].Name, 1, true) ~= nil, "perk note names the Head Start shovel")
	for _, def in Perks.List do
		for level = 0, #def.Costs do
			local stat = RebirthPanel.PerkStat(def.Id, level)
			check(type(stat.Main) == "string" and stat.Main ~= "", def.Id .. " L" .. level .. " stat text")
		end
	end

	Mock.FireClientEvent("DataChanged", {
		Coins = 100,
		Rebirths = 0,
		RebirthTokens = 3,
		RebirthPerks = { PetDen = 2 },
		MaxDepth = Config.Layers[9].DepthStart + 1,
	})
	Mock.Advance(0.4)
	Panel.CloseAll()
	Mock.Advance(0.3)
	Panel.Open("Rebirth", { Tab = "Rebirth" })
	Mock.Advance(0.6)
	local window = Panel.Get("Rebirth").Window
	local rebirthPage = window:FindFirstChild("RebirthPage", true)
	local perksPage = window:FindFirstChild("PerksPage", true)
	check(rebirthPage ~= nil and perksPage ~= nil, "Rebirth panel has Rebirth + Perks pages")
	check(rebirthPage.Visible and not perksPage.Visible, "Rebirth tab shown first")
	local recovery = rebirthPage:FindFirstChild("Recovery", true)
	check(recovery ~= nil and string.find(recovery.Text, Config.Layers[9].Name, 1, true) ~= nil, "recovery preview names your deepest layer: " .. tostring(recovery and recovery.Text))
	local perksTab = window:FindFirstChild("PerksTab", true)
	click(perksTab:FindFirstChild("Face"))
	check(perksPage.Visible and not rebirthPage.Visible and RebirthPanel.CurrentTab() == "Perks", "Perks tab button switches pages")
	local list = perksPage:FindFirstChild("PerkList", true)
	local rows = 0
	for _, def in Perks.List do
		if list:FindFirstChild(def.Id) then
			rows += 1
		end
	end
	check(rows == #Perks.List, "one upgrade row per perk (" .. rows .. ")")
	local denRow = list:FindFirstChild("PetDen")
	local denLabel = denRow:FindFirstChild("Action", true):FindFirstChild("Label", true)
	check(denLabel ~= nil and denLabel.Text == "MAX", "maxed perk shows MAX")
	local touchRow = list:FindFirstChild("GoldenTouch")
	local touchNext = touchRow:FindFirstChild("Next", true):FindFirstChild("Main")
	check(touchNext.Text == "Coins +10%", "next level spelled out: " .. touchNext.Text)
	local s0 = #Mock.Remote.ToServer
	click(touchRow:FindFirstChild("Action", true):FindFirstChild("Face"))
	local buys = sent("BuyRebirthPerk", s0)
	check(#buys == 1 and buys[1][1] == "GoldenTouch", "perk price button sends BuyRebirthPerk(id)")
	Mock.FireClientEvent("DataChanged", { RebirthTokens = 2, RebirthPerks = { PetDen = 2, GoldenTouch = 1 } })
	Mock.Advance(0.4)
	check(touchNext.Text == "Coins +20%", "row moves to the next level after buying")
	Panel.CloseAll()
	Mock.Advance(0.3)
	Panel.Open("Rebirth", { Tab = "Perks" })
	Mock.Advance(0.4)
	check(perksPage.Visible, "Panel.Open(Rebirth, { Tab = Perks })")
	Panel.CloseAll()
	Mock.Advance(0.3)

	-- Sell Anywhere from the perk (no pass): HUD Sell button works
	local passes = table.clone(State.Passes)
	passes.SellAnywhere = false
	State.Apply({ Passes = passes })
	Mock.FireClientEvent("DataChanged", { RebirthPerks = { SellAnywhere = 1 } })
	Mock.Advance(0.4)
	check(State.CanSellAnywhere(), "State.CanSellAnywhere via perk")
	local sell = HUD.Buttons.Sell
	check(sell.Holder.Visible and sell.Label.Text == "Sell", "HUD Sell button visible for the perk")
	local s1 = #Mock.Remote.ToServer
	click(sell.Face)
	local sets = sent("SetSetting", s1)
	check(#sets == 1 and sets[1][1] == "SellNow", "Sell button sells anywhere with the perk")
	Mock.FireClientEvent("DataChanged", { RebirthPerks = {} })
	Mock.Advance(0.4)
	check(not State.CanSellAnywhere(), "no pass, no perk: cannot sell anywhere")

	-- Offline earnings popup
	local popups = playerGui:FindFirstChild("Dig_Popups"):FindFirstChild("Canvas")
	Mock.FireClientEvent("OfflineEarnings", "junk")
	Mock.FireClientEvent("OfflineEarnings", { Coins = 0 })
	Mock.Advance(0.3)
	check(popups:FindFirstChild("Reveal") == nil, "junk / zero offline payloads show nothing")
	Mock.FireClientEvent("OfflineEarnings", {
		Seconds = 7200,
		Away = 30000,
		Sand = 12345,
		Coins = 12345,
		CapSeconds = 7200,
		Capped = true,
		PetId = "toy_truck",
	})
	Mock.Advance(0.8)
	local reveal = popups:FindFirstChild("Reveal")
	local headline = reveal and reveal:FindFirstChild("Headline", true)
	check(headline ~= nil and headline.Text == "WELCOME BACK!", "offline earnings open the welcome-back popup")
	check(string.find(OfflinePopup.LastText, "12.3K sand", 1, true) ~= nil and string.find(OfflinePopup.LastText, "+12.3K coins", 1, true) ~= nil, "popup text: " .. OfflinePopup.LastText)
	local limit = false
	for _, d in reveal:GetDescendants() do
		if d:IsA("TextLabel") and string.find(d.Text, "Long Nap", 1, true) then
			limit = true
		end
	end
	check(limit, "capped absence points at the Long Nap perk")
	Mock.FireEvent(reveal, "Activated", Mock.Input(Enum.UserInputType.MouseButton1), 1)
	Mock.Advance(1.5)
	check(popups:FindFirstChild("Reveal") == nil, "tap collects / closes the popup")
	check(#Mock.Errors == e0, "no errors in rebirth & economy (client)")
end

-- Discovery (v3 slice): detector UI from coarse pings, excavation minigame flow, reveal tiers,
-- streaming-safe find models ------------------------------------------------------------------
section("discovery")
do
	local e0 = #Mock.Errors
	local CP = "StarterPlayer/StarterPlayerScripts/Client/"
	local DiscoveryController = Mock.Require(byPath[CP .. "Controllers/DiscoveryController"])
	local DetectorHUD = Mock.Require(byPath[CP .. "UI/DetectorHUD"])
	local ExcavationGame = Mock.Require(byPath[CP .. "UI/ExcavationGame"])
	local FindReveal = Mock.Require(byPath[CP .. "UI/FindReveal"])
	local DigController = Mock.Require(byPath[CP .. "Controllers/DigController"])
	local HUD = Mock.Require(byPath[CP .. "UI/HUD"])
	local D = Config.Discovery
	local workspace = Mock.Service("Workspace")
	Panel.CloseAll()
	Mock.Advance(6) -- let earlier reveals / toasts clear

	-- Scan button: in the bottom action row, as big as Surface / Sell / Auto
	local scan = HUD.Buttons.Scan
	check(scan ~= nil and scan.Holder.Parent == HUD.ActionsRow, "Scan button sits in the bottom action row")
	check(scan ~= nil and scan.Holder.Size.Y.Offset >= 74 and scan.Holder.Size.X.Offset >= 74, "Scan button >= 74 design px")
	-- Scan cooldown (client mirror)
	Mock.Advance(D.SCAN_COOLDOWN + 0.5)
	local s0 = #Mock.Remote.ToServer
	check(DiscoveryController.Scan() == true, "Scan sends a request")
	check(DiscoveryController.Scan() == false, "Scan again during the cooldown does nothing")
	check(#sent("Scan", s0) == 1, "exactly one Scan remote")
	check(DiscoveryController.CooldownLeft() > 0, "cooldown counting")

	-- detector UI from coarse server data
	Mock.FireClientEvent("DetectorPing", { Band = 1, Sector = 2, Vertical = "Down", Signal = "Gold", Remaining = 6 })
	Mock.Advance(0.3)
	check(DiscoveryController.Ping.Band == 1 and DiscoveryController.IsScanning(), "ping stored, scanning")
	check(scan.Label.Text == "HOT!", "HOT! when the find is close (" .. scan.Label.Text .. ")")
	local pill = scan.Holder:FindFirstChild("Vertical")
	check(pill ~= nil and pill.Visible and pill.Text == "DIG DOWN!", "hot and below: the pill says DIG DOWN!")
	local dot = scan.Holder:FindFirstChild("Dot", true)
	check(dot ~= nil and dot.Visible and dot.BackgroundColor3 == D.SIGNAL_COLORS.Gold, "radar dot in the gold signal colour")
	local radar = scan.Holder:FindFirstChild("Radar")
	local stroke = radar and radar:FindFirstChildOfClass("UIStroke")
	check(stroke ~= nil and stroke.Color == D.SIGNAL_COLORS.Gold and stroke.Transparency == 0, "radar outline glows gold")
	check(math.abs(DiscoveryController.ArrowAngle(Vector3.new(0, 0, 1)) + 90) < 1e-6, "sector +X with the camera looking +Z: arrow points left")
	check(math.abs(DiscoveryController.ArrowAngle(Vector3.new(0, 0, -1)) - 90) < 1e-6, "camera looking -Z: arrow points right")
	local arrow = workspace:FindFirstChild("DetectorArrow")
	check(arrow ~= nil and arrow.Transparency < 1 and arrow.Color == D.SIGNAL_COLORS.Gold, "ground arrow shows while scanning")
	local headL, headR = arrow and arrow:FindFirstChild("HeadLeft"), arrow and arrow:FindFirstChild("HeadRight")
	check(headL ~= nil and headR ~= nil and headL.Transparency < 1 and headR.Color == D.SIGNAL_COLORS.Gold, "ground arrow has a visible chevron head")
	if headL and headR and arrow then
		-- both arms sit further along the pointing direction than the shaft centre
		local dirX = Vector3.new(1, 0, 0) -- sector 2 of 8 = +X
		local shaftAlong = arrow.Position:Dot(dirX)
		check(headL.Position:Dot(dirX) > shaftAlong and headR.Position:Dot(dirX) > shaftAlong, "chevron head is at the tip end of the arrow")
	end
	check(dot:FindFirstChild("Pointer") ~= nil, "radar dot carries an arrowhead")
	Mock.FireClientEvent("DetectorPing", { Band = 4, Sector = 0, Vertical = "Level", Signal = "Purple", Remaining = 3 })
	Mock.Advance(0.3)
	check(scan.Label.Text == "Faint" and not pill.Visible, "Faint at the edge of range, no pill when level")
	Mock.FireClientEvent("DetectorPing", { Band = 0, Sector = -1, Vertical = "", Signal = "", Remaining = 2 })
	Mock.Advance(0.3)
	check(scan.Label.Text == "Nothing" and not dot.Visible, "Nothing in range")
	Mock.FireClientEvent("DetectorPing", "junk")
	Mock.FireClientEvent("DetectorPing", { Band = 99, Sector = "x" })
	Mock.Advance(0.2)
	check(DiscoveryController.Ping.Band <= #D.BANDS + 1 and DiscoveryController.Ping.Sector == -1, "junk pings are sanitised")
	Mock.Advance(D.SCAN_SECONDS + 1)
	check(not DiscoveryController.IsScanning() and (arrow.Transparency == 1), "scan over: arrow hidden")
	check(DetectorHUD.Caption({ Band = 2, Sector = 0, Vertical = "", Signal = "", Remaining = 1 }, true, 0) == "Warm", "Caption: Warm")
	local function instr(band, vertical, scanning)
		return DetectorHUD.Instruction({ Band = band, Sector = 0, Vertical = vertical, Signal = "", Remaining = 1 }, scanning)
	end
	check(instr(1, "Level", true) == "DIG HERE!", "Instruction: hot and level -> DIG HERE!")
	check(instr(1, "Down", true) == "DIG DOWN!" and instr(1, "Up", true) == "UP HERE!", "Instruction: hot below / above")
	check(instr(2, "Down", true) == "DOWN" and instr(3, "Up", true) == "UP" and instr(3, "Level", true) == "", "Instruction: farther away keeps DOWN / UP")
	check(instr(1, "Down", false) == "" and instr(0, "Down", true) == "", "Instruction: nothing when not scanning or nothing in range")
	check(DetectorHUD.Caption({ Band = 0, Sector = -1, Vertical = "", Signal = "", Remaining = 0 }, false, 2.2) == "3s", "Caption: cooldown seconds")
	check(DetectorHUD.Caption({ Band = 0, Sector = -1, Vertical = "", Signal = "", Remaining = 0 }, false, 0) == "Scan", "Caption: ready")

	-- excavation minigame: headless state machine with a pinned clock
	local info = {
		Id = "x900",
		Position = Vector3.new(0, Config.SURFACE_Y - 4, zone.CFrame.Position.Z),
		Signal = "White",
		Rings = 3,
		RingSeconds = 0.9,
		RingGap = 0.25,
		PerfectWindow = D.PERFECT_WINDOW,
		GoodWindow = D.GOOD_WINDOW,
		Timeout = 9,
	}
	-- Actual excavation lifecycle owns toast suppression, including the retiring grade.
	do
		local Toasts = Mock.Require(byPath[CP .. "UI/Toasts"])
		local toastRoot = playerGui:FindFirstChild("Dig_Toasts"):FindFirstChild("Canvas"):FindFirstChild("Toasts")
		local function hasLifecycleToast()
			for _, descendant in toastRoot:GetDescendants() do
				if descendant:IsA("TextLabel") and descendant.Text == "Lifecycle collection notice" then
					return true
				end
			end
			return false
		end
		Toasts.Show("Lifecycle collection notice", "Info", 8)
		check(hasLifecycleToast(), "lifecycle notice visible before actual Start")
		local startAt = Mock.Now()
		ExcavationGame.Start(info, startAt)
		check(not hasLifecycleToast(), "actual Start suppresses existing notice")
		ExcavationGame.Step(startAt + 20)
		Mock.Advance(0.3)
		check(not ExcavationGame.IsActive() and not hasLifecycleToast(), "finished rings keep notices held during final-grade retirement")
		Mock.Advance(0.4)
		check(hasLifecycleToast(), "finished excavation resumes notice after final-grade retirement")

		local nextInfo = table.clone(info)
		nextInfo.Id = "toast-replacement"
		startAt = Mock.Now()
		ExcavationGame.Start(info, startAt)
		ExcavationGame.Step(startAt + 20)
		Mock.Advance(0.3)
		ExcavationGame.Start(nextInfo, Mock.Now())
		Mock.Advance(0.4)
		check(ExcavationGame.IsActive() and not hasLifecycleToast(), "stale teardown cannot release notices during replacement excavation")
		ExcavationGame.DismissForReveal("unrelated-toast-find")
		check(ExcavationGame.IsActive() and not hasLifecycleToast(), "unrelated reveal leaves replacement excavation hold intact")
		ExcavationGame.DismissForReveal(nextInfo.Id)
		check(not ExcavationGame.IsActive(), "matching reveal dismisses active replacement excavation")
		Mock.Advance(0.7)
		check(hasLifecycleToast(), "matching reveal dismissal releases excavation notice hold")
		Mock.Advance(9)
	end

	local x0 = #Mock.Remote.ToServer
	ExcavationGame.Start(info, 100, true)
	check(ExcavationGame.IsActive() and DigController.Enabled == false, "minigame active, digging paused")
	local lead = ExcavationGame.LEAD
	check(ExcavationGame.Tap(100.1) == nil, "a tap before the first ring shows is ignored")
	check(ExcavationGame.Tap(100 + lead + 0.9) == "Perfect", "tap on the beat: Perfect")
	check(ExcavationGame.Tap(100 + lead + 0.9 + 1.15 + 0.15) == "Good", "a little late: Good")
	ExcavationGame.Step(100 + lead + 0.9 + 2.3 + 0.5) -- third ring passes untouched
	check(not ExcavationGame.IsActive() and DigController.Enabled == true, "game over after the last ring, digging back on")
	local ex = sent("Excavate", x0)
	check(#ex == 1 and ex[1][1] == "x900" and #ex[1][2] == 3, "Excavate(id, errors) sent once with 3 rings")
	check(ex[1] and math.abs(ex[1][2][1]) < 1e-9 and math.abs(ex[1][2][2] - 0.15) < 1e-6 and ex[1][2][3] == -1, "errors: 0, 0.15, -1 (miss)")

	-- the real flow: server ExcavationStart -> overlay -> taps -> answer
	local popups = playerGui:FindFirstChild("Dig_Popups"):FindFirstChild("Canvas")
	local x1 = #Mock.Remote.ToServer
	Mock.FireClientEvent("ExcavationStart", {
		Id = "x901",
		Position = info.Position,
		Signal = "Purple",
		Rings = 3,
		RingSeconds = 0.9,
		RingGap = 0.25,
		PerfectWindow = D.PERFECT_WINDOW,
		GoodWindow = D.GOOD_WINDOW,
		Timeout = 9,
	})
	Mock.Advance(0.05)
	local overlay = popups:FindFirstChild("Excavation")
	check(overlay ~= nil and ExcavationGame.IsActive(), "ExcavationStart opens the minigame overlay")
	check(DiscoveryController.Active ~= nil and DiscoveryController.Active.Id == "x901", "controller tracks the active excavation")
	local grades = {}
	local conn = ExcavationGame.Graded:Connect(function(_, g)
		table.insert(grades, g)
	end)
	Mock.Advance(lead + 0.9 - 0.05)
	Mock.FireEvent(overlay, "Activated", Mock.Input(Enum.UserInputType.Touch), 1)
	Mock.Advance(1.15)
	Mock.FireEvent(overlay, "Activated", Mock.Input(Enum.UserInputType.Touch), 1)
	Mock.Advance(1.15)
	Mock.FireEvent(overlay, "Activated", Mock.Input(Enum.UserInputType.Touch), 1)
	Mock.Advance(0.1)
	conn:Disconnect()
	local answer = sent("Excavate", x1)
	check(#answer == 1 and answer[1][1] == "x901", "taps answered the server")
	check(#grades == 3 and grades[1] ~= "Miss" and grades[2] ~= "Miss" and grades[3] ~= "Miss", "on-beat taps grade as hits (" .. table.concat(grades, ",") .. ")")
	Mock.Advance(1)
	check(popups:FindFirstChild("Excavation") == nil and DigController.Enabled, "overlay closed, digging back on")
	-- unanswered: the game times out into misses on its own
	local x2 = #Mock.Remote.ToServer
	Mock.FireClientEvent("ExcavationStart", { Id = "x902", Position = info.Position, Signal = "White", Rings = 3, RingSeconds = 0.9, RingGap = 0.25, PerfectWindow = 0.09, GoodWindow = 0.22, Timeout = 9 })
	Mock.Advance(5)
	local miss = sent("Excavate", x2)
	check(#miss == 1 and miss[1][2][1] == -1 and miss[1][2][3] == -1, "no taps: three misses reported")
	Mock.Advance(1)
	-- The last grade belongs to the completed ring, not the next shrinking ring.
	ExcavationGame.Start(info, 200)
	local cueOverlay = popups:FindFirstChild("Excavation")
	local prompt = cueOverlay:FindFirstChild("Cue")
	local result = cueOverlay:FindFirstChild("Grade")
	local ringUi = cueOverlay:FindFirstChild("Ring")
	ExcavationGame.Tap(200 + lead + 0.1)
	check(result.Text == "1/3: MISS" and prompt.Text == "", "early tap separates numbered miss from next cue")
	check(not ringUi.Visible, "graded ring hides immediately")
	ExcavationGame.Step(200 + lead + 1.15 + 0.1)
	check(prompt.Text == "WAIT..." and result.Text == "1/3: MISS", "next ring cues waiting while preserving the prior result")
	ExcavationGame.Step(200 + lead + 1.15 + 0.9)
	check(prompt.Text == "TAP!" and ringUi.Visible, "good timing window gives an explicit tap cue")
	ExcavationGame.Tap(200 + lead + 1.15 + 0.9)
	check(result.Text == "2/3: PERFECT!" and prompt.Text == "" and not ringUi.Visible, "hit clears tap cue and green ring immediately")
	ExcavationGame.Step(200 + lead + 2.3 + 0.9 - info.GoodWindow)
	check(prompt.Text == "TAP!", "cue starts at the inclusive good-window boundary")
	ExcavationGame.Step(200 + lead + 2.3 + 0.9 + info.GoodWindow + 0.001)
	check(result.Text == "3/3: MISS" and prompt.Text == "" and not ringUi.Visible, "expired final ring never displays a green ring with miss")
	ExcavationGame.Step(210)
	check(cueOverlay.Parent ~= nil, "final grade remains until reward or fallback teardown")
	ExcavationGame.DismissForReveal("unrelated")
	check(cueOverlay.Parent ~= nil, "another find cannot dismiss this excavation result")
	ExcavationGame.DismissForReveal(info.Id)
	check(cueOverlay.Parent == nil, "confirmed matching reward clears retiring target and grade immediately")
	Mock.Advance(1)

	-- reveal tier selection
	local function fi(rarity, size, material, isNew, newVariants)
		local Finds = Mock.Require(byPath["ReplicatedStorage/Shared/Util/Finds"])
		return {
			Id = "x", TreasureId = "bottle_cap", Rarity = rarity, Size = size or "Normal", Material = material or "None",
			Quality = "Good", Value = 10, Tier = Finds.Tier(rarity, size, material), IsNew = isNew or false,
			NewVariants = newVariants or {}, Perfect = false, Ambient = false, Position = info.Position,
		}
	end
	local p = FindReveal.Presentation(fi("Common"))
	check(p.Tier == "Pop" and p.Card == "None" and p.Float and not p.Camera, "Common repeat: float text only")
	p = FindReveal.Presentation(fi("Common", "Normal", "None", true))
	check(p.Card == "Compact" and not p.Float, "first Common find: card without competing floating name/value")
	p = FindReveal.Presentation(fi("Common", "Giant"))
	check(p.Tier == "Beam" and p.Card == "Compact" and p.Sound == "RareTreasure", "Giant common: Beam tier")
	p = FindReveal.Presentation(fi("Rare"))
	check(p.Tier == "Beam" and p.Card == "Compact", "Rare: Beam + compact card")
	p = FindReveal.Presentation(fi("Legendary"))
	check(p.Tier == "Card" and p.Card == "Full" and not p.Float and p.Camera and not p.Flash, "Legendary: full card + camera moment without duplicate text")
	p = FindReveal.Presentation(fi("Mythic"))
	check(p.Tier == "Server" and p.Flash and p.Confetti, "Mythic: server tier, flash + confetti")
	p = FindReveal.Presentation(fi("Relic"))
	check(p.Tier == "Spectacle" and p.Card == "Full" and p.Flash, "Relic: spectacle")
	Mock.FireClientEvent("FindRevealed", fi("Legendary", "Giant", "Crystal", true, { "Giant", "Crystal" }))
	Mock.Advance(0.6)
	local reveal = popups:FindFirstChild("Reveal")
	check(reveal ~= nil and reveal:IsA("TextButton"), "Legendary find shows the full Reveal card")
	local names = {}
	for _, d in (reveal or popups):GetDescendants() do
		if d:IsA("TextLabel") then
			names[d.Text] = true
		end
	end
	check(names["Giant Crystal Bottle Cap"] and names["SIZE"] and names["MATERIAL"] and names["QUALITY"], "card shows the variant name and SIZE / MATERIAL / QUALITY rows")
	local revealStyle = Mock.Require(byPath[CP .. "UI/Components/Style"])
	check(reveal:FindFirstChild("ItemName", true).TextColor3 == revealStyle.Colors.Text, "discovery name uses readable white instead of rarity tint")
	Mock.Advance(6)
	Mock.FireClientEvent("FindRevealed", "junk")
	Mock.Advance(0.2)

	-- A thin flip-flop must retain its front silhouette throughout both reveal paths.
	local savedMotion = State.GetSetting("ReducedMotion", false)
	State.SetSetting("ReducedMotion", false)
	local TreasurePopup = Mock.Require(byPath[CP .. "UI/TreasurePopup"])
	local shown = {}
	local seenAncestors = {}
	local function revealModel()
		local card = popups:FindFirstChild("Reveal")
		local frame = card and card:FindFirstChild("Model", true)
		-- Earlier menu tests can leave a popup ancestor hidden. Exercise actual motion.
		local ancestor = frame
		while ancestor do
			local property = if ancestor:IsA("GuiObject") then "Visible" elseif ancestor:IsA("ScreenGui") then "Enabled" else nil
			if property then
				if not seenAncestors[ancestor] then
					seenAncestors[ancestor] = true
					table.insert(shown, { ancestor, property, ancestor[property] })
				end
				ancestor[property] = true
			end
			ancestor = ancestor.Parent
		end
		return frame and frame:FindFirstChildOfClass("Model")
	end
	local flipInfo = fi("Common", "Normal", "None", true)
	flipInfo.TreasureId = "lost_flip_flop"
	FindReveal.Show(flipInfo)
	Mock.Advance(0.2)
	local flip = revealModel()
	check(flip ~= nil, "flip-flop discovery has a model preview")
	local initial = flip and flip:GetPivot()
	Mock.Advance(0.8)
	check(flip and flip:GetPivot() == initial, "flip-flop discovery keeps its broad front face without Reduced Motion")
	Mock.Advance(5)
	TreasurePopup.Show("lost_flip_flop", "Common")
	Mock.Advance(0.2)
	flip = revealModel()
	initial = flip and flip:GetPivot()
	Mock.Advance(0.8)
	check(flip and flip:GetPivot() == initial, "legacy flip-flop popup also stays static")
	Mock.Advance(5)
	local Reveal = Mock.Require(byPath[CP .. "UI/Reveal"])
	local Models = Mock.Require(byPath["ReplicatedStorage/Shared/Models"])
	Reveal.Show({ Headline = "SPIN DEFAULT", Color = Config.GetRarity("Common").Color, Items = { { Name = "Bottle Cap", Model = Models.Treasure("bottle_cap"), Rows = {} } }, Hold = 3 })
	Mock.Advance(0.2)
	local spinning = revealModel()
	initial = spinning and spinning:GetPivot()
	Mock.Advance(0.8)
	check(spinning and spinning:GetPivot() ~= initial, "visible Reveal item without a Spin option preserves rotation")
	Mock.Advance(5)
	for _, restored in shown do
		if restored[1].Parent then
			restored[1][restored[2]] = restored[3]
		end
	end
	State.SetSetting("ReducedMotion", savedMotion)

	-- world models: streaming-safe tag watching (Stage Excavating -> Revealed, late stream-in)
	local CollectionService = Mock.Service("CollectionService")
	local function findModel(id, stage, tier)
		local m = Mock.Env.Instance.new("Model")
		local part = Mock.Env.Instance.new("Part")
		part.Anchored = true
		part.Size = Vector3.new(1, 1, 1)
		part.CFrame = CFrame.new(5, Config.SURFACE_Y - 6, zone.CFrame.Position.Z)
		part.Parent = m
		m.PrimaryPart = part
		m:SetAttribute("FindId", id)
		m:SetAttribute("Rarity", "Rare")
		m:SetAttribute("Tier", tier)
		m:SetAttribute("Rise", 2)
		m:SetAttribute("Stage", stage)
		m.Parent = workspace
		CollectionService:AddTag(m, "DiscoveryFind")
		return m, part
	end
	local m1, part1 = findModel("w1", "Excavating", "Beam")
	Mock.Advance(0.1)
	check(DiscoveryController.Models.w1 == m1, "tagged find model is tracked")
	local y0 = part1.Position.Y
	m1:SetAttribute("Stage", "Revealed")
	Mock.Advance(1.2)
	check(math.abs(part1.Position.Y - (y0 + 2)) < 0.05, "revealed find rises out of the ground (" .. part1.Position.Y - y0 .. ")")
	check(part1:FindFirstChildOfClass("Beam") ~= nil, "Beam tier gets a light beam")
	local m2, part2 = findModel("w2", "Revealed", "Pop")
	Mock.Advance(0.1)
	check(math.abs(part2.Position.Y - (Config.SURFACE_Y - 6 + 2)) < 0.05, "a find streaming in already revealed is shown risen")
	check(part2:FindFirstChildOfClass("Beam") == nil, "Pop tier: no beam")
	m1:Destroy()
	m2:Destroy()
	Mock.Advance(0.2)
	check(DiscoveryController.Models.w1 == nil and DiscoveryController.Models.w2 == nil, "streamed-out / destroyed models are forgotten")

	-- Index: base item + variant checkmarks, holdings from Finds, true odds line
	local IndexPanel = Mock.Require(byPath[CP .. "UI/Panels/IndexPanel"])
	Mock.FireClientEvent("DataChanged", {
		Index = { bottle_cap = true },
		Treasures = {},
		Finds = { ["bottle_cap|Giant|Golden|Good"] = 2, ["bottle_cap|Normal|None|Damaged"] = 1 },
		FindVariants = { ["bottle_cap/Giant"] = true, ["bottle_cap/Golden"] = true, ["bottle_cap/Normal"] = true },
		MaxDepth = 0,
	})
	Mock.Advance(0.3)
	check(IndexPanel.Held("bottle_cap") == 3, "Index holdings count every variant in Finds")
	local pills = IndexPanel.VariantPills("bottle_cap")
	local lit = {}
	for _, pl in pills do
		lit[pl.Id] = pl.Found
	end
	check(#pills == 7 and lit.Giant and lit.Golden and lit.Normal and not lit.Tiny and not lit.Crystal, "variant pills: 4 sizes + 3 materials, found ones lit")
	local odds = IndexPanel.OddsText()
	local Stats = Mock.Require(byPath["ReplicatedStorage/Shared/Util/Stats"])
	local FindsMod = Mock.Require(byPath["ReplicatedStorage/Shared/Util/Finds"])
	local luck = Stats.GetLuck(State.GetStatsContext())
	local giantOdds = FindsMod.VariantOdds("Size", luck)[4].Chance * 100
	local want = "Giant " .. (if giantOdds >= 10 then string.format("%.0f", giantOdds) else string.format("%.1f", giantOdds)) .. "%"
	check(string.find(odds, want, 1, true) ~= nil, "Index shows true variant odds incl. luck (" .. odds .. ")")
	Panel.Open("Index")
	Mock.Advance(0.5)
	local indexGui = Panel.Get("Index")
	local capCard = indexGui and indexGui.Body:FindFirstChild("bottle_cap", true)
	local giantPill = capCard and capCard:FindFirstChild("Giant", true)
	check(giantPill ~= nil and giantPill:GetAttribute("Found") == true, "Index card shows the Giant checkmark")
	local oddsLabel = indexGui and indexGui.Body:FindFirstChild("Odds", true)
	check(oddsLabel ~= nil and string.find(oddsLabel.Text, "Find odds", 1, true) ~= nil, "Index header shows the odds line")
	Panel.CloseAll()
	Mock.Advance(0.5)
	check(#Mock.Errors == e0, "no errors in discovery")
end

section("confirmed sell feedback")
do
	local UIEffects = Mock.Require(byPath["StarterPlayer/StarterPlayerScripts/Client/UI/UIEffects"])
	local originalFly = UIEffects.FlyTo
	local flights = 0
	UIEffects.FlyTo = function(...)
		flights += 1
	end
	Mock.FireClientEvent("DataChanged", { Sand = 5 })
	Mock.FireClientEvent("DataChanged", { Sand = 0 })
	Mock.Advance(0.1)
	check(flights == 0, "sand reset alone does not celebrate a sale")
	Mock.FireClientEvent("Notify", "Sell", "+8 Coins!")
	Mock.Advance(0.1)
	check(flights == 1, "confirmed treasure-only sale celebrates with an empty sand bag")
	Mock.FireClientEvent("Notify", "Sell", false)
	Mock.Advance(0.1)
	check(flights == 1, "malformed sell notification does not trigger effects")
	UIEffects.FlyTo = originalFly
end

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
