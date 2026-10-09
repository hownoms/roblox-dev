--!strict
--[[
	DigService — every terrain dig goes through DigService.DigAt (docs/V2.md).

	DigAt(player, position, opts) — opts = Types.DigOptions { Power, Radius, SandMultiplier,
	Source = "Shovel" | "Digger" | "Pet" | "Ride" | "Auto", Silent? }. Validation, in order (first failure ->
	DigResult{Success=false,Reason}):
	  Cooldown     Shovel/Auto only: shovel cooldown / speed (x COOLDOWN_LENIENCY for Shovel)
	               x Config.Heat.SunburntCooldownMultiplier while the player is "Sunburnt"
	  OutOfZone    point is not inside the dig zone (World.GetDigZone), or its carve could
	               reach under a protected footprint (World.IsProtected: trophy camp pad)
	  Bottom       point is at the very bottom of the world (The Core floor is indestructible)
	  TooFar       Shovel: further than Config.REACH (+ slack) from HumanoidRootPart;
	               Digger/Pet: further than DIGGER_RANGE from the owner (Auto: never);
	               Ride: further than RIDE_RANGE from opts.Origin (the vehicle, RideService)
	  TooHard      opts.Power < Hardness of the layer at that depth
	  BackpackFull Sand >= effective capacity
	Points with no solid terrain near them are ignored silently (no result).
	The dig point is re-resolved on the server (Shovel: re-raycast from the character; others:
	3 studs below the given point) and a voxel-aligned cube is carved: edge = Radius * 2 rounded
	to whole 4-stud voxels (min 1 voxel), centred horizontally on the target and going DOWN
	from the target voxel; a dig at the surface also clears the voxel above the surface. The
	cube is clamped to the dig zone so the zone walls and the floor never break.
	Success: sand (Stats; opts.SandMultiplier replaces the shovel factor) into the backpack
	(capped at capacity), tide/anti-cheat bookkeeping (BeachService.RecordCarve), MaxDepth via
	BeachService.ReportDig, ServerSignals.Carved(player, min, max, source, layerIndex) (v3: the
	DiscoveryService uncovers buried finds from it; there is no per-dig treasure roll any more),
	ServerSignals.Dug(player, depth, gained, source) and a DigResult unless opts.Silent.

	Messages: the CLIENT shows every dig hint (too hard, backpack full, bottom...) from the
	DigResult it receives, so the server sends no Notify for dig failures (no duplicates).
	Failed Digger digs send nothing (the caller gets the result).

	AutoDig pass: SetSetting("AutoDig", true|false). While on (and the pass is owned) the server
	digs straight down below the character's feet at the shovel's normal cooldown (Source "Auto").

	Public API:
		DigService.DigAt(player, position, opts): Types.DigResult?
		DigService.ShovelOptions(player, source?): Types.DigOptions?   -- equipped shovel stats
		DigService.TryDig(player, position, isAuto)   -- v1 compatibility: DigAt with the shovel
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Stats = require(Shared.Util.Stats)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local MultiplierService = require(script.Parent.MultiplierService)
local Net = require(script.Parent.Net)
local BeachService = require(script.Parent.BeachService)
local ServerSignals = require(script.Parent.ServerSignals)
local SettingsService = require(script.Parent.SettingsService)
local World = require(script.Parent.Parent.World)

local REACH_SLACK = 2 -- studs of latency slack on top of Config.REACH
local DIGGER_RANGE = 16 -- Digger digs must be this close to the owner's character
-- v2.1: pet ("Pet") and ride-on ("Ride") digs follow the "Digger" rules (own stats, no shovel
-- cooldown, DIGGER_RANGE instead of REACH, no failure DigResult).
local COMPANION_SOURCES: { [string]: boolean } = { Digger = true, Pet = true, Ride = true }
local DIGGER_SLACK = 2
local RIDE_RANGE = 64 -- "Ride": max studs from the vehicle (opts.Origin) to the dig point
local SURFACE_SLACK = 4 -- how far above the surface a dig point may be
local BOTTOM_FLOOR = 2 -- studs of indestructible floor kept at the bottom of the world
local EDGE_SLACK = 1 -- dig points may be this far outside the footprint (surface rounding)
local AUTO_TICK = 0.05
local FAIL_RESULT_INTERVAL = 0.2 -- Shovel: min seconds between failure DigResults
local AUTO_FAIL_INTERVAL = 1.5 -- Auto: min seconds between failure DigResults

local S = Config.SURFACE_Y
local ZONE = World.GetDigZone()
local ZONE_CENTER = ZONE.CFrame.Position
local ZONE_HALF_X = ZONE.Size.X / 2
local ZONE_HALF_Z = ZONE.Size.Z / 2
local TOTAL_DEPTH = ZONE.Size.Y

local DigService = {}

local terrain = Workspace.Terrain

local lastDig: { [Player]: number } = {}
local lastFailResult: { [Player]: number } = {}

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

-- Removes a voxel-aligned cube of terrain at the dig point and returns the carved box (min, max).
-- Edge = radius * 2 rounded to whole voxels (radius 2 = one 4-stud voxel, radius 8 = 4x4x4
-- voxels). Horizontally centred on the target, going down from the target voxel. Clamped to
-- voxels fully inside the dig zone so its walls and the floor never break. A dig whose top
-- reaches the surface also clears the voxel above it (the partially filled surface voxel).
-- Hand-spade tiers (Radius <= DENT_MAX_RADIUS) carve a rounded dent instead of a whole voxel:
-- terrain voxels are 4 studs, so anything "smaller than a block" has to come from lowering
-- voxel occupancy with a ball. Playtest asked for ~2x2x2 scoops at the start.
local DENT_MAX_RADIUS = 2.2
local DENT_BALL_RADIUS = 2.6
local DENT_RISE = 1.5 -- ball centre sits this far above the resolved target (≈1.5 under the surface)

local function carveDent(target: Vector3): (Vector3, Vector3)
	local r = DENT_BALL_RADIUS
	local margin = r + 0.5
	local center = Vector3.new(
		math.clamp(target.X, ZONE_CENTER.X - ZONE_HALF_X + margin, ZONE_CENTER.X + ZONE_HALF_X - margin),
		math.max(target.Y + DENT_RISE, S - TOTAL_DEPTH + BOTTOM_FLOOR + margin),
		math.clamp(target.Z, ZONE_CENTER.Z - ZONE_HALF_Z + margin, ZONE_CENTER.Z + ZONE_HALF_Z - margin)
	)
	debug.profilebegin("DigTheBeach.Dig.FillBall")
	local ok, err = pcall(terrain.FillBall, terrain, center, r, Enum.Material.Air)
	debug.profileend()
	if not ok then
		error(err, 0)
	end
	local half = Vector3.new(r, r, r)
	local max = center + half
	return center - half, Vector3.new(max.X, math.min(max.Y, S), max.Z)
end

local function carve(target: Vector3, radius: number): (Vector3, Vector3)
	if radius <= DENT_MAX_RADIUS then
		return carveDent(target)
	end
	local cells = math.max(1, math.floor(radius * 2 / VOXEL + 0.5))
	local function axisStart(value: number, minEdge: number, maxEdge: number): number
		local lo = math.ceil(minEdge / VOXEL)
		local hi = math.floor(maxEdge / VOXEL) - cells
		local start = math.floor(value / VOXEL) - math.floor((cells - 1) / 2)
		return if hi < lo then lo else math.clamp(start, lo, hi)
	end
	local sx = axisStart(target.X, ZONE_CENTER.X - ZONE_HALF_X, ZONE_CENTER.X + ZONE_HALF_X)
	local sz = axisStart(target.Z, ZONE_CENTER.Z - ZONE_HALF_Z, ZONE_CENTER.Z + ZONE_HALF_Z)
	local floorY = S - TOTAL_DEPTH + BOTTOM_FLOOR
	local topCell = math.min(math.floor(target.Y / VOXEL), S // VOXEL - 1)
	local sy = math.max(topCell - (cells - 1), math.ceil(floorY / VOXEL))
	local size = Vector3.new(cells, cells, cells) * VOXEL
	local min = Vector3.new(sx, sy, sz) * VOXEL
	local max = min + size
	local clearTop = if max.Y >= S then S + VOXEL else max.Y
	local box = Vector3.new(size.X, clearTop - min.Y, size.Z)
	debug.profilebegin("DigTheBeach.Dig.FillBlock")
	local ok, err = pcall(terrain.FillBlock, terrain, CFrame.new(min + box / 2), box, Enum.Material.Air)
	debug.profileend()
	if not ok then
		error(err, 0)
	end
	return min, Vector3.new(max.X, math.min(max.Y, S), max.Z)
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
	debug.profilebegin("DigTheBeach.Dig.ReadVoxels")
	local ok, materials, occupancies = pcall(function()
		return terrain:ReadVoxels(region, 4)
	end)
	debug.profileend()
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

local function fail(
	player: Player,
	result: Types.DigResult,
	reason: Types.DigFailReason,
	opts: Types.DigOptions
): Types.DigResult
	result.Reason = reason
	-- No Notify here: the client turns the DigResult into one hint. Throttle failure replies so
	-- spamming the remote can't flood the client back.
	if opts.Silent or COMPANION_SOURCES[opts.Source] or (opts.Source == "Auto" and reason == "Cooldown") then
		return result
	end
	local interval = if opts.Source == "Auto" then AUTO_FAIL_INTERVAL else FAIL_RESULT_INTERVAL
	local now = os.clock()
	local last = lastFailResult[player]
	if last == nil or now - last >= interval then
		lastFailResult[player] = now
		Net.FireClient("DigResult", player, result)
	end
	return result
end

local function cooldownFor(player: Player, ctx: Stats.Context, source: string): number
	local cooldown = Stats.GetCooldown(ctx) * (if source == "Shovel" then Config.COOLDOWN_LENIENCY else 1)
	if player:GetAttribute("Sunburnt") == true then
		cooldown *= Config.Heat.SunburntCooldownMultiplier
	end
	return cooldown
end

-- Dig options from the player's equipped shovel.
function DigService.ShovelOptions(player: Player, source: Types.DigSource?): Types.DigOptions?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	assert(data) -- refine for the type checker (guarded above)
	local shovel = Stats.GetShovel(data)
	return {
		Power = shovel.Power,
		Radius = shovel.Radius,
		SandMultiplier = shovel.SandMultiplier,
		Source = source or "Shovel",
	}
end

function DigService.DigAt(player: Player, position: Vector3, opts: Types.DigOptions): Types.DigResult?
	local data = DataService.Get(player)
	local ctx = MultiplierService.GetContext(player)
	if not data or not ctx then
		return nil
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(ctx) -- refine for the type checker (guarded above)
	local source = opts.Source
	local companion = COMPANION_SOURCES[source] == true
	local result = baseResult(position)
	local now = os.clock()

	if not companion then
		local cooldown = cooldownFor(player, ctx, source)
		local last = lastDig[player]
		if last and now - last < cooldown then
			studioDebug(player, "Cooldown", string.format("cooldown %.2fs not elapsed", cooldown))
			return fail(player, result, "Cooldown", opts)
		end
	end

	-- Zone bounds (zone-local: origin = surface centre, -Y = down).
	local rel = position - ZONE_CENTER
	if
		math.abs(rel.X) > ZONE_HALF_X + EDGE_SLACK
		or math.abs(rel.Z) > ZONE_HALF_Z + EDGE_SLACK
		or rel.Y > SURFACE_SLACK
		or rel.Y < -TOTAL_DEPTH - EDGE_SLACK
	then
		return fail(player, result, "OutOfZone", opts)
	end

	local root = Net.GetRoot(player)
	if source == "Shovel" then
		if not root or (root.Position - position).Magnitude > Config.REACH + REACH_SLACK then
			return fail(player, result, "TooFar", opts)
		end
	elseif source == "Ride" then
		-- Ride: measured from the vehicle (opts.Origin, server-side; the rider sits in its cab).
		local origin = opts.Origin or (if root then root.Position else nil)
		if not root or not origin or (origin - position).Magnitude > RIDE_RANGE then
			return fail(player, result, "TooFar", opts)
		end
	elseif companion then
		if not root or (root.Position - position).Magnitude > DIGGER_RANGE + DIGGER_SLACK then
			return fail(player, result, "TooFar", opts)
		end
	end

	local target = resolveTarget(position, if source == "Shovel" then root else nil)
	local trel = target - ZONE_CENTER
	if math.abs(trel.X) > ZONE_HALF_X + EDGE_SLACK or math.abs(trel.Z) > ZONE_HALF_Z + EDGE_SLACK then
		return fail(player, result, "OutOfZone", opts)
	end
	-- Protected footprints (trophy camp pad): refuse any dig whose carve could reach under one,
	-- at any depth. Today the pad is outside the zone; this keeps it safe if either moves.
	if World.IsProtected(target, math.max(opts.Radius, DENT_BALL_RADIUS) + VOXEL) then
		return fail(player, result, "OutOfZone", opts)
	end
	local depth = math.clamp(S - target.Y, 0, TOTAL_DEPTH)
	if depth >= TOTAL_DEPTH - BOTTOM_FLOOR then
		return fail(player, result, "Bottom", opts)
	end
	local layerIndex = Config.GetLayerIndexAtDepth(depth)
	local layer = Config.Layers[layerIndex]
	result.Radius = opts.Radius
	result.Depth = depth
	result.LayerIndex = layerIndex

	if not hasSolidTerrainNear(target) then
		studioDebug(player, "NoTerrain", "no solid terrain at " .. tostring(target))
		return nil
	end

	if opts.Power < layer.Hardness then
		return fail(player, result, "TooHard", opts)
	end

	local capacity = Stats.GetCapacity(ctx)
	result.Capacity = capacity
	result.Sand = data.Sand
	if data.Sand >= capacity then
		return fail(player, result, "BackpackFull", opts)
	end

	-- Success ------------------------------------------------------------------------------------
	if not companion then
		lastDig[player] = now
	end
	local carvedMin, carvedMax = carve(target, opts.Radius)
	BeachService.RecordCarve(carvedMin, carvedMax)

	-- opts.SandMultiplier replaces the shovel's factor in the multiplier stack.
	local shovelFactor = Stats.GetShovel(data).SandMultiplier
	local sandMultiplier = Stats.GetSandMultiplier(ctx)
	if shovelFactor > 0 then
		sandMultiplier = sandMultiplier / shovelFactor * opts.SandMultiplier
	end
	local gained = math.min(layer.SandValue * sandMultiplier, capacity - data.Sand)
	DataService.Mutate(player, { "Sand", "TotalSandDug" }, function(d)
		d.Sand += gained
		d.TotalSandDug += gained
	end)
	local newRecord, newLayer = BeachService.ReportDig(player, depth)

	-- v3 discovery: finds come from buried deposits (DiscoveryService listens to Carved: uncover,
	-- ownership, excavation, plus a tiny ambient junk chance). No per-dig treasure roll here.
	-- Silent digs (pets, /stress bots) never produce finds or popups for the player.
	if not opts.Silent then
		ServerSignals.Carved:Fire(player, carvedMin, carvedMax, source, layerIndex)
	end

	result.Success = true
	result.SandGained = gained
	result.Sand = data.Sand
	result.NewMaxDepth = newRecord
	result.NewLayer = newLayer
	if not opts.Silent then
		Net.FireClient("DigResult", player, result)
	end

	ServerSignals.Dug:Fire(player, depth, gained, source)
	Analytics.Funnel(player, Analytics.Steps.FirstDig)
	if data.Sand >= capacity then
		ServerSignals.BackpackFull:Fire(player)
	end
	return result
end

-- v1 compatibility: a dig with the equipped shovel (isAuto -> Source "Auto").
function DigService.TryDig(player: Player, position: Vector3, isAuto: boolean): Types.DigResult?
	local opts = DigService.ShovelOptions(player, if isAuto then "Auto" else "Shovel")
	if not opts then
		return nil
	end
	return DigService.DigAt(player, position, opts :: Types.DigOptions)
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
	if os.clock() - (lastDig[player] or 0) < cooldownFor(player, ctx, "Auto") then
		return
	end
	if data.Sand >= Stats.GetCapacity(ctx) then
		return -- the client shows the "Backpack full" hint
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
		local opts = DigService.ShovelOptions(player, "Shovel")
		if opts then
			DigService.DigAt(player, position :: Vector3, opts :: Types.DigOptions)
		end
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
end

return DigService
