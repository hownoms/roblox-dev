--!strict
--[[
	PropsBeach — the beach dressing kit used by Props (map overhaul, stream D): big varied palms,
	cabanas, loungers, volleyball court, bonfire ring, tide pools, rowboats, buoys, kites,
	driftwood, dune grass, fences, surf racks, feather flags, picnic spots, games, hero castle.

	Same conventions as Props: built around the origin, invisible "Root" pivot at the bottom
	centre (added by Props.Build), FRONT = -Z. Every builder works for any variant >= 1.

	Animated pieces are marked with the attribute "AmbientTag" (+ the tag's attributes from
	docs/MAP_ART_DIRECTION.md); the server's Util.ApplyAmbientTags turns them into
	CollectionService tags. Shared code, so no services here.
]]

local Build = require(script.Parent.Build)

local PropsBeach = {}

local V = Vector3.new
local CF = CFrame.new
local X = Vector3.xAxis
local Y = Vector3.yAxis
local Z = Vector3.zAxis
local rgb = Color3.fromRGB
local PI = math.pi
local M = Enum.Material

local WHITE = rgb(250, 246, 236)
local SAND = rgb(255, 222, 140)
local WOOD = rgb(176, 122, 76)
local WOOD_DARK = rgb(124, 84, 52)
local NAVY = rgb(31, 55, 73)
local CORAL = rgb(255, 96, 92)
local OCEAN = rgb(40, 170, 240)
local GOLD = rgb(255, 205, 40)
local ROPE = rgb(214, 190, 140)
local WATER = rgb(70, 190, 220)

local solid = Build.solid

