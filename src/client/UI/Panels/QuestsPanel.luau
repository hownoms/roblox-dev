--!strict
-- QuestsPanel — daily quests (with reset countdown) and milestones: progress bars, rewards,
-- big green Claim buttons; claimed quests sink to the bottom with a tick.
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
local ProgressBar = require(Components.ProgressBar)
local AtlasIcon = require(Components.AtlasIcon)
local Icons = require(script.Parent.Parent.Icons)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local Progress = require(script.Parent.Parent.Parent.Util.Progress)
local RewardText = require(script.Parent.Parent.Parent.Util.RewardText)

local QuestsPanel = {}

local C = Style.Colors

type Row = {
	Quest: Types.QuestDef,
	Card: Card.Card,
	Bar: ProgressBar.ProgressBar,
	Reward: TextLabel,
	Claim: Button.Button,
}

local panel: Panel.Panel
local built = false
local rows: { Row } = {}
local resetLabel: TextLabel

local function progressText(quest: Types.QuestDef, value: number): string
	if quest.Kind == "ReachDepth" then
		return Format.Depth(value) .. " / " .. Format.Depth(quest.Target)
	elseif quest.Kind == "PlayMinutes" then
		return math.floor(value) .. " / " .. quest.Target .. " min"
	end
	return Format.Abbreviate(value) .. " / " .. Format.Abbreviate(quest.Target)
end

local function refresh()
	if not built then
		return
	end
	local data = State.Data
	for _, row in rows do
		local quest = row.Quest
		local value, claimed = Progress.Quest(quest, data)
		local done = value >= quest.Target
		row.Bar:Set(value / quest.Target, if claimed then "Done!" else progressText(quest, value))
		row.Bar:SetColor(if done then C.Success else C.Ocean)
		row.Reward.Text = RewardText.Describe(quest.Reward, data.MaxDepth)
		if claimed then
			row.Claim:SetEnabled(false)
			row.Claim:SetText("Done!")
		elseif done then
			row.Claim:SetEnabled(true)
			row.Claim:SetText("Claim!")
		else
			row.Claim:SetEnabled(false)
			row.Claim:SetText(math.floor(value / quest.Target * 100) .. "%")
		end
		local base = if quest.Reset == "Daily" then 0 else 100
		row.Card.Holder.LayoutOrder = base
			+ (if claimed then 50 elseif done then -50 else 0)
			+ (table.find(Config.Quests, quest) or 0)
		row.Card:SetHighlight(if done and not claimed then C.Gold else nil)
	end
end

local function build()
	if built then
		return
	end
	built = true
	local body = panel.Body
	resetLabel = Style.Label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 24),
		Font = Style.Fonts.Body,
		StrokeThickness = 2,
		MaxTextSize = 17,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = body,
	})
	local list = Panel.Scroller(body, UDim2.new(1, 0, 1, -30), UDim2.fromOffset(0, 30))
	Style.List(list, Enum.FillDirection.Vertical, 8)
	for i, quest in Config.Quests do
		local card = Card.new({
			Name = quest.Id,
			Size = UDim2.new(1, -16, 0, 86),
			LayoutOrder = i,
			Color = if quest.Reset == "Daily" then C.NavyCard else Style.Darken(C.Purple, 0.55),
			ZIndex = 6,
			Parent = list,
		})
		Style.Label({
			Text = quest.Name,
			Size = UDim2.new(0.5, -36, 0, 26),
			Position = UDim2.fromOffset(44, 6),
			StrokeThickness = 2,
			MaxTextSize = 21,
			XAlign = Enum.TextXAlignment.Left,
			ZIndex = 8,
			Parent = card.Face,
		})
		Style.Label({
			Text = quest.Description,
			Size = UDim2.new(0.5, -150, 0, 22),
			Position = UDim2.new(0.5, 0, 0, 8),
			Font = Style.Fonts.Body,
			StrokeThickness = 2,
			MaxTextSize = 15,
			XAlign = Enum.TextXAlignment.Left,
			ZIndex = 8,
			Parent = card.Face,
		})
		AtlasIcon.new({
			Icon = if quest.Reset == "Daily" then "Quests" else "trophy",
			Size = UDim2.fromOffset(32, 32),
			Position = UDim2.fromOffset(8, 3),
			AnchorPoint = Vector2.zero,
			ZIndex = 8,
			Parent = card.Face,
		})
		local bar = ProgressBar.new({
			Size = UDim2.new(0.55, 0, 0, 28),
			Position = UDim2.fromOffset(12, 40),
			MaxTextSize = 16,
			ZIndex = 8,
			Parent = card.Face,
		})
		local reward = Style.Label({
			Text = "",
			Size = UDim2.new(0.45, -150, 0, 36),
			Position = UDim2.new(0.55, 22, 0, 36),
			TextColor = C.Sand,
			Font = Style.Fonts.Title,
			StrokeThickness = 2,
			Wrapped = true,
			MaxTextSize = 16,
			XAlign = Enum.TextXAlignment.Left,
			ZIndex = 8,
			Parent = card.Face,
		})
		local claim = Button.new({
			Text = "Claim!",
			Size = UDim2.fromOffset(130, 76),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Color = C.Success,
			MaxTextSize = 20,
			ZIndex = 8,
			Sound = "Purchase",
			Parent = card.Face,
			OnClick = function()
				Remotes.Get("ClaimQuest"):FireServer(quest.Id)
			end,
		})
		table.insert(rows, { Quest = quest, Card = card, Bar = bar, Reward = reward, Claim = claim })
	end
end

function QuestsPanel.Init()
	panel = Panel.new({
		Name = "Quests",
		Title = "Quests",
		Icon = Icons.Quests,
		Color = C.Sunset,
		Size = Vector2.new(800, 480),
	})
	panel.Opened:Connect(function()
		build()
		refresh()
	end)
	State.ObserveMany({ "Quests", "MaxDepth", "Rebirths" }, function()
		if built and panel.IsOpen then
			refresh()
		end
	end)
	task.spawn(function()
		while true do
			if built and panel.IsOpen then
				resetLabel.Text = "Daily quests reset in " .. Format.Time(Progress.SecondsToDailyReset())
			end
			task.wait(1)
		end
	end)
end

return QuestsPanel
