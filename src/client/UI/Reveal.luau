--!strict
--[[
	Reveal — the one "you got something!" popup (docs/UI_STYLE.md) for egg/crate hatches
	(HatchAnimation), treasure finds (TreasurePopup) and new shovels (ShopPanel):
	  - the rarity word in huge outlined letters in the rarity colour ("LEGENDARY!") at the top,
	    popping in with a wobble, over a slowly spinning sparkle burst
	  - a dark navy card per item: name in big outlined text, the 3D model in a viewport on the
	    left (single item) or on top (several items side by side), stat rows on the right
	    (RARITY, SAND BONUS, DIGS <layer>, RIDEABLE ...), optional "NEW!" tag
	  - twinkling sparkles; tap anywhere to close (auto-closes after Hold seconds)
	Compact = true is the non-blocking variant for frequent finds (common treasures): smaller,
	no dim, never eats taps meant for digging (only the card itself closes it).
	Reveals queue, so rapid finds never overlap.

		Reveal.Show({ Headline = "EPIC!", Color = rarity.Color, Items = { {
			Name = "Golden Crab", Model = ModelFactory.Pet(id),
			Rows = { { Label = "RARITY", Value = "Epic", Color = rarity.Color } } } } })
]]
local Root = require(script.Parent.Root)
local Style = require(script.Parent.Components.Style)
local AtlasIcon = require(script.Parent.Components.AtlasIcon)
local Viewport = require(script.Parent.Components.Viewport)
local UIEffects = require(script.Parent.UIEffects)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local Signal = require(script.Parent.Parent.Util.Signal)

local Reveal = {}

export type Row = { Label: string, Value: string, Color: Color3? }

export type Item = {
	Name: string,
	Model: Model?,
	Yaw: number?,
	Pitch: number?,
	Rotation: CFrame?,
	Rows: { Row },
	Tag: string?, -- "NEW!"
	NameColor: Color3?,
}

export type Spec = {
	Headline: string,
	Color: Color3,
	Gradient: { Color3 }?,
	Caption: string?, -- small line under the headline ("YOU HATCHED", "NEW SHOVEL")
	Items: { Item },
	Compact: boolean?,
	Hold: number?,
	Sound: string?, -- "" = silent
	Confetti: boolean?,
	Flash: boolean?,
	OnClosed: (() -> ())?,
}

Reveal.Closed = Signal.new()

local C = Style.Colors
local queue: { Spec } = {}
local showing = false

local SINGLE = Vector2.new(540, 230)
local MULTI = Vector2.new(220, 300)

