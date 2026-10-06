--!strict
--[[
	UpgradeRow — one shop item as an upgrade row (docs/UI_STYLE.md "Shop"):
	  [model] Name / tag
	          [ current stat ]  ➜  [ next stat (orange) ]            [ big price button ]
	e.g. "Dig 4×4 ➜ Dig 8×8", "Holds 50 ➜ Holds 120", "Shade 6 ➜ Shade 8 studs". The panel
	drives the state through row.Button (green affordable / grey not / Equip / Equipped) and
	SetStats / SetTag / SetLocked. Extra buttons (e.g. "Pick Up") go into row.Actions.

		local row = UpgradeRow.new({ Name = id, Title = def.Name, Model = model, Parent = list,
			OnClick = function() ... end })
		row:SetStats({ Main = "Dig 4×4", Sub = "Wet Sand" }, { Main = "Dig 8×8", Sub = "Shell Bed" })
]]
local Style = require(script.Parent.Style)
local Button = require(script.Parent.Button)
local Card = require(script.Parent.Card)
local Viewport = require(script.Parent.Viewport)
local AtlasIcon = require(script.Parent.AtlasIcon)

local UpgradeRow = {}

UpgradeRow.HEIGHT = 108
local STAGE = 88
local BOX = Vector2.new(162, 56)
local ARROW = 34
local ACTION_W = 190

export type Stat = { Main: string, Sub: string? }

export type Props = {
	Name: string,
	Title: string,
	Parent: Instance?,
	LayoutOrder: number?,
	Model: Model?,
	Yaw: number?,
	Pitch: number?,
	Fill: number?,
	Rotation: CFrame?,
	StageColors: { Color3 }?,
	ActionWidth: number?,
	OnClick: (() -> ())?,
}

export type UpgradeRow = {
	Card: Card.Card,
	Button: Button.Button,
	Actions: Frame,
	Title: TextLabel,
	SetStats: (self: UpgradeRow, current: Stat?, nextStat: Stat) -> (),
	SetTag: (self: UpgradeRow, text: string?, color: Color3?) -> (),
	SetLocked: (self: UpgradeRow, locked: boolean) -> (),
}

local function statBox(
	parent: Instance,
	name: string,
	x: number,
	color: Color3,
	stroke: Color3
): (Frame, TextLabel, TextLabel)
	local box = Instance.new("Frame")
	box.Name = name
	box.Size = UDim2.fromOffset(BOX.X, BOX.Y)
	box.Position = UDim2.fromOffset(x, 42)
	box.BackgroundColor3 = color
	box.ZIndex = 4
	box.Parent = parent
	Style.Corner(box, Style.Theme.CornerSmall)
	Style.Stroke(box, stroke, 3)
	local main = Style.Label({
		Name = "Main",
		Text = "",
		Size = UDim2.new(1, -10, 0.56, 0),
		Position = UDim2.new(0.5, 0, 0, 3),
		AnchorPoint = Vector2.new(0.5, 0),
		MaxTextSize = 22,
		StrokeThickness = 2,
		ZIndex = 5,
		Parent = box,
	})
	local sub = Style.Label({
		Name = "Sub",
		Text = "",
		Size = UDim2.new(1, -10, 0.36, 0),
		Position = UDim2.new(0.5, 0, 1, -3),
		AnchorPoint = Vector2.new(0.5, 1),
		Font = Style.Fonts.Body,
		MaxTextSize = 13,
		StrokeThickness = 1.5,
		ZIndex = 5,
		Parent = box,
	})
	return box, main, sub
end

