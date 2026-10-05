--!strict
--[[
	SurvivalHUD — heat meter, shade indicator, snack quick-slots and the shade placement bar
	(owner: Survival). Lives in its own ScreenGui "Dig_Survival" (same responsive scale as the
	main HUD) on the RIGHT-CENTRE screen edge, which the main HUD leaves free (docs/V2.md).

	- Thermometer: fill + colour follow the Heat attribute; above it a zone chip
	  (☀️ Sun / ⛱️ Shade / 🕳️ Underground / 🌴 Cool, 🧴 while the new-player grace lasts).
	  Sunburnt: the bulb pulses red, a "SUNBURNT!" tag shows and a toast explains the fix.
	- Quick-slots (1/2/3): the best owned snacks with counts; empty slot -> opens the Snacks tab.
	  A ⛱️ button starts placing your best shade (F); without one it opens the Beach Shop.
	- Placement bar (Rotate / Place / Cancel) while PlacementController is active (mobile-friendly).
	- Screen warmth: a client-only ColorCorrectionEffect "HeatTint" in Lighting plus a soft warm
	  edge glow that shimmers when hot. Never touches the World* lighting effects or DepthTint.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Components = script.Parent.Components
local Style = require(Components.Style)
local Button = require(Components.Button)
local Panel = require(Components.Panel)
local Root = require(script.Parent.Root)
local Toasts = require(script.Parent.Toasts)
local State = require(script.Parent.Parent.Controllers.State)
local SurvivalController = require(script.Parent.Parent.Controllers.SurvivalController)
local PlacementController = require(script.Parent.Parent.Controllers.PlacementController)

local SurvivalHUD = {}

local C = Style.Colors
local Heat = Config.Heat

local ZONES: { [string]: { Icon: string, Text: string, Color: Color3 } } = {
	Sun = { Icon = "☀️", Text = "SUN", Color = Color3.fromRGB(255, 170, 40) },
	Shade = { Icon = "⛱️", Text = "SHADE", Color = Color3.fromRGB(60, 170, 255) },
	Underground = { Icon = "🕳️", Text = "COOL", Color = Color3.fromRGB(120, 110, 200) },
	Cool = { Icon = "🌴", Text = "COOL", Color = Color3.fromRGB(70, 200, 120) },
}
local GRACE = { Icon = "🧴", Text = "SAFE", Color = Color3.fromRGB(90, 210, 200) }
local BURNT_ZONE = { Icon = "🥵", Text = "BURNT!", Color = Color3.fromRGB(240, 50, 50) }

local COLD = Color3.fromRGB(80, 190, 255)
local WARM = Color3.fromRGB(255, 205, 60)
local HOT = Color3.fromRGB(255, 120, 40)
local BURNT = Color3.fromRGB(240, 50, 50)

local TUBE_HEIGHT = 108
local HUD_HEIGHT = 206 -- fits the free region: y 180 .. bottom-150 at 540 design px

type Slot = { Button: Button.Button, Count: TextLabel, Key: TextLabel }

local gui: ScreenGui
local canvas: Frame
local fill: Frame
local bulb: Frame
local bulbLabel: TextLabel
local zoneChip: Frame
local zoneIcon: TextLabel
local zoneText: TextLabel
local glow: Frame
local glowGradient: UIGradient
local slots: { Slot } = {}
local shadeButton: Button.Button
local placeBar: Frame
local placeTitle: TextLabel
local tint: ColorCorrectionEffect? = nil
local bulbPulse: Tween? = nil
local glowPulse: Tween? = nil
local warned = false
local wasBurnt = false
local initialized = false

SurvivalHUD.Gui = nil :: ScreenGui?

local function heatColor(alpha: number, burnt: boolean): Color3
	if burnt then
		return BURNT
	end
	if alpha < 0.5 then
		return COLD:Lerp(WARM, alpha / 0.5)
	end
	return WARM:Lerp(HOT, (alpha - 0.5) / 0.5)
end

local function getTint(): ColorCorrectionEffect
	local existing = tint
	if existing and existing.Parent then
		return existing
	end
	local found = Lighting:FindFirstChild("HeatTint")
	local effect: ColorCorrectionEffect
	if found and found:IsA("ColorCorrectionEffect") then
		effect = found
	else
		effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "HeatTint"
		effect.Parent = Lighting
	end
	tint = effect
	return effect
end

-- Build ---------------------------------------------------------------------------------------------

local function makeGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "Dig_Survival"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 2
	SurvivalHUD.Gui = gui

	canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.BackgroundTransparency = 1
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = canvas
	local function applyScale(s: number)
		scale.Scale = s
		canvas.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	applyScale(Root.Scale)
	Root.ScaleChanged:Connect(applyScale)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function buildGlow()
	-- Warm edge glow (top + bottom), invisible when cool.
	glow = Instance.new("Frame")
	glow.Name = "HeatGlow"
	glow.BackgroundColor3 = Color3.fromRGB(255, 140, 40)
	glow.BackgroundTransparency = 1
	glow.BorderSizePixel = 0
	glow.Size = UDim2.fromScale(1.2, 1.2)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Active = false
	glow.ZIndex = 0
	glow.Parent = canvas
	glowGradient = Instance.new("UIGradient")
	glowGradient.Rotation = 90
	glowGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.2, 1),
		NumberSequenceKeypoint.new(0.8, 1),
		NumberSequenceKeypoint.new(1, 0.45),
	})
	glowGradient.Parent = glow
