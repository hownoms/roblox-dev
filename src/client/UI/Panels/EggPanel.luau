--!strict
--[[
	EggPanel — egg list (left) + selected egg detail (right): spinning egg preview, price,
	full odds table (every pet with % chance, rarity colour, bonus — required odds disclosure),
	Hatch x1 / Hatch x3 buttons. x3 needs the Triple Hatch pass (prompts it if configured).
	Robux eggs prompt their developer product (disabled while its id is 0).
	Panel.Open("Eggs", { EggId = "pirate_egg" }) focuses a specific egg (map pedestals).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local Components = script.Parent.Parent.Components
local Style = require(Components.Style)
local Panel = require(Components.Panel)
local Button = require(Components.Button)
local Card = require(Components.Card)
local Viewport = require(Components.Viewport)
local Icons = require(script.Parent.Parent.Icons)
local HatchAnimation = require(script.Parent.Parent.HatchAnimation)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local PurchaseController = require(script.Parent.Parent.Parent.Controllers.PurchaseController)
local ModelFactory = require(script.Parent.Parent.Parent.Util.ModelFactory)

local EggPanel = {}

local C = Style.Colors

local panel: Panel.Panel
local built = false
local selected: string = Config.Eggs[1].Id
local tiles: { [string]: { Card: Card.Card, Price: TextLabel, Lock: TextLabel } } = {}
local detail: {
	View: Viewport.Viewport,
	Name: TextLabel,
	Price: TextLabel,
	Odds: ScrollingFrame,
	Hatch1: Button.Button,
	Hatch3: Button.Button,
}? = nil
local shownEgg: string? = nil

local function currencyIcon(egg: Types.EggDef): string
	return if egg.Currency == "Tokens" then Icons.Tokens elseif egg.Currency == "Robux" then Icons.Robux else Icons.Coins
end

local function balance(egg: Types.EggDef): number
	if egg.Currency == "Tokens" then
		return State.Data.RebirthTokens
	elseif egg.Currency == "Coins" then
		return State.Data.Coins
	end
	return 0
end

local function priceText(egg: Types.EggDef, count: number): string
	if egg.Currency == "Robux" then
		return "R$ " .. egg.Price * count
	end
	return currencyIcon(egg) .. " " .. Format.Abbreviate(egg.Price * count)
end

local function petCount(): number
	local n = 0
	for _ in State.Data.Pets or {} :: { [string]: Types.PetInstance } do
		n += 1
	end
	return n
end

-- Robux product that hatches `count` of this egg (via Grant.Egg / EggCount), if any.
local function productFor(egg: Types.EggDef, count: number): string?
	if count == 1 and egg.ProductKey then
		return egg.ProductKey
	end
	for key, product in Config.Monetization.Products do
		if product.Grant.Egg == egg.Id and (product.Grant.EggCount or 1) == count then
			return key
		end
	end
	return nil
end

local function oddsText(weight: number, total: number): string
	local pct = weight / total * 100
	if pct >= 10 then
		return string.format("%.0f%%", pct)
	elseif pct >= 1 then
		return string.format("%.1f%%", pct)
	end
	return string.format("%.2f%%", pct)
end

local function hatch(egg: Types.EggDef, count: number)
	if egg.Currency == "Robux" then
		local key = productFor(egg, count)
		if key then
			HatchAnimation.SetPendingEgg(egg.Id)
			PurchaseController.PromptProduct(key)
		end
		return
	end
	HatchAnimation.SetPendingEgg(egg.Id)
	Remotes.Get("HatchEgg"):FireServer(egg.Id, count)
end

local function updateButtons()
	local d = detail
	local maybeEgg = Config.GetEgg(selected)
	if not d or not maybeEgg then
		return
	end
	local egg = maybeEgg :: Types.EggDef
	local dd = d :: any
	local hatch1: Button.Button = dd.Hatch1
	local hatch3: Button.Button = dd.Hatch3
	local unlocked = Config.IsEggUnlocked(egg.Id, State.Data.MaxDepth)
	local full = petCount() >= Config.PET_INVENTORY_LIMIT
	if egg.Currency == "Robux" then
		local key1 = productFor(egg, 1)
		local key3 = productFor(egg, 3)
		local ok1 = key1 ~= nil and PurchaseController.IsProductConfigured(key1 :: string)
		local ok3 = key3 ~= nil and PurchaseController.IsProductConfigured(key3 :: string)
		hatch1:SetEnabled(ok1 and not full)
		hatch1:SetText(if ok1
			then "Hatch 1  R$ " .. Config.Monetization.Products[key1 :: string].Price
			else "Coming soon")
		hatch3:SetVisible(key3 ~= nil)
		hatch3:SetEnabled(ok3 and not full)
		hatch3:SetText(if ok3
			then "Hatch 3  R$ " .. Config.Monetization.Products[key3 :: string].Price
			else "Coming soon")
		return
	end
	local have = balance(egg)
	if not unlocked then
		local layer = Config.Layers[egg.UnlockLayer]
		hatch1:SetEnabled(false)
		hatch1:SetText(Icons.Lock .. " Reach " .. layer.Name)
		hatch3:SetVisible(false)
		return
	end
	if full then
		hatch1:SetEnabled(false)
		hatch1:SetText("Pet bag full!")
		hatch3:SetVisible(false)
		return
	end
	hatch1:SetEnabled(have >= egg.Price)
	hatch1:SetText("Hatch 1  " .. priceText(egg, 1))
	local owns3 = State.OwnsPass("TripleHatch")
	local passOk = PurchaseController.IsPassConfigured("TripleHatch")
	hatch3:SetVisible(owns3 or passOk)
	if owns3 then
		hatch3:SetEnabled(have >= egg.Price * Config.TRIPLE_HATCH_COUNT)
		hatch3:SetColor(C.Purple)
		hatch3:SetText("Hatch 3  " .. priceText(egg, Config.TRIPLE_HATCH_COUNT))
	else
		hatch3:SetEnabled(true)
		hatch3:SetColor(C.Robux)
		hatch3:SetText(Icons.Lock .. " Hatch 3 (pass)")
	end
end

local function showEgg(eggId: string)
	local maybeEgg = Config.GetEgg(eggId)
	local d = detail
	if not maybeEgg or not d then
		return
	end
	local egg = maybeEgg :: Types.EggDef
	selected = eggId
	local dd = d :: any
	for id, tile in tiles do
		tile.Card:SetHighlight(if id == eggId then C.Gold else nil)
	end
	if shownEgg ~= eggId then
		shownEgg = eggId
		;(dd.View :: Viewport.Viewport):SetModel(ModelFactory.Egg(eggId))
		Style.Pop((dd.View :: Viewport.Viewport).Frame, 0.15)
		;(dd.Name :: TextLabel).Text = egg.Name
		local odds: ScrollingFrame = dd.Odds
		for _, child in odds:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local total = 0
		for _, entry in egg.Pets do
			total += entry.Weight
		end
		for i, entry in egg.Pets do
			local pet = Config.GetPet(entry.PetId)
			if pet then
				local rarity = Config.GetRarity(pet.Rarity)
				local row = Card.new({
					Name = pet.Id,
					Size = UDim2.new(1, -8, 0, 46),
					LayoutOrder = i,
					Gradient = if rarity then rarity.Gradient else nil,
					GradientRotation = 0,
					ZIndex = 6,
					Parent = odds,
				})
				Style.Label({
					Text = Icons.PetShape(pet.Look.Shape) .. " " .. pet.Name,
					Size = UDim2.new(0.55, 0, 0.8, 0),
					Position = UDim2.new(0, 10, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					MaxTextSize = 18,
					XAlign = Enum.TextXAlignment.Left,
					ZIndex = 8,
					Parent = row.Face,
				})
				Style.Label({
					Text = "x" .. string.format("%.2f", pet.Multiplier),
					Size = UDim2.new(0.2, 0, 0.7, 0),
					Position = UDim2.new(0.58, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Font = Style.Fonts.Number,
					MaxTextSize = 16,
					ZIndex = 8,
					Parent = row.Face,
				})
				Style.Label({
					Text = oddsText(entry.Weight, total),
					Size = UDim2.new(0.2, 0, 0.75, 0),
					Position = UDim2.new(1, -10, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					Font = Style.Fonts.Number,
					MaxTextSize = 20,
					XAlign = Enum.TextXAlignment.Right,
					ZIndex = 8,
					Parent = row.Face,
				})
			end
		end
	end
	local unlocked = Config.IsEggUnlocked(egg.Id, State.Data.MaxDepth)
	;(dd.Price :: TextLabel).Text = if unlocked or egg.Currency == "Robux"
		then priceText(egg, 1) .. " each"
		else Icons.Lock .. " Unlocks at " .. Config.Layers[egg.UnlockLayer].Name
	updateButtons()
end

local function build()
	if built then
		return
	end
	built = true
	local body = panel.Body

	local list = Panel.Scroller(body, UDim2.new(0, 250, 1, 0), UDim2.new())
	Style.List(list, Enum.FillDirection.Vertical, 8)
	for i, egg in Config.Eggs do
		local card = Card.new({ Name = egg.Id, Size = UDim2.new(1, -14, 0, 64), LayoutOrder = i, ZIndex = 6, Parent = list })
		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.fromOffset(42, 50)
		swatch.Position = UDim2.new(0, 8, 0.5, 0)
		swatch.AnchorPoint = Vector2.new(0, 0.5)
		swatch.BackgroundColor3 = egg.Look.ShellColor
		swatch.ZIndex = 8
		swatch.Parent = card.Face
		Style.Corner(swatch, UDim.new(0.5, 0))
		Style.Stroke(swatch, C.Stroke, 2)
		Style.Gradient(swatch, { Color3.new(1, 1, 1), egg.Look.SpotColor:Lerp(Color3.new(1, 1, 1), 0.4) }, 90)
		Style.Label({
			Text = egg.Name,
			Size = UDim2.new(1, -66, 0, 26),
			Position = UDim2.fromOffset(58, 6),
			TextColor = C.TextDark,
			Stroke = false,
			MaxTextSize = 19,
			XAlign = Enum.TextXAlignment.Left,
			ZIndex = 8,
			Parent = card.Face,
		})
		local price = Style.Label({
			Text = priceText(egg, 1),
			Size = UDim2.new(1, -66, 0, 22),
			Position = UDim2.fromOffset(58, 32),
			TextColor = C.SandDark,
			Font = Style.Fonts.Number,
			Stroke = false,
			MaxTextSize = 16,
			XAlign = Enum.TextXAlignment.Left,
			ZIndex = 8,
			Parent = card.Face,
		})
		local lock = Style.Label({
			Text = Icons.Lock,
			Size = UDim2.fromOffset(30, 30),
			Position = UDim2.new(1, -8, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Stroke = false,
			ZIndex = 9,
			Parent = card.Face,
		})
		local hit = Instance.new("TextButton")
		hit.Name = "Face"
		hit.Text = ""
		hit.BackgroundTransparency = 1
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = 10
		hit.Parent = card.Face
		hit.Activated:Connect(function()
			showEgg(egg.Id)
		end)
		tiles[egg.Id] = { Card = card, Price = price, Lock = lock }
	end

	local right = Instance.new("Frame")
	right.Name = "Detail"
	right.BackgroundTransparency = 1
	right.Position = UDim2.fromOffset(262, 0)
	right.Size = UDim2.new(1, -262, 1, 0)
	right.ZIndex = 5
	right.Parent = body

	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.Size = UDim2.fromOffset(190, 190)
	stage.BackgroundColor3 = C.Sky
	stage.ZIndex = 5
	stage.Parent = right
	Style.Corner(stage, Style.Theme.CornerLarge)
	Style.Stroke(stage, C.Stroke, 3)
	Style.Gradient(stage, { C.Sky, C.Ocean }, 90)
	local view = Viewport.new({
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Spin = true,
		SpinSpeed = 0.8,
		Pitch = 10,
		Parent = stage,
	})

	local name = Style.Label({
		Text = "",
		Size = UDim2.new(1, -200, 0, 40),
		Position = UDim2.fromOffset(200, 0),
		TextColor = C.TextDark,
		Stroke = false,
		MaxTextSize = 32,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = right,
	})
	local price = Style.Label({
		Text = "",
		Size = UDim2.new(1, -200, 0, 28),
		Position = UDim2.fromOffset(200, 40),
		TextColor = C.SandDark,
		Font = Style.Fonts.Number,
		Stroke = false,
		MaxTextSize = 22,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = right,
	})
	Style.Label({
		Text = "Chances (before luck boosts):",
		Size = UDim2.new(1, -200, 0, 20),
		Position = UDim2.fromOffset(200, 72),
		TextColor = C.TextDark,
		Font = Style.Fonts.Body,
		Stroke = false,
		MaxTextSize = 14,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = right,
	})
	local hatch1 = Button.new({
		Text = "Hatch 1",
		Icon = Icons.Eggs,
		Size = UDim2.fromOffset(190, 56),
		Position = UDim2.fromOffset(0, 200),
		Color = C.Success,
		MaxTextSize = 20,
		ZIndex = 6,
		Parent = right,
		OnClick = function()
			local egg = Config.GetEgg(selected)
			if egg then
				hatch(egg, 1)
			end
		end,
	})
	local hatch3 = Button.new({
		Text = "Hatch 3",
		Icon = "🥚",
		Size = UDim2.fromOffset(190, 56),
		Position = UDim2.fromOffset(0, 266),
		Color = C.Purple,
		MaxTextSize = 18,
		ZIndex = 6,
		Parent = right,
		OnClick = function()
			local maybeEgg = Config.GetEgg(selected)
			if not maybeEgg then
				return
			end
			local egg = maybeEgg :: Types.EggDef
			if egg.Currency ~= "Robux" and not State.OwnsPass("TripleHatch") then
				PurchaseController.PromptPass("TripleHatch")
				return
			end
			hatch(egg, Config.TRIPLE_HATCH_COUNT)
		end,
	})
	local odds = Panel.Scroller(right, UDim2.new(1, -200, 1, -96), UDim2.fromOffset(200, 96))
	Style.List(odds, Enum.FillDirection.Vertical, 6)

	detail = { View = view, Name = name, Price = price, Odds = odds, Hatch1 = hatch1, Hatch3 = hatch3 }
end

local function refreshTiles()
	for id, tile in tiles do
		local egg = Config.GetEgg(id)
		if egg then
			local unlocked = egg.Currency == "Robux" or Config.IsEggUnlocked(id, State.Data.MaxDepth)
			tile.Lock.Visible = not unlocked
			tile.Price.TextColor3 = if egg.Currency ~= "Robux" and balance(egg) < egg.Price then C.Danger else C.SandDark
		end
	end
	updateButtons()
end

function EggPanel.Init()
	panel = Panel.new({ Name = "Eggs", Title = "Eggs", Icon = Icons.Eggs, Color = C.Sunset, Size = Vector2.new(800, 480) })
	panel.Opened:Connect(function(args: any)
		build()
		local target = if typeof(args) == "table" and typeof(args.EggId) == "string" then args.EggId else nil
		if not target then
			-- default: best unlocked coin egg
			for _, egg in Config.Eggs do
				if egg.Currency == "Coins" and Config.IsEggUnlocked(egg.Id, State.Data.MaxDepth) then
					target = egg.Id
				end
			end
		end
		showEgg(target or selected)
		refreshTiles()
	end)
	State.ObserveMany({ "Coins", "RebirthTokens", "MaxDepth", "Passes", "Pets" }, function()
		if built then
			refreshTiles()
		end
	end)
end

return EggPanel
