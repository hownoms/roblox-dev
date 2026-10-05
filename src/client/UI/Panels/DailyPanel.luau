--!strict
-- DailyPanel — 7-day streak calendar: claimed days ticked, today's tile glows with a Claim
-- button, otherwise a countdown to the next claim. Day 7 is the big exclusive pet day.
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
local Icons = require(script.Parent.Parent.Icons)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local Progress = require(script.Parent.Parent.Parent.Util.Progress)
local RewardText = require(script.Parent.Parent.Parent.Util.RewardText)

local DailyPanel = {}

local C = Style.Colors

type Tile = { Card: Card.Card, Status: TextLabel, Pulse: Tween? }

local panel: Panel.Panel
local built = false
local tiles: { Tile } = {}
local claimButton: Button.Button
local streakLabel: TextLabel

local function refresh()
	if not built then
		return
	end
	local status = Progress.Daily(State.Data)
	streakLabel.Text = "🔥 Streak: "
		.. (if status.Broken then 0 else State.Data.DailyStreak)
		.. " day"
		.. (if State.Data.DailyStreak == 1 then "" else "s")
		.. (if status.Broken and State.Data.DailyStreak > 0 then "  (streak reset — come back every day!)" else "")
	for day, tile in tiles do
		local claimed = day <= status.ClaimedThroughDay
		local isNext = day == status.NextDay
		tile.Card:SetHighlight(if isNext then C.Gold else nil)
		tile.Card.Face.BackgroundTransparency = if claimed then 0.4 else 0
		if claimed then
			tile.Status.Text = "✅"
		elseif isNext and status.CanClaim then
			tile.Status.Text = "TODAY!"
		elseif isNext then
			tile.Status.Text = Format.Time(status.NextIn)
		else
			tile.Status.Text = "Day " .. day
		end
		if isNext and status.CanClaim and not tile.Pulse then
			tile.Pulse = Style.Pulse(tile.Card.Holder, 0.06, 0.9)
		elseif not (isNext and status.CanClaim) and tile.Pulse then
			Style.StopPulse(tile.Card.Holder, tile.Pulse)
			tile.Pulse = nil
		end
	end
	claimButton:SetEnabled(status.CanClaim and State.Loaded)
	claimButton:SetText(
		if status.CanClaim then "Claim Day " .. status.NextDay .. "!" else "Next in " .. Format.Time(status.NextIn)
	)
end

local function build()
	if built then
		return
	end
	built = true
	local body = panel.Body
	streakLabel = Style.Label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 30),
		TextColor = C.Sunset,
		Stroke = false,
		MaxTextSize = 24,
		ZIndex = 6,
		Parent = body,
	})
	local row = Instance.new("Frame")
	row.Name = "Days"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 250)
	row.Position = UDim2.fromOffset(0, 40)
	row.ZIndex = 5
	row.Parent = body
	Style.List(row, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	for i, def in Config.DailyRewards do
		local big = i == #Config.DailyRewards
		local card = Card.new({
			Name = "Day" .. i,
			Size = UDim2.fromOffset(if big then 120 else 96, if big then 240 else 210),
			LayoutOrder = i,
			Gradient = if big then { C.Gold, C.Sunset } else { C.Panel, C.PanelAlt },
			ZIndex = 6,
			Parent = row,
		})
		Style.Label({
			Text = "DAY " .. i,
			Size = UDim2.new(1, -8, 0, 26),
			Position = UDim2.fromOffset(4, 6),
			TextColor = if big then C.Text else C.TextDark,
			Stroke = big,
			MaxTextSize = 20,
			ZIndex = 8,
			Parent = card.Face,
		})
		local icon = if def.Reward.Pet
			then "🐾"
			elseif def.Reward.Egg then "🥚"
			elseif def.Reward.Boost then "⚡"
			elseif def.Reward.RebirthTokens then Icons.Tokens
			else Icons.Coins
		Style.Icon({
			Text = icon,
			Size = UDim2.new(1, -16, 0, 60),
			Position = UDim2.new(0.5, 0, 0, 36),
			AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = 8,
			Parent = card.Face,
		})
		Style.Label({
			Text = def.Label .. "\n" .. RewardText.Describe(def.Reward, State.Data.MaxDepth, "\n"),
			Size = UDim2.new(1, -10, 0, 70),
			Position = UDim2.fromOffset(5, 100),
			TextColor = if big then C.Text else C.TextDark,
			Font = Style.Fonts.Body,
			Stroke = big,
			Wrapped = true,
			MaxTextSize = 13,
			ZIndex = 8,
			Parent = card.Face,
		})
		local status = Style.Label({
			Text = "",
			Size = UDim2.new(1, -10, 0, 26),
			Position = UDim2.new(0, 5, 1, -32),
			TextColor = C.Palm,
			MaxTextSize = 20,
			ZIndex = 8,
			Parent = card.Face,
		})
		table.insert(tiles, { Card = card, Status = status, Pulse = nil })
	end
	claimButton = Button.new({
		Text = "Claim!",
		Icon = Icons.Daily,
		Size = UDim2.fromOffset(300, 64),
		Position = UDim2.new(0.5, 0, 1, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Success,
		MaxTextSize = 26,
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
		Size = Vector2.new(820, 440),
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
