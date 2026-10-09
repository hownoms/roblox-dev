--!strict
--[[
	Hub — the plaza inland of the boardwalk: spawns (on the boardwalk deck), the Sand Exchange
	(sell stand), the free Water Fountain, and (via the Hub* modules) every other station plus
	the plaza ground and dressing:
	  HubShops        ShovelShop "Digger's Hardware", BackpackShop "Surf & Pack Outfitters",
	                  BeachShop tiki snack bar
	  HubAttractions  EggIncubator hatchery, CrateYard construction yard, RebirthShrine temple,
	                  LeaderboardCoins / LeaderboardDepth + HallOfFame
	  HubPlaza        tiled plaza ring, sun mosaic, stepping-stone paths, lamps with banners,
	                  benches, planters, bunting, flags, signposts and story props
	  HubKit          shared part-building helpers
	Hero structures are built from Parts in a local frame whose -Z (front) faces the boardwalk
	spawns. Each station is its own Model (StreamingService makes it Atomic).

	Tags placed: SpawnLocation, SellZone, ShovelShop, BackpackShop, EggShop (one per egg, with
	attribute EggId on the part and on its ProximityPrompt), CrateShop (one per Construction Crate,
	same EggId attribute; EggPanel hooks its "Open" prompt), RebirthStatue, LeaderboardCoins,
	LeaderboardDepth, WaterFountain (prompt "Drink"), BeachShop (prompt "Shop"). Survival /
	Companions clients handle those prompts. Ambient motion tags (docs/MAP_ART_DIRECTION.md):
	AmbientSpin (coin, portal ring, halo), AmbientSway (flags, banners, crane load), AmbientBob
	(rebirth orbs), AmbientNightLight (lamps, lights).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Models = require(ReplicatedStorage.Shared.Models)
local Build = require(ReplicatedStorage.Shared.Models.Build)
local Layout = require(script.Parent.Layout)
local Util = require(script.Parent.Util)
local Kit = require(script.Parent.HubKit)
local HubShops = require(script.Parent.HubShops)
local HubAttractions = require(script.Parent.HubAttractions)
local HubPlaza = require(script.Parent.HubPlaza)

local C = Config.Theme.Colors
local rgb = Color3.fromRGB
local rad = math.rad
local V = Vector3.new
local at = Kit.at
local box = Kit.box
local WHITE = Kit.WHITE
local MARBLE = Kit.MARBLE
local MARBLE_MAT = Enum.Material.Marble
local METAL = Enum.Material.Metal

local Hub = {}

-- Spawns --------------------------------------------------------------------------------------

local function buildSpawns(parent: Instance)
	local colors = { C.Coral, C.Ocean, C.Gold }
	for i, pos in Layout.SPAWNS do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn" .. i
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.AllowTeamChangeOnTouch = false
		spawn.Duration = 0
		spawn.Size = V(8, 1, 8)
		-- On the boardwalk deck, facing the sand / ocean (-Z)
		spawn.CFrame = CFrame.lookAt(pos + V(0, 0.5, 0), pos + V(0, 0.5, -10))
		spawn.Color = colors[(i - 1) % #colors + 1]
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.BottomSurface = Enum.SurfaceType.Smooth
		spawn.Parent = parent
		Util.Tag(spawn, "SpawnLocation")
		-- White rim
		Util.Part({
			Name = "SpawnRim",
			Size = V(9, 0.6, 9),
			CFrame = CFrame.new(pos + V(0, 0.3, 0)),
			Color = WHITE,
			Decor = true,
			Parent = parent,
		})
	end
end

-- Sand Exchange (sell stand) ------------------------------------------------------------------

local function giantCoin(m: Model, coinCF: CFrame)
	local coin = Kit.model(m, "GiantCoin")
	local function disc(name: string, thick: number, d: number, color: Color3): Part
		local p = Util.Part({
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = V(thick, d, d),
			-- part X (cylinder axis) = coin Z, part Y = coin Y: face text stays upright
			CFrame = coinCF * CFrame.Angles(0, rad(-90), 0),
			Color = color,
			Material = METAL,
			Reflectance = 0.3,
			Decor = true,
			Parent = coin,
		})
		p.CastShadow = true
		return p
	end
	disc("CoinRim", 1.2, 11, C.Gold)
	local face = disc("CoinFace", 1.5, 8.6, rgb(232, 172, 24))
	for _, f in { Enum.NormalId.Right, Enum.NormalId.Left } do
		local gui = Util.SurfaceGui(face, f)
		gui.Name = "CoinGui"
		Util.Label(gui, "$", rgb(255, 236, 140), UDim2.fromScale(0.2, 0.1), UDim2.fromScale(0.6, 0.8))
	end
	Build.sparkle(face, C.Gold, 5)
	Kit.ambient(coin, "AmbientSpin", coinCF, { SpinRPM = 8, SpinAxis = V(0, 1, 0) })
end

local function sandScale(m: Model, cf: CFrame)
	box(m, "ScaleBase", cf * CFrame.new(0, 0.2, 0), V(2, 0.4, 1.2), Kit.WOOD_DEEP)
	box(m, "ScalePost", cf * CFrame.new(0, 1.8, 0), V(0.3, 3, 0.3), C.Gold, METAL)
	box(m, "ScaleBeam", cf * CFrame.new(0, 3.3, 0) * CFrame.Angles(0, 0, rad(-8)), V(4.2, 0.25, 0.25), C.Gold, METAL)
	Kit.cyl(m, "ScalePan", cf * CFrame.new(-1.9, 2.3, 0), 0.2, 1.7, C.Gold, METAL)
	Kit.cyl(m, "ScalePan", cf * CFrame.new(1.9, 2.9, 0), 0.2, 1.7, C.Gold, METAL)
	Kit.ball(m, "ScaleSand", (cf * CFrame.new(-1.9, 2.6, 0)).Position, 1.1, Kit.SAND, Enum.Material.Sand)
	Kit.cyl(m, "ScaleCoins", cf * CFrame.new(1.9, 3.15, 0), 0.3, 1.1, C.Gold, METAL)
end

local function buildSell(parent: Instance)
	local m = Kit.model(parent, "SellStand")
	-- Faces the beach so players walking up from the sand see it first.
	local base = Util.Facing(Kit.onSand(Layout.SELL), Layout.SELL + V(0, 0, -10))
	local cream = C.PanelAlt
	local goldDeep = rgb(214, 156, 30)
	local rng = Random.new(28028)

	-- counter (pinned: parts named "Counter" stand on the visible sand)
	box(m, "Counter", at(base, 0, 1.8, 0), V(16, 3.6, 4), C.Coral, nil, true)
	box(m, "CounterTop", at(base, 0, 3.85, 0), V(17, 0.5, 5), Kit.WOOD, Enum.Material.WoodPlanks, true)
	for i = -2, 2 do
		box(m, "CounterStripe", at(base, i * 3.2, 1.8, -2.05), V(1.2, 3.6, 0.2), WHITE)
	end
	box(m, "CounterKick", at(base, 0, 0.3, -2.1), V(16.2, 0.6, 0.3), C.Coral:Lerp(Color3.new(0, 0, 0), 0.3))

	-- Touch pad in front of the counter (keep the deck -> pad line clear)
	local pad = box(m, "SellZone", at(base, 0, 0.2, -6.5), V(16, 1, 8), rgb(50, 170, 75))
	pad.Transparency = 0.3
	pad.CanTouch = true
	pad.CastShadow = false
	Util.Tag(pad, "SellZone")
	local gui = Util.SurfaceGui(pad, Enum.NormalId.Top)
	Util.Label(gui, "SELL HERE!", WHITE, UDim2.fromScale(0.05, 0.1), UDim2.fromScale(0.9, 0.8))

	-- the exchange building behind the counter
	box(m, "Plinth", at(base, 0, 0.4, 7.4), V(26, 0.8, 11.6), Kit.STONE_DARK, Enum.Material.Slate, true)
	box(m, "BackWall", at(base, 0, 7.3, 12), V(22, 13, 1), cream, nil, true)
	box(m, "BackWainscot", at(base, 0, 2.9, 12.6), V(22.2, 4, 0.3), goldDeep)
	for _, sx in { -1, 1 } do
		box(m, "SideWall", at(base, sx * 11, 7.3, 7), V(1, 13, 10), cream, nil, true)
		box(m, "SideWainscot", at(base, sx * 11.6, 2.9, 7), V(0.3, 4, 10.2), goldDeep)
		for _, z in { 2, 12 } do
			box(m, "Pilaster", at(base, sx * 11, 7.6, z), V(1.8, 14.4, 1.8), Kit.TRIM, nil, true)
		end
		Kit.window(m, at(base, sx * 11.65, 8.4, 7, 0, sx * -90, 0), 3.6, 3.4, Kit.TRIM)
		Kit.window(m, at(base, sx * 6, 8.4, 12.65, 0, 180, 0), 4, 3.4, Kit.TRIM)
	end
	box(m, "Cornice", at(base, 0, 14.3, 7), V(24.6, 1, 12.6), C.Gold)
	box(m, "Roof", at(base, 0, 15.1, 7), V(23, 0.6, 11), Kit.TRIM)
	Kit.neon(m, "CorniceGlow", at(base, 0, 13.65, 0.55), V(24.2, 0.3, 0.3), C.Gold, true)
	-- vault door on the inside of the back wall
	local vault = at(base, 0, 7.2, 11.35)
	Kit.cyl(m, "VaultDoor", vault * CFrame.Angles(rad(90), 0, 0), 0.4, 7, Kit.STEEL, METAL)
	Kit.cyl(m, "VaultRing", vault * CFrame.new(0, 0, -0.15) * CFrame.Angles(rad(90), 0, 0), 0.4, 5.4, C.Gold, METAL)
	for k = 0, 1 do
		box(
			m,
			"VaultSpoke",
			vault * CFrame.new(0, 0, -0.45) * CFrame.Angles(0, 0, rad(45 + k * 90)),
			V(4, 0.35, 0.3),
			Kit.STEEL_DARK,
			METAL
		)
	end

	-- western false front: SELL sign, crown with SAND EXCHANGE, giant spinning coin above
	box(m, "Facade", at(base, 0, 19.2, 2.4), V(22, 8.4, 1), C.Coral, nil, true)
	box(m, "FacadeCap", at(base, 0, 23.6, 2.4), V(22.8, 0.6, 1.4), C.Gold)
	box(m, "Crown", at(base, 0, 25.2, 2.4), V(11, 2.6, 1), C.Gold)
	Kit.cyl(m, "CrownArc", at(base, 0, 26.4, 2.4) * CFrame.Angles(rad(90), 0, 0), 1, 6.4, C.Gold)
	Util.Sign(m, "SELL", V(20, 7, 1), at(base, 0, 19.2, 1.6), {
		Name = "SellSign",
		BoardColor = C.Gold,
		SubText = "SAND = COINS!",
	})
	Util.Sign(m, "SAND EXCHANGE", V(10.4, 2.2, 0.3), at(base, 0, 25.1, 1.8), {
		Name = "ExchangeSign",
		BoardColor = Kit.NAVY,
		Decor = true,
	})
	Kit.cyl(m, "CoinPost", at(base, 0, 22.2, 7.5), 13.6, 1.2, Kit.NAVY, METAL)
	giantCoin(m, at(base, 0, 34.2, 7.5))
	for _, sx in { -1, 1 } do
		Kit.flag(
			m,
			(base * CFrame.new(sx * 10.2, 15.4, 11)).Position,
			6.5,
			if sx < 0 then 160 else 20,
			if sx < 0 then C.Ocean else C.Coral,
			WHITE
		)
	end

	-- striped awning over the counter on two posts (outside the pad's footprint)
	Kit.awning(m, at(base, 0, 13.2, 1.4), 24, 5.6, 8, C.Coral, WHITE, 2.2)
	for _, sx in { -1, 1 } do
		box(m, "AwningPost", at(base, sx * 12.4, 5.5, -4.2), V(0.9, 11, 0.9), Kit.TRIM, nil, true)
		box(m, "AwningPostCap", at(base, sx * 12.4, 0.4, -4.2), V(1.4, 0.8, 1.4), C.Gold)
	end
	local fixture = box(m, "CeilingLamp", at(base, 0, 12.6, 0.6), V(1.8, 0.5, 1.8), Kit.NAVY, METAL)
	fixture.CastShadow = false
	local bulb = Kit.neon(m, "CeilingBulb", at(base, 0, 12.2, 0.6), V(1.2, 0.4, 1.2), rgb(255, 210, 120), true)
	Kit.light(bulb, rgb(255, 214, 140), 16, 1.1)

	-- counter dressing: coin stacks + a sand scale
	for k, off in { V(-6.4, 0, 0.6), V(-5.2, 0, 1.2), V(-5.9, 0, -0.5) } do
		local hgt = 0.6 + k * 0.35
		Kit.cyl(m, "CoinStack", at(base, off.X, 4.1 + hgt / 2, off.Z), hgt, 1.2, C.Gold, METAL)
	end
	sandScale(m, at(base, 5, 4.1, 0.6))

	-- sand piles, sacks and a shovel stuck in the sand beside the building
	local piles = { { -15.6, -1.2, 4, 6.4 }, { -14.2, -1, 8.6, 4.4 }, { 15.8, -1.4, 5, 7 }, { 17.6, -1, 1.6, 3.6 } }
	for _, p in piles do
		Kit.ball(m, "SandPile", (base * CFrame.new(p[1], p[2], p[3])).Position, p[4], Kit.SAND, Enum.Material.Sand)
	end
	for k, p in { V(-17.6, 0, 9.8), V(-16, 0, 10.6), V(-16.9, 1.7, 10.2) } do
		Kit.sack(m, at(base, p.X, p.Y, p.Z, 0, rng:NextNumber(-30, 30), 0), 1.9 - k * 0.1)
	end
	Kit.sack(m, at(base, 15.6, 0, 9.6, 0, 20, 82), 1.8)
	Kit.ball(m, "SpilledSand", (base * CFrame.new(14.4, -0.2, 10.6)).Position, 1.8, Kit.SAND, Enum.Material.Sand)
	local stuck = Config.Shovels[math.min(4, #Config.Shovels)]
	if stuck then
		Kit.display(Models.Shovel, stuck.Id, m, at(base, 16.4, 1.6, 4.4, 15, 30, 25))
	end
end

-- Water fountain (free drinks; Survival handles the "Drink" prompt) -------------------------

local function dolphin(m: Model, cf: CFrame)
	local skin = rgb(84, 150, 206)
	local belly = rgb(214, 234, 246)
	box(m, "DolphinBody", cf, V(1.5, 1.6, 4.4), skin)
	box(m, "DolphinBelly", cf * CFrame.new(0, -0.6, -0.2), V(1.1, 0.5, 3.4), belly)
	Kit.ball(m, "DolphinHead", (cf * CFrame.new(0, 0.1, -2.3)).Position, 1.8, skin)
	box(m, "DolphinSnout", cf * CFrame.new(0, -0.2, -3.4), V(0.6, 0.5, 1.2), belly)
	Kit.wedge(m, "DolphinFin", cf * CFrame.new(0, 1.3, 0.2), V(0.3, 1.1, 1.4), skin)
	box(m, "DolphinTail", cf * CFrame.new(0, 0, 2.5) * CFrame.Angles(rad(15), 0, 0), V(2.8, 0.25, 1.1), skin)
end

local function buildFountain(parent: Instance)
	local m = Kit.model(parent, "WaterFountain")
	local p = V(Layout.FOUNTAIN.X, Util.TerrainY(Layout.FOUNTAIN), Layout.FOUNTAIN.Z)
	local root = CFrame.new(p)
	local water = Kit.WATER
	local trim = C.Ocean:Lerp(WHITE, 0.35)
	local basin = Util.Cylinder(m, "Basin", p + V(0, 1, 0), 2, 16, MARBLE, MARBLE_MAT)
	Util.Tag(basin, "WaterFountain")
	Util.Prompt(basin, "Drink", "Water Fountain", 12)
	Kit.cyl(m, "BasinFoot", root * CFrame.new(0, 0.2, 0), 0.4, 17.6, Kit.STONE_DARK, MARBLE_MAT, true)
	for k = 0, 11 do
		local a = rad(k * 30)
		box(
			m,
			"Coping",
			root * CFrame.Angles(0, a, 0) * CFrame.new(0, 2.25, -7.6),
			V(4.1, 0.5, 1.5),
			if k % 2 == 0 then MARBLE else trim,
			MARBLE_MAT
		)
	end
	local pool = Util.Cylinder(m, "Water", p + V(0, 2.05, 0), 0.2, 14, water, Enum.Material.Glass, true)
	pool.Transparency = 0.25
	Kit.light(pool, rgb(110, 220, 255), 14, 0.8)
	-- wishing coins on the pool floor
	local rng = Random.new(54054)
	for _ = 1, 5 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(2.4, 6)
		Kit.cyl(m, "WishCoin", root * CFrame.new(math.cos(a) * r, 2.18, math.sin(a) * r), 0.08, 0.7, C.Gold, METAL)
	end
	-- tier 2
	Kit.cyl(m, "Pillar", root * CFrame.new(0, 4, 0), 4, 2.8, MARBLE, MARBLE_MAT, true)
	Kit.cyl(m, "Bowl", root * CFrame.new(0, 6.3, 0), 0.9, 9, MARBLE, MARBLE_MAT)
	Kit.cyl(m, "BowlRim", root * CFrame.new(0, 6.8, 0), 0.3, 9.3, trim)
	local w2 = Kit.cyl(m, "BowlWater", root * CFrame.new(0, 6.85, 0), 0.15, 8.2, water, Enum.Material.Glass)
	w2.Transparency = 0.25
	-- tier 3 with a falling water curtain into tier 2
	Kit.cyl(m, "Pillar", root * CFrame.new(0, 8.3, 0), 2.8, 1.8, MARBLE, MARBLE_MAT)
	Kit.cyl(m, "TopBowl", root * CFrame.new(0, 9.9, 0), 0.7, 5.2, MARBLE, MARBLE_MAT)
	Kit.cyl(m, "TopBowlRim", root * CFrame.new(0, 10.3, 0), 0.25, 5.5, trim)
	local w3 = Kit.cyl(m, "TopWater", root * CFrame.new(0, 10.35, 0), 0.12, 4.6, water, Enum.Material.Glass)
	w3.Transparency = 0.25
	local curtain = Kit.cyl(m, "WaterCurtain", root * CFrame.new(0, 8.5, 0), 3.3, 5, water, Enum.Material.Glass)
	curtain.Transparency = 0.65
	-- scallop shell + pearl centrepiece (faces the boardwalk), spray from the pearl
	local shell = root * CFrame.new(0, 10.4, 0.5)
	for k = -3, 3 do
		box(
			m,
			"ShellRib",
			shell * CFrame.Angles(0, 0, rad(k * 20)) * CFrame.new(0, 2.3, 0),
			V(1.15, 4.6, 0.4),
			if k % 2 == 0 then rgb(255, 176, 170) else rgb(255, 232, 214)
		)
	end
	local pearl = Kit.ball(m, "Pearl", (shell * CFrame.new(0, 0.9, -0.6)).Position, 1.8, rgb(242, 238, 255))
	pearl.Reflectance = 0.2
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Color = ColorSequence.new(rgb(180, 235, 255), water)
	spray.LightEmission = 0.2
	spray.LightInfluence = 0.6
	spray.Rate = 28
	spray.Lifetime = NumberRange.new(0.9, 1.2)
	spray.Speed = NumberRange.new(11, 14)
	spray.SpreadAngle = Vector2.new(14, 14)
	spray.Acceleration = V(0, -26, 0)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	spray.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0.7),
	})
	spray.Parent = pearl
	-- three dolphins diving into the basin around tier 1
	for _, deg in { 60, 180, 300 } do
		dolphin(m, root * CFrame.Angles(0, rad(deg), 0) * CFrame.new(0, 3.6, -5.6) * CFrame.Angles(rad(-40), 0, 0))
	end

	local base = Util.Facing(p + V(0, 0, -9.5), Layout.HUB_LOOK_TARGET)
	Util.Sign(m, "FREE WATER", V(8, 2, 0.4), base * CFrame.new(0, 2.6, 0), {
		Name = "FountainSign",
		BoardColor = C.Ocean,
		TextColor = WHITE,
	})
	for _, x in { -3.4, 3.4 } do
		box(m, "SignPost", at(base, x, 1, 0.3), V(0.6, 2, 0.6), MARBLE, MARBLE_MAT, true)
		box(m, "SignPostCap", at(base, x, 3.85, 0.3), V(0.8, 0.3, 0.8), trim)
	end
end

function Hub.Build(parent: Instance)
	buildSpawns(parent)
	buildSell(parent)
	HubShops.Build(parent)
	HubAttractions.Build(parent)
	buildFountain(parent)
	HubPlaza.Build(parent)
end

return Hub
