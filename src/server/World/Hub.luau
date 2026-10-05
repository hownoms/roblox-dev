--!strict
--[[
	Hub — the plaza inland of the boardwalk: spawns (on the boardwalk deck), Sell stand,
	Shovel & Backpack huts, Egg incubator, Rebirth shrine, two leaderboards, the free Water
	Fountain, the Digger Garage and the Beach Shop stall. Hero structures are built from Parts in
	a local frame whose -Z (front) faces the boardwalk spawns.

	Tags placed: SpawnLocation, SellZone, ShovelShop, BackpackShop, EggShop (one per egg, with
	attribute EggId on the part and on its ProximityPrompt), RebirthStatue, LeaderboardCoins,
	LeaderboardDepth, WaterFountain (prompt "Drink"), Garage (prompt "Garage"), BeachShop
	(prompt "Shop"). Survival / Diggers clients handle those three prompts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Models = require(ReplicatedStorage.Shared.Models)
local Build = require(ReplicatedStorage.Shared.Models.Build)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Types = require(ReplicatedStorage.Shared.Types)
local Layout = require(script.Parent.Layout)
local Util = require(script.Parent.Util)

local Theme = Config.Theme
local C = Theme.Colors
local rgb = Color3.fromRGB
local S = Layout.SURFACE_Y

local WOOD = rgb(176, 122, 76)
local WOOD_DARK = rgb(124, 84, 52)
local THATCH = rgb(226, 182, 96)
local THATCH_DARK = rgb(196, 148, 70)
local WHITE = Color3.new(1, 1, 1)
local MARBLE = rgb(246, 242, 255)

local Hub = {}

-- Part in a local frame (front = -Z).
local function lp(
	parent: Instance,
	base: CFrame,
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	material: Enum.Material?,
	decor: boolean?
): Part
	return Util.Part({
		Name = name,
		Size = size,
		CFrame = base * CFrame.new(offset),
		Color = color,
		Material = material,
		Decor = decor,
		Parent = parent,
	})
end

local function hubFacing(pos: Vector3): CFrame
	return Util.Facing(pos, Layout.HUB_LOOK_TARGET)
end

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
		spawn.Size = Vector3.new(8, 1, 8)
		-- On the boardwalk deck, facing the sand / ocean (-Z)
		spawn.CFrame = CFrame.lookAt(pos + Vector3.new(0, 0.5, 0), pos + Vector3.new(0, 0.5, -10))
		spawn.Color = colors[(i - 1) % #colors + 1]
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.BottomSurface = Enum.SurfaceType.Smooth
		spawn.Parent = parent
		Util.Tag(spawn, "SpawnLocation")
		-- White rim
		Util.Part({
			Name = "SpawnRim",
			Size = Vector3.new(9, 0.6, 9),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)),
			Color = WHITE,
			Decor = true,
			Parent = parent,
		})
	end
end

-- Sell stand ----------------------------------------------------------------------------------

local function buildSell(parent: Instance)
	local m = Util.Model("SellStand", parent)
	-- Faces the beach so players walking up from the sand see it first.
	local base = Util.Facing(Layout.SELL, Layout.SELL + Vector3.new(0, 0, -10))

	lp(m, base, "Counter", Vector3.new(16, 3.6, 4), Vector3.new(0, 1.8, 0), C.Coral)
	lp(m, base, "CounterTop", Vector3.new(17, 0.5, 5), Vector3.new(0, 3.85, 0), WOOD, Enum.Material.WoodPlanks)
	for i = -2, 2 do
		lp(m, base, "CounterStripe", Vector3.new(1.2, 3.6, 0.2), Vector3.new(i * 3.2, 1.8, -2.05), WHITE, nil, true)
	end
	lp(m, base, "BackWall", Vector3.new(18, 10, 1), Vector3.new(0, 5, 4), C.PanelAlt)
	for _, x in { -8.5, 8.5 } do
		for _, z in { -2.2, 4 } do
			lp(m, base, "Post", Vector3.new(1, 12, 1), Vector3.new(x, 6, z), WHITE)
		end
	end
	-- Striped awning
	for i = 0, 5 do
		local color = if i % 2 == 0 then C.Coral else WHITE
		local awning = lp(m, base, "Awning", Vector3.new(3.2, 0.6, 9.5), Vector3.new(-8 + i * 3.2, 12.3, 0.9), color)
		awning.CFrame = base * CFrame.new(-8 + i * 3.2, 12.3, 0.9) * CFrame.Angles(math.rad(-10), 0, 0)
	end
	-- Sand pile + bucket on the counter
	Util.Ball(m, "SandPile", (base * CFrame.new(-4, 4.4, 1.2)).Position, 3, rgb(255, 224, 150), Enum.Material.Sand)
	Util.Cylinder(m, "Bucket", (base * CFrame.new(4, 5, 0.5)).Position, 2, 2, C.Ocean, nil, true)

	-- Big SELL sign on its own posts
	for _, x in { -7, 7 } do
		lp(m, base, "SignPost", Vector3.new(0.8, 9, 0.8), Vector3.new(x, 14, 3.4), WOOD_DARK, Enum.Material.Wood)
	end
	Util.Sign(m, "SELL", Vector3.new(20, 7, 1), base * CFrame.new(0, 17.5, 2.6), {
		Name = "SellSign",
		BoardColor = C.Gold,
		SubText = "SAND = COINS!",
	})
	for _, x in { -12.5, 12.5 } do
		local coin = Util.Part({
			Name = "Coin",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.8, 5, 5),
			CFrame = base * CFrame.new(x, 17.5, 2.6) * CFrame.Angles(0, math.rad(90), 0),
			Color = C.Gold,
			Reflectance = 0.25,
			Decor = true,
			Parent = m,
		})
		coin.CastShadow = true
	end

	-- Touch pad in front of the counter
	local pad = lp(
		m,
		base,
		"SellZone",
		Vector3.new(16, 1, 8),
		Vector3.new(0, 2.2, -6.5),
		rgb(50, 170, 75),
		Enum.Material.SmoothPlastic
	)
	pad.Transparency = 0.3
	pad.CanCollide = false
	pad.CanQuery = false
	pad.CanTouch = true
	pad.CastShadow = false
	Util.Tag(pad, "SellZone")
	local gui = Util.SurfaceGui(pad, Enum.NormalId.Top)
	Util.Label(gui, "SELL HERE!", WHITE, UDim2.fromScale(0.05, 0.1), UDim2.fromScale(0.9, 0.8))
