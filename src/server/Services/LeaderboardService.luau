--!strict
--[[
	LeaderboardService — the two in-world boards (parts tagged "LeaderboardCoins" /
	"LeaderboardDepth", SurfaceGui on the Front face, cartoon styling from Config.Theme).

	v2.2 scopes: both boards flip every Config.Social.Leaderboard.CycleSeconds between
	  ALL TIME     OrderedDataStores Config.LEADERBOARD_COINS_STORE (Coins) /
	               Config.LEADERBOARD_DEPTH_STORE (MaxDepth)
	  THIS WEEK    OrderedDataStores "<WeeklyPrefix>_W<ISO year>_<ISO week>" (Util/Week), e.g.
	               "Leaderboard_Sand_W2026_41" (sand dug this week, IncrementAsync of the
	               unwritten delta) and "Leaderboard_Depth_W2026_41" (deepest dig this week,
	               UpdateAsync keeping the max). A new week = a new key, so it resets by itself.
	  THIS SERVER  live, from in-memory session counters of the players in this server (sand dug
	               and deepest dig since they joined). No DataStore at all.
	The weekly and server metrics are things a brand-new player can win.

	Request budget: everything DataStore-related runs on the old cadence, once every
	Config.LEADERBOARD_REFRESH_SECONDS (60 s): per player at most 4 sorted-store writes (2 all-time
	SetAsync, 1 IncrementAsync, 1 UpdateAsync; skipped when unchanged) against a budget of
	60 + 10 x players per minute, plus 4 GetSortedAsync reads (budget 5 + 2 x players). Writes
	also check GetRequestBudgetForRequestType when available. Every call is pcall'd with one
	retry; a store that keeps failing is skipped with exponential backoff (30 s .. WriteBackoffMax).
	Scope cycling only redraws from cached entries. In Studio without DataStore access (or if a
	read fails) the board shows the players in this server instead.

	Public API (tests / other services):
		LeaderboardService.GetScope(): "AllTime" | "Week" | "Server"
		LeaderboardService.SetScope(scope)           redraw both boards in that scope now
		LeaderboardService.GetEntries(tag, scope): { { UserId, Name, Value } }
		LeaderboardService.GetSession(player): { WeekKey, WeekSand, WeekDepth, SessionSand, SessionDepth }?
		LeaderboardService.WeeklyStoreName(kind, unix?): string   (kind "Coins" | "Depth")
		LeaderboardService.Refresh()                 one write + fetch + redraw pass (yields)
]]

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Format = require(Shared.Util.Format)
local Week = require(Shared.Util.Week)

local DataService = require(script.Parent.DataService)
local ServerSignals = require(script.Parent.ServerSignals)

export type Scope = string -- "AllTime" | "Week" | "Server"
type Entry = { UserId: number, Name: string, Value: number }

type Session = {
	WeekKey: string,
	WeekSand: number, -- sand dug this ISO week in this session
	WeekSandWritten: number, -- part of WeekSand already added to the weekly store
	WeekDepth: number, -- deepest dig this week in this session
	WeekDepthWritten: number,
	SessionSand: number, -- since joining this server
	SessionDepth: number,
}

type Board = {
	Tag: string,
	Kind: "Coins" | "Depth",
	Titles: { [string]: string },
	Units: { [string]: string },
	AllTimeStoreName: string,
	AllTimeStore: OrderedDataStore?,
	AllTimeValue: (data: Types.PlayerData) -> number,
	WeekValue: (session: Session) -> number,
	ServerValue: (session: Session) -> number,
	FormatValue: (value: number) -> string,
	LastWritten: { [number]: number },
	Entries: { [string]: { Entry } },
}

local SCOPES: { Scope } = { "AllTime", "Week", "Server" }
local SCOPE_LABELS: { [string]: string } = { AllTime = "ALL TIME", Week = "THIS WEEK", Server = "THIS SERVER" }
local DISPLAY_ROWS = math.min(Config.LEADERBOARD_SIZE, 10)
local MAX_ORDERED_VALUE = 2 ^ 53
local PIXELS_PER_STUD = 50
local LB = Config.Social.Leaderboard

