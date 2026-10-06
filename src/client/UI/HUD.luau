--!strict
--[[
	HUD — always-on screen UI (docs/UI_STYLE.md). Every region is placed by UI/Layout.luau
	(design px, recomputed on resize; see the region map there):
	  TopRight  "TopRight" cluster: Coins pill (big green number, icon overlapping its left
	            end), Daily + Settings small round buttons (Daily gets a "!" when claimable),
	            Tokens pill and the rebirth/pet multiplier pill under them
	  Menu      "Menu": big square buttons in 2 columns (Shop, Beach, Eggs, Pets, Index, Quests,
	            Rebirth, Store) with oversized icons, outlined captions on the bottom edge and red
	            "!" badges (claimable quests, rebirth ready, affordable next shovel/backpack).
	            Hidden while a panel is open on small screens.
	            Progressive disclosure (UI/MenuGate, docs/design/Onboarding.md): each button (and
	            the top-right Daily button) appears only once relevant and never disappears
	            again; the visible ones re-flow into the 2 columns without gaps; a newly
	            unlocked one pops in with a toast and a gold "NEW!" tag until its panel is opened.
	  Depth     "Depth" meter: depth, layer, progress bar, record + next layer
	            (top-centre-right on wide screens, under the TopRight cluster on narrow ones)
	  Timers    "Timers": active boost / event chips (live timers) in the top-centre column,
	            under the objective banner (UI/ObjectiveBanner) and above the toasts
	  Bottom    "Bottom": backpack bar (red + pulsing "SELL!" when full), Surface, Sell (pass),
	            Auto Dig (pass) buttons
	HUD.Buttons keeps every button by name (menu entries plus Daily, Settings, Surface, Sell,
	AutoDig). Every button face is >= 74 design px (44 real px at the minimum UI scale 0.6), the
	small round buttons get an invisible 80 px touch area.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local Root = require(script.Parent.Root)
local Style = require(script.Parent.Components.Style)
local Button = require(script.Parent.Components.Button)
local IconLabel = require(script.Parent.Components.IconLabel)
local ProgressBar = require(script.Parent.Components.ProgressBar)
local Panel = require(script.Parent.Components.Panel)
local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local AtlasIcon = require(script.Parent.Components.AtlasIcon)
local ShopPanel = require(script.Parent.Panels.ShopPanel)
local UIEffects = require(script.Parent.UIEffects)
local MenuGate = require(script.Parent.MenuGate)
local Toasts = require(script.Parent.Toasts)
local Track = require(script.Parent.Parent.Util.Track)
local State = require(script.Parent.Parent.Controllers.State)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local LayerController = require(script.Parent.Parent.Controllers.LayerController)
local DigController = require(script.Parent.Parent.Controllers.DigController)
local PurchaseController = require(script.Parent.Parent.Controllers.PurchaseController)
local Progress = require(script.Parent.Parent.Util.Progress)

local HUD = {}

HUD.Buttons = {} :: { [string]: Button.Button }
HUD.Coins = nil :: IconLabel.IconLabel?

local C = Style.Colors
local backpackPulse: Tween? = nil
local backpackHighlight = false
local sellArrowTween: Tween? = nil
local backpackBar: ProgressBar.ProgressBar? = nil
local flashTweens: { [string]: Tween } = {}

-- Progressive menu disclosure state (see the "Menu gating" section below).
local gateVisible: { [string]: boolean } = {}
local refreshMenu: () -> () = function() end

-- Is a gated HUD button (menu entry or Daily) currently shown? Ungated buttons: true.
function HUD.IsUnlocked(name: string): boolean
	if MenuGate.MESSAGES[name] == nil then
		return true
	end
	return gateVisible[name] == true
end

-- Re-evaluate the menu unlock rules right now (also runs on every relevant data change).
function HUD.RefreshMenu()
	refreshMenu()
end

-- Briefly pulse a HUD button to draw attention (e.g. Shop after "Too hard!"). Never points at
-- a hidden (still locked) button.
function HUD.Flash(name: string, seconds: number?)
	local button = HUD.Buttons[name]
	if not button or flashTweens[name] then
		return
	end
	if not HUD.IsUnlocked(name) then
		refreshMenu() -- e.g. the tutorial just reached the step that unlocks it
		if not HUD.IsUnlocked(name) then
			return
		end
	end
	local tween = Style.Pulse(button.Holder, 0.14, 0.5)
	flashTweens[name] = tween
	task.delay(seconds or 3, function()
		Style.StopPulse(button.Holder, tween)
		flashTweens[name] = nil
	end)
end

-- Tutorial: make the backpack bar pulse even before it's full.
function HUD.SetBackpackHighlight(on: boolean)
	backpackHighlight = on
	local bar = backpackBar
	if bar then
		if on and not backpackPulse then
			backpackPulse = Style.Pulse(bar.Frame, 0.06, 0.8)
		elseif not on and backpackPulse and State.Data.Sand < State.GetCapacity() then
			Style.StopPulse(bar.Frame, backpackPulse)
			backpackPulse = nil
		end
	end
end

local ROUND = Vector2.new(64, 70) -- round button holder (64 px face + lip)

local function buildTopRight(canvas: Frame)
	local cluster = Instance.new("Frame")
	cluster.Name = "TopRight"
	cluster.BackgroundTransparency = 1
	cluster.Size = Layout.SizeOf(Layout.Current().TopRight)
	cluster.Parent = canvas
	Layout.Observe(function(regions: Layout.Regions)
		cluster.Position = Layout.Position(regions.TopRight)
		cluster.Size = Layout.SizeOf(regions.TopRight)
	end)

	local coins = IconLabel.new({
		Name = "Coins",
		Icon = "Coins",
		Color = C.Gold,
		TextColor = C.Money,
		Size = UDim2.fromOffset(214, 50),
		Position = UDim2.fromOffset(20, 4),
		MaxTextSize = 34,
		Parent = cluster,
	})
	HUD.Coins = coins
	local tokens = IconLabel.new({
		Name = "Tokens",
		Icon = "Tokens",
		Color = C.Tokens,
		TextColor = C.Tokens,
		Size = UDim2.fromOffset(150, 38),
		Position = UDim2.fromOffset(20, 60),
		MaxTextSize = 26,
		Parent = cluster,
	})
	local rebirth = IconLabel.new({
		Name = "Multiplier",
		Icon = "Rebirth",
		Color = C.Purple,
		TextColor = C.Time,
		Size = UDim2.fromOffset(192, 38),
		Position = UDim2.fromOffset(196, 60),
		MaxTextSize = 22,
		Parent = cluster,
	})

	for i, item in { { Name = "Daily", Color = C.Gold }, { Name = "Settings", Color = C.OceanDark } } do
		HUD.Buttons[item.Name] = Button.new({
			Name = item.Name,
			Icon = item.Name,
			Vertical = true,
			Round = true,
			HitPadding = 8,
			Color = item.Color,
			Size = UDim2.fromOffset(ROUND.X, ROUND.Y),
			Position = UDim2.fromOffset(244 + (i - 1) * (ROUND.X + 16), 0),
			Parent = cluster,
			OnClick = function()
				Panel.Toggle(item.Name)
			end,
		})
	end

	local lastCoins: number? = nil
	State.Observe("Coins", function(value: any)
		if typeof(value) ~= "number" then
			return
		end
		coins:SetValue(value)
		if lastCoins and State.Loaded and value > lastCoins then
			UIEffects.FloatFrom(coins.Frame, "+" .. Format.Abbreviate(value - lastCoins), C.Money)
		end
		lastCoins = value
	end)
	State.Observe("RebirthTokens", function(value: any)
		if typeof(value) == "number" then
			tokens:SetValue(value)
		end
	end)
	State.ObserveMany({ "Rebirths", "Pets", "Passes" }, function()
		local mult = Config.RebirthMultiplier(State.Data.Rebirths)
		rebirth:SetText(
			"x" .. string.format("%.1f", mult) .. "  pets x" .. string.format("%.2f", State.GetPetMultiplier())
		)
	end)
end

local MENU = {
	{ Name = "Shop", Icon = "Shop", Color = C.Palm, Panel = "Shop" },
	{ Name = "Beach", Icon = "Beach", Color = C.Sunset, Panel = "BeachShop" }, -- Survival's panel
	{ Name = "Eggs", Icon = "Eggs", Color = C.Gold, Panel = "Eggs" },
	{ Name = "Pets", Icon = "Pets", Color = C.Coral, Panel = "Pets" },
	{ Name = "Index", Icon = "Index", Color = C.Ocean, Panel = "Index" },
	{ Name = "Quests", Icon = "Quests", Color = Color3.fromRGB(255, 120, 70), Panel = "Quests" },
	{ Name = "Rebirth", Icon = "Rebirth", Color = C.Purple, Panel = "Rebirth" },
	{ Name = "Store", Icon = "Store", Color = Color3.fromRGB(240, 85, 200), Panel = "Store" },
}

-- Cheapest affordable shovel/backpack upgrade exists (Shop "!" badge).
local function canAffordUpgrade(): boolean
	local data = State.Data
	for _, kind in { "Shovels", "Backpacks" } do
		local id = ShopPanel.NextUpgrade(kind)
		local def: any = if id
			then (if kind == "Shovels" then Config.GetShovel(id) else Config.GetBackpack(id))
			else nil
		if def and data.Coins >= def.Price then
			return true
		end
	end
	return false
end

local function buildMenu(canvas: Frame)
	local grid = Instance.new("Frame")
	grid.Name = "Menu"
	grid.BackgroundTransparency = 1
	grid.Parent = canvas
	Layout.Observe(function(regions: Layout.Regions)
		grid.Position = Layout.Position(regions.Menu)
		grid.Size = Layout.SizeOf(regions.Menu)
	end)
	-- Cells are placed by the menu gating (2 columns, visible buttons only, no gaps), not by a
	-- UIGridLayout, so the re-flow is deterministic and can slide.
	for i, item in MENU do
		HUD.Buttons[item.Name] = Button.new({
			Name = item.Name,
			Icon = item.Icon,
			Text = item.Name,
			Vertical = true,
			Color = item.Color,
			Size = UDim2.fromOffset(Layout.MENU_CELL, Layout.MENU_CELL),
			LayoutOrder = i,
			MaxTextSize = 20,
			Corner = UDim.new(0, 12),
			Parent = grid,
			OnClick = function()
				Panel.Toggle(item.Panel)
			end,
		})
	end

	-- badges
	local function refreshBadges()
		local data = State.Data
		local quests = Progress.ClaimableQuests(data)
		HUD.Buttons.Quests:SetBadge(if quests > 0 then tostring(quests) else nil)
		HUD.Buttons.Daily:SetBadge(if Progress.Daily(data).CanClaim and State.Loaded then "!" else nil)
		HUD.Buttons.Rebirth:SetBadge(
			if Progress.CanRebirth(data) or Progress.CanBuyRebirthPerk(data) then "!" else nil -- v2.2 perks
		)
		HUD.Buttons.Shop:SetBadge(if State.Loaded and canAffordUpgrade() then "!" else nil)
	end
	State.ObserveMany({
		"Quests",
		"Coins",
		"Rebirths",
		"DailyStreak",
		"LastDailyClaim",
		"MaxDepth",
		"OwnedShovels",
		"OwnedBackpacks",
		"Shovel",
		"Backpack",
		"RebirthTokens", -- v2.2 perk badge
		"RebirthPerks",
	}, refreshBadges)
	State.LoadedSignal:Connect(refreshBadges)
	task.spawn(function()
		while true do
			task.wait(5)
			refreshBadges()
		end
	end)
end

local function buildTimers(canvas: Frame)
	local row = Instance.new("Frame")
	row.Name = "Timers"
	row.BackgroundTransparency = 1
	row.Parent = canvas
	Layout.Observe(function(regions: Layout.Regions)
		row.Position = Layout.Position(regions.Timers)
		row.Size = Layout.SizeOf(regions.Timers)
	end)
	Style.List(row, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)

	type Chip = { Frame: Frame, Label: TextLabel, Icon: AtlasIcon.AtlasIcon }
	local chips: { [string]: Chip } = {}

	-- Small dark pill: coloured icon + "Name 4:21" (time in sky blue).
	local function chip(key: string, icon: string, color: Color3, order: number, dim: boolean): TextLabel
		local existing = chips[key]
		if existing then
			existing.Frame.LayoutOrder = order
			existing.Frame.BackgroundTransparency = if dim then 0.4 else 0.08
			return existing.Label
		end
		local frame = Instance.new("Frame")
		frame.Name = key
		frame.Size = UDim2.fromOffset(186, 34)
		frame.LayoutOrder = order
		frame.Parent = row
		Style.Pill(frame, if dim then 0.4 else 0.08)
		local ring = frame:FindFirstChildOfClass("UIStroke")
		if ring then
			ring.Color = Style.Darken(color, 0.2)
		end
		local glyph = AtlasIcon.new({
			Icon = icon,
			Size = UDim2.fromOffset(40, 40),
			Position = UDim2.new(0, -6, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			ZIndex = 3,
			Parent = frame,
		})
		local label = Style.Label({
			Size = UDim2.new(1, -46, 0.78, 0),
			Position = UDim2.new(0, 38, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			MaxTextSize = 18,
			RichText = true,
			XAlign = Enum.TextXAlignment.Left,
			ZIndex = 2,
			Parent = frame,
		})
		chips[key] = { Frame = frame, Label = label, Icon = glyph }
		Style.PopIn(frame)
		return label
	end
	local timeHex = "#" .. C.Time:ToHex()
	local function timed(name: string, seconds: number): string
		return name .. ' <font color="' .. timeHex .. '">' .. Format.Time(seconds) .. "</font>"
	end

	local function update()
		local seen: { [string]: boolean } = {}
		local order = 0
		for _, boost in Config.Boosts do
			local remaining = State.GetBoostRemaining(boost.Id)
			if remaining > 0 then
				order += 1
				local key = "Boost_" .. boost.Id
				seen[key] = true
				chip(key, "BoostKinds." .. boost.Kind, boost.Color, order, false).Text = timed(boost.Name, remaining)
			end
		end
		local now = Progress.Now()
		local anyActive = false
		for _, event in Config.Events do
			local active = State.IsEventActive(event.Id)
				or (#State.ActiveEvents == 0 and Config.GetSecondsUntilEvent(event.Id, now) == 0)
			if active then
				anyActive = true
				order += 1
				local key = "Event_" .. event.Id
				seen[key] = true
				local phase = (now + event.OffsetSeconds) % event.IntervalSeconds
				local left = if phase < event.DurationSeconds then event.DurationSeconds - phase else 0
				-- v2.2: started early on this server (server dig goal) -> its real end time
				local forcedEnd = workspace:GetAttribute("EventEnds_" .. event.Id)
				if typeof(forcedEnd) == "number" then
					left = math.max(left, forcedEnd - now)
				end
				left = math.max(0, left)
				chip(key, "Events." .. event.Id, event.Color, order, false).Text = timed(event.Name .. "!", left)
			end
		end
		if not anyActive then
			-- anticipation: show the next upcoming event
			local soonest: string? = nil
			local soonestIn = math.huge
			for _, event in Config.Events do
				local wait = Config.GetSecondsUntilEvent(event.Id, now)
				if wait < soonestIn then
					soonestIn = wait
					soonest = event.Id
				end
			end
			if soonest then
				local event = Config.GetEvent(soonest)
				if event then
					order += 1
					local key = "Next_" .. event.Id
					seen[key] = true
					chip(key, "Events." .. event.Id, event.Color, order, true).Text =
						timed(event.Name .. " in", soonestIn)
				end
			end
		end
		for key, entry in chips do
			if not seen[key] then
				entry.Frame:Destroy()
				chips[key] = nil
			end
		end
	end

	State.ObserveMany({ "Boosts", "ActiveEvents" }, update)
	task.spawn(function()
		while true do
			task.wait(1)
			update()
		end
	end)
end

local function buildDepthMeter(canvas: Frame)
	local holder = Instance.new("Frame")
	holder.Name = "Depth"
	holder.BackgroundTransparency = 1
	holder.Parent = canvas
	Layout.Observe(function(regions: Layout.Regions)
		holder.Position = Layout.Position(regions.Depth)
		holder.Size = Layout.SizeOf(regions.Depth)
	end)

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.new(1, 0, 0, 70)
	card.BackgroundTransparency = 0.08
	card.Parent = holder
	Style.Corner(card, Style.Theme.CornerMedium)
	local cardStroke = Style.Stroke(card, C.Stroke, 3)
	Style.NavyBody(card)

	AtlasIcon.new({
		Name = "DepthIcon",
		Icon = "Depth",
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.fromOffset(-8, -6),
		AnchorPoint = Vector2.zero,
		Rotation = -8,
		ZIndex = 3,
		Parent = card,
	})
	local depthLabel = Style.Label({
		Name = "Depth",
		Text = "0m",
		Size = UDim2.new(1, -52, 0, 36),
		Position = UDim2.fromOffset(44, 3),
		Font = Style.Fonts.Title,
		MaxTextSize = 34,
		StrokeThickness = 3,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = card,
	})
	local layerIcon = AtlasIcon.new({
		Name = "LayerIcon",
		Icon = "Layers." .. Config.Layers[1].Id,
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.fromOffset(8, 41),
		AnchorPoint = Vector2.zero,
		ZIndex = 3,
		Parent = card,
	})
	local layerLabel = Style.Label({
		Name = "Layer",
		Text = Config.Layers[1].Name,
		Size = UDim2.new(1, -46, 0, 24),
		Position = UDim2.fromOffset(38, 42),
		MaxTextSize = 21,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = card,
	})

	local bar = ProgressBar.new({
		Name = "LayerProgress",
		Size = UDim2.new(1, -8, 0, 14),
		Position = UDim2.new(0.5, 0, 0, 76),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Config.Layers[1].Color,
		Parent = holder,
	})
	bar.Label.Visible = false
	local nextLabel = Style.Label({
		Name = "Next",
		Text = "",
		Size = UDim2.new(1, -4, 0, 26),
		Position = UDim2.new(1, -2, 0, 92),
		AnchorPoint = Vector2.new(1, 0),
		MaxTextSize = 13,
		MinTextSize = 9,
		Font = Style.Fonts.Body,
		Wrapped = true,
		RichText = true,
		XAlign = Enum.TextXAlignment.Right,
		YAlign = Enum.TextYAlignment.Top,
		Parent = holder,
	})

	local record = "0m"
	local nextText = ""
	local function setInfo()
		nextLabel.Text = '<font color="#' .. C.Gold:ToHex() .. '">Best ' .. record .. "</font>  ·  " .. nextText
	end
	local lastLayer = 0
	local function update(depth: number, index: number)
		local layer = Config.Layers[index]
		depthLabel.Text = Format.Depth(Config.DepthToMeters(depth))
		if index ~= lastLayer then
			lastLayer = index
			layerIcon:Set("Layers." .. layer.Id)
			layerLabel.Text = layer.Name
			layerLabel.TextColor3 = Color3.new(1, 1, 1):Lerp(layer.Color, 0.55)
			cardStroke.Color = Style.Darken(layer.Color, 0.5)
			bar:SetColor(layer.Color)
			Style.Pop(card, 0.12)
			local nextLayer = Config.Layers[index + 1]
			if nextLayer then
				local canDig = State.GetShovel().Power >= nextLayer.Hardness
				nextText = "Next: "
					.. nextLayer.Name
					.. " @ "
					.. Format.Depth(nextLayer.DepthStart)
					.. (
						if canDig
							then ""
							else '<font color="#'
								.. C.Coral:ToHex()
								.. '"> (needs Power '
								.. nextLayer.Hardness
								.. ")</font>"
					)
			else
				nextText = "The CORE!"
			end
			setInfo()
		end
		local span = layer.DepthEnd - layer.DepthStart
		bar:Set((depth - layer.DepthStart) / span)
	end
	LayerController.DepthChanged:Connect(update)
	State.Changed("Shovel"):Connect(function()
		lastLayer = 0
		update(LayerController.Depth, LayerController.LayerIndex)
	end)
	update(0, 1)
	State.Observe("MaxDepth", function(value: any)
		if typeof(value) == "number" then
			record = Format.Depth(Config.DepthToMeters(value))
			setInfo()
		end
	end)
end

local function buildBottom(canvas: Frame)
	local holder = Instance.new("Frame")
	holder.Name = "Bottom"
	holder.BackgroundTransparency = 1
	holder.Parent = canvas
	Layout.Observe(function(regions: Layout.Regions)
		holder.Position = Layout.Position(regions.Bottom)
		holder.Size = Layout.SizeOf(regions.Bottom)
	end)

	local bar = ProgressBar.new({
		Name = "Backpack",
		Size = UDim2.fromOffset(400, 44),
		Position = UDim2.new(0.5, 0, 1, 0),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Sand,
		Text = "0 / 20",
		MaxTextSize = 26,
		Parent = holder,
	})
	backpackBar = bar
	bar.Label.Size = UDim2.new(1, -60, 0.8, 0)
	bar.Label.Position = UDim2.new(0.5, 18, 0.5, 0)
	AtlasIcon.new({
		Name = "BackpackIcon",
		Icon = "Backpack",
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.new(0, -16, 0.5, -4),
		AnchorPoint = Vector2.new(0, 0.5),
		Rotation = -8,
		ZIndex = 4,
		Parent = bar.Frame,
	})

	local arrow = Style.Label({
		Name = "SellArrow",
		Text = "FULL! GO SELL!",
		Size = UDim2.fromOffset(260, 36),
		Position = UDim2.new(0.5, 0, 1, -52),
		AnchorPoint = Vector2.new(0.5, 1),
		TextColor = C.Coral,
		StrokeThickness = 3,
		MaxTextSize = 30,
		Parent = holder,
	})
	arrow.Visible = false

	local row = Instance.new("Frame")
	row.Name = "Actions"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.new(0.5, 0, 1, -92)
	row.Size = UDim2.fromOffset(400, 80)
	row.Parent = holder
	Style.List(row, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)

	HUD.Buttons.Surface = Button.new({
		Name = "Surface",
		Icon = "Surface",
		Text = "Surface",
		Vertical = true,
		Color = C.Ocean,
		Size = UDim2.fromOffset(80, 80),
		MaxTextSize = 18,
		LayoutOrder = 1,
		Parent = row,
		OnClick = function()
			SoundController.Play("Teleport")
			Remotes.Get("ReturnToSurface"):FireServer()
		end,
	})

	local sell = Button.new({
		Name = "Sell",
		Icon = "Sell",
		Text = "Sell",
		Vertical = true,
		Color = C.Success,
		Size = UDim2.fromOffset(80, 80),
		MaxTextSize = 18,
		LayoutOrder = 2,
		Parent = row,
		OnClick = function()
			if State.CanSellAnywhere() then
				State.SetSetting("SellNow", true)
			elseif not PurchaseController.PromptPass("SellAnywhere") then
				SoundController.Play("Error")
			end
		end,
	})
	HUD.Buttons.Sell = sell

	local auto = Button.new({
		Name = "AutoDig",
		Icon = "AutoDig",
		Text = "Auto",
		Vertical = true,
		Color = C.Disabled,
		Size = UDim2.fromOffset(80, 80),
		MaxTextSize = 18,
		LayoutOrder = 3,
		Parent = row,
		OnClick = function()
			if State.OwnsPass("AutoDig") then
				State.SetSetting("AutoDig", not (State.GetSetting("AutoDig", false) == true))
			else
				PurchaseController.PromptPass("AutoDig")
			end
		end,
	})
	HUD.Buttons.AutoDig = auto

	State.ObserveMany({ "Passes", "Settings", "RebirthPerks" }, function()
		local ownsSell = State.CanSellAnywhere() -- v2.2: pass or rebirth perk
		sell:SetVisible(ownsSell or PurchaseController.IsPassConfigured("SellAnywhere"))
		sell:SetText(if ownsSell then "Sell" else "Sell R$")
		local ownsAuto = State.OwnsPass("AutoDig")
		auto:SetVisible(ownsAuto or PurchaseController.IsPassConfigured("AutoDig"))
		local on = ownsAuto and State.GetSetting("AutoDig", false) == true
		auto:SetColor(if on then C.Success elseif ownsAuto then C.OceanDark else C.Disabled)
		auto:SetText(if on then "Auto ON" elseif ownsAuto then "Auto OFF" else "Auto R$")
	end)

	local wasFull = false
	local lastSand: number? = nil
	local function update()
		local sand = State.Data.Sand or 0
		local capacity = math.max(State.GetCapacity(), 1)
		local full = sand >= capacity
		bar:Set(sand / capacity, Format.Abbreviate(sand) .. " / " .. Format.Abbreviate(capacity))
		bar:SetColor(if full then C.Danger elseif sand / capacity > 0.8 then C.Warning else C.Sand)
		if full ~= wasFull then
			wasFull = full
			arrow.Visible = full
			if full then
				SoundController.Play("DigBlocked", 1.4)
				if not backpackPulse then
					backpackPulse = Style.Pulse(bar.Frame, 0.07, 0.6)
				end
				sellArrowTween = Style.Tween(
					arrow,
					0.35,
					{ Position = UDim2.new(0.5, 0, 1, -62) },
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut,
					-1,
					true
				)
				if State.CanSellAnywhere() then
					HUD.Flash("Sell", 4)
				end
			else
				if sellArrowTween then
					sellArrowTween:Cancel()
					sellArrowTween = nil
				end
				arrow.Position = UDim2.new(0.5, 0, 1, -52)
				if backpackPulse and not backpackHighlight then
					Style.StopPulse(bar.Frame, backpackPulse)
					backpackPulse = nil
				end
			end
		end
		-- Sold! (sand dropped while coins went up): coin rain into the coins counter.
		if lastSand and sand < lastSand and lastSand > 0 and sand == 0 then
			SoundController.Play("Sell")
			local coins = HUD.Coins
			if coins then
				UIEffects.FlyTo(Icons.Coins, coins.Badge, 10, nil, function()
					SoundController.Play("Coin")
				end)
			end
		end
		lastSand = sand
	end
	State.ObserveMany({ "Sand", "Backpack", "Rebirths", "Passes" }, update)
end

-- Menu gating: progressive disclosure (UI/MenuGate, docs/design/Onboarding.md) -------------------

local newTags: { [string]: TextLabel } = {}

-- Gold "NEW!" tag on the top-left corner until the button's panel is first opened.
local function setNewTag(name: string, on: boolean)
	local button = HUD.Buttons[name]
	local tag = newTags[name]
	if not button then
		return
	end
	if on and not tag then
		local label = Style.Label({
			Name = "NewTag",
			Text = "NEW!",
			Size = UDim2.fromOffset(50, 22),
			Position = UDim2.fromOffset(-8, -8),
			AnchorPoint = Vector2.zero,
			MaxTextSize = 16,
			StrokeThickness = 2,
			ZIndex = 8,
			Parent = button.Holder,
		})
		label.BackgroundTransparency = 0
		label.BackgroundColor3 = C.Gold
		label.Rotation = -8
		Style.Corner(label, Style.Theme.CornerPill)
		local ring = Instance.new("UIStroke")
		ring.Color = C.Stroke
		ring.Thickness = 2.5
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ring.Parent = label
		Style.Pulse(label, 0.1, 0.9)
		newTags[name] = label
	elseif not on and tag then
		tag:Destroy()
		newTags[name] = nil
	end
end

-- Visible menu buttons fill the 2 columns in MENU order without gaps.
local function reflow(previous: { [string]: boolean }, animate: boolean)
	local k = 0
	for _, name in MenuGate.MENU do
		local button = HUD.Buttons[name]
		if button then
			local show = gateVisible[name] == true
			button.Holder.Visible = show
			if show then
				k += 1
				local cell = MenuGate.CellPosition(
					k,
					Layout.MENU_CELL,
					Layout.MENU_GAP_X,
					Layout.MENU_GAP_Y,
					Layout.MENU_COLUMNS
				)
				local target = UDim2.fromOffset(cell.X, cell.Y)
				if animate and previous[name] and button.Holder.Position ~= target then
					Style.Tween(button.Holder, 0.25, { Position = target }, Enum.EasingStyle.Back)
				else
					button.Holder.Position = target
				end
			end
		end
	end
	local daily = HUD.Buttons.Daily
	if daily then
		daily.Holder.Visible = gateVisible.Daily == true
	end
end

local function buildMenuGating()
	local evaluated = false
	local heatUnlockAt = MenuGate.BEACH_HEAT
	local localPlayer = Players.LocalPlayer

	refreshMenu = function()
		if not State.Loaded then
			reflow({}, false) -- before the data arrives every gated button stays hidden
			return
		end
		local data = State.Data
		local heat = localPlayer:GetAttribute("Heat")
		local visible = MenuGate.Evaluate({ Data = data, Heat = if type(heat) == "number" then heat else 0 })
		local settings: { [string]: any } = data.Settings or {}
		local persisted = MenuGate.ParseList(settings[MenuGate.UNLOCK_KEY])
		local seen = MenuGate.ParseList(settings[MenuGate.SEEN_KEY])
		local first = not evaluated
		evaluated = true

		if first and MenuGate.IsReturning(data) and settings[MenuGate.SEEN_KEY] == nil then
			-- returning players: everything is already familiar, nothing is "NEW"
			for _, name in MenuGate.ALL do
				seen[name] = true
			end
			State.SetSetting(MenuGate.SEEN_KEY, MenuGate.FormatList(seen))
		end

		local fresh: { string } = {}
		local changed = false
		for _, name in MenuGate.ALL do
			if visible[name] and not gateVisible[name] then
				table.insert(fresh, name)
			end
			if visible[name] and not persisted[name] then
				persisted[name] = true
				changed = true
			end
		end
		if changed and not MenuGate.IsReturning(data) then
			State.SetSetting(MenuGate.UNLOCK_KEY, MenuGate.FormatList(persisted))
		end

		local previous = gateVisible
		gateVisible = visible
		reflow(previous, not first)
		for _, name in MenuGate.ALL do
			setNewTag(name, visible[name] == true and not seen[name])
		end
		if first or #fresh == 0 then
			return -- unlocks found at load (earned last session) appear quietly
		end
		for _, name in fresh do
			local button = HUD.Buttons[name]
			if button then
				Style.PopIn(button.Holder, 0.45)
			end
			Track.Send("menu_unlocked", name)
		end
		SoundController.Play("Purchase", 1.25)
		if #fresh == 1 then
			Toasts.Show(MenuGate.MESSAGES[fresh[1]], "Success", 4)
		else
			Toasts.Show("New menus unlocked! Look for NEW", "Success", 4)
		end
	end

	-- Opening a panel (from the HUD, a world prompt or the tutorial) clears its NEW tag.
	Panel.Changed:Connect(function(panelName: string?)
		if not panelName then
			return
		end
		Track.Send("panel_opened", panelName)
		local name = MenuGate.PANEL_TO_BUTTON[panelName]
		if not name or not State.Loaded then
			return
		end
		local seen = MenuGate.ParseList(State.GetSetting(MenuGate.SEEN_KEY, nil))
		if not seen[name] then
			seen[name] = true
			State.SetSetting(MenuGate.SEEN_KEY, MenuGate.FormatList(seen))
		end
		setNewTag(name, false)
	end)

	State.ObserveMany({
		"Coins",
		"Rebirths",
		"Pets",
		"Index",
		"OwnedShovels",
		"OwnedShades",
		"Quests",
		"PlayTime",
		"LastDailyClaim",
		"Settings",
	}, refreshMenu)
	State.LoadedSignal:Connect(refreshMenu)
	-- "Getting hot" is transient: unlock the Beach shop the moment heat crosses the line.
	localPlayer:GetAttributeChangedSignal("Heat"):Connect(function()
		local heat = localPlayer:GetAttribute("Heat")
		if type(heat) == "number" and heat >= heatUnlockAt and not gateVisible.Beach then
			refreshMenu()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			refreshMenu()
		end
	end)
end

-- First visible menu button (gamepad ButtonY focus target), nil if none is unlocked yet.
function HUD.FirstMenuButton(): Button.Button?
	for _, name in MenuGate.MENU do
		local button = HUD.Buttons[name]
		if button and gateVisible[name] then
			return button
		end
	end
	return nil
end

function HUD.Init()
	local canvas = Root.Get("HUD")
	buildTopRight(canvas)
	buildMenu(canvas)
	buildTimers(canvas)
	buildDepthMeter(canvas)
	buildBottom(canvas)
	buildMenuGating()

	DigController.Feedback:Connect(function(reason: string)
		if reason == "TooHard" then
			HUD.Flash("Shop", 4)
		end
	end)
	-- hide the menu clutter while a panel is open on small screens
	Panel.Changed:Connect(function(name: string?)
		local menu = canvas:FindFirstChild("Menu")
		if menu and menu:IsA("GuiObject") then
			menu.Visible = name == nil or Root.GetDesignSize().X > 1160 -- 820-wide panels clear the menu
		end
	end)
end

return HUD
