--!strict
--[[
	Props — beach scenery at real scale (avatar ~5 studs tall).
	PrimaryPart = invisible "Root" at the bottom-centre (pivot). FRONT faces -Z (towers look
	out along -Z, stall / shack counters open towards -Z, sign text is on the -Z face).
	Main bodies players should stand on / bump into have CanCollide = true; small details don't.
	Optional `variant` (number) picks colours / shape jitter deterministically.
	Signs carry a SurfaceGui whose TextLabel is named "Label" on a part named "SignBoard".
	Names are matched case-, space-, '_' and '-' insensitively ("Lifeguard Tower" works).
]]

local Types = require(script.Parent.Parent.Types)
local Build = require(script.Parent.Build)
local Pets = require(script.Parent.Pets)

local Props = {}

local V = Vector3.new
local CF = CFrame.new
local X = Vector3.xAxis
local Y = Vector3.yAxis
local Z = Vector3.zAxis
local rgb = Color3.fromRGB
local PI = math.pi

local WHITE = rgb(255, 255, 255)
local SAND = rgb(255, 222, 140)
local WOOD = rgb(176, 120, 72)
local WOOD_DARK = rgb(130, 85, 50)
local GOLD = rgb(255, 205, 40)
local M = Enum.Material

local solid = Build.solid

