--!strict
--[[
	HubPlaza — plaza ground and hub dressing (built by World/Hub.luau after the stations):
	tiled ring round the concrete plaza (open towards the Sell pad / deck path), a sun mosaic
	round the fountain, stepping-stone paths to the outer stations, lamp posts with swaying
	banners, benches (one freshly painted), planters with small palms and flowers, bunting, a
	flag gateway at the deck path, signposts and a few story props.

	Ground pieces are flush, non-colliding decor (players keep standing on the terrain, so the
	heat system's floor material is unchanged). Lamps, benches and planters collide and sit
	away from the deck -> Sell -> shops routes. Angles are measured from +Z round the hub centre.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)
local Util = require(script.Parent.Util)
local Kit = require(script.Parent.HubKit)

local C = Config.Theme.Colors
local rgb = Color3.fromRGB
local rad = math.rad
local V = Vector3.new
local box = Kit.box

local HUB = Layout.HUB_CENTER
local TERRACOTTA = rgb(226, 140, 100)
local CREAM = rgb(250, 236, 206)
local BANNERS = { C.Coral, C.Ocean, C.Gold, C.Palm, C.Purple }
local FLOWERS = { C.Coral, C.Gold, C.Purple, rgb(255, 255, 255), rgb(255, 150, 200) }

local HubPlaza = {}

local function polar(deg: number, r: number, centre: Vector3?): Vector3
	local c = centre or HUB
	return V(c.X + math.sin(rad(deg)) * r, c.Y, c.Z + math.cos(rad(deg)) * r)
end

-- flat piece lying on the visible ground at `pos`, long axis (Z) along yaw `deg`
local function flush(
	parent: Instance,
	name: string,
	pos: Vector3,
	deg: number,
	size: Vector3,
	color: Color3,
	mat: Enum.Material?
)
	local g = Kit.onSand(pos)
	local p = box(
		parent,
		name,
		CFrame.new(g + V(0, 0.06, 0)) * CFrame.Angles(0, rad(deg), 0),
		size,
		color,
		mat or Enum.Material.Slate
	)
	p.CastShadow = false
	return p
end

local function buildGround(parent: Instance)
	local m = Kit.model(parent, "PlazaGround")
	-- tiled ring (skips the south arc: Sell pad and the deck path)
	local segs = 24
	for k = 0, segs - 1 do
		local deg = (k + 0.5) * 360 / segs
		if deg < 140 or deg > 220 then
			local color = if k % 2 == 0 then TERRACOTTA else CREAM
			flush(m, "RingTile", polar(deg, 27.8), deg, V(7.1, 0.3, 3.4), color)
			flush(m, "RingBorder", polar(deg, 25.7), deg, V(6.7, 0.32, 0.6), Kit.NAVY)
		end
	end
	-- sun mosaic round the fountain
	local f = Layout.FOUNTAIN
	for k = 0, 15 do
		local deg = k * 22.5
		local long = if k % 2 == 0 then 4.6 else 3.2
		flush(
			m,
			"SunRay",
			polar(deg, 9.2 + long / 2, f),
			deg,
			V(if k % 2 == 0 then 1.8 else 1.2, 0.3, long),
			if k % 2 == 0 then C.Gold else C.Coral
		)
	end
	for k = 0, 3 do
		local deg = k * 90 + 45
		flush(m, "CompassPoint", polar(deg, 15.4, f), deg + 45, V(1.8, 0.3, 1.8), Kit.NAVY)
	end
	-- stepping stones out to the outer stations
	local rng = Random.new(505050)
	local paths = {
		{ HUB + V(0, 0, 30), Layout.LEADERBOARD_COINS:Lerp(Layout.LEADERBOARD_DEPTH, 0.5) - V(0, 0, 6) },
		{ polar(60, 30), Layout.REBIRTH - V(5, 0, 7) },
		{ polar(300, 30), Layout.EGG_ARC_CENTER + V(14, 0, -10) },
		{ V(-47, HUB.Y, 46), Layout.GARAGE + V(10, 0, 0) },
		{ V(47, HUB.Y, 42), Layout.BEACH_SHOP - V(9, 0, 0) },
	}
	for _, p in paths do
		local a, b = p[1], p[2]
		local len = (V(b.X, 0, b.Z) - V(a.X, 0, a.Z)).Magnitude
		local n = math.max(2, math.floor(len / 3.4))
		local deg = math.deg(math.atan2(b.X - a.X, b.Z - a.Z))
		for i = 0, n - 1 do
			local t = (i + 0.5) / n
			local pos = a:Lerp(b, t) + V(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5))
			local s = rng:NextNumber(2.2, 3)
			flush(m, "SteppingStone", pos, deg + rng:NextNumber(-20, 20), V(s * 1.3, 0.3, s), Kit.STONE)
		end
	end
end

local function lamp(parent: Instance, pos: Vector3, yaw: number, banner: Color3, double: boolean)
	local m = Kit.model(parent, "PlazaLamp")
	local g = Kit.onSand(pos)
	local cf = CFrame.new(g) * CFrame.Angles(0, rad(yaw), 0)
	box(m, "LampFoot", cf * CFrame.new(0, 0.4, 0), V(1.6, 0.8, 1.6), Kit.NAVY, nil, true)
	Kit.cyl(m, "LampPost", cf * CFrame.new(0, 6, 0), 11, 0.6, Kit.NAVY, Enum.Material.Metal, true)
	Kit.ball(m, "LampCollar", (cf * CFrame.new(0, 7.6, 0)).Position, 1, C.Gold)
	for _, sx in (if double then { -1, 1 } else { 1 }) :: { number } do
		box(m, "LampArm", cf * CFrame.new(sx * 1.2, 11.3, 0), V(2.6, 0.3, 0.3), Kit.NAVY, Enum.Material.Metal)
		box(m, "LampCap", cf * CFrame.new(sx * 2.3, 11.6, 0), V(1.4, 0.4, 1.4), Kit.NAVY, Enum.Material.Metal)
		Kit.neon(m, "LampGlow", cf * CFrame.new(sx * 2.3, 10.8, 0), V(1, 1.2, 1), rgb(255, 200, 110), true)
	end
	local cloth = Kit.model(m, "LampBanner")
	local hinge = cf * CFrame.new(0, 9.6, -0.5)
	box(cloth, "BannerRod", hinge, V(2.4, 0.2, 0.2), C.Gold, Enum.Material.Metal)
	box(cloth, "Banner", hinge * CFrame.new(0, -1.9, 0), V(2, 3.6, 0.1), banner, Enum.Material.Fabric)
	box(cloth, "BannerStripe", hinge * CFrame.new(0, -3.2, -0.01), V(2.02, 0.5, 0.1), Kit.TRIM, Enum.Material.Fabric)
	Kit.ambient(cloth, "AmbientSway", hinge, { SwayDegrees = 5, SwayPeriod = 3 + (yaw % 7) * 0.2 })
	return (cf * CFrame.new(0, 11.4, 0)).Position
end

local function bench(parent: Instance, pos: Vector3, facing: Vector3, color: Color3): CFrame
	local m = Kit.model(parent, "Bench")
	local cf = Util.Facing(Kit.onSand(pos), facing)
	for _, sx in { -1, 1 } do
		box(m, "BenchLeg", cf * CFrame.new(sx * 2.4, 0.9, 0), V(0.5, 1.8, 2), Kit.NAVY, Enum.Material.Metal, true)
		box(m, "BenchArm", cf * CFrame.new(sx * 2.6, 2.4, 0.1), V(0.4, 0.3, 2), Kit.NAVY, Enum.Material.Metal)
	end
	box(m, "BenchSeat", cf * CFrame.new(0, 1.9, 0), V(5.6, 0.35, 2), color, Enum.Material.WoodPlanks, true)
	box(
		m,
		"BenchBack",
		cf * CFrame.new(0, 3.1, 0.95) * CFrame.Angles(rad(-10), 0, 0),
		V(5.6, 1.4, 0.3),
		color,
		Enum.Material.WoodPlanks
	)
	return cf
end

local function planter(parent: Instance, pos: Vector3, rng: Random, palm: boolean)
	local m = Kit.model(parent, "Planter")
	local g = Kit.onSand(pos)
	local cf = CFrame.new(g)
	Kit.cyl(m, "PlanterPot", cf * CFrame.new(0, 0.8, 0), 1.6, 5.2, Kit.STONE, Enum.Material.Slate, true)
	Kit.cyl(m, "PlanterRim", cf * CFrame.new(0, 1.7, 0), 0.3, 5.6, TERRACOTTA)
	Kit.cyl(m, "PlanterSoil", cf * CFrame.new(0, 1.65, 0), 0.3, 4.6, Kit.WOOD_DEEP, Enum.Material.Ground)
	if palm then
		Kit.palm(m, g + V(0, 1.7, 0), rng:NextNumber(8, 11), rng)
		Kit.flowers(m, g + V(1.4, 1.5, 0.6), rng, FLOWERS, 3)
	else
		for k = 0, 2 do
			local a = rad(k * 120 + rng:NextNumber(-20, 20))
			Kit.flowers(m, g + V(math.cos(a) * 1.2, 1.5, math.sin(a) * 1.2), rng, FLOWERS, 3)
		end
	end
end

local function signpost(parent: Instance, pos: Vector3, arrows: { { string } })
	local m = Kit.model(parent, "Signpost")
	local g = Kit.onSand(pos)
	Kit.cyl(m, "SignpostPole", CFrame.new(g + V(0, 4.5, 0)), 9, 0.6, Kit.WOOD_DARK, Enum.Material.Wood, true)
	Kit.ball(m, "SignpostTop", g + V(0, 9.2, 0), 1, C.Gold)
	for i, a in arrows do
		local target = (Layout :: any)[a[2]] :: Vector3
		local cf = Util.Facing(g + V(0, 8.4 - i * 1.6, 0), target) * CFrame.Angles(0, rad(-90), 0)
		-- board front faces the boardwalk side; it points (X) along the way to `target`
		local board = Util.Sign(m, a[1], V(5, 1.2, 0.25), cf * CFrame.new(2.6, 0, 0), {
			Name = "Arrow",
			BoardColor = BANNERS[(i - 1) % #BANNERS + 1],
			Decor = true,
		})
		board.CastShadow = false
	end
end

local function buildDressing(parent: Instance)
	local m = Kit.model(parent, "PlazaDressing")
	local rng = Random.new(424242)
	-- lamps round the ring (between the station approaches), alternating variants
	local tops: { [number]: Vector3 } = {}
	for i, deg in { 30, 95, 150, 210, 268, 330 } do
		local d = deg + rng:NextNumber(-3, 3)
		tops[deg] =
			lamp(m, polar(d, 31 + rng:NextNumber(-0.8, 0.8)), d + 90, BANNERS[(i - 1) % #BANNERS + 1], i % 2 == 0)
	end
	Kit.bunting(m, tops[30], tops[330], 2.4, BANNERS, 9)
	Kit.bunting(m, tops[150], tops[210], 2, BANNERS, 9)
	Kit.bunting(m, tops[268], tops[210], 2.6, { C.Gold, C.Coral, C.Ocean }, 7)

	-- flag gateway where the deck path meets the hub
	for k, sx in { -1, 1 } do
		Kit.flag(m, Kit.onSand(V(sx * 17, HUB.Y, 14)), 13, if sx < 0 then 180 else 0, BANNERS[k], Kit.TRIM)
	end
	local gl, gr = Kit.onSand(V(-17, HUB.Y, 14)), Kit.onSand(V(17, HUB.Y, 14))
	Kit.bunting(m, gl + V(0, 11.5, 0), gr + V(0, 11.5, 0), 3, BANNERS, 13)

	-- benches facing the fountain (one freshly painted)
	local f = Layout.FOUNTAIN
	for i, deg in { 38, 104, 256, 318 } do
		local d = deg + rng:NextNumber(-4, 4)
		local wet = i == 3
		local cf =
			bench(m, polar(d, 18.5 + rng:NextNumber(-0.6, 0.6), f), f, if wet then rgb(120, 220, 190) else Kit.WOOD)
		if wet then
			local sign = Util.Sign(
				m,
				"WET PAINT",
				V(2.6, 1.2, 0.15),
				cf * CFrame.new(-1.2, 3.2, -1.6) * CFrame.Angles(0, 0, rad(6)),
				{
					Name = "WetPaintSign",
					BoardColor = C.Danger,
					Decor = true,
				}
			)
			sign.CastShadow = false
			box(m, "WetPaintStake", cf * CFrame.new(-1.2, 1.4, -1.65), V(0.2, 2.8, 0.2), Kit.WOOD, Enum.Material.Wood)
			Kit.cyl(m, "PaintCan", cf * CFrame.new(3.6, 0.6, -0.8), 1.2, 1, rgb(120, 220, 190))
			box(
				m,
				"PaintBrush",
				cf * CFrame.new(3.6, 1.3, -0.6) * CFrame.Angles(rad(30), 0, 0),
				V(0.3, 1.6, 0.2),
				Kit.WOOD,
				Enum.Material.Wood
			)
		end
	end

	-- planters between the approaches
	for i, deg in { 35, 88, 272, 325 } do
		planter(m, polar(deg + rng:NextNumber(-4, 4), 21.5 + rng:NextNumber(-1, 1)), rng, i % 2 == 1)
	end
	-- signposts either side of the deck path
	signpost(
		m,
		V(-21, HUB.Y, 18.5),
		{ { "SHOVELS", "SHOVEL_SHOP" }, { "PET EGGS", "EGG_ARC_CENTER" }, { "CRATES", "GARAGE" } }
	)
	signpost(
		m,
		V(21, HUB.Y, 18.5),
		{ { "BACKPACKS", "BACKPACK_SHOP" }, { "REBIRTH", "REBIRTH" }, { "BEACH SHOP", "BEACH_SHOP" } }
	)

	-- story props: a crate of collected shells by a bench, a half-built sandcastle near the hall
	local crate = Util.Facing(Kit.onSand(polar(112, 22, f)), f)
	Kit.crate(m, crate * CFrame.new(0, 1.1, 0), 2.2)
	for k = 0, 4 do
		local a = rad(k * 72 + rng:NextNumber(-20, 20))
		Kit.ball(
			m,
			"Shell",
			(crate * CFrame.new(math.cos(a) * 0.6, 2.3, math.sin(a) * 0.6)).Position,
			rng:NextNumber(0.5, 0.8),
			FLOWERS[k + 1]
		)
	end
	local castle = CFrame.new(Kit.onSand(V(29, HUB.Y, 83)))
	Kit.cyl(m, "CastleBase", castle * CFrame.new(0, 0.6, 0), 1.2, 6, Kit.SAND, Enum.Material.Sand)
	Kit.cyl(m, "CastleKeep", castle * CFrame.new(0, 2, 0), 1.8, 3, Kit.SAND, Enum.Material.Sand)
	for k = 0, 2 do
		local a = rad(k * 120 + 30)
		Kit.cyl(
			m,
			"CastleTower",
			castle * CFrame.new(math.cos(a) * 2.3, 1.7, math.sin(a) * 2.3),
			2.2,
			1.3,
			Kit.SAND,
			Enum.Material.Sand
		)
	end
	box(m, "CastleFlag", castle * CFrame.new(0.4, 3.9, 0), V(0.8, 0.5, 0.05), C.Coral, Enum.Material.Fabric)
	Kit.cyl(m, "CastleBucket", castle * CFrame.new(3.8, 0.7, 1.2), 1.4, 1.4, C.Ocean)
end

function HubPlaza.Build(parent: Instance)
	buildGround(parent)
	buildDressing(parent)
end

return HubPlaza
