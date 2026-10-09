--!strict
--[[
	Decor — the beach dressing (map overhaul stream D, docs/MAP_ART_DIRECTION.md). Instead of
	evenly spaced rows of identical props, the coast and the inland sand are composed as named
	SCENES: deliberate clusters (odd groupings, 1 big + 2 small) with open sand between them.

	Coast (wet sand z -73..-96, shallows to -125), west to east:
	  Tide Pool Point, Kite Field, Lifeguard + Rowboat Landing (jetty), Picnic & Castles,
	  Umbrella Village West (swim zone buoys), [pier], Umbrella Village East (moored boats),
	  Surf School, Snorkel Cove, Bonfire Cove.
	Inland sand (|x| 122..395, z 14..128), west: boardwalk-edge palm groves, Sandcastle Contest,
	  Picnic Lawn, Volleyball Court, Palm Oasis + hammock, Cabana Row West, dune fences/grass.
	  East: boardwalk-edge groves, Beach Games, Sun Deck, Palm Grove + hammock, Cabana Row East.
	Boardwalk stalls (test-pinned names / height) at deck x +-130, +-250, +-350.

	Rules: nothing in or above the dig zone and its walls (x +-392, z -72..0), nothing in the
	pier corridor |x| <= 12, props stay inside the invisible boundary. Placement jitter comes
	from this module's own seeded Random (the shared World rng is not consumed here).
	Small clutter is non-colliding (Util small props); huts, towers, shacks and trunks collide.
]]

local Layout = require(script.Parent.Layout)
local Util = require(script.Parent.Util)
local Vistas = require(script.Parent.Vistas)

local S = Layout.SURFACE_Y
local WATER_Y = Layout.WATER_Y
local FLAT_END = Layout.BEACH_FLAT_END_Z
-- beach slope angle (flat sand at S until z -80, seabed top by z -136)
local SLOPE = math.atan((S - (Layout.SEABED_Y + 4)) / (Layout.BEACH_FLAT_END_Z - Layout.BEACH_SLOPE_END_Z))
local COAST_MAX_Z = Layout.STRIP_Z_SEA - 1 -- -73: seaward of the dig zone's walls

local Decor = {}