local function pick<T>(list: { T }, variant: number): T
	return list[(math.floor(variant) - 1) % #list + 1]
end

type PropBuilder = (m: Model, v: number) -> ()

local builders: { [string]: PropBuilder } = {}

builders.PalmTree = function(m, v)
	local rng = Random.new(v * 7919 + 13)
	local lean = rng:NextNumber() * PI * 2
	local lx, lz = math.cos(lean), math.sin(lean)
	local H = 10.5 + rng:NextNumber() * 1.5
	local function at(t: number): Vector3
		local b = 2.0 * t * t
		return V(lx * b, t * H, lz * b)
	end
	local barkA, barkB = rgb(170, 120, 75), rgb(140, 95, 58)
	local segs = 6
	for i = 0, segs - 1 do
		local a, b = at(i / segs), at((i + 1) / segs)
		solid(
			Build.cylBetween(
				m,
				"Trunk",
				a,
				b + (b - a).Unit * 0.15,
				1.15 - 0.07 * i,
				if i % 2 == 0 then barkA else barkB,
				M.Wood
			)
		)
	end
	local top = at(1)
	Build.ball(m, "Crown", 1.3, CF(top), rgb(60, 150, 70))
	for k = 0, 2 do
		local a = k / 3 * PI * 2 + 0.4
		Build.ball(m, "Coconut", 0.7, CF(top + V(math.cos(a) * 0.55, -0.55, math.sin(a) * 0.55)), rgb(120, 80, 45))
	end
	local greens = { rgb(70, 200, 100), rgb(50, 170, 80), rgb(90, 215, 110) }
	local fronds = 7
	local offset = rng:NextNumber() * PI
	for k = 0, fronds - 1 do
		local a = k / fronds * PI * 2 + offset
		local h = V(math.cos(a), 0, math.sin(a))
		local perp = V(-h.Z, 0, h.X)
		local mid = top + h * 2.2 + V(0, 0.55, 0)
		local tip = top + h * 4.8 + V(0, -1.5, 0)
		local col = greens[k % #greens + 1]
		Build.beam(m, "Frond", top, mid, 1.1, 0.14, col, M.SmoothPlastic, perp)
		Build.triPts(m, "Frond", mid, tip, perp, 1.1, 0.14, col)
	end
end

builders.Umbrella = function(m, v)
	local pairs_ = {
		{ rgb(255, 80, 90), WHITE },
		{ rgb(40, 170, 255), rgb(255, 230, 70) },
		{ rgb(255, 150, 40), WHITE },
		{ rgb(90, 210, 120), rgb(255, 245, 200) },
		{ rgb(170, 100, 255), rgb(255, 200, 230) },
	}
	local cols = pick(pairs_, v)
	local tilt = CFrame.Angles(0.06, 0, 0.04 * ((v % 3) - 1))
	Build.ellipsoid(m, "Mound", V(1.4, 0.45, 1.4), CF(), SAND, M.Sand)
	solid(Build.cylBetween(m, "Pole", V(0, 0, 0), (tilt * CF(0, 7.3, 0)).Position, 0.25, rgb(235, 235, 240)))
	local apex = (tilt * CF(0, 7.45, 0)).Position
	local R = 3.8
	local n = 8
	for k = 0, n - 1 do
		local a = (k + 0.5) / n * PI * 2
		local base = (tilt * CF(R * math.cos(PI / n) * math.cos(a), 6.1, R * math.cos(PI / n) * math.sin(a))).Position
		local tangent = tilt:VectorToWorldSpace(V(-math.sin(a), 0, math.cos(a)))
		Build.triPts(m, "Canopy", base, apex, tangent, 2 * R * math.sin(PI / n) + 0.05, 0.1, cols[k % 2 + 1])
	end
	Build.ball(m, "Finial", 0.4, CF(apex + V(0, 0.1, 0)), cols[1])
end

builders.BeachTowel = function(m, v)
	local cols = pick({
		{ rgb(255, 90, 120), WHITE },
		{ rgb(60, 170, 255), rgb(255, 230, 80) },
		{ rgb(90, 210, 120), rgb(255, 250, 240) },
		{ rgb(255, 160, 50), rgb(140, 90, 230) },
	}, v)
	Build.part(m, "Towel", V(3, 0.1, 5.6), CF(0, 0.14, 0), cols[1], M.Fabric)
	for _, z in { -1.6, 0, 1.6 } do
		Build.part(m, "Stripe", V(2.98, 0.025, 0.5), CF(0, 0.205, z), cols[2], M.Fabric)
	end
	Build.cylBetween(m, "Pillow", V(-1.3, 0.3, -2.45), V(1.3, 0.3, -2.45), 0.6, cols[2], M.Fabric)
end

builders.Sandcastle = function(m, v)
	local mat = M.Sand
	local dark = Build.darken(SAND, 0.12)
	solid(Build.part(m, "Base", V(6, 1.4, 6), CF(0, 0.7, 0), SAND, mat))
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			local c = V(sx * 2.6, 0, sz * 2.6)
			solid(Build.cyl(m, "Tower", 3.2, 1.7, CF(c + V(0, 1.6, 0)), SAND, mat))
			for k = 0, 3 do
				local a = (k + 0.5) / 4 * PI * 2
				Build.part(
					m,
					"Crenel",
					V(0.45, 0.45, 0.45),
					CF(c + V(math.cos(a) * 0.6, 3.42, math.sin(a) * 0.6)),
					SAND,
					mat
				)
			end
		end
	end
	local keep = V(0, 0, 0.4)
	solid(Build.cyl(m, "Keep", 4.6, 2.6, CF(keep + V(0, 2.3, 0)), SAND, mat))
	for k = 0, 5 do
		local a = k / 6 * PI * 2
		Build.part(m, "Crenel", V(0.5, 0.5, 0.5), CF(keep + V(math.cos(a) * 1.05, 4.85, math.sin(a) * 1.05)), SAND, mat)
	end
	Build.part(m, "Door", V(1.1, 1.1, 0.1), CF(0, 0.55, -3.02), dark, mat)
	for side = -1, 1, 2 do
		Build.part(m, "Window", V(0.35, 0.5, 0.1), CF(side * 0.5, 3.2, -0.82), dark, mat)
		Build.ellipsoid(m, "Shell", V(0.45, 0.38, 0.12), CF(side * 1.8, 0.8, -3.03), rgb(255, 170, 180))
	end
	local flag = pick({ rgb(255, 70, 80), rgb(60, 160, 255), rgb(255, 200, 40), rgb(90, 210, 120) }, v)
	Build.cylBetween(m, "FlagPole", V(0, 4.6, 0.4), V(0, 6.5, 0.4), 0.1, WHITE)
	Build.triPts(m, "Flag", V(0.05, 6.05, 0.4), V(1.0, 6.05, 0.4), Y, 0.7, 0.05, flag)
end

builders.Crab = function(m, v)
	local col = pick({ rgb(255, 110, 80), rgb(255, 80, 60), rgb(255, 150, 70), rgb(230, 70, 110) }, v)
	local look: Types.PetLook = {
		BodyColor = col,
		AccentColor = Build.lighten(col, 0.55),
		Shape = "Crab",
		Size = 0.8,
		Glow = false,
	}
	local crab = Pets.FromLook("Crab", look)
	for _, d in crab:GetChildren() do
		if d.Name ~= "Root" then
			d.Parent = m
		end
	end
	crab:Destroy()
	for _, d in m:GetDescendants() do
		if d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
end

local function trussPart(m: Model, size: Vector3, cf: CFrame, color: Color3): TrussPart
	local t = Instance.new("TrussPart")
	t.Name = "Ladder"
	t.Anchored = true
	t.Size = size
	t.CFrame = cf
	t.Color = color
	t.Material = M.SmoothPlastic
	t.Parent = m
	return t
end

builders.LifeguardTower = function(m, v)
	local wall = pick({ rgb(235, 55, 55), rgb(40, 150, 240), rgb(255, 190, 40) }, v)
	local wood = M.Wood
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			solid(
				Build.beam(m, "Leg", V(sx * 2.0, 0, sz * 2.0), V(sx * 1.75, 6.1, sz * 1.75), 0.4, 0.4, WHITE, wood, X)
			)
		end
		Build.beam(m, "Brace", V(sx * 1.95, 0.6, -1.95), V(sx * 1.8, 5.5, 1.8), 0.22, 0.22, WHITE, wood, Z)
	end
	Build.beam(m, "Brace", V(-1.95, 0.6, 1.95), V(1.8, 5.5, 1.8), 0.22, 0.22, WHITE, wood, X)
	solid(Build.part(m, "Platform", V(4.8, 0.4, 4.8), CF(0, 6.2, 0), WOOD, wood))
	solid(Build.part(m, "BackWall", V(4.4, 3.2, 0.3), CF(0, 8.0, 2.2), wall, wood))
	for side = -1, 1, 2 do
		solid(Build.part(m, "SideWall", V(0.3, 3.2, 2.0), CF(side * 2.2, 8.0, 1.2), wall, wood))
		solid(Build.part(m, "Pillar", V(0.3, 3.2, 0.3), CF(side * 2.2, 8.0, -2.2), WHITE, wood))
		solid(Build.part(m, "Railing", V(1.4, 1.1, 0.2), CF(side * 1.5, 6.95, -2.3), WHITE, wood))
	end
	local roofA, roofB = Build.tri(m, "Roof", CF(0, 10.25, 0) * CFrame.Angles(0, PI / 2, 0), 5.6, 1.3, 5.6, wall, wood)
	solid(roofA)
	solid(roofB)
	Build.part(m, "Eaves", V(5.4, 0.2, 5.6), CF(0, 9.6, 0), WHITE, wood)
	solid(trussPart(m, V(2, 6, 2), CF(0, 3.0, -3.1), WHITE))
	local sign = Build.part(m, "SignBoard", V(3.0, 0.7, 0.15), CF(0, 9.25, -2.35), WHITE)
	Build.label(sign, Enum.NormalId.Front, "LIFEGUARD", rgb(235, 55, 55), WHITE)
	Build.cylBetween(m, "Buoy", V(2.36, 7.8, 1.2), V(2.52, 7.8, 1.2), 1.1, rgb(255, 120, 40))
	Build.cylBetween(m, "BuoyHole", V(2.34, 7.8, 1.2), V(2.54, 7.8, 1.2), 0.5, Build.darken(wall, 0.3))
	Build.cylBetween(m, "FlagPole", V(0, 10.85, 0), V(0, 12.7, 0), 0.12, WHITE)
	Build.triPts(m, "Flag", V(0.05, 12.25, 0), V(1.2, 12.25, 0), Y, 0.8, 0.06, wall)
end

builders.BoardwalkStall = function(m, v)
	local cols = pick({
		{ rgb(255, 80, 100), WHITE },
		{ rgb(40, 170, 255), WHITE },
		{ rgb(255, 170, 40), rgb(255, 250, 220) },
		{ rgb(90, 200, 120), rgb(255, 250, 220) },
	}, v)
	local text = pick({ "SNACKS", "ICE CREAM", "SHELLS", "DRINKS" }, v)
	solid(Build.part(m, "BackWall", V(5, 3.6, 0.25), CF(0, 1.8, 1.6), WOOD, M.Wood))
	solid(Build.part(m, "Counter", V(5, 1.15, 1.0), CF(0, 0.575, -1.2), WOOD, M.Wood))
	solid(Build.part(m, "CounterTop", V(5.3, 0.15, 1.2), CF(0, 1.22, -1.2), WHITE))
	for sx = -1, 1, 2 do
		for _, z in { -1.6, 1.6 } do
			solid(Build.cyl(m, "Post", 3.9, 0.3, CF(sx * 2.4, 1.95, z), WHITE))
		end
	end
	for i = 0, 4 do
		local x = -2.0 + i
		Build.part(
			m,
			"Awning",
			V(1.0, 0.15, 3.9),
			CF(x, 4.0, -0.1) * CFrame.Angles(-0.2, 0, 0),
			cols[i % 2 + 1],
			M.Fabric
		)
		Build.tri(m, "Valance", CF(x, 3.42, -2.03) * CFrame.Angles(0, 0, PI), 1.0, 0.4, 0.06, cols[i % 2 + 1], M.Fabric)
	end
	local sign = Build.part(m, "SignBoard", V(3.2, 0.9, 0.15), CF(0, 4.85, -1.0), cols[1])
	Build.label(sign, Enum.NormalId.Front, text, WHITE)
	for i, col in { rgb(255, 90, 90), rgb(255, 220, 60), rgb(120, 220, 120) } do
		Build.ball(m, "Goods", 0.45, CF(-1.6 + i * 0.55, 1.52, -1.25), col)
	end
	Build.cyl(m, "Goods", 0.6, 0.3, CF(1.4, 1.6, -1.2), rgb(80, 180, 255), M.Glass)
end

builders.Surfboard = function(m, v)
	local cols = pick({
		{ rgb(255, 120, 60), WHITE },
		{ rgb(60, 190, 255), rgb(255, 230, 70) },
		{ rgb(255, 90, 160), WHITE },
		{ rgb(90, 220, 140), rgb(40, 90, 200) },
	}, v)
	local cf = CF(0, 3.45, 0) * CFrame.Angles(0, 0, 0.06 * ((v % 3) - 1))
	solid(Build.ellipsoid(m, "Board", V(1.8, 7, 0.3), cf, cols[1]))
	Build.ellipsoid(m, "Stripe", V(0.35, 6.6, 0.34), cf, cols[2])
	Build.triPts(m, "Fin", (cf * CF(0, -2.1, 0.12)).Position, (cf * CF(0, -2.5, 0.6)).Position, Y, 0.6, 0.08, cols[2])
end

builders.BeachBall = function(m, v)
	local c = V(0, 1, 0)
	Build.ball(m, "Ball", 2, CF(c), WHITE)
	local sets = {
		{ rgb(255, 70, 70), rgb(255, 215, 50), rgb(60, 150, 255) },
		{ rgb(255, 120, 200), rgb(90, 220, 140), rgb(255, 160, 40) },
	}
	for i, col in pick(sets, v) do
		Build.ellipsoid(m, "Stripe", V(2.15, 2.15, 1.4), CF(c) * CFrame.Angles(0, (i - 1) * PI / 3, 0), col)
	end
	Build.ball(m, "Cap", 0.45, CF(c + V(0, 0.9, 0)), WHITE)
end

builders.Rock = function(m, v)
	local rng = Random.new(v * 104729 + 7)
	local specs = {
		{ V(3.2, 2.2, 2.6), V(0, 1.0, 0) },
		{ V(2.2, 1.6, 2.0), V(1.2, 0.7, 0.4) },
		{ V(1.5, 1.2, 1.4), V(-1.3, 0.5, -0.3) },
	}
	for i, s in specs do
		local rot = CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, PI * 2), rng:NextNumber(-0.3, 0.3))
		local g = 120 + rng:NextInteger(-15, 20)
		solid(Build.part(m, "Rock", s[1], CF(s[2]) * rot, rgb(g, g, g + 8), M.Slate))
		if i == 1 then
			Build.ellipsoid(m, "Moss", V(2.0, 0.4, 1.6), CF(s[2] + V(0, 1.0, 0)) * rot, rgb(110, 170, 90), M.Grass)
		end
	end