end

local function buildMeter(holder: Frame)
	local column = Instance.new("Frame")
	column.Name = "Meter"
	column.BackgroundTransparency = 1
	column.Size = UDim2.fromOffset(56, HUD_HEIGHT)
	column.Position = UDim2.new(1, 0, 0, 0)
	column.AnchorPoint = Vector2.new(1, 0)
	column.Parent = holder

	zoneChip = Instance.new("Frame")
	zoneChip.Name = "Zone"
	zoneChip.Size = UDim2.fromOffset(50, 50)
	zoneChip.Position = UDim2.new(0.5, 0, 0, 0)
	zoneChip.AnchorPoint = Vector2.new(0.5, 0)
	zoneChip.BackgroundColor3 = ZONES.Cool.Color
	zoneChip.ZIndex = 2
	zoneChip.Parent = column
	Style.Corner(zoneChip, Style.Theme.CornerPill)
	Style.Stroke(zoneChip, C.Stroke, 3)
	zoneIcon = Style.Label({
		Name = "Icon",
		Text = ZONES.Cool.Icon,
		Size = UDim2.new(1, -10, 0.62, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		AnchorPoint = Vector2.new(0.5, 0),
		MaxTextSize = 30,
		Stroke = false,
		ZIndex = 3,
		Parent = zoneChip,
	})
	zoneText = Style.Label({
		Name = "Text",
		Text = ZONES.Cool.Text,
		Size = UDim2.new(1, -6, 0.3, 0),
		Position = UDim2.new(0.5, 0, 1, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		MaxTextSize = 13,
		ZIndex = 3,
		Parent = zoneChip,
	})

	local tube = Instance.new("Frame")
	tube.Name = "Tube"
	tube.Size = UDim2.fromOffset(26, TUBE_HEIGHT)
	tube.Position = UDim2.new(0.5, 0, 0, 56)
	tube.AnchorPoint = Vector2.new(0.5, 0)
	tube.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
	tube.ClipsDescendants = true
	tube.ZIndex = 2
	tube.Parent = column
	Style.Corner(tube, Style.Theme.CornerPill)
	Style.Stroke(tube, C.Stroke, 3)

	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 0, 0)
	fill.Position = UDim2.fromScale(0, 1)
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.BackgroundColor3 = COLD
	fill.BorderSizePixel = 0
	fill.ZIndex = 3
	fill.Parent = tube
	Style.Corner(fill, Style.Theme.CornerPill)
	Style.Shine(fill)
	-- tick marks: warning + sunburnt thresholds
	for _, at in { Heat.WarningAt, Heat.SunburntAt * 0.995 } do
		local tick = Instance.new("Frame")
		tick.Name = "Tick"
		tick.Size = UDim2.new(0.5, 0, 0, 3)
		tick.Position = UDim2.new(0, 0, 1 - at / Heat.Max, 0)
		tick.BackgroundColor3 = C.Stroke
		tick.BackgroundTransparency = 0.4
		tick.BorderSizePixel = 0
		tick.ZIndex = 4
		tick.Parent = tube
	end

	bulb = Instance.new("Frame")
	bulb.Name = "Bulb"
	bulb.Size = UDim2.fromOffset(48, 48)
	bulb.Position = UDim2.new(0.5, 0, 0, 56 + TUBE_HEIGHT - 10)
	bulb.AnchorPoint = Vector2.new(0.5, 0)
	bulb.BackgroundColor3 = COLD
	bulb.ZIndex = 4
	bulb.Parent = column
	Style.Corner(bulb, Style.Theme.CornerPill)
	Style.Stroke(bulb, C.Stroke, 3)
	Style.Shine(bulb)
	bulbLabel = Style.Label({
		Name = "Value",
		Text = "0",
		Size = UDim2.fromScale(0.8, 0.6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		MaxTextSize = 20,
		ZIndex = 5,
		Parent = bulb,
	})
end

local function buildSlots(holder: Frame)
	local column = Instance.new("Frame")
	column.Name = "QuickSlots"
	column.BackgroundTransparency = 1
	column.Size = UDim2.fromOffset(52, HUD_HEIGHT)
	column.Position = UDim2.new(1, -62, 0, 0)
	column.AnchorPoint = Vector2.new(1, 0)
	column.Parent = holder
	Style.List(column, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)

	shadeButton = Button.new({
		Name = "PlaceShade",
		Icon = "⛱️",
		Text = "F",
		Vertical = true,
		Size = UDim2.fromOffset(48, 48),
		Color = C.Sunset,
		MaxTextSize = 14,
		LayoutOrder = 0,
		ZIndex = 3,
		Parent = column,
		OnClick = function()
			if PlacementController.BestOwnedShade() then
				PlacementController.Toggle()
			else
				Panel.Open("BeachShop", { Tab = "Shade" })
			end
		end,
	})

	for i = 1, SurvivalController.SLOT_COUNT do
		local button = Button.new({
			Name = "Slot" .. i,
			Icon = "➕",
			Text = "",
			Vertical = true,
			Size = UDim2.fromOffset(48, 48),
			Color = C.Ocean,
			MaxTextSize = 14,
			LayoutOrder = i,
			ZIndex = 3,
			Parent = column,
			OnClick = function()
				SurvivalController.UseSlot(i)
			end,
		})
		local count = Style.Label({
			Name = "Count",
			Text = "",
			Size = UDim2.fromOffset(34, 22),
			Position = UDim2.new(1, 4, 1, -2),
			AnchorPoint = Vector2.new(1, 1),
			MaxTextSize = 16,
			ZIndex = 8,
			Parent = button.Holder,
		})
		local key = Style.Label({
			Name = "Key",
			Text = tostring(i),
			Size = UDim2.fromOffset(20, 20),
			Position = UDim2.fromOffset(-4, -4),
			MaxTextSize = 14,
			ZIndex = 8,
			Parent = button.Holder,
		})
		key.BackgroundTransparency = 0
		key.BackgroundColor3 = C.Stroke
		Style.Corner(key, Style.Theme.CornerPill)
		table.insert(slots, { Button = button, Count = count, Key = key })
	end
end

local function buildPlaceBar()
	placeBar = Instance.new("Frame")
	placeBar.Name = "PlacementBar"
	placeBar.BackgroundTransparency = 1
	placeBar.Size = UDim2.fromOffset(420, 110)
	placeBar.Position = UDim2.new(0.5, 0, 1, -175)
	placeBar.AnchorPoint = Vector2.new(0.5, 1)
	placeBar.Visible = false
	placeBar.ZIndex = 5
	placeBar.Parent = canvas
	placeTitle = Style.Label({
		Name = "Title",
		Text = "",
		Size = UDim2.new(1, 0, 0, 34),
		MaxTextSize = 24,
		ZIndex = 6,
		Parent = placeBar,
	})
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 66)
	row.Position = UDim2.fromOffset(0, 40)
	row.Parent = placeBar
	Style.List(row, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center)
	Button.new({
		Name = "Rotate",
		Icon = "🔄",
		Text = "Turn",
		Size = UDim2.fromOffset(120, 60),
		Color = C.Ocean,
		LayoutOrder = 1,
		ZIndex = 6,
		Parent = row,
		OnClick = function()
			PlacementController.Rotate()
		end,
	})
	Button.new({
		Name = "Place",
		Icon = "✅",
		Text = "Place",
		Size = UDim2.fromOffset(140, 60),
		Color = C.Success,
		LayoutOrder = 2,
		ZIndex = 6,
		Parent = row,
		OnClick = function()
			PlacementController.Confirm()
		end,
	})
	Button.new({
		Name = "Cancel",
		Icon = "✖",
		Text = "Cancel",
		Size = UDim2.fromOffset(130, 60),
		Color = C.Danger,
		LayoutOrder = 3,
		ZIndex = 6,
		Parent = row,
		OnClick = function()
			PlacementController.Cancel()
		end,
	})
end

-- Refresh -------------------------------------------------------------------------------------------

local function refreshSlots()
	local ids = SurvivalController.GetQuickSlots()
	local counts = State.Data.Consumables or ({} :: { [string]: number })
	for i, slot in slots do
		local id = ids[i]
		local def = if id then Config.GetConsumable(id) else nil
		if def then
			slot.Button:SetIcon(def.Icon)
			slot.Button:SetColor(C.Ocean)
			slot.Count.Text = "x" .. tostring(counts[def.Id] or 0)
			slot.Count.Visible = true
		else
			slot.Button:SetIcon("➕")
			slot.Button:SetColor(C.SandDark)
			slot.Count.Visible = false
		end
	end
	local hasShade = PlacementController.BestOwnedShade() ~= nil
	shadeButton:SetColor(if PlacementController.Active then C.Danger elseif hasShade then C.Sunset else C.SandDark)
	shadeButton:SetText(if PlacementController.Active then "Stop" else "F")
end

local function refreshPlacement()
	placeBar.Visible = PlacementController.Active
	local id = PlacementController.ShadeId
	local def = if id then Config.GetShade(id) else nil
	placeTitle.Text = if def then "Place your " .. def.Name .. "!" else "Place your shade!"
	refreshSlots()
end

local function refreshHeat()
	local heat = SurvivalController.GetHeat()
	local burnt = SurvivalController.IsSunburnt()
	local alpha = math.clamp(heat / Heat.Max, 0, 1)
	local color = heatColor(alpha, burnt)
	Style.Tween(fill, 0.25, { Size = UDim2.new(1, 0, alpha, 0), BackgroundColor3 = color })
	bulb.BackgroundColor3 = color
	bulbLabel.Text = tostring(math.floor(heat + 0.5))

	local zone = if burnt
		then BURNT_ZONE
		elseif SurvivalController.InGrace() and SurvivalController.GetZone() == "Sun" then GRACE
		else ZONES[SurvivalController.GetZone()] or ZONES.Cool
	zoneChip.BackgroundColor3 = zone.Color
	zoneIcon.Text = zone.Icon
	zoneText.Text = zone.Text

	-- Sunburnt state + toasts
	if burnt and not wasBurnt then
		bulbPulse = Style.Pulse(bulb, 0.18, 0.7)
		Toasts.Show("Sunburnt! Find shade or drink water 💧", "Error", 5)
	elseif not burnt and wasBurnt then
		Style.StopPulse(bulb, bulbPulse)
		bulbPulse = nil
		Toasts.Show("Cooled down! Back to full speed 😎", "Success", 3)
	end
	wasBurnt = burnt
	if not burnt and heat >= Heat.WarningAt and not warned then
		warned = true
		local tip = if PlacementController.BestOwnedShade()
			then "Getting hot! ☀️ Press F to place your shade, or have a drink."
			else "Getting hot! ☀️ Find shade, go underground or drink at the fountain."
		Toasts.Show(tip, "Info", 4)
	elseif heat < Heat.WarningAt - 15 then
		warned = false
	end

	-- Screen warmth
	local warmth = math.clamp((heat - 45) / (Heat.Max - 45), 0, 1)
	local effect = getTint()
	effect.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 226, 196), warmth)
	effect.Saturation = 0.12 * warmth
	effect.Contrast = 0.04 * warmth
	local target = if burnt then 0.35 else 1 - 0.5 * warmth
	if warmth > 0 and not glowPulse then
		glowPulse = Style.Tween(
			glowGradient,
			1.4,
			{ Offset = Vector2.new(0, 0.04) },
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1,
			true
		)
	elseif warmth <= 0 and glowPulse then
		glowPulse:Cancel()
		glowPulse = nil
	end
	Style.Tween(glow, 0.4, { BackgroundTransparency = math.clamp(target, 0, 1) })
end

-- Init ----------------------------------------------------------------------------------------------

function SurvivalHUD.Init()
	if initialized then
		return
	end
	initialized = true
	makeGui()
	buildGlow()

	local holder = Instance.new("Frame")
	holder.Name = "SurvivalHUD"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(120, HUD_HEIGHT)
	holder.Position = UDim2.new(1, -8, 0, 180)
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.ZIndex = 2
	holder.Parent = canvas
	buildMeter(holder)
	buildSlots(holder)
	buildPlaceBar()

	PlacementController.Hint = function(text: string, kind: string)
		Toasts.Show(text, kind)
	end
	PlacementController.Changed:Connect(refreshPlacement)
	SurvivalController.Changed:Connect(refreshHeat)
	State.ObserveMany({ "Consumables", "OwnedShades" }, refreshSlots)
	refreshPlacement()
	refreshHeat()
end

SurvivalHUD.Refresh = function()
	refreshHeat()
	refreshSlots()
end

return SurvivalHUD
