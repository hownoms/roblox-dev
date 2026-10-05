--!strict
--[[
	Hub — the plaza between the plot rows: spawns, Sell stand, Shovel & Backpack huts, Egg
	incubator, Rebirth shrine and two leaderboards. Hero structures are built from Parts in a
	local frame whose -Z (front) faces the spawn.

	Tags placed: SpawnLocation, SellZone, ShovelShop, BackpackShop, EggShop (one per egg, with
	attribute EggId on the part and on its ProximityPrompt), RebirthStatue, LeaderboardCoins,
	LeaderboardDepth.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Models = require(ReplicatedStorage.Shared.Models)
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
		-- Face the ocean / Sell stand (-Z)
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
	local base = hubFacing(Layout.SELL)

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
	local pad = lp(m, base, "SellZone", Vector3.new(16, 1, 8), Vector3.new(0, 2.2, -6.5), C.Success, Enum.Material.Neon)
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
	local n = #Config.Eggs
	local arc = Layout.EGG_ARC_DEGREES
	for i, egg in Config.Eggs do
		local t = if n > 1 then (i - 1) / (n - 1) else 0.5
		local a = math.rad(-arc / 2 + arc * t)
		local pos = center + Vector3.new(Layout.EGG_ARC_RADIUS * math.sin(a), 0, Layout.EGG_ARC_RADIUS * math.cos(a))
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
			egg.Look.ShellColor,
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
	local signPos = center + Vector3.new(0, 0, 9)
	local base = Util.Facing(signPos, Layout.SPAWNS[1])
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
		local a = math.rad(sx * (arc / 2 + 14))
		local p = center
			+ Vector3.new((Layout.EGG_ARC_RADIUS + 1) * math.sin(a), 0, (Layout.EGG_ARC_RADIUS + 1) * math.cos(a))
		Util.Part({
			Name = "LampPost",
			Size = Vector3.new(0.8, 7, 0.8),
			CFrame = CFrame.new(p + Vector3.new(0, 3.5, 0)),
			Color = WHITE,
			Parent = m,
		})
		Util.Ball(m, "Lamp", p + Vector3.new(0, 7.4, 0), 2.2, C.Warning, Enum.Material.Neon)
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
	light.Brightness = 1.5
	light.Parent = pedestal

	Util.Cylinder(m, "GlowDisc", (base * CFrame.new(0, 3.05, 0)).Position, 0.2, 9, C.Purple, Enum.Material.Neon, true)

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
		Util.Ball(m, "Orb", (base * CFrame.new(x, 9, 2)).Position, 1.4, C.Purple, Enum.Material.Neon)
	end
	Util.Sign(m, "REBIRTH", Vector3.new(8.6, 2.4, 0.5), base * CFrame.new(0, 4.3, -4.35), {
		Name = "RebirthSign",
		BoardColor = C.Purple,
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

	-- Bunting flag poles around the plaza
	local flagColors = { C.Coral, C.Ocean, C.Gold, C.Palm }
	local i = 0
	for _, x in { -24, 24 } do
		for _, z in { -12, 12 } do
			i += 1
			local p = Vector3.new(x, S, z)
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
