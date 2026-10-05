--!strict
--[[
	BeachShopPanel — Panel "BeachShop" (owner: Survival): shade items and snacks.
	Open with Panel.Open("BeachShop", { Tab = "Shade" | "Snacks" }) (HUD "Beach" button, the
	BeachShop stand's ProximityPrompt, empty quick-slots).

	Shade cards: big Models.Shade preview, radius / cooling stats and one state button:
	  Buy <price> / <price> (can't afford) / 🔒 Rebirth N / Place (owned) — plus Pick Up when
	  that shade is out on the beach. Buying starts placement right away.
	Snack cards: big Models.Consumable preview, cooling + boost, "You have N", Buy 1 / Buy 5.
	Water is free at the fountain (card explains, no buy button).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local Models = require(Shared:WaitForChild("Models"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local Components = script.Parent.Parent.Components
local Style = require(Components.Style)
local Panel = require(Components.Panel)
local Button = require(Components.Button)
local Card = require(Components.Card)
local Viewport = require(Components.Viewport)
local Icons = require(script.Parent.Parent.Icons)
local UIEffects = require(script.Parent.Parent.UIEffects)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local SoundController = require(script.Parent.Parent.Parent.Controllers.SoundController)
local SurvivalController = require(script.Parent.Parent.Parent.Controllers.SurvivalController)
local PlacementController = require(script.Parent.Parent.Parent.Controllers.PlacementController)

local BeachShopPanel = {}

local C = Style.Colors

local CARD_SIZE = Vector2.new(184, 262)
local PREVIEW_HEIGHT = 132

type Tab = string -- "Shade" | "Snacks"

type ItemCard = {
	Id: string,
	Update: () -> (),
}

local panel: Panel.Panel
local tabs: { [Tab]: Button.Button } = {}
local scrollers: { [Tab]: ScrollingFrame } = {}
local cards: { ItemCard } = {}
local built = false
local currentTab: Tab = "Shade"
local pendingPlace: { [string]: boolean } = {}

local function safeModel(builder: (string) -> Model, id: string): Model?
	local ok, result = pcall(builder, id)
	if ok and typeof(result) == "Instance" and result:IsA("Model") then
		for _, d in result:GetDescendants() do
			if d:IsA("BillboardGui") then
				d:Destroy()
			end
		end
		return result
	end
	return nil
end

local function preview(face: Frame, colors: { Color3 }, model: Model?, pitch: number, distance: number)
	local frame = Instance.new("Frame")
	frame.Name = "Preview"
	frame.Size = UDim2.new(1, -12, 0, PREVIEW_HEIGHT)
	frame.Position = UDim2.fromOffset(6, 6)
	frame.BackgroundColor3 = colors[1]
	frame.ZIndex = 3
	frame.Parent = face
	Style.Corner(frame, Style.Theme.CornerSmall)
	Style.Gradient(frame, colors, 90)
	if model then
		-- Fill the frame: the viewport is the whole preview, the camera hugs the bounding box.
		local vp = Viewport.new({
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			Pitch = pitch,
			Distance = distance,
			Parent = frame,
		})
		vp:SetModel(model)
	end
end

local function nameLabel(face: Frame, text: string)
	Style.Label({
		Name = "ItemName",
		Text = text,
		Size = UDim2.new(1, -12, 0, 24),
		Position = UDim2.fromOffset(6, PREVIEW_HEIGHT + 8),
		TextColor = C.TextDark,
		Stroke = false,
		MaxTextSize = 19,
		ZIndex = 3,
		Parent = face,
	})
end

local function statsLabel(face: Frame): TextLabel
	return Style.Label({
		Name = "Stats",
		Text = "",
		Size = UDim2.new(1, -12, 0, 44),
		Position = UDim2.fromOffset(6, PREVIEW_HEIGHT + 32),
		TextColor = C.TextDark,
		Stroke = false,
		Font = Style.Fonts.Body,
		MaxTextSize = 13,
		Wrapped = true,
		RichText = true,
		ZIndex = 3,
		Parent = face,
	})
end

-- Shade cards ---------------------------------------------------------------------------------------

local function isPlaced(shadeId: string): boolean
	return SurvivalController.IsShadePlaced(shadeId)
end

local function makeShadeCard(def: Types.ShadeDef, order: number, parent: Instance): ItemCard
	local card = Card.new({ Name = def.Id, LayoutOrder = order, Color = C.PanelAlt, Parent = parent })
	local face = card.Face
	preview(face, { C.Sky, Style.Lighten(C.Sand, 0.1) }, safeModel(Models.Shade, def.Id), 14, 0.82)
	nameLabel(face, def.Name)
	local stats = statsLabel(face)
	stats.Text = string.format(
		"⛱️ Shade size <b>%d</b>   ❄️ Cools <b>x%s</b>\n%s",
		def.Radius,
		Format.Abbreviate(def.Cooling),
		def.Description
	)
	local rebirths = def.RebirthsRequired or 0

	local main = Button.new({
		Name = "Action",
		Text = "Buy",
		Size = UDim2.new(1, -14, 0, 42),
		Position = UDim2.new(0.5, 0, 1, -6),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Success,
		MaxTextSize = 19,
		ZIndex = 4,
		Parent = face,
		OnClick = function()
			local owned = (State.Data.OwnedShades or ({} :: { [string]: boolean }))[def.Id] == true
			if owned then
				panel:Close()
				PlacementController.Begin(def.Id)
			else
				pendingPlace[def.Id] = true
				Remotes.Get("BuyShade"):FireServer(def.Id)
			end
		end,
	})
	local pickUp = Button.new({
		Name = "PickUp",
		Text = "Pick Up",
		Size = UDim2.new(0.5, -10, 0, 42),
		Position = UDim2.new(1, -6, 1, -6),
		AnchorPoint = Vector2.new(1, 1),
		Color = C.Coral,
		MaxTextSize = 17,
		ZIndex = 4,
		Parent = face,
		OnClick = function()
			Remotes.Get("PickUpShade"):FireServer(def.Id)
		end,
	})

	return {
		Id = def.Id,
		Update = function()
			local data = State.Data
			local owned = (data.OwnedShades or ({} :: { [string]: boolean }))[def.Id] == true
			local placed = owned and isPlaced(def.Id)
			pickUp:SetVisible(placed)
			main.Holder.Size = if placed then UDim2.new(0.5, -10, 0, 42) else UDim2.new(1, -14, 0, 42)
			main.Holder.Position = if placed then UDim2.new(0, 6, 1, -6) else UDim2.new(0.5, 0, 1, -6)
			main.Holder.AnchorPoint = if placed then Vector2.new(0, 1) else Vector2.new(0.5, 1)
			if owned then
				main:SetEnabled(true)
				main:SetColor(C.Ocean)
				main:SetText(if placed then "Move" else "⛱️ Place")
			elseif data.Rebirths < rebirths then
				main:SetEnabled(false)
				main:SetText(Icons.Lock .. " Rebirth " .. rebirths)
			elseif data.Coins < def.Price then
				main:SetEnabled(false)
				main:SetText(Icons.Coins .. " " .. Format.Abbreviate(def.Price))
			else
				main:SetEnabled(true)
				main:SetColor(C.Success)
				main:SetText("Buy " .. Icons.Coins .. " " .. Format.Abbreviate(def.Price))
			end
			card:SetHighlight(if placed then C.Palm elseif owned then C.Ocean else nil)
		end,
	}
end

-- Snack cards ---------------------------------------------------------------------------------------

local function makeSnackCard(def: Types.ConsumableDef, order: number, parent: Instance): ItemCard
	local card = Card.new({ Name = def.Id, LayoutOrder = order, Color = C.PanelAlt, Parent = parent })
	local face = card.Face
	preview(face, { Style.Lighten(C.Ocean, 0.35), C.Sky }, safeModel(Models.Consumable, def.Id), 18, 0.78)
	nameLabel(face, def.Icon .. " " .. def.Name)
	local stats = statsLabel(face)
	local boost = if def.Boost then Config.GetBoost(def.Boost) else nil
	local boostText = if boost and def.BoostSeconds
		then string.format("\n⚡ %s %ds", boost.Name, def.BoostSeconds)
		else "\n" .. def.Description
	local isFree = def.Price <= 0

	local have: TextLabel = Style.Label({
		Name = "Have",
		Text = "",
		Size = UDim2.fromOffset(70, 24),
		Position = UDim2.fromOffset(10, 10),
		MaxTextSize = 16,
		ZIndex = 6,
		Parent = face,
	})
	have.BackgroundTransparency = 0
	have.BackgroundColor3 = C.Stroke
	Style.Corner(have, Style.Theme.CornerPill)

	local buyOne: Button.Button? = nil
	local buyFive: Button.Button? = nil
	if isFree then
		local info = Button.new({
			Name = "Free",
			Text = "💧 At the fountain",
			Size = UDim2.new(1, -14, 0, 42),
			Position = UDim2.new(0.5, 0, 1, -6),
			AnchorPoint = Vector2.new(0.5, 1),
			Color = C.Ocean,
			MaxTextSize = 16,
			ZIndex = 4,
			Parent = face,
		})
		info:SetEnabled(false)
	else
		buyOne = Button.new({
			Name = "Buy1",
			Text = "Buy",
			Size = UDim2.new(0.55, -9, 0, 42),
			Position = UDim2.new(0, 6, 1, -6),
			AnchorPoint = Vector2.new(0, 1),
			Color = C.Success,
			MaxTextSize = 17,
			ZIndex = 4,
			Parent = face,
			OnClick = function()
				Remotes.Get("BuyConsumable"):FireServer(def.Id, 1)
			end,
		})
		buyFive = Button.new({
			Name = "Buy5",
			Text = "x5",
			Size = UDim2.new(0.45, -9, 0, 42),
			Position = UDim2.new(1, -6, 1, -6),
			AnchorPoint = Vector2.new(1, 1),
			Color = C.Sunset,
			MaxTextSize = 17,
			ZIndex = 4,
			Parent = face,
			OnClick = function()
				Remotes.Get("BuyConsumable"):FireServer(def.Id, 5)
			end,
		})
	end

	return {
		Id = def.Id,
		Update = function()
			stats.Text = string.format("❄️ Cools <b>-%d</b> heat%s", def.Cooling, boostText)
			local count = (State.Data.Consumables or ({} :: { [string]: number }))[def.Id] or 0
			have.Visible = not isFree and count > 0
			have.Text = "x" .. tostring(count)
			local coins = State.Data.Coins
			local one = buyOne
			if one then
				one:SetEnabled(coins >= def.Price)
				one:SetText(Icons.Coins .. " " .. Format.Abbreviate(def.Price))
			end
			local five = buyFive
			if five then
				five:SetEnabled(coins >= def.Price * 5)
				five:SetText("x5")
			end
			card:SetHighlight(if count > 0 then C.Ocean else nil)
		end,
	}
end

-- Panel ---------------------------------------------------------------------------------------------

local function refresh()
	if not built then
		return
	end
	for _, item in cards do
		item.Update()
	end
end

local function selectTab(tab: Tab)
	currentTab = tab
	for k, button in tabs do
		button:SetColor(if k == tab then C.Sunset else C.SandDark)
		scrollers[k].Visible = k == tab
	end
end

local function build()
	if built then
		return
	end
	built = true
	local body = panel.Body
	local tabRow = Instance.new("Frame")
	tabRow.Name = "Tabs"
	tabRow.BackgroundTransparency = 1
	tabRow.Size = UDim2.new(1, 0, 0, 50)
	tabRow.ZIndex = 5
	tabRow.Parent = body
	Style.List(tabRow, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left)
	for i, tab in { "Shade", "Snacks" } do
		tabs[tab] = Button.new({
			Text = tab,
			Icon = if tab == "Shade" then "⛱️" else "🍉",
			Size = UDim2.fromOffset(190, 48),
			Color = C.SandDark,
			LayoutOrder = i,
			ZIndex = 5,
			Parent = tabRow,
			OnClick = function()
				selectTab(tab)
			end,
		})
		local scroller = Panel.Scroller(body, UDim2.new(1, 0, 1, -58), UDim2.fromOffset(0, 58))
		scroller.Name = tab
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
		grid.CellPadding = UDim2.fromOffset(10, 12)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		grid.Parent = scroller
		scrollers[tab] = scroller
		if tab == "Shade" then
			for order, def in Config.Shades do
				table.insert(cards, makeShadeCard(def, order, scroller))
			end
		else
			for order, def in Config.Consumables do
				table.insert(cards, makeSnackCard(def, order, scroller))
			end
		end
	end
	-- hint line: how heat works (top right of the tab row)
	Style.Label({
		Name = "Hint",
		Text = "☀️ Sun heats you up. ⛱️ Shade, 🕳️ digging deep and 🍉 snacks cool you down!",
		Size = UDim2.new(1, -410, 0, 44),
		Position = UDim2.new(1, 0, 0, 2),
		AnchorPoint = Vector2.new(1, 0),
		TextColor = C.TextDark,
		Stroke = false,
		Font = Style.Fonts.Body,
		MaxTextSize = 14,
		Wrapped = true,
		ZIndex = 5,
		Parent = body,
	})
	selectTab(currentTab)
	refresh()
end

function BeachShopPanel.Init()
	panel = Panel.new({
		Name = "BeachShop",
		Title = "Beach Shop",
		Icon = Icons.Beach,
		Color = C.Sunset,
		Size = Vector2.new(800, 490),
	})
	panel.Opened:Connect(function(args: any)
		build()
		if typeof(args) == "table" and (args.Tab == "Shade" or args.Tab == "Snacks") then
			selectTab(args.Tab)
		end
		refresh()
	end)
	State.ObserveMany({ "Coins", "OwnedShades", "Consumables", "Rebirths" }, refresh)
	-- placed shades appear / disappear in the world
	CollectionService:GetInstanceAddedSignal("PlacedShade"):Connect(function()
		task.defer(refresh)
	end)
	CollectionService:GetInstanceRemovedSignal("PlacedShade"):Connect(function()
		task.defer(refresh)
	end)
	-- buying a shade jumps straight into placing it
	State.Changed("OwnedShades"):Connect(function(owned: any, old: any)
		if typeof(owned) ~= "table" then
			return
		end
		for id in pendingPlace do
			if owned[id] and not (typeof(old) == "table" and old[id]) then
				pendingPlace[id] = nil
				SoundController.Play("Purchase")
				UIEffects.Confetti(30)
				panel:Close()
				PlacementController.Begin(id)
			end
		end
	end)
end

return BeachShopPanel