local LeaderboardService = {}

local nameCache: { [number]: string } = {}
local surfaces: { [BasePart]: { List: Frame, Title: TextLabel, Scope: TextLabel, ScopeBar: Frame } } = {}
local sessions: { [Player]: Session } = {}
local weeklyStores: { [string]: OrderedDataStore } = {}
type Backoff = { Until: number, Seconds: number }
local backoff: { [string]: Backoff } = {}
local storesEnabled = false
local scopeIndex = 1

local function sandFormat(value: number): string
	return Format.Abbreviate(value)
end

local boards: { Board } = {
	{
		Tag = "LeaderboardCoins",
		Kind = "Coins",
		Titles = { AllTime = "RICHEST DIGGERS", Week = "TOP SAND DIGGERS", Server = "TOP SAND DIGGERS" },
		Units = { AllTime = "coins", Week = "sand dug", Server = "sand dug" },
		AllTimeStoreName = Config.LEADERBOARD_COINS_STORE,
		AllTimeStore = nil,
		AllTimeValue = function(data: Types.PlayerData): number
			return data.Coins
		end,
		WeekValue = function(session: Session): number
			return session.WeekSand
		end,
		ServerValue = function(session: Session): number
			return session.SessionSand
		end,
		FormatValue = sandFormat,
		LastWritten = {},
		Entries = { AllTime = {}, Week = {}, Server = {} },
	},
	{
		Tag = "LeaderboardDepth",
		Kind = "Depth",
		Titles = { AllTime = "DEEPEST DIGGERS", Week = "DEEPEST DIGGERS", Server = "DEEPEST DIGGERS" },
		Units = { AllTime = "record depth", Week = "deepest dig", Server = "deepest dig" },
		AllTimeStoreName = Config.LEADERBOARD_DEPTH_STORE,
		AllTimeStore = nil,
		AllTimeValue = function(data: Types.PlayerData): number
			return data.MaxDepth
		end,
		WeekValue = function(session: Session): number
			return session.WeekDepth
		end,
		ServerValue = function(session: Session): number
			return session.SessionDepth
		end,
		FormatValue = function(value: number): string
			return Format.Depth(value)
		end,
		LastWritten = {},
		Entries = { AllTime = {}, Week = {}, Server = {} },
	},
}

local function getBoard(tag: string): Board?
	for _, board in boards do
		if board.Tag == tag then
			return board
		end
	end
	return nil
end

function LeaderboardService.WeeklyStoreName(kind: "Coins" | "Depth", unix: number?): string
	local prefix = if kind == "Coins" then LB.WeeklyPrefix.Coins else LB.WeeklyPrefix.Depth
	return prefix .. "_" .. Week.Key(unix or os.time())
end

-- Requests ------------------------------------------------------------------------------------------

local function retry<T>(attempts: number, fn: () -> T): (boolean, T?)
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attempt == attempts then
			warn("[LeaderboardService] " .. tostring(result))
		else
			task.wait(attempt * 2)
		end
	end
	return false, nil
end

-- Exponential backoff per store: true when the store may be called now.
local function available(storeName: string): boolean
	local state = backoff[storeName]
	return state == nil or os.clock() >= state.Until
end

local function record(storeName: string, ok: boolean)
	if ok then
		backoff[storeName] = nil
		return
	end
	local state: Backoff = backoff[storeName] or { Until = 0, Seconds = 15 }
	state.Seconds = math.min(state.Seconds * 2, LB.WriteBackoffMax)
	state.Until = os.clock() + state.Seconds
	backoff[storeName] = state
end

-- Remaining sorted-store write budget (math.huge when the engine can't tell us).
local function writeBudget(): number
	local ok, budget = pcall(function(): number
		return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementSortedAsync)
	end)
	return if ok and type(budget) == "number" then budget else math.huge
end

local function call<T>(storeName: string, fn: () -> T): (boolean, T?)
	if not available(storeName) then
		return false, nil
	end
	local ok, result = retry(2, fn)
	record(storeName, ok)
	return ok, result
