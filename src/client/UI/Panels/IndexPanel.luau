--!strict
--[[
	IndexPanel — collection book. Left: one tab per layer (emoji, name, found/total, ✅ when
	complete). Right: that layer's treasures; discovered ones show a 3D preview, rarity and how
	many you hold, undiscovered ones are black silhouettes named "???". Header shows the
	collection bonus: +Config.INDEX_LAYER_BONUS sand per completed layer.
	v3 discovery: each discovered card shows variant pills (sizes XS/M/L/XL, materials
	Gold/Fos/Cry) lit once found (PlayerData.FindVariants), and the header shows the TRUE variant
	odds with your current luck (Util/Finds.VariantOdds, the same function the server rolls
	with). Relics are listed in their layer but do not count towards layer completion.
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
local Finds = require(Shared:WaitForChild("Util"):WaitForChild("Finds"))
local Stats = require(Shared:WaitForChild("Util"):WaitForChild("Stats"))

local IndexPanel = {}

local C = Style.Colors

local panel: Panel.Panel
local built = false
local selectedLayer = 1
local layerButtons: { Button.Button } = {}
local grid: ScrollingFrame
local titleLabel: TextLabel
local bonusLabel: TextLabel
local oddsLabel: TextLabel

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
	local total = 0
	for _, treasure in list do
		if treasure.Rarity ~= "Relic" then
			total += 1
			if State.Data.Index[treasure.Id] then
				count += 1
			end
		end
	end
	return count, total
end

-- How many of this treasure you hold unsold (v3 Finds of every variant + legacy Treasures).
function IndexPanel.Held(treasureId: string): number
	local legacy: { [string]: number } = State.Data.Treasures or {}
	local finds: { [string]: number } = State.Data.Finds or {}
	local held = legacy[treasureId] or 0
	for key, count in finds do
		if type(key) == "string" and string.sub(key, 1, #treasureId + 1) == treasureId .. "|" then
			held += count
		end
	end
	return held
end

-- Variant pills: { {Id, Short, Found, Color} } sizes then materials (the default material "None"
-- is not a pill).
function IndexPanel.VariantPills(treasureId: string): { { Id: string, Short: string, Found: boolean, Color: Color3 } }
	local list = {}
	local seen: { [string]: boolean } = State.Data.FindVariants or {}
	for _, group in { Config.Discovery.SIZES, Config.Discovery.MATERIALS } do
		for _, v in group do
			if v.Id ~= "None" then
				table.insert(list, {
					Id = v.Id,
					Short = v.Short,
					Found = seen[Finds.VariantKey(treasureId, v.Id)] == true,
					Color = v.Color,
				})
			end
		end
	end
	return list
end

-- "Tiny 20% · Large 14% ..." true odds at the player's current luck.
function IndexPanel.OddsText(): string
	local ok, luck = pcall(function(): number
		return Stats.GetLuck(State.GetStatsContext())
	end)
	local l = if ok and type(luck) == "number" then luck else 1
	local parts = {}
	for _, group in { "Size", "Material" } do
		for _, o in Finds.VariantOdds(group, l) do
			if o.Id ~= "Normal" and o.Id ~= "None" then
				local pct = o.Chance * 100
				table.insert(
					parts,
					o.Id .. " " .. (if pct >= 10 then string.format("%.0f", pct) else string.format("%.1f", pct)) .. "%"
				)
			end
		end
	end
	local text = "Find odds: " .. table.concat(parts, "  ")
	if l > 1.001 then
		text ..= string.format("  (luck x%.2g)", l)
	end
	return text
end

local function renderLayer()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local layer = Config.Layers[selectedLayer]
	local have, total = found(selectedLayer)
	titleLabel.Text = layer.Name .. "  —  " .. have .. "/" .. total .. " found"
	titleLabel.TextColor3 = Color3.new(1, 1, 1):Lerp(layer.Color, 0.5)
	local reached = State.Data.MaxDepth >= layer.DepthStart
	local treasures: { Types.TreasureDef } = byLayer[selectedLayer] or EMPTY
	for i, treasure in treasures do
		local discovered = State.Data.Index[treasure.Id] == true
		local rarity = Config.GetRarity(treasure.Rarity)
		local card = Card.new({
			Name = treasure.Id,
			LayoutOrder = i,
			Gradient = if discovered and rarity then rarity.Gradient else { C.NavyCard, C.NavyDark },
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
		local held = IndexPanel.Held(treasure.Id)
		Style.Label({
			Text = if discovered
				then treasure.Rarity .. (if held > 0 then "  ·  x" .. held else "")
				elseif reached then treasure.Rarity .. " · keep digging!"
				else "Reach " .. Format.Depth(layer.DepthStart),
			Size = UDim2.new(1, -10, 0, 18),
			Position = UDim2.fromOffset(5, 128),
			Font = Style.Fonts.Body,
			MaxTextSize = 13,
			ZIndex = 8,
			Parent = card.Face,
		})
		if discovered then
			local pills = Instance.new("Frame")
			pills.Name = "Variants"
			pills.BackgroundTransparency = 1
			pills.Size = UDim2.new(1, -10, 0, 34)
			pills.Position = UDim2.fromOffset(5, 166)
			pills.ZIndex = 8
			pills.Parent = card.Face
			local pillGrid = Instance.new("UIGridLayout")
			pillGrid.CellSize = UDim2.fromOffset(32, 15)
			pillGrid.CellPadding = UDim2.fromOffset(3, 3)
			pillGrid.SortOrder = Enum.SortOrder.LayoutOrder
			pillGrid.Parent = pills
			for j, pill in IndexPanel.VariantPills(treasure.Id) do
				local label = Style.Label({
					Name = pill.Id,
					Text = pill.Short,
					Size = UDim2.fromOffset(32, 15),
					Font = Style.Fonts.Body,
					TextColor = if pill.Found then C.TextDark else Color3.fromRGB(140, 150, 170),
					Stroke = false,
					MaxTextSize = 11,
					ZIndex = 9,
					Parent = pills,
				})
				label.LayoutOrder = j
				label.BackgroundTransparency = 0
				label.BackgroundColor3 = if pill.Found then pill.Color else C.NavyDark
				label:SetAttribute("Found", pill.Found)
				Style.Corner(label, Style.Theme.CornerPill)
			end
			Style.Label({
				Text = Format.Abbreviate(treasure.SellValue) .. " coins",
				Size = UDim2.new(1, -10, 0, 18),
				Position = UDim2.fromOffset(5, 146),
				Font = Style.Fonts.Number,
				TextColor = C.Money,
				MaxTextSize = 14,
				ZIndex = 8,
				Parent = card.Face,
			})
		end
	end
	for i, button in layerButtons do
		button:SetColor(if i == selectedLayer then C.Sunset else C.NavyCard)
	end
end

local function refresh()
	if not built then
		return
	end
	local completed = Config.CountCompletedIndexLayers(State.Data.Index)
	oddsLabel.Text = IndexPanel.OddsText()
	bonusLabel.Text = "Collection bonus: +"
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
			if have == total and total > 0 then "Check" elseif reached then "Layers." .. layer.Id else "Lock"
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
			Icon = "Layers." .. layer.Id,
			Size = UDim2.new(1, -14, 0, 56),
			Color = C.NavyCard,
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
		StrokeThickness = 2,
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
		StrokeThickness = 2,
		MaxTextSize = 16,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = body,
	})
	oddsLabel = Style.Label({
		Name = "Odds",
		Text = "",
		Size = UDim2.new(1, -244, 0, 18),
		Position = UDim2.fromOffset(244, 56),
		TextColor = C.Sky,
		Font = Style.Fonts.Body,
		StrokeThickness = 2,
		MaxTextSize = 14,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = body,
	})
	grid = Panel.Scroller(body, UDim2.new(1, -244, 1, -80), UDim2.fromOffset(244, 80))
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(150, 204)
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
	State.ObserveMany({ "Index", "Treasures", "Finds", "FindVariants", "MaxDepth", "Passes", "Boosts" }, function()
		if built and panel.IsOpen then
			refresh()
		end
	end)
end

return IndexPanel
