--!strict
--[[
	ObjectiveBanner — the slim top-centre objective pill (docs/UI_STYLE.md): dark navy pill with
	an atlas icon overlapping its left end, one short bold outlined line ("Tap the sand to
	DIG!"), an optional step counter chip and an optional bouncing arrow. Toasts stack under it
	(UI/Layout: Banner region, top of the centre column). Used by TutorialController.

		ObjectiveBanner.Show("Sell your sand!", "Sell", { Step = "4/6", Arrow = true })
		ObjectiveBanner.Hide()
]]
local Root = require(script.Parent.Root)
local Layout = require(script.Parent.Layout)
local Style = require(script.Parent.Components.Style)
local AtlasIcon = require(script.Parent.Components.AtlasIcon)
local State = require(script.Parent.Parent.Controllers.State)

local ObjectiveBanner = {}

export type Options = { Step: string?, Arrow: boolean? }

local frame: Frame? = nil
local icon: AtlasIcon.AtlasIcon
local label: TextLabel
local step: TextLabel
local arrow: AtlasIcon.AtlasIcon
local arrowTween: Tween? = nil
local hiding = 0
local suppressed = false -- SetSuppressed (AdventureHUD)

ObjectiveBanner.Visible = false

local function refreshArrow()
	if arrowTween then
		arrowTween:Cancel()
		arrowTween = nil
	end
	if not frame then
		return
	end
	arrow.Frame.Position = UDim2.new(1, -6, 0.5, -2)
	if ObjectiveBanner.Visible and arrow.Frame.Visible and State.GetSetting("ReducedMotion", false) ~= true then
		arrow.Frame.Position = UDim2.new(1, -6, 0.5, -6)
		arrowTween = Style.Tween(
			arrow.Frame,
			0.4,
			{ Position = UDim2.new(1, -6, 0.5, 4) },
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1,
			true
		)
	end
end

State.Changed("Settings"):Connect(refreshArrow)

local function build(): Frame
	local existing = frame
	if existing then
		return existing
	end
	local pill = Instance.new("Frame")
	pill.Name = "Objective"
	pill.Visible = false
	pill.ZIndex = 5
	pill.Parent = Root.Get("HUD")
	Style.Pill(pill, 0.08)
	local ring = pill:FindFirstChildOfClass("UIStroke")
	if ring then
		ring.Thickness = 3
	end
	Layout.Observe(function(regions: Layout.Regions)
		pill.Position = Layout.Position(regions.Banner)
		pill.Size = Layout.SizeOf(regions.Banner)
	end)

	icon = AtlasIcon.new({
		Name = "ObjectiveIcon",
		Icon = "Star",
		Size = UDim2.fromOffset(58, 58),
		Position = UDim2.new(0, -12, 0.5, -2),
		AnchorPoint = Vector2.new(0, 0.5),
		Rotation = -8,
		ZIndex = 7,
		Parent = pill,
	})
	label = Style.Label({
		Name = "Text",
		Text = "",
		Size = UDim2.new(1, -150, 0.78, 0),
		Position = UDim2.new(0, 52, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		MaxTextSize = 24,
		StrokeThickness = 3,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = pill,
	})
	step = Style.Label({
		Name = "Step",
		Text = "",
		Size = UDim2.fromOffset(52, 28),
		Position = UDim2.new(1, -46, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Font = Style.Fonts.Title,
		MaxTextSize = 18,
		ZIndex = 7,
		Parent = pill,
	})
	step.BackgroundTransparency = 0
	step.BackgroundColor3 = Style.Colors.Coral
	Style.Corner(step, Style.Theme.CornerPill)
	Style.Stroke(step, Style.Colors.Stroke, 2)
	arrow = AtlasIcon.new({
		Name = "Arrow",
		Icon = "Arrow",
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.new(1, -6, 0.5, -2),
		AnchorPoint = Vector2.new(1, 0.5),
		ZIndex = 7,
		Parent = pill,
	})
	frame = pill
	return pill
end

function ObjectiveBanner.Show(text: string, iconKey: string?, options: Options?)
	local pill = build()
	local opts: Options = options or {}
	hiding += 1
	label.Text = text
	icon:Set(iconKey or "Star")
	step.Visible = opts.Step ~= nil
	step.Text = opts.Step or ""
	local wantArrow = opts.Arrow == true
	arrow.Frame.Visible = wantArrow
	label.Size = UDim2.new(1, (if opts.Step then -110 else -60) - (if wantArrow then 34 else 0), 0.78, 0)
	step.Position = UDim2.new(1, if wantArrow then -44 else -8, 0.5, 0)
	ObjectiveBanner.Visible = true
	refreshArrow()
	if suppressed then
		return -- shown again by SetSuppressed(false)
	end
	pill.Visible = true
	Style.PopIn(pill, 0.35)
end

function ObjectiveBanner.Hide()
	local maybe = frame
	ObjectiveBanner.Visible = false
	refreshArrow()
	if not maybe or not maybe.Visible then
		return
	end
	local pill = maybe :: Frame
	hiding += 1
	local token = hiding
	local scale = Style.GetPopScale(pill)
	Style.Tween(scale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Once(function()
		if token == hiding then
			pill.Visible = false
		end
	end)
end

-- Keeps the pill off screen without losing its objective (AdventureHUD: the Spring Vault panel
-- covers it in the arena). Show/Hide keep tracking ObjectiveBanner.Visible meanwhile.
function ObjectiveBanner.SetSuppressed(on: boolean)
	if suppressed == on then
		return
	end
	suppressed = on
	local pill = frame
	if pill then
		hiding += 1
		pill.Visible = ObjectiveBanner.Visible and not on
		if pill.Visible then
			Style.PopIn(pill, 0.35)
		end
	end
end

function ObjectiveBanner.IsSuppressed(): boolean
	return suppressed
end

function ObjectiveBanner.Get(): Frame?
	return frame
end

return ObjectiveBanner