end

builders.Shell = function(m, v)
	local col = pick({ rgb(255, 190, 170), rgb(255, 150, 180), rgb(200, 170, 255), rgb(255, 240, 220) }, v)
	local hinge = V(0, 0.15, 0.75)
	Build.ellipsoid(m, "Back", V(2.0, 0.25, 1.5), CF(0, 0.13, 0), Build.darken(col, 0.1))
	for _, a in { -0.9, -0.45, 0, 0.45, 0.9 } do
		local dir = V(math.sin(a), 0, -math.cos(a))
		Build.ellipsoid(
			m,
			"Rib",
			V(0.5, 0.35, 1.6),
			CF(hinge + dir * 0.75 + V(0, 0.08, 0)) * CFrame.Angles(0, -a, 0),
			Build.lighten(col, 0.1)
		)
	end
	Build.part(m, "Hinge", V(0.7, 0.25, 0.3), CF(0, 0.13, 0.8), col)
end

builders.Chest = function(m, v)
	local wood = pick({ rgb(150, 95, 45), rgb(120, 75, 40), rgb(170, 110, 60) }, v)
	solid(Build.part(m, "Base", V(3, 1.6, 2), CF(0, 0.8, 0), wood, M.Wood))
	solid(Build.cylBetween(m, "Lid", V(-1.5, 1.6, 0), V(1.5, 1.6, 0), 2.0, Build.lighten(wood, 0.08), M.Wood))
	for _, x in { -1.0, 1.0 } do
		Build.part(m, "Band", V(0.25, 1.64, 2.04), CF(x, 0.8, 0), GOLD, M.Metal)
		Build.cylBetween(m, "Band", V(x - 0.125, 1.6, 0), V(x + 0.125, 1.6, 0), 2.04, GOLD, M.Metal)
	end
	Build.part(m, "Lock", V(0.5, 0.6, 0.15), CF(0, 1.5, -1.05), GOLD, M.Metal)
	Build.ellipsoid(m, "Gold", V(1.4, 0.45, 1.0), CF(1.3, 0.12, -1.6), GOLD, M.Metal)
	for i = 0, 2 do
		Build.cyl(m, "Coin", 0.08, 0.5, CF(0.4 + i * 0.45, 0.05, -1.9 + (i % 2) * 0.3), GOLD, M.Metal)
	end