end

-- Shop huts -----------------------------------------------------------------------------------

local function buildHut(
	parent: Instance,
	name: string,
	pos: Vector3,
	title: string,
	accent: Color3,
	tag: string,
	objectText: string
): Model
	local m = Util.Model(name, parent)
	local base = hubFacing(pos)

	lp(m, base, "Floor", Vector3.new(16, 1, 13), Vector3.new(0, 0.5, 0), WOOD, Enum.Material.WoodPlanks)
	for _, x in { -7, 7 } do
		for _, z in { -5.5, 5.5 } do
			lp(m, base, "Post", Vector3.new(1, 10, 1), Vector3.new(x, 6, z), WOOD_DARK, Enum.Material.Wood)
		end
	end
	lp(m, base, "BackWall", Vector3.new(14, 8, 0.8), Vector3.new(0, 5, 5.6), accent:Lerp(WHITE, 0.55))
	for _, x in { -7.3, 7.3 } do
		lp(m, base, "SideWall", Vector3.new(0.6, 4, 10), Vector3.new(x, 3, 0.5), accent:Lerp(WHITE, 0.3))
	end
	local counter = lp(m, base, tag, Vector3.new(13, 3.5, 2.4), Vector3.new(0, 2.75, -4.5), accent)
	lp(m, base, "CounterTop", Vector3.new(14, 0.5, 3), Vector3.new(0, 4.75, -4.5), WOOD, Enum.Material.WoodPlanks)
	Util.Tag(counter, tag)
	Util.Prompt(counter, "Shop", objectText, 14)

	-- Tiered thatch roof
	local tiers: { { Size: Vector3, Y: number, Color: Color3 } } = {
		{ Size = Vector3.new(19, 1.4, 16), Y = 11.2, Color = THATCH },
		{ Size = Vector3.new(14, 1.4, 11.5), Y = 12.6, Color = THATCH_DARK },
		{ Size = Vector3.new(8.5, 1.4, 7), Y = 14, Color = THATCH },
		{ Size = Vector3.new(3, 1.6, 2.6), Y = 15.5, Color = accent },
	}
	for _, t in tiers do
		lp(m, base, "Roof", t.Size, Vector3.new(0, t.Y, 0), t.Color, Enum.Material.Fabric)
	end
	Util.Sign(m, title, Vector3.new(13, 3.4, 0.6), base * CFrame.new(0, 8.4, -6.9), {
		Name = "ShopSign",
		BoardColor = accent,
	})
	return m
