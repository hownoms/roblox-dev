--!strict
--[[
	PlotService — plot ownership, spawning, surface teleport, depth tracking.

	- On join a free plot from World.GetPlots() is assigned (fires PlotAssigned(plot); the client
	  can also call GetPlot()). If none is free the player waits in a queue and is told so.
	- Characters (re)spawn at their plot's SpawnCFrame.
	- ReturnToSurface() teleports back to the plot surface (cooldown RETURN_COOLDOWN).
	- On leave: World.ResetPlot(id) ("the tide washes it away") and the plot is freed.
	- Depth: every DEPTH_TICK the character's feet depth inside its own plot is published as the
	  Player attribute "Depth" (studs below surface, for HUD / layer ambience). MaxDepth is driven
	  by successful digs (ReportDig) and by character depth capped at the deepest dug point of the
	  plot, so flying exploiters can't fake depth records.
	- Other attributes: Player "PlotId" (0 = none), Workspace "PlotOwner_<id>" (UserId, 0 = free).

	Public API:
		PlotService.GetPlot(player): PlotInfo?
		PlotService.IsResetting(player): boolean
		PlotService.TeleportToSurface(player)
		PlotService.ReportDig(player, depth, bottomDepth): (newRecord, newLayer)
		PlotService.ResetPlayerPlot(player)   -- teleport to surface, then refill (rebirth)
		PlotService.GetCurrentDepth(player): number
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)

local World = require(script.Parent.Parent.World)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local Analytics = require(script.Parent.Analytics)
local ServerSignals = require(script.Parent.ServerSignals)

type PlotState = {
	Info: Types.PlotInfo,
	Owner: Player?,
	DeepestDug: number, -- deepest point any dig reached in this plot since the last reset
	Resetting: boolean,
}

local RETURN_COOLDOWN = 3
local DEPTH_TICK = 0.5
local SPAWN_LIFT = Vector3.new(0, 3, 0)

local PlotService = {}

local plots: { PlotState } = {}
local plotOf: { [Player]: PlotState } = {}
local waiting: { Player } = {}
local lastReturn: { [Player]: number } = {}
local currentDepth: { [Player]: number } = {}

local function publishOwner(state: PlotState)
	Workspace:SetAttribute("PlotOwner_" .. tostring(state.Info.Id), if state.Owner then state.Owner.UserId else 0)
	local ok, err = pcall(function(): any
		World.SetPlotOwner(state.Info.Id, state.Owner)
		return nil
	end)
	if not ok then
		warn("[PlotService] World.SetPlotOwner failed: " .. tostring(err))
	end
end

local function resetWorldPlot(state: PlotState)
	state.Resetting = true
	local ok, err = pcall(function(): any
		World.ResetPlot(state.Info.Id)
		return nil
	end)
	if not ok then
		warn("[PlotService] World.ResetPlot failed: " .. tostring(err))
	end
	state.DeepestDug = 0
	state.Resetting = false
end

local function teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if character then
		character:PivotTo(cframe + SPAWN_LIFT)
	end
end

local function assign(player: Player): boolean
	for _, state in plots do
		if state.Owner == nil and not state.Resetting then
			state.Owner = player
			plotOf[player] = state
			player:SetAttribute("PlotId", state.Info.Id)
			publishOwner(state)
			Net.FireClient("PlotAssigned", player, state.Info)
			teleport(player, state.Info.SpawnCFrame)
			return true
		end
	end
	return false
end

local function serveQueue()
	while #waiting > 0 do
		local player = waiting[1]
		if player.Parent == nil then
			table.remove(waiting, 1)
		elseif assign(player) then
			table.remove(waiting, 1)
			Net.Notify(player, "Success", "A dig spot is free - it's yours!")
		else
			return
		end
	end
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

local function measureDepth(player: Player, state: PlotState): number?
	local maybeRoot = Net.GetRoot(player)
	if not maybeRoot then
		return nil
	end
	local root = maybeRoot :: BasePart
	local character = root.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid then humanoid.HipHeight else 2
	local feet = root.Position - Vector3.new(0, root.Size.Y / 2 + hip, 0)
	local info = state.Info
	local localPos = info.Origin:PointToObjectSpace(feet)
	if math.abs(localPos.X) > info.Size.X / 2 or math.abs(localPos.Z) > info.Size.Z / 2 then
		return 0 -- outside the plot column: on the beach
	end
	return math.clamp(-localPos.Y, 0, info.Size.Y)
end

local function depthTick()
	for player, state in plotOf do
		local depth = measureDepth(player, state)
		if depth then
			currentDepth[player] = depth
			local rounded = math.floor(depth)
			if player:GetAttribute("Depth") ~= rounded then
				player:SetAttribute("Depth", rounded)
			end
			-- Record only what the plot's actual hole allows (anti fly/noclip).
			updateMaxDepth(player, math.min(depth, state.DeepestDug))
		end
	end
end

-- Public API ------------------------------------------------------------------------------------

function PlotService.GetPlot(player: Player): Types.PlotInfo?
	local state = plotOf[player]
	return if state then state.Info else nil
end

function PlotService.IsResetting(player: Player): boolean
	local state = plotOf[player]
	return state ~= nil and state.Resetting
end

function PlotService.GetCurrentDepth(player: Player): number
	return currentDepth[player] or 0
end

function PlotService.TeleportToSurface(player: Player)
	local state = plotOf[player]
	if state then
		teleport(player, state.Info.SpawnCFrame)
	end
end

-- Called by DigService after a successful dig. `depth` = dig point depth, `bottomDepth` = the
-- deepest point the dig sphere removed. Returns (newMaxDepthRecord, reachedNewLayer).
function PlotService.ReportDig(player: Player, depth: number, bottomDepth: number): (boolean, boolean)
	local state = plotOf[player]
	if state then
		state.DeepestDug = math.max(state.DeepestDug, bottomDepth)
	end
	return updateMaxDepth(player, depth)
end

function PlotService.ResetPlayerPlot(player: Player)
	local state = plotOf[player]
	if not state then
		return
	end
	teleport(player, state.Info.SpawnCFrame)
	task.spawn(resetWorldPlot, state)
end

-- Lifecycle -------------------------------------------------------------------------------------

function PlotService.Init()
	local ok, infos = pcall(World.GetPlots)
	if not ok or type(infos) ~= "table" then
		warn("[PlotService] World.GetPlots failed: " .. tostring(infos))
		infos = {}
	end
	for _, info in infos :: { Types.PlotInfo } do
		local state: PlotState = { Info = info, Owner = nil, DeepestDug = 0, Resetting = false }
		table.insert(plots, state)
		publishOwner(state)
	end
	-- Lowest id first = nearest to the hub.
	table.sort(plots, function(a: PlotState, b: PlotState)
		return a.Info.Id < b.Info.Id
	end)
	if #plots == 0 then
		warn("[PlotService] no plots available from World.GetPlots()")
	end

	Net.OnInvoke("GetPlot", function(player: Player)
		return PlotService.GetPlot(player)
	end, nil, { Rate = 5, Window = 1 })

	Net.On("ReturnToSurface", function(player: Player)
		local now = os.clock()
		local last = lastReturn[player]
		if last and now - last < RETURN_COOLDOWN then
			Net.NotifyThrottled(player, "Error", "Wait a moment...", "ReturnCooldown", 1)
			return
		end
		lastReturn[player] = now
		PlotService.TeleportToSurface(player)
	end, { Rate = 3, Window = 1, RequireData = false })
end

function PlotService.Start()
	task.spawn(function()
		while true do
			task.wait(DEPTH_TICK)
			depthTick()
		end
	end)
	-- A plot can't be "owned" by someone who left without PlayerRemoving firing (paranoia).
	task.spawn(function()
		while true do
			task.wait(30)
			for player in plotOf do
				if player.Parent == nil then
					PlotService.OnPlayerRemoving(player)
				end
			end
		end
	end)
end

function PlotService.OnPlayerAdded(player: Player)
	player:SetAttribute("PlotId", 0)
	player:SetAttribute("Depth", 0)
	player.CharacterAdded:Connect(function(character: Model)
		local state = plotOf[player]
		if not state then
			return
		end
		task.defer(function()
			character:WaitForChild("HumanoidRootPart", 5)
			if character.Parent and plotOf[player] == state then
				character:PivotTo(state.Info.SpawnCFrame + SPAWN_LIFT)
			end
		end)
	end)

	if not assign(player) then
		table.insert(waiting, player)
		Net.Notify(player, "Info", "All dig spots are taken! You'll get one as soon as someone leaves.")
	end

	task.spawn(function()
		if DataService.WaitForData(player, 60) then
			Analytics.Funnel(player, Analytics.Steps.Joined)
		end
	end)
end

function PlotService.OnPlayerRemoving(player: Player)
	lastReturn[player] = nil
	currentDepth[player] = nil
	local index = table.find(waiting, player)
	if index then
		table.remove(waiting, index)
	end
	local state = plotOf[player]
	if not state then
		return
	end
	plotOf[player] = nil
	task.spawn(function()
		resetWorldPlot(state)
		state.Owner = nil
		publishOwner(state)
		serveQueue()
	end)
end

-- Players that existed before Start (Studio Play Solo) are handled by Main.
function PlotService.GetOwners(): { [number]: Player }
	local owners = {}
	for _, state in plots do
		if state.Owner then
			owners[state.Info.Id] = state.Owner
		end
	end
	return owners
end

return PlotService