function UpgradeRow.new(props: Props): UpgradeRow
	local C = Style.Colors
	local card = Card.new({
		Name = props.Name,
		Size = UDim2.new(1, -14, 0, UpgradeRow.HEIGHT),
		LayoutOrder = props.LayoutOrder,
		ZIndex = 2,
		Parent = props.Parent,
	})
	local face = card.Face

	local stage = Instance.new("Frame")
	stage.Name = "Preview"
	stage.Size = UDim2.fromOffset(STAGE, STAGE)
	stage.Position = UDim2.new(0, 8, 0.5, -2)
	stage.AnchorPoint = Vector2.new(0, 0.5)
	stage.BackgroundColor3 = Color3.new(1, 1, 1)
	stage.ZIndex = 3
	stage.Parent = face
	Style.Corner(stage, Style.Theme.CornerMedium)
	Style.Stroke(stage, C.Stroke, 3)
	Style.Gradient(stage, props.StageColors or { C.Sky, C.Ocean }, 90)
	if props.Model then
		local view = Viewport.new({
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			Pitch = props.Pitch,
			Yaw = props.Yaw,
			Fill = props.Fill,
			Rotation = props.Rotation,
			Parent = stage,
		})
		view:SetModel(props.Model)
	end
	local lock = AtlasIcon.new({
		Name = "Lock",
		Icon = "Lock",
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, 6, 1, 6),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 6,
		Parent = stage,
	})
	lock.Frame.Visible = false

	local left = STAGE + 20
	local title = Style.Label({
		Name = "ItemName",
		Text = props.Title,
		Size = UDim2.new(0, BOX.X * 2 + ARROW - 90, 0, 30),
		Position = UDim2.fromOffset(left, 7),
		MaxTextSize = 24,
		StrokeThickness = 2.5,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = face,
	})
	local tag = Style.Label({
		Name = "Tag",
		Text = "",
		Size = UDim2.fromOffset(96, 24),
		Position = UDim2.fromOffset(left + BOX.X * 2 + ARROW - 96, 9),
		MaxTextSize = 15,
		StrokeThickness = 2,
		ZIndex = 5,
		Parent = face,
	})
	tag.BackgroundTransparency = 0
	tag.BackgroundColor3 = C.Coral
	tag.Visible = false
	Style.Corner(tag, Style.Theme.CornerPill)
	Style.Stroke(tag, C.Stroke, 2)

	local currentBox, currentMain, currentSub = statBox(face, "Current", left, C.NavyDark, C.Stroke)
	local arrow = AtlasIcon.new({
		Name = "Arrow",
		Icon = "arrow_right|➜",
		Size = UDim2.fromOffset(ARROW, ARROW),
		Position = UDim2.fromOffset(left + BOX.X + ARROW / 2, 42 + BOX.Y / 2),
		ZIndex = 5,
		Parent = face,
	})
	local nextBox, nextMain, nextSub =
		statBox(face, "Next", left + BOX.X + ARROW, C.Highlight, Style.Darken(C.Highlight, 0.55))
	Style.Gloss(nextBox, Style.Theme.CornerSmall, 4)

	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.BackgroundTransparency = 1
	actions.Size = UDim2.new(0, props.ActionWidth or ACTION_W, 0, 80)
	actions.Position = UDim2.new(1, -10, 0.5, 0)
	actions.AnchorPoint = Vector2.new(1, 0.5)
	actions.ZIndex = 4
	actions.Parent = face
	Style.List(actions, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local button = Button.new({
		Name = "Action",
		Text = "Buy",
		Icon = "Coins",
		Size = UDim2.new(1, 0, 0, 80),
		Color = C.Success,
		MaxTextSize = 26,
		LayoutOrder = 10,
		ZIndex = 5,
		Parent = actions,
		OnClick = props.OnClick,
	})

	local row: UpgradeRow
	row = {
		Card = card,
		Button = button,
		Actions = actions,
		Title = title,
		SetStats = function(_: UpgradeRow, current: Stat?, nextStat: Stat)
			currentBox.Visible = current ~= nil
			arrow.Frame.Visible = current ~= nil
			if current then
				currentMain.Text = current.Main
				currentSub.Text = current.Sub or ""
				nextBox.Position = UDim2.fromOffset(left + BOX.X + ARROW, 42)
			else
				nextBox.Position = UDim2.fromOffset(left, 42)
			end
			nextMain.Text = nextStat.Main
			nextSub.Text = nextStat.Sub or ""
		end,
		SetTag = function(_: UpgradeRow, text: string?, color: Color3?)
			local was = tag.Visible
			tag.Visible = text ~= nil
			tag.Text = text or ""
			tag.BackgroundColor3 = color or C.Coral
			if text and not was then
				Style.PopIn(tag)
			end
		end,
		SetLocked = function(_: UpgradeRow, locked: boolean)
			lock.Frame.Visible = locked
			face.BackgroundColor3 = if locked then C.NavyCardDark else C.NavyCard
			nextBox.BackgroundColor3 = if locked then Style.Darken(C.Highlight, 0.45) else C.Highlight
		end,
	}
	return row
end

return UpgradeRow
