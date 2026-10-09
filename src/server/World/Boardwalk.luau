--!strict
--[[
	Boardwalk — Stream B entry point: the promenade (Promenade.luau), Sunset Pier and its carnival
	(PierCarnival.luau), the "dig anywhere" markers and zone-end flags, the marquee title sign with
	a giant shovel and treasure chest in the dunes, and the invisible boundary walls.
	Shared builders live in PromenadeKit.luau.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Models.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.PromenadeKit)
local Layout = require(script.Parent.Layout)
local PierCarnival = require(script.Parent.PierCarnival)
local Promenade = require(script.Parent.Promenade)
local Util = require(script.Parent.Util)

local C = Config.Theme.Colors
local rgb = Color3.fromRGB
local S = Layout.SURFACE_Y
local VISIBLE = S + Layout.VISIBLE_SURFACE_OFFSET -- visible sand height

local Boardwalk = {}

-- Marquee title sign at TITLE_SIGN facing the boardwalk (-Z), giant shovel east, chest west.
local function buildTitle(parent: Instance)
	local m = Kit.model("TitleSign", parent)
	local p = Layout.TITLE_SIGN
	local base = Util.Facing(p, Vector3.new(p.X, p.Y, 0)) -- local axes = world axes, front = -Z
	local function L(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	local g = VISIBLE - p.Y -- local y of the visible sand
	-- Striped posts
	for _, x in { -23, 23 } do
		Kit.solid(Kit.part(m, "PostFooting", Vector3.new(3.4, 1.6, 3.4), L(x, g + 0.3, 0.9), Kit.NAVY))
		Kit.solid(Kit.part(m, "Post", Vector3.new(2.2, 28, 2.2), L(x, g + 14, 0.9), Kit.WHITE))
		for i = 1, 4 do
			Kit.part(
				m,
				"PostStripe",
				Vector3.new(2.35, 1.1, 2.35),
				L(x, g + 2.5 + i * 2.6, 0.9),
				if i % 2 == 0 then C.Ocean else C.Coral
			)
		end
		Kit.part(m, "PostCap", Vector3.new(3.0, 0.9, 3.0), L(x, g + 28.4, 0.9), C.Gold)
		Kit.ball(m, "PostFinial", 1.8, base:PointToWorldSpace(Vector3.new(x, g + 29.7, 0.9)), C.Coral)
	end
	-- Layered board: navy back plate, gold frame, ocean main board, coral ribbon
	local cy = g + 20
	local back = Kit.part(m, "TitleBack", Vector3.new(52, 17, 1.4), L(0, cy, 1.4), Kit.NAVY)
	back.CastShadow = true
	for _, bar in
		{
			{ Vector3.new(50, 1.4, 1.2), Vector3.new(0, 7.3, -0.1) },
			{ Vector3.new(50, 1.4, 1.2), Vector3.new(0, -7.3, -0.1) },
			{ Vector3.new(1.4, 16, 1.2), Vector3.new(-24.3, 0, -0.1) },
			{ Vector3.new(1.4, 16, 1.2), Vector3.new(24.3, 0, -0.1) },
		}
	do
		Kit.part(m, "TitleFrame", bar[1], L(bar[2].X, cy + bar[2].Y, bar[2].Z), C.Gold, Enum.Material.Metal)
	end
	local board = Util.Sign(m, "DIG TO THE CORE!", Vector3.new(46.4, 9.6, 1), L(0, cy + 1.6, 0), {
		Name = "TitleBoard",
		BoardColor = C.Ocean,
		Decor = true,
	})
	board.CastShadow = true
	local ribbon = Util.Sign(m, "BEACH SIMULATOR", Vector3.new(30, 3.4, 0.8), L(0, cy - 5.2, -0.9), {
		Name = "TitleRibbon",
		BoardColor = C.Coral,
		Decor = true,
	})
	ribbon.CastShadow = true
	for _, sx in { -1, 1 } do
		-- folded ribbon tails
		Kit.wedge(
			m,
			"RibbonTail",
			Vector3.new(0.7, 3.4, 3),
			L(sx * 16.3, cy - 5.9, -0.7) * CFrame.Angles(0, math.rad(sx * 90), 0),
			Build.darken(C.Coral, 0.2)
		)
	end
	-- Marquee bulb border (alternating gold / sunset)
	local bulbs = Kit.model("MarqueeBulbs", m)
	local hw, hh = 25.0, 8.0
	local per = 4 * hw + 4 * hh
	local n = 56
	for i = 0, n - 1 do
		local d = per * i / n
		local x, y
		if d < 2 * hw then
			x, y = -hw + d, hh
		elseif d < 2 * hw + 2 * hh then
			x, y = hw, hh - (d - 2 * hw)
		elseif d < 4 * hw + 2 * hh then
			x, y = hw - (d - 2 * hw - 2 * hh), -hh
		else
			x, y = -hw, -hh + (d - 4 * hw - 2 * hh)
		end
		local b = Build.ball(
			bulbs,
			"Bulb",
			0.75,
			L(x, cy + y, -0.85),
			if i % 2 == 0 then C.Gold else C.Sunset,
			Enum.Material.Neon
		)
		b.CastShadow = false
		if i == 6 or i == 22 then
			Kit.light(b, C.Gold, 16, 1.2)
		end
	end
	Kit.tag(bulbs, Kit.NIGHT_TAG)
	-- Sunburst crest behind the top
	local crest = base:PointToWorldSpace(Vector3.new(0, cy + 9.4, 1.8))
	Kit.cyl(m, "Crest", 0.8, 9, CFrame.new(crest) * CFrame.Angles(math.rad(90), 0, 0), C.Gold)
	for i = 0, 8 do
		local a = math.rad(i * 22.5)
		local dir = Vector3.new(math.cos(a), math.sin(a), 0)
		Kit.tri(
			m,
			"CrestRay",
			crest + dir * 4.2,
			crest + dir * 7.4,
			Vector3.zAxis:Cross(dir),
			2.0,
			0.5,
			if i % 2 == 0 then C.Sunset else C.Gold
		)
	end

	-- Giant shovel stuck in a sand mound (east)
	local sp = base:PointToWorldSpace(Vector3.new(36, g, 2))
	Kit.ellipsoid(
		m,
		"ShovelMound",
		Vector3.new(11, 3.2, 9),
		CFrame.new(sp + Vector3.new(0, 0.4, 0)),
		C.SandDark,
		Enum.Material.Sand
	)
	local steel = rgb(200, 210, 225)
	local tilt = CFrame.new(sp) * CFrame.Angles(0, math.rad(-20), math.rad(-14))
	local blade =
		Kit.part(m, "GiantShovelBlade", Vector3.new(7, 7, 1), tilt * CFrame.new(0, 2.6, 0), steel, Enum.Material.Metal)
	blade.Reflectance = 0.2
	Kit.solid(blade)
	Kit.cyl(
		m,
		"GiantShovelTip",
		1,
		7,
		tilt * CFrame.new(0, -0.9, 0) * CFrame.Angles(math.rad(90), 0, 0),
		steel,
		Enum.Material.Metal
	)
	Kit.part(
		m,
		"GiantShovelCollar",
		Vector3.new(2.2, 1.6, 1.6),
		tilt * CFrame.new(0, 6.8, 0),
		C.Gold,
		Enum.Material.Metal
	)
	Kit.solid(
		Kit.cyl(m, "GiantShovelHandle", 20, 1.4, tilt * CFrame.new(0, 17.4, 0), rgb(170, 110, 60), Enum.Material.Wood)
	)
	for _, sx in { -1, 1 } do
		Kit.rod(
			m,
			"GiantShovelYoke",
			tilt:PointToWorldSpace(Vector3.new(0, 27, 0)),
			tilt:PointToWorldSpace(Vector3.new(sx * 2.0, 29, 0)),
			0.9,
			C.Coral
		)
	end
	Kit.rod(
		m,
		"GiantShovelGrip",
		tilt:PointToWorldSpace(Vector3.new(-2.3, 29.2, 0)),
		tilt:PointToWorldSpace(Vector3.new(2.3, 29.2, 0)),
		1.1,
		C.Coral
	)

	-- Overflowing treasure chest (west)
	local cp = base:PointToWorldSpace(Vector3.new(-36, g, 1))
	local ccf = CFrame.lookAt(cp, cp + Vector3.new(0.35, 0, -1))
	local wood = rgb(130, 78, 44)
	Kit.solid(Kit.part(m, "ChestBody", Vector3.new(7, 4, 4.6), ccf * CFrame.new(0, 2, 0), wood, Enum.Material.Wood))
	for _, x in { -2.6, 0, 2.6 } do
		Kit.part(m, "ChestBand", Vector3.new(0.5, 4.1, 4.7), ccf * CFrame.new(x, 2, 0), C.Gold, Enum.Material.Metal)
	end
	Kit.part(m, "ChestLock", Vector3.new(1.1, 1.3, 0.3), ccf * CFrame.new(0, 3.2, -2.4), C.Gold, Enum.Material.Metal)
	local lid = ccf * CFrame.new(0, 4, 2.3) * CFrame.Angles(math.rad(-105), 0, 0) * CFrame.new(0, 0, -2.3)
	Kit.part(m, "ChestLid", Vector3.new(7, 0.7, 4.6), lid, wood, Enum.Material.Wood)
	Kit.part(m, "ChestLidBand", Vector3.new(7.1, 0.75, 0.5), lid * CFrame.new(0, 0, -2.0), C.Gold, Enum.Material.Metal)
	local pile = Kit.ellipsoid(
		m,
		"GoldPile",
		Vector3.new(6.4, 2.4, 4.0),
		ccf * CFrame.new(0, 4.1, 0),
		C.Gold,
		Enum.Material.Metal
	)
	pile.Reflectance = 0.15
	Kit.sparkle(pile, C.Gold, 6)
	local crng = Random.new(77011)
	for _ = 1, 7 do
		local off = Vector3.new(crng:NextNumber(-6, 6), 0.15, crng:NextNumber(-4.5, -1.5))
		local tiltC = CFrame.Angles(crng:NextNumber(-0.3, 0.3), 0, crng:NextNumber(-0.3, 0.3))
		Kit.cyl(m, "Coin", 0.25, 1.2, CFrame.new(ccf:PointToWorldSpace(off)) * tiltC, C.Gold, Enum.Material.Metal)
	end
	for j, col in { C.Coral, C.Ocean, C.Purple } do
		local gp = ccf:PointToWorldSpace(Vector3.new(-2 + j * 1.2, 5.1, crng:NextNumber(-0.8, 0.8)))
		Kit.ball(m, "Gem", 0.9, gp, col, Enum.Material.Glass)
	end
end

local function buildBoundaries(parent: Instance)
	local f = Util.Folder("Boundaries", parent)
	local hx, zn, zs = Layout.BOUND_HALF_X, Layout.BOUND_NORTH_Z, Layout.BOUND_SOUTH_Z
	local y0, y1 = Layout.SEABED_Y - 10, S + 90
	local h, yc = y1 - y0, (y0 + y1) / 2
	local walls: { { Vector3 } } = {
		{ Vector3.new(4, h, zn - zs), Vector3.new(-hx - 2, yc, (zn + zs) / 2) },
		{ Vector3.new(4, h, zn - zs), Vector3.new(hx + 2, yc, (zn + zs) / 2) },
		{ Vector3.new(hx * 2 + 8, h, 4), Vector3.new(0, yc, zn + 2) },
		{ Vector3.new(hx * 2 + 8, h, 4), Vector3.new(0, yc, zs - 2) },
	}
	for _, w in walls do
		local p = Util.Part({
			Name = "Boundary",
			Size = w[1],
			CFrame = CFrame.new(w[2]),
			Transparency = 1,
			CastShadow = false,
			Parent = f,
		})
		p.CanQuery = false
	end
end

-- "Dig anywhere" signs on the deck's sea edge and striped flags at the dig zone corners.
local function buildDigMarkers(parent: Instance)
	local m = Kit.model("DigMarkers", parent)
	local z = Layout.BOARDWALK_Z0 + 2
	for _, x in { -40, 40, -200, 200 } do
		local p = Vector3.new(x, Layout.DECK_TOP, z)
		for _, sx in { -1, 1 } do
			local postPos = p + Vector3.new(sx * 3.6, 2.8, 0.7)
			Kit.solid(
				Kit.part(
					m,
					"SignPost",
					Vector3.new(0.7, 5.6, 0.7),
					CFrame.new(postPos),
					Kit.WOOD_DARK,
					Enum.Material.Wood
				)
			)
			Kit.ball(m, "SignPostKnob", 0.8, p + Vector3.new(sx * 3.6, 5.8, 0.7), C.Coral)
		end
		-- Faces inland so it reads while walking down from the hub.
		local face = CFrame.lookAt(p + Vector3.new(0, 4.4, 0.4), p + Vector3.new(0, 4.4, 10))
		Kit.part(m, "DigSignBack", Vector3.new(9.6, 3.4, 0.35), face * CFrame.new(0, 0, 0.3), Kit.NAVY)
		Util.Sign(m, "DIG ANYWHERE!", Vector3.new(8.8, 2.7, 0.4), face, {
			Name = "DigSign",
			BoardColor = C.Gold,
			SubText = "ON THE SAND",
			Decor = true,
		})
		-- Little shovel stuck in the top of the board + arrow pointing down to the sand
		local tip = face:PointToWorldSpace(Vector3.new(3.4, 1.4, 0.2))
		Kit.rod(m, "SignShovelHandle", tip, tip + Vector3.new(0.6, 2.4, 0), 0.22, Kit.WOOD)
		Kit.part(
			m,
			"SignShovelBlade",
			Vector3.new(1.0, 1.1, 0.15),
			CFrame.new(tip + Vector3.new(-0.1, -0.2, 0)) * CFrame.Angles(0, 0, math.rad(-14)),
			rgb(200, 210, 225),
			Enum.Material.Metal
		)
		local ab = face:PointToWorldSpace(Vector3.new(0, -1.8, 0))
		Kit.tri(m, "DigArrow", ab, ab - Vector3.new(0, 1.2, 0), Vector3.xAxis, 1.6, 0.3, C.Coral)
	end
	-- Striped flags at the four corners of the dig zone, poles on the visible sand
	local stripes = { C.Coral, Kit.WHITE, C.Coral }
	for _, sx in { -1, 1 } do
		for _, zEdge in { Layout.DIG_Z_INLAND, Layout.DIG_Z_SEA } do
			local p = Vector3.new(sx * (Layout.DIG_HALF_X + 2), VISIBLE, zEdge)
			Kit.part(m, "ZoneFlagFoot", Vector3.new(1.4, 0.6, 1.4), CFrame.new(p + Vector3.new(0, 0.1, 0)), Kit.NAVY)
			Kit.solid(Kit.cyl(m, "ZoneFlagPole", 11, 0.45, CFrame.new(p + Vector3.new(0, 5.5, 0)), Kit.WHITE))
			for i = 1, 3 do
				Kit.cyl(m, "ZoneFlagPoleStripe", 0.8, 0.5, CFrame.new(p + Vector3.new(0, i * 2.4, 0)), C.Coral)
			end
			Kit.ball(m, "ZoneFlagBall", 0.7, p + Vector3.new(0, 11.2, 0), C.Gold)
			local flag = Kit.flag(m, p + Vector3.new(0, 10.4, 0), Vector3.new(-sx, 0, 0.15), 3.8, 2.4, stripes)
			flag.Name = "ZoneFlag"
		end
	end
end

function Boardwalk.Build(parent: Instance)
	Kit.Stats.lights = 0
	Kit.Stats.emitters = 0
	Promenade.Build(parent)
	PierCarnival.Build(parent)
	buildDigMarkers(parent)
	buildTitle(parent)
	buildBoundaries(parent)
end

return Boardwalk