local function starburst(parent: Instance, color: Color3, z: number): Frame
	local burst = Instance.new("Frame")
	burst.Name = "Burst"
	burst.BackgroundTransparency = 1
	burst.AnchorPoint = Vector2.new(0.5, 0.5)
	burst.Position = UDim2.fromScale(0.5, 0.5)
	burst.Size = UDim2.fromOffset(0, 0)
	burst.ZIndex = z
	burst.Parent = parent
	for i = 0, 7 do
		local ray = Instance.new("Frame")
		ray.Name = "Ray"
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.new(1, 0, 0.1, 0)
		ray.Rotation = i * 22.5
		ray.BackgroundColor3 = color
		ray.BorderSizePixel = 0
		ray.ZIndex = z
		ray.Parent = burst
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = ray
	end
	Style.Tween(burst, 8, { Rotation = 360 }, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
	return burst
end

local function sparkles(parent: Frame, z: number)
	local spots = {
		Vector2.new(-0.04, 0.1),
		Vector2.new(1.03, 0.2),
		Vector2.new(0.08, 0.95),
		Vector2.new(0.95, 0.9),
		Vector2.new(0.5, -0.06),
		Vector2.new(-0.06, 0.55),
		Vector2.new(1.06, 0.6),
	}
	for i, spot in spots do
		local star = AtlasIcon.new({
			Name = "Sparkle",
			Icon = "Star",
			Size = UDim2.fromOffset(26 + (i % 3) * 8, 26 + (i % 3) * 8),
			Position = UDim2.fromScale(spot.X, spot.Y),
			ZIndex = z,
			Parent = parent,
		})
		local scale = Style.GetPopScale(star.Frame)
		scale.Scale = 0.2
		task.delay(0.08 * i, function()
			if star.Frame.Parent then
				Style.Tween(
					scale,
					0.5 + (i % 3) * 0.12,
					{ Scale = 1.1 },
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut,
					-1,
					true
				)
				Style.Tween(star.Frame, 3, { Rotation = if i % 2 == 0 then 180 else -180 }, Enum.EasingStyle.Linear)
			end
		end)
	end
end

local function statRows(parent: Frame, rows: { Row }, rowHeight: number, maxText: number, z: number)
	local list = Instance.new("Frame")
	list.Name = "Stats"
	list.BackgroundTransparency = 1
	list.Size = UDim2.fromScale(1, 1)
	list.ZIndex = z
	list.Parent = parent
	Style.List(list, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center)
	for i, row in rows do
		local line = Instance.new("Frame")
		line.Name = row.Label
		line.Size = UDim2.new(1, 0, 0, rowHeight)
		line.BackgroundColor3 = C.NavyCard
		line.BackgroundTransparency = 0.15
		line.LayoutOrder = i
		line.ZIndex = z
		line.Parent = list
		Style.Corner(line, Style.Theme.CornerSmall)
		Style.Stroke(line, C.Stroke, 2)
		Style.Label({
			Name = "Key",
			Text = row.Label,
			Size = UDim2.new(0.46, -8, 0.7, 0),
			Position = UDim2.new(0, 8, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			TextColor = C.Sky,
			MaxTextSize = maxText - 3,
			XAlign = Enum.TextXAlignment.Left,
			ZIndex = z + 1,
			Parent = line,
		})
		Style.Label({
			Name = "Value",
			Text = row.Value,
			Size = UDim2.new(0.54, -8, 0.78, 0),
			Position = UDim2.new(1, -8, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			TextColor = row.Color or C.Text,
			MaxTextSize = maxText,
			XAlign = Enum.TextXAlignment.Right,
			ZIndex = z + 1,
			Parent = line,
		})
	end
end

local function card(parent: Instance, item: Item, spec: Spec, single: boolean, z: number): Frame
	local size = if single then SINGLE else MULTI
	local holder = Instance.new("Frame")
	holder.Name = "Card"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size.X, size.Y)
	holder.ZIndex = z
	holder.Parent = parent

	local lip = Instance.new("Frame")
	lip.Name = "Shadow"
	lip.Size = UDim2.new(1, 0, 1, -6)
	lip.Position = UDim2.fromOffset(0, 6)
	lip.BackgroundColor3 = C.Stroke
	lip.ZIndex = z
	lip.Parent = holder
	Style.Corner(lip, Style.Theme.CornerLarge)

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 1, -6)
	face.ZIndex = z + 1
	face.Parent = holder
	Style.Corner(face, Style.Theme.CornerLarge)
	Style.Stroke(face, C.Stroke, 4)
	Style.NavyBody(face)
	-- rarity accent ring just inside the outline
	local ring = Instance.new("Frame")
	ring.Name = "Accent"
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.new(1, -8, 1, -8)
	ring.Position = UDim2.fromOffset(4, 4)
	ring.ZIndex = z + 1
	ring.Parent = face
	Style.Corner(ring, Style.Theme.CornerMedium)
	Style.Stroke(ring, spec.Color, 3)

	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.ZIndex = z + 2
	stage.Parent = face
	if single then
		stage.Size = UDim2.new(0, size.Y - 30, 1, -22)
		stage.Position = UDim2.fromOffset(12, 11)
	else
		stage.Size = UDim2.new(1, -20, 0, 120)
		stage.Position = UDim2.fromOffset(10, 10)
	end
	Style.Corner(stage, Style.Theme.CornerMedium)
	Style.Stroke(stage, C.Stroke, 3)
	stage.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.Gradient(stage, spec.Gradient or { Style.Lighten(spec.Color, 0.45), Style.Darken(spec.Color, 0.25) }, 90)
	local view = Viewport.new({
		Name = "Model",
		Size = UDim2.fromScale(1, 1),
		Spin = true,
		SpinSpeed = 1.4,
		Pitch = item.Pitch or 12,
		Yaw = item.Yaw,
		Rotation = item.Rotation,
		ZIndex = z + 3,
		Parent = stage,
	})
	if item.Model then
		view:SetModel(item.Model)
		local scale = Style.GetPopScale(view.Frame)
		scale.Scale = 0
		Style.Tween(scale, 0.7, { Scale = 1 }, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
	end

	local right = Instance.new("Frame")
	right.Name = "Info"
	right.BackgroundTransparency = 1
	right.ZIndex = z + 2
	right.Parent = face
	if single then
		right.Size = UDim2.new(1, -(size.Y - 30) - 36, 1, -22)
		right.Position = UDim2.fromOffset(size.Y - 30 + 24, 11)
	else
		right.Size = UDim2.new(1, -20, 1, -140)
		right.Position = UDim2.fromOffset(10, 134)
	end
	local nameHeight = if single then 46 else 34
	Style.Label({
		Name = "ItemName",
		Text = item.Name,
		Size = UDim2.new(1, 0, 0, nameHeight),
		TextColor = item.NameColor or C.Text,
		MaxTextSize = if single then 40 else 26,
		StrokeThickness = 3,
		XAlign = if single then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		ZIndex = z + 3,
		Parent = right,
	})
	local rowsFrame = Instance.new("Frame")
	rowsFrame.Name = "Rows"
	rowsFrame.BackgroundTransparency = 1
	rowsFrame.Size = UDim2.new(1, 0, 1, -nameHeight - 6)
	rowsFrame.Position = UDim2.fromOffset(0, nameHeight + 6)
	rowsFrame.ZIndex = z + 2
	rowsFrame.Parent = right
	-- 5+ rows (hatches add a CHANCE row, v2.2 true odds) get slightly shorter rows to fit the card
	local many = #item.Rows > 4
	local rowHeight = if single then (if many then 30 else 32) else (if many then 23 else 26)
	statRows(
		rowsFrame,
		item.Rows,
		rowHeight,
		if single then (if many then 19 else 20) else (if many then 15 else 16),
		z + 3
	)

	if item.Tag then
		local tag = Style.Label({
			Name = "Tag",
			Text = item.Tag,
			Size = UDim2.fromOffset(84, 30),
			Position = UDim2.fromOffset(-10, -12),
			MaxTextSize = 20,
			ZIndex = z + 6,
			Parent = holder,
		})
		tag.Rotation = -8
		tag.BackgroundTransparency = 0
		tag.BackgroundColor3 = C.Coral
		Style.Corner(tag, Style.Theme.CornerPill)
		Style.Stroke(tag, C.Stroke, 3)
	end
	return holder
end

local pump: () -> ()

local function show(spec: Spec)
	showing = true
	local canvas = Root.Get("Popups")
	local compact = spec.Compact == true
	local items = spec.Items
	local single = #items <= 1
	local cardSize = if single then SINGLE else MULTI
	local count = math.max(#items, 1)
	local rowWidth = if single then cardSize.X else count * cardSize.X + (count - 1) * 14

	-- root: the dim overlay (tap anywhere) or, when compact, an invisible container
	local root: GuiObject
	local closeRequested = false
	if compact then
		local frame = Instance.new("Frame")
		frame.Name = "Reveal"
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(1, 1)
		frame.ZIndex = 30
		frame.Parent = canvas
		root = frame
	else
		local overlay = Instance.new("TextButton")
		overlay.Name = "Reveal"
		overlay.Text = ""
		overlay.AutoButtonColor = false
		overlay.Selectable = false
		overlay.BackgroundColor3 = Color3.new(0, 0, 0)
		overlay.BackgroundTransparency = 1
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.ZIndex = 30
		overlay.Parent = canvas
		Style.Tween(overlay, 0.2, { BackgroundTransparency = 0.45 })
		overlay.Activated:Connect(function()
			closeRequested = true
		end)
		root = overlay
	end

	local group = Instance.new("Frame")
	group.Name = "Group"
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = if compact then UDim2.fromScale(0.5, 0.42) else UDim2.fromScale(0.5, 0.52)
	group.Size = UDim2.fromOffset(rowWidth, cardSize.Y + 110)
	group.ZIndex = 31
	group.Parent = root
	local groupScale = Style.GetPopScale(group)
	local fit = 1
	local design = Root.GetDesignSize()
	if design.X > 0 and design.Y > 0 then
		fit = math.min(1, (design.X - 40) / rowWidth, (design.Y - 30) / (cardSize.Y + 110))
	end
	local target = fit * (if compact then 0.62 else 1)
	groupScale.Scale = target * 0.6
	Style.Tween(groupScale, 0.35, { Scale = target }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local burst = starburst(group, spec.Color, 31)
	burst.Position = UDim2.new(0.5, 0, 1, -cardSize.Y / 2)
	Style.Tween(burst, 0.5, { Size = UDim2.fromOffset(rowWidth + 260, rowWidth + 260) }, Enum.EasingStyle.Back)

	-- huge outlined rarity word with pop-in + wobble
	local headline = Style.Label({
		Name = "Headline",
		Text = spec.Headline,
		Size = UDim2.new(1, 120, 0, 84),
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		TextColor = spec.Color,
		MaxTextSize = 80,
		StrokeThickness = 5,
		ZIndex = 40,
		Parent = group,
	})
	if spec.Gradient then
		Style.Gradient(headline, { Style.Lighten(spec.Color, 0.35), spec.Color, Style.Darken(spec.Color, 0.1) }, 90)
	end
	local headScale = Style.GetPopScale(headline)
	headScale.Scale = 0.1
	Style.Tween(headScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
	headline.Rotation = -8
	Style.Tween(headline, 0.18, { Rotation = 6 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 5, true)
	task.delay(1.9, function()
		if headline.Parent then
			Style.Tween(headline, 0.2, { Rotation = -3 }, Enum.EasingStyle.Sine)
		end
	end)
	if spec.Caption then
		Style.Label({
			Name = "Caption",
			Text = spec.Caption,
			Size = UDim2.new(1, 0, 0, 26),
			Position = UDim2.new(0.5, 0, 0, 80),
			AnchorPoint = Vector2.new(0.5, 0),
			MaxTextSize = 22,
			ZIndex = 40,
			Parent = group,
		})
	end

	local row = Instance.new("Frame")
	row.Name = "Cards"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, cardSize.Y)
	row.Position = UDim2.new(0, 0, 1, -cardSize.Y)
	row.ZIndex = 32
	row.Parent = group
	Style.List(row, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center)
	for i, item in items do
		local c = card(row, item, spec, single, 33)
		c.LayoutOrder = i
		local s = Style.GetPopScale(c)
		s.Scale = 0
		task.delay(0.08 * (i - 1), function()
			Style.Tween(s, 0.45, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end)
	end
	sparkles(group, 41)

	if compact then
		-- only the card itself closes a compact reveal (taps elsewhere keep digging)
		local hit = Instance.new("TextButton")
		hit.Name = "Close"
		hit.Text = ""
		hit.BackgroundTransparency = 1
		hit.Selectable = false
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = 45
		hit.Parent = group
		hit.Activated:Connect(function()
			closeRequested = true
		end)
	else
		Style.Label({
			Name = "Hint",
			Text = "Tap to close",
			Size = UDim2.fromOffset(200, 24),
			Position = UDim2.new(0.5, 0, 1, 14),
			AnchorPoint = Vector2.new(0.5, 0),
			TextColor = C.Sky,
			MaxTextSize = 18,
			ZIndex = 40,
			Parent = group,
		})
	end

	if spec.Sound ~= "" then
		SoundController.Play(spec.Sound or "Purchase")
	end
	if spec.Flash then
		UIEffects.Flash(spec.Color, 0.6)
	end
	if spec.Confetti then
		UIEffects.Confetti(50, spec.Gradient)
	end

	local hold = spec.Hold or (if compact then 2.4 else 4)
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < hold and not closeRequested and root.Parent do
			task.wait(0.05)
		end
		if root:IsA("TextButton") then
			Style.Tween(root, 0.2, { BackgroundTransparency = 1 })
		end
		local out = Style.Tween(groupScale, 0.22, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		out.Completed:Once(function()
			root:Destroy()
			showing = false
			if spec.OnClosed then
				task.spawn(spec.OnClosed)
			end
			Reveal.Closed:Fire()
			pump()
		end)
	end)
end

pump = function()
	if showing then
		return
	end
	local spec = table.remove(queue, 1)
	if spec then
		show(spec)
	end
end

function Reveal.Show(spec: Spec)
	if #queue >= 6 then
		-- drop the oldest compact reveal first so big moments are never lost
		for i, queued in queue do
			if queued.Compact then
				table.remove(queue, i)
				break
			end
		end
	end
	table.insert(queue, spec)
	pump()
end

function Reveal.IsShowing(): boolean
	return showing
end

return Reveal
