--!strict
--[[
	TreasurePopup — TreasureFound(treasureId, rarity): a rarity-coloured card slides in on the
	right with the spinning treasure (ViewportFrame + Models.Treasure), name, rarity and value.
	"NEW!" tag on first discovery. Epic+ get a louder sound; Legendary/Mythic flash + confetti.
	Popups queue so rapid finds never overlap.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local Root = require(script.Parent.Root)
local Style = require(script.Parent.Components.Style)
local Card = require(script.Parent.Components.Card)
local Viewport = require(script.Parent.Components.Viewport)
local Icons = require(script.Parent.Icons)
local UIEffects = require(script.Parent.UIEffects)
local State = require(script.Parent.Parent.Controllers.State)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local ModelFactory = require(script.Parent.Parent.Util.ModelFactory)

local TreasurePopup = {}

type Entry = { Id: string, Rarity: string, IsNew: boolean }

local queue: { Entry } = {}
local showing = false
local seen: { [string]: boolean } = {}
local seeded = false

local function seed()
	if seeded or not State.Loaded then
		return
	end
	seeded = true
	for id in State.Data.Index or {} :: { [string]: boolean } do
		seen[id] = true
	end
end

local pump: () -> ()

local function show(entry: Entry)
	showing = true
	local def = Config.GetTreasure(entry.Id)
	local rarity = Config.GetRarity(entry.Rarity) or (if def then Config.GetRarity(def.Rarity) else nil)
	local order = if rarity then rarity.Order else 1

	local card = Card.new({
		Name = "TreasurePopup",
		Size = UDim2.fromOffset(330, 130),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 360, 0.56, 0),
		Gradient = if rarity then rarity.Gradient else nil,
		GradientRotation = 0,
		ZIndex = 25,
		Parent = Root.Get("Popups"),
	})
	local stage = Instance.new("Frame")
	stage.Size = UDim2.fromOffset(110, 110)
	stage.Position = UDim2.fromOffset(10, 8)
	stage.BackgroundColor3 = Color3.new(1, 1, 1)
	stage.BackgroundTransparency = 0.6
	stage.ZIndex = 27
	stage.Parent = card.Face
	Style.Corner(stage, Style.Theme.CornerMedium)
	local view = Viewport.new({ Size = UDim2.fromScale(1, 1), Spin = true, SpinSpeed = 2, ZIndex = 28, Parent = stage })
	view:SetModel(ModelFactory.Treasure(entry.Id))

	local shapeIcon = if def then Icons.TreasureShapes[def.Look.Shape] or "💎" else "💎"
	Style.Label({
		Text = if entry.IsNew then "NEW TREASURE! " .. shapeIcon else "TREASURE! " .. shapeIcon,
		Size = UDim2.new(1, -136, 0, 22),
		Position = UDim2.fromOffset(128, 10),
		MaxTextSize = 18,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 27,
		Parent = card.Face,
	})
	Style.Label({
		Text = if def then def.Name else entry.Id,
		Size = UDim2.new(1, -136, 0, 34),
		Position = UDim2.fromOffset(128, 34),
		MaxTextSize = 28,
		StrokeThickness = 3,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 27,
		Parent = card.Face,
	})
	Style.Label({
		Text = entry.Rarity .. (if def then "  ·  " .. Icons.Coins .. " " .. Format.Abbreviate(def.SellValue) else ""),
		Size = UDim2.new(1, -136, 0, 22),
		Position = UDim2.fromOffset(128, 72),
		Font = Style.Fonts.Body,
		MaxTextSize = 17,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 27,
		Parent = card.Face,
	})
	if def then
		Style.Label({
			Text = def.FlavorText,
			Size = UDim2.new(1, -136, 0, 28),
			Position = UDim2.fromOffset(128, 96),
			Font = Style.Fonts.Body,
			MaxTextSize = 11,
			Wrapped = true,
			XAlign = Enum.TextXAlignment.Left,
			ZIndex = 27,
			Parent = card.Face,
		})
	end

	if order >= 5 then
		SoundController.Play("RareTreasure")
		UIEffects.Flash(if rarity then rarity.Color else nil, 0.6)
		UIEffects.Confetti(50, if rarity then rarity.Gradient else nil)
	elseif order >= 4 then
		SoundController.Play("RareTreasure", 1.2)
	else
		SoundController.Play("Treasure", 1 + order * 0.05)
	end

	Style.Tween(card.Holder, 0.45, { Position = UDim2.new(1, -16, 0.56, 0) }, Enum.EasingStyle.Back)
	Style.Pop(card.Holder, 0.12)
	local hold = if order >= 5 then 4 elseif entry.IsNew then 3 else 2.2
	task.delay(hold, function()
		local out = Style.Tween(
			card.Holder,
			0.3,
			{ Position = UDim2.new(1, 360, 0.56, 0) },
			Enum.EasingStyle.Back,
			Enum.EasingDirection.In
		)
		out.Completed:Once(function()
			card.Holder:Destroy()
			showing = false
			pump()
		end)
	end)
end

pump = function()
	if showing then
		return
	end
	local entry = table.remove(queue, 1)
	if entry then
		show(entry)
	end
end

function TreasurePopup.Show(treasureId: string, rarity: string?)
	seed()
	local def = Config.GetTreasure(treasureId)
	local isNew = not seen[treasureId]
	seen[treasureId] = true
	if #queue >= 4 then
		table.remove(queue, 1)
	end
	local rarityName: string = rarity or (if def then def.Rarity :: string else "Common")
	table.insert(queue, { Id = treasureId, Rarity = rarityName, IsNew = isNew })
	pump()
end

function TreasurePopup.Init()
	State.LoadedSignal:Connect(seed)
	task.spawn(function()
		Remotes.Get("TreasureFound").OnClientEvent:Connect(function(treasureId: any, rarity: any)
			if typeof(treasureId) == "string" then
				TreasurePopup.Show(treasureId, if typeof(rarity) == "string" then rarity else nil)
			end
		end)
	end)
end

return TreasurePopup
