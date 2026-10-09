--!strict
--[[
	PierCarnival — Sunset Pier and the carnival deck at its end.

	  Pier       x -6..6 from the wet sand (z -68) to the carnival (z -178), plank segments of
	             uneven length ("Deck", top = DECK_TOP), pilings to the seabed, railings, a
	             viewing bulge either side at z -112..-136 (x ±14), white crook lamps in pairs
	             with criss-cross string lights and bunting, tall flag lamps at the entrance.
	  Carnival   deck x -40..40, z -178..-230 (inside the south boundary at -232):
	             - Ferris wheel (diameter 48, hub (0, DECK_TOP + 31, -212), turning in the XY plane
	               so it faces the spawns), AmbientFerrisWheel contract: Model "FerrisWheel" with
	               child Model "Wheel" (pivot at the hub, axis = pivot local Z) and direct-child
	               "Gondola" Models carrying HangOffset.
	             - carousel (-24, -195, AmbientSpin), ticket booth (25, -190), strength tester
	               (32, -211), pier-end beacon (33.5, -224.5), "SUNSET PIER" arch at z -180,
	               flags (AmbientSway), maypole string lights from the wheel to the deck lamps,
	               benches + telescopes on the rear rail facing the open sea.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Models.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.PromenadeKit)
local Layout = require(script.Parent.Layout)

local C = Config.Theme.Colors
local rgb = Color3.fromRGB
local TOP = Layout.DECK_TOP
local HW = Layout.PIER_HALF_W -- 6
local PZ0 = Layout.PIER_Z0 -- -68
local JOIN = -178 -- pier meets the carnival deck
local BULGE0, BULGE1, BULGE_X = -112, -136, 14
local CX = 40 -- carnival half width
local CZ1 = Layout.BOUND_SOUTH_Z + 2 -- -230 (rear edge)
local WZ = -212 -- Ferris wheel plane
local HUB_Y = TOP + 31
local R = 24
local PILE_BOTTOM = Layout.SEABED_Y - 4

local PierCarnival = {}

local TONES = {
	rgb(192, 140, 92),
	rgb(178, 126, 80),
	rgb(166, 116, 72),
	rgb(200, 156, 108),
}

local function deck(m: Model, x0: number, x1: number, z0: number, z1: number, color: Color3)
	local p = Kit.part(
		m,
		"Deck",
		Vector3.new(x1 - x0, 1, math.abs(z1 - z0)),
		CFrame.new((x0 + x1) / 2, TOP - 0.5, (z0 + z1) / 2),
		color,
		Enum.Material.WoodPlanks
	)
	Kit.solid(p)
	p.CastShadow = true
end

local function piling(m: Model, x: number, z: number, d: number?)
	local h = TOP - 1 - PILE_BOTTOM
	local p =
		Kit.cyl(m, "Piling", h, d or 1.6, CFrame.new(x, PILE_BOTTOM + h / 2, z), Kit.WOOD_DARK, Enum.Material.Wood)
	Kit.solid(p)
end

-- Straight railing from a to b (deck-level points): posts every ~`step`, top + mid rail.
local function railRun(m: Model, a: Vector3, b: Vector3, step: number, skip: { Vector3 }?)
	local d = b - a
	local len = d.Magnitude
	local n = math.max(1, math.floor(len / step + 0.5))
	for i = 0, n do
		local p = a + d * (i / n)
		local blocked = false
		local list: { Vector3 } = skip or {}
		for _, s in list do
			if (s - p).Magnitude < 2.2 then
				blocked = true
			end
		end
		if not blocked then
			Kit.solid(
				Kit.part(m, "RailPost", Vector3.new(0.6, 3.4, 0.6), CFrame.new(p + Vector3.new(0, 1.7, 0)), Kit.WHITE)
			)
		end
	end
	local mid = (a + b) / 2
	local frame = CFrame.lookAt(mid, b)
	Kit.solid(Kit.part(m, "Rail", Vector3.new(0.5, 0.35, len), frame + Vector3.new(0, 3.2, 0), Kit.WHITE))
	Kit.part(m, "RailMid", Vector3.new(0.28, 0.25, len), frame + Vector3.new(0, 1.8, 0), Kit.WHITE)
end

local function at(x: number, z: number): Vector3
	return Vector3.new(x, TOP, z)
end

-- Pier --------------------------------------------------------------------------------------

type Pair = { [number]: Kit.LampInfo }

local function buildPier(parent: Instance, rng: Random)
	local m = Kit.model("Pier", parent)
	-- Deck planks of uneven length
	local z, last = PZ0, 0
	while z > JOIN + 0.01 do
		local zn = math.max(z - ({ 6, 8, 8, 10, 12 })[rng:NextInteger(1, 5)], JOIN)
		if zn - JOIN < 2.5 then
			zn = JOIN
		end
		local k = rng:NextInteger(1, #TONES)
		if k == last then
			k = k % #TONES + 1
		end
		last = k
		deck(m, -HW, HW, z, zn, TONES[k])
		z = zn
	end
	for _, sx in { -1, 1 } do
		local x0, x1 = if sx < 0 then -BULGE_X else HW, if sx < 0 then -HW else BULGE_X
		deck(m, x0, x1, BULGE0, BULGE1, TONES[if sx < 0 then 4 else 2])
	end
	-- Pilings + cross braces
	z = PZ0 - 6
	while z > JOIN do
		for _, sx in { -1, 1 } do
			piling(m, sx * (HW - 0.6), z)
		end
		Kit.part(
			m,
			"PierBrace",
			Vector3.new(HW * 2 - 1, 0.6, 0.6),
			CFrame.new(0, TOP - 4.5, z),
			Kit.WOOD_DARK,
			Enum.Material.Wood
		)
		z -= 16
	end
	for _, sx in { -1, 1 } do
		for _, bz in { BULGE0 - 0.6, (BULGE0 + BULGE1) / 2, BULGE1 + 0.6 } do
			piling(m, sx * (BULGE_X - 0.6), bz)
		end
		-- fascia boards on the long sides
		Kit.part(
			m,
			"PierFascia",
			Vector3.new(0.3, 0.9, PZ0 - JOIN),
			CFrame.new(sx * (HW + 0.1), TOP - 0.8, (PZ0 + JOIN) / 2),
			Kit.WHITE
		)
	end

	-- Lamps: white crook pairs, tall flag lamps on the bulges and at the entrance
	local pairs: { Pair } = {}
	local lampZ = { -80, -104, -124, -144, -168 }
	for i, lz in lampZ do
		local pair: Pair = {}
		for _, sx in { -1, 1 } do
			local bulge = lz == -124
			local x = sx * (if bulge then BULGE_X - 0.3 else HW - 0.3)
			local p = at(x, lz)
			local cf = CFrame.lookAt(p, p + Vector3.new(-sx, 0, 0))
			pair[sx] = Kit.lamp(m, if bulge then "Tall" else "Crook", cf, {
				scheme = Kit.SCHEMES.White,
				light = (i == 2 and sx < 0) or (i == 4 and sx > 0),
				height = if bulge then 13.5 else 9.4 + rng:NextNumber(0, 0.4),
				wind = Vector3.new(1, 0, 0.15),
				pennant = if sx < 0 then C.Ocean else C.Gold,
			})
		end
		table.insert(pairs, pair)
	end
	local gate: Pair = {}
	for _, sx in { -1, 1 } do
		local p = at(sx * (HW - 0.3), PZ0 - 2.5)
		gate[sx] = Kit.lamp(m, "Tall", CFrame.lookAt(p, p + Vector3.zAxis), {
			scheme = Kit.SCHEMES.White,
			height = 12.5,
			wind = Vector3.new(1, 0, 0.1),
			pennant = C.Coral,
		})
	end
	local skip: { Vector3 } = {}
	for _, pair in pairs do
		for _, info in pair do
			local pv = info.model:GetPivot()
			table.insert(skip, Vector3.new(pv.X, TOP, pv.Z))
		end
	end
	for _, sx in { -1, 1 } do
		table.insert(skip, at(sx * (HW - 0.3), PZ0 - 2.5))
	end
	-- Railings (open where the bulges join)
	for _, sx in { -1, 1 } do
		local x = sx * (HW - 0.3)
		local bx = sx * (BULGE_X - 0.3)
		railRun(m, at(x, PZ0 - 0.5), at(x, BULGE0), 11, skip)
		railRun(m, at(x, BULGE1), at(x, JOIN), 11, skip)
		railRun(m, at(x, BULGE0 - 0.3), at(bx, BULGE0 - 0.3), 8, skip)
		railRun(m, at(bx, BULGE0 - 0.3), at(bx, BULGE1 + 0.3), 6, skip)
		railRun(m, at(bx, BULGE1 + 0.3), at(x, BULGE1 + 0.3), 8, skip)
	end

	-- Festoons: criss-cross lights between consecutive pairs, bunting across each pair
	local fest = Kit.model("Festoons", m)
	for i = 1, #pairs - 1 do
		local a, b = pairs[i], pairs[i + 1]
		Kit.stringLights(fest, a[-1].anchor, a[-1].top, b[1].anchor, b[1].top, 1.6, { offset = i })
		Kit.stringLights(fest, a[1].anchor, a[1].top, b[-1].anchor, b[-1].top, 1.6, { offset = i + 3 })
	end
	for i, pair in pairs do
		local lift = if i == 3 then -1.4 else -0.35
		Kit.bunting(
			fest,
			pair[-1].anchor,
			pair[-1].top + Vector3.new(0, lift, 0),
			pair[1].anchor,
			pair[1].top + Vector3.new(0, lift, 0),
			if i == 3 then 2.2 else 1.0,
			{ spacing = 2.0, h = 1.3 }
		)
	end
	Kit.bunting(fest, gate[-1].anchor, gate[-1].top, gate[1].anchor, gate[1].top, 1.2, { spacing = 1.9, h = 1.4 })

	-- Bulge dressing: benches facing out to sea, fishing spot, coin binoculars, lifebuoys
	local mid = (BULGE0 + BULGE1) / 2
	local benchL = at(-BULGE_X + 2.4, mid + 6.5)
	Kit.bench(m, CFrame.lookAt(benchL, benchL - Vector3.xAxis), TONES[1])
	local benchR = at(BULGE_X - 2.4, mid - 6.5)
	Kit.bench(m, CFrame.lookAt(benchR, benchR + Vector3.xAxis), TONES[3])
	-- fishing rods leaning on the west bulge rail, line into the water
	for j, dz in { -3.6, -5.0 } do
		local foot = at(-BULGE_X + 2.0, mid + dz)
		local tip = foot + Vector3.new(-6.2, 6.8 + j * 0.6, 0.4 * j)
		local rod =
			Kit.rod(m, "FishingRod", foot + Vector3.new(0, 0.2, 0), tip, 0.16, if j == 1 then C.Coral else C.Ocean)
		Kit.cyl(m, "FishingReel", 0.3, 0.45, Build.orient(foot:Lerp(tip, 0.15), Vector3.zAxis), Kit.IRON)
		local floatPos = Vector3.new(tip.X - 1.8, Layout.WATER_Y + 0.15, tip.Z)
		local float = Kit.ball(m, "FishingFloat", 0.45, floatPos, C.Danger)
		Kit.wire(rod, tip, float, floatPos, 0.05, rgb(235, 235, 235), 0.04)
	end
	Kit.cyl(m, "BaitBucket", 1.2, 1.3, CFrame.new(at(-BULGE_X + 3.6, mid - 7.4) + Vector3.new(0, 0.6, 0)), C.Ocean)
	Kit.part(
		m,
		"TackleBox",
		Vector3.new(1.6, 0.8, 1.0),
		CFrame.new(at(-BULGE_X + 4.2, mid - 9.0) + Vector3.new(0, 0.4, 0)),
		C.Palm
	)
	local bino = at(BULGE_X - 1.6, mid + 6.5)
	Kit.solid(
		Kit.cyl(m, "BinocularPost", 3.4, 0.45, CFrame.new(bino + Vector3.new(0, 1.7, 0)), Kit.NAVY, Enum.Material.Metal)
	)
	local head = Kit.part(
		m,
		"BinocularHead",
		Vector3.new(1.0, 0.9, 1.6),
		CFrame.lookAt(bino + Vector3.new(0, 3.8, 0), bino + Vector3.new(6, 4.5, -3)),
		C.Gold,
		Enum.Material.Metal
	)
	for _, sx in { -0.28, 0.28 } do
		Kit.cyl(
			m,
			"BinocularLens",
			0.5,
			0.4,
			head.CFrame * CFrame.new(sx, 0.1, -0.9) * CFrame.Angles(math.rad(90), 0, 0),
			Kit.IRON
		)
	end
	for _, b in { { -1, -92 }, { 1, -156 } } do
		local p = at(b[1] * (HW - 0.3), b[2])
		Kit.lifebuoy(m, CFrame.lookAt(p + Vector3.new(-b[1] * 0.55, 2.0, 0), p + Vector3.new(-b[1] * 5, 2.0, 0)), 0.9)
	end
end

-- Ferris wheel ------------------------------------------------------------------------------

local function gondola(parent: Instance, hang: Vector3, hub: Vector3, color: Color3): Model
	local g = Kit.model("Gondola", parent)
	local hanger = Kit.part(g, "Hanger", Vector3.new(0.5, 0.5, 3.4), CFrame.new(hang), Kit.IRON, Enum.Material.Metal)
	g.PrimaryPart = hanger
	for _, sz in { -1, 1 } do
		Kit.rod(
			g,
			"GondolaArm",
			hang + Vector3.new(0, 0, sz * 1.3),
			hang + Vector3.new(0, -3.7, sz * 1.3),
			0.22,
			Kit.IRON
		)
	end
	Kit.part(g, "GondolaRoof", Vector3.new(3.7, 0.4, 3.3), CFrame.new(hang + Vector3.new(0, -1.9, 0)), color)
	Kit.part(g, "GondolaTrim", Vector3.new(3.55, 0.3, 3.2), CFrame.new(hang + Vector3.new(0, -3.75, 0)), Kit.WHITE)
	Kit.part(g, "GondolaTub", Vector3.new(3.4, 1.65, 3.05), CFrame.new(hang + Vector3.new(0, -4.6, 0)), color)
	g:SetAttribute("HangOffset", hang - hub)
	return g
end

local function buildFerrisWheel(parent: Instance): BasePart
	local hub = Vector3.new(0, HUB_Y, WZ)
	local fw = Kit.model("FerrisWheel", parent)
	-- Static A-frames, axle, boarding platform
	-- (kept outside the tagged model: the motion controller skips models with collidable parts)
	local support = Kit.model("FerrisWheelStand", parent)
	local apex: BasePart? = nil
	for _, zf in { WZ + 4.6, WZ - 4.6 } do
		for _, sx in { -1, 1 } do
			local foot = at(sx * 13, zf)
			Kit.solid(
				Kit.part(
					support,
					"WheelFooting",
					Vector3.new(2.6, 0.8, 2.6),
					CFrame.new(foot + Vector3.new(0, 0.4, 0)),
					Kit.NAVY
				)
			)
			Kit.solid(
				Kit.rod(support, "WheelLeg", foot + Vector3.new(0, 0.8, 0), Vector3.new(0, HUB_Y, zf), 1.3, Kit.WHITE)
			)
		end
		for _, hy in { 10, 21 } do
			local hx = 13 * (1 - hy / 31) - 0.2
			Kit.rod(support, "WheelBrace", Vector3.new(-hx, TOP + hy, zf), Vector3.new(hx, TOP + hy, zf), 0.7, C.Coral)
		end
		local bearing =
			Kit.part(support, "WheelBearing", Vector3.new(2.4, 2.4, 1.4), CFrame.new(0, HUB_Y, zf), Kit.NAVY)
		if zf > WZ then
			apex = bearing
		end
	end
	local axle =
		Kit.cyl(fw, "WheelAxle", 10.8, 1.3, Build.orient(hub, Vector3.zAxis), rgb(150, 155, 165), Enum.Material.Metal)
	fw.PrimaryPart = axle
	Kit.solid(Kit.part(support, "BoardingPlatform", Vector3.new(10, 0.6, 7.4), CFrame.new(0, TOP + 0.3, WZ), C.Coral))

	-- Rotating wheel (pivot = hub, local Z = world Z)
	local wheel = Kit.model("Wheel", fw)
	local root = Kit.part(wheel, "WheelRoot", Vector3.new(1, 1, 1), CFrame.new(hub), Kit.WHITE)
	root.Transparency = 1
	wheel.PrimaryPart = root
	Kit.cyl(wheel, "WheelHub", 4.6, 3.8, Build.orient(hub, Vector3.zAxis), C.Coral)
	local hubGlow = Kit.neon(
		wheel,
		"WheelHubGlow",
		Vector3.new(0.4, 3.0, 3.0),
		CFrame.new(hub + Vector3.new(0, 0, 2.5)) * CFrame.Angles(0, math.rad(90), 0),
		C.Gold
	)
	hubGlow.Shape = Enum.PartType.Cylinder
	Kit.light(hubGlow, C.Gold, 16, 1.6)
	local SEG, N = 20, 10
	for _, side in { -1, 1 } do
		local z = WZ + side * 2.0
		local function rimPt(a: number, r: number): Vector3
			return Vector3.new(math.cos(a) * r, HUB_Y + math.sin(a) * r, z)
		end
		for i = 0, SEG - 1 do
			local a0, a1 = i * math.pi * 2 / SEG, (i + 1) * math.pi * 2 / SEG
			local am = (a0 + a1) / 2
			local radial = Vector3.new(math.cos(am), math.sin(am), 0)
			Kit.bar(wheel, "WheelRim", rimPt(a0, R), rimPt(a1, R), 1.0, 0.6, Kit.WHITE, nil, radial)
			local lights = Kit.bar(
				wheel,
				"WheelLights",
				rimPt(a0, R + 0.62),
				rimPt(a1, R + 0.62),
				0.28,
				0.32,
				Kit.BULBS[i % #Kit.BULBS + 1],
				Enum.Material.Neon,
				radial
			)
			Kit.tag(lights, Kit.NIGHT_TAG)
			if i % 2 == 0 then
				local a2 = (i + 2) * math.pi * 2 / SEG
				Kit.bar(
					wheel,
					"WheelInnerRim",
					rimPt(a0, R * 0.55),
					rimPt(a2, R * 0.55),
					0.5,
					0.35,
					C.Coral,
					nil,
					radial
				)
			end
		end
		for g = 0, N - 1 do
			local a = -math.pi / 2 + g * math.pi * 2 / N
			Kit.rod(wheel, "WheelSpoke", rimPt(a, 1.8), rimPt(a, R), 0.36, Kit.WHITE)
		end
	end
	-- Gondola pins (rotate with the wheel) + gondolas (direct children, stay upright)
	local colors = { C.Coral, C.Ocean, C.Gold, C.Palm, C.Purple, C.Sunset }
	for g = 0, N - 1 do
		local a = -math.pi / 2 + g * math.pi * 2 / N
		local pin = Vector3.new(math.cos(a) * R, HUB_Y + math.sin(a) * R, WZ)
		Kit.rod(
			wheel,
			"GondolaPin",
			pin - Vector3.new(0, 0, 2.2),
			pin + Vector3.new(0, 0, 2.2),
			0.4,
			Kit.IRON,
			Enum.Material.Metal
		)
		gondola(fw, pin, hub, colors[g % #colors + 1])
	end
	fw:SetAttribute("SpinRPM", 1.25)
	Kit.motion(fw, "AmbientFerrisWheel")
	return apex :: BasePart
end

-- Carnival attractions ----------------------------------------------------------------------

local function buildCarousel(parent: Instance, c: Vector3)
	local m = Kit.model("Carousel", parent)
	Kit.solid(Kit.cyl(m, "CarouselPlinth", 0.5, 17.6, CFrame.new(c + Vector3.new(0, 0.25, 0)), Kit.WHITE))
	Kit.cyl(m, "CarouselPlinthTrim", 0.3, 18.1, CFrame.new(c + Vector3.new(0, 0.15, 0)), C.Coral)
	local spin = Kit.model("CarouselSpin", m)
	local root = Kit.part(spin, "CarouselRoot", Vector3.new(1, 1, 1), CFrame.new(c + Vector3.new(0, 0.5, 0)), Kit.WHITE)
	root.Transparency = 1
	spin.PrimaryPart = root
	Kit.cyl(spin, "CarouselFloor", 0.3, 16.4, CFrame.new(c + Vector3.new(0, 0.65, 0)), rgb(255, 236, 196))
	local column =
		Kit.cyl(spin, "CarouselColumn", 9.8, 2.0, CFrame.new(c + Vector3.new(0, 5.6, 0)), C.Gold, Enum.Material.Metal)
	for _, y in { 2.4, 8.6 } do
		Kit.cyl(spin, "CarouselBand", 0.5, 2.4, CFrame.new(c + Vector3.new(0, y, 0)), C.Coral)
	end
	Kit.cyl(spin, "CarouselRoof", 0.5, 17.6, CFrame.new(c + Vector3.new(0, 10.7, 0)), Kit.WHITE)
	Kit.cyl(spin, "CarouselValance", 1.0, 17.9, CFrame.new(c + Vector3.new(0, 10.0, 0)), C.Coral)
	local apex = c + Vector3.new(0, 14.8, 0)
	for i = 0, 7 do
		local a = (i + 0.5) * math.pi / 4
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local rimMid = c + Vector3.new(0, 10.95, 0) + dir * 8.8 * math.cos(math.pi / 8)
		Kit.tri(
			spin,
			"CarouselCanopy",
			rimMid,
			apex,
			dir:Cross(Vector3.yAxis),
			2 * 8.8 * math.sin(math.pi / 8) + 0.1,
			0.2,
			if i % 2 == 0 then C.Coral else Kit.WHITE
		)
	end
	Kit.ball(spin, "CarouselTopper", 1.3, apex + Vector3.new(0, 0.5, 0), C.Gold)
	local bulbs = Kit.model("CarouselBulbs", spin)
	for i = 0, 11 do
		local a = i * math.pi * 2 / 12
		Build.ball(
			bulbs,
			"Bulb",
			0.5,
			CFrame.new(c + Vector3.new(math.cos(a) * 9.05, 9.6, math.sin(a) * 9.05)),
			Kit.BULBS[i % #Kit.BULBS + 1],
			Enum.Material.Neon
		)
	end
	Kit.tag(bulbs, Kit.NIGHT_TAG)
	local horseColors = { Kit.WHITE, rgb(255, 200, 220), rgb(200, 230, 255), rgb(255, 236, 170) }
	for i = 0, 7 do
		local a = i * math.pi * 2 / 8
		local p = c + Vector3.new(math.cos(a) * 5.8, 0, math.sin(a) * 5.8)
		Kit.rod(
			spin,
			"HorsePole",
			p + Vector3.new(0, 0.8, 0),
			p + Vector3.new(0, 10.4, 0),
			0.22,
			C.Gold,
			Enum.Material.Metal
		)
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
		local body = p + Vector3.new(0, 3.4 + (i % 2) * 0.9, 0)
		local cf = CFrame.lookAt(body, body + tangent)
		local col = horseColors[i % #horseColors + 1]
		Kit.part(spin, "HorseBody", Vector3.new(0.9, 1.1, 2.5), cf, col)
		Kit.part(
			spin,
			"HorseHead",
			Vector3.new(0.7, 1.4, 0.9),
			cf * CFrame.new(0, 0.9, -1.35) * CFrame.Angles(math.rad(-25), 0, 0),
			col
		)
		Kit.part(
			spin,
			"HorseSaddle",
			Vector3.new(1.0, 0.25, 0.9),
			cf * CFrame.new(0, 0.62, 0.1),
			if i % 2 == 0 then C.Coral else C.Ocean
		)
	end
	Kit.light(column, C.Gold, 14, 1.2)
	spin:SetAttribute("SpinRPM", 3.5)
	Kit.motion(spin, "AmbientSpin")
end

local function buildBooth(parent: Instance, p: Vector3)
	local m = Kit.model("TicketBooth", parent)
	local cf = CFrame.lookAt(p, p - Vector3.xAxis) -- window faces the pier axis
	Kit.solid(Kit.part(m, "BoothBase", Vector3.new(5.6, 0.4, 5.6), cf * CFrame.new(0, 0.2, 0), Kit.NAVY))
	Kit.solid(Kit.part(m, "BoothBody", Vector3.new(4.6, 4.4, 4.6), cf * CFrame.new(0, 2.6, 0), Kit.WHITE))
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.part(m, "BoothCorner", Vector3.new(0.6, 4.6, 0.6), cf * CFrame.new(sx * 2.3, 2.7, sz * 2.3), C.Coral)
		end
	end
	local window = Kit.part(
		m,
		"BoothWindow",
		Vector3.new(2.8, 1.6, 0.1),
		cf * CFrame.new(0, 3.0, -2.33),
		rgb(255, 230, 170),
		Enum.Material.Glass
	)
	window.Transparency = 0.35
	Kit.part(m, "BoothCounter", Vector3.new(3.2, 0.2, 0.8), cf * CFrame.new(0, 2.15, -2.6), C.Gold)
	Kit.part(m, "BoothEave", Vector3.new(5.8, 0.4, 5.8), cf * CFrame.new(0, 5.0, 0), C.Coral)
	local apex = cf:PointToWorldSpace(Vector3.new(0, 7.8, 0))
	for i = 0, 3 do
		local a = i * math.pi / 2
		local dir = cf:VectorToWorldSpace(Vector3.new(math.cos(a), 0, math.sin(a)))
		local base = cf:PointToWorldSpace(Vector3.new(0, 5.2, 0)) + dir * 2.9
		Kit.tri(m, "BoothRoof", base, apex, dir:Cross(Vector3.yAxis), 5.8, 0.2, if i % 2 == 0 then C.Gold else C.Coral)
	end
	Kit.rod(m, "BoothPole", apex, apex + Vector3.new(0, 2.2, 0), 0.16, Kit.WHITE)
	Kit.pennant(m, apex + Vector3.new(0, 1.9, 0), Vector3.new(1, 0, 0.2), 2.2, 1.1, C.Purple)
	local sign = Kit.part(m, "BoothSign", Vector3.new(4.2, 1.2, 0.25), cf * CFrame.new(0, 4.35, -2.45), C.Gold)
	Kit.label(sign, Enum.NormalId.Front, "TICKETS")
	Kit.light(window, Kit.WARM, 12, 1.0)
	-- Queue stanchions with sagging rope
	local posts: { BasePart } = {}
	local tops: { Vector3 } = {}
	for i = 0, 2 do
		local sp = cf:PointToWorldSpace(Vector3.new(-1.6 + i * 1.6, 0, -4.8 - i * 0.6))
		Kit.cyl(m, "StanchionBase", 0.15, 0.9, CFrame.new(sp + Vector3.new(0, 0.08, 0)), C.Gold)
		table.insert(
			posts,
			Kit.cyl(m, "Stanchion", 2.4, 0.22, CFrame.new(sp + Vector3.new(0, 1.2, 0)), C.Gold, Enum.Material.Metal)
		)
		table.insert(tops, sp + Vector3.new(0, 2.3, 0))
	end
	for i = 1, 2 do
		Kit.wire(posts[i], tops[i], posts[i + 1], tops[i + 1], 0.45, C.Danger, 0.16)
	end
end

local function buildStrengthTester(parent: Instance, p: Vector3)
	local m = Kit.model("StrengthTester", parent)
	local cf = CFrame.lookAt(p, p - Vector3.xAxis)
	Kit.solid(Kit.part(m, "TesterBase", Vector3.new(3.2, 0.5, 2.4), cf * CFrame.new(0, 0.25, 0), Kit.NAVY))
	Kit.solid(Kit.part(m, "TesterTower", Vector3.new(1.4, 15, 0.6), cf * CFrame.new(0, 8, 0.3), Kit.WHITE))
	local bands = { C.Palm, C.Gold, C.Sunset, C.Coral, C.Danger }
	for i, col in bands do
		Kit.part(m, "TesterBand", Vector3.new(1.5, 0.7, 0.2), cf * CFrame.new(0, 2 + i * 2.4, -0.05), col)
	end
	Kit.rod(
		m,
		"TesterTrack",
		cf:PointToWorldSpace(Vector3.new(0, 0.6, -0.35)),
		cf:PointToWorldSpace(Vector3.new(0, 15.2, -0.35)),
		0.16,
		Kit.IRON
	)
	Kit.part(m, "TesterPuck", Vector3.new(0.7, 0.5, 0.4), cf * CFrame.new(0, 6.5, -0.45), C.Coral)
	Kit.cyl(m, "TesterBell", 0.8, 1.8, cf * CFrame.new(0, 15.9, 0.1), C.Gold, Enum.Material.Metal)
	Kit.ball(m, "TesterBellTop", 0.6, cf:PointToWorldSpace(Vector3.new(0, 16.5, 0.1)), C.Gold)
	Kit.part(m, "TesterPad", Vector3.new(1.4, 0.4, 1.4), cf * CFrame.new(0, 0.7, -1.0), C.Danger)
	-- mallet leaning on the base
	local foot = cf:PointToWorldSpace(Vector3.new(1.4, 0.5, -0.9))
	local head = cf:PointToWorldSpace(Vector3.new(1.9, 4.4, -0.2))
	Kit.rod(m, "MalletHandle", foot, head, 0.26, Kit.WOOD, Enum.Material.Wood)
	Kit.cyl(m, "MalletHead", 1.6, 0.9, Build.orient(head, cf.LookVector), C.Danger)
end

local function buildBeacon(parent: Instance, p: Vector3)
	local m = Kit.model("PierBeacon", parent)
	Kit.solid(Kit.part(m, "BeaconBase", Vector3.new(4.6, 1.2, 4.6), CFrame.new(p + Vector3.new(0, 0.6, 0)), Kit.NAVY))
	local y = 1.2
	for i, w in { 3.6, 3.1, 2.6 } do
		local part = Kit.part(
			m,
			"BeaconTower",
			Vector3.new(w, 3.6, w),
			CFrame.new(p + Vector3.new(0, y + 1.8, 0)),
			if i % 2 == 1 then Kit.WHITE else C.Danger
		)
		if i == 1 then
			Kit.solid(part)
		end
		y += 3.6
	end
	Kit.part(m, "BeaconGallery", Vector3.new(4.0, 0.35, 4.0), CFrame.new(p + Vector3.new(0, y + 0.18, 0)), Kit.NAVY)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		local c0 = p + Vector3.new(math.cos(a) * 2.6, y + 1.1, math.sin(a) * 2.6)
		local c1 = p + Vector3.new(math.cos(a + math.pi / 2) * 2.6, y + 1.1, math.sin(a + math.pi / 2) * 2.6)
		Kit.rod(m, "BeaconRail", c0, c1, 0.14, Kit.WHITE)
	end
	local glass = Kit.cyl(
		m,
		"BeaconGlass",
		2.0,
		2.2,
		CFrame.new(p + Vector3.new(0, y + 1.35, 0)),
		rgb(255, 240, 200),
		Enum.Material.Glass
	)
	glass.Transparency = 0.4
	local lamp = Kit.bulb(m, "BeaconLamp", 1.4, p + Vector3.new(0, y + 1.35, 0), C.Sunset)
	Kit.light(lamp, C.Sunset, 16, 1.8)
	local roofBase = p + Vector3.new(0, y + 2.4, 0)
	for _, wd in { Vector3.xAxis, Vector3.zAxis } do
		Kit.tri(m, "BeaconRoof", roofBase, roofBase + Vector3.new(0, 2.0, 0), wd, 2.8, 0.6, C.Danger)
	end
	Kit.ball(m, "BeaconFinial", 0.55, roofBase + Vector3.new(0, 2.15, 0), C.Gold)
end

-- "SUNSET PIER" arch where the pier meets the carnival. Returns pillar-cap anchors.
local function buildPierArch(parent: Instance): { [number]: { part: BasePart, pos: Vector3 } }
	local m = Kit.model("SunsetPierArch", parent)
	local z = JOIN - 2
	local caps: { [number]: { part: BasePart, pos: Vector3 } } = {}
	local ph = 11.5
	for _, sx in { -1, 1 } do
		local p = at(sx * 8, z)
		Kit.solid(Kit.part(m, "ArchPlinth", Vector3.new(2.6, 1, 2.6), CFrame.new(p + Vector3.new(0, 0.5, 0)), Kit.NAVY))
		Kit.solid(
			Kit.part(
				m,
				"ArchPillar",
				Vector3.new(1.8, ph - 1, 1.8),
				CFrame.new(p + Vector3.new(0, (ph + 1) / 2, 0)),
				Kit.WHITE
			)
		)
		for _, y in { 3.5, 7.0 } do
			Kit.part(m, "ArchBand", Vector3.new(1.95, 0.6, 1.95), CFrame.new(p + Vector3.new(0, y, 0)), C.Sunset)
		end
		local cap =
			Kit.part(m, "ArchCap", Vector3.new(2.5, 0.7, 2.5), CFrame.new(p + Vector3.new(0, ph + 0.35, 0)), C.Coral)
		Kit.ball(m, "ArchFinial", 1.1, p + Vector3.new(0, ph + 1.2, 0), C.Gold)
		caps[sx] = { part = cap, pos = p + Vector3.new(0, ph + 0.6, 0) }
	end
	local function arcPt(x: number): Vector3
		local t = x / 8
		return Vector3.new(x, TOP + ph + 0.6 + 3.2 * (1 - t * t), z)
	end
	local bulbs = Kit.model("ArchBulbs", m)
	for i = 0, 5 do
		local a, b = arcPt(-8 + i * 16 / 6), arcPt(-8 + (i + 1) * 16 / 6)
		Kit.bar(m, "ArchBeam", a, b, 1.2, 0.9, C.Sunset, nil, Vector3.zAxis)
		Build.ball(
			bulbs,
			"Bulb",
			0.45,
			CFrame.new(a:Lerp(b, 0.5) + Vector3.new(0, -0.7, 0.45)),
			if i % 2 == 0 then C.Gold else C.Coral,
			Enum.Material.Neon
		)
	end
	Kit.tag(bulbs, Kit.NIGHT_TAG)
	local bc = at(0, z) + Vector3.new(0, ph - 1.4, 0)
	local board = Kit.part(m, "PierSign", Vector3.new(12.4, 2.8, 0.5), CFrame.lookAt(bc, bc + Vector3.zAxis), C.Sunset)
	board.CastShadow = true
	Kit.part(m, "PierSignFrame", Vector3.new(13.2, 3.5, 0.3), CFrame.new(bc - Vector3.new(0, 0, 0.2)), C.Gold)
	Kit.label(board, Enum.NormalId.Front, "SUNSET PIER")
	Kit.label(board, Enum.NormalId.Back, "COME BACK SOON!")
	Kit.light(board, C.Sunset, 14, 1.0)
	return caps
end

local function telescope(parent: Instance, p: Vector3, yaw: number)
	local m = Kit.model("Telescope", parent)
	Kit.solid(
		Kit.cyl(m, "TelescopeStand", 3.4, 0.5, CFrame.new(p + Vector3.new(0, 1.7, 0)), Kit.NAVY, Enum.Material.Metal)
	)
	local head = CFrame.new(p + Vector3.new(0, 3.7, 0))
		* CFrame.Angles(0, math.rad(yaw), 0)
		* CFrame.Angles(math.rad(12), 0, 0)
	Kit.cyl(m, "Telescope", 2.8, 0.9, head * CFrame.Angles(math.rad(90), 0, 0), C.Gold, Enum.Material.Metal)
	Kit.cyl(m, "TelescopeLens", 0.4, 1.1, head * CFrame.new(0, 0, -1.4) * CFrame.Angles(math.rad(90), 0, 0), Kit.IRON)
end

local function buildCarnival(parent: Instance, rng: Random)
	local m = Kit.model("Carnival", parent)
	-- Deck strips (x) of uneven width
	local x, i = -CX, 0
	while x < CX - 0.01 do
		local x1 = math.min(x + ({ 8, 10, 12, 9 })[rng:NextInteger(1, 4)], CX)
		if CX - x1 < 4 then
			x1 = CX
		end
		i += 1
		deck(m, x, x1, JOIN, CZ1, TONES[i % #TONES + 1])
		x = x1
	end
	-- Fascia + pilings around the edge
	for _, side in { { Vector3.new(CX * 2, 0.9, 0.3), Vector3.new(0, TOP - 0.8, CZ1 - 0.1) } } do
		Kit.part(m, "CarnivalFascia", side[1], CFrame.new(side[2]), Kit.WHITE)
	end
	for _, sx in { -1, 1 } do
		Kit.part(
			m,
			"CarnivalFascia",
			Vector3.new(0.3, 0.9, JOIN - CZ1),
			CFrame.new(sx * (CX + 0.1), TOP - 0.8, (JOIN + CZ1) / 2),
			Kit.WHITE
		)
		Kit.part(
			m,
			"CarnivalFascia",
			Vector3.new(CX - HW, 0.9, 0.3),
			CFrame.new(sx * (CX + HW) / 2, TOP - 0.8, JOIN + 0.1),
			Kit.WHITE
		)
		for _, px in { 14, 39.2 } do
			piling(m, sx * px, JOIN - 0.8, 1.9)
			piling(m, sx * px, CZ1 + 0.8, 1.9)
		end
		for _, pz in { -191, -204, -217 } do
			piling(m, sx * (CX - 0.8), pz, 1.9)
		end
	end
	piling(m, 0, CZ1 + 0.8, 1.9)

	-- Railings (open at the pier mouth)
	local railSkip = { at(-8, JOIN - 0.4), at(8, JOIN - 0.4) }
	for _, sx in { -1, 1 } do
		railRun(m, at(sx * HW, JOIN - 0.4), at(sx * (CX - 0.4), JOIN - 0.4), 11, railSkip)
		railRun(m, at(sx * (CX - 0.4), JOIN - 0.4), at(sx * (CX - 0.4), CZ1 + 0.4), 11)
	end
	railRun(m, at(-(CX - 0.4), CZ1 + 0.4), at(CX - 0.4, CZ1 + 0.4), 11)

	local apex = buildFerrisWheel(m)
	buildCarousel(m, at(-24, -195))
	buildBooth(m, at(25, -190))
	buildStrengthTester(m, at(32, -211))
	buildBeacon(m, at(33.5, -224.5))
	local caps = buildPierArch(m)

	-- Lamps (carnival colours)
	local lamps: { [string]: Kit.LampInfo } = {}
	type Spot = { key: string, x: number, z: number, kind: string }
	local spots: { Spot } = {
		{ key = "FW", x = -38.4, z = -181, kind = "Crook" },
		{ key = "FE", x = 38.4, z = -181, kind = "Crook" },
		{ key = "SW", x = -38.4, z = -203, kind = "Crook" },
		{ key = "SE", x = 38.4, z = -199, kind = "Crook" },
		{ key = "RW", x = -38.4, z = -228, kind = "Crook" },
		{ key = "RC", x = 6, z = -228.6, kind = "Twin" },
	}
	for _, s in spots do
		local p = at(s.x, s.z)
		local cf = if s.kind == "Twin" then CFrame.new(p) else CFrame.lookAt(p, p + Vector3.new(-math.sign(p.X), 0, 0))
		lamps[s.key] = Kit.lamp(m, s.kind, cf, { scheme = Kit.SCHEMES.Carnival, height = 9.6 + rng:NextNumber(0, 0.4) })
	end
	-- Maypole lights from the wheel's front bearing down to the deck lamps
	local apexPos = apex.Position + Vector3.new(0, 0.6, 0.8)
	local fest = Kit.model("Festoons", m)
	for j, key in { "FW", "FE", "SW", "SE" } do
		local l = lamps[key]
		Kit.stringLights(fest, apex, apexPos, l.anchor, l.top, 3.2, { spacing = 4.0, size = 0.6, offset = j })
	end
	-- Bunting from the Sunset Pier arch to the front corner lamps, and across the rear
	Kit.bunting(fest, caps[-1].part, caps[-1].pos, lamps.FW.anchor, lamps.FW.top, 1.8, { spacing = 2.3 })
	Kit.bunting(fest, caps[1].part, caps[1].pos, lamps.FE.anchor, lamps.FE.top, 1.8, { spacing = 2.3 })
	Kit.bunting(fest, lamps.RW.anchor, lamps.RW.top, lamps.RC.anchor, lamps.RC.heads[1], 1.6, { spacing = 2.4 })

	-- Flags on the side rails
	local stripeSets = {
		{ C.Coral, Kit.WHITE, C.Coral },
		{ C.Ocean, Kit.WHITE, C.Ocean },
		{ C.Gold, C.Sunset, C.Gold },
		{ C.Palm, Kit.WHITE, C.Palm },
	}
	for j, f in { { -1, -191 }, { 1, -186 }, { -1, -216 }, { 1, -219 } } do
		local p = at(f[1] * (CX - 0.4), f[2])
		Kit.solid(Kit.cyl(m, "FlagPole", 15, 0.4, CFrame.new(p + Vector3.new(0, 7.5, 0)), Kit.WHITE))
		Kit.ball(m, "FlagPoleBall", 0.7, p + Vector3.new(0, 15.3, 0), C.Gold)
		Kit.flag(m, p + Vector3.new(0, 14.4, 0), Vector3.new(1, 0, 0.12), 4.6, 2.8, stripeSets[j])
	end

	-- Rear viewing rail: benches, telescopes facing the open sea
	for _, bx in { -31, 22.5 } do
		local bp = at(bx, CZ1 + 3.6)
		Kit.bench(m, CFrame.lookAt(bp, bp - Vector3.zAxis), TONES[rng:NextInteger(1, #TONES)])
	end
	telescope(m, at(-20, CZ1 + 1.6), 180 + 15)
	telescope(m, at(14, CZ1 + 1.6), 180 - 10)
	-- Lifebuoys on the side rails
	for _, sx in { -1, 1 } do
		local p = at(sx * (CX - 0.4), -210)
		Kit.lifebuoy(m, CFrame.lookAt(p + Vector3.new(-sx * 0.55, 2.0, 0), p + Vector3.new(-sx * 5, 2.0, 0)), 0.95)
	end
	-- A little balloon bunch tied to the ticket booth queue
	local tie = at(25 - 5.6, -190 - 1.0) + Vector3.new(0, 2.3, 0)
	for j, col in { C.Coral, C.Gold, C.Ocean, C.Purple, C.Palm } do
		local a = j * 1.3
		local bp = tie + Vector3.new(math.cos(a) * 0.9, 4.0 + (j % 3) * 0.7, math.sin(a) * 0.9)
		Kit.ellipsoid(m, "Balloon", Vector3.new(1.3, 1.6, 1.3), CFrame.new(bp), col)
	end
end

function PierCarnival.Build(parent: Instance)
	local rng = Random.new(52031)
	buildPier(parent, rng)
	buildCarnival(parent, rng)
end

return PierCarnival