local function pick<T>(list: { T }, variant: number): T
	return list[(math.floor(variant) - 1) % #list + 1]
end

export type Builder = (m: Model, v: number) -> ()

-- Mark an instance for the server to tag (see header).
local function ambient(inst: Instance, tag: string, attrs: { [string]: any }?)
	inst:SetAttribute("AmbientTag", tag)
	if attrs then
		for k, value in attrs do
			inst:SetAttribute(k, value)
		end
	end
end

-- Child model that sways about `hinge` (flags, banners). Returns the model to build into.
local function swayGroup(m: Model, name: string, hinge: Vector3, degrees: number, period: number): Model
	local g = Instance.new("Model")
	g.Name = name
	local pivot = Build.part(g, "Pivot", V(0.2, 0.2, 0.2), CF(hinge), WHITE)
	pivot.Transparency = 1
	pivot.CastShadow = false
	g.PrimaryPart = pivot
	ambient(g, "AmbientSway", { SwayDegrees = degrees, SwayPeriod = period })
	g.Parent = m
	return g
end
PropsBeach.swayGroup = swayGroup

----------------------------------------------------------------------------------------------
-- Palms
----------------------------------------------------------------------------------------------

local PALM_GREENS = {
	{ rgb(64, 168, 78), rgb(96, 198, 98), rgb(44, 128, 64) },
	{ rgb(84, 182, 70), rgb(128, 208, 92), rgb(60, 142, 58) },
	{ rgb(54, 158, 96), rgb(88, 192, 116), rgb(38, 118, 78) },
	{ rgb(98, 176, 64), rgb(140, 204, 84), rgb(72, 138, 52) },
}
local PALM_BARK = {
	{ rgb(168, 122, 80), rgb(138, 98, 62) },
	{ rgb(150, 112, 80), rgb(122, 88, 62) },
	{ rgb(178, 136, 94), rgb(146, 104, 70) },
}

-- Curved palm, 18-34 studs (three height classes cycle with the variant). The crown leans
-- towards local -Z (+-20 degrees) so callers aim the lean with the yaw. `hero` = full detail
-- (layered droopy fronds, coconuts); otherwise a cheap ~11-part background palm.
function PropsBeach.Palm(m: Model, v: number, hero: boolean)
	local rng = Random.new(v * 7919 + (if hero then 13 else 71))
	local class = (math.floor(v) - 1) % 3
	local H = (if class == 0 then 18 elseif class == 1 then 24 else 29) + rng:NextNumber(0, 5)
	local la = -PI / 2 + rng:NextNumber(-0.35, 0.35)
	local lx, lz = math.cos(la), math.sin(la)
	local bend = H * rng:NextNumber(0.12, 0.24)
	local function at(t: number): Vector3
		local b = bend * t ^ 1.7
		return V(lx * b, t * H, lz * b)
	end
	local bark = pick(PALM_BARK, v + (if hero then 0 else 1))
	local greens = pick(PALM_GREENS, v * 3 + 1)
	local base = 1.6 * math.sqrt(H / 24)
	local segs = if hero then 5 else 3
	for i = 0, segs - 1 do
		local a, b = at(i / segs), at((i + 1) / segs)
		local d = (b - a).Unit
		local p = Build.cylBetween(
			m,
			"Trunk",
			a - (if i == 0 then d * 0.4 else Vector3.zero),
			b + d * 0.3,
			base * (1 - 0.34 * i / segs),
			bark[i % 2 + 1],
			M.Wood
		)
		if i < 2 then
			solid(p)
		end
	end
	local top = at(1)
	local k = math.clamp(H / 24, 0.8, 1.3)
	Build.ball(m, "Crown", 1.6 * k, CF(top), greens[3])
	local L = H * 0.3 * rng:NextNumber(0.9, 1.1)
	local offset = rng:NextNumber() * PI * 2
	if hero then
		local nuts = 3 + (math.floor(v) % 2)
		for i = 0, nuts - 1 do
			local a = i / nuts * PI * 2 + offset
			Build.ball(
				m,
				"Coconut",
				0.95 * k,
				CF(top + V(math.cos(a) * 0.7 * k, -0.85 * k, math.sin(a) * 0.7 * k)),
				if i % 2 == 0 then rgb(118, 82, 46) else rgb(150, 132, 60)
			)
		end
		-- upper ring: rise then droop; lower ring: older fronds hanging steeply
		local rings = {
			{ n = 6, rise = 0.14, drop = 0.3, reach = 1.0, w = 0.25 },
			{ n = 4, rise = -0.06, drop = 0.62, reach = 0.72, w = 0.21 },
		}
		for r, ring in rings do
			for f = 0, ring.n - 1 do
				local a = (f + (r - 1) * 0.5) / ring.n * PI * 2 + offset + rng:NextNumber(-0.18, 0.18)
				local h = V(math.cos(a), 0, math.sin(a))
				local perp = V(-h.Z, 0, h.X)
				local len = L * rng:NextNumber(0.88, 1.12)
				local mid = top + h * (len * 0.48 * ring.reach) + Y * (len * ring.rise)
				local tip = top + h * (len * ring.reach) - Y * (len * ring.drop)
				local col = if r == 2 then greens[3] else greens[f % 2 + 1]
				local w = len * ring.w
				Build.beam(m, "Frond", top, mid, w, 0.14, col, M.SmoothPlastic, (perp + Y * 0.2).Unit)
				Build.beam(m, "Frond", mid, tip, w * 0.62, 0.12, col, M.SmoothPlastic, (perp - Y * 0.15).Unit)
			end
		end
	else
		for f = 0, 6 do
			local a = f / 7 * PI * 2 + offset
			local h = V(math.cos(a), 0, math.sin(a))
			local perp = V(-h.Z, 0, h.X)
			local tip = top + h * (L * 0.85) - Y * (L * (if f % 2 == 0 then 0.42 else 0.22))
			Build.beam(m, "Frond", top, tip, L * 0.26, 0.15, greens[f % 2 + 1], M.SmoothPlastic, perp)
		end
	end
end

local builders: { [string]: Builder } = {}
PropsBeach.Builders = builders
PropsBeach.Order = {} :: { string }
local function add(name: string, fn: Builder)
	builders[name] = fn
	table.insert(PropsBeach.Order, name)
end

add("BackgroundPalm", function(m, v)
	PropsBeach.Palm(m, v, false)
end)

----------------------------------------------------------------------------------------------
-- Seating
----------------------------------------------------------------------------------------------

local FABRIC = {
	{ rgb(255, 96, 110), WHITE },
	{ rgb(40, 170, 240), rgb(255, 228, 90) },
	{ rgb(255, 160, 60), WHITE },
	{ rgb(80, 196, 140), rgb(255, 246, 214) },
	{ rgb(160, 110, 240), rgb(255, 210, 230) },
	{ NAVY, WHITE },
	{ rgb(40, 196, 196), rgb(255, 240, 200) },
}

-- Sun lounger (odd variants) or folding deck chair (even). Feet towards -Z, back at +Z.
add("Lounger", function(m, v)
	local cols = pick(FABRIC, v)
	if math.floor(v) % 2 == 1 then
		local frame = if math.floor(v) % 4 == 1 then WHITE else WOOD
		for sx = -1, 1, 2 do
			Build.part(m, "Rail", V(0.22, 0.22, 6.2), CF(sx * 1.1, 1.15, 0), frame, M.Wood)
		end
		for _, z in { -2.8, 2.6 } do
			Build.part(m, "Legs", V(2.4, 1.05, 0.24), CF(0, 0.52, z), frame, M.Wood)
		end
		Build.part(m, "Seat", V(2.2, 0.32, 4.0), CF(0, 1.42, -1.0), cols[1], M.Fabric)
		local back = CF(0, 1.42, 1.0) * CFrame.Angles(-0.8, 0, 0) * CF(0, 0, 1.2)
		Build.part(m, "Back", V(2.2, 0.32, 2.4), back, cols[1], M.Fabric)
		Build.part(m, "Stripe", V(0.5, 0.34, 4.02), CF(0, 1.43, -1.0), cols[2], M.Fabric)
		Build.part(m, "Stripe", V(0.5, 0.34, 2.42), back * CF(0, 0.01, 0), cols[2], M.Fabric)
	else
		local wood = if math.floor(v) % 4 == 0 then WOOD_DARK else WOOD
		for sx = -1, 1, 2 do
			Build.beam(m, "Frame", V(sx * 1.15, 0, -1.6), V(sx * 1.15, 3.6, 1.4), 0.2, 0.2, wood, M.Wood, X)
			Build.beam(m, "Frame", V(sx * 1.15, 0, 1.0), V(sx * 1.15, 1.4, -1.1), 0.2, 0.2, wood, M.Wood, X)
			Build.part(m, "Arm", V(0.24, 0.16, 1.7), CF(sx * 1.2, 1.9, -0.2), wood, M.Wood)
		end
		Build.beam(m, "Sling", V(0, 0.9, -1.1), V(0, 3.5, 1.3), 2.2, 0.12, cols[1], M.Fabric, X)
		Build.beam(m, "Stripe", V(0, 0.9, -1.12), V(0, 3.5, 1.28), 0.7, 0.14, cols[2], M.Fabric, X)
	end
end)

add("LogBench", function(m, v)
	local rng = Random.new(v * 211 + 3)
	local len = 6 + rng:NextNumber(0, 2)
	local bark = pick({ rgb(124, 86, 54), rgb(110, 78, 50), rgb(140, 98, 62) }, v)
	solid(Build.cylBetween(m, "Log", V(-len / 2, 1.5, 0), V(len / 2, 1.5, 0), 1.5, bark, M.Wood))
	for sx = -1, 1, 2 do
		Build.cyl(
			m,
			"Cut",
			0.06,
			1.3,
			CF(sx * (len / 2 + 0.02), 1.5, 0) * CFrame.Angles(0, 0, PI / 2),
			rgb(206, 166, 112),
			M.Wood
		)
		Build.part(m, "Chock", V(0.9, 0.8, 1.4), CF(sx * (len / 2 - 0.9), 0.4, 0), WOOD_DARK, M.Wood)
	end
	Build.part(m, "Seat", V(len - 0.6, 0.12, 0.7), CF(0, 2.24, 0), rgb(192, 150, 98), M.Wood)
end)

----------------------------------------------------------------------------------------------
-- Cabanas (changing huts)
----------------------------------------------------------------------------------------------

local PASTELS = {
	{ rgb(255, 190, 196), rgb(240, 108, 120) },
	{ rgb(170, 222, 246), rgb(48, 150, 220) },
	{ rgb(255, 232, 160), rgb(236, 168, 40) },
	{ rgb(184, 236, 200), rgb(60, 170, 110) },
	{ rgb(214, 196, 250), rgb(130, 96, 220) },
	{ rgb(255, 210, 170), rgb(236, 120, 60) },
	{ rgb(160, 230, 226), rgb(30, 160, 160) },
}

-- Pastel beach hut: plinth, white corner trim, peaked roof with eaves, numbered door (odd
-- variants) or striped curtain (even). Door faces -Z. The number shown is the variant.
add("BeachCabana", function(m, v)
	local cols = pick(PASTELS, v)
	local wall, accent = cols[1], cols[2]
	local W, D, Hw = 6, 6, 6.6 -- width, depth, wall height
	local y0 = 0.6
	solid(Build.part(m, "Plinth", V(W + 1.6, y0, D + 1.4), CF(0, y0 / 2, 0.2), WOOD, M.Wood))
	solid(Build.part(m, "Step", V(2.6, 0.3, 0.9), CF(0, 0.15, -D / 2 - 1.0), WOOD_DARK, M.Wood))
	local cy = y0 + Hw / 2
	solid(Build.part(m, "BackWall", V(W, Hw, 0.3), CF(0, cy, D / 2), wall, M.WoodPlanks))
	for sx = -1, 1, 2 do
		solid(Build.part(m, "SideWall", V(0.3, Hw, D), CF(sx * W / 2, cy, 0), wall, M.WoodPlanks))
		solid(Build.part(m, "FrontWall", V(1.6, Hw, 0.3), CF(sx * (W / 2 - 0.8), cy, -D / 2), wall, M.WoodPlanks))
		for _, sz in { -1, 1 } do
			Build.part(m, "Trim", V(0.45, Hw + 0.1, 0.45), CF(sx * W / 2, cy, sz * D / 2), WHITE, M.Wood)
		end
	end
	Build.part(m, "Header", V(2.9, 1.2, 0.34), CF(0, y0 + Hw - 0.6, -D / 2), wall, M.WoodPlanks)
	Build.part(m, "Sill", V(W + 0.5, 0.3, D + 0.5), CF(0, y0 + Hw + 0.15, 0), WHITE, M.Wood)
	-- roof: two slopes meeting at the ridge, overhanging eaves, gable ends in the accent colour
	local eaveY, ridgeY = y0 + Hw + 0.3, y0 + Hw + 3.0
	for sx = -1, 1, 2 do
		local a = V(sx * (W / 2 + 0.9), eaveY - 0.25, 0)
		local b = V(0, ridgeY, 0)
		solid(Build.beam(m, "Roof", a, b + (b - a).Unit * 0.2, D + 1.4, 0.3, accent, M.SmoothPlastic, Z))
	end
	for _, sz in { -1, 1 } do
		Build.tri(
			m,
			"Gable",
			CF(0, (eaveY + ridgeY) / 2 - 0.05, sz * (D / 2 + 0.05)),
			W + 0.2,
			ridgeY - eaveY,
			0.3,
			WHITE,
			M.Wood
		)
	end
	Build.ball(m, "Finial", 0.6, CF(0, ridgeY + 0.25, -D / 2 - 0.4), accent)
	if math.floor(v) % 2 == 1 then
		local door =
			Build.part(m, "Door", V(2.5, Hw - 1.3, 0.2), CF(0, y0 + (Hw - 1.3) / 2, -D / 2 + 0.05), accent, M.Wood)
		door.CastShadow = false
		local plate = Build.part(m, "SignBoard", V(1.1, 1.1, 0.12), CF(0, y0 + Hw - 2.3, -D / 2 - 0.1), WHITE)
		Build.label(plate, Enum.NormalId.Front, tostring(math.floor(v)), accent, WHITE)
		Build.ball(m, "Knob", 0.3, CF(0.85, y0 + 2.4, -D / 2 - 0.12), GOLD, M.Metal)
	else
		for i = 0, 3 do
			Build.part(
				m,
				"Curtain",
				V(0.64, Hw - 1.3, 0.12),
				CF(-0.96 + i * 0.64, y0 + (Hw - 1.3) / 2, -D / 2 + 0.05),
				if i % 2 == 0 then accent else WHITE,
				M.Fabric
			)
		end
	end
	Build.ellipsoid(m, "Porthole", V(0.3, 1.3, 1.3), CF(W / 2 + 0.15, y0 + Hw - 2.0, 0), WHITE)
	Build.part(m, "Towel", V(0.12, 1.8, 1.1), CF(-W / 2 - 0.2, y0 + 3.4, -1.2), pick(FABRIC, v + 2)[1], M.Fabric)
end)

----------------------------------------------------------------------------------------------
-- Activities
----------------------------------------------------------------------------------------------

-- 32 x 16 sand court (long axis X), rope border, net across the middle, ball and score sign.
add("VolleyballCourt", function(m, v)
	local L, Wd = 32, 16
	local rope = pick({ WHITE, OCEAN, CORAL }, v)
	for _, sz in { -1, 1 } do
		Build.part(m, "Line", V(L, 0.12, 0.35), CF(0, 0.06, sz * Wd / 2), rope)
	end
	for _, sx in { -1, 1 } do
		Build.part(m, "Line", V(0.35, 0.12, Wd), CF(sx * L / 2, 0.06, 0), rope)
		for _, sz in { -1, 1 } do
			Build.cyl(m, "Stake", 0.8, 0.3, CF(sx * L / 2, 0.4, sz * Wd / 2), WOOD_DARK, M.Wood)
		end
	end
	local poleH = 8.4
	for _, sz in { -1, 1 } do
		local z = sz * (Wd / 2 + 1.2)
		solid(Build.cyl(m, "NetPole", poleH, 0.45, CF(0, poleH / 2, z), WHITE, M.Metal))
		Build.cylBetween(m, "GuyRope", V(0, poleH - 0.4, z), V(0, 0, z + sz * 3.2), 0.1, ROPE)
		Build.part(m, "Pad", V(0.8, 2.4, 0.8), CF(0, 1.4, z), pick({ CORAL, OCEAN, GOLD }, v + 1), M.Fabric)
	end
	local net = Build.part(m, "Net", V(0.08, 3.0, Wd + 2.4), CF(0, poleH - 2.0, 0), rgb(40, 40, 50), M.Fabric)
	net.Transparency = 0.55
	Build.part(m, "NetTape", V(0.14, 0.32, Wd + 2.4), CF(0, poleH - 0.5, 0), WHITE, M.Fabric)
	Build.part(m, "NetTape", V(0.14, 0.18, Wd + 2.4), CF(0, poleH - 3.5, 0), WHITE, M.Fabric)
	local ball = V(-6, 0.9, 2.5)
	Build.ball(m, "Ball", 1.8, CF(ball), rgb(255, 236, 120))
	Build.ellipsoid(m, "BallStripe", V(1.86, 1.86, 0.7), CF(ball) * CFrame.Angles(0.4, 0.6, 0), OCEAN)
	solid(Build.part(m, "SignPost", V(0.35, 5.2, 0.35), CF(L / 2 + 2, 2.6, Wd / 2 + 1), WOOD_DARK, M.Wood))
	local sign = Build.part(m, "SignBoard", V(5.2, 1.6, 0.25), CF(L / 2 + 2, 5.0, Wd / 2 + 0.85), WOOD, M.Wood)
	Build.label(sign, Enum.NormalId.Front, "BEACH VOLLEY", WHITE)
end)

add("Cornhole", function(m, v)
	local cols = pick({ { CORAL, WHITE }, { OCEAN, GOLD }, { rgb(60, 180, 110), WHITE } }, v)
	for _, sz in { -1, 1 } do
		local cf = CF(0, 0.75, sz * 7) * CFrame.Angles(sz * 0.22, if sz > 0 then PI else 0, 0)
		Build.part(m, "Board", V(2.4, 0.2, 4.4), cf, cols[1], M.Wood)
		Build.part(m, "Trim", V(2.5, 0.22, 0.5), cf * CF(0, 0.01, 1.4), cols[2], M.Wood)
		Build.cyl(m, "Hole", 0.24, 0.8, cf * CF(0, 0.02, -1.2), rgb(30, 30, 40))
		Build.part(m, "Legs", V(2.2, 1.3, 0.2), CF(0, 0.65, sz * 8.9), WOOD_DARK, M.Wood)
		for i = 1, 2 do
			Build.part(
				m,
				"Bag",
				V(0.7, 0.25, 0.7),
				CF(0.5 * i - 0.8, 0.13, sz * (3 + i)),
				if i == 1 then cols[1] else cols[2],
				M.Fabric
			)
		end
	end
end)

add("Tetherball", function(m, v)
	local col = pick({ GOLD, CORAL, OCEAN, rgb(120, 220, 120) }, v)
	solid(Build.cyl(m, "Pole", 9, 0.35, CF(0, 4.5, 0), WHITE, M.Metal))
	Build.cyl(m, "Base", 0.4, 2.2, CF(0, 0.2, 0), rgb(120, 120, 130), M.Concrete)
	local ball = V(1.6, 4.4, 1.2)
	Build.cylBetween(m, "Rope", V(0, 8.8, 0), ball, 0.08, ROPE)
	Build.ball(m, "Ball", 1.4, CF(ball), col)
end)

----------------------------------------------------------------------------------------------
-- Bonfire cove
----------------------------------------------------------------------------------------------

local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"

local function fireEmitter(p: BasePart, scale: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Fire"
	e.Texture = FIRE_TEX
	e.Color = ColorSequence.new(rgb(255, 210, 90), rgb(255, 90, 30))
	e.LightEmission = 0.9
	e.LightInfluence = 0
	e.Rate = 26 * scale
	e.Lifetime = NumberRange.new(0.5, 1.0)
	e.Speed = NumberRange.new(2 * scale, 4 * scale)
	e.SpreadAngle = Vector2.new(10, 10)
	e.Acceleration = V(0, 3 * scale, 0)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Rotation = NumberRange.new(0, 360)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.6 * scale),
		NumberSequenceKeypoint.new(1, 0.2 * scale),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Parent = p
end

-- Stone ring, log teepee, glowing coals, flames + smoke + embers, warm night light.
add("Bonfire", function(m, v)
	local rng = Random.new(v * 433 + 9)
	for i = 0, 9 do
		local a = i / 10 * PI * 2
		local g = 118 + rng:NextInteger(-14, 18)
		solid(
			Build.ellipsoid(
				m,
				"Stone",
				V(1.5, 0.9, 1.2) * rng:NextNumber(0.85, 1.2),
				CF(math.cos(a) * 2.6, 0.35, math.sin(a) * 2.6) * CFrame.Angles(0, -a, 0),
				rgb(g, g - 4, g - 10),
				M.Slate
			)
		)
	end
	Build.ellipsoid(m, "Ash", V(4.2, 0.4, 4.2), CF(0, 0.12, 0), rgb(70, 62, 58), M.Slate)
	local coals = Build.ellipsoid(m, "Coals", V(2.6, 0.5, 2.6), CF(0, 0.3, 0), rgb(255, 110, 30), M.Neon)
	coals.CastShadow = false
	for i = 0, 3 do
		local a = i / 4 * PI * 2 + 0.4
		Build.cylBetween(
			m,
			"Log",
			V(math.cos(a) * 1.6, 0.2, math.sin(a) * 1.6),
			V(math.cos(a) * 0.2, 2.6, math.sin(a) * 0.2),
			0.5,
			rgb(96, 64, 40),
			M.Wood
		)
	end
	Build.spike(m, "Flame", V(0, 0.4, 0), V(0, 3.6, 0), 1.6, rgb(255, 150, 40), M.Neon)
	local emitter = Build.part(m, "FireEmitter", V(1.6, 0.4, 1.6), CF(0, 0.8, 0), WHITE)
	emitter.Transparency = 1
	fireEmitter(emitter, 1)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = SMOKE_TEX
	smoke.Color = ColorSequence.new(rgb(120, 116, 112))
	smoke.LightInfluence = 0.6
	smoke.Rate = 4
	smoke.Lifetime = NumberRange.new(3, 5)
	smoke.Speed = NumberRange.new(2, 3.5)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.Acceleration = V(0.6, 0.4, 0)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	smoke.Parent = emitter
	local embers = Build.sparkle(emitter, rgb(255, 170, 60), 6)
	embers.Name = "Embers"
	embers.Speed = NumberRange.new(2, 5)
	embers.SpreadAngle = Vector2.new(25, 25)
	local light = Build.glow(emitter, rgb(255, 170, 90), 2.4, 16)
	ambient(light, "AmbientNightLight")
end)

-- Bamboo tiki torch with a real flame (emitter + night light).
add("TikiTorch", function(m, v)
	local bamboo = pick({ rgb(200, 170, 100), rgb(180, 150, 86) }, v)
	solid(Build.cyl(m, "Pole", 6.4, 0.36, CF(0, 3.2, 0), bamboo, M.Wood))
	for _, y in { 1.6, 3.4, 5.0 } do
		Build.cyl(m, "Node", 0.16, 0.44, CF(0, y, 0), Build.darken(bamboo, 0.25), M.Wood)
	end
	Build.cyl(m, "Cup", 0.9, 0.8, CF(0, 6.7, 0), rgb(110, 76, 46), M.Wood)
	local flame = Build.ellipsoid(m, "Flame", V(0.6, 1.1, 0.6), CF(0, 7.6, 0), rgb(255, 150, 40), M.Neon)
	flame.CastShadow = false
	fireEmitter(flame, 0.35)
	local light = Build.glow(flame, rgb(255, 170, 90), 1.6, 12)
	ambient(light, "AmbientNightLight")
end)

----------------------------------------------------------------------------------------------
-- Shoreline
----------------------------------------------------------------------------------------------

local function rockColor(rng: Random): Color3
	local g = 112 + rng:NextInteger(-16, 22)
	return rgb(g, g + 2, g + 10)
end

-- Ring of barnacled rocks around a shallow pool with starfish, urchins and weed (~11 x 9).
add("TidePool", function(m, v)
	local rng = Random.new(v * 977 + 41)
	local pool = Build.cyl(m, "PoolWater", 0.2, 6.6, CF(0, 0.35, 0), WATER, M.SmoothPlastic)
	pool.Transparency = 0.3
	pool.Reflectance = 0.15
	Build.cyl(m, "PoolBed", 0.1, 6.2, CF(0, 0.2, 0), rgb(196, 170, 120), M.Sand)
	local n = 6 + (math.floor(v) % 2)
	for i = 0, n - 1 do
		local a = i / n * PI * 2 + rng:NextNumber(-0.25, 0.25)
		local r = 4.1 + rng:NextNumber(-0.3, 0.6)
		local s = V(2.6, 1.9, 2.2) * rng:NextNumber(0.75, 1.35)
		local cf = CF(math.cos(a) * r, s.Y * 0.32, math.sin(a) * r * 0.85)
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.3), rng:NextNumber(-0.3, 0.3))
		solid(Build.part(m, "Rock", s, cf, rockColor(rng), M.Slate))
		if i % 3 == 0 then
			Build.ellipsoid(m, "Weed", V(s.X * 0.8, 0.35, s.Z * 0.8), cf * CF(0, s.Y / 2, 0), rgb(86, 150, 80), M.Grass)
		end
	end
	local stars = { rgb(255, 140, 60), rgb(255, 90, 120), rgb(170, 100, 255) }
	for i = 1, 2 do
		local c = V(rng:NextNumber(-1.8, 1.8), 0.47, rng:NextNumber(-1.6, 1.6))
		local col = pick(stars, v + i)
		for k = 0, 4 do
			local a = k / 5 * PI * 2
			Build.beam(m, "StarArm", c, c + V(math.cos(a), 0, math.sin(a)) * 0.75, 0.32, 0.12, col, M.SmoothPlastic, Y)
		end
	end
	for i = 1, 2 do
		Build.ball(
			m,
			"Urchin",
			0.8,
			CF(rng:NextNumber(-2, 2), 0.5, rng:NextNumber(-2, 2)),
			if i == 1 then rgb(70, 40, 100) else rgb(30, 30, 50),
			M.CorrodedMetal
		)
	end
	for i = 1, 2 do
		local b = V(rng:NextNumber(-2, 2), 0.3, rng:NextNumber(-2, 2))
		Build.beam(
			m,
			"Kelp",
			b,
			b + V(rng:NextNumber(-0.4, 0.4), 1.3, rng:NextNumber(-0.4, 0.4)),
			0.3,
			0.08,
			rgb(60, 140, 70),
			M.SmoothPlastic,
			X
		)
	end
