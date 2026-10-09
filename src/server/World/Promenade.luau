--!strict
--[[
	Promenade — the boardwalk deck between the dig zone and the hub (players spawn on it).

	  Deck      plank segments of uneven width and five wood tones ("Deck", top = DECK_TOP),
	            darker edge boards, ocean-blue fascia on the sea edge.
	  Railing   inland side for |x| >= 96 (open in front of the hub), posts with caps, two rails,
	            beach-access gaps with gate posts.
	  Lamps     bespoke vintage lamps on the sea edge (z -2.6): crook, twin-head and tall
	            flagpole lamps in a hand-set, jittered rhythm; PointLights on a few.
	  Festoons  string lights + bunting sagging between the hub-stretch lamps and fanning from
	            the welcome arch.
	  Arch      "WELCOME TO SUNNY SANDS BEACH" over the spawns (pillars x ±38, z 10.4).
	  Clusters  benches, planters, bins, lifebuoys, foot showers, signposts and two snack carts
	            grouped along the inland edge (z 9..12), never in the stall footprints
	            (x ±130/±250/±350, z 3..11) or the spawn zone (x -24..24).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Models.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.PromenadeKit)
local Layout = require(script.Parent.Layout)
local Util = require(script.Parent.Util)

local C = Config.Theme.Colors
local rgb = Color3.fromRGB
local TOP = Layout.DECK_TOP
local Z0, Z1 = Layout.BOARDWALK_Z0, Layout.BOARDWALK_Z1
local HALF = Layout.BOUND_HALF_X - 4 -- 396
local HUB_GAP = 96 -- no inland railing within this |x| (the way up to the hub)
local LAMP_Z = Z0 + 1.4 -- -2.6
local ARCH_X, ARCH_Z = 38, 10.4

local Promenade = {}

local TONES = {
	rgb(190, 138, 90),
	rgb(178, 125, 80),
	rgb(166, 114, 70),
	rgb(198, 152, 104),
	rgb(156, 106, 66),
}

local function buildDeck(m: Model, rng: Random)
	local depth, zc = Z1 - Z0, (Z0 + Z1) / 2
	local widths = { 6, 8, 10, 10, 12, 14, 16 }
	local x, last = -HALF, 0
	while x < HALF - 0.01 do
		local x1 = math.min(x + widths[rng:NextInteger(1, #widths)], HALF)
		if HALF - x1 < 3 then
			x1 = HALF
		end
		local k = rng:NextInteger(1, #TONES)
		if k == last then
			k = k % #TONES + 1
		end
		last = k
		local deck = Kit.part(
			m,
			"Deck",
			Vector3.new(x1 - x, 1, depth),
			CFrame.new((x + x1) / 2, TOP - 0.5, zc),
			TONES[k],
			Enum.Material.WoodPlanks
		)
		Kit.solid(deck)
		deck.CastShadow = true
		x = x1
	end
	-- Edge boards: darker trim planks along both long edges (decor; the deck carries players).
	for _, z in { Z0 + 0.45 } do
		local bx = -HALF
		local i = 0
		while bx < HALF - 0.01 do
			local bx1 = math.min(bx + rng:NextNumber(44, 72), HALF)
			if HALF - bx1 < 6 then
				bx1 = HALF
			end
			i += 1
			Kit.part(
				m,
				"EdgeBoard",
				Vector3.new(bx1 - bx - 0.08, 0.26, 0.9),
				CFrame.new((bx + bx1) / 2, TOP - 0.01, z),
				if i % 2 == 0 then Kit.WOOD_DARK else rgb(138, 94, 60),
				Enum.Material.Wood
			)
			bx = bx1
		end
	end
	local trim = Kit.part(
		m,
		"Trim",
		Vector3.new(HALF * 2, 1.2, 0.4),
		CFrame.new(0, TOP - 1.2, Z0 - 0.1),
		C.Ocean,
		Enum.Material.SmoothPlastic
	)
	trim.CastShadow = false
	Kit.part(m, "TrimStripe", Vector3.new(HALF * 2, 0.22, 0.45), CFrame.new(0, TOP - 0.62, Z0 - 0.1), Kit.WHITE)
end

-- Inland railing (|x| >= HUB_GAP) with beach-access gaps; returns post positions by |x|.
local function buildRail(m: Model, sx: number, gaps: { { number } }): { [number]: Vector3 }
	local z = Z1 - 0.45
	local posts: { [number]: Vector3 } = {}
	local function inGap(ax: number, pad: number): boolean
		for _, g in gaps do
			if ax > g[1] - pad and ax < g[2] + pad then
				return true
			end
		end
		return false
	end
	local function post(ax: number, gate: boolean)
		local p = Vector3.new(sx * ax, TOP, z)
		if gate then
			Kit.solid(
				Kit.part(m, "GatePost", Vector3.new(1.0, 5.2, 1.0), CFrame.new(p + Vector3.new(0, 2.6, 0)), Kit.WHITE)
			)
			Kit.part(m, "GatePostCap", Vector3.new(1.3, 0.35, 1.3), CFrame.new(p + Vector3.new(0, 5.3, 0)), C.Ocean)
			Kit.ball(m, "GatePostBall", 0.9, p + Vector3.new(0, 5.85, 0), C.Gold)
		else
			Kit.solid(
				Kit.part(m, "RailPost", Vector3.new(0.7, 3.6, 0.7), CFrame.new(p + Vector3.new(0, 1.8, 0)), Kit.WHITE)
			)
			Kit.part(m, "RailCap", Vector3.new(0.95, 0.3, 0.95), CFrame.new(p + Vector3.new(0, 3.75, 0)), C.Ocean)
		end
		posts[ax] = p
	end
	local ax = HUB_GAP
	while ax <= HALF - 4 do
		if not inGap(ax, 1.5) then
			post(ax, false)
		end
		ax += 12
	end
	post(HALF - 0.5, false)
	for _, g in gaps do
		post(g[1], true)
		post(g[2], true)
	end
	-- Rails between gaps
	local edges = { HUB_GAP }
	for _, g in gaps do
		table.insert(edges, g[1])
		table.insert(edges, g[2])
	end
	table.insert(edges, HALF - 0.5)
	for i = 1, #edges, 2 do
		local a, b = edges[i], edges[i + 1]
		local len, cx = b - a, sx * (a + b) / 2
		Kit.solid(Kit.part(m, "Rail", Vector3.new(len, 0.35, 0.55), CFrame.new(cx, TOP + 3.4, z), Kit.WHITE))
		Kit.part(m, "RailMid", Vector3.new(len, 0.25, 0.3), CFrame.new(cx, TOP + 1.9, z), Kit.WHITE)
	end
	return posts
end

type LampSpec = { x: number, kind: string, light: boolean? }

local function lampAt(m: Model, spec: LampSpec, rng: Random): Kit.LampInfo
	local pos = Vector3.new(spec.x + rng:NextNumber(-1.5, 1.5), TOP, LAMP_Z)
	local cf = if spec.kind == "Twin" then CFrame.new(pos) else CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)) -- crook arm over the walkway
	return Kit.lamp(m, spec.kind, cf, {
		light = spec.light,
		height = if spec.kind == "Tall" then 13.5 + rng:NextNumber(0, 1.5) else 9.4 + rng:NextNumber(0, 0.5),
		wind = Vector3.new(1, 0, rng:NextNumber(-0.25, 0.25)),
		pennant = Kit.FLAGS[rng:NextInteger(1, 5)],
	})
end

-- Hand-set lamp rhythm: twins frame the spawns, singles through the hub stretch, tall flag
-- lamps where the railing starts / by the dig signs / at the ends, then a looser jittered beat.
local LAMPS: { [number]: { LampSpec } } = {
	[-1] = {
		{ x = -30, kind = "Twin", light = true },
		{ x = -53, kind = "Crook" },
		{ x = -78, kind = "Crook", light = true },
		{ x = -100, kind = "Tall" },
		{ x = -131, kind = "Crook" },
		{ x = -163, kind = "Crook" },
		{ x = -188, kind = "Twin" },
		{ x = -209, kind = "Tall", light = true },
		{ x = -271, kind = "Crook" },
		{ x = -297, kind = "Twin", light = true },
		{ x = -327, kind = "Crook" },
		{ x = -389, kind = "Tall" },
	},
	[1] = {
		{ x = 30, kind = "Twin", light = true },
		{ x = 55, kind = "Crook" },
		{ x = 80, kind = "Crook", light = true },
		{ x = 100, kind = "Tall" },
		{ x = 126, kind = "Crook" },
		{ x = 157, kind = "Twin" },
		{ x = 186, kind = "Crook" },
		{ x = 208, kind = "Tall", light = true },
		{ x = 262, kind = "Twin", light = true },
		{ x = 291, kind = "Crook" },
		{ x = 318, kind = "Crook" },
		{ x = 345, kind = "Twin" },
		{ x = 389, kind = "Tall" },
	},
}

-- Welcome arch over the spawns. Returns the two pillar-cap anchors (west, east).
local function buildArch(parent: Instance, rng: Random): { [number]: { part: BasePart, pos: Vector3 } }
	local m = Kit.model("WelcomeArch", parent)
	local caps: { [number]: { part: BasePart, pos: Vector3 } } = {}
	local pillarTop = 16.6
	for _, sx in { -1, 1 } do
		local p = Vector3.new(sx * ARCH_X, TOP, ARCH_Z)
		Kit.solid(
			Kit.part(m, "ArchPlinth", Vector3.new(3.4, 1.2, 3.2), CFrame.new(p + Vector3.new(0, 0.6, 0)), Kit.NAVY)
		)
		Kit.solid(
			Kit.part(
				m,
				"ArchPillar",
				Vector3.new(2.3, pillarTop - 1.2, 2.3),
				CFrame.new(p + Vector3.new(0, (pillarTop + 1.2) / 2, 0)),
				Kit.WHITE
			)
		)
		for i, y in { 4.2, 8.4, 12.6 } do
			Kit.part(
				m,
				"ArchBand",
				Vector3.new(2.45, 0.7, 2.45),
				CFrame.new(p + Vector3.new(0, y, 0)),
				if i == 2 then C.Ocean else C.Coral
			)
		end
		local cap = Kit.part(
			m,
			"ArchCap",
			Vector3.new(3.1, 0.8, 3.1),
			CFrame.new(p + Vector3.new(0, pillarTop + 0.4, 0)),
			C.Ocean
		)
		Kit.ball(m, "ArchFinial", 1.5, p + Vector3.new(0, pillarTop + 1.5, 0), C.Gold)
		caps[sx] = { part = cap, pos = p + Vector3.new(0, pillarTop + 0.6, 0) }
	end
	-- Curved crown: parabola from cap to cap, a row of bulbs underneath.
	local rise = 6.4
	local function arcPt(x: number): Vector3
		local t = x / ARCH_X
		return Vector3.new(x, TOP + pillarTop + 0.6 + rise * (1 - t * t), ARCH_Z)
	end
	local segs = 10
	local bulbs = Kit.model("ArchBulbs", m)
	for i = 0, segs - 1 do
		local a = arcPt(-ARCH_X + 2 * ARCH_X * i / segs)
		local b = arcPt(-ARCH_X + 2 * ARCH_X * (i + 1) / segs)
		Kit.bar(m, "ArchBeam", a, b, 1.6, 1.1, if i % 2 == 0 then C.Ocean else rgb(34, 160, 220), nil, Vector3.zAxis)
	end
	for i = 1, 2 * segs - 1 do
		local p = arcPt(-ARCH_X + ARCH_X * i / segs) + Vector3.new(0, -0.85, -0.55)
		Build.ball(bulbs, "Bulb", 0.55, CFrame.new(p), if i % 2 == 0 then C.Gold else C.Coral, Enum.Material.Neon)
	end
	Kit.tag(bulbs, Kit.NIGHT_TAG)
	-- Hanging welcome board
	local bc = Vector3.new(0, TOP + 17.4, ARCH_Z)
	local board = Kit.part(m, "WelcomeBoard", Vector3.new(31, 4.6, 0.7), CFrame.lookAt(bc, bc - Vector3.zAxis), C.Coral)
	board.CastShadow = true
	Kit.part(m, "WelcomeFrame", Vector3.new(32.2, 5.6, 0.45), CFrame.new(bc + Vector3.new(0, 0, 0.2)), C.Gold)
	for _, x in { -12, 12 } do
		local top = arcPt(x)
		Kit.rod(
			m,
			"WelcomeChain",
			Vector3.new(x, bc.Y + 2.8, ARCH_Z),
			top - Vector3.new(0, 0.5, 0),
			0.18,
			Kit.IRON,
			Enum.Material.Metal
		)
	end
	local function twoLine(face: Enum.NormalId, small: string, big: string)
		local gui = Util.SurfaceGui(board, face)
		gui.Name = "WelcomeGui" .. face.Name
		Util.Label(gui, small, C.Gold, UDim2.fromScale(0.3, 0.04), UDim2.fromScale(0.4, 0.3), Config.Theme.Fonts.Number)
		Util.Label(gui, big, C.Text, UDim2.fromScale(0.03, 0.32), UDim2.fromScale(0.94, 0.64))
	end
	twoLine(Enum.NormalId.Front, "WELCOME TO", "SUNNY SANDS BEACH")
	twoLine(Enum.NormalId.Back, "SUNNY SANDS BEACH", "HAVE A SUNNY DAY!")
	-- Smiling sun on the crown
	local sun = Vector3.new(0, TOP + pillarTop + rise + 3.4, ARCH_Z)
	local rot = CFrame.Angles(math.rad(90), 0, 0)
	Kit.cyl(m, "SunDisc", 0.7, 5.4, CFrame.new(sun) * rot, C.Gold)
	local glow = Kit.neon(m, "SunGlow", Vector3.new(1, 1, 1), CFrame.new(sun + Vector3.new(0, 0, 0.2)), C.Sunset)
	glow.Shape = Enum.PartType.Cylinder
	glow.Size = Vector3.new(0.5, 6.2, 6.2)
	glow.CFrame = CFrame.new(sun + Vector3.new(0, 0, 0.25)) * CFrame.Angles(0, math.rad(90), 0)
	for i = 0, 9 do
		local a = i * math.pi * 2 / 10 + rng:NextNumber(-0.05, 0.05)
		local dir = Vector3.new(math.cos(a), math.sin(a), 0)
		Kit.tri(
			m,
			"SunRay",
			sun + dir * 3.0,
			sun + dir * (if i % 2 == 0 then 5.0 else 4.3),
			Vector3.zAxis:Cross(dir),
			1.3,
			0.4,
			if i % 2 == 0 then C.Sunset else C.Gold
		)
	end
	Build.face(m, CFrame.lookAt(sun + Vector3.new(0, 0, -0.36), sun + Vector3.new(0, 0, -5)), 3.2, { radius = 0 })
	Kit.light(glow, C.Gold, 16, 1.1)
	return caps
end

type Item = { kind: string, x: number }

-- Inland-edge clusters (odd groupings, open deck between them).
local ITEMS: { Item } = {
	-- west
	{ kind = "SignWest", x = -28 },
	{ kind = "PalmPlanter", x = -45 },
	{ kind = "Trash", x = -50.5 },
	{ kind = "IceCream", x = -66 },
	{ kind = "FlowerPlanter", x = -88 },
	{ kind = "Bench", x = -108 },
	{ kind = "PalmPlanter", x = -114.5 },
	{ kind = "Trash", x = -119 },
	{ kind = "Recycle", x = -151.5 },
	{ kind = "Trash", x = -154 },
	{ kind = "Bench", x = -161 },
	{ kind = "FlowerPlanter", x = -167.5 },
	{ kind = "RailBuoy", x = -216 },
	{ kind = "Shower", x = -224 },
	{ kind = "PalmPlanter", x = -232 },
	{ kind = "Bench", x = -279 },
	{ kind = "PalmPlanter", x = -285.5 },
	{ kind = "Bench", x = -292 },
	{ kind = "Trash", x = -297 },
	{ kind = "Recycle", x = -333 },
	{ kind = "FlowerPlanter", x = -366 },
	{ kind = "Bench", x = -373 },
	{ kind = "PalmPlanter", x = -380 },
	-- east
	{ kind = "SignEast", x = 28 },
	{ kind = "FlowerPlanter", x = 47 },
	{ kind = "Recycle", x = 57 },
	{ kind = "Lemonade", x = 70 },
	{ kind = "PalmPlanter", x = 86 },
	{ kind = "Trash", x = 104 },
	{ kind = "Bench", x = 110 },
	{ kind = "FlowerPlanter", x = 116.5 },
	{ kind = "Shower", x = 146 },
	{ kind = "RailBuoy", x = 152 },
	{ kind = "Bench", x = 193 },
	{ kind = "PalmPlanter", x = 199.5 },
	{ kind = "Trash", x = 205 },
	{ kind = "Recycle", x = 207.5 },
	{ kind = "FlowerPlanter", x = 232 },
	{ kind = "Bench", x = 266 },
	{ kind = "Bench", x = 272 },
	{ kind = "PalmPlanter", x = 278.5 },
	{ kind = "BuoyPost", x = 318 },
	{ kind = "FlowerPlanter", x = 324 },
	{ kind = "Trash", x = 330 },
	{ kind = "Bench", x = 364 },
	{ kind = "PalmPlanter", x = 371 },
	{ kind = "Recycle", x = 378 },
	{ kind = "Shower", x = 386 },
}

local function placeItems(m: Model, rng: Random, posts: { [number]: { [number]: Vector3 } })
	local hub = Layout.HUB_CENTER
	local function seaFrame(x: number, z: number, yawJitter: number): CFrame
		local p = Vector3.new(x, TOP, z)
		return CFrame.lookAt(p, p - Vector3.zAxis)
			* CFrame.Angles(0, math.rad(rng:NextNumber(-yawJitter, yawJitter)), 0)
	end
	for _, it in ITEMS do
		local x = it.x + rng:NextNumber(-0.4, 0.4)
		local k = it.kind
		if k == "Bench" then
			Kit.bench(m, seaFrame(x, 10.15, 4), TONES[rng:NextInteger(1, #TONES)])
		elseif k == "PalmPlanter" then
			Kit.planter(m, seaFrame(x, 10.2, 6), "Palm", rng)
		elseif k == "FlowerPlanter" then
			Kit.planter(m, seaFrame(x, 10.2, 6), "Flowers", rng)
		elseif k == "Trash" or k == "Recycle" then
			Kit.bin(m, Vector3.new(x, TOP, 10.4 + rng:NextNumber(-0.2, 0.2)), k)
		elseif k == "BuoyPost" then
			Kit.lifebuoyPost(m, seaFrame(x, 10.4, 5))
		elseif k == "RailBuoy" then
			local sx = if it.x < 0 then -1 else 1
			local best: Vector3? = nil
			for ax, p in posts[sx] do
				if best == nil or math.abs(ax - math.abs(it.x)) < math.abs((best :: Vector3).X - it.x) then
					best = p
				end
			end
			if best then
				local p = best :: Vector3
				Kit.lifebuoy(m, CFrame.lookAt(p + Vector3.new(0, 2.2, -0.65), p + Vector3.new(0, 2.2, -5)), 0.95)
			end
		elseif k == "Shower" then
			Kit.shower(m, seaFrame(x, 10.0, 0))
		elseif k == "IceCream" or k == "Lemonade" then
			Kit.cart(m, seaFrame(x, 9.3, 8), k)
		elseif k == "SignWest" then
			Kit.signpost(m, Vector3.new(x, TOP, 10.2), {
				{ text = "SELL", target = Layout.SELL, color = C.Gold },
				{ text = "SHOVELS", target = Layout.SHOVEL_SHOP, color = C.Coral },
				{ text = "PETS", target = Layout.EGG_ARC_CENTER, color = C.Purple },
				{ text = "PIER", target = Vector3.new(0, TOP, Layout.PIER_Z0), color = C.Ocean },
			})
		elseif k == "SignEast" then
			Kit.signpost(m, Vector3.new(x, TOP, 10.2), {
				{ text = "SELL", target = Layout.SELL, color = C.Gold },
				{ text = "BACKPACKS", target = Layout.BACKPACK_SHOP, color = C.Palm },
				{ text = "REBIRTH", target = Layout.REBIRTH, color = C.Purple },
				{ text = "PIER", target = Vector3.new(0, TOP, Layout.PIER_Z0), color = C.Ocean },
				{ text = "HUB", target = hub, color = C.Coral },
			})
		end
	end
	-- A couple of lifeguard buoys on the sea edge, facing the hub.
	for _, x in { -252.5 } do
		local p = Vector3.new(x, TOP, LAMP_Z + 0.2)
		Kit.lifebuoyPost(m, CFrame.lookAt(p, p + Vector3.zAxis))
	end
end

local function festoon(
	m: Model,
	rng: Random,
	lamps: { [number]: { Kit.LampInfo } },
	caps: { [number]: { part: BasePart, pos: Vector3 } }
)
	for _, sx in { -1, 1 } do
		local row = lamps[sx]
		-- row[1] twin (±30), row[2] crook, row[3] crook, row[4] tall (±100)
		local twin, c1, c2, tall = row[1], row[2], row[3], row[4]
		local outer = twin.heads[if sx < 0 then 1 else 2]
		Kit.stringLights(m, twin.anchor, outer, c1.anchor, c1.top, 1.4, { offset = rng:NextInteger(0, 5) })
		Kit.bunting(m, c1.anchor, c1.top - Vector3.new(0, 0.3, 0), c2.anchor, c2.top - Vector3.new(0, 0.3, 0), 1.9)
		Kit.stringLights(
			m,
			c2.anchor,
			c2.top,
			tall.anchor,
			tall.top - Vector3.new(0, 1.2, 0),
			1.3,
			{ offset = rng:NextInteger(0, 5) }
		)
		-- Fan of lights from the arch pillar down to the deck lamps
		local cap = caps[sx]
		Kit.stringLights(m, cap.part, cap.pos, twin.anchor, outer, 1.2, { spacing = 2.3 })
	end
	-- Bunting across the front of the spawns, twin to twin
	local w, e = lamps[-1][1], lamps[1][1]
	Kit.bunting(m, w.anchor, w.heads[2], e.anchor, e.heads[1], 2.0, { spacing = 2.4, h = 1.7 })
end

function Promenade.Build(parent: Instance)
	local rng = Random.new(41017)
	local m = Kit.model("Promenade", parent)
	buildDeck(m, rng)
	local posts = {
		[-1] = buildRail(m, -1, { { 180, 188 }, { 308, 316 } }),
		[1] = buildRail(m, 1, { { 172, 180 }, { 300, 308 } }),
	}
	local lampFolder = Kit.model("Lamps", m)
	local lamps: { [number]: { Kit.LampInfo } } = { [-1] = {}, [1] = {} }
	for sx, list in LAMPS do
		for _, spec in list do
			table.insert(lamps[sx], lampAt(lampFolder, spec, rng))
		end
	end
	local caps = buildArch(m, rng)
	festoon(Kit.model("Festoons", m), rng, lamps, caps)
	placeItems(Kit.model("Furniture", m), rng, posts)
end

return Promenade
