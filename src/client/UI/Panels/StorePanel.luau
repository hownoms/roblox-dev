--!strict
--[[
	StorePanel — Robux store from Config.Monetization. Tabs: Game Passes / Boosts & Coins.
	Items with Id 0 are shown greyed out as "Soon" (never prompted). Owned passes show ✅.
	Coin packs show the live amount for your deepest layer (Config.ResolveCoins).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Components = script.Parent.Parent.Components
local Style = require(Components.Style)
local Panel = require(Components.Panel)
local Button = require(Components.Button)
local Card = require(Components.Card)
local Icons = require(script.Parent.Parent.Icons)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local PurchaseController = require(script.Parent.Parent.Parent.Controllers.PurchaseController)
local RewardText = require(script.Parent.Parent.Parent.Util.RewardText)

local StorePanel = {}

local C = Style.Colors

local PASS_ORDER =
	{ "DoubleSand", "VIP", "SellAnywhere", "AutoDig", "Lucky", "MegaBackpack", "ExtraPets", "TripleHatch" }
local PASS_ICONS: { [string]: string } = {
	VIP = "👑",
	DoubleSand = "⏳",
	SellAnywhere = "💸",
	AutoDig = "🤖",
	Lucky = "🍀",
	TripleHatch = "🥚",
	ExtraPets = "🐾",
	MegaBackpack = "🎒",
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

type Item = { Key: string, IsPass: boolean, Button: Button.Button, Detail: TextLabel }

local panel: Panel.Panel
local built = false
local items: { Item } = {}
local tabs: { [string]: Button.Button } = {}
local pages: { [string]: ScrollingFrame } = {}

local function refresh()
	if not built then
		return
	end
	for _, item in items do
		if item.IsPass then
			local pass = Config.Monetization.GamePasses[item.Key]
			if State.OwnsPass(item.Key) then
				item.Button:SetEnabled(true)
				item.Button:SetColor(C.Disabled)
				item.Button:SetText("Owned ✅")
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
end

local function selectTab(name: string)
	for key, button in tabs do
		button:SetColor(if key == name then C.Sunset else C.SandDark)
		pages[key].Visible = key == name
	end
end

local function makeItem(page: Instance, key: string, isPass: boolean, order: number)
	local name, description, color, icon
	if isPass then
		local pass = Config.Monetization.GamePasses[key]
		name, description, color, icon = pass.Name, pass.Description, pass.Color, PASS_ICONS[key] or "💎"
	else
		local product = Config.Monetization.Products[key]
		name, description = product.Name, product.Description
		local grant = product.Grant
		if grant.Boost then
			local boost = Config.GetBoost(grant.Boost)
			color = if boost then boost.Color else C.Ocean
			icon = if boost then Icons.BoostKinds[boost.Kind] or "⚡" else "⚡"
		elseif grant.Egg then
			color, icon = C.Gold, "🥚"
		elseif grant.Rebirth then
			color, icon = C.Purple, Icons.Rebirth
		else
			color, icon = C.Coins, Icons.Coins
		end
	end
	local card = Card.new({
		Name = key,
		LayoutOrder = order,
		Gradient = { Style.Lighten(color, 0.55), Style.Lighten(color, 0.2) },
		ZIndex = 6,
		Parent = page,
	})
	Style.Label({
		Text = icon,
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.fromOffset(8, 8),
		Stroke = false,
		MaxTextSize = 48,
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
		TextColor = C.TextDark,
		Font = Style.Fonts.Body,
		Stroke = false,
		Wrapped = true,
		MaxTextSize = 14,
		XAlign = Enum.TextXAlignment.Left,
		YAlign = Enum.TextYAlignment.Top,
		ZIndex = 8,
		Parent = card.Face,
	})
	local button = Button.new({
		Text = "R$",
		Size = UDim2.new(1, -16, 0, 48),
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
	table.insert(items, { Key = key, IsPass = isPass, Button = button, Detail = detail })
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
			Size = UDim2.fromOffset(210, 48),
			Color = C.SandDark,
			LayoutOrder = i,
			ZIndex = 5,
			Parent = tabRow,
			OnClick = function()
				selectTab(tab)
			end,
		})
		local page = Panel.Scroller(body, UDim2.new(1, 0, 1, -58), UDim2.fromOffset(0, 58))
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(235, 190)
		grid.CellPadding = UDim2.fromOffset(10, 10)
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = page
		pages[tab] = page
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
	State.ObserveMany({ "Passes", "MaxDepth" }, refresh)
end

return StorePanel