end

local function weeklyStore(storeName: string): OrderedDataStore?
	if not storesEnabled then
		return nil
	end
	local cached = weeklyStores[storeName]
	if cached then
		return cached
	end
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(storeName)
	end)
	if ok and store then
		weeklyStores[storeName] = store
		return store
	end
	return nil
end

local function resolveName(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and type(name) == "string" then name else "Digger"
	nameCache[userId] = result
	return result
end

local function clampValue(value: number): number
	if value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, MAX_ORDERED_VALUE)
end

-- Sessions ----------------------------------------------------------------------------------------

local function newSession(): Session
	return {
		WeekKey = Week.Key(os.time()),
		WeekSand = 0,
		WeekSandWritten = 0,
		WeekDepth = 0,
		WeekDepthWritten = 0,
		SessionSand = 0,
		SessionDepth = 0,
	}
end

local function getSession(player: Player): Session
	local session = sessions[player]
	if not session then
		session = newSession()
		sessions[player] = session
	end
	return session
end

function LeaderboardService.GetSession(player: Player): Session?
	return sessions[player]
end

local function onDug(player: Player, depth: number, gained: number, _source: string)
	if type(gained) ~= "number" or gained ~= gained or player.Parent == nil then
		return
	end
	local session = getSession(player)
	local sand = math.max(gained, 0)
	session.WeekSand += sand
	session.SessionSand += sand
	if type(depth) == "number" and depth == depth then
		local d = math.max(math.floor(depth), 0)
		session.WeekDepth = math.max(session.WeekDepth, d)
		session.SessionDepth = math.max(session.SessionDepth, d)
	end
end

-- Writes ------------------------------------------------------------------------------------------

local function writeAllTime(board: Board, player: Player)
	local store = board.AllTimeStore
	local data = DataService.Get(player)
	if not store or not data then
		return
	end
	assert(store) -- refine for the type checker (guarded above)
	assert(data) -- refine for the type checker (guarded above)
	local value = clampValue(board.AllTimeValue(data))
	if board.LastWritten[player.UserId] == value or value <= 0 then
		return
	end
	local ok = call(board.AllTimeStoreName, function()
		store:SetAsync(tostring(player.UserId), value)
		return true
	end)
	if ok then
		board.LastWritten[player.UserId] = value
	end
end

-- Flush this player's weekly counters into the stores of the week they were earned in.
local function writeWeekly(player: Player, session: Session)
	local key = tostring(player.UserId)
	local delta = clampValue(session.WeekSand - session.WeekSandWritten)
	if delta > 0 then
		local name = LB.WeeklyPrefix.Coins .. "_" .. session.WeekKey
		local store = weeklyStore(name)
		if store then
			local ok = call(name, function()
				return store:IncrementAsync(key, delta)
			end)
			if ok then
				session.WeekSandWritten += delta
			end
		end
	end
	local depth = clampValue(session.WeekDepth)
	if depth > session.WeekDepthWritten then
		local name = LB.WeeklyPrefix.Depth .. "_" .. session.WeekKey
		local store = weeklyStore(name)
		if store then
			local ok = call(name, function()
				return store:UpdateAsync(key, function(old: any): any
					if type(old) == "number" and old >= depth then
						return nil -- keep the better value already stored
					end
					return depth
				end)
			end)
			if ok then
				session.WeekDepthWritten = depth
			end
		end
	end
end

-- New ISO week: start the weekly counters again (call after writeWeekly flushed the old week).
local function rollWeek(session: Session, now: number)
	local key = Week.Key(now)
	if key ~= session.WeekKey then
		session.WeekKey = key
		session.WeekSand = 0
		session.WeekSandWritten = 0
		session.WeekDepth = 0
		session.WeekDepthWritten = 0
	end
end

-- Reads -------------------------------------------------------------------------------------------

