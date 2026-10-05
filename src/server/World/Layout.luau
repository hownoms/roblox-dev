--!strict
--[[
	Layout — every map coordinate in one place (see docs/MAP.md for the top-down drawing).

	Axes: +X = east, -X = west, +Z = inland (boardwalk / dunes), -Z = ocean.
	The hub plaza sits at the origin on the surface (Y = Config.SURFACE_Y). A central path runs
	east-west along Z = 0; plots line both sides of it, 3 west + 3 east of the hub per row.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local S = Config.SURFACE_Y
local FOOT = Config.PLOT_FOOTPRINT
local SPACING = Config.PLOT_SPACING

local Layout = {}

Layout.SURFACE_Y = S
Layout.BOTTOM_Y = S - Config.TOTAL_DEPTH -- 24 (never below 0)
Layout.WATER_Y = S - 4 -- terrain water surface
Layout.SEABED_Y = S - 20
Layout.SEED = 20261005

-- Hub plaza (between the inner plots of both rows)
Layout.HUB_HALF_X = 50
Layout.HUB_HALF_Z = 42

-- Plot rows: near edge |z| = ROW_NEAR, centre |z| = ROW_NEAR + FOOT/2
Layout.ROW_NEAR = 14
Layout.ROW_CENTER = Layout.ROW_NEAR + FOOT / 2 -- 28
Layout.ROW_FAR = Layout.ROW_NEAR + FOOT -- 42
Layout.PLOTS_PER_SIDE = 3 -- per row per side of the hub (2 rows x 2 sides x 3 = 12)
Layout.PLOT_PITCH = FOOT + SPACING

-- Underground layered blocks (one strip per row; walls between plots are layered too)
Layout.STRIP_HALF_X = Layout.HUB_HALF_X + Layout.PLOTS_PER_SIDE * Layout.PLOT_PITCH - SPACING + 8 -- 162
Layout.STRIP_INNER_Z = 6
Layout.STRIP_OUTER_Z = Layout.ROW_FAR + 8 -- 50

-- Beach / ocean (south, -Z)
Layout.BEACH_FLAT_END_Z = -64 -- sand stays at surface height until here
Layout.BEACH_SLOPE_END_Z = -120 -- then slopes down to the seabed
Layout.OCEAN_FAR_Z = -420
Layout.TERRAIN_HALF_X = 320

-- Boardwalk (north, +Z)
Layout.BOARDWALK_Z0 = 46
Layout.BOARDWALK_Z1 = 62
Layout.DUNES_Z0 = 84
Layout.TERRAIN_NORTH_Z = 130

-- Pier (south from the hub)
Layout.PIER_HALF_W = 6
Layout.PIER_Z0 = -42
Layout.PIER_Z1 = -170
Layout.PIER_END_HALF = 14 -- end platform half-size (x), spans z PIER_Z1 .. PIER_Z1 - 24
Layout.PIER_END_DEPTH = 24

-- Invisible boundary
Layout.BOUND_HALF_X = 180
Layout.BOUND_NORTH_Z = 100
Layout.BOUND_SOUTH_Z = -200

-- Hub stations (surface positions)
Layout.SPAWNS = {
	Vector3.new(0, S, 4),
	Vector3.new(-9, S, -3),
	Vector3.new(9, S, -3),
}
Layout.SELL = Vector3.new(0, S, -32)
Layout.SHOVEL_SHOP = Vector3.new(-32, S, 29)
Layout.BACKPACK_SHOP = Vector3.new(32, S, 29)
Layout.LEADERBOARD_COINS = Vector3.new(-12, S, 38)
Layout.LEADERBOARD_DEPTH = Vector3.new(12, S, 38)
Layout.REBIRTH = Vector3.new(31, S, -29)
Layout.EGG_ARC_CENTER = Vector3.new(-30, S, -48)
Layout.EGG_ARC_RADIUS = 19
Layout.EGG_ARC_DEGREES = 110
Layout.TITLE_SIGN = Vector3.new(0, S, 76)
Layout.HUB_LOOK_TARGET = Vector3.new(0, S, 0)

-- Plot ids are ordered nearest-to-hub first so "first free plot" assignment keeps players close.
-- id = (ring - 1) * 4 + slot; slot 1 = north-west, 2 = north-east, 3 = south-west, 4 = south-east.
function Layout.PlotCenter(id: number): Vector3
	local ring = (id - 1) // 4 + 1
	local slot = (id - 1) % 4 + 1
	local xSign = if slot == 1 or slot == 3 then -1 else 1
	local zSign = if slot <= 2 then 1 else -1
	local x = xSign * (Layout.HUB_HALF_X + FOOT / 2 + (ring - 1) * Layout.PLOT_PITCH)
	local z = zSign * Layout.ROW_CENTER
	return Vector3.new(x, S, z)
end

-- Unit vector from the plot centre towards the central path (the plot's "front").
function Layout.PlotFront(id: number): Vector3
	local c = Layout.PlotCenter(id)
	return Vector3.new(0, 0, if c.Z > 0 then -1 else 1)
end

-- Terrain surface height at `z` on the beach side (flat, then linear slope to the seabed).
function Layout.GroundY(z: number): number
	if z >= Layout.BEACH_FLAT_END_Z then
		return S
	end
	local seabedTop = Layout.SEABED_Y + 4
	local t = math.clamp((Layout.BEACH_FLAT_END_Z - z) / (Layout.BEACH_FLAT_END_Z - Layout.BEACH_SLOPE_END_Z), 0, 1)
	return S + (seabedTop - S) * t
end

-- Snap a Y value to the 4-stud terrain voxel grid.
function Layout.SnapY(y: number): number
	return math.floor(y / 4 + 0.5) * 4
end

return Layout
