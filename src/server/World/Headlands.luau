--!strict
--[[
	Headlands — shared shape data for the two headlands that close the beach, the west sea arch
	and the offshore sea stacks. Pure data (deterministic, own Random): no instances.

	Every blob is built twice:
	  * Terrain.luau fills it as smooth terrain (Rock base and cliff, Grass cap), which is
	    what a player standing near the map ends sees;
	  * Vistas.luau builds a slightly smaller part ellipsoid inside it (Persistent model), which is
	    what everyone else sees: with StreamingEnabled (TargetRadius 320) terrain more than ~320
	    studs away is not streamed to the client, and the spawn is ~450 studs from both headlands.
	Where the terrain is loaded it covers the parts; where it is not, the parts stand in for it.

	No blob ever reaches into the playable box (|x| < 400, -232 < z < 130) plus a margin, so the
	walkable surface inside the boundary is untouched.
]]

local Layout = require(script.Parent.Layout)

local Headlands = {}

export type Blob = {
	Center: Vector3,
	Radius: number,
	Material: Enum.Material, -- terrain material (Rock / Grass / LeafyGrass)
	Layer: number, -- fill order: 1 rock, 2 cliff, 3 cap
}

export type Data = {
	Blobs: { Blob },
	LighthouseBase: Vector3, -- top of the plateau under the lighthouse
	CottageBase: Vector3, -- keeper's cottage floor centre
	PalmSpots: { Vector3 }, -- headland-top palm bases (approximate ground Y)
	ArchCenter: Vector3,
}

local V = Vector3.new
local W = Layout.WATER_Y -- 1020
local MARGIN = 6
local PLAY_X = Layout.BOUND_HALF_X + MARGIN -- 406
local PLAY_SOUTH = Layout.BOUND_SOUTH_Z - MARGIN -- -238
local PLAY_NORTH = Layout.BOUND_NORTH_Z + MARGIN -- 136

-- Largest radius a ball at `c` may have without entering the playable box.
local function clampRadius(c: Vector3, r: number): number
	local dx = math.max(math.abs(c.X) - PLAY_X, 0)
	local dz = math.max(PLAY_SOUTH - c.Z, c.Z - PLAY_NORTH, 0)
	local d = math.sqrt(dx * dx + dz * dz)
	return math.min(r, d)
end

type SpinePoint = { x: number, z: number, h: number, r: number, fixed: boolean? }

-- East: inland ridge -> shore -> curls out to sea, lighthouse on the tip.
local EAST: { SpinePoint } = {
	{ x = 612, z = 262, h = 66, r = 60 },
	{ x = 548, z = 182, h = 60, r = 56 },
	{ x = 506, z = 104, h = 52, r = 52 },
	{ x = 484, z = 24, h = 48, r = 50 },
	{ x = 474, z = -56, h = 46, r = 50 },
	{ x = 464, z = -138, h = 52, r = 50 },
	{ x = 452, z = -222, h = 58, r = 46 },
	{ x = 424, z = -302, h = 62, r = 50 },
	{ x = 384, z = -378, h = 66, r = 50, fixed = true },
	{ x = 340, z = -450, h = 70, r = 48, fixed = true },
}
-- West: mirror-ish but lower, broken tip, sea arch beyond it.
local WEST: { SpinePoint } = {
	{ x = -606, z = 250, h = 62, r = 58 },
	{ x = -546, z = 170, h = 56, r = 54 },
	{ x = -502, z = 92, h = 50, r = 50 },
	{ x = -484, z = 12, h = 44, r = 48 },
	{ x = -472, z = -70, h = 42, r = 48 },
	{ x = -464, z = -150, h = 50, r = 48 },
	{ x = -458, z = -226, h = 56, r = 46 },
	{ x = -428, z = -302, h = 60, r = 50 },
	{ x = -388, z = -372, h = 62, r = 48 },
	{ x = -350, z = -432, h = 54, r = 44 },
	{ x = -334, z = -468, h = 26, r = 28, fixed = true },
}

local data: Data? = nil