end)

local HULLS = {
	{ WHITE, CORAL },
	{ rgb(60, 150, 220), WHITE },
	{ rgb(250, 210, 80), rgb(40, 110, 170) },
	{ rgb(60, 180, 160), WHITE },
	{ rgb(236, 90, 70), rgb(255, 236, 200) },
	{ rgb(240, 236, 226), rgb(40, 120, 90) },
}

-- Wooden rowboat (10 long, bow at -Z) with thwarts and a pair of oars.
add("Rowboat", function(m, v)
	local cols = pick(HULLS, v)
	local hull, stripe = cols[1], cols[2]
	local inner = rgb(196, 150, 100)
	solid(Build.part(m, "Bottom", V(2.6, 0.3, 7.6), CF(0, 0.25, 0.6), inner, M.WoodPlanks))
	for sx = -1, 1, 2 do
		local side = CF(sx * 1.55, 0.95, 0.6) * CFrame.Angles(0, 0, sx * -0.22)
		solid(Build.part(m, "Side", V(0.25, 1.5, 7.6), side, hull, M.Wood))
		Build.part(m, "Stripe", V(0.27, 0.35, 7.62), side * CF(0, 0.35, 0), stripe, M.Wood)
		Build.beam(m, "Bow", V(sx * 1.6, 0.95, -3.25), V(0, 1.15, -5.4), 1.5, 0.25, hull, M.Wood, Y)
		Build.beam(m, "Gunwale", V(sx * 1.73, 1.72, -3.2), V(sx * 1.73, 1.72, 4.4), 0.25, 0.3, WOOD_DARK, M.Wood, X)
	end
	Build.part(m, "Keel", V(0.4, 0.5, 2.6), CF(0, 0.35, -4.1) * CFrame.Angles(0.35, 0, 0), stripe, M.Wood)
	Build.part(m, "Transom", V(3.4, 1.5, 0.25), CF(0, 0.95, 4.4), hull, M.Wood)
	for _, z in { -1.6, 1.6 } do
		Build.part(m, "Thwart", V(3.1, 0.2, 0.9), CF(0, 1.3, z), WOOD, M.Wood)
	end
	for sx = -1, 1, 2 do
		Build.cylBetween(m, "Oar", V(sx * 0.7, 1.45, -2.6), V(sx * 0.9, 1.45, 3.4), 0.18, WOOD)
		Build.part(m, "Blade", V(0.12, 0.6, 1.4), CF(sx * 0.92, 1.45, 3.8), stripe, M.Wood)
	end
end)