end

local function buildShops(parent: Instance)
	local shovel = buildHut(parent, "ShovelShop", Layout.SHOVEL_SHOP, "SHOVELS", C.Ocean, "ShovelShop", "Shovels")
	local backpack =
		buildHut(parent, "BackpackShop", Layout.BACKPACK_SHOP, "BACKPACKS", C.Palm, "BackpackShop", "Backpacks")

	-- Shovel display on the counter (Models.Shovel of the 2nd shovel, leaning)
	local display = Config.Shovels[math.min(2, #Config.Shovels)]
	if display then
		local ok, result = pcall(Models.Shovel, display.Id)
		if ok and typeof(result) == "Instance" and result:IsA("Model") then
			local model = result :: Model
			Util.Finish(model, true)
			local base = hubFacing(Layout.SHOVEL_SHOP)
			Util.Ground(model, base * CFrame.new(4, 5, -4.5) * CFrame.Angles(0, 0, math.rad(-20)))
			model.Parent = shovel
		end
	end
	-- Bucket-and-bag display on the backpack counter
	local base = hubFacing(Layout.BACKPACK_SHOP)
	Util.Cylinder(backpack, "DisplayBucket", (base * CFrame.new(-4, 6, -4.5)).Position, 2.4, 2.2, C.Coral, nil, true)
	Util.Part({
		Name = "DisplayBag",
		Size = Vector3.new(2.4, 2.8, 1.6),
		CFrame = base * CFrame.new(4, 6.4, -4.5),
		Color = C.Purple,
		Material = Enum.Material.Fabric,
		Decor = true,
		Parent = backpack,
	})
end

-- Leaderboards --------------------------------------------------------------------------------

local function buildLeaderboard(
	parent: Instance,
	name: string,
	pos: Vector3,
	tag: string,
	title: string,
	accent: Color3
)
	local m = Util.Model(name, parent)
	local base = Util.Facing(pos, Layout.SPAWNS[1])
	for _, x in { -6, 6 } do
		lp(m, base, "Leg", Vector3.new(1.2, 4, 1.2), Vector3.new(x, 2, 0.6), WOOD_DARK, Enum.Material.Wood)
	end
	local board = lp(m, base, "Board", Vector3.new(14, 18, 1), Vector3.new(0, 13, 0), rgb(35, 30, 60))
	Util.Tag(board, tag)
	-- Frame
	lp(m, base, "FrameTop", Vector3.new(15.6, 1, 1.4), Vector3.new(0, 22.4, 0.3), accent)
	lp(m, base, "FrameBottom", Vector3.new(15.6, 1, 1.4), Vector3.new(0, 3.6, 0.3), accent)
	for _, x in { -7.4, 7.4 } do
		lp(m, base, "FrameSide", Vector3.new(1, 19.8, 1.4), Vector3.new(x, 13, 0.3), accent)
	end
	Util.Sign(m, title, Vector3.new(15.6, 3, 1), base * CFrame.new(0, 24.4, 0.2), {
		Name = "Header",
		BoardColor = accent,
	})
end

-- Egg incubator ------------------------------------------------------------------------------

local function priceText(egg: Types.EggDef): string
	if egg.Currency == "Robux" then
		return "R$ " .. Format.Commas(egg.Price)
	elseif egg.Currency == "Tokens" then
		return Format.Abbreviate(egg.Price) .. " Tokens"
	end
	return Format.Abbreviate(egg.Price) .. " Coins"
end

local function buildEggs(parent: Instance)
	local m = Util.Model("EggIncubator", parent)
	local center = Layout.EGG_ARC_CENTER
	-- The arc bulges towards the plaza; `dir` points from the arc centre to the plaza.
	local toHub = Layout.HUB_CENTER - center
	local dir = Vector3.new(toHub.X, 0, toHub.Z).Unit
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local function arcPoint(a: number, r: number): Vector3
		return center + (right * math.sin(a) + dir * math.cos(a)) * r
	end
	local n = #Config.Eggs
	local arc = Layout.EGG_ARC_DEGREES
	for i, egg in Config.Eggs do
		local t = if n > 1 then (i - 1) / (n - 1) else 0.5
		local a = math.rad(-arc / 2 + arc * t)
		local pos = arcPoint(a, Layout.EGG_ARC_RADIUS)
		local out = (pos - center).Unit

		local pedestal = Util.Cylinder(m, "EggPedestal_" .. egg.Id, pos + Vector3.new(0, 1.5, 0), 3, 4.4, MARBLE)
		pedestal:SetAttribute("EggId", egg.Id)
		Util.Tag(pedestal, "EggShop")
		local prompt = Util.Prompt(pedestal, "Hatch", egg.Name, 8)
		prompt:SetAttribute("EggId", egg.Id)

		local ring = Util.Cylinder(
			m,
			"Ring",
			pos + Vector3.new(0, 3.1, 0),
			0.4,
			4.8,
			Build.neonSafe(egg.Look.ShellColor),
			Enum.Material.Neon,
			true
		)
		ring.Parent = pedestal

		local ok, result = pcall(Models.Egg, egg.Id)
		if ok and typeof(result) == "Instance" and result:IsA("Model") then
			local eggModel = result :: Model
			Util.Finish(eggModel, true)
			Util.Ground(eggModel, CFrame.lookAt(pos + Vector3.new(0, 3.3, 0), pos + Vector3.new(0, 3.3, 0) + out))
			eggModel.Parent = pedestal
		else
			warn("[World] Models.Egg failed for", egg.Id, result)
		end

		local bb = Instance.new("BillboardGui")
		bb.Name = "EggInfo"
		bb.Size = UDim2.fromScale(7, 2.8)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 7.5, 0)
		bb.MaxDistance = 70
		bb.LightInfluence = 0
		bb.Parent = pedestal
		Util.Label(bb, egg.Name, egg.Look.ShellColor:Lerp(WHITE, 0.25), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.45))
		local price = Util.Label(
			bb,
			priceText(egg),
			C.Gold,
			UDim2.fromScale(0.1, 0.45),
			UDim2.fromScale(0.8, 0.3),
			Theme.Fonts.Number
		)
		price.Name = "Price"
		local layer = Config.Layers[egg.UnlockLayer]
		if layer and layer.DepthStart > 0 then
			local unlock = Util.Label(
				bb,
				"Unlocks at " .. Format.Depth(layer.DepthStart),
				WHITE,
				UDim2.fromScale(0.15, 0.76),
				UDim2.fromScale(0.7, 0.22),
				Theme.Fonts.Body
			)
			unlock.Name = "Unlock"
		end
	end

	-- Backdrop: "EGGS" sign behind the arc, facing the plaza
	local signPos = center + dir * 9
	local base = Util.Facing(signPos, signPos + dir)
	for _, x in { -7, 7 } do
		lp(m, base, "SignPost", Vector3.new(0.9, 13, 0.9), Vector3.new(x, 6.5, 0.6), WOOD_DARK, Enum.Material.Wood)
	end
	Util.Sign(m, "PET EGGS", Vector3.new(17, 4.6, 0.8), base * CFrame.new(0, 11, 0), {
		Name = "EggSign",
		BoardColor = C.Purple,
		SubText = "Hatch pets for more sand!",
	})
	-- Incubator heat lamps (neon domes on posts) at the arc ends
	for _, sx in { -1, 1 } do
		local p = arcPoint(math.rad(sx * (arc / 2 + 14)), Layout.EGG_ARC_RADIUS + 1)
		Util.Part({
			Name = "LampPost",
			Size = Vector3.new(0.8, 7, 0.8),
			CFrame = CFrame.new(p + Vector3.new(0, 3.5, 0)),
			Color = WHITE,
			Parent = m,
		})
		Util.Ball(m, "Lamp", p + Vector3.new(0, 7.4, 0), 2.2, rgb(210, 145, 40), Enum.Material.Neon)
	end