local function build(): Data
	local rng = Random.new(77031)
	local blobs: { Blob } = {}
	local palms: { Vector3 } = {}

	local function add(c: Vector3, r: number, material: Enum.Material, layer: number)
		local rr = clampRadius(c, r)
		if rr >= 6 then
			table.insert(blobs, { Center = c, Radius = rr, Material = material, Layer = layer })
		end
	end

	-- One cliff column: rock ball at the waterline, rock cliff above it, grass cap on top.
	-- Returns the cap top Y.
	local function column(x: number, z: number, h: number, r: number, grassy: number, capMat: Enum.Material): number
		local top = W + h
		add(V(x, W - 8, z), r, Enum.Material.Rock, 1)
		local ru = r * 0.78
		local cy = math.max(top - ru, W - 8)
		add(V(x, cy, z), ru, Enum.Material.Rock, 2)
		local rc = ru * grassy
		add(V(x, top - rc + 3, z), rc, capMat, 3)
		return top + 3
	end

	local function spine(points: { SpinePoint }, palmEvery: number)
		local step = 38
		local count = 0
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local len = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
			local n = math.max(1, math.floor(len / step + 0.5))
			for k = 0, n - 1 do
				local t = k / n
				local fixed = (t == 0 and a.fixed == true)
				local jx = if fixed then 0 else rng:NextNumber(-8, 8)
				local jz = if fixed then 0 else rng:NextNumber(-8, 8)
				local x = a.x + (b.x - a.x) * t + jx
				local z = a.z + (b.z - a.z) * t + jz
				local h = a.h + (b.h - a.h) * t + (if fixed then 0 else rng:NextNumber(-6, 6))
				local r = (a.r + (b.r - a.r) * t) * (if fixed then 1 else rng:NextNumber(0.88, 1.12))
				-- Inland the ridge is a grassy hill; seaward it is a cliff with a thin grass lip.
				local grassy = if z > -70 then 0.9 else 0.72
				local capMat = if rng:NextNumber() < 0.4 then Enum.Material.LeafyGrass else Enum.Material.Grass
				local capTop = column(x, z, h, r, grassy, capMat)
				count += 1
				if count % palmEvery == 0 and z > -330 then
					local side = rng:NextNumber(-6, 6)
					table.insert(palms, V(x + side, capTop - 1.5, z + rng:NextNumber(-6, 6)))
				end
			end
		end
		local last = points[#points]
		column(last.x, last.z, last.h, last.r, 0.78, Enum.Material.Grass)
	end

	spine(EAST, 4)
	spine(WEST, 4)

	-- Lighthouse plateau: a broad flat-topped blob on the east tip.
	local tip = EAST[#EAST]
	local plateauTop = W + tip.h + 3
	add(V(tip.x, plateauTop - 31, tip.z), 32, Enum.Material.Grass, 3)

	-- Small rocks off the headland tips (rock only, no cap).
	for _, s in { { 300, -506, 8, 16 }, { 274, -532, 3, 10 }, { 372, -470, 4, 12 }, { -372, -478, 5, 13 } } do
		add(V(s[1], W + s[3] - s[4], s[2]), s[4], Enum.Material.Rock, 1)
	end

	-- Sea stacks: one tapered pillar of closely overlapping rock balls (a coarse stack of
	-- separate balls read as snowmen in Studio), leaning slightly, a grass tuft on the tallest.
	local function stack(x: number, z: number, radii: { number }, tuft: boolean)
		local y = W - 6
		local lean = rng:NextNumber(0, math.pi * 2)
		local lx, lz = math.cos(lean), math.sin(lean)
		local top = y
		for i = 1, #radii - 1 do
			local r0, r1 = radii[i], radii[i + 1]
			for k = 0, 2 do
				local t = k / 3
				local r = r0 + (r1 - r0) * t
				local h = (i - 1 + t) * 3
				add(
					V(x + lx * h + rng:NextNumber(-1.5, 1.5), y, z + lz * h + rng:NextNumber(-1.5, 1.5)),
					r,
					Enum.Material.Rock,
					i == 1 and k == 0 and 1 or 2
				)
				top = y + r
				y += r * 0.42
			end
		end
		local rLast = radii[#radii]
		local h = (#radii - 1) * 3
		add(V(x + lx * h, y, z + lz * h), rLast, Enum.Material.Rock, 2)
		top = y + rLast
		if tuft then
			add(V(x + lx * h, top - rLast * 0.35, z + lz * h), rLast * 0.6, Enum.Material.LeafyGrass, 3)
		end
	end
	stack(-214, -332, { 22, 18, 14, 10 }, true)
	stack(-148, -404, { 16, 13, 9 }, false)
	stack(-254, -276, { 12, 9 }, false)
	stack(252, -382, { 15, 12, 8 }, true)

	-- West sea arch, set across the sightline from the spawn so you look through it.
	local center = V(-295, W, -505)
	local toSpawn = (V(0, W, 4) - center).Unit
	local across = V(-toSpawn.Z, 0, toSpawn.X)
	local legA = center - across * 36
	local legB = center + across * 36
	local H = 62
	local pts: { Vector3 } = {}
	local samples = 80
	for k = 0, samples do
		local t = k / samples
		local p = legA:Lerp(legB, t)
		local lift = math.sin(math.pi * t) ^ 0.45
		table.insert(pts, V(p.X, W - 12 + (H + 12) * lift, p.Z))
	end
	local walked = 0
	local nextAt = 0
	for k = 1, #pts do
		if k > 1 then
			walked += (pts[k] - pts[k - 1]).Magnitude
		end
		if walked >= nextAt or k == #pts then
			local t = (k - 1) / samples
			local r = 11 + 7 * (1 - math.sin(math.pi * t))
			add(pts[k], r, Enum.Material.Rock, 2)
			nextAt = walked + 9
		end
	end
	-- Grass along the crown of the arch.
	for _, t in { 0.4, 0.5, 0.6 } do
		local p = legA:Lerp(legB, t)
		add(V(p.X, W + H - 4, p.Z), 8, Enum.Material.Grass, 3)
	end
	-- Saddle between the west tip and the arch's landward leg.
	add(V(-332, W - 4, -478), 22, Enum.Material.Rock, 1)

	local toward = V(EAST[#EAST - 1].x - tip.x, 0, EAST[#EAST - 1].z - tip.z).Unit
	return {
		Blobs = blobs,
		LighthouseBase = V(tip.x, plateauTop + 1, tip.z),
		CottageBase = V(tip.x, plateauTop - 1, tip.z) + toward * 30,
		PalmSpots = palms,
		ArchCenter = center + V(0, H, 0),
	}
end

function Headlands.Get(): Data
	local d = data
	if d == nil then
		d = build()
		data = d
	end
	return d :: Data
end

return Headlands
