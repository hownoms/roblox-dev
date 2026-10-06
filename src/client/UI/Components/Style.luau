--!strict
-- Shared styling helpers: theme access, instance property application, corners, strokes,
-- gradients, chunky text and bouncy tweens. Every component builds on these.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Root = require(script.Parent.Parent.Root)

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

-- Text size caps follow the UI scale --------------------------------------------------------
-- UITextSizeConstraint limits are applied in screen pixels and are NOT multiplied by the
-- canvas UIScale, so on a big PC screen (scale 1.35) a "MaxTextSize = 16" caption stayed 16 px
-- inside a button that had grown 35% ("tiny text" playtest feedback). Every constraint made
-- by Style.Label registers its design-pixel caps here and is rescaled whenever Root.Scale
-- changes. Caps are never shrunk below their design value (TextScaled already shrinks text to
-- fit smaller boxes on phones) and the minimum never drops below a readable 8 px.
local MIN_READABLE = 8
local constraints: { [UITextSizeConstraint]: { Max: number, Min: number } } = setmetatable({}, { __mode = "k" }) :: any

local function applyCaps(constraint: UITextSizeConstraint, caps: { Max: number, Min: number }, scale: number)
	local up = math.max(scale, 1)
	constraint.MaxTextSize = math.clamp(math.floor(caps.Max * up + 0.5), 1, 100)
	constraint.MinTextSize = math.clamp(math.max(caps.Min, MIN_READABLE), 1, constraint.MaxTextSize)
end

-- Registers a UITextSizeConstraint (design-pixel caps) so it follows the UI scale.
function Style.TrackTextSize(constraint: UITextSizeConstraint, maxDesign: number, minDesign: number?)
	local caps = { Max = maxDesign, Min = minDesign or MIN_READABLE }
	constraints[constraint] = caps
	applyCaps(constraint, caps, Root.Scale)
end

Root.ScaleChanged:Connect(function(scale: number)
	for constraint, caps in constraints do
		applyCaps(constraint, caps, scale)
	end
end)

-- Emoji-safe sizing ------------------------------------------------------------------------
-- Playtest: every label containing an emoji ("⛏️ 0m", menu icons) rendered at a fraction of its
-- box, while plain-text labels were fine. TextScaled sizes by the font's line metrics and the
-- emoji fallback font reports a very tall line, so the whole label shrinks. Labels whose text
-- contains a multi-byte symbol therefore use an explicit TextSize computed from the box
-- (height, then shrunk to fit the measured width) instead of TextScaled.
local FIT_HEIGHT = 0.8
local FIT_WIDTH = 0.96

local function hasSymbol(text: string): boolean
	-- 3- and 4-byte UTF-8 sequences: emoji and pictographic symbols (☀ ⛏ 🏝 ...).
	return string.find(text, "[\226-\244]") ~= nil
end

local function fitLabel(label: TextLabel, constraint: UITextSizeConstraint)
	local text = label.Text
	if not hasSymbol(text) then
		label.TextScaled = true
		constraint.Parent = label
		return
	end
	constraint.Parent = nil -- caps are applied by hand below
	label.TextScaled = false
	local box = label.AbsoluteSize
	if box.X < 1 or box.Y < 1 then
		return
	end
	local scale = if Root.Scale > 0 then Root.Scale else 1
	local px = box.Y * FIT_HEIGHT
	local ok, bounds = pcall(function()
		return TextService:GetTextSize(text, math.max(1, math.floor(px)), label.Font, Vector2.new(1e5, 1e5))
	end)
	if ok and bounds.X > box.X * FIT_WIDTH then
		px *= box.X * FIT_WIDTH / bounds.X
	end
	-- TextSize is in canvas units; the canvas UIScale multiplies it back up to screen pixels.
	label.TextSize = math.clamp(math.floor(px / scale), MIN_READABLE, 100)
end

local function autoFit(label: TextLabel, constraint: UITextSizeConstraint)
	local function refit()
		fitLabel(label, constraint)
	end
	label:GetPropertyChangedSignal("Text"):Connect(refit)
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	local scaleConn = Root.ScaleChanged:Connect(refit)
	label.Destroying:Connect(function()
		scaleConn:Disconnect()
	end)
	refit()
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
	Style.TrackTextSize(constraint, props.MaxTextSize or 28, props.MinTextSize)
	constraint.Parent = label
	autoFit(label, constraint)
	if props.Stroke ~= false then
		Style.Stroke(label, props.StrokeColor, props.StrokeThickness or 2, false)
	end
	if props.Parent then
		label.Parent = props.Parent
	end
	return label
end

export type IconProps = {
	Name: string?,
	Text: string,
	Size: UDim2?, -- default: fills the parent
	Position: UDim2?, -- default: centred
	AnchorPoint: Vector2?,
	ZIndex: number?,
	LayoutOrder: number?,
	Parent: Instance?,
}

-- Emoji icon that fills its box: square (aspect-ratio locked, fits inside the given size),
-- centred, TextScaled with no small cap, no stroke. Use for every icon slot so icons read at
-- the same visual weight on PC and phone.
function Style.Icon(props: IconProps): TextLabel
	local icon = Style.Label({
		Name = props.Name or "Icon",
		Text = props.Text,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		MaxTextSize = 96,
		MinTextSize = 12,
		Stroke = false,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
	})
	icon.TextYAlignment = Enum.TextYAlignment.Center
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.AspectType = Enum.AspectType.FitWithinMaxSize
	ratio.Parent = icon
	if props.Parent then
		icon.Parent = props.Parent
	end
	return icon
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