end

-- Rebirth shrine ------------------------------------------------------------------------------

local function buildRebirth(parent: Instance)
	local m = Util.Model("RebirthShrine", parent)
	local base = hubFacing(Layout.REBIRTH)
	lp(m, base, "Step1", Vector3.new(14, 1, 14), Vector3.new(0, 0.5, 0), MARBLE, Enum.Material.Marble)
	lp(
		m,
		base,
		"Step2",
		Vector3.new(11, 1, 11),
		Vector3.new(0, 1.5, 0),
		C.Purple:Lerp(WHITE, 0.55),
		Enum.Material.Marble
	)
	lp(m, base, "Step3", Vector3.new(8, 1, 8), Vector3.new(0, 2.5, 0), MARBLE, Enum.Material.Marble)
	local pedestal = lp(m, base, "Pedestal", Vector3.new(4, 5, 4), Vector3.new(0, 5.5, 0), MARBLE, Enum.Material.Marble)
	Util.Tag(pedestal, "RebirthStatue")
	Util.Prompt(pedestal, "Rebirth", "Rebirth Shrine", 14)
	local light = Instance.new("PointLight")
	light.Color = C.Purple
	light.Range = 18
	light.Brightness = 0.9
	light.Parent = pedestal

	Util.Cylinder(
		m,
		"GlowDisc",
		(base * CFrame.new(0, 3.05, 0)).Position,
		0.2,
		9,
		rgb(130, 75, 200),
		Enum.Material.Neon,
		true
	)

	-- Golden digger statue holding a shovel up high
	local gold = C.Gold
	local function g(name: string, size: Vector3, offset: Vector3)
		local p = lp(m, base, name, size, offset, gold, nil, true)
		p.Reflectance = 0.25
		p.CastShadow = true
	end
	g("Legs", Vector3.new(2.4, 2.4, 1.4), Vector3.new(0, 9.2, 0))
	g("Torso", Vector3.new(3, 3, 1.6), Vector3.new(0, 11.9, 0))
	g("ArmL", Vector3.new(0.9, 2.8, 0.9), Vector3.new(-1.95, 11.8, 0))
	g("ArmR", Vector3.new(0.9, 3.4, 0.9), Vector3.new(1.95, 14.6, 0))
	g("Handle", Vector3.new(0.4, 6, 0.4), Vector3.new(1.95, 18.5, 0))
	g("Blade", Vector3.new(1.8, 2.4, 0.4), Vector3.new(1.95, 22.4, 0))
	local head = Util.Ball(m, "Head", (base * CFrame.new(0, 14.7, 0)).Position, 2.6, gold)
	head.Reflectance = 0.25
	-- Floating orbs
	for _, x in { -5, 5 } do
		Util.Ball(m, "Orb", (base * CFrame.new(x, 9, 2)).Position, 1.4, rgb(130, 75, 200), Enum.Material.Neon)
	end
	Util.Sign(m, "REBIRTH", Vector3.new(8.6, 2.4, 0.5), base * CFrame.new(0, 4.3, -4.35), {
		Name = "RebirthSign",
		BoardColor = C.Purple,
	})
