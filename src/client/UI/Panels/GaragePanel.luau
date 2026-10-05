--!strict
--[[
	GaragePanel — Panel "Garage": buy, upgrade and equip digger companions.
	Opened by the HUD "Garage" button and the map's Garage station (DiggerController).

	Top bar: slot pips (equipped / slots) + how to get more slots (AutoDig pass, rebirth 2 / 5).
	Cards (one per Config.Diggers entry, price order): a ViewportFrame preview of Models.Digger
	framed by the model's bounding box so it fills the card, level stars, stats (deepest layer it
	can dig, seconds per dig, sand multiplier at the current level), and buttons:
	  not owned: Buy <price> (green) / <price> (can't afford, disabled) / 🔒 Rebirth N
	  owned:     Equip (blue) | Unequip (grey) | Slots full (disabled)  +  Upgrade <cost> / MAX
	A "⭐ NEXT" tag marks the cheapest unlocked digger the player does not own yet.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Models = require(Shared:WaitForChild("Models"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local Components = script.Parent.Parent.Components
local Style = require(Components.Style)
local Panel = require(Components.Panel)
local Button = require(Components.Button)
local Card = require(Components.Card)
local Icons = require(script.Parent.Parent.Icons)
local UIEffects = require(script.Parent.Parent.UIEffects)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local SoundController = require(script.Parent.Parent.Parent.Controllers.SoundController)
local PurchaseController = require(script.Parent.Parent.Parent.Controllers.PurchaseController)

local GaragePanel = {}

local C = Style.Colors
local ICON = "🚜"
local CARD_SIZE = Vector2.new(196, 340)
local PREVIEW_SIZE = Vector2.new(CARD_SIZE.X - 16, 132)
local CAMERA_FOV = 30
local VIEW_DIR = Vector3.new(0.85, 0.55, -1).Unit -- front-right-above (models face -Z)

type DiggerCard = {
	Id: string,
	Card: Card.Card,
	Tag: TextLabel,
	Update: () -> (),
}

local panel: Panel.Panel
local cards: { DiggerCard } = {}
local built = false
local slotLabel: TextLabel
local slotPips: Frame
local slotHint: TextLabel
local passButton: Button.Button

-- Helpers ---------------------------------------------------------------------------------------

local function owned(): { [string]: Types.DiggerInstance }
	return State.Data.Diggers or {}
end

local function slotCount(): number
	return Config.GetDiggerSlots(State.Data.Rebirths or 0, State.OwnsPass("AutoDig"))
end

local function equippedCount(): number
	local n = 0
	for id, inst in owned() do
		if inst.Equipped and Config.GetDigger(id) then
			n += 1
		end
	end
	return n
end

local function nextDigger(): string?
	local data = State.Data
	for _, def in Config.Diggers do
		if not owned()[def.Id] and (def.RebirthsRequired or 0) <= data.Rebirths then
			return def.Id
		end
	end
	return nil
end

local function layerName(power: number): string
	local layer = Config.Layers[Config.GetMaxLayerIndexForPower(power)]
	return Icons.Layer(layer.Id) .. " " .. layer.Name
end

-- Frames `model` so its bounding box fills a viewport of the given aspect ratio (3/4 view).
local function frameModel(camera: Camera, model: Model, aspect: number, margin: number)
	model:PivotTo(CFrame.new())
	local boxCFrame, size = model:GetBoundingBox()
	local center = boxCFrame.Position
	local view = CFrame.lookAt(center + VIEW_DIR, center)
	local tanV = math.tan(math.rad(CAMERA_FOV / 2)) * margin
	local tanH = tanV * aspect
	local distance = 0
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = boxCFrame:PointToWorldSpace(Vector3.new(sx, sy, sz) * size / 2)
				local p = view.Rotation:PointToObjectSpace(corner - center)
				-- camera at center + VIEW_DIR * d looks along -VIEW_DIR; depth = d - p.Z
				distance = math.max(distance, p.Z + math.abs(p.X) / tanH, p.Z + math.abs(p.Y) / tanV)
			end
		end
	end
	camera.FieldOfView = CAMERA_FOV
	camera.CFrame = CFrame.lookAt(center + VIEW_DIR * math.max(distance, 1), center)
end

local function makePreview(id: string, parent: Instance)
	local preview = Instance.new("Frame")
	preview.Name = "Preview"
	preview.Size = UDim2.fromOffset(PREVIEW_SIZE.X, PREVIEW_SIZE.Y)
	preview.Position = UDim2.fromOffset(8, 8)
	preview.BackgroundColor3 = C.Sky
	preview.ZIndex = 3
	preview.ClipsDescendants = true
	preview.Parent = parent
	Style.Corner(preview, Style.Theme.CornerSmall)
	Style.Gradient(preview, { C.Sky, C.Sand }, 90)

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Viewport"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.ZIndex = 4
	viewport.Ambient = Color3.fromRGB(190, 190, 200)
	viewport.LightColor = Color3.fromRGB(255, 250, 235)
	viewport.LightDirection = Vector3.new(-1, -1.4, -0.8)
	viewport.Parent = preview
	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local ok, result = pcall(Models.Digger, id)
	if ok and typeof(result) == "Instance" and result:IsA("Model") then
		local model = result :: Model
		for _, d in model:GetDescendants() do
			if d:IsA("ParticleEmitter") or d:IsA("PointLight") then
				d:Destroy()
			end
		end
		frameModel(camera, model, PREVIEW_SIZE.X / PREVIEW_SIZE.Y, 0.9)
		model.Parent = viewport
	else
		warn("[GaragePanel] Models.Digger failed for", id, result)
	end
end

-- Cards -------------------------------------------------------------------------------------------

local function makeCard(def: Types.DiggerDef, order: number, parent: Instance): DiggerCard
	local card = Card.new({ Name = def.Id, LayoutOrder = order, Color = C.PanelAlt, Parent = parent })
	local face = card.Face
	makePreview(def.Id, face)

	local tag = Style.Label({
		Name = "Tag",
		Text = Icons.Star .. " NEXT",
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

	local levelLabel = Style.Label({
		Name = "Level",
		Text = "",
		Size = UDim2.fromOffset(PREVIEW_SIZE.X - 8, 22),
		Position = UDim2.fromOffset(12, 8 + PREVIEW_SIZE.Y - 26),
		XAlign = Enum.TextXAlignment.Right,
		MaxTextSize = 18,
		ZIndex = 6,
		Parent = face,
	})

	local top = 8 + PREVIEW_SIZE.Y + 2
	Style.Label({
		Name = "ItemName",
		Text = def.Name,
		Size = UDim2.new(1, -12, 0, 24),
		Position = UDim2.fromOffset(6, top),
		TextColor = C.TextDark,
		Stroke = false,
		MaxTextSize = 19,
		ZIndex = 3,
		Parent = face,
	})
	local stats = Style.Label({
		Name = "Stats",
		Text = "",
		Size = UDim2.new(1, -12, 0, 62),
		Position = UDim2.fromOffset(6, top + 24),
		TextColor = C.TextDark,
		Stroke = false,
		Font = Style.Fonts.Body,
		MaxTextSize = 13,
		Wrapped = true,
		RichText = true,
		ZIndex = 3,
		Parent = face,
	})

	-- Buttons: one full-width (buy) or two stacked (equip + upgrade) when owned.
	local buy = Button.new({
		Name = "Buy",
		Text = "Buy",
		Size = UDim2.new(1, -14, 0, 48),
		Position = UDim2.new(0.5, 0, 1, -6),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Success,
		MaxTextSize = 20,
		ZIndex = 4,
		Parent = face,
		OnClick = function()
			Remotes.Get("BuyDigger"):FireServer(def.Id)
		end,
	})
	local equip = Button.new({
		Name = "Equip",
		Text = "Equip",
		Size = UDim2.new(1, -14, 0, 44),
		Position = UDim2.new(0.5, 0, 1, -54),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Ocean,
		MaxTextSize = 18,
		ZIndex = 4,
		Parent = face,
		OnClick = function()
			local inst = owned()[def.Id]
			if inst and inst.Equipped then
				Remotes.Get("UnequipDigger"):FireServer(def.Id)
			elseif inst then
				Remotes.Get("EquipDigger"):FireServer(def.Id)
			end
		end,
	})
	local upgrade = Button.new({
		Name = "Upgrade",
		Text = "Upgrade",
		Size = UDim2.new(1, -14, 0, 44),
		Position = UDim2.new(0.5, 0, 1, -6),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Sunset,
		MaxTextSize = 18,
		ZIndex = 4,
		Parent = face,
		OnClick = function()
			Remotes.Get("UpgradeDigger"):FireServer(def.Id)
		end,
	})

	local item: DiggerCard
	item = {
		Id = def.Id,
		Card = card,
		Tag = tag,
		Update = function()
			local data = State.Data
			local inst = owned()[def.Id]
			local level = if inst then inst.Level else 1
			local s = Config.GetDiggerStats(def, level)
			local nextCost = if inst then Config.GetDiggerUpgradeCost(def, level) else nil
			local stars = string.rep("★", level) .. string.rep("☆", def.MaxLevel - level)
			levelLabel.Text = if inst then "Lv " .. level .. " " .. stars else ""
			local lines = {
				string.format("%s Digs to <b>%s</b>", Icons.Power, layerName(s.Power)),
				string.format(
					"%s <b>%.1fs</b> per dig   %s Sand <b>x%s</b>",
					Icons.Speed,
					s.Interval,
					Icons.Sand,
					Format.Abbreviate(math.floor(s.SandMultiplier * 10 + 0.5) / 10)
				),
			}
			if inst and nextCost then
				local n = Config.GetDiggerStats(def, level + 1)
				table.insert(
					lines,
					string.format(
						'<font color="#2E9E4A">Next: %.1fs, x%s</font>',
						n.Interval,
						Format.Abbreviate(math.floor(n.SandMultiplier * 10 + 0.5) / 10)
					)
				)
			elseif not inst then
				table.insert(lines, def.Description)
			end
			stats.Text = table.concat(lines, "\n")

			local isOwned = inst ~= nil
			buy:SetVisible(not isOwned)
			equip:SetVisible(isOwned)
			upgrade:SetVisible(isOwned)
			local needed = def.RebirthsRequired or 0
			if not isOwned then
				if data.Rebirths < needed then
					buy:SetEnabled(false)
					buy:SetText(Icons.Lock .. " Rebirth " .. needed)
				elseif data.Coins < def.Price then
					buy:SetEnabled(false)
					buy:SetText(Icons.Coins .. " " .. Format.Abbreviate(def.Price))
				else
					buy:SetEnabled(true)
					buy:SetColor(C.Success)
					buy:SetText("Buy " .. Icons.Coins .. " " .. Format.Abbreviate(def.Price))
				end
			else
				if inst and inst.Equipped then
					equip:SetEnabled(true)
					equip:SetColor(C.Disabled)
					equip:SetText("Unequip")
				elseif equippedCount() >= slotCount() then
					equip:SetEnabled(false)
					equip:SetText("Slots full")
				else
					equip:SetEnabled(true)
					equip:SetColor(C.Ocean)
					equip:SetText("Equip")
				end
				if not nextCost then
					upgrade:SetEnabled(false)
					upgrade:SetText(Icons.Star .. " MAX")
				elseif data.Coins < (nextCost :: number) then
					upgrade:SetEnabled(false)
					upgrade:SetText("⬆️ " .. Format.Abbreviate(nextCost :: number))
				else
					upgrade:SetEnabled(true)
					upgrade:SetColor(C.Sunset)
					upgrade:SetText("⬆️ " .. Icons.Coins .. " " .. Format.Abbreviate(nextCost :: number))
				end
			end
			card:SetHighlight(if inst and inst.Equipped then C.Palm else nil)
		end,
	}
	return item
end

-- Slots bar -----------------------------------------------------------------------------------------

local function updateSlots()
	local slots = slotCount()
	local used = math.min(equippedCount(), slots)
	slotLabel.Text = string.format("%s Digger slots: %d / %d", ICON, used, slots)
	for _, child in slotPips:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i = 1, slots do
		local pip = Instance.new("Frame")
		pip.Name = "Pip"
		pip.Size = UDim2.fromOffset(22, 22)
		pip.BackgroundColor3 = if i <= used then C.Palm else C.Disabled
		pip.LayoutOrder = i
		pip.ZIndex = 6
		pip.Parent = slotPips
		Style.Corner(pip, Style.Theme.CornerPill)
		Style.Stroke(pip, C.Stroke, 2)
	end
	local hints = {}
	if not State.OwnsPass("AutoDig") then
		table.insert(hints, "+1 with Auto Dig")
	end
	for _, needed in Config.DIGGER_REBIRTH_SLOTS do
		if (State.Data.Rebirths or 0) < needed then
			table.insert(hints, "+1 at Rebirth " .. needed)
		end
	end
	slotHint.Text = if #hints > 0 then table.concat(hints, "   ") else "All slots unlocked!"
	passButton:SetVisible(not State.OwnsPass("AutoDig") and PurchaseController.IsPassConfigured("AutoDig"))
end

local function refresh()
	if not built then
		return
	end
	updateSlots()
	local nextId = nextDigger()
	for _, item in cards do
		item.Update()
		local isNext = item.Id == nextId
		if isNext and not item.Tag.Visible then
			Style.PopIn(item.Tag)
		end
		item.Tag.Visible = isNext
	end
end

local function build()
	if built then
		return
	end
	built = true
	local body = panel.Body

	local bar = Instance.new("Frame")
	bar.Name = "SlotsBar"
	bar.Size = UDim2.new(1, 0, 0, 54)
	bar.BackgroundColor3 = C.PanelAlt
	bar.ZIndex = 5
	bar.Parent = body
	Style.Corner(bar, Style.Theme.CornerMedium)
	Style.Stroke(bar, C.Stroke, 2)
	slotLabel = Style.Label({
		Name = "Slots",
		Text = "",
		Size = UDim2.new(0, 250, 0, 26),
		Position = UDim2.fromOffset(12, 4),
		XAlign = Enum.TextXAlignment.Left,
		TextColor = C.TextDark,
		Stroke = false,
		MaxTextSize = 20,
		ZIndex = 6,
		Parent = bar,
	})
	slotHint = Style.Label({
		Name = "Hint",
		Text = "",
		Size = UDim2.new(0, 330, 0, 18),
		Position = UDim2.fromOffset(12, 31),
		XAlign = Enum.TextXAlignment.Left,
		TextColor = C.TextDark,
		Stroke = false,
		Font = Style.Fonts.Body,
		MaxTextSize = 13,
		ZIndex = 6,
		Parent = bar,
	})
	slotPips = Instance.new("Frame")
	slotPips.Name = "Pips"
	slotPips.BackgroundTransparency = 1
	slotPips.Size = UDim2.fromOffset(150, 26)
	slotPips.Position = UDim2.fromOffset(350, 14)
	slotPips.ZIndex = 6
	slotPips.Parent = bar
	Style.List(slotPips, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left)
	passButton = Button.new({
		Name = "GetSlot",
		Text = "+1 Slot",
		Icon = Icons.AutoDig,
		Size = UDim2.fromOffset(150, 46),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = C.Ocean,
		MaxTextSize = 18,
		ZIndex = 6,
		Parent = bar,
		OnClick = function()
			PurchaseController.PromptPass("AutoDig")
		end,
	})

	local scroller = Panel.Scroller(body, UDim2.new(1, 0, 1, -62), UDim2.fromOffset(0, 62))
	scroller.Name = "Diggers"
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	grid.CellPadding = UDim2.fromOffset(10, 12)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroller
	for order, def in Config.Diggers do
		table.insert(cards, makeCard(def, order, scroller))
	end
	refresh()
end

function GaragePanel.Init()
	panel =
		Panel.new({ Name = "Garage", Title = "Garage", Icon = ICON, Color = C.Sunset, Size = Vector2.new(840, 500) })
	panel.Opened:Connect(function()
		build()
		refresh()
	end)
	State.ObserveMany({ "Coins", "Diggers", "Rebirths", "Passes" }, refresh)
	State.Changed("Diggers"):Connect(function(new: any, old: any)
		if typeof(new) ~= "table" or typeof(old) ~= "table" or not State.Loaded then
			return
		end
		for id in new do
			if old[id] == nil and Config.GetDigger(id) then
				SoundController.Play("Purchase")
				UIEffects.Confetti(30)
				return
			end
		end
	end)
end

return GaragePanel