local function localEntries(valueOf: (Player) -> number?): { Entry }
	local entries = {}
	for _, player in DataService.GetLoadedPlayers() do
		local value = valueOf(player)
		if value and value > 0 then
			table.insert(entries, { UserId = player.UserId, Name = player.DisplayName, Value = clampValue(value) })
		end
	end
	table.sort(entries, function(a: Entry, b: Entry)
		return a.Value > b.Value
	end)
	return entries
end

local function allTimeLocal(board: Board): { Entry }
	return localEntries(function(player: Player): number?
		local data = DataService.Get(player)
		return if data then board.AllTimeValue(data) else nil
	end)
end

local function weekLocal(board: Board): { Entry }
	return localEntries(function(player: Player): number?
		local session = sessions[player]
		return if session then board.WeekValue(session) else nil
	end)
end

local function serverEntries(board: Board): { Entry }
	return localEntries(function(player: Player): number?
		local session = sessions[player]
		return if session then board.ServerValue(session) else nil
	end)
end

local function fetchSorted(storeName: string, store: OrderedDataStore?): { Entry }?
	if not store then
		return nil
	end
	assert(store) -- refine for the type checker (guarded above)
	local ok, page = call(storeName, function()
		local pages = store:GetSortedAsync(false, math.clamp(Config.LEADERBOARD_SIZE, 1, 100))
		return pages:GetCurrentPage()
	end)
	if not ok or type(page) ~= "table" then
		return nil
	end
	local entries = {}
	for _, item in page :: { any } do
		local userId = tonumber(item.key)
		local value = tonumber(item.value)
		if userId and value and value > 0 then
			table.insert(entries, { UserId = userId, Name = resolveName(userId), Value = value })
		end
	end
	return entries
end

function LeaderboardService.GetEntries(tag: string, scope: Scope): { Entry }
	local found = getBoard(tag)
	if found == nil then
		return {}
	end
	local board = found :: Board
	if scope == "Server" then
		return serverEntries(board)
	end
	return board.Entries[scope]
end

-- Rendering ---------------------------------------------------------------------------------------

local Theme = Config.Theme
local RANK_COLORS = {
	Theme.Colors.Gold,
	Color3.fromRGB(215, 220, 230),
	Color3.fromRGB(230, 150, 90),
}
local SCOPE_COLORS: { [string]: Color3 } = {
	AllTime = Theme.Colors.Purple,
	Week = Theme.Colors.Coral,
	Server = Theme.Colors.Palm,
}

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function stroke(parent: Instance, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = Theme.Colors.Stroke
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
end

local function label(parent: Instance, name: string, text: string, font: Enum.Font, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = font
	l.TextColor3 = color
	l.TextScaled = true
	l.Parent = parent
	return l
end

local function scopeText(scope: Scope, board: Board): string
	local text = SCOPE_LABELS[scope] .. "  -  " .. board.Units[scope]
	if scope == "Week" then
		text ..= "  (new week in " .. Format.Time(Week.SecondsLeft(os.time())) .. ")"
	end
	return text
end

local function buildSurface(part: BasePart, board: Board)
	local existing = part:FindFirstChild("LeaderboardGui")
	if existing then
		existing:Destroy()
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Brightness = 1.5
	gui.ResetOnSpawn = false
	gui.Adornee = part

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Theme.Colors.OceanDark
	root.Parent = gui
	corner(root, Theme.CornerLarge)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.03, 0)
	padding.PaddingBottom = UDim.new(0.03, 0)
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.Parent = root

	local title = Instance.new("Frame")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.12)
	title.BackgroundColor3 = Theme.Colors.Gold
	title.Parent = root
	corner(title, Theme.CornerMedium)
	stroke(title, Theme.StrokeThickness * 2)
	local titleText = label(title, "Text", board.Titles.AllTime, Theme.Fonts.Title, Theme.Colors.Text)
	titleText.Size = UDim2.fromScale(0.94, 0.8)
	titleText.Position = UDim2.fromScale(0.03, 0.1)
	stroke(titleText, Theme.StrokeThickness * 2)

	-- scope strip: "THIS WEEK - sand dug (new week in 2d 4h)" in the scope colour
	local scopeBar = Instance.new("Frame")
	scopeBar.Name = "Scope"
	scopeBar.Position = UDim2.fromScale(0.06, 0.135)
	scopeBar.Size = UDim2.fromScale(0.88, 0.07)
	scopeBar.BackgroundColor3 = SCOPE_COLORS.AllTime
	scopeBar.Parent = root
	corner(scopeBar, Theme.CornerPill)
	stroke(scopeBar, Theme.StrokeThickness * 1.5)
	local scopeLabel = label(scopeBar, "Text", scopeText("AllTime", board), Theme.Fonts.Title, Theme.Colors.Text)
	scopeLabel.Size = UDim2.fromScale(0.94, 0.78)
	scopeLabel.Position = UDim2.fromScale(0.03, 0.11)
	stroke(scopeLabel, Theme.StrokeThickness)

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0, 0.22)
	list.Size = UDim2.fromScale(1, 0.78)
	list.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.01, 0)
	layout.Parent = list

	gui.Parent = part
	surfaces[part] = { List = list, Title = titleText, Scope = scopeLabel, ScopeBar = scopeBar }