end

-- Water fountain (free drinks; Survival handles the "Drink" prompt) -------------------------

local function buildFountain(parent: Instance)
	local m = Util.Model("WaterFountain", parent)
	local p = Layout.FOUNTAIN
	local water = rgb(70, 196, 240)
	local basin = Util.Cylinder(m, "Basin", p + Vector3.new(0, 1, 0), 2, 16, MARBLE, Enum.Material.Marble)
	Util.Tag(basin, "WaterFountain")
	Util.Prompt(basin, "Drink", "Water Fountain", 12)
	local pool = Util.Cylinder(m, "Water", p + Vector3.new(0, 2.05, 0), 0.2, 14, water, Enum.Material.Glass, true)
	pool.Transparency = 0.25
	Util.Cylinder(m, "Pillar", p + Vector3.new(0, 4, 0), 4, 2.4, MARBLE, Enum.Material.Marble)
	Util.Cylinder(m, "Bowl", p + Vector3.new(0, 6.3, 0), 0.8, 7, C.Ocean)
	local top = Util.Cylinder(m, "BowlWater", p + Vector3.new(0, 6.75, 0), 0.15, 6.2, water, Enum.Material.Glass, true)
	top.Transparency = 0.25
	Util.Ball(m, "Spout", p + Vector3.new(0, 8.2, 0), 2.2, water, Enum.Material.Glass)
	-- Little splashing "jets" around the bowl
	for k = 0, 5 do
		local a = math.rad(k * 60)
		Util.Ball(
			m,
			"Splash",
			p + Vector3.new(math.cos(a) * 4.4, 3.4, math.sin(a) * 4.4),
			1,
			water,
			Enum.Material.Glass
		)
	end
	local base = Util.Facing(p + Vector3.new(0, 0, -9.5), Layout.HUB_LOOK_TARGET)
	Util.Sign(m, "FREE WATER", Vector3.new(8, 2, 0.4), base * CFrame.new(0, 2.6, 0), {
		Name = "FountainSign",
		BoardColor = C.Ocean,
		TextColor = WHITE,
	})
	for _, x in { -3.4, 3.4 } do
		lp(m, base, "SignPost", Vector3.new(0.5, 2, 0.5), Vector3.new(x, 1, 0.3), WOOD_DARK, Enum.Material.Wood)
	end
