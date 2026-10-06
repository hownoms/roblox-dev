--!strict
--[[
	DailyPanel — 7-day streak (docs/UI_STYLE.md "Daily rewards"): a horizontal row of day cards
	("DAY N", big atlas icon, amount coloured by type: green coins, sky-blue boosts, gold pets/
	eggs, mint tokens). Today's card gets a gold outline + pulse, claimed days a check overlay,
	Day 7 is a wider jackpot card. A big green CLAIM button below (countdown when not ready).
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
local AtlasIcon = require(Components.AtlasIcon)
local Icons = require(script.Parent.Parent.Icons)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local Progress = require(script.Parent.Parent.Parent.Util.Progress)

local DailyPanel = {}

local C = Style.Colors

local DAY = Vector2.new(92, 214)
local JACKPOT_W = 152

type Tile = {
	Card: Card.Card,
	Claimed: Frame,
	Today: TextLabel,
	Amount: TextLabel,
	Sub: TextLabel,
	Def: Types.DailyRewardDef,
	Pulse: Tween?,
}

local panel: Panel.Panel
local built = false
local tiles: { Tile } = {}
local claimButton: Button.Button
local streakLabel: TextLabel

-- (icon key, amount text, amount colour, sub line) for a reward
local function describe(reward: Types.Reward): (string, string, Color3, string)
	local coins = Config.ResolveCoins(reward, State.Data.MaxDepth)
	local boost = if reward.Boost then Config.GetBoost(reward.Boost) else nil
	local boostText = if boost then boost.Name .. " " .. math.floor((reward.BoostSeconds or 0) / 60) .. "m" else ""
	if reward.Pet then
		local pet = Config.GetPet(reward.Pet)
		return if pet then "PetShapes." .. pet.Look.Shape else "Pets",
			if pet then pet.Name else reward.Pet,
			C.Gold,
			boostText
	elseif reward.Egg then
		local egg = Config.GetEgg(reward.Egg)
		return "Eggs", "x" .. (reward.EggCount or 1), C.Gold, if egg then egg.Name else ""
	elseif boost then
		return "BoostKinds." .. boost.Kind, math.floor((reward.BoostSeconds or 0) / 60) .. " min", C.Time, boost.Name
	elseif coins > 0 then
		local tokens = reward.RebirthTokens or 0
		return "Coins",
			Format.Abbreviate(coins),
			C.Money,
			if tokens > 0 then "+" .. tokens .. " Token" .. (if tokens > 1 then "s" else "") else "Coins"
	elseif reward.RebirthTokens then
		return "Tokens", "+" .. reward.RebirthTokens, C.Tokens, "Tokens"
	end
	return "gift", "", C.Text, ""
end

local function refresh()
	if not built then
		return
	end
	local status = Progress.Daily(State.Data)
	local streak = if status.Broken then 0 else State.Data.DailyStreak
	streakLabel.Text = "Streak: "
		.. streak
		.. " day"
		.. (if streak == 1 then "" else "s")
		.. (if status.Broken and State.Data.DailyStreak > 0 then "  (reset — come back every day!)" else "")
	for day, tile in tiles do
		local claimed = day <= status.ClaimedThroughDay
		local isNext = day == status.NextDay
		tile.Card:SetHighlight(if isNext then C.Gold else nil)
		tile.Claimed.Visible = claimed
		tile.Today.Visible = isNext
		tile.Today.Text = if status.CanClaim then "TODAY!" else Format.Time(status.NextIn)
		local _, amount, _, sub = describe(tile.Def.Reward)
		tile.Amount.Text = amount
		tile.Sub.Text = sub
		if isNext and status.CanClaim and not tile.Pulse then
			tile.Pulse = Style.Pulse(tile.Card.Holder, 0.05, 0.9)
		elseif not (isNext and status.CanClaim) and tile.Pulse then
			Style.StopPulse(tile.Card.Holder, tile.Pulse)
			tile.Pulse = nil
		end
	end
	claimButton:SetEnabled(status.CanClaim and State.Loaded)
	claimButton:SetText(if status.CanClaim then "CLAIM!" else "Next in " .. Format.Time(status.NextIn))
end

local function build()
	if built then
		return
	end
	built = true
	local body = panel.Body
	streakLabel = Style.Label({
		Name = "Streak",
		Text = "",
		Size = UDim2.new(1, 0, 0, 30),
		TextColor = C.Highlight,
		MaxTextSize = 24,
		StrokeThickness = 2.5,
		ZIndex = 6,
		Parent = body,
	})
	local row = Instance.new("Frame")
	row.Name = "Days"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, DAY.Y + 10)
	row.Position = UDim2.fromOffset(0, 40)
	row.ZIndex = 5
	row.Parent = body
	Style.List(row, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	for i, def in Config.DailyRewards do
		local jackpot = i == #Config.DailyRewards
		local card = Card.new({
			Name = "Day" .. i,
			Size = UDim2.fromOffset(if jackpot then JACKPOT_W else DAY.X, DAY.Y),
			LayoutOrder = i,
			Gradient = if jackpot then { C.Gold, C.Sunset } else nil,
			ZIndex = 6,
			Parent = row,
		})
		Style.Label({
			Name = "Day",
			Text = "DAY " .. i,
			Size = UDim2.new(1, -8, 0, 28),
			Position = UDim2.fromOffset(4, 6),
			MaxTextSize = 22,
			StrokeThickness = 2.5,
			ZIndex = 8,
			Parent = card.Face,
		})
		local icon, amountText, amountColor, sub = describe(def.Reward)
		AtlasIcon.new({
			Name = "RewardIcon",
			Icon = icon,
			Size = UDim2.new(1, -10, 0, if jackpot then 100 else 80),
			Position = UDim2.new(0.5, 0, 0, if jackpot then 84 else 76),
			ZIndex = 8,
			Parent = card.Face,
		})
		local amount = Style.Label({
			Name = "Amount",
			Text = amountText,
			Size = UDim2.new(1, -8, 0, 30),
			Position = UDim2.new(0.5, 0, 1, -40),
			AnchorPoint = Vector2.new(0.5, 1),
			TextColor = amountColor,
			MaxTextSize = 24,
			StrokeThickness = 3,
			ZIndex = 8,
			Parent = card.Face,
		})
		local subLabel = Style.Label({
			Name = "Sub",
			Text = sub,
			Size = UDim2.new(1, -8, 0, 28),
			Position = UDim2.new(0.5, 0, 1, -8),
			AnchorPoint = Vector2.new(0.5, 1),
			Font = Style.Fonts.Body,
			Wrapped = true,
			MaxTextSize = 12,
			StrokeThickness = 1.5,
			ZIndex = 8,
			Parent = card.Face,
		})
		local claimed = Instance.new("Frame")
		claimed.Name = "Claimed"
		claimed.BackgroundColor3 = C.NavyDark
		claimed.BackgroundTransparency = 0.35
		claimed.Size = UDim2.fromScale(1, 1)
		claimed.ZIndex = 10
		claimed.Visible = false
		claimed.Parent = card.Face
		Style.Corner(claimed, Style.Theme.CornerMedium)
		AtlasIcon.new({
			Name = "Check",
			Icon = "Check",
			Size = UDim2.fromScale(0.7, 0.5),
			ZIndex = 11,
			Parent = claimed,
		})
		local today = Style.Label({
			Name = "Today",
			Text = "TODAY!",
			Size = UDim2.new(1, 8, 0, 26),
			Position = UDim2.new(0.5, 0, 0, -14),
			AnchorPoint = Vector2.new(0.5, 0),
			MaxTextSize = 17,
			StrokeThickness = 2,
			ZIndex = 12,
			Parent = card.Holder,
		})
		today.BackgroundTransparency = 0
		today.BackgroundColor3 = C.Coral
		today.Visible = false
		Style.Corner(today, Style.Theme.CornerPill)
		Style.Stroke(today, C.Stroke, 2)
		table.insert(
			tiles,
			{ Card = card, Claimed = claimed, Today = today, Amount = amount, Sub = subLabel, Def = def, Pulse = nil }
		)
	end
	claimButton = Button.new({
		Name = "Claim",
		Text = "CLAIM!",
		Icon = "gift",
		Size = UDim2.fromOffset(320, 84),
		Position = UDim2.new(0.5, 0, 1, 0),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Success,
		MaxTextSize = 34,
		ZIndex = 6,
		Sound = "Purchase",
		Parent = body,
		OnClick = function()
			Remotes.Get("ClaimDailyReward"):FireServer()
		end,
	})
end

function DailyPanel.Init()
	panel = Panel.new({
		Name = "Daily",
		Title = "Daily Rewards",
		Icon = Icons.Daily,
		Color = C.Gold,
		Size = Vector2.new(820, 450),
	})
	panel.Opened:Connect(function()
		build()
		refresh()
	end)
	State.ObserveMany({ "DailyStreak", "LastDailyClaim" }, function()
		if built then
			refresh()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if built and panel.IsOpen then
				refresh()
			end
		end
	end)
	-- Gentle nudge: open the calendar once per session when a reward is waiting.
	State.LoadedSignal:Connect(function()
		task.wait(6)
		if Progress.Daily(State.Data).CanClaim and not Panel.Current() and State.Data.TotalSandDug > 0 then
			panel:Open()
		end
	end)
end

return DailyPanel
