--!strict
--[[
	World — procedural beach map (owner: Beach). Everything is built in code at server start,
	deterministically (fixed Random seed). See docs/MAP.md for the layout and coordinates.

	API (docs/V2.md "Interfaces between agents"):
	  World.Build()                              -- build once (idempotent)
	  World.GetDigZone(): { CFrame, Size }       -- CFrame at the centre of the flat dig surface
	                                             -- (Y = SURFACE_Y, axis-aligned); Size = X/Z
	                                             -- footprint, Y = total depth
	  World.IsInDigZone(position): boolean       -- inside the footprint, between the bottom of
	                                             -- the world and a little above the surface
	  World.GetSurfacePoint(near): CFrame        -- safe standing pivot on the boardwalk nearest
	                                             -- to `near`, facing the sand (spawn / return)
	Extras:
	  World.GetSpawnCFrame(index?): CFrame       -- one of the boardwalk spawn pivots
	  World.ClampToDigZone(position, margin?)    -- nearest point inside the footprint
	  World.FillLayered(min, max)                -- refill a box with the layer materials (sync)
	  World.ApplyEvent(eventIds)                 -- HighTide / GoldenHour visuals (also driven by
	                                             -- the workspace attribute "ActiveEvents")
	  World.IsReady(): boolean                   -- true once the deep layers finished filling
	                                             -- (workspace attribute "WorldReady" mirrors it)
	Workspace attributes for clients: "DigZoneCFrame" (CFrame), "DigZoneSize" (Vector3).
]]

local Workspace = game:GetService("Workspace")

local Layout = require(script.Layout)
local Util = require(script.Util)
local TerrainBuilder = require(script.Terrain)
local Hub = require(script.Hub)
local Boardwalk = require(script.Boardwalk)
local Decor = require(script.Decor)
local LightingBuilder = require(script.Lighting)

export type DigZone = { CFrame: CFrame, Size: Vector3 }

local World = {}

local built = false
local ready = false
local spawnCounter = 0

local ZONE_CFRAME = CFrame.new(Layout.DIG_CENTER)
local ZONE_SIZE = Layout.DIG_SIZE
local ABOVE_SURFACE = 16 -- IsInDigZone accepts points up to this far above the surface
local STAND_HEIGHT = 3.5 -- HumanoidRootPart height above the floor it stands on

local function step(name: string, fn: () -> ())
	local err = Util.Try(fn)
	if err ~= nil then
		warn("[World] build step failed:", name, err)
	end
end

function World.Build()
	if built then
		return
	end
	built = true
	local started = os.clock()
	local rng = Random.new(Layout.SEED)
	Workspace:SetAttribute("WorldReady", false)
	Workspace:SetAttribute("DigZoneCFrame", ZONE_CFRAME)
	Workspace:SetAttribute("DigZoneSize", ZONE_SIZE)

	local map = Util.Folder("Map", Workspace)
	local hubFolder = Util.Folder("Hub", map)
	local boardwalkFolder = Util.Folder("Boardwalk", map)
	local decorFolder = Util.Folder("Decor", map)
	local fxFolder = Util.Folder("Effects", map)

	-- Terrain first so nothing spawns over the void: surface slab, then the layered strip tops.
	step("terrain colours", TerrainBuilder.ApplyColors)
	step("surface", function()
		TerrainBuilder.BuildSurface(rng)
	end)
	step("strip tops", TerrainBuilder.BuildStripTops)
	-- Core floor under the whole dig zone: nothing can fall out of the bottom of a hole.
	Util.Part({
		Name = "CoreFloor",
		Size = Vector3.new(Layout.STRIP_HALF_X * 2, 4, Layout.STRIP_Z_INLAND - Layout.STRIP_Z_SEA),
		CFrame = CFrame.new(0, Layout.BOTTOM_Y - 2, (Layout.STRIP_Z_INLAND + Layout.STRIP_Z_SEA) / 2),
		Color = Color3.fromRGB(255, 200, 60),
		Material = Enum.Material.Neon,
		CastShadow = false,
		Parent = map,
	})

	step("hub", function()
		Hub.Build(hubFolder)
	end)
	step("boardwalk", function()
		Boardwalk.Build(boardwalkFolder)
	end)
	step("decor", function()
		Decor.Build(decorFolder, rng)
	end)
	step("lighting", function()
		LightingBuilder.Build(fxFolder)
	end)

	-- Deep layers fill in the background (~100 frames) so Build returns quickly.
	task.spawn(function()
		local err = Util.Try(TerrainBuilder.BuildStripsDeep)
		if err ~= nil then
			warn("[World] deep terrain fill failed:", err)
		end
		ready = true
		Workspace:SetAttribute("WorldReady", true)
		print(string.format("[World] map ready in %.2fs", os.clock() - started))
	end)
end

function World.GetDigZone(): DigZone
	return { CFrame = ZONE_CFRAME, Size = ZONE_SIZE }
end

function World.IsInDigZone(position: Vector3): boolean
	local rel = position - Layout.DIG_CENTER
	return math.abs(rel.X) <= ZONE_SIZE.X / 2
		and math.abs(rel.Z) <= ZONE_SIZE.Z / 2
		and rel.Y <= ABOVE_SURFACE
		and rel.Y >= -ZONE_SIZE.Y
end

-- Nearest point inside the footprint (shrunk by `margin` studs), same Y.
function World.ClampToDigZone(position: Vector3, margin: number?): Vector3
	local m = margin or 0
	local c = Layout.DIG_CENTER
	local hx = math.max(0, ZONE_SIZE.X / 2 - m)
	local hz = math.max(0, ZONE_SIZE.Z / 2 - m)
	return Vector3.new(
		math.clamp(position.X, c.X - hx, c.X + hx),
		position.Y,
		math.clamp(position.Z, c.Z - hz, c.Z + hz)
	)
end

-- A pivot standing on the boardwalk deck (never dug, never refilled) as close to `near` as
-- possible, looking out over the sand.
function World.GetSurfacePoint(near: Vector3): CFrame
	local limit = Layout.BOUND_HALF_X - 10
	local x = math.clamp(near.X, -limit, limit)
	local z = (Layout.BOARDWALK_Z0 + Layout.BOARDWALK_Z1) / 2
	local pos = Vector3.new(x, Layout.DECK_TOP + STAND_HEIGHT, z)
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
end

-- Boardwalk spawn pivots (round-robin when no index is given).
function World.GetSpawnCFrame(index: number?): CFrame
	local i = index
	if i == nil then
		spawnCounter += 1
		i = spawnCounter
	end
	local spawns = Layout.SPAWNS
	local p = spawns[((i :: number) - 1) % #spawns + 1]
	local pos = p + Vector3.new(0, 1 + STAND_HEIGHT, 0) -- SpawnLocation pad is 1 stud thick
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
end

function World.FillLayered(minV: Vector3, maxV: Vector3)
	TerrainBuilder.FillLayered(minV, maxV)
end

function World.ApplyEvent(eventIds: { string })
	LightingBuilder.ApplyEvent(eventIds)
end

function World.IsReady(): boolean
	return ready
end

return World
