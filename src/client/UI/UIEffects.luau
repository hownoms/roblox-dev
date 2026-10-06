--!strict
-- Screen-space juice: icons flying into a HUD counter (coin rain on sell), screen flash,
-- confetti and floating "+123" numbers next to HUD elements.
local Debris = game:GetService("Debris")

local Root = require(script.Parent.Root)
local Style = require(script.Parent.Components.Style)
local AtlasIcon = require(script.Parent.Components.AtlasIcon)
local State = require(script.Parent.Parent.Controllers.State)

local UIEffects = {}

local function canvas(): Frame
	return Root.Get("Popups")
end

-- Absolute screen position -> design-px position inside the Popups canvas.
local function toCanvas(absolute: Vector2): Vector2
	local c = canvas()
	return (absolute - c.AbsolutePosition) / Root.Scale
end

local function centerOf(gui: GuiObject): Vector2
	return toCanvas(gui.AbsolutePosition + gui.AbsoluteSize / 2)
end

local function lowGraphics(): boolean
	return State.GetSetting("LowGraphics", false) == true
end

-- Icons (AtlasIcon keys) burst out from `from` (design px; default screen centre) and fly
-- into `target`.
function UIEffects.FlyTo(icon: string, target: GuiObject, count: number?, from: Vector2?, onArrive: (() -> ())?)
	local c = canvas()
	local start = from or (c.AbsoluteSize / Root.Scale) / 2
	local finish = centerOf(target)
	local n = if lowGraphics() then math.min(count or 8, 4) else (count or 8)
	for i = 1, n do
		local label = AtlasIcon.new({
			Icon = icon,
			Size = UDim2.fromOffset(44, 44),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(start.X, start.Y),
			ZIndex = 50,
			Parent = c,
		}).Frame
		local angle = math.random() * math.pi * 2
		local radius = 50 + math.random() * 70
		local scatter = start + Vector2.new(math.cos(angle), math.sin(angle)) * radius
		Style.PopIn(label, 0.2)
		local out = Style.Tween(
			label,
			0.3,
			{ Position = UDim2.fromOffset(scatter.X, scatter.Y) },
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		)
		out.Completed:Once(function()
			task.wait(0.04 * i)
			local fly = Style.Tween(
				label,
				0.45,
				{ Position = UDim2.fromOffset(finish.X, finish.Y), Size = UDim2.fromOffset(24, 24) },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			fly.Completed:Once(function()
				label:Destroy()
				if i == 1 and onArrive then
					onArrive()
				end
				Style.Pop(target, 0.12)
			end)
		end)
		Debris:AddItem(label, 3)
	end
end

-- "+1.2K" rising from a HUD element.
function UIEffects.FloatFrom(target: GuiObject, text: string, color: Color3?)
	local c = canvas()
	local pos = centerOf(target) + Vector2.new(target.AbsoluteSize.X / Root.Scale / 2 + 10, 0)
	local label = Style.Label({
		Text = text,
		Size = UDim2.fromOffset(160, 34),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		TextColor = color or Style.Colors.Success,
		Font = Style.Fonts.Number,
		MaxTextSize = 28,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		ZIndex = 40,
		Parent = c,
	})
	Style.PopIn(label, 0.25)
	Style.Tween(label, 1.1, { Position = UDim2.fromOffset(pos.X + 6, pos.Y - 40) }, Enum.EasingStyle.Quad)
	task.delay(0.7, function()
		Style.Tween(label, 0.4, { TextTransparency = 1 })
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			Style.Tween(stroke, 0.4, { Transparency = 1 })
		end
	end)
	Debris:AddItem(label, 1.4)
end

function UIEffects.Flash(color: Color3?, strength: number?)
	local c = canvas()
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BackgroundColor3 = color or Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1 - (strength or 0.6)
	flash.Size = UDim2.fromScale(3, 3)
	flash.Position = UDim2.fromScale(0.5, 0.5)
	flash.AnchorPoint = Vector2.new(0.5, 0.5)
	flash.ZIndex = 60
	flash.Parent = c
	Style.Tween(flash, 0.5, { BackgroundTransparency = 1 })
	Debris:AddItem(flash, 0.6)
end

function UIEffects.Confetti(count: number?, colors: { Color3 }?)
	local c = canvas()
	local size = c.AbsoluteSize / Root.Scale
	local palette: { Color3 } = colors
		or { Style.Colors.Coral, Style.Colors.Gold, Style.Colors.Ocean, Style.Colors.Palm, Style.Colors.Purple }
	local n = if lowGraphics() then 12 else (count or 40)
	for _ = 1, n do
		local piece = Instance.new("Frame")
		piece.Name = "Confetti"
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = palette[math.random(1, #palette)]
		piece.Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22))
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		local x = math.random() * size.X
		piece.Position = UDim2.fromOffset(x, -20)
		piece.Rotation = math.random(0, 360)
		piece.ZIndex = 55
		piece.Parent = c
		local duration = 1.4 + math.random() * 1.2
		Style.Tween(piece, duration, {
			Position = UDim2.fromOffset(x + (math.random() - 0.5) * 220, size.Y + 30),
			Rotation = piece.Rotation + math.random(-540, 540),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(piece, duration + 0.1)
	end
end

return UIEffects