end

builders.Bucket = function(m, v)
	local cols = pick({
		{ rgb(60, 170, 255), rgb(255, 230, 60) },
		{ rgb(255, 90, 90), rgb(255, 255, 255) },
		{ rgb(255, 200, 40), rgb(60, 170, 255) },
		{ rgb(90, 210, 120), rgb(255, 120, 200) },
	}, v)
	Build.cyl(m, "Body", 1.2, 1.2, CF(0, 0.6, 0), cols[1])
	Build.cyl(m, "Rim", 0.14, 1.32, CF(0, 1.2, 0), cols[2])
	Build.ellipsoid(m, "SandFill", V(1.05, 0.35, 1.05), CF(0, 1.22, 0), SAND, M.Sand)
	Build.beam(m, "Handle", V(-0.62, 1.0, 0), V(-0.45, 1.6, 0), 0.08, 0.08, cols[2], M.SmoothPlastic, Z)
	Build.beam(m, "Handle", V(-0.5, 1.6, 0), V(0.5, 1.6, 0), 0.08, 0.08, cols[2], M.SmoothPlastic, Z)
	Build.beam(m, "Handle", V(0.45, 1.6, 0), V(0.62, 1.0, 0), 0.08, 0.08, cols[2], M.SmoothPlastic, Z)
	Build.cylBetween(m, "Spade", V(0.1, 1.0, 0.05), V(0.45, 2.2, 0.2), 0.12, cols[2])
	Build.ball(m, "SpadeGrip", 0.25, CF(0.47, 2.27, 0.21), cols[2])
