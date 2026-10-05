--!strict
-- Shared styling helpers: theme access, instance property application, corners, strokes,
-- gradients, chunky text and bouncy tweens. Every component builds on these.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Style = {}

Style.Theme = Config.Theme
Style.Colors = Config.Theme.Colors
Style.Fonts = Config.Theme.Fonts

-- Assigns props to inst (Parent last) and returns inst with its type preserved.
function Style.Apply<T>(inst: T, props: { [string]: any }): T
	local parent = nil
	for key, value in props do
		if key == "Parent" then
			parent = value
		else
			(inst :: any)[key] = value
		end
	end
	if parent then
		(inst :: any).Parent = parent
	end
	return inst
end

function Style.Darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

function Style.Lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

function Style.Corner(parent: Instance, radius: UDim?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Style.Theme.CornerMedium
	corner.Parent = parent
	return corner
end

-- border = true strokes the frame outline; false strokes text (Contextual).
function Style.Stroke(parent: Instance, color: Color3?, thickness: number?, border: boolean?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Style.Colors.Stroke
	stroke.Thickness = thickness or Style.Theme.StrokeThickness
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.ApplyStrokeMode = if border == false then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Style.Sequence(colors: { Color3 }): ColorSequence
	if #colors == 0 then
		return ColorSequence.new(Color3.new(1, 1, 1))
	elseif #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keypoints = {}
	for i, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keypoints)
end

function Style.Gradient(parent: Instance, colors: { Color3 }, rotation: number?): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = Style.Sequence(colors)
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
end

-- Subtle top-to-bottom shine used on buttons/cards (white -> light grey multiplies the colour).
function Style.Shine(parent: Instance): UIGradient
	return Style.Gradient(parent, { Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215) }, 90)
end

function Style.Padding(parent: Instance, px: number, horizontal: number?): UIPadding
	local padding = Instance.new("UIPadding")
	local h = UDim.new(0, horizontal or px)
	local v = UDim.new(0, px)
	padding.PaddingLeft = h
	padding.PaddingRight = h
	padding.PaddingTop = v
	padding.PaddingBottom = v
	padding.Parent = parent
	return padding
end

function Style.List(
	parent: Instance,
	direction: Enum.FillDirection?,
	padding: number?,
	hAlign: Enum.HorizontalAlignment?,
	vAlign: Enum.VerticalAlignment?
): UIListLayout
	local list = Instance.new("UIListLayout")
	list.FillDirection = direction or Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, padding or 6)
	list.HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center
	list.VerticalAlignment = vAlign or Enum.VerticalAlignment.Top
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = parent
	return list
end

export type LabelProps = {
	Name: string?,
	Text: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Font: Enum.Font?,
	TextColor: Color3?,
	MaxTextSize: number?,
	MinTextSize: number?,
	Stroke: boolean?, -- dark outline (default true for light text)
	StrokeColor: Color3?,
	StrokeThickness: number?,
	XAlign: Enum.TextXAlignment?,
	YAlign: Enum.TextYAlignment?,
	LayoutOrder: number?,
	ZIndex: number?,
	Wrapped: boolean?,
	RichText: boolean?,
	Parent: Instance?,
}

-- Chunky cartoon text: scaled to fit, capped by MaxTextSize, dark stroke by default.
function Style.Label(props: LabelProps): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = props.Name or "Label"
	label.BackgroundTransparency = 1
	label.Text = props.Text or ""
	label.Size = props.Size or UDim2.fromScale(1, 1)
	label.Position = props.Position or UDim2.new()
	label.AnchorPoint = props.AnchorPoint or Vector2.zero
	label.Font = props.Font or Style.Fonts.Title
	label.TextColor3 = props.TextColor or Style.Colors.Text
	label.TextScaled = true
	label.TextWrapped = props.Wrapped == true
	label.RichText = props.RichText == true
	label.TextXAlignment = props.XAlign or Enum.TextXAlignment.Center
	label.TextYAlignment = props.YAlign or Enum.TextYAlignment.Center
	label.LayoutOrder = props.LayoutOrder or 0
	label.ZIndex = props.ZIndex or 1
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = props.MaxTextSize or 28
	constraint.MinTextSize = props.MinTextSize or 6
	constraint.Parent = label
	if props.Stroke ~= false then
		Style.Stroke(label, props.StrokeColor, props.StrokeThickness or 2, false)
	end
	if props.Parent then
		label.Parent = props.Parent
	end
	return label
end

function Style.Tween(
	inst: Instance,
	time: number,
	props: { [string]: any },
	easingStyle: Enum.EasingStyle?,
	direction: Enum.EasingDirection?,
	repeatCount: number?,
	reverses: boolean?
): Tween
	local info = TweenInfo.new(
		time,
		easingStyle or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out,
		repeatCount or 0,
		reverses or false
	)
	local tween = TweenService:Create(inst, info, props)
	tween:Play()
	return tween
end

-- Returns (creating if needed) a UIScale named "Pop" used for bounce effects.
function Style.GetPopScale(gui: GuiObject): UIScale
	local existing = gui:FindFirstChild("Pop")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Name = "Pop"
	scale.Parent = gui
	return scale
end

-- Quick squash-and-stretch bounce: grows by `amount` then springs back.
function Style.Pop(gui: GuiObject, amount: number?)
	local scale = Style.GetPopScale(gui)
	scale.Scale = 1 + (amount or 0.18)
	Style.Tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
end

-- Pop in from nothing.
function Style.PopIn(gui: GuiObject, time: number?)
	local scale = Style.GetPopScale(gui)
	scale.Scale = 0
	Style.Tween(scale, time or 0.35, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

-- Endless gentle pulse; returns the tween so callers can :Cancel() it.
function Style.Pulse(gui: GuiObject, amount: number?, period: number?): Tween
	local scale = Style.GetPopScale(gui)
	scale.Scale = 1
	return Style.Tween(
		scale,
		(period or 0.9) / 2,
		{ Scale = 1 + (amount or 0.08) },
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1,
		true
	)
end

function Style.StopPulse(gui: GuiObject, tween: Tween?)
	if tween then
		tween:Cancel()
	end
	local scale = gui:FindFirstChild("Pop")
	if scale and scale:IsA("UIScale") then
		Style.Tween(scale, 0.15, { Scale = 1 })
	end
end

return Style
