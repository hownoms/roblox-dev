--!strict
--[[
	LeaderboardService — global boards (OrderedDataStores Config.LEADERBOARD_COINS_STORE /
	Config.LEADERBOARD_DEPTH_STORE) rendered on parts tagged "LeaderboardCoins" /
	"LeaderboardDepth" (SurfaceGui on the part's Front face, cartoon styling from Config.Theme).

	Every Config.LEADERBOARD_REFRESH_SECONDS: write changed values of players in this server,
	read the top Config.LEADERBOARD_SIZE, resolve names (cached) and redraw. In Studio without
	DataStore access (or if a read fails) the board shows the players in this server instead.
]]

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)

type Entry = { UserId: number, Name: string, Value: number }

type Board = {
	Tag: string,
	Title: string,
	StoreName: string,
	Store: OrderedDataStore?,
	ValueOf: (data: Types.PlayerData) -> number,
	FormatValue: (value: number) -> string,
	LastWritten: { [number]: number },
	Entries: { Entry },
}

local DISPLAY_ROWS = math.min(Config.LEADERBOARD_SIZE, 10)
local MAX_ORDERED_VALUE = 2 ^ 53
local PIXELS_PER_STUD = 50

local LeaderboardService = {}

local nameCache: { [number]: string } = {}
local surfaces: { [BasePart]: Frame } = {} -- part -> list frame

local boards: { Board } = {
	{
		Tag = "LeaderboardCoins",
		Title = "RICHEST DIGGERS",
		StoreName = Config.LEADERBOARD_COINS_STORE,
		Store = nil,
		ValueOf = function(data: Types.PlayerData): number
			return data.Coins
		end,
		FormatValue = function(value: number): string
			return Format.Abbreviate(value)
		end,
		LastWritten = {},
		Entries = {},
	},
	{
		Tag = "LeaderboardDepth",
		Title = "DEEPEST DIGGERS",
		StoreName = Config.LEADERBOARD_DEPTH_STORE,
		Store = nil,
		ValueOf = function(data: Types.PlayerData): number
			return data.MaxDepth
		end,
		FormatValue = function(value: number): string
			return Format.Depth(value)
		end,
		LastWritten = {},
		Entries = {},
	},
}

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

-- Data --------------------------------------------------------------------------------------------

local function writePlayer(board: Board, player: Player)
	local store = board.Store
	local data = DataService.Get(player)
	if not store or not data then
		return
	end
	local value = clampValue(board.ValueOf(data))
	if board.LastWritten[player.UserId] == value or value <= 0 then
		return
	end
	local ok = retry(2, function()
		store:SetAsync(tostring(player.UserId), value)
		return true
	end)
	if ok then
		board.LastWritten[player.UserId] = value
	end
end

local function localEntries(board: Board): { Entry }
	local entries = {}
	for _, player in DataService.GetLoadedPlayers() do
		local data = DataService.Get(player)
		if data then
			table.insert(
				entries,
				{ UserId = player.UserId, Name = player.DisplayName, Value = clampValue(board.ValueOf(data)) }
			)
		end
	end
	table.sort(entries, function(a: Entry, b: Entry)
		return a.Value > b.Value
	end)
	return entries
end

local function fetch(board: Board): { Entry }
	local store = board.Store
	if not store then
		return localEntries(board)
	end
	local ok, page = retry(2, function()
		local pages = store:GetSortedAsync(false, math.clamp(Config.LEADERBOARD_SIZE, 1, 100))
		return pages:GetCurrentPage()
	end)
	if not ok or type(page) ~= "table" then
		return localEntries(board)
	end
	local entries = {}
	for _, item in page :: { any } do
		local userId = tonumber(item.key)
		local value = tonumber(item.value)
		if userId and value then
			table.insert(entries, { UserId = userId, Name = resolveName(userId), Value = value })
		end
	end
	return entries
end

-- Rendering ---------------------------------------------------------------------------------------

local Theme = Config.Theme
local RANK_COLORS = {
	Theme.Colors.Gold,
	Color3.fromRGB(215, 220, 230),
	Color3.fromRGB(230, 150, 90),
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

local function buildSurface(part: BasePart, board: Board): Frame
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
	title.Size = UDim2.fromScale(1, 0.14)
	title.BackgroundColor3 = Theme.Colors.Gold
	title.Parent = root
	corner(title, Theme.CornerMedium)
	stroke(title, Theme.StrokeThickness * 2)
	local titleText = label(title, "Text", board.Title, Theme.Fonts.Title, Theme.Colors.Text)
	titleText.Size = UDim2.fromScale(0.94, 0.8)
	titleText.Position = UDim2.fromScale(0.03, 0.1)
	stroke(titleText, Theme.StrokeThickness * 2)

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0, 0.17)
	list.Size = UDim2.fromScale(1, 0.83)
	list.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.01, 0)
	layout.Parent = list

	gui.Parent = part
	return list
end

local function renderRows(list: Frame, board: Board)
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local rowHeight = 1 / DISPLAY_ROWS - 0.01
	if #board.Entries == 0 then
		local row = Instance.new("Frame")
		row.Name = "Empty"
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, rowHeight * 2)
		row.Parent = list
		local text = label(row, "Text", "Start digging to get on the board!", Theme.Fonts.Body, Theme.Colors.Text)
		text.Size = UDim2.fromScale(1, 1)
		stroke(text, Theme.StrokeThickness)
		return
	end
	for rank = 1, math.min(#board.Entries, DISPLAY_ROWS) do
		local entry = board.Entries[rank]
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
	local list = buildSurface(part, board)
	surfaces[part] = list
	renderRows(list, board)
	part.Destroying:Connect(function()
		surfaces[part] = nil
	end)
end

local function redraw(board: Board)
	for _, instance in CollectionService:GetTagged(board.Tag) do
		if instance:IsA("BasePart") then
			local list = surfaces[instance]
			if list then
				renderRows(list, board)
			else
				attach(board, instance)
			end
		end
	end
end

local function refresh()
	for _, board in boards do
		for _, player in DataService.GetLoadedPlayers() do
			writePlayer(board, player)
		end
		board.Entries = fetch(board)
		redraw(board)
	end
end

-- Lifecycle ---------------------------------------------------------------------------------------

function LeaderboardService.Init()
	if DataService.IsMock() then
		return
	end
	for _, board in boards do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(board.StoreName)
		end)
		if ok then
			board.Store = store
		else
			warn("[LeaderboardService] no OrderedDataStore " .. board.StoreName .. ": " .. tostring(store))
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
			local ok, err = pcall(refresh)
			if not ok then
				warn("[LeaderboardService] refresh failed: " .. tostring(err))
			end
			task.wait(Config.LEADERBOARD_REFRESH_SECONDS)
		end
	end)
end

function LeaderboardService.OnPlayerRemoving(player: Player)
	-- Final write while data is still in memory (DataService releases after us).
	for _, board in boards do
		task.spawn(writePlayer, board, player)
	end
end

return LeaderboardService