end

builders.Sign = function(m, v)
	local text = pick({ "DIG!", "SELL", "SHOP", "EGGS", "DANGER!" }, v)
	solid(Build.part(m, "Post", V(0.35, 4, 0.35), CF(0, 2, 0.12), WOOD_DARK, M.Wood))
	Build.part(m, "Frame", V(3.4, 1.6, 0.14), CF(0, 3.6, 0.1), WOOD_DARK, M.Wood)
	local board = solid(Build.part(m, "SignBoard", V(3.2, 1.4, 0.2), CF(0, 3.6, 0), WOOD, M.Wood))
	Build.label(board, Enum.NormalId.Front, text, WHITE)
end

builders.Lamp = function(m, v)
	local metal = pick({ rgb(85, 110, 125), rgb(85, 90, 105), rgb(55, 135, 145) }, v)
	solid(Build.cyl(m, "Base", 0.4, 1.0, CF(0, 0.2, 0), metal, M.Metal))
	solid(Build.cyl(m, "Pole", 8.1, 0.3, CF(0, 4.45, 0), metal, M.Metal))
	Build.beam(m, "Arm", V(0, 8.3, 0), V(0, 8.6, -1.2), 0.2, 0.2, metal, M.Metal, X)
	Build.part(m, "Shade", V(0.85, 0.3, 0.85), CF(0, 8.6, -1.3), metal, M.Metal)
	local bulb = Build.ball(m, "Bulb", 0.55, CF(0, 8.3, -1.3), rgb(255, 235, 170), M.Neon)
	Build.glow(bulb, rgb(255, 220, 160), 1.5, 18)
	Build.ball(m, "Finial", 0.4, CF(0, 8.6, 0), metal, M.Metal)
