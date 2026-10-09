--!strict
--[[
	HubShops — the three counter shops of the hub (built by World/Hub.luau):
	  ShovelShop   "Digger's Hardware": rugged plank shack, corrugated tin gable roof with a
	               giant crossed shovel + pickaxe crest, tool rack, mine cart, lantern.
	  BackpackShop "Surf & Pack Outfitters": mint surf shop, flat roof with a parapet and a
	               giant backpack on top, striped awning, surfboard rack, life ring.
	  BeachShop    tiki snack bar: bamboo posts, thatch roof with fringe, a giant lemonade cup
	               on the ridge, tiki masks, torches, stools and coolers.
	Tagged counters (ShovelShop / BackpackShop / BeachShop) keep their "Shop" prompts (14 studs)
	and stay direct children of their station Model (StreamingService makes it Atomic).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Models = require(ReplicatedStorage.Shared.Models)
local Layout = require(script.Parent.Layout)
local Util = require(script.Parent.Util)
local Kit = require(script.Parent.HubKit)

local C = Config.Theme.Colors
local rgb = Color3.fromRGB
local rad = math.rad
local V = Vector3.new
local at = Kit.at
local box = Kit.box
local WOOD_MAT = Enum.Material.Wood
local PLANKS = Enum.Material.WoodPlanks
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric

local HubShops = {}

-- Shared shop shell: plinth, floor, porch step and the tagged counter with its prompt.
local function shopBase(m: Model, base: CFrame, tag: string, objectText: string, counterColor: Color3)
	box(m, "Plinth", at(base, 0, 0.25, 0), V(19.6, 0.5, 16.6), Kit.STONE_DARK, Enum.Material.Slate, true)
	box(m, "Floor", at(base, 0, 0.8, 0), V(18, 0.6, 15), Kit.WOOD, PLANKS, true)
	box(m, "PorchStep", at(base, 0, 0.3, -8.9), V(9, 0.6, 1.6), Kit.WOOD_DARK, PLANKS, true)
	local counter = box(m, tag, at(base, 0, 2.75, -4.5), V(13, 3.5, 2.4), counterColor, nil, true)
	box(m, "CounterTop", at(base, 0, 4.75, -4.5), V(14, 0.5, 3), Kit.WOOD, PLANKS, true)
	box(m, "CounterKick", at(base, 0, 1.35, -5.75), V(13.2, 0.5, 0.2), counterColor:Lerp(Color3.new(0, 0, 0), 0.3))
	Util.Tag(counter, tag)
	Util.Prompt(counter, "Shop", objectText, 14)
end

-- Digger's Hardware -------------------------------------------------------------------------

local function giantTools(m: Model, cf: CFrame)
	-- shovel, blade up, leaning right
	local s = cf * CFrame.Angles(0, 0, rad(-32))
	box(m, "GiantShovelHandle", s, V(0.9, 15, 0.9), Kit.WOOD, WOOD_MAT)
	box(m, "GiantShovelGrip", s * CFrame.new(0, -7.6, 0), V(3.2, 0.9, 0.9), Kit.WOOD_DEEP, WOOD_MAT)
	box(m, "GiantShovelCollar", s * CFrame.new(0, 6.4, 0), V(1.4, 1.8, 1.4), Kit.STEEL_DARK, METAL)
	box(m, "GiantShovelBlade", s * CFrame.new(0, 9.5, 0), V(4.6, 4.6, 0.5), Kit.STEEL, METAL)
	box(
		m,
		"GiantShovelTip",
		s * CFrame.new(0, 11.6, 0) * CFrame.Angles(0, 0, rad(45)),
		V(3.25, 3.25, 0.48),
		Kit.STEEL,
		METAL
	)
	-- pickaxe, head up, leaning left, in front of the shovel
	local p = cf * CFrame.new(0, 0, -1) * CFrame.Angles(0, 0, rad(32))
	box(m, "GiantPickHandle", p, V(0.9, 15, 0.9), Kit.WOOD_DARK, WOOD_MAT)
	box(m, "GiantPickHead", p * CFrame.new(0, 7.2, 0), V(8, 1.5, 1.2), Kit.STEEL_DARK, METAL)
	for _, sx in { -1, 1 } do
		Kit.wedge(
			m,
			"GiantPickTip",
			p * CFrame.new(sx * 5.3, 7.2, 0) * CFrame.Angles(0, rad(-90 * sx), 0),
			V(1.2, 1.5, 2.6),
			Kit.STEEL,
			METAL
		)
	end
	box(m, "GiantPickBand", p * CFrame.new(0, 7.2, 0), V(1.6, 1.9, 1.5), C.Ocean)
end

local function buildShovelShop(parent: Instance): Model
	local m = Kit.model(parent, "ShovelShop")
	local base = Kit.hubFacing(Layout.SHOVEL_SHOP)
	local accent = C.Ocean
	shopBase(m, base, "ShovelShop", "Shovels", accent)

	-- plank walls, darker wainscot, heavy corner posts
	box(m, "BackWall", at(base, 0, 5.6, 7.1), V(17, 9, 0.8), Kit.WOOD, PLANKS, true)
	for _, sx in { -1, 1 } do
		box(m, "SideWall", at(base, sx * 8.6, 5.6, 0), V(0.8, 9, 14), Kit.WOOD, PLANKS, true)
		box(m, "Wainscot", at(base, sx * 8.75, 2.6, 0), V(0.8, 3, 14.2), Kit.WOOD_DEEP, PLANKS)
		box(m, "FrontWall", at(base, sx * 7.6, 5.6, -7), V(2, 9, 0.8), Kit.WOOD, PLANKS, true)
		for _, z in { -7.2, 7.2 } do
			box(m, "CornerPost", at(base, sx * 8.7, 5.9, z), V(1.3, 10.2, 1.3), Kit.WOOD_DEEP, WOOD_MAT, true)
		end
		Kit.window(m, at(base, sx * 9.05, 6.2, 1.5, 0, sx * -90, 0), 3.6, 3, Kit.WOOD_DEEP)
	end
	box(m, "Wainscot", at(base, 0, 2.6, 7.6), V(17.4, 3, 0.4), Kit.WOOD_DEEP, PLANKS)
	box(m, "Header", at(base, 0, 10.4, -7.2), V(18.6, 1.2, 1.4), Kit.WOOD_DEEP, WOOD_MAT)
	box(m, "Header", at(base, 0, 10.4, 7.2), V(18.6, 1.2, 1.4), Kit.WOOD_DEEP, WOOD_MAT)

	-- corrugated tin gable roof, crest of giant tools, stove pipe
	Kit.gable(m, at(base, 0, 11, 0), 19.6, 16.4, 6.2, Kit.STEEL, {
		Under = Kit.WOOD_DARK,
		Trim = accent,
		Mat = METAL,
		Overhang = 2,
		EndOverhang = 1.4,
	})
	giantTools(m, at(base, 0, 18, -10.2))
	Kit.cyl(m, "StovePipe", at(base, 5.5, 17.2, 4), 5, 1.1, Kit.BLACK, METAL)
	Kit.cyl(m, "StoveCap", at(base, 5.5, 19.9, 4), 0.5, 1.8, Kit.BLACK, METAL)

	Util.Sign(m, "SHOVELS", V(13, 3.4, 0.6), at(base, 0, 8.4, -7.9), {
		Name = "ShopSign",
		BoardColor = accent,
		SubText = "DIGGER'S HARDWARE",
	})
	-- lantern hanging by the doorway
	box(m, "LanternArm", at(base, -6.6, 9.6, -8.3), V(0.3, 0.3, 1.6), Kit.BLACK, METAL)
	box(m, "Lantern", at(base, -6.6, 8.6, -8.9), V(1.1, 1.5, 1.1), Kit.BLACK, METAL)
	local glow = Kit.neon(m, "LanternGlow", at(base, -6.6, 8.6, -8.9), V(0.8, 1.1, 1.2), rgb(255, 170, 70), true)
	Kit.light(glow, rgb(255, 180, 100), 14, 0.9)

	-- tool rack on the left wall with real shovels from the shop
	local rack = at(base, -10.4, 0, 0)
	for _, z in { -3.6, 3.6 } do
		box(m, "RackPost", rack * CFrame.new(-0.4, 3.5, z), V(0.5, 7, 0.5), Kit.WOOD_DEEP, WOOD_MAT)
	end
	box(m, "RackRail", rack * CFrame.new(-0.4, 6.4, 0), V(0.4, 0.4, 7.8), Kit.WOOD_DEEP, WOOD_MAT)
	box(m, "RackRail", rack * CFrame.new(-0.4, 2.2, 0), V(0.4, 0.4, 7.8), Kit.WOOD_DEEP, WOOD_MAT)
	local rackIds = { 3, 5, 7 }
	for i, idx in rackIds do
		local def = Config.Shovels[math.min(idx, #Config.Shovels)]
		if def then
			Kit.display(
				Models.Shovel,
				def.Id,
				m,
				rack * CFrame.new(0, 0.3, (i - 2) * 2.4) * CFrame.Angles(rad(8 * (i - 2)), rad(90), rad(-10))
			)
		end
	end
	-- counter display (the 2nd shovel, leaning)
	local display = Config.Shovels[math.min(2, #Config.Shovels)]
	if display then
		Kit.display(Models.Shovel, display.Id, m, at(base, 4, 5, -4.5, 0, 0, -20))
	end

	-- mine cart full of ore on a stub of track (right side)
	local cart = at(base, 12.6, 0, -2, 0, 78, 0)
	for _, z in { -1.3, 1.3 } do
		box(m, "Rail", cart * CFrame.new(0, 0.12, z), V(8, 0.25, 0.3), Kit.STEEL_DARK, METAL)
	end
	box(m, "Sleeper", cart * CFrame.new(-2.5, 0.05, 0), V(0.8, 0.12, 3.4), Kit.WOOD_DEEP, WOOD_MAT)
	box(m, "Sleeper", cart * CFrame.new(2.4, 0.05, 0), V(0.8, 0.12, 3.4), Kit.WOOD_DEEP, WOOD_MAT)
	box(m, "CartBody", cart * CFrame.new(0.4, 2, 0), V(4.2, 2.4, 2.8), Kit.STEEL_DARK, METAL)
	box(m, "CartRim", cart * CFrame.new(0.4, 3.25, 0), V(4.5, 0.3, 3.1), accent, METAL)
	for _, x in { -0.9, 1.7 } do
		for _, z in { -1.45, 1.45 } do
			Kit.cyl(
				m,
				"CartWheel",
				cart * CFrame.new(x, 0.75, z) * CFrame.Angles(rad(90), 0, 0),
				0.4,
				1.5,
				Kit.BLACK,
				METAL
			)
		end
	end
	Kit.ball(m, "Ore", (cart * CFrame.new(-0.3, 3.5, 0.3)).Position, 1.6, C.Gold, Enum.Material.Slate)
	Kit.ball(m, "Ore", (cart * CFrame.new(1.2, 3.4, -0.4)).Position, 1.3, rgb(140, 130, 150), Enum.Material.Slate)
	Kit.ball(m, "Ore", (cart * CFrame.new(0.8, 3.7, 0.6)).Position, 1, rgb(110, 220, 255), Enum.Material.Glass)

	-- barrel of spare handles by the porch
	local barrel = at(base, 10.2, 0, -8.6)
	Kit.barrel(m, barrel, 3.2, 2.4)
	for k = 0, 2 do
		local a = k * 120
		box(
			m,
			"SpareHandle",
			barrel * CFrame.Angles(0, rad(a), 0) * CFrame.new(0.4, 4, 0) * CFrame.Angles(0, 0, rad(10)),
			V(0.35, 3.2, 0.35),
			Kit.WOOD,
			WOOD_MAT
		)
	end
	box(m, "SpareHead", barrel * CFrame.new(0.4, 5.6, 0), V(2.2, 0.5, 0.4), Kit.STEEL, METAL)
	return m
end

-- Surf & Pack Outfitters --------------------------------------------------------------------

local function giantBackpack(m: Model, cf: CFrame)
	local body = rgb(255, 128, 64)
	local dark = rgb(196, 84, 40)
	local trim = Kit.NAVY
	box(m, "PackBody", cf * CFrame.new(0, 4.6, 0), V(9, 9.2, 5.4), body, FABRIC)
	Kit.cyl(m, "PackTop", cf * CFrame.new(0, 9.2, 0) * CFrame.Angles(0, 0, rad(90)), 9, 5.4, body, FABRIC)
	box(m, "PackFlap", cf * CFrame.new(0, 9.1, -2.55) * CFrame.Angles(rad(-8), 0, 0), V(8.2, 4.4, 0.6), dark, FABRIC)
	box(m, "PackPocket", cf * CFrame.new(0, 3.4, -3.1), V(7, 4.6, 1.4), dark, FABRIC)
	box(m, "PackZip", cf * CFrame.new(0, 5.5, -3.85), V(6.4, 0.3, 0.2), C.Gold, METAL)
	for _, sx in { -1, 1 } do
		box(m, "PackSide", cf * CFrame.new(sx * 4.9, 3.2, 0), V(1.4, 4.4, 3.6), trim, FABRIC)
		box(m, "PackStrap", cf * CFrame.new(sx * 2.4, 4.8, 2.9), V(1.3, 8.6, 0.6), trim, FABRIC)
		box(m, "PackBuckle", cf * CFrame.new(sx * 2.4, 7.2, -2.95), V(1.1, 1.5, 0.4), C.Gold, METAL)
		box(m, "PackFlapStrap", cf * CFrame.new(sx * 2.4, 8.4, -2.85), V(0.9, 2.6, 0.3), trim, FABRIC)
	end
	box(m, "PackHandle", cf * CFrame.new(0, 12.3, 0), V(3, 0.5, 0.6), trim, FABRIC)
	Kit.cyl(m, "PackPatch", cf * CFrame.new(0, 3.4, -3.85) * CFrame.Angles(rad(90), 0, 0), 0.2, 2.6, C.Palm)
end

local function surfboard(m: Model, cf: CFrame, color: Color3, stripe: Color3)
	box(m, "Surfboard", cf, V(2.2, 7.4, 0.35), color)
	for _, sy in { -1, 1 } do
		Kit.cyl(m, "SurfboardEnd", cf * CFrame.new(0, sy * 3.7, 0) * CFrame.Angles(rad(90), 0, 0), 0.35, 2.2, color)
	end
	box(m, "SurfboardStripe", cf * CFrame.new(0, 0, -0.05), V(0.5, 8.6, 0.36), stripe)
end

local function buildBackpackShop(parent: Instance): Model
	local m = Kit.model(parent, "BackpackShop")
	local base = Kit.hubFacing(Layout.BACKPACK_SHOP)
	local accent = C.Palm
	local wall = accent:Lerp(Kit.WHITE, 0.62)
	local deep = accent:Lerp(Color3.new(0, 0, 0), 0.25)
	shopBase(m, base, "BackpackShop", "Backpacks", accent)

	box(m, "BackWall", at(base, 0, 6.1, 7.1), V(17, 10, 0.8), wall, nil, true)
	for _, sx in { -1, 1 } do
		box(m, "SideWall", at(base, sx * 8.6, 6.1, 0), V(0.8, 10, 14), wall, nil, true)
		box(m, "Wainscot", at(base, sx * 8.75, 2.4, 0), V(0.8, 2.6, 14.2), deep)
		box(m, "FrontWall", at(base, sx * 7.6, 6.1, -7), V(2, 10, 0.8), wall, nil, true)
		for _, z in { -7.2, 7.2 } do
			box(m, "CornerBoard", at(base, sx * 8.7, 6.1, z), V(1.2, 10.4, 1.2), Kit.TRIM, nil, true)
		end
		Kit.window(m, at(base, sx * 9.05, 6.6, 0.5, 0, sx * -90, 0), 4.2, 3.4, Kit.TRIM)
	end
	box(m, "Wainscot", at(base, 0, 2.4, 7.6), V(17.4, 2.6, 0.4), deep)
	-- flat roof, fascia, parapet (sign rides on it) and the giant backpack behind it
	box(m, "Fascia", at(base, 0, 11.4, 0), V(19.8, 1.2, 16.8), accent)
	box(m, "Roof", at(base, 0, 12.2, 0), V(19.2, 0.5, 16.2), Kit.TRIM)
	box(m, "Soffit", at(base, 0, 10.7, 0), V(19.4, 0.3, 16.4), deep)
	box(m, "Parapet", at(base, 0, 13.7, -8.1), V(19.8, 3, 0.8), accent)
	box(m, "ParapetCap", at(base, 0, 15.3, -8.1), V(20.4, 0.4, 1.2), Kit.TRIM)
	Util.Sign(m, "BACKPACKS", V(14.5, 2.8, 0.5), at(base, 0, 13.7, -8.7), {
		Name = "ShopSign",
		BoardColor = C.Coral,
		SubText = "SURF & PACK OUTFITTERS",
	})
	giantBackpack(m, at(base, 0, 12.4, 1.6, 0, -8, 0))
	-- striped awning over the counter
	Kit.awning(m, at(base, 0, 10.2, -7.6), 18, 3.8, 7, accent, Kit.TRIM, 1.6)

	-- counter display: bucket + a real backpack model
	Kit.cyl(m, "DisplayBucket", at(base, -4, 6.1, -4.5), 2.4, 2.2, C.Coral)
	local packs = Config.Backpacks
	local pick = packs[math.min(3, #packs)]
	if pick then
		Kit.display(Models.Backpack, pick.Id, m, at(base, 4, 5, -4.5, 0, 180, 0))
	end

	-- surfboard rack on the right
	local rack = at(base, 11.4, 0, 0.5)
	for _, z in { -3.6, 3.6 } do
		box(m, "RackPost", rack * CFrame.new(0, 2.5, z), V(0.5, 5, 0.5), Kit.WOOD_DARK, WOOD_MAT)
	end
	box(m, "RackBar", rack * CFrame.new(0, 4.6, 0), V(0.5, 0.5, 8), Kit.WOOD_DARK, WOOD_MAT)
	local boards = { { C.Coral, Kit.TRIM }, { C.Ocean, C.Gold }, { C.Gold, C.Coral } }
	for i, c in boards do
		surfboard(
			m,
			rack * CFrame.new(-0.6 + i * 0.1, 4.2, (i - 2) * 2.6) * CFrame.Angles(0, rad(90), rad(-8 - i * 2)),
			c[1],
			c[2]
		)
	end
	-- life ring on the left wall, a flag on the roof
	local ring = at(base, -9.3, 7.4, -3.4, 0, 90, 0)
	Kit.cyl(m, "LifeRing", ring * CFrame.Angles(rad(90), 0, 0), 0.6, 3.2, C.Coral)
	Kit.cyl(m, "LifeRingHole", ring * CFrame.new(0, 0, 0.05) * CFrame.Angles(rad(90), 0, 0), 0.62, 1.6, wall)
	for k = 0, 3 do
		box(
			m,
			"LifeRingBand",
			ring * CFrame.Angles(0, 0, rad(k * 90 + 45)) * CFrame.new(0, 1.2, -0.05),
			V(0.7, 0.8, 0.62),
			Kit.TRIM
		)
	end
	Kit.flag(m, (base * CFrame.new(-8, 12.4, 6.5)).Position, 8, 20, C.Ocean, Kit.TRIM)
	return m
end

-- Tiki snack bar ----------------------------------------------------------------------------

local function tikiMask(m: Model, cf: CFrame, color: Color3)
	box(m, "TikiMask", cf, V(1.9, 3.2, 0.6), color, WOOD_MAT)
	for _, sx in { -1, 1 } do
		Kit.neon(m, "TikiEye", cf * CFrame.new(sx * 0.45, 0.6, -0.32), V(0.5, 0.4, 0.1), rgb(255, 150, 40), true)
	end
	box(m, "TikiMouth", cf * CFrame.new(0, -0.8, -0.32), V(1.2, 0.5, 0.1), Kit.WOOD_DEEP)
	box(m, "TikiBrow", cf * CFrame.new(0, 1.15, -0.25), V(2.2, 0.4, 0.4), C.Coral)
end

local function buildBeachShop(parent: Instance): Model
	local m = Kit.model(parent, "BeachShop")
	local base = Kit.hubFacing(Layout.BEACH_SHOP)
	local lime = rgb(150, 220, 80)
	local rng = Random.new(76040)

	box(m, "Floor", at(base, 0, 0.5, 0), V(16, 1, 12), Kit.WOOD, PLANKS, true)
	box(m, "FloorEdge", at(base, 0, 0.35, -6.1), V(16.4, 0.7, 0.4), Kit.WOOD_DEEP, WOOD_MAT)
	local counter = box(m, "Counter", at(base, 0, 2.8, -3.5), V(14, 3.6, 3), lime, nil, true)
	box(m, "CounterTop", at(base, 0, 4.85, -3.5), V(15, 0.5, 3.6), Kit.BAMBOO, PLANKS, true)
	Util.Tag(counter, "BeachShop")
	Util.Prompt(counter, "Shop", "Beach Shop", 14)
	-- bamboo slats on the counter front
	for k = -3, 3 do
		Kit.cyl(
			m,
			"Bamboo",
			at(base, k * 1.95, 2.8, -5.05),
			3.6,
			0.55,
			if k % 2 == 0 then Kit.BAMBOO else rgb(196, 166, 92),
			WOOD_MAT
		)
	end
	box(m, "BackWall", at(base, 0, 5, 5.6), V(16, 9, 0.8), Kit.BAMBOO, PLANKS, true)
	box(m, "MenuBoard", at(base, 0, 6.6, 5.1), V(8, 3.2, 0.2), Kit.NAVY)
	for _, x in { -7.6, 7.6 } do
		for _, z in { -5.4, 5.4 } do
			Kit.cyl(m, "BambooPost", at(base, x, 6, z), 11, 1, Kit.BAMBOO, WOOD_MAT, true)
			Kit.cyl(m, "PostRing", at(base, x, 8.5, z), 0.4, 1.15, Kit.WOOD_DEEP, WOOD_MAT)
		end
	end
	-- thatch roof (ridge across the front) with a ragged fringe
	Kit.gable(m, at(base, 0, 11.2, 0, 0, 90, 0), 15, 18, 6.4, Kit.THATCH, {
		Under = Kit.THATCH_DARK,
		Mat = Enum.Material.Grass,
		Overhang = 2.6,
		EndOverhang = 1.2,
		Thick = 0.9,
	})
	for _, sz in { -1, 1 } do
		for k = 0, 6 do
			local len = rng:NextNumber(1.2, 2.2)
			box(
				m,
				"Fringe",
				at(base, -8.4 + k * 2.8, 9.7 - len / 2, sz * 9.4),
				V(2.8, len, 0.4),
				if k % 2 == 0 then Kit.THATCH else Kit.THATCH_DARK,
				Enum.Material.Grass
			)
		end
	end
	-- giant lemonade cup on the ridge
	local cup = at(base, 0, 17.4, 0)
	Kit.cyl(m, "GiantCup", cup * CFrame.new(0, 3.5, 0), 7, 5.6, rgb(255, 236, 90), Enum.Material.Glass)
	Kit.cyl(m, "GiantCupBand", cup * CFrame.new(0, 3, 0), 2.2, 5.75, Kit.TRIM)
	Kit.cyl(m, "GiantCupRim", cup * CFrame.new(0, 7.1, 0), 0.4, 6, Kit.TRIM)
	box(m, "GiantStraw", cup * CFrame.new(1.2, 9, 0) * CFrame.Angles(0, 0, rad(-14)), V(0.8, 7, 0.8), C.Coral)
	box(m, "GiantStrawTip", cup * CFrame.new(2.3, 12.4, 0) * CFrame.Angles(0, 0, rad(-60)), V(0.8, 2.4, 0.8), C.Coral)
	local lemon = cup * CFrame.new(-2.9, 7, -0.6) * CFrame.Angles(rad(90), rad(20), 0)
	Kit.cyl(m, "LemonSlice", lemon, 0.5, 3.4, rgb(255, 250, 220))
	Kit.cyl(m, "LemonFlesh", lemon * CFrame.new(0, 0.02, 0), 0.52, 2.8, rgb(255, 220, 40))
	Util.Sign(m, "BEACH SHOP", V(14, 3.2, 0.6), at(base, 0, 9.1, -6.4), {
		Name = "BeachShopSign",
		BoardColor = lime,
		SubText = "SHADE & SNACKS",
	})
	-- tiki masks on the front posts
	for _, sx in { -1, 1 } do
		tikiMask(m, at(base, sx * 7.6, 6.4, -6), if sx < 0 then Kit.WOOD_DARK else Kit.WOOD)
	end

	-- counter display: lemonade jug, coconuts
	Kit.cyl(m, "Lemonade", at(base, -4.5, 6.2, -3.5), 2.2, 1.8, rgb(255, 236, 90), Enum.Material.Glass)
	for k = 0, 2 do
		Kit.ball(m, "Coconut", (base * CFrame.new(-0.8 + k * 1.5, 5.7, -3.3)).Position, 1.4, rgb(120, 80, 50))
	end
	Kit.ball(m, "Coconut", (base * CFrame.new(0.7, 6.8, -3.3)).Position, 1.4, rgb(120, 80, 50))
	Kit.cyl(m, "Pineapple", at(base, 4.6, 6.1, -3.6), 1.9, 1.5, rgb(240, 180, 50), Enum.Material.Slate)
	box(m, "PineappleLeaves", at(base, 4.6, 7.6, -3.6, 0, 45, 0), V(0.9, 1.2, 0.9), Kit.LEAF, Enum.Material.Grass)

	-- stools, torches, coolers, chalkboard
	for k = -1, 1 do
		local p = at(base, k * 4.4 + rng:NextNumber(-0.5, 0.5), 0, -7.6 + rng:NextNumber(-0.4, 0.4))
		Kit.cyl(m, "StoolLeg", p * CFrame.new(0, 1.2, 0), 2.4, 0.5, Kit.BAMBOO, WOOD_MAT)
		Kit.cyl(m, "StoolSeat", p * CFrame.new(0, 2.5, 0), 0.4, 2, Kit.WOOD_DARK, WOOD_MAT)
	end
	local torchSpots = { V(-10.4, 0, -8.6), V(10.8, 0, -7.4), V(-10.8, 0, 6.4) }
	for i, spot in torchSpots do
		local p = base * CFrame.new(spot)
		local flame = Kit.torch(m, p.Position, 7 + i * 0.6)
		if i == 1 then
			Kit.light(flame, rgb(255, 160, 70), 14, 1)
		end
	end
	Kit.cooler(m, at(base, 10.6, 0, -2, 0, 14, 0), C.Ocean)
	Kit.cooler(m, at(base, 10.9, 0, 1.4, 0, -10, 0), C.Coral)
	Kit.cooler(m, at(base, 10.8, 2.15, -0.4, 0, 40, 0), C.Gold)
	-- chalkboard A-frame
	local chalk = at(base, -11.2, 0, -3, 0, -30, 0)
	box(m, "Chalkboard", chalk * CFrame.new(0, 1.6, -0.4) * CFrame.Angles(rad(-12), 0, 0), V(2.6, 3.4, 0.2), Kit.NAVY)
	box(
		m,
		"Chalkboard",
		chalk * CFrame.new(0, 1.6, 0.4) * CFrame.Angles(rad(12), 0, 0),
		V(2.6, 3.4, 0.2),
		Kit.WOOD_DARK
	)
	local chalkSign =
		Util.Sign(m, "ICE COLD!", V(2.2, 1.2, 0.1), chalk * CFrame.new(0, 2.1, -0.62) * CFrame.Angles(rad(-12), 0, 0), {
			Name = "ChalkText",
			BoardColor = Kit.NAVY,
			Decor = true,
		})
	chalkSign.CastShadow = false
	return m
end

function HubShops.Build(parent: Instance)
	buildShovelShop(parent)
	buildBackpackShop(parent)
	buildBeachShop(parent)
end

return HubShops
