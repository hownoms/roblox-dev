--!strict
--[[
	HUD — always-on screen UI (design px, see Root; a landscape phone is ~1070-1330 x 500
	design px, a 1080p PC ~1420 x 760):
	  top-left      Coins / Rebirth tokens / rebirth multiplier pills (count-up + pop)
	                x 18..268, y 10..154
	  left          5x2 menu (10 buttons): Shop, Beach, Eggs, Pets, Index / Quests, Daily,
	                Rebirth, Store, Settings (red "!" badges when claimable)
	                x 14..408, y 162..328. Hidden while a panel is open on small screens.
	                (v2.1: the Garage button is gone; vehicles are pets from crates.)
	  top-centre    active boosts + events chips with live timers (or "High Tide in 4:21")
	                centred, y 8..48 (toasts sit below at y 104+, banners at 30% height)
	  top-right     compact depth meter: depth, layer, record, progress bar, next layer
	                x right-196..right-14, y 10..172
	  bottom-centre backpack bar (red + pulsing "SELL!" when full), Surface, Sell (pass),
	                Auto Dig (pass) buttons: 420 wide centred, bottom 180 px
	FREE for other HUDs (SurvivalHUD): the RIGHT-CENTRE edge, x right-230..right-8,
	y 180..(bottom - 150). Phones put the jump button in the bottom-right corner.
	Every button is >= 74 x 75 design px face (>= 44 real px at the minimum UI scale 0.6).
]]
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
local UIEffects = require(script.Parent.UIEffects)
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

-- Briefly pulse a HUD button to draw attention (e.g. Shop after "Too hard!").
function HUD.Flash(name: string, seconds: number?)
	local button = HUD.Buttons[name]
	if not button or flashTweens[name] then
		return
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

local function buildStats(canvas: Frame)
	local stack = Instance.new("Frame")
	stack.Name = "Stats"
	stack.BackgroundTransparency = 1
	stack.Position = UDim2.fromOffset(18, 10)
	stack.Size = UDim2.fromOffset(250, 144)
	stack.Parent = canvas
	Style.List(stack, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Left)

	local coins = IconLabel.new({
		Name = "Coins",
		Icon = Icons.Coins,
		Color = C.Coins,
		TextColor = C.Gold,
		Size = UDim2.fromOffset(240, 48),
		MaxTextSize = 32,
		LayoutOrder = 1,
		Parent = stack,
	})
	HUD.Coins = coins
	local tokens = IconLabel.new({
		Name = "Tokens",
		Icon = Icons.Tokens,
		Color = C.Tokens,
		TextColor = C.Tokens,
		Size = UDim2.fromOffset(190, 40),
		MaxTextSize = 26,
		LayoutOrder = 2,
		Parent = stack,
	})
	local rebirth = IconLabel.new({
		Name = "Multiplier",
		Icon = Icons.Rebirth,
		Color = C.Purple,
		Size = UDim2.fromOffset(240, 40),
		MaxTextSize = 24,
		LayoutOrder = 3,
		Parent = stack,
	})

	local lastCoins: number? = nil
	State.Observe("Coins", function(value: any)
		if typeof(value) ~= "number" then
			return
		end
		coins:SetValue(value)
		if lastCoins and State.Loaded and value > lastCoins then
			UIEffects.FloatFrom(coins.Frame, "+" .. Format.Abbreviate(value - lastCoins), C.Gold)
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
			"x" .. string.format("%.1f", mult) .. "  ·  🐾 x" .. string.format("%.2f", State.GetPetMultiplier())
		)
	end)
end

local MENU = {
	{ Name = "Shop", Icon = Icons.Shop, Color = C.Palm, Panel = "Shop" },
	{ Name = "Beach", Icon = Icons.Beach, Color = C.Ocean, Panel = "BeachShop" }, -- Survival's panel
	{ Name = "Eggs", Icon = Icons.Eggs, Color = C.Sand, Panel = "Eggs" },
	{ Name = "Pets", Icon = Icons.Pets, Color = C.Coral, Panel = "Pets" },
	{ Name = "Index", Icon = Icons.Index, Color = C.OceanDark, Panel = "Index" },
	{ Name = "Quests", Icon = Icons.Quests, Color = C.Sunset, Panel = "Quests" },
	{ Name = "Daily", Icon = Icons.Daily, Color = C.Gold, Panel = "Daily" },
	{ Name = "Rebirth", Icon = Icons.Rebirth, Color = C.Purple, Panel = "Rebirth" },
	{ Name = "Store", Icon = Icons.Store, Color = C.Robux, Panel = "Store" },
	{ Name = "Settings", Icon = Icons.Settings, Color = C.Disabled, Panel = "Settings" },
}

