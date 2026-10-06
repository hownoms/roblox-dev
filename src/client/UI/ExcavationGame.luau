--!strict
--[[
	ExcavationGame (v3 discovery slice) — the 3-5 second "dig it out!" moment when one of your
	digs uncovers a buried find (server ExcavationStart -> DiscoveryController.ExcavationStarted).

	Rings: after a short "ready" lead, info.Rings rings shrink one after another onto a target
	circle in the middle of the screen (info.RingSeconds each, info.RingGap apart). Tap anywhere
	(touch / click), or press Space / E / gamepad A / R2, when the ring meets the circle:
	  |error| <= PerfectWindow  PERFECT!   (2 points)
	  |error| <= GoodWindow     GOOD       (1 point)
	  later / no tap            MISS       (0; the find is never lost, only its quality drops)
	When every ring is graded the client sends Excavate(id, errors) (seconds, -1 = no tap); the
	server re-grades them (Util/Finds.Score) and decides the quality. Digging is paused while
	the session runs. The state machine (Start / Tap / Step with an optional clock) is public so
	tests can drive it without the UI.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Finds = require(Shared:WaitForChild("Util"):WaitForChild("Finds"))

local Root = require(script.Parent.Root)
local Style = require(script.Parent.Components.Style)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local DiscoveryController = require(script.Parent.Parent.Controllers.DiscoveryController)
local DigController = require(script.Parent.Parent.Controllers.DigController)
local Signal = require(script.Parent.Parent.Util.Signal)

local ExcavationGame = {}

ExcavationGame.LEAD = 0.45 -- seconds of "ready" before the first ring starts shrinking
ExcavationGame.Graded = Signal.new() -- (ring: number, grade: string)
ExcavationGame.Finished = Signal.new() -- (id: string, errors: { number })

local TARGET = 150 -- design px
local RING_START = 430

type Game = {
	Info: Types.ExcavationInfo,
	StartAt: number,
	Errors: { number },
	Done: boolean,
}

local session: Game? = nil
type UiRefs = {
	Root: TextButton,
	Ring: Frame,
	RingStroke: UIStroke,
	Target: Frame,
	Grade: TextLabel,
	Dots: { Frame },
}
local gui: UiRefs? = nil
local initialized = false

local function targetTime(g: Game, ring: number): number
	local info = g.Info
	return g.StartAt + ExcavationGame.LEAD + (ring - 1) * (info.RingSeconds + info.RingGap) + info.RingSeconds
end

function ExcavationGame.IsActive(): boolean
	return session ~= nil and not (session :: Game).Done
end

function ExcavationGame.Errors(): { number }
	return if session then table.clone((session :: Game).Errors) else {}
end

local GRADE_COLORS: { [string]: Color3 } = {
	Perfect = Color3.fromRGB(120, 255, 200),
	Good = Color3.fromRGB(255, 220, 90),
	Miss = Color3.fromRGB(255, 110, 110),
}

local function showGrade(ring: number, grade: string)
	local maybeUi = gui
	if not maybeUi then
		return
	end
	local ui = maybeUi :: UiRefs
	ui.Grade.Text = if grade == "Perfect" then "PERFECT!" elseif grade == "Good" then "GOOD!" else "MISS"
	ui.Grade.TextColor3 = GRADE_COLORS[grade]
	Style.Pop(ui.Grade, 0.35)
	local dot = ui.Dots[ring]
	if dot then
		dot.BackgroundColor3 = GRADE_COLORS[grade]
	end
end

local function teardown()
	local ui = gui
	gui = nil
	if ui then
		local root = ui.Root
		task.delay(0.6, function()
			root:Destroy()
		end)
	end
	DigController.Enabled = true
end

local function finish(g: Game)
	if g.Done then
		return
	end
	g.Done = true
	DiscoveryController.Excavate(g.Info.Id, g.Errors)
	ExcavationGame.Finished:Fire(g.Info.Id, table.clone(g.Errors))
	teardown()
end

local function record(g: Game, err: number)
	local ring = #g.Errors + 1
	table.insert(g.Errors, err)
	local grade = Finds.Grade(err)
	showGrade(ring, grade)
	if grade == "Perfect" then
		SoundController.Play("ExcavatePerfect", 1 + ring * 0.08)
		DiscoveryController.Nudge(g.Info.Id, 0.35)
	elseif grade == "Good" then
		SoundController.Play("ExcavateHit", 1)
		DiscoveryController.Nudge(g.Info.Id, 0.2)
	else
		SoundController.Play("DigBlocked", 0.9, 0.5)
	end
	ExcavationGame.Graded:Fire(ring, grade)
	if #g.Errors >= g.Info.Rings then
		finish(g)
	end
end

-- A tap at `now` (default os.clock()). Taps before the current ring appears are ignored.
function ExcavationGame.Tap(nowArg: number?): string?
	local maybe = session
	if not maybe then
		return nil
	end
	local g = maybe :: Game
	if g.Done then
		return nil
	end
	local now = nowArg or os.clock()
	local ring = #g.Errors + 1
	local t = targetTime(g, ring)
	if now < t - g.Info.RingSeconds then
		return nil
	end
	local err = math.abs(now - t)
	if err > g.Info.GoodWindow then
		err = if now < t then err else -1 -- early-but-visible taps count as a (missed) attempt
	end
	record(g, err)
	return Finds.Grade(err)
end

-- Advance time: rings that passed their window without a tap are misses.
function ExcavationGame.Step(nowArg: number?)
	local maybe = session
	if not maybe then
		return
	end
	local g = maybe :: Game
	if g.Done then
		return
	end
	local now = nowArg or os.clock()
	while not g.Done and now > targetTime(g, #g.Errors + 1) + g.Info.GoodWindow do
		record(g, -1)
	end
	local maybeUi = gui
	if maybeUi and not g.Done then
		local ui = maybeUi :: UiRefs
		local t = targetTime(g, #g.Errors + 1)
		local alpha = math.clamp(1 - (t - now) / g.Info.RingSeconds, 0, 1.15)
		local visible = now >= t - g.Info.RingSeconds
		local size = RING_START + (TARGET - RING_START) * alpha
		ui.Ring.Size = UDim2.fromOffset(size, size)
		ui.Ring.Visible = visible
		local close = math.abs(t - now) <= g.Info.GoodWindow
		ui.RingStroke.Color = if close then GRADE_COLORS.Perfect else Color3.new(1, 1, 1)
	end
end

local function build(info: Types.ExcavationInfo)
	local color = DiscoveryController.SignalColor(info.Signal)
	local canvas = Root.Get("Popups")
	local overlay = Instance.new("TextButton")
	overlay.Name = "Excavation"
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Selectable = false
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.75
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 50
	overlay.Parent = canvas

	local title = Style.Label({
		Name = "Title",
		Text = "DIG IT OUT!",
		Size = UDim2.fromOffset(520, 64),
		Position = UDim2.new(0.5, 0, 0.5, -250),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor = color,
		MaxTextSize = 56,
		StrokeThickness = 4,
		ZIndex = 52,
		Parent = overlay,
	})
	Style.PopIn(title)
	Style.Label({
		Name = "Hint",
		Text = "Tap when the ring hits the circle!",
		Size = UDim2.fromOffset(520, 30),
		Position = UDim2.new(0.5, 0, 0.5, -205),
		AnchorPoint = Vector2.new(0.5, 0.5),
		MaxTextSize = 24,
		ZIndex = 52,
		Parent = overlay,
	})

	local target = Instance.new("Frame")
	target.Name = "Target"
	target.AnchorPoint = Vector2.new(0.5, 0.5)
	target.Position = UDim2.fromScale(0.5, 0.5)
	target.Size = UDim2.fromOffset(TARGET, TARGET)
	target.BackgroundColor3 = color
	target.BackgroundTransparency = 0.55
	target.ZIndex = 51
	target.Parent = overlay
	Style.Corner(target, UDim.new(1, 0))
	Style.Stroke(target, Style.Colors.Stroke, 5)

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(RING_START, RING_START)
	ring.BackgroundTransparency = 1
	ring.Visible = false
	ring.ZIndex = 53
	ring.Parent = overlay
	Style.Corner(ring, UDim.new(1, 0))
	local ringStroke = Style.Stroke(ring, Color3.new(1, 1, 1), 8)

	local grade = Style.Label({
		Name = "Grade",
		Text = "READY...",
		Size = UDim2.fromOffset(TARGET + 60, 50),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		MaxTextSize = 40,
		StrokeThickness = 4,
		ZIndex = 54,
		Parent = overlay,
	})

	local dotsRow = Instance.new("Frame")
	dotsRow.Name = "Dots"
	dotsRow.BackgroundTransparency = 1
	dotsRow.AnchorPoint = Vector2.new(0.5, 0.5)
	dotsRow.Position = UDim2.new(0.5, 0, 0.5, 200)
	dotsRow.Size = UDim2.fromOffset(info.Rings * 44, 34)
	dotsRow.ZIndex = 52
	dotsRow.Parent = overlay
	Style.List(dotsRow, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
	local dots: { Frame } = {}
	for i = 1, info.Rings do
		local dot = Instance.new("Frame")
		dot.Name = "Dot" .. i
		dot.Size = UDim2.fromOffset(32, 32)
		dot.BackgroundColor3 = Style.Colors.NavyCard
		dot.LayoutOrder = i
		dot.ZIndex = 53
		dot.Parent = dotsRow
		Style.Corner(dot, UDim.new(1, 0))
		Style.Stroke(dot, Style.Colors.Stroke, 3)
		dots[i] = dot
	end

	overlay.Activated:Connect(function()
		ExcavationGame.Tap()
	end)
	gui = { Root = overlay, Ring = ring, RingStroke = ringStroke, Target = target, Grade = grade, Dots = dots }
end

-- Starts the minigame for a server ExcavationStart. `now` lets tests pin the clock.
function ExcavationGame.Start(info: Types.ExcavationInfo, nowArg: number?, headless: boolean?)
	if session and not (session :: Game).Done then
		finish(session :: Game) -- a new find replaces an unanswered one (server already moved on)
	end
	local rings = math.clamp(math.floor(tonumber(info.Rings) or 3), 1, 5)
	local safe: Types.ExcavationInfo = {
		Id = info.Id,
		Position = info.Position,
		Signal = info.Signal,
		Rings = rings,
		RingSeconds = math.clamp(tonumber(info.RingSeconds) or 0.9, 0.3, 3),
		RingGap = math.clamp(tonumber(info.RingGap) or 0.25, 0, 2),
		PerfectWindow = tonumber(info.PerfectWindow) or 0.09,
		GoodWindow = tonumber(info.GoodWindow) or 0.22,
		Timeout = tonumber(info.Timeout) or 9,
	}
	session = { Info = safe, StartAt = nowArg or os.clock(), Errors = {}, Done = false }
	DigController.Enabled = false
	if not headless then
		build(safe)
	end
end

function ExcavationGame.Init()
	if initialized then
		return
	end
	initialized = true
	DiscoveryController.ExcavationStarted:Connect(function(info: Types.ExcavationInfo)
		ExcavationGame.Start(info)
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, _processed: boolean)
		if not ExcavationGame.IsActive() then
			return
		end
		local key = input.KeyCode
		if
			key == Enum.KeyCode.Space
			or key == Enum.KeyCode.E
			or key == Enum.KeyCode.ButtonA
			or key == Enum.KeyCode.ButtonR2
		then
			ExcavationGame.Tap()
		end
	end)
	RunService.Heartbeat:Connect(function()
		if ExcavationGame.IsActive() then
			ExcavationGame.Step()
		end
	end)
end

return ExcavationGame
