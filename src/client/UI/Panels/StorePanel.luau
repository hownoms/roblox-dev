--!strict
--[[
	StorePanel — Robux store from Config.Monetization. Tabs: Game Passes / Boosts & Coins.
	Items with Id 0 are shown greyed out as "Soon" (never prompted). Owned passes show ✅.
	Coin packs show the live amount for your deepest layer (Config.ResolveCoins).
	v2.2 policy: items marked PaidRandom (coins, golden eggs, luck, skip rebirth, Lucky pass) are
	hidden entirely while State.IsPaidRandomRestricted() (server PolicyService attribute). The grid
	re-flows, and an empty tab says so instead of showing a blank page. The Cooler Pack is gone.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Components = script.Parent.Parent.Components
local Style = require(Components.Style)
local Panel = require(Components.Panel)
local Button = require(Components.Button)
local Card = require(Components.Card)
local AtlasIcon = require(Components.AtlasIcon)
local Icons = require(script.Parent.Parent.Icons)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local PurchaseController = require(script.Parent.Parent.Parent.Controllers.PurchaseController)
local RewardText = require(script.Parent.Parent.Parent.Util.RewardText)

local StorePanel = {}

local C = Style.Colors

local PASS_ORDER =
	{ "DoubleSand", "VIP", "SellAnywhere", "AutoDig", "Lucky", "MegaBackpack", "ExtraPets", "TripleHatch" }
local PASS_ICONS: { [string]: string } = {
	VIP = "trophy|👑",
	DoubleSand = "boost_sand",
	SellAnywhere = "Sell",
	AutoDig = "AutoDig",
	Lucky = "boost_luck",
	TripleHatch = "egg_hatch",
	ExtraPets = "Pets",
	MegaBackpack = "Backpack",
}
local PRODUCT_ORDER = {
	"SandBoost15",
	"LuckBoost15",
	"CoinsSmall",
	"CoinsMedium",
	"CoinsLarge",
	"CoinsHuge",
	"GoldenEgg",
	"GoldenEgg3",
	"SkipRebirth",
}

type Item = { Key: string, IsPass: boolean, Button: Button.Button, Detail: TextLabel, Card: Card.Card }

local panel: Panel.Panel
local built = false
local items: { Item } = {}
local tabs: { [string]: Button.Button } = {}
local pages: { [string]: ScrollingFrame } = {}
local emptyNotes: { [string]: TextLabel } = {}

local function refresh()
	if not built then
		return
	end
	local shown: { [string]: number } = {}
	for _, item in items do
		local visible = State.CanBuy(if item.IsPass then "GamePass" else "Product", item.Key)
		item.Card.Holder.Visible = visible
		local page = if item.IsPass then "Passes" else "Boosts & Coins"
		shown[page] = (shown[page] or 0) + (if visible then 1 else 0)
		if not visible then
			continue
		end
		if item.IsPass then
			local pass = Config.Monetization.GamePasses[item.Key]
			if State.OwnsPass(item.Key) then
				item.Button:SetEnabled(true)
				item.Button:SetColor(C.Disabled)
				item.Button:SetText("Owned!")
			elseif pass.Id == 0 then
				item.Button:SetEnabled(false)
				item.Button:SetText("Soon")
			else
				item.Button:SetEnabled(true)
				item.Button:SetColor(C.Robux)
				item.Button:SetText("R$ " .. pass.Price)
			end
		else
			local product = Config.Monetization.Products[item.Key]
			item.Detail.Text = product.Description .. "\n" .. RewardText.Describe(product.Grant, State.Data.MaxDepth)
			if product.Id == 0 then
				item.Button:SetEnabled(false)
				item.Button:SetText("Soon")
			else
				item.Button:SetEnabled(true)
				item.Button:SetText("R$ " .. product.Price)
			end
		end
	end
	for page, note in emptyNotes do
		note.Visible = (shown[page] or 0) == 0
	end
end

local function selectTab(name: string)
	for key, button in tabs do
		button:SetColor(if key == name then C.Sunset else C.NavyCard)
		pages[key].Visible = key == name
	end
end

local function makeItem(page: Instance, key: string, isPass: boolean, order: number)
	local name, description, color, icon
	if isPass then
		local pass = Config.Monetization.GamePasses[key]
		name, description, color, icon = pass.Name, pass.Description, pass.Color, PASS_ICONS[key] or "gem"
	else
		local product = Config.Monetization.Products[key]
		name, description = product.Name, product.Description
		local grant = product.Grant
		if grant.Boost then
			local boost = Config.GetBoost(grant.Boost)
			color = if boost then boost.Color else C.Ocean
			icon = if boost then "BoostKinds." .. boost.Kind else "boost_speed"
		elseif grant.Egg then
			color, icon = C.Gold, "Eggs"
		elseif grant.Rebirth then
			color, icon = C.Purple, "Rebirth"
		else
			color, icon = C.Coins, "Coins"
		end
	end
	local card = Card.new({
		Name = key,
		LayoutOrder = order,
		Gradient = { Style.Darken(color, 0.15), Style.Darken(color, 0.5) },
		ZIndex = 6,
		Parent = page,
	})
	AtlasIcon.new({
		Icon = icon,
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.fromOffset(6, 4),
		AnchorPoint = Vector2.zero,
		ZIndex = 8,
		Parent = card.Face,
	})
	Style.Label({
		Text = name,
		Size = UDim2.new(1, -76, 0, 30),
		Position = UDim2.fromOffset(68, 10),
		MaxTextSize = 22,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 8,
		Parent = card.Face,
	})
	local detail = Style.Label({
		Text = description,
		Size = UDim2.new(1, -16, 0, 58),
		Position = UDim2.fromOffset(8, 66),
		Font = Style.Fonts.Body,
		StrokeThickness = 2,
		Wrapped = true,
		MaxTextSize = 14,
		XAlign = Enum.TextXAlignment.Left,
		YAlign = Enum.TextYAlignment.Top,
		ZIndex = 8,
		Parent = card.Face,
	})
	local button = Button.new({
		Text = "R$",
		Size = UDim2.new(1, -16, 0, 60),
		Position = UDim2.new(0.5, 0, 1, -6),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Robux,
		MaxTextSize = 22,
		ZIndex = 8,
		Parent = card.Face,
		OnClick = function()
			if isPass then
				PurchaseController.PromptPass(key)
			else
				PurchaseController.PromptProduct(key)
			end
		end,
	})
	table.insert(items, { Key = key, IsPass = isPass, Button = button, Detail = detail, Card = card })
end

local function build()
	if built then
		return
	end
	built = true
	local body = panel.Body
	local tabRow = Instance.new("Frame")
	tabRow.BackgroundTransparency = 1
	tabRow.Size = UDim2.new(1, 0, 0, 50)
	tabRow.ZIndex = 5
	tabRow.Parent = body
	Style.List(tabRow, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left)
	for i, tab in { "Passes", "Boosts & Coins" } do
		tabs[tab] = Button.new({
			Text = tab,
			Size = UDim2.fromOffset(210, 56),
			Color = C.NavyCard,
			LayoutOrder = i,
			ZIndex = 5,
			Parent = tabRow,
			OnClick = function()
				selectTab(tab)
			end,
		})
		local page = Panel.Scroller(body, UDim2.new(1, 0, 1, -58), UDim2.fromOffset(0, 58))
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(235, 200)
		grid.CellPadding = UDim2.fromOffset(10, 10)
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = page
		pages[tab] = page
		local note = Style.Label({
			Text = "Nothing here right now. Dig, rebirth and finish quests to earn boosts!",
			Size = UDim2.new(1, -40, 0, 60),
			Position = UDim2.new(0.5, 0, 0, 120),
			AnchorPoint = Vector2.new(0.5, 0),
			TextColor = C.Sand,
			StrokeThickness = 2,
			Wrapped = true,
			MaxTextSize = 22,
			ZIndex = 6,
			Parent = page,
		})
		note.Name = "EmptyNote"
		note.Visible = false
		emptyNotes[tab] = note
	end
	for i, key in PASS_ORDER do
		if Config.Monetization.GamePasses[key] then
			makeItem(pages.Passes, key, true, i)
		end
	end
	for i, key in PRODUCT_ORDER do
		if Config.Monetization.Products[key] then
			makeItem(pages["Boosts & Coins"], key, false, i)
		end
	end
	selectTab("Passes")
end

function StorePanel.Init()
	panel = Panel.new({
		Name = "Store",
		Title = "Store",
		Icon = Icons.Store,
		Color = C.Robux,
		Size = Vector2.new(800, 480),
	})
	panel.Opened:Connect(function(args: any)
		build()
		if typeof(args) == "table" and typeof(args.Tab) == "string" and pages[args.Tab] then
			selectTab(args.Tab)
		end
		refresh()
	end)
	State.ObserveMany({ "Passes", "MaxDepth", "PaidRandomRestricted" }, refresh)
end

return StorePanel
