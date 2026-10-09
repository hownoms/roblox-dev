--!strict
--[[
	Skyline — the far backdrop beyond the headlands, built from parts (Persistent, part of
	CoastalVistas) so it shows from everywhere regardless of terrain streaming:
	  * far sea: a turquoise sea plane to the horizon at the terrain water level (z < -620,
	    |x| > 720) plus a low plane hidden under the seabed that fills the gap where the terrain
	    ocean has streamed out on a client;
	  * land plane, rolling hills, jungle treeline and hazy mountains to the north, coast hills
	    east and west;
	  * islands at several distances (palms, rocks, a smoking volcano);
	  * sky life for the client ambient controller: gulls (AmbientOrbit), sailboats and a
	    banner plane (AmbientDrift).
	Own Random (never the shared World rng). Everything anchored, no collide / query / touch.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Models.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)
local Util = require(script.Parent.Util)

local Skyline = {}

local V, CF = Vector3.new, CFrame.new
local rgb = Color3.fromRGB
local S = Layout.SURFACE_Y
local SEA_Y = Layout.WATER_Y - 0.5 -- far-sea plane top (terrain water surface is WATER_Y)
local LOW_SEA_Y = Layout.SEABED_Y + 1 -- 1005: just under the seabed sand top (1008)
local LAND_Y = S - 2.5 -- land plane top, inside the terrain slab where terrain exists

local SEA = rgb(38, 158, 190)
local SHALLOW = rgb(92, 214, 214)
local SAND = rgb(240, 214, 160)
local GRASS = rgb(98, 186, 84)
local GRASS_DARK = rgb(70, 150, 72)
local JUNGLE = rgb(46, 122, 60)
local ROCK = rgb(108, 110, 122)
local TRUNK = rgb(150, 112, 76)
local FROND = rgb(62, 164, 72)
local FROND_DARK = rgb(44, 134, 60)
local WHITE = rgb(250, 246, 236)
local NAVY = rgb(31, 55, 73)
local CORAL = Config.Theme.Colors.Coral

local function tag(inst: Instance, name: string)
	CollectionService:AddTag(inst, name)
end

local function slab(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Build.part(parent, name, size, cf, color, material)
	p.CastShadow = false
	return p
end

local function blob(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shadow: boolean?
): Part
	local p = Build.ellipsoid(parent, name, size, cf, color, material)
	p.CastShadow = shadow == true
	return p
end

-- Y of the top surface of an axis-aligned ellipsoid (centre c, full size s) at (x, z).
local function ellipsoidTop(c: Vector3, s: Vector3, x: number, z: number): number
	local u = ((x - c.X) / (s.X / 2)) ^ 2 + ((z - c.Z) / (s.Z / 2)) ^ 2
	return c.Y + s.Y / 2 * math.sqrt(math.max(0, 1 - u))
end

-- Palm: curved 3-piece trunk, coconut crown, 6 drooping fronds (10 parts). `base` = ground.
function Skyline.Palm(parent: Instance, base: Vector3, height: number, yaw: number, rng: Random): Model
	local m = Util.Model("BackdropPalm", parent)
	local s = height / 24
	local lean = CFrame.Angles(0, yaw, 0).LookVector * height * rng:NextNumber(0.12, 0.28)
	local top = base + V(0, height, 0) + lean
	local ctrl = base + V(0, height * 0.55, 0)
	local prev = base - V(0, 1, 0)
	for k = 1, 3 do
		local t = k / 3
		local p = base:Lerp(ctrl, t):Lerp(ctrl:Lerp(top, t), t) -- quadratic bezier
		local seg = Build.cylBetween(m, "Trunk", prev, p, (2.1 - k * 0.3) * s, TRUNK:Lerp(rgb(120, 86, 58), k * 0.2))
		seg.CastShadow = false
		prev = p
	end
	local crown = Build.ball(m, "Coconuts", 2.6 * s, CF(top - V(0, 0.6 * s, 0)), rgb(112, 76, 44))
	crown.CastShadow = false
	for k = 0, 5 do
		local a = yaw + k * math.pi / 3 + rng:NextNumber(-0.25, 0.25)
		local len = rng:NextNumber(9, 12) * s
		local droop = rng:NextNumber(0.35, 0.65)
		local dir = V(math.cos(a), 0, math.sin(a))
		local tip = top + dir * len * math.cos(droop) - V(0, len * math.sin(droop), 0)
		local f = Build.beam(
			m,
			"Frond",
			top,
			tip,
			2.8 * s,
			0.35 * s,
			if k % 2 == 0 then FROND else FROND_DARK,
			nil,
			dir:Cross(Vector3.yAxis)
		)
		f.CastShadow = false
	end
	return m
end

-- Far sea, low sea and land planes (big tiles; parts max 2048 per axis).
local function buildPlanes(parent: Instance)
	local m = Util.Model("FarSea", parent)
	local function tile(
		name: string,
		x0: number,
		x1: number,
		z0: number,
		z1: number,
		top: number,
		color: Color3,
		thick: number,
		material: Enum.Material?
	)
		local p = slab(
			m,
			name,
			V(x1 - x0, thick, z1 - z0),
			CF((x0 + x1) / 2, top - thick / 2, (z0 + z1) / 2),
			color,
			material
		)
		if name ~= "Land" then
			p.Reflectance = 0.18
		end
	end
	-- Sea to the horizon. Thick so its edge at z -620 reads as water, not a seam.
	for _, zr in { { -2668, -620 }, { -4096, -2668 } } do
		for x = -4096, 2048, 2048 do
			tile("FarSea", x, x + 2048, zr[1], zr[2], SEA_Y, SEA, 16)
		end
	end
	tile("FarSea", 720, 2768, -620, 150, SEA_Y, SEA, 16)
	tile("FarSea", -2768, -720, -620, 150, SEA_Y, SEA, 16)
	-- Hidden under the seabed where the terrain ocean exists; shows where it has streamed out.
	tile("LowSea", -720, 720, -620, -140, LOW_SEA_Y, SEA, 2)
	for x = -3000, 1000, 2000 do
		tile("Land", x, x + 2000, 150, 2198, LAND_Y, GRASS_DARK, 12, Enum.Material.Grass)
	end
end

type IslandSpec = {
	Name: string,
	At: Vector3, -- centre on the sea plane
	Size: Vector3, -- sand footprint (X, height, Z)
	Hill: number, -- grass hill height
	Palms: number,
	PalmHeight: number,
	Rocks: number,
	Yaw: number,
}

local function buildIsland(parent: Instance, spec: IslandSpec, rng: Random)
	local m = Util.Model(spec.Name, parent)
	local c = spec.At
	local yaw = CFrame.Angles(0, spec.Yaw, 0)
	local sz = spec.Size
	blob(m, "Shallows", V(sz.X * 1.55, 1.2, sz.Z * 1.6), CF(c + V(0, 0.2, 0)) * yaw, SHALLOW)
	blob(m, "Sand", V(sz.X, sz.Y * 2, sz.Z), CF(c) * yaw, SAND, Enum.Material.Sand)
	local hillSize = V(sz.X * 0.62, spec.Hill * 2, sz.Z * 0.58)
	local hillC = c + yaw:VectorToWorldSpace(V(sz.X * 0.06, sz.Y * 0.4, sz.Z * 0.04))
	blob(m, "Hill", hillSize, CF(hillC) * yaw, GRASS, Enum.Material.Grass)
	if spec.Hill > 20 then
		local sub = V(hillSize.X * 0.5, hillSize.Y * 1.3, hillSize.Z * 0.55)
		blob(
			m,
			"Peak",
			sub,
			CF(hillC + yaw:VectorToWorldSpace(V(-hillSize.X * 0.12, 0, 0))) * yaw,
			GRASS_DARK,
			Enum.Material.Grass
		)
	end
	for k = 1, spec.Rocks do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = c + V(math.cos(a) * sz.X * 0.42, 0, math.sin(a) * sz.Z * 0.4)
		local r = rng:NextNumber(0.08, 0.14) * sz.X
		blob(
			m,
			"Rock",
			V(r * 1.3, r * 1.1, r),
			CF(p) * CFrame.Angles(0, a, 0.2),
			ROCK:Lerp(SAND, k % 2 * 0.15),
			Enum.Material.Slate
		)
	end
	-- Palms on the grass (local frame of the island; heights follow the hill surface).
	local hillLocal = Vector3.zero
	for k = 1, spec.Palms do
		local a = (k / spec.Palms) * math.pi * 2 + rng:NextNumber(-0.5, 0.5)
		local rr = rng:NextNumber(0.15, 0.45)
		local lx, lz = math.cos(a) * hillSize.X / 2 * rr, math.sin(a) * hillSize.Z / 2 * rr
		local y = ellipsoidTop(hillLocal, hillSize, lx, lz)
		local world = hillC + yaw:VectorToWorldSpace(V(lx, 0, lz)) + V(0, y - 2, 0)
		Skyline.Palm(m, world, spec.PalmHeight * rng:NextNumber(0.85, 1.2), a + rng:NextNumber(-0.6, 0.6), rng)
	end
end

local function buildVolcano(parent: Instance)
	local m = Util.Model("Volcano", parent)
	local c = V(-600, SEA_Y, -1560)
	local basalt = rgb(98, 86, 84)
	blob(m, "Shallows", V(820, 1.2, 700), CF(c + V(0, 0.2, 0)), SHALLOW)
	blob(m, "JungleSkirt", V(720, 70, 600), CF(c), JUNGLE, Enum.Material.Grass)
	blob(m, "Beach", V(760, 24, 640), CF(c - V(0, 4, 0)), SAND, Enum.Material.Sand)
	-- Stacked ellipsoid tiers: green lower slopes, bare basalt cone (size, lift, colour).
	local tiers: { { Size: Vector3, Lift: number, Color: Color3 } } = {
		{ Size = V(560, 130, 470), Lift = 0, Color = basalt:Lerp(JUNGLE, 0.45) },
		{ Size = V(420, 220, 350), Lift = 18, Color = basalt:Lerp(JUNGLE, 0.2) },
		{ Size = V(290, 290, 240), Lift = 46, Color = basalt },
		{ Size = V(180, 320, 150), Lift = 74, Color = basalt:Lerp(rgb(70, 62, 64), 0.5) },
	}
	for i, t in tiers do
		blob(m, "Slope" .. i, t.Size, CF(c + V(i * 4, t.Lift, -i * 3)), t.Color, Enum.Material.Basalt)
	end
	local rimY = c.Y + 74 + 160 - 6
	Build.cyl(m, "CraterRim", 14, 112, CF(c.X + 16, rimY, c.Z - 12), rgb(70, 62, 64), Enum.Material.Basalt).CastShadow =
		false
	local glow =
		Build.cyl(m, "CraterGlow", 2, 84, CF(c.X + 16, rimY + 6.2, c.Z - 12), rgb(255, 110, 40), Enum.Material.Neon)
	glow.CastShadow = false
	-- One lazy smoke plume (big soft particles; reads at 1.6k studs as a wisp).
	local vent = slab(m, "SmokeVent", V(20, 1, 20), CF(c.X + 16, rimY + 8, c.Z - 12), WHITE)
	vent.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Name = "VolcanoSmoke"
	e.Color = ColorSequence.new(rgb(236, 232, 228), rgb(196, 192, 196))
	e.LightEmission = 0
	e.LightInfluence = 1
	e.Rate = 0.8
	e.Lifetime = NumberRange.new(22, 30)
	e.Speed = NumberRange.new(5, 8)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Acceleration = V(3, 0.4, 0)
	e.Drag = 0.15
	e.RotSpeed = NumberRange.new(-8, 8)
	e.Rotation = NumberRange.new(0, 360)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 40),
		NumberSequenceKeypoint.new(1, 140),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.6, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Parent = vent
end

-- North hills, jungle treeline and hazy mountains; coast hills east and west.
local function buildHinterland(parent: Instance, rng: Random)
	local m = Util.Model("Hinterland", parent)
	local greens = { GRASS, GRASS_DARK, rgb(112, 196, 92), rgb(84, 168, 80) }
	-- Near hills (just beyond the terrain's north edge, z 340) with trees along the crests.
	local x = -980
	while x < 980 do
		local w = rng:NextNumber(150, 250)
		local h = rng:NextNumber(46, 96) * (1 + math.abs(x) / 1400)
		local cpos = V(x + w / 2 + rng:NextNumber(-20, 20), LAND_Y - 6, rng:NextNumber(390, 470))
		local size = V(w * 1.15, h * 2, rng:NextNumber(140, 220))
		blob(
			m,
			"Hill",
			size,
			CF(cpos) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0),
			greens[rng:NextInteger(1, #greens)],
			Enum.Material.Grass
		)
		for _ = 1, 3 do
			local tx = cpos.X + rng:NextNumber(-0.32, 0.32) * size.X
			local tz = cpos.Z + rng:NextNumber(-0.3, 0.1) * size.Z
			local ty = ellipsoidTop(cpos, size, tx, tz)
			local cs = rng:NextNumber(26, 40)
			blob(
				m,
				"Canopy",
				V(cs, cs * 0.75, cs * rng:NextNumber(0.8, 1.1)),
				CF(tx, ty + cs * 0.22, tz),
				JUNGLE:Lerp(GRASS_DARK, rng:NextNumber(0, 0.4)),
				Enum.Material.Grass
			)
		end
		x += w * rng:NextNumber(0.7, 0.9)
	end
	-- A few palm silhouettes poking above the treeline behind the hub.
	for _, px in { -250, -96, 70, 210, 330 } do
		local pz = rng:NextNumber(360, 380)
		Skyline.Palm(
			m,
			V(px + rng:NextNumber(-20, 20), LAND_Y - 1, pz),
			rng:NextNumber(30, 40),
			rng:NextNumber(0, 6.28),
			rng
		)
	end
	-- Mid hills.
	for k = 0, 6 do
		local mx = -1500 + k * 500 + rng:NextNumber(-80, 80)
		local w = rng:NextNumber(380, 560)
		blob(
			m,
			"FarHill",
			V(w, rng:NextNumber(220, 360), rng:NextNumber(260, 380)),
			CF(mx, LAND_Y - 10, rng:NextNumber(720, 900)),
			rgb(74, 146, 84):Lerp(rgb(96, 150, 120), rng:NextNumber(0, 0.4)),
			Enum.Material.Grass
		)
	end
	-- Hazy mountains (the atmosphere turns them blue-grey).
	for k = 0, 4 do
		local mx = -1800 + k * 900 + rng:NextNumber(-150, 150)
		local w = rng:NextNumber(700, 1000)
		local h = rng:NextNumber(520, 820)
		local pos = V(mx, LAND_Y - 20, rng:NextNumber(1500, 1800))
		blob(m, "Mountain", V(w, h, w * 0.7), CF(pos), rgb(104, 132, 140), Enum.Material.Rock)
		blob(
			m,
			"Summit",
			V(w * 0.45, h * 1.18, w * 0.35),
			CF(pos + V(w * 0.08, 0, -w * 0.05)),
			rgb(118, 142, 150),
			Enum.Material.Rock
		)
	end
	-- Coast hills beyond the headlands, straddling the sea / land seam at z 150.
	for _, side in { -1, 1 } do
		local cx = 760
		while cx < 1900 do
			local w = rng:NextNumber(220, 380)
			local h = rng:NextNumber(70, 150)
			local pos = V(side * (cx + w / 2), SEA_Y - 10, rng:NextNumber(140, 260))
			local rocky = rng:NextNumber() < 0.3
			blob(
				m,
				if rocky then "CoastCliff" else "CoastHill",
				V(w, h * 2, rng:NextNumber(240, 340)),
				CF(pos) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0),
				if rocky then rgb(196, 182, 156) else greens[rng:NextInteger(1, #greens)],
				if rocky then Enum.Material.Limestone else Enum.Material.Grass
			)
			cx += w * 0.75
		end
	end
end

-- Sky life ----------------------------------------------------------------------------------

local function gull(parent: Instance, center: Vector3, radius: number, seconds: number, bob: number, phase: number)
	local m = Util.Model("Seagull", parent)
	local start = center + V(math.cos(phase) * radius, 0, math.sin(phase) * radius)
	-- Facing travel (counter-clockwise tangent) at the start.
	local tangent = V(-math.sin(phase), 0, math.cos(phase))
	local cf = CFrame.lookAt(start, start + tangent)
	local body = blob(m, "Body", V(1.5, 1.3, 4), cf, WHITE)
	m.PrimaryPart = body
	blob(m, "Head", V(1.2, 1.2, 1.3), cf * CF(0, 0.35, -2.2), WHITE)
	slab(m, "Beak", V(0.35, 0.3, 0.9), cf * CF(0, 0.25, -3.1), rgb(250, 176, 60))
	for _, sx in { -1, 1 } do
		local inner = cf * CF(sx * 3.4, 0.6, 0) * CFrame.Angles(0, 0, sx * math.rad(16))
		slab(m, "Wing", V(6.4, 0.3, 2.3), inner, rgb(236, 236, 240))
		slab(
			m,
			"WingTip",
			V(3.2, 0.25, 1.7),
			inner * CF(sx * 4.4, 0, 0.2) * CFrame.Angles(0, 0, -sx * math.rad(22)) * CF(sx * 0.4, -0.4, 0),
			rgb(70, 74, 84)
		)
	end
	m:SetAttribute("OrbitCenter", center)
	m:SetAttribute("OrbitRadius", radius)
	m:SetAttribute("OrbitSeconds", seconds)
	m:SetAttribute("OrbitBob", bob)
	tag(m, "AmbientOrbit")
end

local function sailboat(
	parent: Instance,
	from: Vector3,
	to: Vector3,
	seconds: number,
	sailColor: Color3,
	hullColor: Color3
)
	local m = Util.Model("Sailboat", parent)
	-- Built at the origin facing -Z, then moved to `from` facing `to`.
	local root = slab(m, "Root", V(1, 1, 1), CF(), WHITE)
	root.Transparency = 1
	m.PrimaryPart = root
	slab(m, "Hull", V(9, 4.5, 30), CF(0, 1.2, 2), hullColor)
	Build.tri(m, "Bow", CFrame.fromMatrix(V(0, 1.2, -16.5), Vector3.xAxis, -Vector3.zAxis), 9, 7, 4.5, hullColor)
	slab(m, "Stripe", V(9.2, 0.9, 30.2), CF(0, 2.2, 2), NAVY)
	slab(m, "Deck", V(8, 0.4, 28), CF(0, 3.6, 2), rgb(176, 122, 76))
	Build.cyl(m, "Mast", 40, 0.9, CF(0, 23.5, -3), WHITE).CastShadow = false
	local sailCF = CFrame.fromMatrix(V(0, 22, 7), Vector3.zAxis, Vector3.yAxis)
	Build.tri(m, "Sail", sailCF, 19, 34, 0.4, sailColor)
	Build.tri(m, "Jib", CFrame.fromMatrix(V(0, 17, -10), Vector3.zAxis, Vector3.yAxis), 12, 24, 0.4, CORAL)
	slab(m, "Pennant", V(0.2, 1.6, 4), CF(0, 43, -1), CORAL)
	m:PivotTo(CFrame.lookAt(from, V(to.X, from.Y, to.Z)))
	m:SetAttribute("DriftFrom", from)
	m:SetAttribute("DriftTo", to)
	m:SetAttribute("DriftSeconds", seconds)
	tag(m, "AmbientDrift")
end

local function bannerPlane(parent: Instance, from: Vector3, to: Vector3, seconds: number)
	local m = Util.Model("BannerPlane", parent)
	local gold = Config.Theme.Colors.Gold
	local root = slab(m, "Root", V(1, 1, 1), CF(), WHITE)
	root.Transparency = 1
	m.PrimaryPart = root
	slab(m, "Fuselage", V(3.2, 3.2, 13), CF(0, 0, 0), gold)
	blob(m, "Nose", V(3.2, 3.2, 3.4), CF(0, 0, -6.4), gold)
	slab(m, "Cockpit", V(2.4, 1.6, 3.4), CF(0, 2.2, -2), rgb(150, 210, 235), Enum.Material.Glass)
	slab(m, "Wing", V(24, 0.6, 3.8), CF(0, 0.6, -1.5), WHITE)
	slab(m, "Fin", V(0.5, 4.2, 3.2), CF(0, 3, 5.6), CORAL)
	slab(m, "Tailplane", V(8.5, 0.4, 2.4), CF(0, 0.6, 5.8), WHITE)
	local prop = Build.cyl(m, "Propeller", 0.3, 5.6, CF(0, 0, -8.3) * CFrame.Angles(math.pi / 2, 0, 0), rgb(60, 60, 70))
	prop.Transparency = 0.5
	prop.CastShadow = false
	slab(m, "TowRope", V(0.25, 0.25, 22), CF(0, -0.8, 17.5), rgb(80, 70, 60))
	slab(m, "BannerPole", V(0.6, 11, 0.6), CF(0, -1.2, 28.8), NAVY)
	local banner = slab(m, "Banner", V(0.3, 10, 62), CF(0, -1.2, 60), WHITE, Enum.Material.Fabric)
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "BannerGui"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 10
		gui.LightInfluence = 0.4
		gui.MaxDistance = 1600
		gui.Parent = banner
		Util.Label(gui, "DIG TO THE CORE!", CORAL, UDim2.fromScale(0.03, 0.08), UDim2.fromScale(0.94, 0.84))
	end
	m:PivotTo(CFrame.lookAt(from, V(to.X, from.Y, to.Z)))
	m:SetAttribute("DriftFrom", from)
	m:SetAttribute("DriftTo", to)
	m:SetAttribute("DriftSeconds", seconds)
	tag(m, "AmbientDrift")
end

local function buildSkyLife(parent: Instance)
	local m = Util.Model("SkyLife", parent)
	-- Gulls: over the pier, both beaches, the hub, the lighthouse and the arch.
	gull(m, V(36, S + 72, -128), 46, 22, 3, 0.4)
	gull(m, V(-210, S + 58, -112), 58, 26, 4, 2.1)
	gull(m, V(-196, S + 64, -126), 40, 19, 3, 4.4)
	gull(m, V(232, S + 66, -116), 52, 24, 4, 1.2)
	gull(m, V(40, S + 84, 64), 64, 30, 5, 3.3)
	gull(m, V(330, S + 118, -430), 36, 18, 3, 5.0)
	gull(m, V(-292, S + 92, -500), 44, 21, 4, 0.9)
	-- Horizon sailboats (sea plane level) and the banner plane over the swim line.
	sailboat(m, V(-1500, SEA_Y, -880), V(1500, SEA_Y, -880), 260, WHITE, WHITE)
	sailboat(m, V(1600, SEA_Y, -1260), V(-1600, SEA_Y, -1260), 340, rgb(255, 236, 196), rgb(40, 110, 170))
	bannerPlane(m, V(-1150, S + 104, -262), V(1150, S + 104, -262), 110)
end

function Skyline.Build(parent: Instance)
	local rng = Random.new(90417)
	buildPlanes(parent)
	local islands = Util.Model("Islands", parent)
	local specs: { IslandSpec } = {
		{
			Name = "PalmKey",
			At = V(-150, SEA_Y, -780),
			Size = V(150, 7, 96),
			Hill = 12,
			Palms = 4,
			PalmHeight = 34,
			Rocks = 2,
			Yaw = 0.3,
		},
		{
			Name = "Sandbar",
			At = V(150, SEA_Y, -1000),
			Size = V(110, 5, 54),
			Hill = 6,
			Palms = 2,
			PalmHeight = 38,
			Rocks = 1,
			Yaw = -0.2,
		},
		{
			Name = "TwinIsle",
			At = V(360, SEA_Y, -1220),
			Size = V(300, 10, 170),
			Hill = 42,
			Palms = 4,
			PalmHeight = 46,
			Rocks = 3,
			Yaw = 0.15,
		},
		{
			Name = "LongReef",
			At = V(860, SEA_Y, -1560),
			Size = V(420, 8, 140),
			Hill = 26,
			Palms = 2,
			PalmHeight = 52,
			Rocks = 2,
			Yaw = -0.35,
		},
		{
			Name = "FarKey",
			At = V(-1240, SEA_Y, -1180),
			Size = V(260, 8, 130),
			Hill = 30,
			Palms = 2,
			PalmHeight = 50,
			Rocks = 2,
			Yaw = 0.5,
		},
	}
	for _, spec in specs do
		buildIsland(islands, spec, rng)
	end
	buildVolcano(parent)
	buildHinterland(parent, rng)
	buildSkyLife(parent)
end

return Skyline