end

local function renderRows(part: BasePart, board: Board, scope: Scope)
	local surface = surfaces[part]
	if not surface then
		return
	end
	surface.Title.Text = board.Titles[scope]
	surface.Scope.Text = scopeText(scope, board)
	surface.ScopeBar.BackgroundColor3 = SCOPE_COLORS[scope]
	surface.ScopeBar:SetAttribute("Scope", scope)
	local list = surface.List
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local entries = LeaderboardService.GetEntries(board.Tag, scope)
	local rowHeight = 1 / DISPLAY_ROWS - 0.01
	if #entries == 0 then
		local row = Instance.new("Frame")
		row.Name = "Empty"
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, rowHeight * 2)
		row.Parent = list
		local message = if scope == "AllTime"
			then "Start digging to get on the board!"
			else "Nobody yet - dig now to take #1!"
		local text = label(row, "Text", message, Theme.Fonts.Body, Theme.Colors.Text)
		text.Size = UDim2.fromScale(1, 1)
		stroke(text, Theme.StrokeThickness)
		return
	end
	for rank = 1, math.min(#entries, DISPLAY_ROWS) do
		local entry = entries[rank]
		local row = Instance.new("Frame")
		row.Name = "Row" .. rank
		row.LayoutOrder = rank
		row.Size = UDim2.fromScale(1, rowHeight)
		row.BackgroundColor3 = if rank % 2 == 1 then Theme.Colors.Panel else Theme.Colors.PanelAlt
		row.Parent = list
		corner(row, Theme.CornerSmall)

		local rankColor = RANK_COLORS[rank] or Theme.Colors.Ocean
		local badge = Instance.new("Frame")
		badge.Name = "Rank"
		badge.Size = UDim2.fromScale(0.12, 0.84)
		badge.Position = UDim2.fromScale(0.01, 0.08)
		badge.BackgroundColor3 = rankColor
		badge.Parent = row
		corner(badge, Theme.CornerPill)
		local rankText = label(badge, "Text", "#" .. rank, Theme.Fonts.Number, Theme.Colors.Text)
		rankText.Size = UDim2.fromScale(0.9, 0.8)
		rankText.Position = UDim2.fromScale(0.05, 0.1)
		stroke(rankText, Theme.StrokeThickness)

		local nameText = label(row, "Name", entry.Name, Theme.Fonts.Title, Theme.Colors.TextDark)
		nameText.Size = UDim2.fromScale(0.5, 0.7)
		nameText.Position = UDim2.fromScale(0.16, 0.15)
		nameText.TextXAlignment = Enum.TextXAlignment.Left

		local valueText = label(row, "Value", board.FormatValue(entry.Value), Theme.Fonts.Number, Theme.Colors.Coins)
		valueText.Size = UDim2.fromScale(0.3, 0.7)
		valueText.Position = UDim2.fromScale(0.68, 0.15)
		valueText.TextXAlignment = Enum.TextXAlignment.Right
		stroke(valueText, Theme.StrokeThickness)
	end
end

local function attach(board: Board, instance: Instance)
	if not instance:IsA("BasePart") or surfaces[instance] then
		return
	end
	local part = instance :: BasePart
	buildSurface(part, board)
	renderRows(part, board, SCOPES[scopeIndex])
	part.Destroying:Connect(function()
		surfaces[part] = nil
	end)
end

local function redraw()
	local scope = SCOPES[scopeIndex]
	for _, board in boards do
		for _, instance in CollectionService:GetTagged(board.Tag) do
			if instance:IsA("BasePart") then
				if surfaces[instance] then
					renderRows(instance :: BasePart, board, scope)
				else
					attach(board, instance)
				end
			end
		end
	end
end

function LeaderboardService.GetScope(): Scope
	return SCOPES[scopeIndex]
end

function LeaderboardService.SetScope(scope: Scope)
	scopeIndex = table.find(SCOPES, scope) or 1
	redraw()
end

-- Refresh (DataStore cadence) -------------------------------------------------------------------

function LeaderboardService.Refresh()
	local now = os.time()
	local players = DataService.GetLoadedPlayers()
	-- writes: all-time values, then weekly deltas (only what changed), within the budget
	local budget = writeBudget()
	for _, player in players do
		if budget < 4 then
			break
		end
		for _, board in boards do
			writeAllTime(board, player)
		end
		local session = sessions[player]
		if session then
			writeWeekly(player, session)
			rollWeek(session, now)
		end
		budget = writeBudget()
	end
	-- reads: all-time + this week's stores (fallback: players in this server)
	for _, board in boards do
		board.Entries.AllTime = fetchSorted(board.AllTimeStoreName, board.AllTimeStore) or allTimeLocal(board)
		local weekName = LeaderboardService.WeeklyStoreName(board.Kind, now)
		board.Entries.Week = fetchSorted(weekName, weeklyStore(weekName)) or weekLocal(board)
	end
	redraw()
end

-- Lifecycle ---------------------------------------------------------------------------------------

function LeaderboardService.Init()
	ServerSignals.Dug:Connect(onDug)
	if DataService.IsMock() then
		return
	end
	storesEnabled = true
	for _, board in boards do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(board.AllTimeStoreName)
		end)
		if ok then
			board.AllTimeStore = store
		else
			warn("[LeaderboardService] no OrderedDataStore " .. board.AllTimeStoreName .. ": " .. tostring(store))
		end
	end