end

builders.Bench = function(m, v)
	local wood = pick({ WOOD, rgb(80, 160, 220), rgb(230, 90, 80) }, v)
	local metal = rgb(50, 50, 60)
	for _, z in { -0.5, 0, 0.5 } do
		solid(Build.part(m, "Seat", V(5, 0.18, 0.45), CF(0, 1.5, z), wood, M.Wood))
	end
	for i, y in { 2.2, 2.75 } do
		solid(
			Build.part(m, "Back", V(5, 0.4, 0.15), CF(0, y, 0.78 + i * 0.05) * CFrame.Angles(-0.15, 0, 0), wood, M.Wood)
		)
	end
	for _, x in { -2.2, 2.2 } do
		Build.part(m, "Leg", V(0.2, 1.5, 0.2), CF(x, 0.75, -0.55), metal, M.Metal)
		Build.part(m, "Leg", V(0.2, 3.0, 0.2), CF(x, 1.5, 0.75) * CFrame.Angles(-0.1, 0, 0), metal, M.Metal)
		Build.part(m, "Armrest", V(0.22, 0.15, 1.4), CF(x * 1.08, 2.1, 0.05), metal, M.Metal)
	end
end

builders.Barrel = function(m, v)
	local wood = pick({ rgb(150, 95, 50), rgb(120, 80, 45), rgb(175, 120, 70) }, v)
	solid(Build.cyl(m, "Body", 2.8, 2.2, CF(0, 1.4, 0), wood, M.Wood))
	Build.cyl(m, "Bulge", 1.6, 2.36, CF(0, 1.4, 0), wood, M.Wood)
	for _, y in { 0.55, 2.25 } do
		Build.cyl(m, "Hoop", 0.18, 2.34, CF(0, y, 0), rgb(80, 80, 90), M.Metal)
	end
	Build.cyl(m, "Lid", 0.06, 2.0, CF(0, 2.81, 0), Build.darken(wood, 0.2), M.Wood)
end

