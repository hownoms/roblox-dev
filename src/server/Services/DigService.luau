--!strict
--[[
	DigService — the Dig remote (docs/ARCHITECTURE.md "Core mechanic").

	Dig(position: Vector3) validation, in order (first failure -> DigResult{Success=false,Reason}):
	  NoPlot       player has no plot (queue) / plot is being refilled
	  Cooldown     less than shovel cooldown / speed x COOLDOWN_LENIENCY since the last dig
	  OutOfPlot    point is not inside the player's own plot column
	  Bottom       point is at the very bottom of the plot (The Core floor is indestructible)
	  TooFar       point further than Config.REACH (+ small latency slack) from HumanoidRootPart
	  TooHard      shovel Power < Hardness of the layer at that depth
	  BackpackFull Sand >= effective capacity
	Points with no solid terrain near them are ignored silently (no result).
	The dig sphere center is clamped so the sphere never cuts plot walls or the floor.
	Success: FillBall(center, shovel.Radius, Air), sand (Stats) into the backpack (capped at
	capacity), MaxDepth / layer bookkeeping via PlotService, treasure roll (layer chance x luck,
	capped; luck boosts non-Common weights), DigResult to the digger.
	The 8th dig of a brand-new player's first session always finds a Common treasure (GDD §8).

	AutoDig pass: SetSetting("AutoDig", true|false). While on (and the pass is owned) the server
	digs straight down below the character's feet at the shovel's normal cooldown.

	Public API:
		DigService.TryDig(player, position, isAuto): Types.DigResult?
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Stats = require(Shared.Util.Stats)
local Weighted = require(Shared.Util.Weighted)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local MultiplierService = require(script.Parent.MultiplierService)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local ServerSignals = require(script.Parent.ServerSignals)
local SettingsService = require(script.Parent.SettingsService)

local REACH_SLACK = 2 -- studs of latency slack on top of Config.REACH
local SURFACE_SLACK = 4 -- how far above the plot surface a dig point may be
local BOTTOM_FLOOR = 2 -- studs of indestructible floor kept at the bottom of the plot
local EDGE_SLACK = 1 -- dig points may be this far outside the footprint (surface rounding)
local FTUE_TREASURE_DIG = 8
local AUTO_TICK = 0.05

local DigService = {}

local terrain = Workspace.Terrain
local rng = Random.new()

local lastDig: { [Player]: number } = {}
local lastFailResult: { [Player]: number } = {}
local sessionDigs: { [Player]: number } = {}

local function baseResult(position: Vector3): Types.DigResult
	return {
		Success = false,
		Reason = nil,
		Position = position,
		Radius = 0,
		SandGained = 0,
		Sand = 0,
		Capacity = 0,
		Depth = 0,
		LayerIndex = 1,
		NewMaxDepth = false,
		NewLayer = false,
		TreasureId = nil,
	}
end

local VOXEL = 4 -- terrain resolution; carving whole voxels makes every dig visible

-- Prints why a dig was silently ignored. Studio only, at most once per reason per 5 seconds.
local debugThrottle: { [string]: number } = {}
local function studioDebug(player: Player, reason: string, detail: string)
	if not RunService:IsStudio() then
		return
	end
	local key = player.Name .. reason
	local now = os.clock()
	if (debugThrottle[key] or 0) + 5 > now then
		return
	end
	debugThrottle[key] = now
	print(string.format("[DigService] %s dig ignored: %s", player.Name, detail))
end

-- Removes a voxel-aligned cube of terrain at the dig point. Shovel radius sets the cube size
-- (radius 2 = one 4-stud voxel, radius 6 = 3x3x3 voxels). The cube is clamped to voxels fully
-- inside the plot column so plot walls and the floor never break.
local function carve(plot: Types.PlotInfo, target: Vector3, radius: number)
	local cells = math.max(1, math.floor(radius * 2 / VOXEL + 0.5))
	local origin = plot.Origin.Position
	local half = plot.Size / 2
	local function axisStart(value: number, minEdge: number, maxEdge: number): number
		local lo = math.ceil(minEdge / VOXEL)
		local hi = math.floor(maxEdge / VOXEL) - cells
		local start = math.floor(value / VOXEL) - math.floor((cells - 1) / 2)
		return if hi < lo then lo else math.clamp(start, lo, hi)
	end
	local sx = axisStart(target.X, origin.X - half.X, origin.X + half.X)
	local sz = axisStart(target.Z, origin.Z - half.Z, origin.Z + half.Z)
	local floorY = origin.Y - plot.Size.Y + BOTTOM_FLOOR
	local sy = math.max(math.floor(target.Y / VOXEL) - math.floor((cells - 1) / 2), math.ceil(floorY / VOXEL))
	-- One extra voxel on top clears the partially filled surface voxel above the dig.
	local size = Vector3.new(cells, cells + 1, cells) * VOXEL
	local min = Vector3.new(sx, sy, sz) * VOXEL
	terrain:FillBlock(CFrame.new(min + size / 2), size, Enum.Material.Air)
end

-- The smooth-terrain surface a player clicks is not on voxel boundaries, so the raw hit point can
-- sit in the empty voxel above the ground. Re-cast from the digger toward the click and step 2
-- studs into the surface along its normal. 3 studs (not 2) so a hit exactly on a voxel boundary
-- still lands in the solid voxel below rather than the partially filled one above.
local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { terrain }

local function resolveTarget(position: Vector3, root: BasePart?): Vector3
	if root then
		local offset = position - root.Position
		if offset.Magnitude > 0.01 then
			local hit = Workspace:Raycast(root.Position, offset.Unit * (offset.Magnitude + 6), terrainOnly)
			if hit then
				return hit.Position - hit.Normal * 3
			end
		end
	end
	return position - Vector3.new(0, 3, 0)
end

local function hasSolidTerrainNear(position: Vector3): boolean
	local half = Vector3.new(2, 2, 2)
	local region = Region3.new(position - half, position + half):ExpandToGrid(4)
	local ok, materials, occupancies = pcall(function()
		return terrain:ReadVoxels(region, 4)
	end)
	if not ok then
		return true -- don't block digging on an engine hiccup
	end
	assert(ok) -- refine for the type checker (guarded above)
	local size: Vector3 = materials.Size
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				local material = materials[x][y][z]
				if material ~= Enum.Material.Air and material ~= Enum.Material.Water and occupancies[x][y][z] > 0 then
					return true
				end
			end
		end
	end
	return false
end

local function rollTreasure(
	player: Player,
	data: Types.PlayerData,
	ctx: Stats.Context,
	layerIndex: number
): Types.TreasureDef?
	local layer = Config.Layers[layerIndex]
	local digs = sessionDigs[player] or 0
	local forced = digs == FTUE_TREASURE_DIG and next(data.Index) == nil
	if forced then
		for _, entry in layer.LootTable do
			local def = Config.GetTreasure(entry.TreasureId)
			if def and def.Rarity == "Common" then
				return def
			end
		end
	end
	if rng:NextNumber() >= Stats.GetTreasureChance(ctx, layerIndex) then
		return nil
	end
	local luck = Stats.GetLuck(ctx)
	local entry = Weighted.Pick(layer.LootTable, function(e: Types.LootEntry): number
		local def = Config.GetTreasure(e.TreasureId)
		return Stats.LuckWeight(e.Weight, if def then def.Rarity else nil, luck)
	end, rng:NextNumber())
	return if entry then Config.GetTreasure(entry.TreasureId) else nil
end

local function awardTreasure(player: Player, treasure: Types.TreasureDef)
	DataService.Mutate(player, { "Treasures", "Index" }, function(d)
		d.Treasures[treasure.Id] = (d.Treasures[treasure.Id] or 0) + 1
		d.Index[treasure.Id] = true
	end)
	Net.FireClient("TreasureFound", player, treasure.Id, treasure.Rarity)
	local rarity = Config.GetRarity(treasure.Rarity)
	if rarity and rarity.Announce then
		Net.NotifyAll(
			"Announce",
			string.format("%s found a %s %s!", player.DisplayName, string.upper(treasure.Rarity), treasure.Name)
		)
	end
	ServerSignals.TreasureFound:Fire(player, treasure.Id)
end

local function fail(
	player: Player,
	result: Types.DigResult,
	reason: Types.DigFailReason,
	isAuto: boolean
): Types.DigResult
	result.Reason = reason
	if reason == "TooHard" then
		Net.NotifyThrottled(player, "Error", "Too hard! Need a better shovel!", "TooHard", 3)
	elseif reason == "BackpackFull" then
		Net.NotifyThrottled(player, "Error", "Backpack full! Go sell!", "BackpackFull", 3)
	elseif reason == "Bottom" then
		Net.NotifyThrottled(player, "Info", "You reached the bottom of the world!", "Bottom", 10)
	end
	-- Throttle failure replies so spamming the remote can't flood the client back.
	local now = os.clock()
	local last = lastFailResult[player]
	if not isAuto and (last == nil or now - last >= 0.2) then
		lastFailResult[player] = now
		Net.FireClient("DigResult", player, result)
	end
	return result
end

function DigService.TryDig(player: Player, position: Vector3, isAuto: boolean): Types.DigResult?
	local data = DataService.Get(player)
	local ctx = MultiplierService.GetContext(player)
	if not data or not ctx then
		return nil
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(ctx) -- refine for the type checker (guarded above)
	local result = baseResult(position)
	local plot = PlotService.GetPlot(player)
	if not plot or PlotService.IsResetting(player) then
		return fail(player, result, "NoPlot", isAuto)
	end
	assert(plot) -- refine for the type checker (guarded above)

	local shovel = Stats.GetShovel(data)
	local cooldown = Stats.GetCooldown(ctx) * (if isAuto then 1 else Config.COOLDOWN_LENIENCY)
	local now = os.clock()
	local last = lastDig[player]
	if last and now - last < cooldown then
		studioDebug(player, "Cooldown", string.format("cooldown %.2fs not elapsed", cooldown))
		return fail(player, result, "Cooldown", isAuto)
	end

	-- Plot bounds (plot-local space: origin = surface center, -Y = down).
	local localPos = plot.Origin:PointToObjectSpace(position)
	local halfX, halfZ, totalDepth = plot.Size.X / 2, plot.Size.Z / 2, plot.Size.Y
	if
		math.abs(localPos.X) > halfX + EDGE_SLACK
		or math.abs(localPos.Z) > halfZ + EDGE_SLACK
		or localPos.Y > SURFACE_SLACK
		or localPos.Y < -totalDepth - EDGE_SLACK
	then
		return fail(player, result, "OutOfPlot", isAuto)
	end
	if -localPos.Y >= totalDepth - BOTTOM_FLOOR then
		return fail(player, result, "Bottom", isAuto)
	end

	local radius = shovel.Radius
	local depth = math.clamp(-localPos.Y, 0, totalDepth)
	local layerIndex = Config.GetLayerIndexAtDepth(depth)
	local layer = Config.Layers[layerIndex]
	result.Radius = radius
	result.Depth = depth
	result.LayerIndex = layerIndex

	if not isAuto then
		local root = Net.GetRoot(player)
		if not root or (root.Position - position).Magnitude > Config.REACH + REACH_SLACK then
			return fail(player, result, "TooFar", isAuto)
		end
	end

	local target = resolveTarget(position, if isAuto then nil else Net.GetRoot(player))
	if not hasSolidTerrainNear(target) then
		studioDebug(player, "NoTerrain", "no solid terrain at " .. tostring(target))
		return nil
	end

	if shovel.Power < layer.Hardness then
		return fail(player, result, "TooHard", isAuto)
	end

	local capacity = Stats.GetCapacity(ctx)
	result.Capacity = capacity
	result.Sand = data.Sand
	if data.Sand >= capacity then
		return fail(player, result, "BackpackFull", isAuto)
	end

	-- Success ------------------------------------------------------------------------------------
	lastDig[player] = now
	sessionDigs[player] = (sessionDigs[player] or 0) + 1
	carve(plot, target, radius)

	local gained = math.min(layer.SandValue * Stats.GetSandMultiplier(ctx), capacity - data.Sand)
	DataService.Mutate(player, { "Sand", "TotalSandDug" }, function(d)
		d.Sand += gained
		d.TotalSandDug += gained
	end)
	local newRecord, newLayer = PlotService.ReportDig(player, depth, depth + radius)

	local treasure = rollTreasure(player, data, ctx, layerIndex)
	if treasure then
		awardTreasure(player, treasure)
	end

	result.Success = true
	result.SandGained = gained
	result.Sand = data.Sand
	result.NewMaxDepth = newRecord
	result.NewLayer = newLayer
	result.TreasureId = if treasure then treasure.Id else nil
	Net.FireClient("DigResult", player, result)

	ServerSignals.Dug:Fire(player, depth, gained)
	Analytics.Funnel(player, Analytics.Steps.FirstDig)
	if data.Sand >= capacity then
		ServerSignals.BackpackFull:Fire(player)
		Net.NotifyThrottled(player, "Error", "Backpack full! Go sell!", "BackpackFull", 3)
	end
	return result
end

-- AutoDig ---------------------------------------------------------------------------------------

local function autoDigEnabled(player: Player): boolean
	return SettingsService.Get(player, "AutoDig") == true and MonetizationService.OwnsPass(player, "AutoDig")
end

local function autoDigStep(player: Player)
	local root = Net.GetRoot(player)
	if not root then
		return
	end
	assert(root) -- refine for the type checker (guarded above)
	local data = DataService.Get(player)
	local ctx = MultiplierService.GetContext(player)
	if not data or not ctx then
		return
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(ctx) -- refine for the type checker (guarded above)
	if os.clock() - (lastDig[player] or 0) < Stats.GetCooldown(ctx) then
		return
	end
	if data.Sand >= Stats.GetCapacity(ctx) then
		Net.NotifyThrottled(player, "Error", "Backpack full! Go sell!", "BackpackFull", 10)
		return
	end
	local humanoid = (root.Parent :: Instance):FindFirstChildOfClass("Humanoid")
	local hip = if humanoid then humanoid.HipHeight else 2
	local below = root.Position - Vector3.new(0, root.Size.Y / 2 + hip + 0.5, 0)
	local result = DigService.TryDig(player, below, true)
	if result and not result.Success and result.Reason == "TooHard" then
		lastDig[player] = os.clock() -- back off; the notify is already throttled
	end
end

function DigService.Init()
	Net.On("Dig", function(player: Player, position: any)
		if not Net.IsVector3(position) then
			return
		end
		DigService.TryDig(player, position :: Vector3, false)
	end, { Rate = 20, Window = 1 })

	SettingsService.RegisterValidator("AutoDig", function(player: Player, value: any): (boolean, any)
		if type(value) ~= "boolean" then
			return false, nil
		end
		if value and not MonetizationService.OwnsPass(player, "AutoDig") then
			Net.Notify(player, "Error", "Get the Auto Dig pass to dig automatically!")
			return false, nil
		end
		return true, value
	end)
end

function DigService.Start()
	task.spawn(function()
		while true do
			task.wait(AUTO_TICK)
			for _, player in DataService.GetLoadedPlayers() do
				if autoDigEnabled(player) then
					local ok, err = pcall(function(): any
						autoDigStep(player)
						return nil
					end)
					if not ok then
						warn("[DigService] auto dig error: " .. tostring(err))
					end
				end
			end
		end
	end)
end

function DigService.OnPlayerRemoving(player: Player)
	lastDig[player] = nil
	lastFailResult[player] = nil
	sessionDigs[player] = nil
end

return DigService
