--!strict
--[[
	IndexPanel — collection book. Left: one tab per layer (emoji, name, found/total, ✅ when
	complete). Right: that layer's treasures; discovered ones show a 3D preview, rarity and how
	many you hold, undiscovered ones are black silhouettes named "???". Header shows the
	collection bonus: +Config.INDEX_LAYER_BONUS sand per completed layer.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local Components = script.Parent.Parent.Components
local Style = require(Components.Style)
local Panel = require(Components.Panel)
local Button = require(Components.Button)
local Card = require(Components.Card)
local Viewport = require(Components.Viewport)
local Icons = require(script.Parent.Parent.Icons)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local ModelFactory = require(script.Parent.Parent.Parent.Util.ModelFactory)

local IndexPanel = {}

local C = Style.Colors

local panel: Panel.Panel
local built = false
local selectedLayer = 1
local layerButtons: { Button.Button } = {}
local grid: ScrollingFrame
local titleLabel: TextLabel
local bonusLabel: TextLabel

local byLayer: { [number]: { Types.TreasureDef } } = {}
for _, treasure in Config.Treasures do
	local list = byLayer[treasure.Layer]
	if not list then
		list = {}
		byLayer[treasure.Layer] = list
	end
	table.insert(list :: { Types.TreasureDef }, treasure)
end
for _, list in byLayer do
	table.sort(list, function(a: Types.TreasureDef, b: Types.TreasureDef): boolean
		local ra = Config.GetRarity(a.Rarity)
		local rb = Config.GetRarity(b.Rarity)
		return (if ra then ra.Order else 0) < (if rb then rb.Order else 0)
	end)
end

local EMPTY: { Types.TreasureDef } = {}

local function found(layerIndex: number): (number, number)
	local list: { Types.TreasureDef } = byLayer[layerIndex] or EMPTY
	local count = 0
	for _, treasure in list do
		if State.Data.Index[treasure.Id] then
			count += 1
		end
	end
	return count, #list
end

local function renderLayer()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local layer = Config.Layers[selectedLayer]
	local have, total = found(selectedLayer)
	titleLabel.Text = Icons.Layer(layer.Id) .. " " .. layer.Name .. "  —  " .. have .. "/" .. total .. " found"
	titleLabel.TextColor3 = Style.Darken(layer.Color, 0.45)
	local reached = State.Data.MaxDepth >= layer.DepthStart
	local treasures: { Types.TreasureDef } = byLayer[selectedLayer] or EMPTY
	for i, treasure in treasures do
		local discovered = State.Data.Index[treasure.Id] == true
		local rarity = Config.GetRarity(treasure.Rarity)
		local card = Card.new({
			Name = treasure.Id,
			LayoutOrder = i,
			Gradient = if discovered and rarity then rarity.Gradient else { C.PanelAlt, C.SandDark },
			ZIndex = 6,
			Parent = grid,
		})
		local vp = Viewport.new({
			Size = UDim2.new(1, -16, 0, 96),
			Position = UDim2.fromOffset(8, 6),
			ZIndex = 8,
			Silhouette = not discovered,
			Pitch = 20,
			Parent = card.Face,
		})
		vp:SetModel(ModelFactory.Treasure(treasure.Id))
		Style.Label({
			Text = if discovered then treasure.Name else "???",
			Size = UDim2.new(1, -10, 0, 24),
			Position = UDim2.fromOffset(5, 104),
			MaxTextSize = 17,
			ZIndex = 8,
			Parent = card.Face,
		})
		local held = State.Data.Treasures[treasure.Id] or 0
		Style.Label({
			Text = if discovered
				then treasure.Rarity .. (if held > 0 then "  ·  x" .. held else "")
				elseif reached then treasure.Rarity .. " · keep digging!"
				else Icons.Lock .. " Reach " .. Format.Depth(layer.DepthStart),
			Size = UDim2.new(1, -10, 0, 18),
			Position = UDim2.fromOffset(5, 128),
			Font = Style.Fonts.Body,
			MaxTextSize = 13,
			ZIndex = 8,
			Parent = card.Face,
		})
		if discovered then
			Style.Label({
				Text = Icons.Coins .. " " .. Format.Abbreviate(treasure.SellValue),
				Size = UDim2.new(1, -10, 0, 18),
				Position = UDim2.fromOffset(5, 146),
				Font = Style.Fonts.Number,
				TextColor = C.Gold,
				MaxTextSize = 14,
				ZIndex = 8,
				Parent = card.Face,
			})
		end
	end
	for i, button in layerButtons do
		button:SetColor(if i == selectedLayer then C.Sunset else C.SandDark)
	end
end

local function refresh()
	if not built then
		return
	end
	local completed = Config.CountCompletedIndexLayers(State.Data.Index)
	bonusLabel.Text = "📖 Collection bonus: +"
		.. math.floor(completed * Config.INDEX_LAYER_BONUS * 100 + 0.5)
		.. "% sand  ("
		.. completed
		.. "/"
		.. #Config.Layers
		.. " layers complete, +"
		.. math.floor(Config.INDEX_LAYER_BONUS * 100 + 0.5)
		.. "% each)"
	for i, button in layerButtons do
		local layer = Config.Layers[i]
		local have, total = found(i)
		local reached = State.Data.MaxDepth >= layer.DepthStart
		button:SetIcon(
			if have == total and total > 0 then "✅" elseif reached then Icons.Layer(layer.Id) else Icons.Lock
		)
		button:SetText(layer.Name .. " " .. have .. "/" .. total)
	end
	renderLayer()
end

local function build()
	if built then
		return
	end
	built = true
	local body = panel.Body
	local list = Panel.Scroller(body, UDim2.new(0, 230, 1, 0))
	Style.List(list, Enum.FillDirection.Vertical, 6)
	for i, layer in Config.Layers do
		layerButtons[i] = Button.new({
			Text = layer.Name,
			Icon = Icons.Layer(layer.Id),
			Size = UDim2.new(1, -14, 0, 50),
			Color = C.SandDark,
			MaxTextSize = 16,
			LayoutOrder = i,
			ZIndex = 6,
			Parent = list,
			OnClick = function()
				selectedLayer = i
				renderLayer()
			end,
		})
	end
	titleLabel = Style.Label({
		Text = "",
		Size = UDim2.new(1, -244, 0, 30),
		Position = UDim2.fromOffset(244, 0),
		Stroke = false,
		MaxTextSize = 26,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = body,
	})
	bonusLabel = Style.Label({
		Text = "",
		Size = UDim2.new(1, -244, 0, 22),
		Position = UDim2.fromOffset(244, 32),
		TextColor = C.Palm,
		Font = Style.Fonts.Body,
		Stroke = false,
		MaxTextSize = 16,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = body,
	})
	grid = Panel.Scroller(body, UDim2.new(1, -244, 1, -60), UDim2.fromOffset(244, 60))
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(150, 172)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
end

function IndexPanel.Init()
	panel = Panel.new({
		Name = "Index",
		Title = "Treasure Index",
		Icon = Icons.Index,
		Color = C.Ocean,
		Size = Vector2.new(800, 480),
	})
	panel.Opened:Connect(function()
		build()
		selectedLayer = Config.GetLayerIndexAtDepth(State.Data.MaxDepth)
		refresh()
	end)
	State.ObserveMany({ "Index", "Treasures", "MaxDepth" }, function()
		if built and panel.IsOpen then
			refresh()
		end
	end)
end

return IndexPanel
