--!strict
--[[
	BeachService — the shared open beach (replaces v1 PlotService). See docs/V2.md.

	- Spawning: every character (re)spawns on the boardwalk (World.GetSpawnCFrame), facing the
	  sand. There are no plots, so there is no join queue (Config.MAX_PLAYERS = 16).
	- ReturnToSurface(): teleports to World.GetSurfacePoint(near the character) (cooldown).
	- Depth: every DEPTH_TICK the character's feet depth is published as the Player attribute
	  "Depth" (studs below the surface; 0 outside the dig zone or above the surface).
	- MaxDepth anti-cheat: depth only counts where terrain was actually dug. Dug terrain is
	  tracked on a coarse grid of CELL x CELL stud columns ("cells") with the deepest dug point;
	  standing depth is capped at the deepest dug point of the cell under the feet.
	- Tide: a cell refills (bottom-up, layer materials, throttled per frame) once no player was
	  within Config.TIDE_CLEAR_RADIUS studs (horizontally) for Config.TIDE_REFILL_SECONDS.
	  High Tide (workspace attribute ActiveEvents contains "HighTide") lifts everyone standing
	  in a dug column to the surface and then smooths every dug cell. Never buries a player:
	  anyone inside a column is lifted out before each refill step.

	Public API:
		BeachService.TeleportToSurface(player)
		BeachService.RecordCarve(min: Vector3, max: Vector3)   -- DigService after every carve
		BeachService.ReportDig(player, depth): (newRecord, newLayer)
		BeachService.GetCurrentDepth(player): number
		BeachService.GetDugDepthAt(position): number   -- deepest dug point of that cell (studs)
		BeachService.CountDugCells(): number
		BeachService.TideStep(force: boolean?)          -- one tide pass now (tests / dev)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)

local World = require(script.Parent.Parent.World)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local Analytics = require(script.Parent.Analytics)
local ServerSignals = require(script.Parent.ServerSignals)

local RETURN_COOLDOWN = 3
local DEPTH_TICK = 0.5
local TIDE_TICK = 1
local CELL = 8 -- tide / anti-cheat grid (studs); dig zone edges are multiples of this
local CHUNK = 128 -- studs of column refilled per FillBlock step
local VOXELS_PER_FRAME = 4096 -- refill budget before yielding a frame
local LIFT_MARGIN = 3 -- studs around a column that still count as "inside" it
local DEPTH_SLACK = 4 -- standing depth may exceed the deepest dug point by this much

local S = Config.SURFACE_Y
local BOTTOM_Y = S - Config.TOTAL_DEPTH

type Cell = {
	CX: number,
	CZ: number,
	Deepest: number, -- studs below the surface of the deepest carve in this column
	LastActive: number, -- os.clock() of the last dig in / player near this column
	Version: number, -- bumped by every carve (a refill in progress notices new digs)
}

local BeachService = {}

local cells: { [number]: Cell } = {}
local lastReturn: { [Player]: number } = {}
local currentDepth: { [Player]: number } = {}
local highTidePending = false
local highTideActive = false
local tideBusy = false

local function cellKey(cx: number, cz: number): number
	return (cx + 4096) * 8192 + (cz + 4096)
end

local function cellAt(position: Vector3): Cell?
	return cells[cellKey(math.floor(position.X / CELL), math.floor(position.Z / CELL))]
end

-- Horizontal distance from `pos` to the cell's rectangle (0 inside).
local function cellDistance(cell: Cell, pos: Vector3): number
	local x0, z0 = cell.CX * CELL, cell.CZ * CELL
	local dx = math.max(x0 - pos.X, 0, pos.X - (x0 + CELL))
	local dz = math.max(z0 - pos.Z, 0, pos.Z - (z0 + CELL))
	return math.sqrt(dx * dx + dz * dz)
end

local function getRoots(): { BasePart }
	local roots = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(roots, root)
		end
	end
	return roots
end

local function liftRoot(root: BasePart)
	local character = root.Parent
	if character and character:IsA("Model") then
		character:PivotTo(World.GetSurfacePoint(root.Position))
	end
end

-- Lift anyone whose character is inside the column (below the surface).
local function liftFromCell(cell: Cell)
	for _, root in getRoots() do
		if root.Position.Y < S + 1 and cellDistance(cell, root.Position) <= LIFT_MARGIN then
			liftRoot(root)
		end
	end
end

local function anyoneNear(cell: Cell, radius: number): boolean
	for _, root in getRoots() do
		if cellDistance(cell, root.Position) <= radius then
			return true
		end
	end
	return false
end

-- Refill one cell bottom-up. Normal tide aborts as soon as someone comes near or digs in it;
-- `force` (High Tide) lifts people out and carries on. Returns true when the cell is solid.
local function refillCell(cell: Cell, force: boolean): boolean
	local key = cellKey(cell.CX, cell.CZ)
	local x0, z0 = cell.CX * CELL, cell.CZ * CELL
	local version = cell.Version
	local y = math.max(BOTTOM_Y, math.floor((S - cell.Deepest) / 4) * 4 - 4)
	local budget = VOXELS_PER_FRAME
	while y < S do
		if cells[key] ~= cell then
			return false
		end
		if not force and (cell.Version ~= version or anyoneNear(cell, Config.TIDE_CLEAR_RADIUS)) then
			cell.LastActive = os.clock()
			return false
		end
		liftFromCell(cell)
		local top = math.min(S, y + CHUNK)
		debug.profilebegin("DigTheBeach.Tide.FillChunk")
		World.FillLayered(Vector3.new(x0, y, z0), Vector3.new(x0 + CELL, top, z0 + CELL))
		debug.profileend()
		if cell.Version == version then
			cell.Deepest = math.max(0, S - top)
		end
		budget -= (CELL / 4) * (CELL / 4) * ((top - y) / 4)
		y = top
		if budget <= 0 then
			budget = VOXELS_PER_FRAME
			task.wait()
		end
	end
	if cell.Version ~= version then
		return false -- dug again while refilling (High Tide): keep it for the next pass
	end
	if cells[key] == cell then
		cells[key] = nil
	end
	return true
end

local function inDugColumn(pos: Vector3): boolean
	if pos.Y >= S + 1 or not World.IsInDigZone(pos) then
		return false
	end
	for dx = -1, 1 do
		for dz = -1, 1 do
			local cell = cells[cellKey(math.floor(pos.X / CELL) + dx, math.floor(pos.Z / CELL) + dz)]
			if cell and cell.Deepest > 0 and cellDistance(cell, pos) <= LIFT_MARGIN then
				return true
			end
		end
	end
	return false
end

local function liftAllFromHoles()
	for _, root in getRoots() do
		if inDugColumn(root.Position) then
			liftRoot(root)
		end
	end
end

function BeachService.TideStep(force: boolean?)
	if tideBusy then
		return
	end
	tideBusy = true
	local now = os.clock()
	local roots = getRoots()
	local smoothing = force == true or highTidePending
	highTidePending = false
	if smoothing then
		liftAllFromHoles()
	end
	local due: { Cell } = {}
	for _, cell in cells do
		if not smoothing then
			for _, root in roots do
				if cellDistance(cell, root.Position) <= Config.TIDE_CLEAR_RADIUS then
					cell.LastActive = now
					break
				end
			end
		end
		if smoothing or now - cell.LastActive >= Config.TIDE_REFILL_SECONDS then
			table.insert(due, cell)
		end
	end
	for _, cell in due do
		local ok, err = pcall(refillCell, cell, smoothing)
		if not ok then
			warn("[BeachService] tide refill failed: " .. tostring(err))
		end
	end
	tideBusy = false
end

-- Depth -----------------------------------------------------------------------------------------

local function updateMaxDepth(player: Player, depth: number): (boolean, boolean)
	local maybeData = DataService.Get(player)
	if not maybeData then
		return false, false
	end
	local data = maybeData :: Types.PlayerData
	local newDepth = math.floor(math.clamp(depth, 0, Config.TOTAL_DEPTH))
	if newDepth <= data.MaxDepth then
		return false, false
	end
	local oldLayer = Config.GetLayerIndexAtDepth(data.MaxDepth)
	local newLayer = Config.GetLayerIndexAtDepth(newDepth)
	DataService.Set(player, "MaxDepth", newDepth)
	ServerSignals.DepthReached:Fire(player, newDepth)
	return true, newLayer > oldLayer
end

local function measureDepth(player: Player): (number, Vector3?)
	local maybeRoot = Net.GetRoot(player)
	if not maybeRoot then
		return 0, nil
	end
	local root = maybeRoot :: BasePart
	local character = root.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid then humanoid.HipHeight else 2
	local feet = root.Position - Vector3.new(0, root.Size.Y / 2 + hip, 0)
	if not World.IsInDigZone(feet) then
		return 0, feet
	end
	return math.clamp(S - feet.Y, 0, Config.TOTAL_DEPTH), feet
end

local function depthTick()
	for _, player in Players:GetPlayers() do
		local depth, feet = measureDepth(player)
		currentDepth[player] = depth
		local rounded = math.floor(depth)
		if player:GetAttribute("Depth") ~= rounded then
			player:SetAttribute("Depth", rounded)
		end
		if feet and depth > 0 then
			-- Record only what the dug terrain allows (anti fly / noclip).
			local cell = cellAt(feet)
			local dug = if cell then cell.Deepest + DEPTH_SLACK else 0
			updateMaxDepth(player, math.min(depth, dug))
		end
	end
end

-- Public API ------------------------------------------------------------------------------------

function BeachService.GetCurrentDepth(player: Player): number
	return currentDepth[player] or 0
end

function BeachService.TeleportToSurface(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local model = character :: Model
	local root = model:FindFirstChild("HumanoidRootPart")
	local near = if root and root:IsA("BasePart") then root.Position else model:GetPivot().Position
	model:PivotTo(World.GetSurfacePoint(near))
end

-- Called after every carve (DigService, dev commands): marks the overlapped cells as dug.
function BeachService.RecordCarve(minV: Vector3, maxV: Vector3)
	local now = os.clock()
	local deepest = math.clamp(S - minV.Y, 0, Config.TOTAL_DEPTH)
	for cx = math.floor(minV.X / CELL), math.ceil(maxV.X / CELL) - 1 do
		for cz = math.floor(minV.Z / CELL), math.ceil(maxV.Z / CELL) - 1 do
			local key = cellKey(cx, cz)
			local cell = cells[key]
			if not cell then
				cell = { CX = cx, CZ = cz, Deepest = 0, LastActive = now, Version = 0 }
				cells[key] = cell
			end
			local c = cell :: Cell
			c.Deepest = math.max(c.Deepest, deepest)
			c.LastActive = now
			c.Version += 1
		end
	end
end

-- After a successful dig at `depth` studs. Returns (newMaxDepthRecord, reachedNewLayer).
function BeachService.ReportDig(player: Player, depth: number): (boolean, boolean)
	return updateMaxDepth(player, depth)
end

function BeachService.GetDugDepthAt(position: Vector3): number
	local cell = cellAt(position)
	return if cell then cell.Deepest else 0
end

function BeachService.CountDugCells(): number
	local n = 0
	for _ in cells do
		n += 1
	end
	return n
end

-- Lifecycle -------------------------------------------------------------------------------------

local function hasHighTide(): boolean
	local raw = Workspace:GetAttribute("ActiveEvents")
	if typeof(raw) ~= "string" then
		return false
	end
	for id in string.gmatch(raw, "[^,%s]+") do
		if id == "HighTide" then
			return true
		end
	end
	return false
end

function BeachService.Init()
	Net.On("ReturnToSurface", function(player: Player)
		local now = os.clock()
		local last = lastReturn[player]
		if last and now - last < RETURN_COOLDOWN then
			Net.NotifyThrottled(player, "Error", "Wait a moment...", "ReturnCooldown", 1)
			return
		end
		lastReturn[player] = now
		BeachService.TeleportToSurface(player)
	end, { Rate = 3, Window = 1, RequireData = false })

	highTideActive = hasHighTide()
	Workspace:GetAttributeChangedSignal("ActiveEvents"):Connect(function()
		local active = hasHighTide()
		if active and not highTideActive then
			highTidePending = true
			liftAllFromHoles() -- lift first, the smoothing pass follows within a tick
		end
		highTideActive = active
	end)
end

function BeachService.Start()
	task.spawn(function()
		while true do
			task.wait(DEPTH_TICK)
			depthTick()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(TIDE_TICK)
			local ok, err = pcall(function(): boolean
				BeachService.TideStep(false)
				return true
			end)
			if not ok then
				tideBusy = false
				warn("[BeachService] tide error: " .. tostring(err))
			end
		end
	end)
end

function BeachService.OnPlayerAdded(player: Player)
	player:SetAttribute("Depth", 0)
	local function onCharacter(character: Model)
		task.defer(function()
			character:WaitForChild("HumanoidRootPart", 5)
			if character.Parent and player.Character == character then
				character:PivotTo(World.GetSpawnCFrame())
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	task.spawn(function()
		if DataService.WaitForData(player, 60) then
			Analytics.Funnel(player, Analytics.Steps.Joined)
		end
	end)
end

function BeachService.OnPlayerRemoving(player: Player)
	lastReturn[player] = nil
	currentDepth[player] = nil
end

return BeachService