-- Swim-line float (most variants) or a tall marker buoy (every 4th). Front = -Z.
add("Buoy", function(m, v)
	local iv = math.floor(v)
	if iv % 4 == 0 then
		local col = pick({ CORAL, GOLD }, iv // 4)
		Build.cyl(m, "Float", 1.6, 2.6, CF(0, 0.8, 0), col)
		Build.cyl(m, "Band", 0.5, 2.7, CF(0, 1.2, 0), WHITE)
		Build.spike(m, "Cone", V(0, 1.6, 0), V(0, 4.6, 0), 1.4, col)
		Build.ball(m, "Lamp", 0.5, CF(0, 4.75, 0), rgb(255, 210, 80), M.Neon)
	else
		local col = pick({ CORAL, GOLD, WHITE }, iv)
		Build.ball(m, "Float", 1.3, CF(0, 0.55, 0), col)
		Build.cyl(m, "Band", 0.3, 1.36, CF(0, 0.55, 0), if col == WHITE then CORAL else WHITE)
	end
end)

----------------------------------------------------------------------------------------------
-- Motion: kites and feather flags (the whole model sways about its ground pivot)
----------------------------------------------------------------------------------------------

add("Kite", function(m, v)
	local rng = Random.new(v * 613 + 2)
	local cols = pick({
		{ CORAL, GOLD },
		{ OCEAN, WHITE },
		{ rgb(160, 110, 240), rgb(120, 230, 160) },
		{ GOLD, rgb(255, 120, 190) },
		{ rgb(60, 190, 120), CORAL },
	}, v)
	local h = 26 + rng:NextNumber(0, 10)
	local kite = V(rng:NextNumber(-3, 3), h, -(10 + rng:NextNumber(0, 6)))
	Build.cyl(m, "Stake", 1.2, 0.25, CF(0, 0.6, 0), WOOD_DARK, M.Wood)
	Build.cylBetween(m, "String", V(0, 1.1, 0), kite + V(0, -1.6, 0), 0.06, WHITE)
	local face = Build.orient(kite, Y, X) * CFrame.Angles(-0.5, 0, 0)
	Build.tri(m, "Sail", face * CF(0, 1.2, 0), 3.2, 2.4, 0.08, cols[1], M.Fabric)
	Build.tri(m, "Sail", face * CF(0, -1.6, 0) * CFrame.Angles(0, 0, PI), 3.2, 3.2, 0.08, cols[2], M.Fabric)
	for i = 1, 3 do
		local p = face * CF(math.sin(i) * 0.4, -3.2 - i * 1.1, 0.1 * i)
		Build.part(m, "Tail", V(0.7, 0.3, 0.08), p, if i % 2 == 0 then cols[1] else cols[2], M.Fabric)
	end
	ambient(m, "AmbientSway", { SwayDegrees = 4 + rng:NextNumber(0, 3), SwayPeriod = 5 + rng:NextNumber(0, 3) })
end)

add("BeachFlag", function(m, v)
	local cols = pick({
		{ CORAL, WHITE },
		{ OCEAN, GOLD },
		{ GOLD, CORAL },
		{ rgb(60, 190, 120), WHITE },
		{ rgb(160, 110, 240), GOLD },
	}, v)
	Build.cyl(m, "Base", 0.4, 1.4, CF(0, 0.2, 0), rgb(60, 60, 70))
	Build.cyl(m, "Pole", 11, 0.18, CF(0, 5.5, 0), rgb(220, 220, 226), M.Metal)
	-- feather banner: three panels stepping out, curving over at the top
	Build.part(m, "Banner", V(1.8, 5.4, 0.08), CF(0.95, 5.0, 0), cols[1], M.Fabric)
	Build.part(m, "Banner", V(1.5, 2.4, 0.08), CF(0.9, 8.8, 0) * CFrame.Angles(0, 0, -0.12), cols[1], M.Fabric)
	Build.part(m, "BannerStripe", V(0.4, 7.6, 0.1), CF(0.4, 6.2, 0), cols[2], M.Fabric)
	ambient(m, "AmbientSway", { SwayDegrees = 3, SwayPeriod = 2.6 + (math.floor(v) % 3) * 0.4 })
end)

----------------------------------------------------------------------------------------------
-- Small dressing
----------------------------------------------------------------------------------------------

add("Driftwood", function(m, v)
	local rng = Random.new(v * 151 + 1)
	local col = pick({ rgb(196, 182, 160), rgb(170, 150, 126), rgb(150, 132, 112) }, v)
	local len = 5 + rng:NextNumber(0, 5)
	local mid = V(rng:NextNumber(-0.4, 0.4), 0.45, rng:NextNumber(-0.6, 0.6))
	Build.cylBetween(m, "Log", V(-len / 2, 0.4, 0), mid, 0.8, col, M.Wood)
	Build.cylBetween(m, "Log", mid, V(len / 2, 0.35, rng:NextNumber(-1, 1)), 0.65, col, M.Wood)
	Build.cylBetween(
		m,
		"Branch",
		mid + V(len * 0.2, 0, 0),
		mid + V(len * 0.35, 1.2, -1.2),
		0.3,
		Build.darken(col, 0.08),
		M.Wood
	)
end)

add("DuneGrass", function(m, v)
	local rng = Random.new(v * 37 + 5)
	local cols = { rgb(150, 178, 92), rgb(186, 190, 110), rgb(120, 160, 80) }
	local n = 5 + (math.floor(v) % 2)
	for i = 0, n - 1 do
		local a = i / n * PI * 2 + rng:NextNumber(-0.3, 0.3)
		local base = V(math.cos(a) * 0.3, 0, math.sin(a) * 0.3)
		local tip = base + V(math.cos(a) * 1.0, 2.2 + rng:NextNumber(0, 1.4), math.sin(a) * 1.0)
		Build.beam(m, "Blade", base, tip, 0.22, 0.08, cols[i % 3 + 1], M.SmoothPlastic, V(-math.sin(a), 0, math.cos(a)))
	end
end)

-- Weathered slat sand fence section (12 long along X), slats leaning a little.
add("Fence", function(m, v)
	local rng = Random.new(v * 59 + 11)
	local grey = rgb(186, 170, 146)
	for _, x in { -6, 0, 6 } do
		Build.cyl(
			m,
			"Post",
			4.2,
			0.35,
			CF(x, 2.0, 0) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06)),
			WOOD_DARK,
			M.Wood
		)
	end
	for _, y in { 1.2, 3.0 } do
		Build.part(m, "Wire", V(12, 0.08, 0.08), CF(0, y, 0.12), rgb(90, 86, 80), M.Metal)
	end
	for i = 0, 6 do
		local x = -5.1 + i * 1.7
		local h = 3.2 + rng:NextNumber(-0.4, 0.3)
		Build.part(
			m,
			"Slat",
			V(0.5, h, 0.1),
			CF(x, h / 2, 0.2) * CFrame.Angles(0, 0, rng:NextNumber(-0.08, 0.08)),
			grey,
			M.Wood
		)
	end