end

-- Digger garage (Diggers agent opens its panel from the "Garage" prompt) ---------------------

local function buildGarage(parent: Instance)
	local m = Util.Model("Garage", parent)
	local base = hubFacing(Layout.GARAGE)
	local wall = rgb(236, 226, 206)
	local trim = C.Gold
	local roof = rgb(96, 104, 124)

	lp(m, base, "Floor", Vector3.new(24, 1, 20), Vector3.new(0, 0.5, 0), rgb(150, 150, 160), Enum.Material.Concrete)
	lp(m, base, "BackWall", Vector3.new(24, 14, 1), Vector3.new(0, 7.5, 9.5), wall)
	for _, x in { -11.5, 11.5 } do
		lp(m, base, "SideWall", Vector3.new(1, 14, 20), Vector3.new(x, 7.5, 0), wall)
	end
	-- Front: two pillars and a lintel around the big open door
	for _, x in { -10, 10 } do
		lp(m, base, "Pillar", Vector3.new(3, 14, 1.2), Vector3.new(x, 7.5, -9.6), trim)
	end
	lp(m, base, "Lintel", Vector3.new(24, 3, 1.2), Vector3.new(0, 13, -9.6), trim)
	-- Rolled-up striped door
	for k = 0, 2 do
		lp(
			m,
			base,
			"DoorRoll",
			Vector3.new(17, 0.7, 1.4),
			Vector3.new(0, 10.9 - k * 0.7, -9),
			if k % 2 == 0 then C.Coral else WHITE,
			nil,
			true
		)
	end
	lp(m, base, "Roof", Vector3.new(26, 1.2, 22), Vector3.new(0, 15.1, 0), roof, Enum.Material.Metal)
	lp(m, base, "RoofTrim", Vector3.new(26.4, 0.6, 22.4), Vector3.new(0, 14.4, 0), trim, nil, true)
	Util.Sign(m, "GARAGE", Vector3.new(16, 3.4, 0.6), base * CFrame.new(0, 17.6, -9.6), {
		Name = "GarageSign",
		BoardColor = C.Coral,
		SubText = "DIGGERS",
	})

	-- Workbench just inside the door carries the tag + prompt
	local bench = lp(m, base, "Workbench", Vector3.new(10, 3.4, 3), Vector3.new(0, 2.7, -5), C.Ocean)
	lp(m, base, "BenchTop", Vector3.new(10.6, 0.5, 3.4), Vector3.new(0, 4.6, -5), WOOD, Enum.Material.WoodPlanks)
	Util.Tag(bench, "Garage")
	Util.Prompt(bench, "Garage", "Diggers", 14)

	-- Toy digger on display (pure decor)
	local yellow = rgb(255, 196, 40)
	local dark = rgb(60, 64, 76)
	lp(m, base, "DiggerTracks", Vector3.new(6, 1.4, 4.4), Vector3.new(0, 1.7, 3.5), dark, nil, true)
	lp(m, base, "DiggerBody", Vector3.new(5, 2.4, 4), Vector3.new(0, 3.6, 3.5), yellow, nil, true)
	lp(
		m,
		base,
		"DiggerCab",
		Vector3.new(2.6, 2.4, 2.6),
		Vector3.new(-1, 6, 3.8),
		rgb(140, 210, 245),
		Enum.Material.Glass,
		true
	)
	local arm = lp(m, base, "DiggerArm", Vector3.new(0.8, 0.8, 5), Vector3.new(1.6, 6, 0.8), yellow, nil, true)
	arm.CFrame = base * CFrame.new(1.6, 6, 0.8) * CFrame.Angles(math.rad(-25), 0, 0)
	lp(
		m,
		base,
		"DiggerBucket",
		Vector3.new(2.2, 1.6, 1.4),
		Vector3.new(1.6, 3.6, -1.6),
		dark,
		Enum.Material.Metal,
		true
	)
end

-- Beach shop stall: shade + snacks (Survival opens its panel from the "Shop" prompt) ----------