builders.Starfish = function(m, v)
	local col = pick({ rgb(255, 150, 60), rgb(255, 90, 120), rgb(170, 100, 255), rgb(255, 210, 60) }, v)
	local dot = Build.lighten(col, 0.5)
	local c = CF(0, 0.15, 0)
	Build.ellipsoid(m, "Body", V(1.0, 0.3, 1.0), c, col)
	for k = 0, 4 do
		local a = k / 5 * PI * 2
		Build.tri(
			m,
			"Arm",
			c * CFrame.Angles(0, a, 0) * CFrame.Angles(-PI / 2, 0, 0) * CF(0, 0.85, 0),
			0.8,
			1.0,
			0.25,
			col
		)
		Build.ball(m, "Dot", 0.16, c * CFrame.Angles(0, a, 0) * CF(0, 0.12, -0.75), dot)
	end
end

builders.Dock = function(m, v)
	local planks = { rgb(175, 125, 80), rgb(160, 110, 70) }
	for i = 0, 9 do
		solid(Build.part(m, "Plank", V(8, 0.4, 1.55), CF(0, 4.4, -7.2 + i * 1.6), planks[i % 2 + 1], M.Wood))
	end
	for _, x in { -3.8, 3.8 } do
		Build.part(m, "Stringer", V(0.4, 0.5, 16), CF(x * 0.8, 3.95, 0), WOOD_DARK, M.Wood)
		for _, z in { -7, 0, 7 } do
			solid(Build.cyl(m, "Post", 5.0, 0.7, CF(x, 2.5, z), WOOD_DARK, M.Wood))
		end
	end
end

builders.Flag = function(m, v)
	local cols = pick({
		{ rgb(235, 50, 50), WHITE },
		{ rgb(40, 140, 255), rgb(255, 220, 50) },
		{ rgb(70, 200, 110), WHITE },
		{ rgb(150, 80, 230), GOLD },
		{ rgb(30, 30, 40), WHITE },
	}, v)
	Build.cyl(m, "Base", 0.3, 0.8, CF(0, 0.15, 0), rgb(200, 200, 210), M.Metal)
	solid(Build.cyl(m, "Pole", 10, 0.25, CF(0, 5, 0), WHITE, M.Metal))
	Build.ball(m, "Finial", 0.45, CF(0, 10.1, 0), GOLD, M.Metal)
	Build.part(m, "Cloth", V(3, 2, 0.08), CF(1.6, 8.9, 0), cols[1], M.Fabric)
	Build.part(m, "ClothStripe", V(3.02, 0.6, 0.1), CF(1.6, 8.9, 0), cols[2], M.Fabric)
end

builders.Cooler = function(m, v)
	local col = pick({ rgb(40, 200, 230), rgb(255, 90, 90), rgb(90, 200, 120), rgb(40, 110, 220) }, v)
	solid(Build.part(m, "Body", V(2.4, 1.4, 1.4), CF(0, 0.7, 0), col))
	solid(Build.part(m, "Lid", V(2.5, 0.35, 1.5), CF(0, 1.57, 0), WHITE))
	for side = -1, 1, 2 do
		Build.part(m, "HandlePost", V(0.14, 0.3, 0.14), CF(side * 0.6, 1.85, 0), rgb(220, 220, 225))
	end
	Build.part(m, "Handle", V(1.34, 0.14, 0.2), CF(0, 2.0, 0), rgb(220, 220, 225))
	Build.part(m, "Latch", V(0.4, 0.4, 0.1), CF(0, 1.35, -0.75), WHITE)
end

