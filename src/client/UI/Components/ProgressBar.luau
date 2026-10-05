--!strict
-- ProgressBar — pill-shaped bar with shiny fill and centred caption. Set(alpha, text).
local Style = require(script.Parent.Style)

local ProgressBar = {}

export type ProgressBarProps = {
	Name: string?,
	Parent: Instance?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	BackColor: Color3?,
	Text: string?,
	LayoutOrder: number?,
	MaxTextSize: number?,
	Vertical: boolean?, -- fills bottom -> top
	ZIndex: number?,
}

export type ProgressBar = {
	Frame: Frame,
	Fill: Frame,
	Label: TextLabel,
	Stroke: UIStroke,
	Alpha: number,
	Set: (self: ProgressBar, alpha: number, text: string?, instant: boolean?) -> (),
	SetColor: (self: ProgressBar, color: Color3) -> (),
}

function ProgressBar.new(props: ProgressBarProps): ProgressBar
	local z = props.ZIndex or 1
	local vertical = props.Vertical == true

	local frame = Instance.new("Frame")
	frame.Name = props.Name or "ProgressBar"
	frame.Size = props.Size or UDim2.fromOffset(240, 32)
	frame.Position = props.Position or UDim2.new()
	frame.AnchorPoint = props.AnchorPoint or Vector2.zero
	frame.BackgroundColor3 = props.BackColor or Style.Darken(Style.Colors.Stroke, 0.1)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.LayoutOrder = props.LayoutOrder or 0
	frame.ZIndex = z
	frame.ClipsDescendants = false
	Style.Corner(frame, Style.Theme.CornerPill)
	local stroke = Style.Stroke(frame, Style.Colors.Stroke, 3)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = props.Color or Style.Colors.Palm
	fill.ZIndex = z + 1
	if vertical then
		fill.AnchorPoint = Vector2.new(0, 1)
		fill.Position = UDim2.fromScale(0, 1)
		fill.Size = UDim2.fromScale(1, 0)
	else
		fill.Size = UDim2.fromScale(0, 1)
	end
	fill.Parent = frame
	Style.Corner(fill, Style.Theme.CornerPill)
	Style.Gradient(
		fill,
		{ Color3.new(1, 1, 1), Color3.fromRGB(225, 225, 225), Color3.fromRGB(190, 190, 190) },
		if vertical then 0 else 90
	)

	local label = Style.Label({
		Name = "Caption",
		Text = props.Text or "",
		Size = UDim2.new(1, -12, 0.8, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		MaxTextSize = props.MaxTextSize or 22,
		Font = Style.Fonts.Number,
		ZIndex = z + 2,
		Parent = frame,
	})

	local bar: ProgressBar
	bar = {
		Frame = frame,
		Fill = fill,
		Label = label,
		Stroke = stroke,
		Alpha = 0,
		Set = function(self: ProgressBar, alpha: number, text: string?, instant: boolean?)
			alpha = math.clamp(if alpha ~= alpha then 0 else alpha, 0, 1)
			self.Alpha = alpha
			local visible = alpha > 0.001
			local target = if vertical then UDim2.new(1, 0, alpha, 0) else UDim2.new(alpha, 0, 1, 0)
			fill.Visible = visible
			if instant then
				fill.Size = target
			else
				Style.Tween(fill, 0.25, { Size = target }, Enum.EasingStyle.Quad)
			end
			if text then
				label.Text = text
			end
		end,
		SetColor = function(_: ProgressBar, color: Color3)
			fill.BackgroundColor3 = color
		end,
	}

	if props.Parent then
		frame.Parent = props.Parent
	end
	return bar
end

return ProgressBar