end)

add("SurfRack", function(m, v)
	local boards = {
		{ rgb(255, 120, 60), WHITE },
		{ rgb(60, 190, 255), rgb(255, 230, 70) },
		{ rgb(255, 90, 160), WHITE },
		{ rgb(90, 220, 140), rgb(40, 90, 200) },
		{ GOLD, CORAL },
	}
	for _, sx in { -3.4, 3.4 } do
		solid(Build.beam(m, "Frame", V(sx, 0, -1.4), V(sx, 3.4, 0), 0.3, 0.3, WOOD, M.Wood, X))
		solid(Build.beam(m, "Frame", V(sx, 0, 1.4), V(sx, 3.4, 0), 0.3, 0.3, WOOD, M.Wood, X))
	end
	Build.part(m, "Rail", V(7.4, 0.3, 0.3), CF(0, 3.3, 0), WOOD_DARK, M.Wood)
	Build.part(m, "Rail", V(7.4, 0.3, 0.3), CF(0, 0.8, -1.1), WOOD_DARK, M.Wood)
	for i = 0, 4 do
		local c = pick(boards, v + i)
		local cf = CF(-2.6 + i * 1.3, 3.0, -0.3) * CFrame.Angles(0.35, 0, 0.04 * (i - 2))
		Build.ellipsoid(m, "Board", V(1.1, 6.2, 0.25), cf, c[1])
		Build.ellipsoid(m, "BoardStripe", V(0.25, 5.9, 0.28), cf, c[2])
	end
end)