builders.SurfShack = function(m, v)
	local wallCol = pick({ rgb(255, 245, 225), rgb(140, 220, 240), rgb(255, 210, 170) }, v)
	local trim = pick({ rgb(40, 150, 240), rgb(255, 110, 90), rgb(60, 180, 120) }, v)
	local W = M.Wood
	solid(Build.part(m, "Floor", V(12, 0.6, 10), CF(0, 0.3, 0), WOOD, W))
	solid(Build.part(m, "BackWall", V(12, 5, 0.4), CF(0, 3.1, 4.8), wallCol, W))
	for side = -1, 1, 2 do
		solid(Build.part(m, "SideWall", V(0.4, 5, 9.6), CF(side * 5.8, 3.1, 0), wallCol, W))
	end
	-- front (-Z): wall left of the door, door gap, then serving window with counter
	solid(Build.part(m, "FrontWall", V(1.8, 5, 0.4), CF(-5.1, 3.1, -4.8), wallCol, W))
	solid(Build.part(m, "DoorHeader", V(1.8, 1.2, 0.4), CF(-3.3, 5.0, -4.8), wallCol, W))
	solid(Build.part(m, "FrontWall", V(8.4, 1.8, 0.4), CF(1.8, 1.5, -4.8), wallCol, W))
	solid(Build.part(m, "FrontHeader", V(8.4, 1.2, 0.4), CF(1.8, 5.0, -4.8), wallCol, W))
	Build.part(m, "WindowPost", V(0.3, 2.0, 0.3), CF(1.8, 3.4, -4.8), trim, W)
	solid(Build.part(m, "Counter", V(8.6, 0.2, 1.0), CF(1.8, 2.5, -5.1), trim, W))
	local ra, rb =
		Build.tri(m, "Roof", CF(0, 7.0, 0) * CFrame.Angles(0, PI / 2, 0), 11.5, 2.8, 13, rgb(225, 185, 105), M.Fabric)
	solid(ra)
	solid(rb)
	local sign = Build.part(m, "SignBoard", V(6, 1.3, 0.3), CF(1.2, 6.25, -5.35), trim, W)
	Build.label(sign, Enum.NormalId.Front, "SURF SHACK", WHITE)
	local boards = { { rgb(255, 120, 60), WHITE }, { rgb(60, 190, 255), rgb(255, 230, 70) } }
	for i, x in { -5.3, 5.3 } do
		local cf = CF(x, 3.4, -5.35) * CFrame.Angles(0.12, 0, 0)
		Build.ellipsoid(m, "Surfboard", V(1.4, 5.5, 0.25), cf, boards[i][1])
		Build.ellipsoid(m, "SurfboardStripe", V(0.3, 5.2, 0.28), cf, boards[i][2])
	end
	solid(Build.part(m, "Step", V(3, 0.3, 1), CF(-3.3, 0.15, -5.4), WOOD_DARK, W))
	local lamp = Build.ball(m, "Lantern", 0.5, CF(-3.3, 4.1, -5.3), rgb(255, 230, 160), M.Neon)
	Build.glow(lamp, rgb(255, 220, 160), 1, 14)
end

local function fallback(m: Model, _v: number)
	solid(Build.part(m, "Crate", V(2, 2, 2), CF(0, 1, 0), WOOD, M.Wood))
	for _, y in { 0.35, 1.65 } do
		Build.part(m, "Band", V(2.04, 0.2, 2.04), CF(0, y, 0), WOOD_DARK, M.Wood)
	end
end

local ORDER = {
	"PalmTree",
	"Umbrella",
	"BeachTowel",
	"Sandcastle",
	"Crab",
	"LifeguardTower",
	"BoardwalkStall",
	"Surfboard",
	"BeachBall",
	"Rock",
	"Shell",
	"Chest",
	"Bucket",
	"Sign",
	"Lamp",
	"Bench",
	"Barrel",
	"Starfish",
	"Dock",
	"Flag",
	"Cooler",
	"SurfShack",
}

local function key(name: string): string
	return (string.gsub(string.lower(name), "[%s_%-]", ""))
end

local byKey: { [string]: string } = {}
for _, name in ORDER do
	byKey[key(name)] = name
end

function Props.Build(name: string, variant: number?): Model
	local canonical = byKey[key(name)]
	local m = Build.model(canonical or name)
	Build.root(m, CFrame.identity, V(1, 0.1, 1))
	local v = math.max(1, math.floor(variant or 1))
	local builder: PropBuilder = if canonical then builders[canonical] else fallback
	builder(m, v)
	return m
end

function Props.List(): { string }
	return table.clone(ORDER)
end

return Props