local MENU_COLUMNS = 5
local MENU_CELL = Vector2.new(74, 80) -- face 74 x 75 design px -> >= 44 real px on phones
local MENU_GAP = 6

local function buildMenu(canvas: Frame)
	local rows = math.ceil(#MENU / MENU_COLUMNS)
	local grid = Instance.new("Frame")
	grid.Name = "Menu"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(14, 162) -- directly under the stat pills
	grid.Size =
		UDim2.fromOffset(MENU_COLUMNS * (MENU_CELL.X + MENU_GAP) - MENU_GAP, rows * (MENU_CELL.Y + MENU_GAP) - MENU_GAP)
	grid.Parent = canvas
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(MENU_CELL.X, MENU_CELL.Y)
	layout.CellPadding = UDim2.fromOffset(MENU_GAP, MENU_GAP)
	layout.FillDirectionMaxCells = MENU_COLUMNS
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	for i, item in MENU do
		HUD.Buttons[item.Name] = Button.new({
			Name = item.Name,
			Icon = item.Icon,
			Text = item.Name,
			Vertical = true,
			Color = item.Color,
			LayoutOrder = i,
			MaxTextSize = 19,
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
		HUD.Buttons.Rebirth:SetBadge(if Progress.CanRebirth(data) then "!" else nil)
	end
	State.ObserveMany({ "Quests", "Coins", "Rebirths", "DailyStreak", "LastDailyClaim", "MaxDepth" }, refreshBadges)
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
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, 8)
	row.Size = UDim2.fromOffset(560, 40)
	row.Parent = canvas
	Style.List(row, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)

	local chips: { [string]: { Frame: Frame, Label: TextLabel } } = {}

	local function chip(key: string, color: Color3, order: number, dim: boolean): TextLabel
		local existing = chips[key]
		if existing then
			existing.Frame.LayoutOrder = order
			existing.Frame.BackgroundTransparency = if dim then 0.45 else 0
			return existing.Label
		end
		local frame = Instance.new("Frame")
		frame.Name = key
		frame.Size = UDim2.fromOffset(190, 38)
		frame.BackgroundColor3 = color
		frame.BackgroundTransparency = if dim then 0.45 else 0
		frame.LayoutOrder = order
		frame.Parent = row
		Style.Corner(frame, Style.Theme.CornerPill)
		Style.Stroke(frame, C.Stroke, 3)
		Style.Shine(frame)
		local label = Style.Label({
			Size = UDim2.new(1, -16, 0.75, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			MaxTextSize = 20,
			ZIndex = 2,
			Parent = frame,
		})
		chips[key] = { Frame = frame, Label = label }
		Style.PopIn(frame)
		return label
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
				chip(key, boost.Color, order, false).Text = (Icons.BoostKinds[boost.Kind] or "⚡")
					.. " "
					.. boost.Name
					.. " "
					.. Format.Time(remaining)
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
				local left = math.max(0, event.DurationSeconds - phase)
				chip(key, event.Color, order, false).Text = Icons.Event(event.Id, event.Kind)
					.. " "
					.. event.Name
					.. "! "
					.. Format.Time(left)
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
					chip(key, event.Color, order, true).Text = Icons.Event(event.Id, event.Kind)
						.. " "
						.. event.Name
						.. " in "
						.. Format.Time(soonestIn)
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
	-- Compact (ends at y ~172) so the right-centre edge stays free for SurvivalHUD.
	local holder = Instance.new("Frame")
	holder.Name = "Depth"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.new(1, -14, 0, 10)
	holder.Size = UDim2.fromOffset(182, 162)
	holder.Parent = canvas

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.new(1, 0, 0, 92)
	card.BackgroundColor3 = C.Stroke
	card.BackgroundTransparency = 0.25
	card.Parent = holder
	Style.Corner(card, Style.Theme.CornerMedium)
	local cardStroke = Style.Stroke(card, C.Stroke, 3)

	local depthLabel = Style.Label({
		Name = "Depth",
		Text = "⛏️ 0m",
		Size = UDim2.new(1, -12, 0, 34),
		Position = UDim2.fromOffset(6, 4),
		Font = Style.Fonts.Number,
		MaxTextSize = 30,
		Parent = card,
	})
	local layerLabel = Style.Label({
		Name = "Layer",
		Text = "Dry Sand",
		Size = UDim2.new(1, -12, 0, 26),
		Position = UDim2.fromOffset(6, 38),
		MaxTextSize = 22,
		Parent = card,
	})
	local maxLabel = Style.Label({
		Name = "Max",
		Text = "Record 0m",
		Size = UDim2.new(1, -12, 0, 20),
		Position = UDim2.fromOffset(6, 66),
		Font = Style.Fonts.Body,
		MaxTextSize = 17,
		TextColor = C.Sand,
		Parent = card,
	})

	local bar = ProgressBar.new({
		Name = "LayerProgress",
		Size = UDim2.new(1, -8, 0, 16),
		Position = UDim2.new(0.5, 0, 0, 100),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Config.Layers[1].Color,
		Parent = holder,
	})
	bar.Label.Visible = false
	local nextLabel = Style.Label({
		Name = "Next",
		Text = "",
		Size = UDim2.new(1, -4, 0, 40),
		Position = UDim2.new(1, -2, 0, 122),
		AnchorPoint = Vector2.new(1, 0),
		MaxTextSize = 17,
		MinTextSize = 10,
		Font = Style.Fonts.Body,
		Wrapped = true,
		XAlign = Enum.TextXAlignment.Right,
		YAlign = Enum.TextYAlignment.Top,
		Parent = holder,
	})

	local lastLayer = 0
	local function update(depth: number, index: number)
		local layer = Config.Layers[index]
		depthLabel.Text = Icons.Depth .. " " .. Format.Depth(Config.DepthToMeters(depth))
		if index ~= lastLayer then
			lastLayer = index
			layerLabel.Text = Icons.Layer(layer.Id) .. " " .. layer.Name
			layerLabel.TextColor3 = Color3.new(1, 1, 1):Lerp(layer.Color, 0.55)
			cardStroke.Color = Style.Darken(layer.Color, 0.35)
			bar:SetColor(layer.Color)
			Style.Pop(card, 0.12)
			local nextLayer = Config.Layers[index + 1]
			if nextLayer then
				local canDig = State.GetShovel().Power >= nextLayer.Hardness
				nextLabel.Text = "Next: "
					.. nextLayer.Name
					.. " @ "
					.. Format.Depth(nextLayer.DepthStart)
					.. (if canDig then "" else "\n🔒 needs 💪" .. nextLayer.Hardness)
			else
				nextLabel.Text = "The CORE! 🌟"
			end
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
			maxLabel.Text = "🏆 Record " .. Format.Depth(Config.DepthToMeters(value))
		end
	end)
end

local function buildBottom(canvas: Frame)
	local holder = Instance.new("Frame")
	holder.Name = "Bottom"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -10)
	holder.Size = UDim2.fromOffset(420, 180)
	holder.Parent = canvas

	local bar = ProgressBar.new({
		Name = "Backpack",
		Size = UDim2.fromOffset(400, 44),
		Position = UDim2.new(0.5, 0, 1, 0),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Sand,
		Text = "🎒 0 / 20",
		MaxTextSize = 24,
		Parent = holder,
	})
	backpackBar = bar

	local arrow = Style.Label({
		Name = "SellArrow",
		Text = "FULL! SELL! 💰⬇️",
		Size = UDim2.fromOffset(260, 36),
		Position = UDim2.new(0.5, 0, 1, -52),
		AnchorPoint = Vector2.new(0.5, 1),
		TextColor = C.Danger,
		StrokeColor = C.Text,
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
		Icon = Icons.Surface,
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
		Icon = Icons.Sell,
		Text = "Sell",
		Vertical = true,
		Color = C.Success,
		Size = UDim2.fromOffset(80, 80),
		MaxTextSize = 18,
		LayoutOrder = 2,
		Parent = row,
		OnClick = function()
			if State.OwnsPass("SellAnywhere") then
				State.SetSetting("SellNow", true)
			elseif not PurchaseController.PromptPass("SellAnywhere") then
				SoundController.Play("Error")
			end
		end,
	})
	HUD.Buttons.Sell = sell

	local auto = Button.new({
		Name = "AutoDig",
		Icon = Icons.AutoDig,
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

	State.ObserveMany({ "Passes", "Settings" }, function()
		local ownsSell = State.OwnsPass("SellAnywhere")
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
		bar:Set(
			sand / capacity,
			Icons.Backpack .. " " .. Format.Abbreviate(sand) .. " / " .. Format.Abbreviate(capacity)
		)
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
				if State.OwnsPass("SellAnywhere") then
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

function HUD.Init()
	local canvas = Root.Get("HUD")
	buildStats(canvas)
	buildMenu(canvas)
	buildTimers(canvas)
	buildDepthMeter(canvas)
	buildBottom(canvas)

	DigController.Feedback:Connect(function(reason: string)
		if reason == "TooHard" then
			HUD.Flash("Shop", 4)
		end
	end)
	-- hide the menu clutter while a panel is open on small screens
	Panel.Changed:Connect(function(name: string?)
		local menu = canvas:FindFirstChild("Menu")
		if menu and menu:IsA("GuiObject") then
			menu.Visible = name == nil or Root.GetDesignSize().X > 1150
		end
	end)
end

return HUD
