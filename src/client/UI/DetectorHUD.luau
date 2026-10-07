--!strict
--[[
	DetectorHUD (v3 discovery slice) — the free treasure detector everyone has.

	One big toy button "Scan" (80 x 80 design px, same as Surface / Sell / Auto) at the left of
	the bottom action row (HUD.ActionsRow), so phones, tablets and PCs all get it in the same
	thumb-friendly spot. Key T / gamepad L2 do the same (DiscoveryController).

	While a scan runs the button becomes the radar:
	  - its outline glows in the signal colour (white = common, gold = rare+, purple = mythic+)
	  - a dot orbits the button pointing at the find, relative to the camera
	  - the caption reads the distance band (HOT! / Warm / Cool / Faint / Nothing)
	  - a pill above it says what to do: DIG HERE! / DIG DOWN! when the find is within the hot
	    band, otherwise DOWN / UP when it is below / above you (DetectorHUD.Instruction)
	  - the orbiting dot carries an arrowhead pointing away from the button, toward the find
	Between scans the caption counts the cooldown down. Everything is driven by the coarse
	DetectorPing (band, sector, vertical, signal); DetectorHUD.Render(ping, scanning, cooldown)
	is public for tests.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))

local Style = require(script.Parent.Components.Style)
local Button = require(script.Parent.Components.Button)
local AtlasIcon = require(script.Parent.Components.AtlasIcon)
local HUD = require(script.Parent.HUD)
local DiscoveryController = require(script.Parent.Parent.Controllers.DiscoveryController)

local DetectorHUD = {}

DetectorHUD.Button = nil :: Button.Button?
DetectorHUD.BAND_WORDS = table.freeze({ "HOT!", "Warm", "Cool", "Faint" })

local C = Style.Colors
local pivot: Frame? = nil
local dot: Frame? = nil
local ringStroke: UIStroke? = nil
local verticalPill: TextLabel? = nil
local initialized = false

-- What the pill above the button says (pure, tests): "" when there is nothing to say.
function DetectorHUD.Instruction(ping: Types.DetectorPing, scanning: boolean): string
	if not scanning or ping.Band <= 0 then
		return ""
	end
	if ping.Band == 1 then
		return if ping.Vertical == "Up" then "UP HERE!" elseif ping.Vertical == "Down" then "DIG DOWN!" else "DIG HERE!"
	end
	return if ping.Vertical == "Down" then "DOWN" elseif ping.Vertical == "Up" then "UP" else ""
end

-- Caption for the button (pure, tests).
function DetectorHUD.Caption(ping: Types.DetectorPing, scanning: boolean, cooldown: number): string
	if scanning then
		if ping.Band <= 0 then
			return "Nothing"
		end
		return DetectorHUD.BAND_WORDS[math.clamp(ping.Band, 1, #DetectorHUD.BAND_WORDS)]
	end
	if cooldown > 0 then
		return tostring(math.ceil(cooldown)) .. "s"
	end
	return "Scan"
end

function DetectorHUD.Render(ping: Types.DetectorPing, scanning: boolean, cooldown: number)
	local maybeButton = DetectorHUD.Button
	if not maybeButton then
		return
	end
	local button = maybeButton :: Button.Button
	button:SetText(DetectorHUD.Caption(ping, scanning, cooldown))
	local live = scanning and ping.Band > 0
	local color = DiscoveryController.SignalColor(ping.Signal)
	if ringStroke then
		ringStroke.Color = if live then color else C.Stroke
		ringStroke.Transparency = if live then 0 else 1
	end
	local angle = if live then DiscoveryController.ArrowAngle() else nil
	if pivot and dot then
		dot.Visible = angle ~= nil
		dot.BackgroundColor3 = color
		if angle then
			pivot.Rotation = angle
			local size = 14 + (4 - math.clamp(ping.Band, 1, 4)) * 4
			dot.Size = UDim2.fromOffset(size, size)
		end
	end
	if verticalPill then
		local word = DetectorHUD.Instruction(ping, scanning)
		verticalPill.Visible = word ~= ""
		verticalPill.Text = word
		verticalPill.BackgroundColor3 = if ping.Band == 1 then color:Lerp(C.Navy, 0.35) else C.Navy
	end
	button:SetColor(if scanning then C.Purple elseif cooldown > 0 then C.Disabled else C.Coral)
end

function DetectorHUD.Init()
	if initialized then
		return
	end
	initialized = true
	local row = HUD.ActionsRow
	if not row then
		return
	end
	local button = Button.new({
		Name = "Scan",
		Icon = "📡",
		Text = "Scan",
		Vertical = true,
		Color = C.Coral,
		Size = UDim2.fromOffset(80, 80),
		MaxTextSize = 18,
		LayoutOrder = 0,
		Sound = "",
		Parent = row,
		OnClick = function()
			DiscoveryController.Scan()
		end,
	})
	DetectorHUD.Button = button
	HUD.Buttons.Scan = button

	-- radar overlay: glowing outline, orbiting direction dot, DOWN/UP pill
	local ring = Instance.new("Frame")
	ring.Name = "Radar"
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.new(1, 8, 1, 8)
	ring.Position = UDim2.fromOffset(-4, -4)
	ring.ZIndex = 6
	ring.Parent = button.Holder
	Style.Corner(ring, UDim.new(0, 14))
	ringStroke = Style.Stroke(ring, C.Stroke, 4)
	local p = Instance.new("Frame")
	p.Name = "Pivot"
	p.BackgroundTransparency = 1
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromScale(0.5, 0.46)
	p.Size = UDim2.fromOffset(100, 100)
	p.ZIndex = 7
	p.Parent = button.Holder
	pivot = p
	local d = Instance.new("Frame")
	d.Name = "Dot"
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = UDim2.fromScale(0.5, 0)
	d.Size = UDim2.fromOffset(16, 16)
	d.Visible = false
	d.ZIndex = 8
	d.Parent = p
	Style.Corner(d, UDim.new(1, 0))
	Style.Stroke(d, C.Stroke, 2)
	-- the pivot's rotation carries this round; 180 turns the down-arrow icon to point outward
	AtlasIcon.new({
		Name = "Pointer",
		Icon = "Arrow",
		Size = UDim2.fromScale(1.1, 1.1),
		Position = UDim2.fromScale(0.5, -0.35),
		Rotation = 180,
		ZIndex = 8,
		Parent = d,
	})
	dot = d
	local pill = Style.Label({
		Name = "Vertical",
		Text = "",
		Size = UDim2.fromOffset(96, 24),
		Position = UDim2.new(0.5, 0, 0, -16),
		AnchorPoint = Vector2.new(0.5, 1),
		MaxTextSize = 16,
		ZIndex = 9,
		Parent = button.Holder,
	})
	pill.BackgroundTransparency = 0
	pill.BackgroundColor3 = C.Navy
	pill.Visible = false
	Style.Corner(pill, Style.Theme.CornerPill)
	Style.Stroke(pill, C.Stroke, 2)
	verticalPill = pill

	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		DetectorHUD.Render(
			DiscoveryController.Ping,
			DiscoveryController.IsScanning(),
			DiscoveryController.CooldownLeft()
		)
	end)
	DetectorHUD.Render(DiscoveryController.Ping, false, 0)
end

return DetectorHUD