add("ShellPile", function(m, v)
	local rng = Random.new(v * 89 + 4)
	local cols = { rgb(255, 196, 176), rgb(255, 160, 186), rgb(206, 180, 255), rgb(255, 240, 222), rgb(255, 210, 140) }
	for i = 1, 5 do
		local p = V(rng:NextNumber(-1, 1), 0.15 + (if i == 5 then 0.3 else 0), rng:NextNumber(-1, 1))
		Build.ellipsoid(
			m,
			"Shell",
			V(0.9, 0.35, 0.7) * rng:NextNumber(0.8, 1.3),
			CF(p) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), 0),
			pick(cols, v + i)
		)
	end
	Build.spike(m, "Conch", V(0.4, 0.3, 0.6), V(1.3, 0.5, 0.9), 0.7, rgb(255, 214, 190))
end)

add("PicnicBlanket", function(m, v)
	local cols = pick(
		{ { CORAL, WHITE }, { OCEAN, WHITE }, { rgb(80, 190, 110), rgb(255, 246, 214) }, { GOLD, rgb(255, 120, 120) } },
		v
	)
	Build.part(m, "Blanket", V(6, 0.1, 5), CF(0, 0.06, 0), cols[2], M.Fabric)
	for i = -1, 1 do
		Build.part(m, "Check", V(6.02, 0.12, 0.8), CF(0, 0.07, i * 1.6), cols[1], M.Fabric)
		Build.part(m, "Check", V(0.8, 0.13, 5.02), CF(i * 2.0, 0.075, 0), cols[1], M.Fabric)
	end
	local basket = rgb(196, 150, 92)
	Build.part(m, "Basket", V(1.8, 1.0, 1.2), CF(1.6, 0.6, 1.2), basket, M.Wood)
	Build.part(
		m,
		"Lid",
		V(1.9, 0.18, 1.3),
		CF(1.6, 1.15, 1.2) * CFrame.Angles(0, 0.0, 0.06),
		Build.darken(basket, 0.12),
		M.Wood
	)
	Build.part(m, "Handle", V(1.4, 0.14, 0.14), CF(1.6, 1.75, 1.2), WOOD_DARK, M.Wood)
	for i = 0, 1 do
		Build.cyl(m, "Plate", 0.06, 1.1, CF(-1.4 + i * 1.6, 0.16, -1.2), WHITE)
	end
	Build.ball(m, "Melon", 0.9, CF(-1.4, 0.55, -1.2), rgb(80, 170, 80))
	Build.cyl(m, "Bottle", 0.9, 0.35, CF(0.2, 0.55, -0.4), rgb(120, 200, 230), M.Glass)
end)

