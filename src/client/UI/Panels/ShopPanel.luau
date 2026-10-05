--!strict
--[[
	ShopPanel — Shovels & Backpacks tabs. Cards show a ViewportFrame preview (Models.Shovel)
	or a backpack emoji, stats, price and a state button:
	  Equipped (grey) / Equip (blue) / Buy <price> (green) / <price> (can't afford, disabled)
	  / 🔒 Rebirth N (locked). The cheapest useful upgrade gets a "⭐ NEXT" tag (also used by the
	tutorial's shop step). Buying auto-equips the new item once the server confirms ownership.
	Open with Panel.Open("Shop", { Tab = "Shovels" | "Backpacks" }).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
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
local ModelFactory = require(script.Parent.Parent.Parent.Util.ModelFactory)

local ShopPanel = {}

local C = Style.Colors

type Kind = string -- "Shovels" | "Backpacks"

type ItemCard = {
	Id: string,
	Kind: Kind,
	Card: Card.Card,
	Button: Button.Button,
	Tag: TextLabel,
	Stats: TextLabel,
	Update: () -> (),
}

local panel: Panel.Panel
local tabs: { [Kind]: Button.Button } = {}
local scrollers: { [Kind]: ScrollingFrame } = {}
local cards: { ItemCard } = {}
local built = false
local currentTab: Kind = "Shovels"
local pendingEquip: { [string]: Kind } = {}

local function digsTo(power: number): string
	local layer = Config.Layers[Config.GetMaxLayerIndexForPower(power)]
	return Icons.Layer(layer.Id) .. " " .. layer.Name
end

-- Cheapest item (of a kind) that is not owned and not locked: the "next upgrade".
local function nextUpgrade(kind: Kind): string?
	local data = State.Data
	if kind == "Shovels" then
		local equipped = State.GetShovel()
		for _, def in Config.Shovels do
			if
				not data.OwnedShovels[def.Id]
				and def.RebirthsRequired <= data.Rebirths
				and def.Power >= equipped.Power
			then
				return def.Id
			end
		end
	else
		local equipped = State.GetBackpack()
		for _, def in Config.Backpacks do
			if
				not data.OwnedBackpacks[def.Id]
				and def.RebirthsRequired <= data.Rebirths
				and def.Capacity > equipped.Capacity
			then
				return def.Id
			end
		end
	end
	return nil
end

local function makeCard(kind: Kind, id: string, order: number, parent: Instance): ItemCard
	local isShovel = kind == "Shovels"
	local shovel = if isShovel then Config.GetShovel(id) else nil
	local backpack = if not isShovel then Config.GetBackpack(id) else nil
	local name = if shovel then shovel.Name elseif backpack then backpack.Name else id
	local price = if shovel then shovel.Price elseif backpack then backpack.Price else 0
	local rebirths = if shovel then shovel.RebirthsRequired elseif backpack then backpack.RebirthsRequired else 0

	local card = Card.new({ Name = id, LayoutOrder = order, Color = C.PanelAlt, Parent = parent })
	local face = card.Face

	local preview = Instance.new("Frame")
	preview.Name = "Preview"
	preview.Size = UDim2.new(1, -16, 0, 92)
	preview.Position = UDim2.fromOffset(8, 8)
	preview.BackgroundColor3 = C.Sky
	preview.ZIndex = 3
	preview.Parent = face
	Style.Corner(preview, Style.Theme.CornerSmall)
	Style.Gradient(preview, { C.Sky, C.Ocean }, 90)
	if shovel then
		local vp = Viewport.new({ Size = UDim2.fromScale(1, 1), ZIndex = 4, Pitch = 10, Parent = preview })
		vp:SetModel(ModelFactory.Shovel(id))
	elseif backpack then
		Style.Label({
			Text = Icons.BackpackShapes[backpack.Look.Shape] or Icons.Backpack,
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			MaxTextSize = 64,
			Stroke = false,
			ZIndex = 4,
			Parent = preview,
		})
		preview.BackgroundColor3 = backpack.Look.Color
	end

	local tag = Style.Label({
		Name = "Tag",
		Text = "⭐ NEXT",
		Size = UDim2.fromOffset(84, 24),
		Position = UDim2.fromOffset(4, 4),
		MaxTextSize = 16,
		ZIndex = 6,
		Parent = face,
	})
	tag.BackgroundTransparency = 0
	tag.BackgroundColor3 = C.Coral
	tag.Visible = false
	Style.Corner(tag, Style.Theme.CornerPill)
	Style.Stroke(tag, C.Stroke, 2)

	Style.Label({
		Name = "ItemName",
		Text = name,
		Size = UDim2.new(1, -12, 0, 24),
		Position = UDim2.fromOffset(6, 102),
		TextColor = C.TextDark,
		Stroke = false,
		MaxTextSize = 19,
		ZIndex = 3,
		Parent = face,
	})
	local stats = Style.Label({
		Name = "Stats",
		Text = "",
		Size = UDim2.new(1, -12, 0, 54),
		Position = UDim2.fromOffset(6, 126),
		TextColor = C.TextDark,
		Stroke = false,
		Font = Style.Fonts.Body,
		MaxTextSize = 13,
		Wrapped = true,
		RichText = true,
		ZIndex = 3,
		Parent = face,
	})

	local item: ItemCard
	local button = Button.new({
		Name = "Action",
		Text = "Buy",
		Size = UDim2.new(1, -14, 0, 44),
		Position = UDim2.new(0.5, 0, 1, -6),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Success,
		MaxTextSize = 20,
		ZIndex = 4,
		Parent = face,
		OnClick = function()
			local data = State.Data
			local owned = if isShovel then data.OwnedShovels[id] else data.OwnedBackpacks[id]
			if owned then
				Remotes.Get(if isShovel then "EquipShovel" else "EquipBackpack"):FireServer(id)
			else
				pendingEquip[id] = kind
				Remotes.Get(if isShovel then "BuyShovel" else "BuyBackpack"):FireServer(id)
			end
		end,
	})

	item = {
		Id = id,
		Kind = kind,
		Card = card,
		Button = button,
		Tag = tag,
		Stats = stats,
		Update = function()
			local data = State.Data
			local owned = if isShovel then data.OwnedShovels[id] == true else data.OwnedBackpacks[id] == true
			local equipped = if isShovel then data.Shovel == id else data.Backpack == id
			if shovel then
				local rate = 1 / shovel.Cooldown
				stats.Text = string.format(
					"💪 Power <b>%d</b>   ⚡ <b>%.1f</b>/s\n📏 Size <b>%d</b>   ✖️ Sand <b>x%s</b>\n⛏️ Digs to %s",
					shovel.Power,
					rate,
					shovel.Radius,
					Format.Abbreviate(shovel.SandMultiplier),
					digsTo(shovel.Power)
				)
			elseif backpack then
				local mega = if State.OwnsPass("MegaBackpack") then 2 else 1
				local capacity = backpack.Capacity * Config.RebirthMultiplier(data.Rebirths) * mega
				stats.Text = "🎒 Holds <b>" .. Format.Abbreviate(capacity) .. "</b> sand\n" .. backpack.Description
			end
			if equipped then
				button:SetEnabled(true)
				button:SetColor(C.Disabled)
				button:SetText("Equipped ✅")
			elseif owned then
				button:SetEnabled(true)
				button:SetColor(C.Ocean)
				button:SetText("Equip")
			elseif data.Rebirths < rebirths then
				button:SetEnabled(false)
				button:SetText(Icons.Lock .. " Rebirth " .. rebirths)
			elseif data.Coins < price then
				button:SetEnabled(false)
				button:SetText(Icons.Coins .. " " .. Format.Abbreviate(price))
			else
				button:SetEnabled(true)
				button:SetColor(C.Success)
				button:SetText("Buy " .. Icons.Coins .. " " .. Format.Abbreviate(price))
			end
			card:SetHighlight(if equipped then C.Palm else nil)
		end,
	}
	return item
end

local function refresh()
	if not built then
		return
	end
	local nextIds = { Shovels = nextUpgrade("Shovels"), Backpacks = nextUpgrade("Backpacks") }
	for _, item in cards do
		item.Update()
		local isNext = nextIds[item.Kind] == item.Id
		if isNext and not item.Tag.Visible then
			Style.PopIn(item.Tag)
		end
		item.Tag.Visible = isNext
	end
end

local function selectTab(kind: Kind)
	currentTab = kind
	for k, button in tabs do
		button:SetColor(if k == kind then C.Sunset else C.SandDark)
		scrollers[k].Visible = k == kind
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
	for i, kind in { "Shovels", "Backpacks" } do
		tabs[kind] = Button.new({
			Text = kind,
			Icon = if kind == "Shovels" then "⛏️" else Icons.Backpack,
			Size = UDim2.fromOffset(190, 48),
			Color = C.SandDark,
			LayoutOrder = i,
			ZIndex = 5,
			Parent = tabRow,
			OnClick = function()
				selectTab(kind)
			end,
		})
		local scroller = Panel.Scroller(body, UDim2.new(1, 0, 1, -58), UDim2.fromOffset(0, 58))
		scroller.Name = kind
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(172, 236)
		grid.CellPadding = UDim2.fromOffset(10, 12)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		grid.Parent = scroller
		scrollers[kind] = scroller
		local list = if kind == "Shovels" then Config.Shovels else Config.Backpacks
		for order, def in list :: { any } do
			table.insert(cards, makeCard(kind, def.Id, order, scroller))
		end
	end
	selectTab(currentTab)
	refresh()
end

-- Scroll the active tab so the "next upgrade" card is visible.
local function scrollToNext()
	local id = nextUpgrade(currentTab)
	local scroller = scrollers[currentTab]
	if not id or not scroller then
		return
	end
	for _, item in cards do
		if item.Id == id and item.Kind == currentTab then
			task.defer(function()
				local offset = item.Card.Holder.AbsolutePosition.Y
					- scroller.AbsolutePosition.Y
					+ scroller.CanvasPosition.Y
				scroller.CanvasPosition = Vector2.new(0, math.max(0, offset - 20))
				Style.Pop(item.Card.Holder, 0.08)
			end)
		end
	end
end

function ShopPanel.Init()
	panel =
		Panel.new({ Name = "Shop", Title = "Shop", Icon = Icons.Shop, Color = C.Palm, Size = Vector2.new(780, 480) })
	panel.Opened:Connect(function(args: any)
		build()
		if typeof(args) == "table" and (args.Tab == "Shovels" or args.Tab == "Backpacks") then
			selectTab(args.Tab)
		end
		refresh()
		scrollToNext()
	end)
	State.ObserveMany(
		{ "Coins", "OwnedShovels", "OwnedBackpacks", "Shovel", "Backpack", "Rebirths", "Passes" },
		refresh
	)
	local function onOwned(kind: Kind)
		return function(owned: any, old: any)
			if typeof(owned) ~= "table" then
				return
			end
			for id, k in pendingEquip do
				if k == kind and owned[id] and not (typeof(old) == "table" and old[id]) then
					pendingEquip[id] = nil
					SoundController.Play("Purchase")
					UIEffects.Confetti(30)
					local equipped = if kind == "Shovels" then State.Data.Shovel else State.Data.Backpack
					if equipped ~= id then
						Remotes.Get(if kind == "Shovels" then "EquipShovel" else "EquipBackpack"):FireServer(id)
					end
				end
			end
		end
	end
	State.Changed("OwnedShovels"):Connect(onOwned("Shovels"))
	State.Changed("OwnedBackpacks"):Connect(onOwned("Backpacks"))
end

ShopPanel.NextUpgrade = nextUpgrade

return ShopPanel
