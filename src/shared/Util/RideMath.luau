--!strict
--[[
	RideMath — ride-on vehicle geometry shared by RideService (server) and RideController
	(client) so both agree on the allowed area and the ground height (Config.Ride).

	- Bounds(zoneCFrame, zoneSize): the rectangle the vehicle PIVOT may occupy: the dig zone
	  (minus EdgeMargin) plus the boardwalk up to InlandMaxZ.
	- Clamp(position, bounds): position clamped into the rectangle (Y unchanged).
	- Inside(position, bounds, slack): horizontal containment test.
	- GroundY(pivot): height for the pivot (bottom of the tracks) at `pivot`: the highest of the
	  track samples, where each sample is the boardwalk deck top (z >= DeckSeaEdgeZ) or the terrain
	  surface from a raycast, floored at SURFACE_Y so the vehicle rides OVER dug holes at surface
	  level instead of falling in.
]]

local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)

local RideMath = {}

export type Bounds = { MinX: number, MaxX: number, MinZ: number, MaxZ: number }

local R = Config.Ride
local S = Config.SURFACE_Y

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { Workspace.Terrain }
terrainOnly.IgnoreWater = true

function RideMath.Bounds(zoneCFrame: CFrame, zoneSize: Vector3): Bounds
	local c = zoneCFrame.Position
	return {
		MinX = c.X - zoneSize.X / 2 + R.EdgeMargin,
		MaxX = c.X + zoneSize.X / 2 - R.EdgeMargin,
		MinZ = c.Z - zoneSize.Z / 2 + R.EdgeMargin,
		MaxZ = R.InlandMaxZ,
	}
end

function RideMath.Clamp(position: Vector3, b: Bounds): Vector3
	return Vector3.new(math.clamp(position.X, b.MinX, b.MaxX), position.Y, math.clamp(position.Z, b.MinZ, b.MaxZ))
end

function RideMath.Inside(position: Vector3, b: Bounds, slack: number?): boolean
	local s = slack or 0
	return position.X >= b.MinX - s
		and position.X <= b.MaxX + s
		and position.Z >= b.MinZ - s
		and position.Z <= b.MaxZ + s
end

-- Ground height at one world (x, z) point.
function RideMath.GroundAt(x: number, z: number): number
	if z >= R.DeckSeaEdgeZ then
		return S + R.DeckTop
	end
	local hit = Workspace:Raycast(Vector3.new(x, S + 12, z), Vector3.new(0, -24, 0), terrainOnly)
	if hit then
		return math.max(hit.Position.Y, S)
	end
	return S
end

-- Pivot height for a vehicle whose pivot is at `pivot` (only position + yaw are used).
function RideMath.GroundY(pivot: CFrame): number
	local best = -math.huge
	for _, sample in R.TrackSamples do
		local p = pivot * Vector3.new(sample.X, 0, sample.Y)
		best = math.max(best, RideMath.GroundAt(p.X, p.Z))
	end
	return best + R.HoverHeight
end

return RideMath