function Decor.Build(parent: Instance, _rng: Random)
	-- Stream A's skyline (outside the boundary) is built from here.
	Vistas.Build(parent)

	local R = Random.new(20261008)
	local function j(a: number): number
		return R:NextNumber(-a, a)
	end
	local function yawTo(x: number, z: number, dx: number, dz: number): number
		-- yaw that aims a prop's -Z (palm lean, tower view) along (dx, dz)
		return Util.YawTowards(Vector3.new(x, 0, z), Vector3.new(x + dx, 0, z + dz))
	end

	-- Upright on the visible ground (handles the beach slope via GroundY).
	local function put(name: string, x: number, z: number, yaw: number, variant: number?, scale: number?): Model?
		return Util.Prop(name, parent, Vector3.new(x, Layout.GroundY(z), z), yaw, scale, nil, variant)
	end
	-- Visible sand height and slope tilt at z (tilt eases in over the first 3 studs of slope).
	local function sandY(x: number, z: number): number
		return Util.TerrainY(Vector3.new(x, Layout.GroundY(z), z))
	end
	local function tiltAt(z: number): CFrame
		local t = math.clamp((FLAT_END - z) / 3, 0, 1)
		return CFrame.Angles(-SLOPE * t, 0, 0)
	end
	-- Lying on the sand, tilted to the slope (towels, boats, loungers, pools).
	local function lay(name: string, x: number, z: number, yaw: number, variant: number?, sink: number?): Model?
		local cf = CFrame.new(x, sandY(x, z) - (sink or 0), z) * tiltAt(z) * CFrame.Angles(0, math.rad(yaw), 0)
		return Util.PropAt(name, parent, cf, nil, variant)
	end
	-- Upright with its pivot at an explicit height relative to the sand (sunk / stilted).
	local function stand(
		name: string,
		x: number,
		z: number,
		yaw: number,
		dy: number,
		variant: number?,
		scale: number?
	): Model?
		local cf = CFrame.new(x, sandY(x, z) + dy, z) * CFrame.Angles(0, math.rad(yaw), 0)
		return Util.PropAt(name, parent, cf, scale, variant)
	end
	-- Floating on the sea with a gentle bob (contract: AmbientBob).
	local function float(
		name: string,
		x: number,
		z: number,
		yaw: number,
		variant: number,
		sinkBy: number,
		bob: number
	): Model?
		local m = Util.PropAt(
			name,
			parent,
			CFrame.new(x, WATER_Y - sinkBy, z) * CFrame.Angles(0, math.rad(yaw), 0),
			nil,
			variant
		)
		if m then
			m:SetAttribute("BobHeight", bob)
			m:SetAttribute("BobPeriod", 3 + R:NextNumber(0, 2))
			m:SetAttribute("BobRoll", 3 + R:NextNumber(0, 4))
			Util.Tag(m, "AmbientBob")
		end
		return m
	end
	local function rock(x: number, z: number, scale: number, variant: number)
		stand("Rock", x, z, R:NextNumber(0, 360), -0.5 * scale, variant, scale)
	end
	-- Palm whose crown leans along (dx, dz).
	local function palm(x: number, z: number, variant: number, dx: number, dz: number, background: boolean?)
		put(if background then "BackgroundPalm" else "PalmTree", x, z, yawTo(x, z, dx, dz) + j(12), variant)
	end
	-- 3-5 palms around a centre with a clearing, leaning outwards (one tall, others mixed).
	local function grove(cx: number, cz: number, n: number, radius: number, v0: number)
		local a0 = R:NextNumber(0, math.pi * 2)
		for i = 0, n - 1 do
			local a = a0 + i / n * math.pi * 2 + j(0.4)
			local r = radius * R:NextNumber(0.6, 1.1)
			local dx, dz = math.cos(a), math.sin(a)
			palm(cx + dx * r, cz + dz * r, v0 + i, dx, dz)
		end
	end
	-- Umbrella with loungers / towels / a cooler underneath. Coast sets face the sea.
	local setCount = 0
	local function beachSet(x: number, z: number, facing: number)
		setCount += 1
		local v = setCount
		put("Umbrella", x, z, R:NextNumber(0, 360), v)
		local roll = R:NextInteger(1, 4)
		local side = if R:NextNumber() < 0.5 then -1 else 1
		local c, s = math.cos(math.rad(facing)), math.sin(math.rad(facing))
		local function off(lx: number, lz: number): (number, number)
			-- local (lx, lz) around the umbrella, rotated by `facing`
			return x + lx * c + lz * s, z - lx * s + lz * c
		end
		if roll == 1 then
			for k = -1, 1, 2 do
				local ax, az = off(k * 1.6, 0.5)
				lay("Lounger", ax, az, facing + j(8), v * 2 + 1)
			end
		elseif roll == 2 then
			local ax, az = off(side * 1.8, 0.2)
			lay("Lounger", ax, az, facing + j(10), v * 2)
			local bx, bz = off(-side * 2.6, 1.0)
			lay("BeachTowel", bx, bz, facing + j(15), v)
		elseif roll == 3 then
			local ax, az = off(-1.7, 0.6)
			lay("BeachTowel", ax, az, facing + j(12), v)
			local bx, bz = off(1.7, 0.9)
			lay("BeachTowel", bx, bz, facing + j(12), v + 1)
			local cx, cz = off(side * 3.6, -1.6)
			put("Cooler", cx, cz, R:NextNumber(0, 360), v)
		else
			local ax, az = off(side * 1.5, 0.3)
			lay("Lounger", ax, az, facing + j(6), v * 2 + 1)
			local bx, bz = off(-side * 3.0, -2.2)
			put("BeachBall", bx, bz, R:NextNumber(0, 360), v)
		end
	end
	local function coastZ(z: number, r: number): number
		return math.min(z, COAST_MAX_Z - r)
	end

	----------------------------------------------------------------------------------------
	-- Foam along the waterline: four long pulsing strips (water surface, either side of the pier)
	----------------------------------------------------------------------------------------
	local foam = Util.Model("ShoreFoam", parent)
	for _, sx in { -1, 1 } do
		local x0, x1 = 13, Layout.TERRAIN_HALF_X - 20
		local cx = sx * (x0 + x1) / 2
		for i, band in { { z = -99, w = 8, t = 0.5 }, { z = -105.5, w = 1.6, t = 0.6 } } do
			local p = Util.Part({
				Name = "Foam",
				Size = Vector3.new(x1 - x0, 0.1, band.w),
				CFrame = CFrame.new(cx, WATER_Y + 0.1 + i * 0.02, band.z),
				Color = Color3.fromRGB(250, 252, 255),
				Material = Enum.Material.SmoothPlastic,
				Transparency = band.t,
				Decor = true,
				Parent = foam,
			})
			p:SetAttribute("PulseMin", band.t - 0.15)
			p:SetAttribute("PulseMax", math.min(0.95, band.t + 0.35))
			p:SetAttribute("PulsePeriod", 4 + i * 1.3)
			Util.Tag(p, "AmbientPulse")
		end
	end

	----------------------------------------------------------------------------------------
	-- COAST
	----------------------------------------------------------------------------------------

	-- Tide Pool Point (x -398..-335): rock clusters, pools at the waterline, driftwood, palms.
	lay("TidePool", -372, -92, 20, 1, 0.2)
	lay("TidePool", -352, -97, -35, 2, 0.2)
	lay("TidePool", -389, -99, 60, 3, 0.2)
	for _, r in
		{
			{ -397, -79, 2.4 },
			{ -391, -86, 1.8 },
			{ -383, -81, 1.3 },
			{ -362, -86, 1.6 },
			{ -344, -91, 2.0 },
			{ -340, -86, 1.1 },
			{ -379, -103, 2.2 },
		}
	do
		rock(r[1], r[2], r[3], math.floor(r[2]))
	end
	lay("Driftwood", -366, -80, 25, 1)
	lay("Driftwood", -338, -95, -40, 2)
	lay("Starfish", -369, -89, 30, 1)
	lay("Starfish", -356, -93, 80, 3)
	lay("Starfish", -385, -95, 140, 4)
	put("Crab", -360, -90, 200, 1)
	put("Crab", -381, -88, 40, 3)
	lay("ShellPile", -348, -82, 10, 1)
	palm(-395, -80, 3, -1, -0.4)
	palm(-387, -81, 1, -0.5, -1)
	palm(-397, -86, 5, -1, 0.2)
	put("Sign", -364, -75, 180 + j(6), 6) -- TIDE POOLS

	-- Kite Field (x -335..-280): mostly open sand, one kite flyer.
	put("Kite", -318, -80, j(15), 1)
	lay("BeachTowel", -321, -77, 170, 3)
	put("Bucket", -316, -77, 0, 2)
	put("BeachBall", -302, -86, 0, 2)
	lay("ShellPile", -331, -89, 70, 2)
	put("Sandcastle", -292, -79, 160, 2)

	-- Lifeguard + Rowboat Landing (x -280..-205): yellow tower, boats on the sand, a jetty.
	put("LifeguardTower", -262, coastZ(-78, 5), j(5), 3)
	put("BeachFlag", -271, -76, 0, 2)
	put("BeachFlag", -254, -77, 0, 4)
	lay("Rowboat", -240, -88, 172, 1)
	lay("Rowboat", -230, -91, 196, 3)
	lay("Rowboat", -248, -94, 105, 5)
	do
		-- jetty: deck top just above the sand at its landward end, posts down into the sea
		local deckTop = sandY(-216, -92) + 0.8
		Util.PropAt("Dock", parent, CFrame.new(-216, deckTop - 4.6, -100), nil, 1)
	end
	float("Rowboat", -207.5, -106, 8, 2, 0.6, 0.35)
	put("Barrel", -222, -85, 0, 1)
	put("Barrel", -224.5, -87, 40, 2, 0.8)
	lay("Driftwood", -276, -90, 70, 3)

	-- Picnic & Castles (x -200..-130): three umbrella sets, little castles and buckets.
	beachSet(-188, -79, 0)
	beachSet(-160, -80, 10)
	beachSet(-143, -86, -12)
	put("Sandcastle", -172, -86, 200, 1)
	put("Sandcastle", -167, -89, 150, 3)
	put("Bucket", -169, -84, 0, 1)
	put("Bucket", -175, -88, 0, 4)
	lay("ShellPile", -150, -92, 0, 3)

	-- Umbrella Village West (x -112..-16) + swim zone. The busiest beach, in front of the hub.
	for _, p in
		{
			{ -104, -78 },
			{ -94, -87 },
			{ -84, -78 },
			{ -50, -79 },
			{ -41, -88 },
			{ -30, -78 },
			{ -76, -91 },
		}
	do
		beachSet(p[1] + j(2.5), p[2] + j(1), j(14))
	end
	put("LifeguardTower", -64, coastZ(-78, 5), j(4), 1)
	put("Kite", -92, -80, j(20), 2)
	put("Sandcastle", -60, -88, 180, 4)
	put("Cooler", -22, -80, 25, 3)
	palm(-20, -80, 3, -0.6, -1)
	do
		-- swim zone: a U of floats with corner marker buoys and a rope along the outer line
		local x0, x1, zf, zn = -98, -24, -118, -106
		local n = 0
		for k = 0, 12 do
			n += 1
			float("Buoy", x0 + (x1 - x0) * k / 12, zf, 0, if k == 0 or k == 12 then 4 else n, 0.45, 0.25)
		end
		for _, bx in { x0, x1 } do
			for _, bz in { zn, (zn + zf) / 2 } do
				n += 1
				float("Buoy", bx, bz, 0, n, 0.45, 0.25)
			end
		end
		Util.Part({
			Name = "SwimRope",
			Size = Vector3.new(x1 - x0, 0.15, 0.15),
			CFrame = CFrame.new((x0 + x1) / 2, WATER_Y + 0.05, zf),
			Color = Color3.fromRGB(250, 246, 236),
			Decor = true,
			Parent = parent,
		})
		put("Sign", -100, -80, 180, 7) -- SWIM ZONE
	end
	float("Rowboat", -112, -114, 30, 4, 0.6, 0.35)

	-- Umbrella Village East (x 16..112): staggered sets, moored boats beyond the waterline.
	for _, p in
		{
			{ 26, -79 },
			{ 37, -88 },
			{ 49, -78 },
			{ 66, -84 },
			{ 84, -78 },
			{ 95, -89 },
			{ 106, -79 },
		}
	do
		beachSet(p[1] + j(2.5), p[2] + j(1), j(14))
	end
	palm(20, -80, 6, 0.6, -1)
	put("Kite", 74, -80, j(20), 3)
	put("Sandcastle", 58, -90, 170, 5)
	put("BeachBall", 76, -92, 0, 1)
	float("Rowboat", 34, -112, -20, 6, 0.6, 0.35)
	float("Rowboat", 82, -117, 15, 1, 0.6, 0.35)
	float("Buoy", 58, -121, 0, 8, 0.45, 0.3)
	float("Buoy", 104, -124, 0, 12, 0.45, 0.3)

	-- Surf School (x 125..235): stilted shack facing the beach, rack, boards, blue tower, flags.
	stand("SurfShack", 175, -80, 180, 0.3, 2)
	put("SurfRack", 154, -78, 180 + j(6), 1)
	for i, x in { 197, 200.5, 204 } do
		put("Surfboard", x, -80.5 + (i % 2), j(10), i + 1)
	end
	put("LifeguardTower", 222, coastZ(-78, 5), j(5), 2)
	put("BeachFlag", 140, -76, 0, 1)
	put("BeachFlag", 190, -76, 0, 3)
	put("BeachFlag", 211, -77, 0, 5)
	lay("BeachTowel", 186, -88, 10, 4)
	lay("BeachTowel", 190, -89, -8, 2)
	put("Crab", 160, -92, 120, 2)

	-- Snorkel Cove (x 245..325): rental shack, boats, barrels, a kite, marker buoys.
	stand("SurfShack", 285, -80, 180, 0.3, 3)
	lay("Rowboat", 258, -90, 168, 2)
	lay("Rowboat", 267, -93, 197, 6)
	float("Rowboat", 302, -112, 40, 3, 0.6, 0.35)
	float("Buoy", 278, -119, 0, 4, 0.45, 0.3)
	float("Buoy", 312, -123, 0, 16, 0.45, 0.3)
	put("Barrel", 302, -78, 0, 3)
	put("Barrel", 305, -80, 30, 1, 0.8)
	put("Cooler", 249, -78, 60, 2)
	lay("ShellPile", 272, -84, 0, 4)
	put("Kite", 318, -80, j(15), 4)
	put("Crab", 292, -95, 300, 4)

	-- Bonfire Cove (x 335..398): fire ring, log benches, tiki torches, loungers, palms.
	stand("Bonfire", 362, -84, 0, -0.3, 1)
	lay("LogBench", 354, -84, 90, 1)
	lay("LogBench", 362, -91.5, 4, 2)
	lay("LogBench", 370, -84, 92, 3)
	put("TikiTorch", 350, -77, 0, 1)
	put("TikiTorch", 374, -77, 0, 2)
	lay("Lounger", 385, -79, -10, 2)
	lay("Lounger", 390.5, -80, 8, 4)
	put("Cooler", 381, -77, 0, 1)
	lay("Driftwood", 377, -90, 110, 4)
	lay("Driftwood", 346, -92, 20, 5)
	put("Sign", 341, -75, 180, 8) -- BONFIRE
	palm(396, -80, 6, 1, -0.3)
	palm(389, -86, 4, 0.6, -1)
	palm(398, -93, 2, 1, -0.6)
	rock(394, -100, 2.0, 7)
	rock(386, -104, 1.4, 9)

	----------------------------------------------------------------------------------------
	-- INLAND SAND (|x| 122..395, z 14..128)
	----------------------------------------------------------------------------------------

	-- Boardwalk-edge groves: palms frame the stalls, benches look out over the deck.
	grove(-196, 24, 3, 6, 1)
	grove(-302, 25, 3, 6, 4)
	palm(-384, 22, 3, -1, 0.2)
	grove(194, 25, 3, 6, 7)
	grove(304, 23, 3, 6, 10)
	palm(386, 21, 6, 1, 0.3)
	for _, x in { -222, -276, 222, 278 } do
		put("Bench", x + j(3), 17, j(5), if x < 0 then 1 else 2)
	end

	-- Sandcastle Contest (west, by the boardwalk): hero castle, entrants, buckets, sign.
	stand("HeroSandcastle", -150, 40, j(8), -1.0, 1)
	put("Sandcastle", -134, 31, 200, 2)
	put("Sandcastle", -166, 29, 160, 3)
	put("Sandcastle", -137, 50, 230, 1)
	put("Bucket", -141, 29, 0, 3)
	put("Bucket", -158, 27, 0, 2)
	put("Bucket", -131, 41, 0, 4)
	put("Sign", -165, 21, 10, 11) -- SANDCASTLE CONTEST
	lay("BeachTowel", -128, 26, 30, 1)

	-- Picnic Lawn (west): blankets with baskets, a thatched umbrella, a kite, palms.
	lay("PicnicBlanket", -192, 60, 15, 1)
	lay("PicnicBlanket", -178, 69, -20, 3)
	lay("PicnicBlanket", -201, 74, 40, 2)
	put("Umbrella", -186, 66, 0, 3)
	put("Kite", -184, 80, 180 + j(20), 5)
	palm(-210, 63, 2, -1, 0.3)
	palm(-171, 82, 3, 0.4, 1)
	put("Cooler", -195, 66, 15, 4)

	-- Volleyball Court (west): court, spectators' towels and umbrella, flags.
	put("VolleyballCourt", -262, 52, 0, 1)
	put("BeachFlag", -281, 41, 0, 1)
	put("BeachFlag", -243, 41, 0, 3)
	for i, x in { -272, -266, -259 } do
		lay("BeachTowel", x + j(1), 68 + j(1), 180 + j(12), i + 1)
	end
	put("Umbrella", -252, 70, 0, 5)
	lay("Lounger", -249, 73, 180, 5)
	put("Cooler", -246, 66, 0, 2)
	put("BeachBall", -284, 62, 0, 1)

	-- Palm Oasis + hammock (west end)
	do
		local hx, hz, hyaw = -358, 58, 12
		put("Hammock", hx, hz, hyaw, 1)
		local c, s = math.cos(math.rad(hyaw)), math.sin(math.rad(hyaw))
		for k = -1, 1, 2 do
			-- local x axis of the hammock after yaw: (cos, 0, -sin)
			palm(hx + k * 6.9 * c, hz - k * 6.9 * s, if k < 0 then 3 else 2, k * c, -k * s)
		end
		palm(-373, 44, 1, -1, -0.5)
		palm(-344, 71, 5, 0.6, 1)
		palm(-377, 73, 4, -0.8, 1)
		lay("Lounger", -349, 49, 160, 6)
		put("Cooler", -352, 52, 30, 3)
		lay("PicnicBlanket", -366, 66, 70, 4)
	end

	-- Beach Games (east, by the hub): cornhole, tetherball, balls, flags, kite.
	put("Cornhole", 168, 44, 90, 1)
	put("Tetherball", 202, 54, 0, 1)
	put("BeachBall", 186, 36, 0, 2)
	put("BeachBall", 211, 41, 0, 1)
	put("Cooler", 180, 58, 40, 1)
	put("BeachFlag", 150, 33, 0, 2)
	put("BeachFlag", 150, 55, 0, 4)
	put("Kite", 160, 72, 180 + j(20), 2)
	lay("BeachTowel", 192, 64, 200, 3)
	palm(222, 66, 3, 1, 0.4)

	-- Sun Deck (east): an arc of loungers and umbrellas looking out to sea, palms behind.
	for i = 0, 4 do
		local a = (i - 2) * 0.16
		local x = 268 + math.sin(a) * 60
		local z = 40 + (1 - math.cos(a)) * 60 + j(1)
		lay("Lounger", x, z, math.deg(a) * 0.6 + j(5), if i % 2 == 0 then 3 + i * 2 else 1 + i * 2)
		if i % 2 == 0 then
			put("Umbrella", x + 3, z + 1.5, 0, 9 + i)
		end
	end
	put("Cooler", 262, 46, 0, 4)
	grove(268, 66, 3, 7, 13)

	-- Palm Grove + hammock (east end)
	do
		local hx, hz, hyaw = 356, 50, -18
		put("Hammock", hx, hz, hyaw, 2)
		local c, s = math.cos(math.rad(hyaw)), math.sin(math.rad(hyaw))
		for k = -1, 1, 2 do
			palm(hx + k * 6.9 * c, hz - k * 6.9 * s, if k < 0 then 6 else 1, k * c, -k * s)
		end
		palm(372, 66, 2, 1, 0.6)
		palm(341, 36, 4, -0.4, -1)
		palm(382, 38, 3, 1, -0.4)
		lay("PicnicBlanket", 348, 64, -30, 3)
		lay("Lounger", 364, 40, 200, 7)
	end

	-- Cabana rows at the dune edge, facing the sea, with background palms behind.
	local cabanaV = 0
	local function cabanaRow(x0: number, x1: number, n: number, z: number, curve: number)
		for i = 0, n - 1 do
			cabanaV += 1
			local t = (i / (n - 1)) * 2 - 1
			local x = x0 + (x1 - x0) * (i / (n - 1)) + j(1.5)
			local cz = z + curve * t * t + j(1)
			put("BeachCabana", x, cz, -t * curve * 0.6 + j(3), cabanaV)
			if i % 2 == 0 and i < n - 1 then
				lay("BeachTowel", x + 6 + j(1), cz - 7 + j(1), j(20), cabanaV + 1)
			end
		end
	end
	cabanaRow(-338, -206, 7, 104, -4)
	cabanaRow(196, 300, 5, 102, -3)
	lay("Lounger", -290, 92, 0, 9)
	lay("Lounger", -238, 93, 10, 11)
	lay("Lounger", 236, 90, -8, 10)

	-- Dunes: background palms on the ridge, weathered fences with gaps, grass tufts.
	for _, p in
		{
			{ -392, 118 },
			{ -357, 124 },
			{ -318, 121 },
			{ -262, 126 },
			{ -229, 119 },
			{ -163, 123 },
			{ 171, 125 },
			{ 238, 121 },
			{ 289, 126 },
			{ 327, 118 },
			{ 362, 123 },
			{ 394, 116 },
		}
	do
		palm(p[1] + j(3), p[2] + j(2), math.floor(math.abs(p[1])) % 7 + 1, j(1), 1, true)
	end
	for _, f in
		{
			{ -372, 121, 4 },
			{ -360, 122, -6 },
			{ -300, 124, 3 },
			{ -196, 122, -4 },
			{ -184, 121, 8 },
			{ 150, 122, 5 },
			{ 226, 123, 6 },
			{ 316, 121, -5 },
			{ 376, 122, 4 },
		}
	do
		put("Fence", f[1], f[2], f[3], math.floor(math.abs(f[1])))
	end
	for i = 1, 18 do
		local side = if i % 2 == 0 then 1 else -1
		local x = side * R:NextNumber(126, 396)
		local z = R:NextNumber(110, 128)
		put("DuneGrass", x, z, R:NextNumber(0, 360), i, R:NextNumber(0.9, 1.4))
	end
	for _, p in { { -396, 120 }, { 396, 121 }, { -397, 96 } } do
		rock(p[1], p[2], 1.8, math.floor(p[2]))
	end

	----------------------------------------------------------------------------------------
	-- Boardwalk stalls (on Stream B's deck; names / height pinned by smoke.spec)
	----------------------------------------------------------------------------------------
	local deckZ = (Layout.BOARDWALK_Z0 + Layout.BOARDWALK_Z1) / 2 + 3
	for x, kind in { [-350] = 4, [-250] = 3, [-130] = 2, [130] = 1, [250] = 8, [350] = 6 } do
		Util.Prop("BoardwalkStall", parent, Vector3.new(x, Layout.DECK_TOP, deckZ), 0, nil, true, kind)
	end
end

return Decor
