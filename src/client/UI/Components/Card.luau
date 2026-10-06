--!strict
-- Card — rounded tile with a chunky dark base and outline. Default colour is the lighter
-- navy used for inner cards on the ocean-navy panel bodies (docs/UI_STYLE.md); optional
-- gradient (e.g. rarity colours). SetHighlight(Gold) = selected/current (3-4 px gold outline).
local Style = require(script.Parent.Style)

local Card = {}

local SHADOW = 4

export type CardProps = {
	Name: string?,
	Parent: Instance?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	Gradient: { Color3 }?,
	GradientRotation: number?,
	StrokeColor: Color3?,
	LayoutOrder: number?,
	Corner: UDim?,
	ZIndex: number?,
}

export type Card = {
	Holder: Frame,
	Face: Frame,
	Shadow: Frame,
	Stroke: UIStroke,
	Gradient: UIGradient?,
	SetColor: (self: Card, color: Color3, gradient: { Color3 }?) -> (),
	SetHighlight: (self: Card, color: Color3?) -> (),
}

function Card.new(props: CardProps): Card
	local color = props.Color or Style.Colors.NavyCard
	local corner = props.Corner or Style.Theme.CornerMedium
	local z = props.ZIndex or 1

	local holder = Instance.new("Frame")
	holder.Name = props.Name or "Card"
	holder.BackgroundTransparency = 1
	holder.Size = props.Size or UDim2.fromOffset(150, 200)
	holder.Position = props.Position or UDim2.new()
	holder.AnchorPoint = props.AnchorPoint or Vector2.zero
	holder.LayoutOrder = props.LayoutOrder or 0
	holder.ZIndex = z

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 0, 1, -SHADOW)
	shadow.Position = UDim2.fromOffset(0, SHADOW)
	shadow.BackgroundColor3 = Style.Colors.Stroke
	shadow.BackgroundTransparency = 0.2
	shadow.BorderSizePixel = 0
	shadow.ZIndex = z
	shadow.Parent = holder
	Style.Corner(shadow, corner)

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 1, -SHADOW)
	face.BackgroundColor3 = color
	face.BorderSizePixel = 0
	face.ZIndex = z + 1
	face.Parent = holder
	Style.Corner(face, corner)
	local stroke = Style.Stroke(face, props.StrokeColor or Style.Colors.Stroke, 3)

	local gradient: UIGradient? = nil
	if props.Gradient then
		face.BackgroundColor3 = Color3.new(1, 1, 1)
		gradient = Style.Gradient(face, props.Gradient, props.GradientRotation or 90)
	end

	local card: Card
	card = {
		Holder = holder,
		Face = face,
		Shadow = shadow,
		Stroke = stroke,
		Gradient = gradient,
		SetColor = function(self: Card, newColor: Color3, newGradient: { Color3 }?)
			if newGradient then
				face.BackgroundColor3 = Color3.new(1, 1, 1)
				if not self.Gradient then
					self.Gradient = Style.Gradient(face, newGradient, props.GradientRotation or 90)
				else
					(self.Gradient :: UIGradient).Color = Style.Sequence(newGradient)
				end
			else
				face.BackgroundColor3 = newColor
				if self.Gradient then
					(self.Gradient :: UIGradient):Destroy()
					self.Gradient = nil
				end
			end
		end,
		SetHighlight = function(self: Card, highlight: Color3?)
			self.Stroke.Color = highlight or props.StrokeColor or Style.Colors.Stroke
			self.Stroke.Thickness = if highlight then 4 else 3
		end,
	}

	if props.Parent then
		holder.Parent = props.Parent
	end
	return card
end

return Card
