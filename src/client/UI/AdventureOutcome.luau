--!strict
--[[
	AdventureOutcome — one compact card per adventure settlement outcome for THIS player
	(server AdventureSettlement -> remote AdventureOutcome(outcome)). Sits under the toast
	column (UI/Layout "Toasts" region) in the Toasts layer.

	outcome = { InstanceId, Kind = "Stage" | "Final", StageId?, State = "Accepted" | "Pending" |
	"Refused", Status, Coins, Trophy, Stand, Certification?, Reason?, Resolved? }

	Truthfulness rules (the server guarantees the State; this module only words it):
	  * Only State == "Accepted" is ever worded as earned/saved.
	  * "Pending" says what is still in flight (saving, or waiting for the save to load) and
	    never claims the reward is safe yet: no "saved", no unlock lines, coins marked "not
	    saved yet", even when the payload's Trophy/Stand/Certification name what is in flight.
	  * "Refused" always says why (no contribution, disconnected, left, could not be stored).
	A later outcome for the same run (same InstanceId/Kind/StageId, e.g. Resolved after a
	Pending) replaces the card on screen instead of stacking.

	Public API:
		AdventureOutcome.Init()
		AdventureOutcome.Show(outcome)          (also used by tests)
		AdventureOutcome.Describe(outcome) -> { Title, Lines, State }? (pure; tests)
		AdventureOutcome.LastText: string       (title + lines of the last card; tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Root = require(script.Parent.Root)
local Style = require(script.Parent.Components.Style)
local Layout = require(script.Parent.Layout)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local AdventureOutcome = {}

AdventureOutcome.LastText = ""

export type Described = {
	Title: string,
	Lines: { string },
	State: string,
}

local C = Style.Colors
local WIDTH, LINE_HEIGHT, TITLE_HEIGHT = 360, 20, 26
local MAX_VISIBLE = 2
local HOLD: { [string]: number } = { Accepted = 6, Pending = 9, Refused = 6 }
local ACCENT: { [string]: Color3 } = { Accepted = C.Gold, Pending = C.Warning, Refused = C.Coral }

local STAGE_TEXT: { [string]: string } = {
	excavation = "clearing the vault anchors",
	vault_open = "opening the Spring Vault",
	ball_return = "bringing the beach ball home",
}

local REFUSED_TEXT: { [string]: string } = {
	NoContribution = "No reward: you joined but didn't contribute yet.",
	LowContribution = "No reward: you joined but didn't contribute enough.",
	NotPresent = "No reward: you weren't there for an objective.",
	EventIneligible = "No reward: you weren't in the crew at the finish.",
	Disconnected = "No reward: you were disconnected for this stage.",
	Left = "No reward: you left the adventure.",
	PendingWriteFailed = "Your reward couldn't be stored. Nothing was lost; try again later.",
	PendingFull = "Your reward couldn't be stored. Nothing was lost; try again later.",
}

-- Statuses the server counts as durable (AdventureSettlement STATE). An "Accepted" payload with
-- any other Status is worded as Pending: nothing reads as saved before it is.
local DURABLE: { [string]: boolean } = { Saved = true, Queued = true, Duplicate = true }

local TROPHY_TEXT: { [string]: string } = {
	TrophyUnavailable = "Trophies are paused right now: no trophy this time.",
	TrophyRecordLimit = "Your trophy shelf is full: no trophy this time.",
	TrophyPendingWriteFailed = "The trophy couldn't be stored: clear the vault again to get it.",
	TrophyPendingFull = "The trophy couldn't be stored: clear the vault again to get it.",
}

local function str(v: any): string?
	return if typeof(v) == "string" and #v > 0 and #v <= 120 then v else nil
end

local function num(v: any): number
	return if typeof(v) == "number" and v == v and v >= 0 and v < 1e9 then math.floor(v) else 0
end

local function unlocks(outcome: any): { string }
	local lines: { string } = {}
	if outcome.Trophy == true then
		table.insert(lines, "Spring Vault trophy")
	end
	if outcome.Stand == true then
		table.insert(lines, "Mara's trophy stand")
	end
	if str(outcome.Certification) then
		table.insert(lines, "Crew certification")
	end
	return lines
end

local function described(title: string, lines: { string }, state: string): Described
	return { Title = title, Lines = lines, State = state }
end

-- Pure wording for an outcome; nil for a malformed payload.
function AdventureOutcome.Describe(outcome: any): Described?
	if typeof(outcome) ~= "table" then
		return nil
	end
	local state: string = outcome.State
	local kind = outcome.Kind
	if (state ~= "Accepted" and state ~= "Pending" and state ~= "Refused") or (kind ~= "Stage" and kind ~= "Final") then
		return nil
	end
	local coins = num(outcome.Coins)
	local status = str(outcome.Status) or ""
	if state == "Accepted" and not DURABLE[status] then
		state = "Pending"
	end
	local reason = str(outcome.Reason)
	local stageText = STAGE_TEXT[str(outcome.StageId) or ""] or "that stage"
	local lines: { string } = {}
	local title: string

	if state == "Refused" then
		title = if kind == "Final" then "ADVENTURE COMPLETE" else "STAGE COMPLETE"
		table.insert(lines, REFUSED_TEXT[reason or ""] or "No reward this time.")
		return described(title, lines, state)
	end

	if state == "Pending" then
		if status == "PendingRejoin" then
			-- the intent is queued, not granted: never worded "saved" (only Accepted is)
			title = "REWARDS WAITING"
			table.insert(lines, "Not added yet: they'll be added when your save loads,")
			table.insert(lines, "here or the next time you join.")
		else
			title = "SAVING YOUR REWARDS..."
			if coins > 0 then
				table.insert(lines, string.format("+%d Coins (not saved yet)", coins))
			end
			table.insert(lines, "Still saving: stay a moment and we'll confirm.")
		end
	else
		if status == "Duplicate" and coins == 0 and #unlocks(outcome) == 0 then
			title = "ALREADY COLLECTED"
			table.insert(lines, "Rewards for this run were saved earlier.")
			return described(title, lines, state)
		end
		if outcome.Resolved == true then
			title = "REWARDS FROM YOUR LAST ADVENTURE"
		elseif kind == "Final" then
			title = "ADVENTURE REWARDS SAVED"
		else
			title = "STAGE REWARD SAVED"
		end
		if coins > 0 then
			table.insert(
				lines,
				if kind == "Stage" and outcome.Resolved ~= true
					then string.format("+%d Coins for %s", coins, stageText)
					else string.format("+%d Coins", coins)
			)
		end
		for _, line in unlocks(outcome) do
			table.insert(lines, line)
		end
		if #lines == 0 then
			table.insert(lines, "Nothing new this time.")
		end
	end
	if reason and TROPHY_TEXT[reason] then
		table.insert(lines, TROPHY_TEXT[reason])
	end
	return described(title, lines, state)
end

-- Cards ---------------------------------------------------------------------------------------

type Card = { Key: string, Frame: Frame, Expires: number }

local container: Frame? = nil
local cards: { Card } = {}
local queue: { { Key: string, Outcome: any } } = {}
local order = 0

local function keyOf(outcome: any): string
	return string.format("%s|%s|%s", str(outcome.InstanceId) or "?", tostring(outcome.Kind), str(outcome.StageId) or "")
end

local function getContainer(): Frame
	if container then
		return container
	end
	local frame = Instance.new("Frame")
	frame.Name = "AdventureOutcomes"
	frame.BackgroundTransparency = 1
	frame.Parent = Root.Get("Toasts")
	Layout.Observe(function(regions: Layout.Regions)
		local r = regions.Toasts
		frame.Position = UDim2.fromOffset(r.X + r.W / 2 - WIDTH / 2, r.Y + r.H + 6)
		frame.Size = UDim2.fromOffset(WIDTH, 2 * (TITLE_HEIGHT + 4 * LINE_HEIGHT + 20))
	end)
	Style.List(frame, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)
	container = frame
	return frame
end

local pump: () -> ()

local function remove(card: Card)
	local index = table.find(cards, card)
	if index then
		table.remove(cards, index)
	end
	card.Frame:Destroy()
	pump()
end

local function build(described: Described): Frame
	order += 1
	local accent = ACCENT[described.State] or C.Ocean
	local height = TITLE_HEIGHT + #described.Lines * LINE_HEIGHT + 16
	local frame = Instance.new("Frame")
	frame.Name = "OutcomeCard"
	frame.Size = UDim2.fromOffset(WIDTH, height)
	frame.LayoutOrder = order
	frame.BackgroundColor3 = C.NavyDark
	frame.BackgroundTransparency = 0.06
	frame.BorderSizePixel = 0
	Style.Corner(frame, Style.Theme.CornerMedium)
	Style.Stroke(frame, Style.Darken(accent, 0.1), 3)
	Style.Label({
		Name = "Title",
		Text = described.Title,
		Size = UDim2.new(1, -24, 0, TITLE_HEIGHT),
		Position = UDim2.fromOffset(12, 6),
		Font = Style.Fonts.Title,
		TextColor = accent,
		MaxTextSize = 20,
		XAlign = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	for i, line in described.Lines do
		Style.Label({
			Name = "Line" .. i,
			Text = line,
			Size = UDim2.new(1, -24, 0, LINE_HEIGHT),
			Position = UDim2.fromOffset(12, 6 + TITLE_HEIGHT + (i - 1) * LINE_HEIGHT),
			Font = Style.Fonts.Body,
			MaxTextSize = 16,
			XAlign = Enum.TextXAlignment.Left,
			Parent = frame,
		})
	end
	return frame
end

local function display(key: string, outcome: any): boolean
	local described = AdventureOutcome.Describe(outcome)
	if not described then
		return false
	end
	AdventureOutcome.LastText = described.Title .. "\n" .. table.concat(described.Lines, "\n")
	local frame = build(described)
	frame.Parent = getContainer()
	local card: Card = { Key = key, Frame = frame, Expires = os.clock() + (HOLD[described.State] or 6) }
	table.insert(cards, card)
	Style.PopIn(frame, 0.3)
	if described.State == "Accepted" and (num(outcome.Coins) > 0 or outcome.Trophy == true) then
		SoundController.Play(if outcome.Trophy == true then "Purchase" else "Coin", 1, 0.8)
	end
	task.delay(HOLD[described.State] or 6, function()
		while table.find(cards, card) and os.clock() < card.Expires do
			task.wait(card.Expires - os.clock())
		end
		if table.find(cards, card) then
			remove(card)
		end
	end)
	return true
end

pump = function()
	while #queue > 0 and #cards < MAX_VISIBLE do
		local entry = table.remove(queue, 1) :: { Key: string, Outcome: any }
		display(entry.Key, entry.Outcome)
	end
end

function AdventureOutcome.Show(outcome: any)
	if AdventureOutcome.Describe(outcome) == nil then
		return
	end
	local key = keyOf(outcome)
	-- a newer outcome for the same run replaces the old one (e.g. Pending -> Resolved)
	for i = #queue, 1, -1 do
		if queue[i].Key == key then
			table.remove(queue, i)
		end
	end
	for _, card in cards do
		if card.Key == key then
			local index = table.find(cards, card)
			if index then
				table.remove(cards, index)
			end
			card.Frame:Destroy()
			break
		end
	end
	table.insert(queue, { Key = key, Outcome = outcome })
	pump()
end

-- Cards currently on screen (tests).
function AdventureOutcome.VisibleCount(): number
	return #cards
end

function AdventureOutcome.Init()
	getContainer()
	task.spawn(function()
		Remotes.Get("AdventureOutcome").OnClientEvent:Connect(AdventureOutcome.Show)
	end)
end

return AdventureOutcome