local function buildBeachShop(parent: Instance)
	local m = Util.Model("BeachShop", parent)
	local base = hubFacing(Layout.BEACH_SHOP)
	local lime = rgb(150, 220, 80)

	lp(m, base, "Floor", Vector3.new(16, 1, 12), Vector3.new(0, 0.5, 0), WOOD, Enum.Material.WoodPlanks)
	local counter = lp(m, base, "Counter", Vector3.new(14, 3.6, 3), Vector3.new(0, 2.8, -3.5), lime)
	lp(m, base, "CounterTop", Vector3.new(15, 0.5, 3.6), Vector3.new(0, 4.85, -3.5), WOOD, Enum.Material.WoodPlanks)
	Util.Tag(counter, "BeachShop")
	Util.Prompt(counter, "Shop", "Beach Shop", 14)
	lp(m, base, "BackWall", Vector3.new(16, 9, 0.8), Vector3.new(0, 5, 5.6), C.Ocean:Lerp(WHITE, 0.5))
	for _, x in { -7.6, 7.6 } do
		for _, z in { -5.4, 5.4 } do
			lp(m, base, "Post", Vector3.new(0.8, 11, 0.8), Vector3.new(x, 6, z), WHITE)
		end
	end
	-- Striped awning (lime / white)
	for k = 0, 5 do
		local color = if k % 2 == 0 then lime else WHITE
		local awning = lp(m, base, "Awning", Vector3.new(2.8, 0.5, 13), Vector3.new(-7 + k * 2.8, 11.6, 0), color)
		awning.CFrame = base * CFrame.new(-7 + k * 2.8, 11.6, 0) * CFrame.Angles(math.rad(-8), 0, 0)
	end
	-- Display: lemonade jug, coconuts, folded umbrella
	Util.Cylinder(
		m,
		"Lemonade",
		(base * CFrame.new(-4.5, 6.2, -3.5)).Position,
		2.2,
		1.8,
		rgb(255, 236, 90),
		Enum.Material.Glass,
		true
	)
	for k = 0, 2 do
		Util.Ball(m, "Coconut", (base * CFrame.new(-0.8 + k * 1.5, 5.7, -3.3)).Position, 1.4, rgb(120, 80, 50))
	end
	Util.Cylinder(m, "UmbrellaPole", (base * CFrame.new(4.8, 7.4, -3.5)).Position, 4.6, 0.3, WHITE, nil, true)
	Util.Part({
		Name = "UmbrellaTop",
		Size = Vector3.new(1.4, 2.4, 1.4),
		CFrame = base * CFrame.new(4.8, 8.6, -3.5),
		Color = C.Coral,
		Material = Enum.Material.Fabric,
		Decor = true,
		Parent = m,
	})
	Util.Sign(m, "BEACH SHOP", Vector3.new(14, 3.2, 0.6), base * CFrame.new(0, 14.2, -5.6), {
		Name = "BeachShopSign",
		BoardColor = lime,
		SubText = "SHADE & SNACKS",
	})
end

function Hub.Build(parent: Instance)
	buildSpawns(parent)
	buildSell(parent)
	buildShops(parent)
	buildLeaderboard(parent, "LeaderboardCoins", Layout.LEADERBOARD_COINS, "LeaderboardCoins", "RICHEST", C.Gold)
	buildLeaderboard(parent, "LeaderboardDepth", Layout.LEADERBOARD_DEPTH, "LeaderboardDepth", "DEEPEST", C.Ocean)
	buildEggs(parent)
	buildRebirth(parent)

	buildFountain(parent)
	buildGarage(parent)
	buildBeachShop(parent)

	-- Bunting flag poles around the plaza
	local flagColors = { C.Coral, C.Ocean, C.Gold, C.Palm }
	local i = 0
	for _, x in { -22, 22 } do
		for _, dz in { -12, 14 } do
			i += 1
			local p = Vector3.new(x, S, Layout.HUB_CENTER.Z + dz)
			Util.Part({
				Name = "FlagPole",
				Size = Vector3.new(0.6, 14, 0.6),
				CFrame = CFrame.new(p + Vector3.new(0, 7, 0)),
				Color = WHITE,
				Parent = parent,
			})
			Util.Wedge({
				Name = "Flag",
				Size = Vector3.new(0.2, 2.6, 4),
				CFrame = CFrame.new(p + Vector3.new(0, 12.4, 2)),
				Color = flagColors[i],
				Decor = true,
				Parent = parent,
			})
		end
	end
end

return Hub
