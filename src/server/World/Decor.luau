--!strict
--[[
	Decor — Models.Prop scenery: palms, umbrellas + towels, lifeguard towers, sandcastles, crabs,
	surfboards, beach balls, rocks, shells, boardwalk stalls and chests. Deterministic (seeded
	Random passed in by World). Small props are non-colliding & shadowless (Util.Prop).

	Nothing is placed inside the dig zone (props would float over holes): beach props stand on
	the wet sand between the dig zone and the shoreline, the rest around the hub and dunes.
]]

local Layout = require(script.Parent.Layout)
local Util = require(script.Parent.Util)

local S = Layout.SURFACE_Y

local Decor = {}

-- Random point on the wet sand strip seaward of the dig zone, avoiding the pier corridor.
local function beachPoint(rng: Random, zMin: number, zMax: number): Vector3
	local x
	repeat
		x = rng:NextNumber(-Layout.BOUND_HALF_X + 6, Layout.BOUND_HALF_X - 6)
	until math.abs(x) > Layout.PIER_HALF_W + 6
	local z = rng:NextNumber(zMin, zMax)
	return Vector3.new(x, Layout.GroundY(z), z)
end

function Decor.Build(parent: Instance, rng: Random)
	local prop = function(name: string, pos: Vector3, yaw: number, scale: number?)
		Util.Prop(name, parent, pos, yaw, scale)
	end
	local wetZ0, wetZ1 = Layout.BEACH_FLAT_END_Z + 2, Layout.DIG_Z_SEA - 4 -- -78 .. -68
	local hub = Layout.HUB_CENTER
	local B = Layout.BOUND_HALF_X

	-- Palms: a row behind the hub (dunes edge), along the boardwalk's inland edge away from the
	-- hub, framing the title sign and at the beach ends.
	local px = -B + 10
	while px < B do
		if math.abs(px) > 30 then
			prop(
				"PalmTree",
				Vector3.new(px + rng:NextNumber(-4, 4), S, 108 + rng:NextNumber(-3, 5)),
				rng:NextNumber(0, 360)
			)
		end
		if math.abs(px) > 110 then
			prop(
				"PalmTree",
				Vector3.new(px + rng:NextNumber(-5, 5), S, Layout.BOARDWALK_Z1 + 8 + rng:NextNumber(0, 6)),
				rng:NextNumber(0, 360)
			)
		end
		px += 34
	end
	for _, p in
		{
			Vector3.new(-28, S, 112),
			Vector3.new(28, S, 112),
			Vector3.new(-B + 8, S, -74),
			Vector3.new(B - 8, S, -76),
			Vector3.new(-16, S, -72),
			Vector3.new(16, S, -72),
			Vector3.new(-32, S, 62),
			Vector3.new(32, S, 60),
		}
	do
		prop("PalmTree", p, rng:NextNumber(0, 360))
	end
	-- Scenic palms outside the boundary (dunes / far beach)
	for _ = 1, 16 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x = side * rng:NextNumber(B + 10, Layout.TERRAIN_HALF_X - 30)
		prop("PalmTree", Vector3.new(x, S, rng:NextNumber(10, 100)), rng:NextNumber(0, 360), rng:NextNumber(0.9, 1.3))
	end

	-- Umbrella + towel pairs on the wet sand, facing the sea
	local ux = -B + 30
	local i = 0
	while ux < B - 20 do
		if math.abs(ux) > 30 then
			i += 1
			local u = Vector3.new(ux + rng:NextNumber(-6, 6), S, if i % 2 == 0 then -71 else -75)
			prop("Umbrella", u, rng:NextNumber(0, 360))
			prop("BeachTowel", u + Vector3.new(3.5, 0, -2), rng:NextNumber(-15, 15))
		end
		ux += 46
	end

	-- Lifeguard towers looking out to sea, surfboards leaning nearby
	for _, x in { -260, -110, 120, 270 } do
		local p = Vector3.new(x, S, -76)
		prop("Lifeguard Tower", p, 0) -- -Z = looking out to sea
		prop("Surfboard", p + Vector3.new(7, 0, 2), rng:NextNumber(0, 360))
		prop("Surfboard", p + Vector3.new(9, 0, 3), rng:NextNumber(0, 360))
	end

	-- Sandcastles on the wet sand
	for _, x in { -330, -190, -48, 52, 180, 320 } do
		local p = Vector3.new(x, S, -70)
		prop("Sandcastle", p, Util.YawTowards(p, hub))
	end

	-- Crabs, beach balls and shells scattered over the wet sand / shallows
	for _ = 1, 16 do
		prop("Crab", beachPoint(rng, wetZ0 - 8, wetZ1), rng:NextNumber(0, 360))
	end
	for _ = 1, 8 do
		prop("BeachBall", beachPoint(rng, wetZ0, wetZ1), rng:NextNumber(0, 360))
	end
	for _ = 1, 28 do
		prop("Shell", beachPoint(rng, wetZ0 - 10, wetZ1), rng:NextNumber(0, 360))
	end

	-- Rocks along the shoreline (half in the water) and at the boundary corners
	for _ = 1, 22 do
		local p = beachPoint(rng, -98, -88)
		prop("Rock", p + Vector3.new(0, -1.5, 0), rng:NextNumber(0, 360), rng:NextNumber(0.8, 1.6))
	end
	for _, p in
		{
			Vector3.new(-B + 4, S, 120),
			Vector3.new(B - 4, S, 120),
			Vector3.new(-B + 4, S, -78),
			Vector3.new(B - 4, S, -78),
		}
	do
		prop("Rock", p, rng:NextNumber(0, 360), 1.8)
	end

	-- Boardwalk stalls (on the deck, away from the hub, facing the sand)
	local deckZ = (Layout.BOARDWALK_Z0 + Layout.BOARDWALK_Z1) / 2 + 3
	for _, x in { -130, -250, -350, 130, 250, 350 } do
		prop("Boardwalk Stall", Vector3.new(x, Layout.DECK_TOP, deckZ), 0)
	end

	-- Chests: next to the rebirth shrine and on the pier end platform
	prop("Chest", Layout.REBIRTH + Vector3.new(9, 0, -4), Util.YawTowards(Layout.REBIRTH, hub))
	prop("Chest", Vector3.new(-9, S + 1, Layout.PIER_Z1 - Layout.PIER_END_DEPTH + 4), 0)
end

return Decor
