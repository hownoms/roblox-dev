--!strict
--[[
	Toasts — notification queue: short dark pills (kind-coloured outline, atlas icon overlapping
	the left end, outlined text) stacked under the top-centre objective banner and boost chips
	(UI/Layout "Toasts" region). Server Notify(kind, text) lands here; clients call
	Toasts.Show(text, kind). Max 3 on screen.
	Dedupe: the same message (case/punctuation/emoji-insensitive, and also when one text is just
	a longer version of the other, e.g. the server's "Backpack full! Go sell!" and the client's
	"Backpack full! Go SELL your sand") arriving within DEDUPE_WINDOW seconds of the last one is
	dropped (it only refreshes the visible toast's timer). Repeats after that window, while the
	toast is still visible, are merged into an "x2" counter instead of stacking.
	Kinds: Success, Error, Info, Warning, Reward, Announce (anything else -> Info).
	Routes (v2.2): Toasts.SetRoute(kind, fn) hands every message of that kind to another
	presenter instead (UI/Announcements takes "Announce" -> big gold top banner).
	Excavation: existing and incoming nonurgent notices wait until the rings and final grade
	leave the screen, then resume their remaining reading time without replaying sound.
	Reveals: while a Reveal popup is on screen, new non-urgent toasts (anything but Error and
	Warning) wait in the queue so they never cover its rarity headline; they appear when it
	closes, or after REVEAL_HOLD_MAX seconds if reveals keep chaining.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Root = require(script.Parent.Root)
local Style = require(script.Parent.Components.Style)
local AtlasIcon = require(script.Parent.Components.AtlasIcon)
local Layout = require(script.Parent.Layout)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local Reveal = require(script.Parent.Reveal)

local Toasts = {}

local MAX_VISIBLE = 3
local MAX_QUEUED = 7
local excavating = false
local DEFAULT_DURATION = 3.2
local DEDUPE_WINDOW = 2
local MIN_PREFIX = 10 -- normalised chars needed before a prefix counts as "the same message"
local REVEAL_HOLD_MAX = 6 -- seconds a toast may wait behind reveals before it shows anyway

type KindStyle = { Color: Color3, Icon: string, Sound: string? }

local C = Style.Colors
local KINDS: { [string]: KindStyle } = {
	success = { Color = C.Success, Icon = "Check", Sound = "Coin" },
	error = { Color = C.Danger, Icon = "❌", Sound = "Error" },
	info = { Color = C.Ocean, Icon = "info" },
	warning = { Color = C.Warning, Icon = "⚠️", Sound = "DigBlocked" },
	reward = { Color = C.Gold, Icon = "gift", Sound = "Purchase" },
	announce = { Color = C.Purple, Icon = "notify", Sound = "RareTreasure" },
	purchase = { Color = C.Robux, Icon = "Store", Sound = "Purchase" },
	sell = { Color = C.Gold, Icon = "Coins" }, -- the HUD already plays the sell sound + coin rain
	event = { Color = C.Sunset, Icon = "star", Sound = "RareTreasure" },
}

type Entry = { Text: string, Kind: string, Duration: number, Queued: number, Silent: boolean? }
type Active =
	{ Kind: string, Text: string, Key: string, Frame: Frame, Count: number, Label: TextLabel, Expires: number }

local container: Frame? = nil
local queue: { Entry } = {}
local active: { Active } = {}
local order = 0
local recent: { [string]: number } = {} -- normalised text -> os.clock() it was last shown

-- Lowercase letters and digits only: "Backpack full! Go SELL 💰" -> "backpackfullgosell".
local function normalise(text: string): string
	return (string.gsub(string.lower(text), "[^%w]", ""))
end

local function sameMessage(a: string, b: string): boolean
	if a == b then
		return true
	end
	local shorter, longer = a, b
	if #shorter > #longer then
		shorter, longer = b, a
	end
	return #shorter >= MIN_PREFIX and string.sub(longer, 1, #shorter) == shorter
end

-- Most recent time a message matching `key` was shown, if within the window.
local function recentlyShown(key: string, now: number): boolean
	for other, at in recent do
		if now - at > DEDUPE_WINDOW then
			recent[other] = nil
		elseif sameMessage(key, other) then
			return true
		end
	end
	return false
end

local function getKind(kind: string): KindStyle
	local key = string.lower(kind)
	if KINDS[key] then
		return KINDS[key]
	end
	if string.find(key, "err") or string.find(key, "fail") then
		return KINDS.error
	elseif string.find(key, "warn") then
		return KINDS.warning
	elseif string.find(key, "success") or string.find(key, "ok") then
		return KINDS.success
	elseif string.find(key, "reward") or string.find(key, "claim") or string.find(key, "code") then
		return KINDS.reward
	end
	return KINDS.info
end

local function getContainer(): Frame
	if container then
		return container
	end
	local frame = Instance.new("Frame")
	frame.Name = "Toasts"
	frame.BackgroundTransparency = 1
	frame.Parent = Root.Get("Toasts")
	Layout.Observe(function(regions: Layout.Regions)
		frame.Position = Layout.Position(regions.Toasts)
		frame.Size = Layout.SizeOf(regions.Toasts)
	end)
	Style.List(frame, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)
	container = frame
	return frame
end

local pump: () -> ()

local function dismiss(item: Active)
	local index = table.find(active, item)
	if index then
		table.remove(active, index)
	end
	local scale = Style.GetPopScale(item.Frame)
	local tween = Style.Tween(scale, 0.18, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	tween.Completed:Once(function()
		item.Frame:Destroy()
		pump()
	end)
end

local function display(entry: Entry)
	local kind = getKind(entry.Kind)
	order += 1
	local frame = Instance.new("Frame")
	frame.Name = "Toast"
	frame.Size = UDim2.new(1, -12, 0, 40)
	frame.LayoutOrder = order
	frame.Parent = getContainer()
	Style.Pill(frame, 0.1)
	local ring = frame:FindFirstChildOfClass("UIStroke")
	if ring then
		ring.Color = Style.Darken(kind.Color, 0.15)
	end

	AtlasIcon.new({
		Name = "IconBg",
		Icon = kind.Icon,
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(0, -10, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 3,
		Parent = frame,
	})

	local label = Style.Label({
		Text = entry.Text,
		Size = UDim2.new(1, -54, 0.84, 0),
		Position = UDim2.new(0, 42, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Font = Style.Fonts.Title,
		MaxTextSize = 19,
		XAlign = Enum.TextXAlignment.Left,
		Wrapped = true,
		ZIndex = 2,
		Parent = frame,
	})

	local item: Active = {
		Kind = entry.Kind,
		Text = entry.Text,
		Key = normalise(entry.Text),
		Frame = frame,
		Count = 1,
		Label = label,
		Expires = os.clock() + entry.Duration,
	}
	table.insert(active, item)
	Style.PopIn(frame, 0.3)
	if kind.Sound and not entry.Silent then
		SoundController.Play(kind.Sound, 1, 0.8)
	end
	task.delay(entry.Duration, function()
		while table.find(active, item) and os.clock() < item.Expires do
			task.wait(item.Expires - os.clock())
		end
		if table.find(active, item) then
			dismiss(item)
		end
	end)
end

-- Errors and warnings are about what the player is doing right now: never held back.
function Toasts.IsUrgent(kind: string): boolean
	local style = getKind(kind)
	return style == KINDS.error or style == KINDS.warning
end

local function waitsForReveal(entry: Entry, now: number): boolean
	return not Toasts.IsUrgent(entry.Kind)
		and (excavating or (Reveal.IsShowing() and now - entry.Queued < REVEAL_HOLD_MAX))
end

local holdTimer = false
pump = function()
	local now = os.clock()
	local i = 1
	while i <= #queue and #active < MAX_VISIBLE do
		local entry = queue[i]
		if waitsForReveal(entry, now) then
			i += 1
		else
			display(table.remove(queue, i) :: Entry)
		end
	end
	if #queue > 0 and Reveal.IsShowing() and not holdTimer then
		-- re-check when the hold cap runs out even if the reveals never stop
		holdTimer = true
		task.delay(1, function()
			holdTimer = false
			pump()
		end)
	end
end

-- Excavation pushes presentation state, avoiding a Toasts -> ExcavationGame require cycle.
function Toasts.SetExcavating(value: boolean)
	if excavating == value then
		return
	end
	excavating = value
	if value then
		local now = os.clock()
		for i = #active, 1, -1 do
			local item = active[i]
			if not Toasts.IsUrgent(item.Kind) then
				table.remove(active, i)
				item.Frame:Destroy()
				if #queue >= MAX_QUEUED then
					table.remove(queue)
				end
				table.insert(queue, 1, {
					Text = item.Label.Text,
					Kind = item.Kind,
					Duration = math.max(0.5, item.Expires - now),
					Queued = now,
					Silent = true,
				})
			end
		end
		pump()
	else
		-- A confirmed find reveal may take over during this same event.
		task.defer(pump)
	end
end

local routes: { [string]: (text: string) -> () } = {}

-- Send every message of `kind` (case-insensitive) to `fn` instead of a toast (nil: back to toasts).
function Toasts.SetRoute(kind: string, fn: ((text: string) -> ())?)
	routes[string.lower(kind)] = fn :: any
end

function Toasts.Show(text: string, kind: string?, duration: number?)
	if text == "" then
		return
	end
	local route = routes[string.lower(kind or "Info")]
	if route then
		route(text)
		return
	end
	local key = normalise(text)
	local now = os.clock()
	local isRecent = recentlyShown(key, now)
	if key ~= "" then
		recent[key] = now
	end
	-- merge duplicates that are still on screen
	for _, item in active do
		if item.Text == text or sameMessage(item.Key, key) then
			item.Expires = math.max(item.Expires, now + (duration or DEFAULT_DURATION))
			if isRecent then
				return -- the same notice twice in a row (e.g. server + client): show it once
			end
			item.Count += 1
			item.Label.Text = item.Text .. "  x" .. item.Count
			Style.Pop(item.Frame, 0.06)
			return
		end
	end
	for _, entry in queue do
		if entry.Text == text or sameMessage(normalise(entry.Text), key) then
			return
		end
	end
	if isRecent then
		return -- already shown and dismissed a moment ago
	end
	if #queue >= MAX_QUEUED then
		table.remove(queue, 1)
	end
	table.insert(
		queue,
		{ Text = text, Kind = kind or "Info", Duration = duration or DEFAULT_DURATION, Queued = os.clock() }
	)
	pump()
end

function Toasts.Init()
	getContainer()
	Reveal.Closed:Connect(function()
		-- deferred: Closed fires before Reveal shows the next queued reveal; a chained reveal
		-- must keep holding toasts instead of letting them pop in under its headline
		task.defer(pump)
	end)
	task.spawn(function()
		Remotes.Get("Notify").OnClientEvent:Connect(function(kind: any, text: any)
			if typeof(text) == "string" then
				Toasts.Show(text, if typeof(kind) == "string" then kind else "Info")
			elseif typeof(kind) == "string" and text == nil then
				Toasts.Show(kind, "Info")
			end
		end)
	end)
end

return Toasts
