--!strict
-- RebirthPanel — cost + progress bar, multiplier now -> after, tokens gained, what resets and
-- what you keep, a Rebirth button with a second-tap confirm, and the Skip Rebirth product.
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
local ProgressBar = require(Components.ProgressBar)
local Icons = require(script.Parent.Parent.Icons)
local Banner = require(script.Parent.Parent.Banner)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local PurchaseController = require(script.Parent.Parent.Parent.Controllers.PurchaseController)

local RebirthPanel = {}

local C = Style.Colors

local panel: Panel.Panel
local built = false
local confirm = false
local multLabel: TextLabel
local tokensLabel: TextLabel
local bar: ProgressBar.ProgressBar
local rebirthButton: Button.Button
local skipButton: Button.Button

local function refresh()
	if not built then
		return
	end
	local data = State.Data
	local n = data.Rebirths
	local cost = Config.RebirthCost(n)
	multLabel.Text = string.format("x%.1f  ➜  x%.1f", Config.RebirthMultiplier(n), Config.RebirthMultiplier(n + 1))
	tokensLabel.Text = "+"
		.. Config.RebirthTokens(n)
		.. " "
		.. Icons.Tokens
		.. " Rebirth Token(s)   ·   Rebirths: "
		.. n
	bar:Set(data.Coins / cost, Icons.Coins .. " " .. Format.Abbreviate(data.Coins) .. " / " .. Format.Abbreviate(cost))
	bar:SetColor(if data.Coins >= cost then C.Success else C.Gold)
	local can = data.Coins >= cost
	rebirthButton:SetEnabled(can)
	rebirthButton:SetText(
		if not can
			then "Need " .. Format.Abbreviate(cost - data.Coins) .. " more"
			elseif confirm then "Tap again to REBIRTH!"
			else "Rebirth!"
	)
	skipButton:SetVisible(PurchaseController.IsProductConfigured("SkipRebirth"))
end

local function listCard(parent: Instance, title: string, lines: string, color: Color3, x: number)
	local card = Card.new({
		Size = UDim2.new(0.5, -8, 0, 120),
		Position = UDim2.new(x, if x > 0 then 8 else 0, 0, 120),
		Color = color,
		ZIndex = 6,
		Parent = parent,
	})
	Style.Label({
		Text = title,
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 6),
		MaxTextSize = 20,
		ZIndex = 8,
		Parent = card.Face,
	})
	Style.Label({
		Text = lines,
		Size = UDim2.new(1, -16, 1, -40),
		Position = UDim2.fromOffset(8, 34),
		Font = Style.Fonts.Body,
		Wrapped = true,
		MaxTextSize = 15,
		YAlign = Enum.TextYAlignment.Top,
		ZIndex = 8,
		Parent = card.Face,
	})
end

local function build()
	if built then
		return
	end
	built = true
	local body = panel.Body
	multLabel = Style.Label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 50),
		TextColor = C.Purple,
		StrokeColor = C.Stroke,
		MaxTextSize = 44,
		ZIndex = 6,
		Parent = body,
	})
	tokensLabel = Style.Label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 50),
		TextColor = C.TextDark,
		Font = Style.Fonts.Body,
		Stroke = false,
		MaxTextSize = 17,
		ZIndex = 6,
		Parent = body,
	})
	bar = ProgressBar.new({
		Size = UDim2.new(1, -40, 0, 34),
		Position = UDim2.new(0.5, 0, 0, 78),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = C.Gold,
		ZIndex = 6,
		Parent = body,
	})
	listCard(
		body,
		"🔄 Resets",
		"Coins, sand, shovels, backpacks and unsold treasures. Your hole is refilled.",
		C.Coral,
		0
	)
	listCard(
		body,
		"💖 You keep",
		"Pets, Index, depth record, quests, boosts, tokens — and +"
			.. Config.Rebirths.MultiplierPerRebirth
			.. "x sand & backpack space FOREVER!",
		C.Palm,
		0.5
	)
	rebirthButton = Button.new({
		Text = "Rebirth!",
		Icon = Icons.Rebirth,
		Size = UDim2.fromOffset(330, 64),
		Position = UDim2.new(0.5, -90, 1, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Purple,
		MaxTextSize = 24,
		ZIndex = 6,
		Parent = body,
		OnClick = function()
			if not confirm then
				confirm = true
				refresh()
				task.delay(3, function()
					confirm = false
					refresh()
				end)
				return
			end
			confirm = false
			Remotes.Get("Rebirth"):FireServer()
		end,
	})
	skipButton = Button.new({
		Text = "Skip R$ " .. Config.Monetization.Products.SkipRebirth.Price,
		Size = UDim2.fromOffset(170, 64),
		Position = UDim2.new(1, -10, 1, -4),
		AnchorPoint = Vector2.new(1, 1),
		Color = C.Robux,
		MaxTextSize = 20,
		ZIndex = 6,
		Parent = body,
		OnClick = function()
			PurchaseController.PromptProduct("SkipRebirth")
		end,
	})
end

function RebirthPanel.Init()
	panel = Panel.new({
		Name = "Rebirth",
		Title = "Rebirth",
		Icon = Icons.Rebirth,
		Color = C.Purple,
		Size = Vector2.new(700, 440),
	})
	panel.Opened:Connect(function()
		build()
		confirm = false
		refresh()
	end)
	State.ObserveMany({ "Coins", "Rebirths" }, refresh)
	State.Changed("Rebirths"):Connect(function(new: any, old: any)
		if typeof(new) == "number" and typeof(old) == "number" and new > old then
			panel:Close()
			Banner.Show({
				Title = "REBIRTH " .. new .. "! ♻️",
				Subtitle = string.format(
					"Everything is now x%.1f — dig back down, faster!",
					Config.RebirthMultiplier(new)
				),
				Tag = "NEW MULTIPLIER",
				Color = C.Purple,
				Sound = "Rebirth",
				Confetti = true,
				Duration = 4,
			})
		end
	end)
end

return RebirthPanel
