--!strict
-- IconLabel — HUD stat pill: coloured emoji badge on the left + big number on a dark pill.
-- SetValue animates the number counting up/down with a pop for that "numbers go up" feel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Style = require(script.Parent.Style)
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))

local IconLabel = {}

export type IconLabelProps = {
	Name: string?,
	Parent: Instance?,
	Icon: string,
	Text: string?,
	Color: Color3?, -- badge colour
	TextColor: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	MaxTextSize: number?,
}

export type IconLabel = {
	Frame: Frame,
	Badge: Frame,
	Icon: TextLabel,
	Label: TextLabel,
	Value: number,
	SetText: (self: IconLabel, text: string, pop: boolean?) -> (),
	SetValue: (self: IconLabel, value: number, formatter: ((number) -> string)?) -> (),
}

function IconLabel.new(props: IconLabelProps): IconLabel
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "IconLabel"
	frame.Size = props.Size or UDim2.fromOffset(200, 44)
	frame.Position = props.Position or UDim2.new()
	frame.AnchorPoint = props.AnchorPoint or Vector2.zero
	frame.LayoutOrder = props.LayoutOrder or 0
	frame.BackgroundColor3 = Style.Colors.Stroke
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	Style.Corner(frame, Style.Theme.CornerPill)
	Style.Stroke(frame, Style.Colors.Stroke, 3)

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.Size = UDim2.new(1, 8, 1, 8)
	badge.Position = UDim2.new(0, -6, 0.5, 0)
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.BackgroundColor3 = props.Color or Style.Colors.Gold
	badge.BorderSizePixel = 0
	badge.ZIndex = 2
	badge.Parent = frame
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.DominantAxis = Enum.DominantAxis.Height
	ratio.Parent = badge
	Style.Corner(badge, Style.Theme.CornerPill)
	Style.Stroke(badge, Style.Colors.Stroke, 3)
	Style.Shine(badge)

	local icon = Style.Label({
		Name = "Icon",
		Text = props.Icon,
		Size = UDim2.fromScale(0.78, 0.78),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		MaxTextSize = 40,
		Stroke = false,
		ZIndex = 3,
		Parent = badge,
	})

	local label = Style.Label({
		Name = "Value",
		Text = props.Text or "0",
		Size = UDim2.new(1, -56, 0.76, 0),
		Position = UDim2.new(0, 48, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Font = Style.Fonts.Number,
		TextColor = props.TextColor,
		MaxTextSize = props.MaxTextSize or 28,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = frame,
	})

	local counting: RBXScriptConnection? = nil

	local iconLabel: IconLabel
	iconLabel = {
		Frame = frame,
		Badge = badge,
		Icon = icon,
		Label = label,
		Value = 0,
		SetText = function(_: IconLabel, text: string, pop: boolean?)
			label.Text = text
			if pop then
				Style.Pop(badge, 0.25)
			end
		end,
		SetValue = function(self: IconLabel, value: number, formatter: ((number) -> string)?)
			local fmt = formatter or Format.Abbreviate
			local from = self.Value
			self.Value = value
			if counting then
				counting:Disconnect()
				counting = nil
			end
			if from == value then
				label.Text = fmt(value)
				return
			end
			if value > from then
				Style.Pop(badge, 0.3)
			end
			local start = os.clock()
			local duration = 0.45
			counting = RunService.Heartbeat:Connect(function()
				local t = math.min((os.clock() - start) / duration, 1)
				local eased = 1 - (1 - t) ^ 3
				label.Text = fmt(from + (value - from) * eased)
				if t >= 1 and counting then
					counting:Disconnect()
					counting = nil
				end
			end)
		end,
	}

	if props.Parent then
		frame.Parent = props.Parent
	end
	return iconLabel
end

return IconLabel
