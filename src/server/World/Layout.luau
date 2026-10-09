--!strict
--[[
	Layout — every map coordinate in one place (see docs/MAP.md for the top-down drawing).

	Axes: +X = east, -X = west, +Z = inland (boardwalk / hub / dunes), -Z = ocean.
	One long shared DIG ZONE runs along the shoreline on the water side. Inland of it sits the
	boardwalk (spawns), then the hub plaza with every station, then the dunes. The pier leaves
	from the wet sand beyond the dig zone out into the sea.

	All dig-zone edges sit on the 8-stud tide-cell grid (and therefore the 4-stud voxel grid).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local S = Config.SURFACE_Y

local Layout = {}

Layout.SURFACE_Y = S
Layout.BOTTOM_Y = S - Config.TOTAL_DEPTH -- 24 (never below 0)
Layout.WATER_Y = S - 4 -- terrain water surface
Layout.SEABED_Y = S - 20
Layout.SEED = 20261005

-- Dig zone (the diggable sand strip). X/Z footprint, surface at S, bottom at BOTTOM_Y.
Layout.DIG_HALF_X = 384 -- 768 studs of diggable coastline
Layout.DIG_Z_INLAND = -8 -- inland edge (towards the boardwalk)
Layout.DIG_Z_SEA = -64 -- seaward edge
Layout.DIG_CENTER = Vector3.new(0, S, (Layout.DIG_Z_INLAND + Layout.DIG_Z_SEA) / 2) -- z -36
Layout.DIG_SIZE = Vector3.new(Layout.DIG_HALF_X * 2, Config.TOTAL_DEPTH, Layout.DIG_Z_INLAND - Layout.DIG_Z_SEA)

-- Underground layered block = dig zone + solid layered walls around it (never diggable).
Layout.WALL = 8
Layout.STRIP_HALF_X = Layout.DIG_HALF_X + Layout.WALL -- 392
Layout.STRIP_Z_INLAND = Layout.DIG_Z_INLAND + Layout.WALL -- 0
Layout.STRIP_Z_SEA = Layout.DIG_Z_SEA - Layout.WALL -- -72

-- Beach / ocean (south, -Z)
Layout.BEACH_FLAT_END_Z = -80 -- wet sand stays at surface height until here
Layout.BEACH_SLOPE_END_Z = -136 -- then slopes down to the seabed
Layout.OCEAN_FAR_Z = -460
Layout.TERRAIN_HALF_X = 520

-- Boardwalk (inland edge of the dig zone; spawns stand on it)
Layout.BOARDWALK_Z0 = -4 -- seaward edge
Layout.BOARDWALK_Z1 = 12 -- inland edge
-- Smooth terrain's visible surface sits ~2 studs above the 4-stud voxel grid that S is on
-- (CHANGELOG: v1/v2 playtests and the v2.2 playtest). Decks and stations are lifted by it.
Layout.VISIBLE_SURFACE_OFFSET = 2
-- Deck top 1 stud above the VISIBLE sand. v2.2 playtest: at S + 1 the deck, the spawn pads and
-- their rims were half under the sand.
Layout.DECK_TOP = S + Layout.VISIBLE_SURFACE_OFFSET + 1

-- Hub (north of the boardwalk)
Layout.HUB_CENTER = Vector3.new(0, S, 50)
Layout.HUB_RADIUS = 30
Layout.DUNES_Z0 = 120
Layout.TERRAIN_NORTH_Z = 170

-- Kept for Lighting.luau (High Tide sheet starts at z = -ROW_FAR - 3 = the dig zone's inland edge).
Layout.ROW_FAR = -Layout.DIG_Z_INLAND - 3 -- 5

-- Pier (from the wet sand beyond the dig zone out to sea)
Layout.PIER_HALF_W = 6
Layout.PIER_Z0 = Layout.DIG_Z_SEA - 4 -- -68
Layout.PIER_Z1 = -200
Layout.PIER_END_HALF = 14 -- end platform half-size (x), spans z PIER_Z1 .. PIER_Z1 - 24
Layout.PIER_END_DEPTH = 24

-- Invisible boundary
Layout.BOUND_HALF_X = 400
Layout.BOUND_NORTH_Z = 130
Layout.BOUND_SOUTH_Z = -232

-- Hub stations (surface positions). Spawns stand on the boardwalk deck, facing the sand.
Layout.SPAWNS = {
	Vector3.new(0, Layout.DECK_TOP, 4),
	Vector3.new(-14, Layout.DECK_TOP, 4),
	Vector3.new(14, Layout.DECK_TOP, 4),
}
Layout.HUB_LOOK_TARGET = Vector3.new(0, S, 4) -- hub stations face the boardwalk spawns
Layout.SELL = Vector3.new(0, S, 28)
Layout.FOUNTAIN = Vector3.new(0, S, 54)
Layout.SHOVEL_SHOP = Vector3.new(-36, S, 34)
Layout.BACKPACK_SHOP = Vector3.new(36, S, 34)
Layout.GARAGE = Vector3.new(-78, S, 44)
Layout.BEACH_SHOP = Vector3.new(76, S, 40)
Layout.LEADERBOARD_COINS = Vector3.new(-14, S, 92)
Layout.LEADERBOARD_DEPTH = Vector3.new(14, S, 92)
Layout.REBIRTH = Vector3.new(44, S, 72)
Layout.EGG_ARC_CENTER = Vector3.new(-50, S, 92)
Layout.EGG_ARC_RADIUS = 19
Layout.EGG_ARC_DEGREES = 110
Layout.TITLE_SIGN = Vector3.new(0, S, 118)

-- Trophy camp pad (bible ch.02 "Camps and trophies"; TrophyCampDisplay borrows it). One
-- 24x24 display deck on open sand between the Rebirth shrine and the Beach Shop: >= 10 studs
-- from every hub part (stations, paths, lamps), far from the spawns, the deck path and the dig
-- zone. Centre is ground level; the deck top is DECK_TOP. The footprint plus its rim is
-- protected from digging (World.IsProtected).
Layout.CAMP_PAD_SIZE = 24
Layout.CAMP_PAD_RIM = 1 -- border strip outside the 24x24 footprint
Layout.CAMP_PADS = { Vector3.new(80, S, 76) }

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
