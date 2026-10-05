--!strict
--[[
	Decor — Models.Prop scenery: palms, umbrellas + towels, lifeguard towers, sandcastles, crabs,
	surfboards, beach balls, rocks, shells, boardwalk stalls and chests. Deterministic (seeded
	Random passed in by World). Small props are non-colliding & shadowless (Util.Prop).
]]

local Layout = require(script.Parent.Layout)
local Util = require(script.Parent.Util)

local S = Layout.SURFACE_Y

local Decor = {}

-- Random beach point on the flat sand strip between the south plot row and the shoreline,
-- avoiding the pier corridor.
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
	local beachZ0, beachZ1 = Layout.BEACH_FLAT_END_Z + 2, -Layout.ROW_FAR - 5 -- -62 .. -47
	local hub = Layout.HUB_LOOK_TARGET

	-- Palms: along the dunes behind the boardwalk, framing the title sign, at the beach ends
	local px = -Layout.BOUND_HALF_X + 10
	while px < Layout.BOUND_HALF_X do
		if math.abs(px) > 30 then
			prop(
				"PalmTree",
				Vector3.new(px + rng:NextNumber(-4, 4), S, 72 + rng:NextNumber(-3, 5)),
				rng:NextNumber(0, 360)
			)
		end
		px += 30
	end
	for _, p in
		{
			Vector3.new(-26, S, 74),
			Vector3.new(26, S, 74),
			Vector3.new(-170, S, -50),
			Vector3.new(170, S, -52),
			Vector3.new(-170, S, 6),
			Vector3.new(170, S, -4),
			Vector3.new(-14, S, -46),
			Vector3.new(14, S, -46),
		}
	do
		prop("PalmTree", p, rng:NextNumber(0, 360))
	end
	-- Scenic palms outside the boundary (dunes / far beach)
	for _ = 1, 14 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x = side * rng:NextNumber(Layout.BOUND_HALF_X + 10, Layout.TERRAIN_HALF_X - 30)
		prop("PalmTree", Vector3.new(x, S, rng:NextNumber(-55, 70)), rng:NextNumber(0, 360), rng:NextNumber(0.9, 1.3))
	end

	-- Umbrella + towel pairs on the beach strip, facing the sea
	for i, x in { -30, -62, -96, -128, -158, 34, 66, 98, 130, 160 } do
		local z = if i % 2 == 0 then -52 else -58
		local u = Vector3.new(x, S, z)
		prop("Umbrella", u, rng:NextNumber(0, 360))
		prop("BeachTowel", u + Vector3.new(3.5, 0, -2), rng:NextNumber(-15, 15))
	end

	-- Lifeguard towers looking out to sea, surfboards leaning nearby
	for _, p in { Vector3.new(-80, S, -66), Vector3.new(112, S, -66) } do
		prop("Lifeguard Tower", p, 0) -- -Z = looking out to sea
		prop("Surfboard", p + Vector3.new(7, 0, 2), rng:NextNumber(0, 360))
		prop("Surfboard", p + Vector3.new(9, 0, 3), rng:NextNumber(0, 360))
	end
	prop("Surfboard", Vector3.new(44, S, -50), 200)

	-- Sandcastles
	for _, p in
		{ Vector3.new(44, S, -60), Vector3.new(-118, S, -54), Vector3.new(150, S, -60), Vector3.new(-44, S, -58) }
	do
		prop("Sandcastle", p, Util.YawTowards(p, hub))
	end

	-- Crabs, beach balls and shells scattered over the beach
	for _ = 1, 9 do
		local p = beachPoint(rng, beachZ0 - 8, beachZ1)
		prop("Crab", p, rng:NextNumber(0, 360))
	end
	for _ = 1, 5 do
		prop("BeachBall", beachPoint(rng, beachZ0, beachZ1), rng:NextNumber(0, 360))
	end
	for _ = 1, 16 do
		prop("Shell", beachPoint(rng, beachZ0 - 10, beachZ1), rng:NextNumber(0, 360))
	end
	-- Shells / crabs in the gaps between plots (path side), a little life near the dig spots
	for ring = 1, Layout.PLOTS_PER_SIDE - 1 do
		local gx = Layout.HUB_HALF_X + ring * Layout.PLOT_PITCH - Layout.PLOT_PITCH / 2 + 14
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local name = if rng:NextNumber() < 0.5 then "Shell" else "Crab"
				prop(name, Vector3.new(sx * gx, S, sz * rng:NextNumber(20, 38)), rng:NextNumber(0, 360))
			end
		end
	end

	-- Rocks along the shoreline (half in the water) and at the boundary corners
	for _ = 1, 12 do
		local p = beachPoint(rng, -82, -72)
		prop("Rock", p + Vector3.new(0, -1.5, 0), rng:NextNumber(0, 360), rng:NextNumber(0.8, 1.6))
	end
	for _, p in
		{
			Vector3.new(-176, S, 90),
			Vector3.new(176, S, 90),
			Vector3.new(-176, S, -60),
			Vector3.new(176, S, -60),
		}
	do
		prop("Rock", p, rng:NextNumber(0, 360), 1.8)
	end

	-- Boardwalk stalls (on the deck, facing the plots)
	local deckZ = (Layout.BOARDWALK_Z0 + Layout.BOARDWALK_Z1) / 2 + 2
	for _, x in { -64, -112, -156, 64, 112, 156 } do
		prop("Boardwalk Stall", Vector3.new(x, S + 1, deckZ), 0)
	end

	-- Chests: next to the rebirth shrine and on the pier end platform
	prop("Chest", Layout.REBIRTH + Vector3.new(9, 0, -4), Util.YawTowards(Layout.REBIRTH, hub))
	prop("Chest", Vector3.new(-9, S + 1, Layout.PIER_Z1 - Layout.PIER_END_DEPTH + 4), 0)
end

return Decor