-- Striped hammock slung between two trees 12 studs apart along X (callers plant the trees at
-- local x = +-6.6).
add("Hammock", function(m, v)
	local cols = pick(FABRIC, v + 3)
	local ends = { V(-6.2, 4.4, 0), V(6.2, 4.4, 0) }
	local mids = { V(-3.6, 2.6, 0), V(0, 2.1, 0), V(3.6, 2.6, 0) }
	Build.cylBetween(m, "Rope", ends[1], mids[1] + V(-1, 0.2, 0), 0.1, ROPE)
	Build.cylBetween(m, "Rope", ends[2], mids[3] + V(1, 0.2, 0), 0.1, ROPE)
	Build.beam(m, "Bed", mids[1] + V(-1.1, 0.25, 0), mids[2], 2.4, 0.12, cols[1], M.Fabric, Z)
	Build.beam(m, "Bed", mids[2], mids[3] + V(1.1, 0.25, 0), 2.4, 0.12, cols[2], M.Fabric, Z)
	Build.ellipsoid(m, "Pillow", V(1.6, 0.5, 1.4), CF(mids[1] + V(-0.6, 0.45, 0)), WHITE, M.Fabric)
end)

----------------------------------------------------------------------------------------------
-- Hero sandcastle (~20 x 18)
----------------------------------------------------------------------------------------------

