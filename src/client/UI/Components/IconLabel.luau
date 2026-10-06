--!strict
-- IconLabel — HUD currency pill: big atlas icon overlapping the left end of a dark navy pill
-- with a big outlined number (coloured by meaning: green coins, mint tokens).
-- SetValue animates the number counting up/down with a pop for that "numbers go up" feel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Style = require(script.Parent.Style)
local AtlasIcon = require(script.Parent.AtlasIcon)
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))

local IconLabel = {}

export type IconLabelProps = {
	Name: string?,
	Parent: Instance?,
	Icon: string,
	Text: string?,
	Color: Color3?, -- glow behind the icon
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
	Icon: AtlasIcon.AtlasIcon,
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
	Style.Pill(frame, 0.12)

	-- Big icon overlapping the pill's left end (docs/UI_STYLE.md currency counters).
	local height = if frame.Size.Y.Offset > 0 then frame.Size.Y.Offset else 44
	local iconSize = height + 16
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.BackgroundTransparency = 1
	badge.Size = UDim2.fromOffset(iconSize, iconSize)
	badge.Position = UDim2.new(0, -iconSize * 0.3, 0.5, 0)
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.ZIndex = 3
	badge.Parent = frame
	if props.Color then
		-- soft coloured glow behind the icon
		local glow = Instance.new("Frame")
		glow.Name = "Glow"
		glow.Size = UDim2.fromScale(0.72, 0.72)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.BackgroundColor3 = props.Color
		glow.BackgroundTransparency = 0.55
		glow.ZIndex = 3
		glow.Parent = badge
		Style.Corner(glow, Style.Theme.CornerPill)
	end
	local icon = AtlasIcon.new({ Icon = props.Icon, ZIndex = 4, Parent = badge })

	local textLeft = iconSize * 0.7 + 6
	local label = Style.Label({
		Name = "Value",
		Text = props.Text or "0",
		Size = UDim2.new(1, -(textLeft + 12), 0.86, 0),
		Position = UDim2.new(0, textLeft, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Font = Style.Fonts.Title,
		TextColor = props.TextColor,
		StrokeThickness = 3,
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
