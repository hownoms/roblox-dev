--!strict
--[[
	PetsPanel — pet inventory: grid of pet tiles (emoji on rarity gradient, bonus, ✅ when
	equipped), sorted by multiplier (or rarity), header with "Equipped 2/3" + total pet bonus,
	"Equip Best" and sort toggle. Selecting a pet shows a spinning 3D preview with
	Equip/Unequip and Delete (tap twice to confirm).
	v2.1: digging pets show a ⛏ badge (top-left of the tile) and their dig stats in the detail
	("⛏ digs to Pirate Cove · every 3.0s · x2.25 sand"); rideable pets a 🚜 "Rideable" badge (the
	Ride agent adds the actual ride button). Vehicle pets use vehicle icons.
	v2.2 DUPLICATE FUSION: selecting a pet with >= Config.GOLDEN_FUSE_COUNT (5) identical non-golden
	copies enables "Fuse 5 -> Golden" (remote FusePets(uid), validated by PetService). Golden pets
	(PetInstance.Golden) get a gold outline + "GOLDEN" tag, a gold-tinted sparkling preview
	(ModelFactory.MakeGolden), x1.5 sand bonus and 1.25x dig speed in their stats.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Components = script.Parent.Parent.Components
local Style = require(Components.Style)
local Panel = require(Components.Panel)
local Button = require(Components.Button)
local Card = require(Components.Card)
local AtlasIcon = require(Components.AtlasIcon)
local Viewport = require(Components.Viewport)
local Icons = require(script.Parent.Parent.Icons)
local Toasts = require(script.Parent.Parent.Toasts)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local ModelFactory = require(script.Parent.Parent.Parent.Util.ModelFactory)

local PetsPanel = {}

local C = Style.Colors

type Entry = { Uid: string, Pet: Types.PetInstance, Def: Types.PetDef, Order: number, Mult: number }

local panel: Panel.Panel
local built = false
local sortMode: "Bonus" | "Rarity" = "Bonus"
local selectedUid: string? = nil
local confirmDelete = false

local grid: ScrollingFrame
local equippedLabel: TextLabel
local bonusLabel: TextLabel
local sortButton: Button.Button
local view: Viewport.Viewport
local nameLabel: TextLabel
local infoLabel: TextLabel
local digLabel: TextLabel
local equipButton: Button.Button
local deleteButton: Button.Button
local fuseButton: Button.Button
local emptyLabel: TextLabel
local shownModelFor: string? = nil

-- v2.2: this pet's own multiplier, Golden included.
local function multOf(pet: Types.PetInstance): number
	return Config.PetEffectiveMultiplier(pet.Id, pet.Golden == true)
end

-- Non-golden copies of petId in the inventory (the fusion count).
local function copiesOf(petId: string): number
	local n = 0
	for _, pet in State.Data.Pets or {} :: { [string]: Types.PetInstance } do
		if pet.Id == petId and pet.Golden ~= true then
			n += 1
		end
	end
	return n
end

local function petIcon(def: Types.PetDef): string
	return if def.VehicleKind then "VehicleKinds." .. def.VehicleKind else "PetShapes." .. def.Look.Shape
end

local function rarityOrder(def: Types.PetDef): number
	local rarity = Config.GetRarity(def.Rarity)
	return if rarity then rarity.Order else 0
end

-- "⛏ digs to Pirate Cove · every 3.0s · x2.25 sand" (nil for pets that don't dig)
local function digInfo(def: Types.PetDef, golden: boolean?): string?
	local dig = def.Dig
	if not dig then
		return nil
	end
	assert(dig) -- refine for the type checker (guarded above)
	local layer = Config.Layers[Config.GetMaxLayerIndexForPower(dig.Power)]
	local interval = Config.GetPetDigInterval(def.Id, golden) or dig.Interval
	return string.format("digs to %s · every %.1fs · x%g sand", layer.Name, interval, dig.SandMultiplier)
end

local function entries(): { Entry }
	local list: { Entry } = {}
	for uid, pet in State.Data.Pets or {} :: { [string]: Types.PetInstance } do
		local def = Config.GetPet(pet.Id)
		if def then
			table.insert(list, { Uid = uid, Pet = pet, Def = def, Order = 0, Mult = multOf(pet) })
		end
	end
	table.sort(list, function(a: Entry, b: Entry): boolean
		if a.Pet.Equipped ~= b.Pet.Equipped then
			return a.Pet.Equipped
		end
		if sortMode == "Rarity" and a.Def.Rarity ~= b.Def.Rarity then
			return rarityOrder(a.Def) > rarityOrder(b.Def)
		end
		if a.Mult ~= b.Mult then
			return a.Mult > b.Mult
		end
		if a.Def.Id ~= b.Def.Id then
			return a.Def.Id < b.Def.Id
		end
		return a.Uid < b.Uid
	end)
	return list
end

local function equipBest()
	local list = entries()
	table.sort(list, function(a: Entry, b: Entry): boolean
		return a.Mult > b.Mult
	end)
	local slots = State.GetPetSlots()
	local best: { [string]: boolean } = {}
	for i = 1, math.min(slots, #list) do
		best[list[i].Uid] = true
	end
	local changed = false
	for _, entry in list do
		if entry.Pet.Equipped and not best[entry.Uid] then
			Remotes.Get("UnequipPet"):FireServer(entry.Uid)
			changed = true
		end
	end
	for _, entry in list do
		if best[entry.Uid] and not entry.Pet.Equipped then
			Remotes.Get("EquipPet"):FireServer(entry.Uid)
			changed = true
		end
	end
	if not changed then
		Toasts.Show("Your best pets are already equipped! 🐾", "Info")
	end
end

local function refreshDetail()
	local uid = selectedUid
	local pet = if uid then State.Data.Pets[uid] else nil
	local def = if pet then Config.GetPet(pet.Id) else nil
	if not uid or not pet or not def then
		view:SetModel(nil)
		shownModelFor = nil
		nameLabel.Text = "Pick a pet!"
		infoLabel.Text = "Tap a pet to see it here."
		digLabel.Text = ""
		equipButton:SetVisible(false)
		deleteButton:SetVisible(false)
		fuseButton:SetVisible(false)
		return
	end
	local p = pet :: Types.PetInstance
	local d = def :: Types.PetDef
	local golden = p.Golden == true
	if shownModelFor ~= uid then
		shownModelFor = uid
		local model = ModelFactory.Pet(d.Id)
		view:SetModel(if golden then ModelFactory.MakeGolden(model) else model)
		Style.Pop(view.Frame, 0.15)
	end
	local rarity = Config.GetRarity(d.Rarity)
	nameLabel.Text = (if golden then "Golden " else "") .. d.Name
	nameLabel.TextColor3 = if golden then C.Gold elseif rarity then rarity.Color else C.Text
	infoLabel.Text = d.Rarity
		.. "  ·  x"
		.. string.format("%.2f", multOf(p))
		.. " sand"
		.. (if d.Rideable then "  ·  Rideable!" else "")
	digLabel.Text = digInfo(d, golden) or ""
	-- v2.2 fusion: N identical non-golden copies -> one Golden pet
	fuseButton:SetVisible(not golden)
	if not golden then
		local copies = copiesOf(d.Id)
		local need = Config.GOLDEN_FUSE_COUNT
		fuseButton:SetEnabled(copies >= need)
		fuseButton:SetText(
			if copies >= need
				then string.format("Fuse %d → Golden", need)
				else string.format("Golden: %d/%d copies", copies, need)
		)
	end
	equipButton:SetVisible(true)
	deleteButton:SetVisible(true)
	if p.Equipped then
		equipButton:SetText("Unequip")
		equipButton:SetColor(C.Warning)
		equipButton:SetEnabled(true)
	else
		equipButton:SetText("Equip")
		equipButton:SetColor(C.Success)
		equipButton:SetEnabled(#State.GetEquippedPetIds() < State.GetPetSlots())
		if not equipButton.Enabled then
			equipButton:SetText("Slots full")
		end
	end
	deleteButton:SetText(if confirmDelete then "Sure? 🗑️" else "Delete")
	deleteButton:SetEnabled(not p.Equipped)
end

local function refreshGrid()
	if not built then
		return
	end
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local list = entries()
	emptyLabel.Visible = #list == 0
	for i, entry in list do
		local rarity = Config.GetRarity(entry.Def.Rarity)
		local card = Card.new({
			Name = entry.Uid,
			LayoutOrder = i,
			Gradient = if rarity then rarity.Gradient else nil,
			ZIndex = 6,
			Parent = grid,
		})
		if entry.Uid == selectedUid then
			card:SetHighlight(C.Gold)
		elseif entry.Pet.Golden then
			card.Stroke.Color = C.Gold
		end
		if entry.Pet.Golden then
			local tag = Style.Label({
				Name = "GoldenTag",
				Text = "GOLDEN",
				Size = UDim2.new(1, -8, 0, 16),
				Position = UDim2.new(0.5, 0, 0.62, 0),
				AnchorPoint = Vector2.new(0.5, 1),
				TextColor = C.Gold,
				StrokeThickness = 2,
				MaxTextSize = 14,
				ZIndex = 9,
				Parent = card.Face,
			})
			tag.Rotation = -6
		end
		AtlasIcon.new({
			Icon = petIcon(entry.Def),
			Size = UDim2.new(1, -10, 0.6, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = 8,
			Parent = card.Face,
		})
		Style.Label({
			Text = "x" .. string.format("%.2f", entry.Mult),
			Size = UDim2.new(1, -8, 0.3, 0),
			Position = UDim2.new(0.5, 0, 1, -4),
			AnchorPoint = Vector2.new(0.5, 1),
			Font = Style.Fonts.Number,
			MaxTextSize = 17,
			ZIndex = 8,
			Parent = card.Face,
		})
		-- digging pet / rideable badges (atlas icons "Dig" / "Ride"), top-left
		if entry.Def.Dig or entry.Def.Rideable then
			local badges = Instance.new("Frame")
			badges.Name = "Badges"
			badges.BackgroundTransparency = 1
			badges.Size = UDim2.fromOffset(52, 26)
			badges.Position = UDim2.fromOffset(2, 2)
			badges.ZIndex = 9
			badges.Parent = card.Face
			Style.List(badges, Enum.FillDirection.Horizontal, 0, Enum.HorizontalAlignment.Left)
			local keys: { string } = {}
			if entry.Def.Dig then
				table.insert(keys, "Dig")
			end
			if entry.Def.Rideable then
				table.insert(keys, "Ride")
			end
			for i, key in keys do
				AtlasIcon.new({
					Icon = key,
					Size = UDim2.fromOffset(26, 26),
					LayoutOrder = i,
					ZIndex = 9,
					Parent = badges,
				})
			end
		end
		if entry.Pet.Equipped then
			AtlasIcon.new({
				Name = "Equipped",
				Icon = "Check",
				Size = UDim2.fromOffset(28, 28),
				Position = UDim2.new(1, -2, 0, 2),
				AnchorPoint = Vector2.new(1, 0),
				ZIndex = 9,
				Parent = card.Face,
			})
		end
		local hit = Instance.new("TextButton")
		hit.Name = "Face"
		hit.Text = ""
		hit.BackgroundTransparency = 1
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = 10
		hit.Parent = card.Face
		hit.Activated:Connect(function()
			if selectedUid ~= entry.Uid then
				selectedUid = entry.Uid
				confirmDelete = false
				refreshGrid()
			end
		end)
	end
	local equipped = #State.GetEquippedPetIds()
	equippedLabel.Text = "Equipped "
		.. equipped
		.. "/"
		.. State.GetPetSlots()
		.. "   ·   "
		.. #list
		.. "/"
		.. Config.PET_INVENTORY_LIMIT
	bonusLabel.Text = "Bonus x" .. string.format("%.2f", State.GetPetMultiplier())
	if selectedUid and not State.Data.Pets[selectedUid :: string] then
		selectedUid = nil
	end
	if not selectedUid and list[1] then
		selectedUid = list[1].Uid
	end
	refreshDetail()
end

local function build()
	if built then
		return
	end
	built = true
	local body = panel.Body

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 50)
	header.ZIndex = 5
	header.Parent = body
	equippedLabel = Style.Label({
		Text = "",
		Size = UDim2.new(0, 260, 0, 24),
		Position = UDim2.fromOffset(4, 0),
		StrokeThickness = 2,
		MaxTextSize = 20,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = header,
	})
	bonusLabel = Style.Label({
		Text = "",
		Size = UDim2.new(0, 260, 0, 22),
		Position = UDim2.fromOffset(4, 26),
		TextColor = C.Palm,
		Font = Style.Fonts.Number,
		StrokeThickness = 2,
		MaxTextSize = 18,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = header,
	})
	Button.new({
		Text = "Equip Best",
		Icon = Icons.Star,
		Size = UDim2.fromOffset(170, 48),
		Position = UDim2.new(1, -180, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		Color = C.Palm,
		MaxTextSize = 18,
		ZIndex = 6,
		Parent = header,
		OnClick = equipBest,
	})
	sortButton = Button.new({
		Text = "Sort: Bonus",
		Size = UDim2.fromOffset(170, 48),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		Color = C.Ocean,
		MaxTextSize = 18,
		ZIndex = 6,
		Parent = header,
		OnClick = function()
			sortMode = if sortMode == "Bonus" then "Rarity" else "Bonus"
			sortButton:SetText("Sort: " .. sortMode)
			refreshGrid()
		end,
	})

	grid = Panel.Scroller(body, UDim2.new(1, -250, 1, -58), UDim2.fromOffset(0, 58))
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(94, 104)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	emptyLabel = Style.Label({
		Text = "No pets yet!\nHatch an egg!",
		Size = UDim2.new(1, -250, 0, 80),
		Position = UDim2.fromOffset(0, 120),
		TextColor = C.Sand,
		StrokeThickness = 2,
		Wrapped = true,
		MaxTextSize = 26,
		ZIndex = 6,
		Parent = body,
	})

	local side = Card.new({
		Name = "Detail",
		Size = UDim2.new(0, 236, 1, -58),
		Position = UDim2.new(1, 0, 0, 58),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 5,
		Parent = body,
	})
	local stage = Instance.new("Frame")
	stage.Size = UDim2.new(1, -20, 0, 110)
	stage.Position = UDim2.fromOffset(10, 10)
	stage.ZIndex = 7
	stage.Parent = side.Face
	Style.Corner(stage, Style.Theme.CornerMedium)
	Style.Stroke(stage, C.Stroke, 3)
	stage.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.Gradient(stage, { C.Sky, C.Ocean }, 90)
	view = Viewport.new({ Size = UDim2.fromScale(1, 1), Spin = true, ZIndex = 8, Pitch = 12, Parent = stage })
	nameLabel = Style.Label({
		Text = "",
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.fromOffset(8, 124),
		MaxTextSize = 24,
		ZIndex = 7,
		Parent = side.Face,
	})
	infoLabel = Style.Label({
		Text = "",
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 154),
		Font = Style.Fonts.Body,
		StrokeThickness = 2,
		MaxTextSize = 16,
		ZIndex = 7,
		Parent = side.Face,
	})
	digLabel = Style.Label({
		Text = "",
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 176),
		TextColor = C.Sand,
		Font = Style.Fonts.Body,
		StrokeThickness = 2,
		MaxTextSize = 14,
		ZIndex = 7,
		Parent = side.Face,
	})
	digLabel.Name = "DigInfo"
	fuseButton = Button.new({
		Name = "Fuse",
		Text = "Fuse",
		Size = UDim2.new(1, -20, 0, 46),
		Position = UDim2.fromOffset(10, 200),
		MaxTextSize = 18,
		Color = C.Gold,
		ZIndex = 7,
		Parent = side.Face,
		OnClick = function()
			local uid = selectedUid
			local pet = if uid then State.Data.Pets[uid] else nil
			if uid and pet and pet.Golden ~= true and copiesOf(pet.Id) >= Config.GOLDEN_FUSE_COUNT then
				Remotes.Get("FusePets"):FireServer(uid)
			end
		end,
	})
	equipButton = Button.new({
		Text = "Equip",
		Size = UDim2.new(0.5, -14, 0, 76),
		Position = UDim2.new(0, 10, 1, -10),
		AnchorPoint = Vector2.new(0, 1),
		MaxTextSize = 22,
		Color = C.Success,
		ZIndex = 7,
		Parent = side.Face,
		OnClick = function()
			local uid = selectedUid
			local pet = if uid then State.Data.Pets[uid] else nil
			if uid and pet then
				Remotes.Get(if pet.Equipped then "UnequipPet" else "EquipPet"):FireServer(uid)
			end
		end,
	})
	deleteButton = Button.new({
		Text = "Delete",
		Size = UDim2.new(0.5, -14, 0, 76),
		Position = UDim2.new(1, -10, 1, -10),
		AnchorPoint = Vector2.new(1, 1),
		Color = C.Danger,
		MaxTextSize = 20,
		ZIndex = 7,
		Parent = side.Face,
		OnClick = function()
			local uid = selectedUid
			if not uid then
				return
			end
			if not confirmDelete then
				confirmDelete = true
				refreshDetail()
				task.delay(3, function()
					if confirmDelete and selectedUid == uid then
						confirmDelete = false
						refreshDetail()
					end
				end)
				return
			end
			confirmDelete = false
			Remotes.Get("DeletePet"):FireServer(uid)
		end,
	})
end

function PetsPanel.Init()
	panel =
		Panel.new({ Name = "Pets", Title = "Pets", Icon = Icons.Pets, Color = C.Coral, Size = Vector2.new(800, 480) })
	panel.Opened:Connect(function()
		build()
		refreshGrid()
	end)
	State.ObserveMany({ "Pets", "PetSlots", "Passes" }, function()
		if built and panel.IsOpen then
			refreshGrid()
		end
	end)
end

return PetsPanel