add("HeroSandcastle", function(m, v)
	local mat = M.Sand
	local light = Build.lighten(SAND, 0.08)
	local dark = Build.darken(SAND, 0.18)
	local moat = Build.cyl(m, "Moat", 0.14, 19, CF(0, 0.1, 0), WATER)
	moat.Transparency = 0.25
	solid(Build.ellipsoid(m, "Mound", V(15, 2.4, 15), CF(0, 0.2, 0), SAND, mat))
	solid(Build.part(m, "Plinth", V(11, 1.2, 11), CF(0, 1.0, 0), light, mat))
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local n = V(d[1], 0, d[2])
		local t = V(-n.Z, 0, n.X)
		local wc = n * 4.9 + V(0, 3.2, 0)
		solid(Build.part(m, "Wall", V(9.6, 3.2, 1.2), CFrame.lookAt(wc, wc + n), SAND, mat))
		for k = -1, 1 do
			local c = wc + t * (k * 3.0) + V(0, 2.0, 0)
			Build.part(m, "Crenel", V(1.1, 0.8, 1.2), CFrame.lookAt(c, c + n), SAND, mat)
		end
	end
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			local c = V(sx * 5.2, 0, sz * 5.2)
			solid(Build.cyl(m, "Tower", 6.4, 3.2, CF(c + V(0, 4.4, 0)), light, mat))
			Build.spike(m, "Spire", c + V(0, 7.5, 0), c + V(0, 10.4, 0), 3.4, dark, mat)
		end
	end
	solid(Build.cyl(m, "Keep", 9, 4.6, CF(0, 6.0, 0.4), light, mat))
	Build.spike(m, "Spire", V(0, 10.4, 0.4), V(0, 14.4, 0.4), 4.8, dark, mat)
	Build.part(m, "Gate", V(2.4, 2.8, 0.2), CF(0, 3.0, -5.55), Build.darken(SAND, 0.35), mat)
	Build.part(m, "Drawbridge", V(2.6, 0.25, 4.4), CF(0, 0.5, -8.2) * CFrame.Angles(0.12, 0, 0), WOOD, M.Wood)
	for side = -1, 1, 2 do
		Build.part(m, "Window", V(0.6, 0.9, 0.1), CF(side * 1.0, 7.6, -1.92), dark, mat)
		Build.ellipsoid(m, "Shell", V(0.7, 0.55, 0.14), CF(side * 2.6, 2.6, -5.56), rgb(255, 170, 180))
	end
	Build.cylBetween(m, "FlagPole", V(0, 14.2, 0.4), V(0, 17.2, 0.4), 0.14, WHITE)
	local flag = swayGroup(m, "Pennant", V(0, 16.8, 0.4), 8, 2.4)
	Build.triPts(flag, "Flag", V(0.05, 16.4, 0.4), V(2.2, 16.4, 0.4), Y, 1.0, 0.06, pick({ CORAL, OCEAN, GOLD }, v))
end)

return PropsBeach