end

function LeaderboardService.Start()
	for _, board in boards do
		for _, instance in CollectionService:GetTagged(board.Tag) do
			attach(board, instance)
		end
		CollectionService:GetInstanceAddedSignal(board.Tag):Connect(function(instance: Instance)
			attach(board, instance)
		end)
	end
	task.spawn(function()
		task.wait(5) -- let the first players load
		while true do
			local ok, err = pcall(function(): any
				LeaderboardService.Refresh()
				return nil
			end)
			if not ok then
				warn("[LeaderboardService] refresh failed: " .. tostring(err))
			end
			task.wait(Config.LEADERBOARD_REFRESH_SECONDS)
		end
	end)
	-- scope cycling: redraw only (cached entries + live server scope), no requests
	task.spawn(function()
		while true do
			task.wait(LB.CycleSeconds)
			scopeIndex = scopeIndex % #SCOPES + 1
			local ok, err = pcall(function(): any
				redraw()
				return nil
			end)
			if not ok then
				warn("[LeaderboardService] redraw failed: " .. tostring(err))
			end
		end
	end)
end

function LeaderboardService.OnPlayerAdded(player: Player)
	getSession(player)
end

function LeaderboardService.OnPlayerRemoving(player: Player)
	-- Final writes while data is still in memory (DataService releases after us).
	for _, board in boards do
		task.spawn(writeAllTime, board, player)
	end
	local session = sessions[player]
	sessions[player] = nil
	if session then
		task.spawn(writeWeekly, player, session)
	end
end

return LeaderboardService
