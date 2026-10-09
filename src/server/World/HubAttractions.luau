--!strict
--[[
	HubAttractions — the hub's bigger set pieces (built by World/Hub.luau):
	  EggIncubator  pastel hatchery: the 9 marble egg pedestals on straw nests + pastel pavers,
	                a giant hatching egg (a pet peeking out of the cracked top), warm heat lamps,
	                pastel bunting.
	  CrateYard     construction yard: the Construction Crate pallets in front of a fenced yard
	                with a tower crane (swinging crate), scaffolding holding the sign, stacked
	                crates, sacks, cable spool, work light and a porta-loo.
	  RebirthShrine mystical temple: the 3 marble steps + statue, a colonnade, a spinning neon
	                portal ring, a golden halo, braziers, runes, bobbing orbs, sparkles.
	  Hall of Fame  the two leaderboards as marble columned frames with pediments and marquee
	                bulbs, joined by a central column carrying a giant trophy.
	Tagged parts (EggShop / CrateShop / RebirthStatue / LeaderboardCoins / LeaderboardDepth),
	their attributes, prompts and the pinned names (Step1, Board size/face) are unchanged.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Models = require(ReplicatedStorage.Shared.Models)
local Build = require(ReplicatedStorage.Shared.Models.Build)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Types = require(ReplicatedStorage.Shared.Types)
local Layout = require(script.Parent.Layout)
local Util = require(script.Parent.Util)
local Kit = require(script.Parent.HubKit)

local Theme = Config.Theme
local C = Theme.Colors
local rgb = Color3.fromRGB
local rad = math.rad
local V = Vector3.new
local at = Kit.at
local box = Kit.box
local WHITE = Kit.WHITE
local MARBLE = Kit.MARBLE
local MARBLE_MAT = Enum.Material.Marble
local METAL = Enum.Material.Metal
local WOOD_MAT = Enum.Material.Wood
local FABRIC = Enum.Material.Fabric

local PASTELS = { rgb(255, 190, 214), rgb(180, 220, 255), rgb(190, 240, 210), rgb(255, 236, 170), rgb(220, 196, 255) }

local HubAttractions = {}

local function priceText(egg: Types.EggDef): string
	if egg.Currency == "Robux" then
		return "R$ " .. Format.Commas(egg.Price)
	elseif egg.Currency == "Tokens" then
		return Format.Abbreviate(egg.Price) .. " Tokens"
	end
	return Format.Abbreviate(egg.Price) .. " Coins"
end

local function infoLabels(bb: BillboardGui, egg: Types.EggDef, nameColor: Color3)
	Util.Label(bb, egg.Name, nameColor, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.45))
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

-- Display egg / crate models keep their sparkles but not their PointLights (hub light budget;
-- the neon rings already glow).
local function dropLights(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("Light") then
			d:Destroy()
		end
	end
end

-- Pastel hatchery --------------------------------------------------------------------------

local function giantEgg(m: Model, ground: CFrame)
	-- lathe of discs: an egg 19 studs tall, cracked open at the top
	local radii = { 6.2, 7.3, 7.7, 7.6, 7.2, 6.5, 5.5, 4.2 }
	local h = 2.4
	local cream = rgb(255, 246, 226)
	local bands: { [number]: Color3 } = { [3] = PASTELS[1], [6] = PASTELS[3] }
	for i, r in radii do
		local disc = Kit.cyl(
			m,
			"GiantEgg",
			ground * CFrame.new(0, (i - 0.5) * h, 0),
			h + 0.05,
			r * 2,
			bands[i] or cream,
			nil,
			i <= 3
		)
		disc.CastShadow = true
	end
	-- pastel spots on the plaza-facing side (front = -Z)
	local spots = { { -40, 3, 1 }, { 25, 5.6, 2 }, { -10, 10.4, 4 }, { 50, 12.6, 5 }, { -55, 15.4, 2 } }
	for _, s in spots do
		local yIdx = math.clamp(math.floor(s[2] / h) + 1, 1, #radii)
		local r = radii[yIdx] - 0.5
		local a = rad(s[1])
		Kit.ball(
			m,
			"EggSpot",
			(ground * CFrame.new(math.sin(a) * r, s[2], -math.cos(a) * r)).Position,
			3,
			PASTELS[s[3]]
		)
	end
	-- jagged shell shards around the open top
	local topY = #radii * h
	for k = 0, 6 do
		local a = rad(k * (360 / 7))
		local r = radii[#radii] - 0.6
		local tall = 1.6 + (k % 3) * 0.7
		box(
			m,
			"EggShard",
			ground
				* CFrame.new(math.sin(a) * r, topY + tall / 2 - 0.2, math.cos(a) * r)
				* CFrame.Angles(0, a, rad(if k % 2 == 0 then 12 else -12)),
			V(2.6, tall, 0.6),
			cream
		)
	end
	-- straw nest under the egg
	Kit.cyl(m, "Nest", ground * CFrame.new(0, 0.6, 0), 1.2, 17, Kit.THATCH_DARK, Enum.Material.Grass, true)
	for k = 0, 4 do
		local a = rad(k * 72 + 20)
		box(
			m,
			"Straw",
			ground * CFrame.new(math.sin(a) * 8.2, 1.2, math.cos(a) * 8.2) * CFrame.Angles(0, a, rad(30)),
			V(0.3, 2.6, 0.3),
			Kit.THATCH,
			Enum.Material.Grass
		)
	end
	-- a pet peeking out of the top
	local pets = Config.Pets
	local pet = pets[math.min(4, #pets)]
	if pet then
		Kit.display(Models.Pet, pet.Id, m, ground * CFrame.new(0, topY - 1.5, -0.5), 3.2)
	end
	return topY
end

local function heatLamp(m: Model, pos: Vector3, toward: Vector3, color: Color3): Vector3
	local cf = Util.Facing(pos, toward)
	Kit.cyl(m, "LampPost", cf * CFrame.new(0, 4.5, 0), 9, 0.6, WHITE, METAL, true)
	Kit.cyl(m, "LampFoot", cf * CFrame.new(0, 0.3, 0), 0.6, 1.8, color)
	box(m, "LampArm", cf * CFrame.new(0, 8.8, -1.3), V(0.4, 0.4, 2.8), WHITE, METAL)
	Kit.cyl(m, "LampShade", cf * CFrame.new(0, 8.6, -2.7), 0.9, 2.8, color)
	local bulb = Kit.neon(
		m,
		"LampBulb",
		cf * CFrame.new(0, 7.9, -2.7),
		V(1.4, 1.4, 1.4),
		rgb(255, 150, 60),
		false,
		Enum.PartType.Ball
	)
	Kit.light(bulb, rgb(255, 170, 90), 14, 1)
	return (cf * CFrame.new(0, 9.2, 0)).Position
end

local function buildEggs(parent: Instance)
	local m = Kit.model(parent, "EggIncubator")
	local center = Layout.EGG_ARC_CENTER
	-- The arc bulges towards the plaza; `dir` points from the arc centre to the plaza.
	local toHub = Layout.HUB_CENTER - center
	local dir = V(toHub.X, 0, toHub.Z).Unit
	local right = V(-dir.Z, 0, dir.X)
	local function arcPoint(a: number, r: number): Vector3
		return center + (right * math.sin(a) + dir * math.cos(a)) * r
	end
	local eggs: { Types.EggDef } = {}
	for _, egg in Config.Eggs do
		if egg.Kind ~= "Crate" then -- crates get their own yard (buildCrateYard)
			table.insert(eggs, egg)
		end
	end
	local n = #eggs
	local arc = Layout.EGG_ARC_DEGREES
	local sparkleBudget = 3
	for i = n, 1, -1 do
		local egg = eggs[i]
		local t = if n > 1 then (i - 1) / (n - 1) else 0.5
		local a = math.rad(-arc / 2 + arc * t)
		-- +2: smooth terrain's visible surface sits ~2 studs above the voxel grid, so pedestals
		-- placed at the grid height looked sunk and their labels ended up in the sand.
		local pos = arcPoint(a, Layout.EGG_ARC_RADIUS) + V(0, 2, 0)
		local out = (pos - center) * V(1, 0, 1)
		out = out.Unit
		local face = CFrame.lookAt(pos, pos + out)

		local pedestal = Util.Cylinder(m, "EggPedestal_" .. egg.Id, pos + V(0, 0.5, 0), 5, 4.4, MARBLE) -- 2 studs sunk into the sand
		pedestal:SetAttribute("EggId", egg.Id)
		Util.Tag(pedestal, "EggShop")
		local prompt = Util.Prompt(pedestal, "Hatch", egg.Name, 8)
		prompt:SetAttribute("EggId", egg.Id)

		local ring = Util.Cylinder(
			m,
			"Ring",
			pos + V(0, 3.1, 0),
			0.4,
			4.8,
			Build.neonSafe(egg.Look.ShellColor),
			Enum.Material.Neon,
			true
		)
		ring.Parent = pedestal
		-- straw nest round the pedestal foot and a pastel paver under it
		Kit.cyl(m, "Nest", CFrame.new(pos + V(0, 0.45, 0)), 0.9, 6.4, Kit.THATCH_DARK, Enum.Material.Grass)
		box(
			m,
			"Paver",
			face * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, rad(45), 0),
			V(6.6, 0.3, 6.6),
			PASTELS[(i - 1) % #PASTELS + 1]
		)

		local ok, result = pcall(Models.Egg, egg.Id)
		if ok and typeof(result) == "Instance" and result:IsA("Model") then
			local eggModel = result :: Model
			Util.Finish(eggModel, true)
			dropLights(eggModel)
			for _, d in eggModel:GetDescendants() do
				if d:IsA("ParticleEmitter") then
					if sparkleBudget > 0 then
						sparkleBudget -= 1
					else
						d:Destroy() -- hub emitter budget: only the rarest eggs sparkle
					end
				end
			end
			Util.Ground(eggModel, CFrame.lookAt(pos + V(0, 3.3, 0), pos + V(0, 3.3, 0) + out))
			eggModel.Parent = pedestal
		else
			warn("[World] Models.Egg failed for", egg.Id, result)
		end

		local bb = Instance.new("BillboardGui")
		bb.Name = "EggInfo"
		bb.Size = UDim2.fromScale(6, 2.4)
		-- Anchor to an unrotated attachment above the pedestal, not the pedestal itself: the
		-- pedestal is a cylinder rotated 90° about Z, and its rotation turned the billboard's
		-- "+Y" offset sideways, so the labels sat at pedestal-centre height in the sand, next to
		-- the wrong eggs. Pedestals are ~4.6 studs apart and labels 6 wide, so every other one is
		-- raised by more than a label's height to keep neighbours from overlapping.
		local anchor = Instance.new("Attachment")
		anchor.Name = "EggInfoAnchor"
		anchor.Parent = pedestal
		local labelHeight = if i % 2 == 0 then 10.6 else 8
		anchor.Position = pedestal.CFrame:PointToObjectSpace(pedestal.Position + V(0, labelHeight, 0))
		bb.Adornee = anchor
		bb.MaxDistance = 40
		bb.LightInfluence = 0
		bb.Parent = pedestal
		infoLabels(bb, egg, egg.Look.ShellColor:Lerp(WHITE, 0.25))
	end

	-- the giant hatching egg at the arc centre, facing the plaza
	local ground = Util.Facing(Kit.onSand(center), center + dir)
	local topY = giantEgg(m, ground)

	-- sign on short pastel posts in front of the egg
	local signPos = Kit.onSand(center + dir * 10)
	local base = Util.Facing(signPos, signPos + dir)
	for k, x in { -7.6, 7.6 } do
		Kit.cyl(m, "SignPost", at(base, x, 3.6, 0.5), 7.2, 0.9, PASTELS[k + 1], nil, true)
		Kit.ball(m, "SignFinial", (base * CFrame.new(x, 7.6, 0.5)).Position, 1.4, PASTELS[k + 3])
	end
	Util.Sign(m, "PET EGGS", V(17, 4.6, 0.8), at(base, 0, 5.4, 0), {
		Name = "EggSign",
		BoardColor = C.Purple,
		SubText = "Hatch pets for more sand!",
	})
	-- warm heat lamps at the arc ends and pastel bunting up to the egg's crown
	local crown = (ground * CFrame.new(0, topY + 1, 0)).Position
	for k, sx in { -1, 1 } do
		local p = Kit.onSand(arcPoint(math.rad(sx * (arc / 2 + 14)), Layout.EGG_ARC_RADIUS + 1))
		local top = heatLamp(m, p, center, PASTELS[k * 2])
		Kit.bunting(m, top, crown, 2.2, PASTELS, 6)
	end
end

-- Construction yard -------------------------------------------------------------------------

local CRATE_YARD = Layout.GARAGE
local CRATE_ARC_RADIUS = 16
local CRATE_ARC_DEGREES = 80

local function cone(m: Model, pos: Vector3)
	local orange = rgb(255, 120, 30)
	box(m, "ConeBase", CFrame.new(pos + V(0, 0.15, 0)), V(2.4, 0.3, 2.4), orange)
	Kit.cyl(m, "Cone", CFrame.new(pos + V(0, 1.4, 0)), 2.4, 1.4, orange)
	Kit.cyl(m, "ConeStripe", CFrame.new(pos + V(0, 1.6, 0)), 0.4, 1.45, WHITE)
end

local function tape(m: Model, a: Vector3, b: Vector3)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(mid, b)
	for k = 0, 1 do
		box(
			m,
			"HazardTape",
			cf * CFrame.new(0, -0.1 * k, (k - 0.5) * len / 2),
			V(0.1, 0.35, len / 2),
			if k == 0 then Kit.HAZARD else Kit.BLACK,
			FABRIC
		)
	end
end

local function buildCrateYard(parent: Instance)
	local crates: { Types.EggDef } = {}
	for _, egg in Config.Eggs do
		if egg.Kind == "Crate" then
			table.insert(crates, egg)
		end
	end
	if #crates == 0 then
		return
	end
	local m = Kit.model(parent, "CrateYard")
	local toHub = Layout.HUB_CENTER - CRATE_YARD
	local dir = V(toHub.X, 0, toHub.Z).Unit
	local right = V(-dir.Z, 0, dir.X)
	local center = CRATE_YARD - dir * 10
	local function arcPoint(a: number, r: number): Vector3
		return center + (right * math.sin(a) + dir * math.cos(a)) * r
	end
	local hazard = Kit.HAZARD
	local black = Kit.BLACK
	local n = #crates
	for i, egg in crates do
		local t = if n > 1 then (i - 1) / (n - 1) else 0.5
		local a = math.rad(-CRATE_ARC_DEGREES / 2 + CRATE_ARC_DEGREES * t)
		-- +2: smooth terrain's visible surface sits ~2 studs above the voxel grid (see buildEggs)
		local pos = arcPoint(a, CRATE_ARC_RADIUS) + V(0, 2, 0)
		local out = ((pos - center) * V(1, 0, 1)).Unit
		local base = CFrame.lookAt(pos, pos + out)

		-- pallet (2 studs sunk into the sand, top at pos.Y + 1)
		local pallet = box(
			m,
			"CratePallet_" .. egg.Id,
			base * CFrame.new(0, -0.5, 0),
			V(6, 3, 6),
			Kit.WOOD,
			Enum.Material.WoodPlanks,
			true
		)
		pallet:SetAttribute("EggId", egg.Id)
		Util.Tag(pallet, "CrateShop")
		local prompt = Util.Prompt(pallet, "Open", egg.Name, 8)
		prompt:SetAttribute("EggId", egg.Id)
		for k = -1, 1 do
			box(m, "PalletSlat", base * CFrame.new(0, 1.1, k * 2.3), V(6.2, 0.3, 1.2), Kit.WOOD_DARK, WOOD_MAT).Parent =
				pallet
		end
		-- hazard stripes on the pallet's front edge
		for k = 0, 2 do
			box(
				m,
				"HazardStripe",
				base * CFrame.new(-2 + k * 2, 0.4, -3.05),
				V(2, 0.5, 0.2),
				if k % 2 == 0 then hazard else black
			).Parent =
				pallet
		end

		local ok, result = pcall(Models.Egg, egg.Id)
		if ok and typeof(result) == "Instance" and result:IsA("Model") then
			local crateModel = result :: Model
			Util.Finish(crateModel, true)
			dropLights(crateModel)
			for _, d in crateModel:GetDescendants() do
				if d:IsA("ParticleEmitter") then
					d:Destroy() -- hub emitter budget (the pet-egg displays keep theirs)
				end
			end
			Util.Ground(crateModel, CFrame.lookAt(pos + V(0, 1.3, 0), pos + V(0, 1.3, 0) + out))
			crateModel.Parent = pallet
		else
			warn("[World] Models.Egg failed for", egg.Id, result)
		end

		local bb = Instance.new("BillboardGui")
		bb.Name = "CrateInfo"
		bb.Size = UDim2.fromScale(6, 2.4)
		bb.StudsOffsetWorldSpace = V(0, 7.5, 0)
		bb.MaxDistance = 40
		bb.LightInfluence = 0
		bb.Parent = pallet
		infoLabels(bb, egg, egg.Look.SpotColor:Lerp(WHITE, 0.2))
	end

	-- yard frame: -Z faces the plaza, +Z is the back of the yard
	local yard = Util.Facing(Kit.onSand(center), center + dir)
	local rng = Random.new(780044)

	-- packed-gravel ground (flush, decor) and the fence round the back of the yard
	box(m, "YardGround", at(yard, 0, 0.04, 1.5), V(38, 0.2, 22), rgb(206, 192, 162), Enum.Material.Slate)
	local fenceColor = rgb(255, 128, 40)
	local corners = { V(-19, 0, -8), V(-19, 0, 12), V(19, 0, 12), V(19, 0, -8) }
	for k = 1, #corners - 1 do
		local a, b = corners[k], corners[k + 1]
		local segs = if k == 2 then 4 else 2
		for s = 0, segs - 1 do
			local p0 = a:Lerp(b, s / segs)
			local p1 = a:Lerp(b, (s + 1) / segs)
			local mid = (p0 + p1) / 2
			local len = (p1 - p0).Magnitude
			local panelCF = yard * CFrame.lookAt(mid, p1) * CFrame.new(0, 2.2, 0)
			local panel = box(m, "FencePanel", panelCF, V(0.15, 3.4, len - 0.4), fenceColor, FABRIC)
			panel.Transparency = 0.3
			box(m, "FenceRail", panelCF * CFrame.new(0, 1.8, 0), V(0.3, 0.3, len), Kit.STEEL, METAL)
			box(m, "FencePost", yard * CFrame.new(p0 + V(0, 2.1, 0)), V(0.5, 4.2, 0.5), Kit.STEEL_DARK, METAL, true)
		end
	end
	for _, c in { corners[4] } do
		box(m, "FencePost", yard * CFrame.new(c + V(0, 2.1, 0)), V(0.5, 4.2, 0.5), Kit.STEEL_DARK, METAL, true)
	end
	local hardHat = Util.Sign(m, "HARD HAT AREA", V(5, 2, 0.2), at(yard, -19, 3, -8.3), {
		Name = "HardHatSign",
		BoardColor = hazard,
		TextColor = WHITE,
		Decor = true,
	})
	hardHat.CastShadow = false

	-- scaffolding carrying the CONSTRUCTION CRATES sign
	local sc = yard * CFrame.new(0, 0, 1)
	for _, x in { -10.4, 10.4 } do
		for _, z in { 0.6, 4 } do
			box(m, "ScaffoldPole", sc * CFrame.new(x, 8, z), V(0.5, 16, 0.5), Kit.STEEL, METAL, true)
		end
		box(
			m,
			"ScaffoldBrace",
			sc * CFrame.new(x, 4.5, 2.3) * CFrame.Angles(rad(52), 0, 0),
			V(0.3, 8.6, 0.3),
			Kit.STEEL_DARK,
			METAL
		)
	end
	for _, y in { 5, 15.6 } do
		box(m, "ScaffoldPlank", sc * CFrame.new(0, y, 2.3), V(21.4, 0.4, 3.6), Kit.WOOD, Enum.Material.WoodPlanks)
		box(m, "ScaffoldToeBoard", sc * CFrame.new(0, y + 0.5, 0.6), V(21.4, 0.6, 0.2), hazard)
	end
	Util.Sign(m, "CONSTRUCTION CRATES", V(19, 4.6, 0.8), sc * CFrame.new(0, 10.2, 0), {
		Name = "CrateSign",
		BoardColor = rgb(240, 160, 30),
		SubText = "Pets that DIG for you!",
	})
	Kit.flag(m, (sc * CFrame.new(10.4, 16, 4)).Position, 6, 90, hazard, black)

	-- tower crane: truss mast, cab, jib towards the sign with a swinging crate
	local mast = yard * CFrame.new(13, 0, 9)
	local mastH = 44
	box(m, "CraneFoot", mast * CFrame.new(0, 0.6, 0), V(5, 1.2, 5), rgb(190, 190, 196), Enum.Material.Concrete, true)
	Kit.truss(m, "CraneMast", mast * CFrame.new(0, 1.2 + mastH / 2, 0), mastH, hazard)
	local topPos = (mast * CFrame.new(0, 1.2 + mastH + 1, 0)).Position
	local hookPos = (yard * CFrame.new(-2, 0, -1)).Position
	local jibDir = (V(hookPos.X, topPos.Y, hookPos.Z) - topPos).Unit
	local jibCF = CFrame.lookAt(topPos, topPos + jibDir)
	local reach = (V(hookPos.X, topPos.Y, hookPos.Z) - topPos).Magnitude
	local jibLen = 2 * math.ceil((reach + 4 + 10) / 2)
	Kit.truss(
		m,
		"CraneJib",
		jibCF * CFrame.new(0, 0, -(jibLen / 2 - 10)) * CFrame.Angles(rad(90), 0, 0),
		jibLen,
		hazard
	)
	box(m, "CraneCab", jibCF * CFrame.new(1.8, -1.6, -1.2), V(3, 3, 3), hazard, METAL)
	local cabGlass = box(
		m,
		"CraneCabGlass",
		jibCF * CFrame.new(1.8, -1.4, -2.75),
		V(2.4, 1.6, 0.2),
		rgb(150, 220, 255),
		Enum.Material.Glass
	)
	cabGlass.Transparency = 0.3
	box(m, "CraneWeight", jibCF * CFrame.new(0, -1.2, 8), V(3.6, 3, 3.6), rgb(170, 170, 176), Enum.Material.Concrete)
	box(m, "CraneApex", jibCF * CFrame.new(0, 3, 0), V(1, 6, 1), hazard, METAL)
	box(
		m,
		"CraneTie",
		jibCF * CFrame.new(0, 3.5, -reach / 2) * CFrame.Angles(-math.atan2(5, reach), 0, 0),
		V(0.25, 0.25, math.sqrt(25 + reach * reach)),
		Kit.STEEL_DARK,
		METAL
	)
	box(
		m,
		"CraneTie",
		jibCF * CFrame.new(0, 3.5, 4) * CFrame.Angles(math.atan2(5, 8), 0, 0),
		V(0.25, 0.25, 9.4),
		Kit.STEEL_DARK,
		METAL
	)
	local trolley = jibCF * CFrame.new(0, -1.3, -reach)
	box(m, "CraneTrolley", trolley, V(2.2, 0.8, 2.2), black, METAL)
	local load = Kit.model(m, "CraneLoad")
	local cable = 19
	box(load, "CraneCable", trolley * CFrame.new(0, -cable / 2, 0), V(0.18, cable, 0.18), black, METAL)
	box(load, "CraneHook", trolley * CFrame.new(0, -cable - 0.4, 0), V(0.8, 0.8, 0.8), hazard, METAL)
	for _, sx in { -1, 1 } do
		box(
			load,
			"CraneSling",
			trolley * CFrame.new(sx * 1.1, -cable - 1.5, 0) * CFrame.Angles(0, 0, rad(sx * 30)),
			V(0.12, 2.6, 0.12),
			black
		)
	end
	Kit.crate(load, trolley * CFrame.new(0, -cable - 4.4, 0) * CFrame.Angles(0, rad(20), 0), 3.8, rgb(232, 170, 70))
	box(
		load,
		"CrateStencil",
		trolley * CFrame.new(0, -cable - 4.4, 0) * CFrame.Angles(0, rad(20), 0) * CFrame.new(0, 0, -1.96),
		V(2, 2, 0.1),
		hazard
	)
	Kit.ambient(load, "AmbientSway", trolley, { SwayDegrees = 4, SwayPeriod = 4.2 })

	-- stacked crates (3 + 2 + 1, jittered), sacks, spool, wheelbarrow, porta-loo, work light
	local stack = yard * CFrame.new(-12.5, 0, 7.5)
	local rows = { { -3.8, 0, 3.8 }, { -1.9, 1.9 }, { 0 } }
	local y = 0
	for r, row in rows do
		local s = 3.8 - r * 0.25
		for _, x in row do
			Kit.crate(
				m,
				stack
					* CFrame.new(x + rng:NextNumber(-0.3, 0.3), y + s / 2, rng:NextNumber(-0.4, 0.4))
					* CFrame.Angles(0, rad(rng:NextNumber(-12, 12)), 0),
				s,
				if r == 2 then rgb(214, 150, 80) else nil
			)
		end
		y += s
	end
	for k = 0, 2 do
		Kit.sack(
			m,
			yard * CFrame.new(5 + k * 1.9, 0, 9.8 - (k % 2) * 0.6) * CFrame.Angles(0, rad(rng:NextNumber(-25, 25)), 0),
			1.9,
			rgb(206, 206, 196)
		)
	end
	Kit.sack(m, yard * CFrame.new(6.9, 1.7, 9.4) * CFrame.Angles(0, rad(80), rad(90)), 1.8, rgb(206, 206, 196))
	local spool = yard * CFrame.new(-4, 0, 9) * CFrame.Angles(0, rad(25), 0)
	for _, z in { -1.1, 1.1 } do
		Kit.cyl(m, "SpoolEnd", spool * CFrame.new(0, 2, z) * CFrame.Angles(rad(90), 0, 0), 0.35, 4, Kit.WOOD, WOOD_MAT)
	end
	Kit.cyl(m, "SpoolCable", spool * CFrame.new(0, 2, 0) * CFrame.Angles(rad(90), 0, 0), 1.9, 2.8, black)
	local barrow = yard * CFrame.new(-14.5, 0, -4) * CFrame.Angles(0, rad(-35), 0)
	box(m, "BarrowTray", barrow * CFrame.new(0, 1.7, 0), V(2.4, 1.1, 3.4), C.Ocean, METAL)
	Kit.ball(m, "BarrowSand", (barrow * CFrame.new(0, 2.2, 0)).Position, 2.2, Kit.SAND, Enum.Material.Sand)
	Kit.cyl(m, "BarrowWheel", barrow * CFrame.new(0, 0.7, -2) * CFrame.Angles(0, 0, rad(90)), 0.4, 1.4, black)
	for _, sx in { -0.9, 0.9 } do
		box(
			m,
			"BarrowHandle",
			barrow * CFrame.new(sx, 1.4, 2.6) * CFrame.Angles(rad(-15), 0, 0),
			V(0.25, 0.25, 3),
			Kit.WOOD_DARK,
			WOOD_MAT
		)
	end
	local loo = yard * CFrame.new(16.2, 0, 9.4) * CFrame.Angles(0, rad(-90), 0)
	box(m, "PortaLoo", loo * CFrame.new(0, 3, 0), V(3.4, 6, 3.4), C.Ocean, nil, true)
	box(m, "PortaLooRoof", loo * CFrame.new(0, 6.2, 0), V(3.8, 0.4, 3.8), WHITE)
	box(m, "PortaLooDoor", loo * CFrame.new(0, 2.9, -1.72), V(2.4, 5, 0.1), Kit.NAVY)
	Kit.neon(m, "PortaLooSign", loo * CFrame.new(0, 4.8, -1.8), V(1.2, 0.4, 0.05), C.Palm)
	local lamp = yard * CFrame.new(-17, 0, 1) * CFrame.Angles(0, rad(-60), 0)
	box(m, "WorkLightPole", lamp * CFrame.new(0, 3.5, 0), V(0.4, 7, 0.4), black, METAL, true)
	box(
		m,
		"WorkLightHead",
		lamp * CFrame.new(0, 7.2, -0.4) * CFrame.Angles(rad(-25), 0, 0),
		V(2.4, 1.6, 0.8),
		hazard,
		METAL
	)
	local panel = Kit.neon(
		m,
		"WorkLightPanel",
		lamp * CFrame.new(0, 7.0, -0.85) * CFrame.Angles(rad(-25), 0, 0),
		V(2, 1.2, 0.1),
		rgb(255, 230, 150),
		true
	)
	Kit.light(panel, rgb(255, 236, 190), 16, 1.1)
	-- cones and hazard tape across the yard's open front corners
	local coneSpots: { Vector3 } = {}
	for _, sx in { -1, 1 } do
		local p = Kit.onSand(arcPoint(math.rad(sx * (CRATE_ARC_DEGREES / 2 + 16)), CRATE_ARC_RADIUS))
		cone(m, p)
		table.insert(coneSpots, p)
	end
	tape(m, coneSpots[1] + V(0, 2.2, 0), (yard * CFrame.new(-19, 2.2, -8)).Position)
	tape(m, coneSpots[2] + V(0, 2.2, 0), (yard * CFrame.new(19, 2.2, -8)).Position)
	cone(m, (yard * CFrame.new(rng:NextNumber(4, 6), 0, -4)).Position)
end

-- Rebirth temple ----------------------------------------------------------------------------

local function buildRebirth(parent: Instance)
	local m = Kit.model(parent, "RebirthShrine")
	local base = Kit.hubFacing(Layout.REBIRTH)
	local purple = C.Purple
	local lilac = purple:Lerp(WHITE, 0.55)
	local glow = rgb(130, 75, 200)
	box(m, "Step1", at(base, 0, 0.5, 0), V(14, 1, 14), MARBLE, MARBLE_MAT, true)
	box(m, "Step2", at(base, 0, 1.5, 0), V(11, 1, 11), lilac, MARBLE_MAT, true)
	box(m, "Step3", at(base, 0, 2.5, 0), V(8, 1, 8), MARBLE, MARBLE_MAT, true)
	box(m, "StepTrim", at(base, 0, 1.02, 0), V(14.3, 0.12, 14.3), C.Gold, METAL)
	local pedestal = box(m, "Pedestal", at(base, 0, 5.5, 0), V(4, 5, 4), MARBLE, MARBLE_MAT, true)
	Util.Tag(pedestal, "RebirthStatue")
	Util.Prompt(pedestal, "Rebirth", "Rebirth Shrine", 14)
	local light = Instance.new("PointLight")
	light.Color = purple
	light.Range = 16
	light.Brightness = 0.9
	light.Shadows = false
	light.Parent = pedestal
	local sparkles = Build.sparkle(pedestal, purple, 6)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.Speed = NumberRange.new(2, 4)
	sparkles.Lifetime = NumberRange.new(1.5, 2.5)
	box(m, "PedestalCap", at(base, 0, 8.1, 0), V(4.6, 0.4, 4.6), C.Gold, METAL)

	Util.Cylinder(m, "GlowDisc", (base * CFrame.new(0, 3.05, 0)).Position, 0.2, 9, glow, Enum.Material.Neon, true)

	-- Golden digger statue holding a shovel up high
	local gold = C.Gold
	local function g(name: string, size: Vector3, offset: Vector3)
		local p = box(m, name, base * CFrame.new(offset), size, gold)
		p.Reflectance = 0.25
		p.CastShadow = true
	end
	g("Legs", V(2.4, 2.4, 1.4), V(0, 9.5, 0))
	g("Torso", V(3, 3, 1.6), V(0, 12.2, 0))
	g("ArmL", V(0.9, 2.8, 0.9), V(-1.95, 12.1, 0))
	g("ArmR", V(0.9, 3.4, 0.9), V(1.95, 14.9, 0))
	g("Handle", V(0.4, 6, 0.4), V(1.95, 18.8, 0))
	g("Blade", V(1.8, 2.4, 0.4), V(1.95, 22.7, 0))
	local head = Util.Ball(m, "Head", (base * CFrame.new(0, 15, 0)).Position, 2.6, gold)
	head.Reflectance = 0.25

	-- colonnade: six columns in a back semicircle, lintels on pairs
	local cols: { Vector3 } = {}
	for k, deg in { -105, -63, -21, 21, 63, 105 } do
		local a = rad(deg)
		local p = V(math.sin(a) * 10.5, 0, math.cos(a) * 10.5)
		table.insert(cols, p)
		local cf = base * CFrame.new(p)
		local tall = if k == 3 or k == 4 then 15 else 13
		box(m, "ColumnBase", cf * CFrame.new(0, 0.4, 0), V(2.8, 0.8, 2.8), lilac, MARBLE_MAT, true)
		Kit.cyl(m, "Column", cf * CFrame.new(0, 0.8 + tall / 2, 0), tall, 2, MARBLE, MARBLE_MAT, true)
		Kit.cyl(m, "ColumnBand", cf * CFrame.new(0, tall - 0.6, 0), 0.5, 2.3, C.Gold, METAL)
		box(m, "Capital", cf * CFrame.new(0, tall + 1.25, 0), V(3, 0.9, 3), lilac, MARBLE_MAT)
	end
	for k = 1, 5, 2 do
		local a, b = cols[k], cols[k + 1]
		local tall = if k == 3 then 15 else 13
		local mid = (a + b) / 2
		local cf = base * CFrame.lookAt(mid + V(0, tall + 2.2, 0), b + V(0, tall + 2.2, 0))
		box(m, "Lintel", cf, V(2.6, 1.1, (b - a).Magnitude + 3), MARBLE, MARBLE_MAT)
		Kit.neon(m, "LintelGlow", cf * CFrame.new(0, -0.2, 0), V(2.7, 0.25, (b - a).Magnitude + 2), glow, true)
	end

	-- spinning neon portal ring behind the statue + a golden halo above it
	local ringCF = base * CFrame.new(0, 15.5, 6.5)
	local ring = Kit.model(m, "PortalRing")
	local segs = 16
	local R = 8
	for k = 0, segs - 1 do
		local a = k * (2 * math.pi / segs)
		Kit.neon(
			ring,
			"PortalSegment",
			ringCF * CFrame.Angles(0, 0, a) * CFrame.new(R, 0, 0) * CFrame.Angles(0, 0, math.pi / 2),
			V(2 * math.pi * R / segs + 0.15, 0.9, 0.9),
			if k % 2 == 0 then purple else rgb(255, 120, 220)
		)
	end
	Kit.ambient(ring, "AmbientSpin", ringCF, { SpinRPM = 4, SpinAxis = V(0, 0, 1) })
	local haloCF = base * CFrame.new(0, 26.4, 0)
	local halo = Kit.model(m, "Halo")
	for k = 0, 9 do
		local a = k * (2 * math.pi / 10)
		Kit.neon(
			halo,
			"HaloSegment",
			haloCF * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -3.2),
			V(2.1, 0.35, 0.5),
			if k % 2 == 0 then gold else rgb(255, 240, 150)
		)
	end
	Kit.ambient(halo, "AmbientSpin", haloCF, { SpinRPM = 10, SpinAxis = V(0, 1, 0) })

	-- floating orbs
	for k, off in { V(-5.5, 9.5, 1.5), V(5.5, 10.5, 1.5), V(-2.5, 20, -2) } do
		local orb = Kit.model(m, "Orb")
		local p = (base * CFrame.new(off)).Position
		Kit.neon(
			orb,
			"Orb",
			CFrame.new(p),
			V(1.4, 1.4, 1.4) * (if k == 3 then 0.8 else 1),
			glow,
			false,
			Enum.PartType.Ball
		)
		Kit.ambient(orb, "AmbientBob", CFrame.new(p), { BobHeight = 0.8, BobPeriod = 3 + k * 0.4, BobRoll = 0 })
	end
	-- braziers and runes
	for _, sx in { -1, 1 } do
		local p = base * CFrame.new(sx * 8.6, 0, -8.4)
		Kit.cyl(m, "BrazierStand", p * CFrame.new(0, 1.5, 0), 3, 1.1, Kit.STONE_DARK, MARBLE_MAT, true)
		Kit.cyl(m, "Brazier", p * CFrame.new(0, 3.3, 0), 0.8, 2.6, rgb(70, 40, 110), METAL)
		Kit.neon(m, "BrazierFlame", p * CFrame.new(0, 4.4, 0) * CFrame.Angles(0, rad(45), 0), V(1.2, 1.6, 1.2), purple)
	end
	for k = 0, 7 do
		local a = rad(k * 45 + 22.5)
		Kit.neon(
			m,
			"Rune",
			base * CFrame.new(math.sin(a) * 8.4, 0.08, math.cos(a) * 8.4) * CFrame.Angles(0, a + rad(45), 0),
			V(1.3, 0.15, 1.3),
			glow
		)
	end
	Util.Sign(m, "REBIRTH", V(8.6, 2.4, 0.5), base * CFrame.new(0, 4.3, -4.35), {
		Name = "RebirthSign",
		BoardColor = purple,
	})
end

-- Hall of Fame ------------------------------------------------------------------------------

local function buildLeaderboard(
	parent: Instance,
	name: string,
	pos: Vector3,
	tag: string,
	title: string,
	accent: Color3
)
	local m = Kit.model(parent, name)
	local base = Util.Facing(Kit.onSand(pos), Layout.SPAWNS[1])
	box(m, "Plinth", at(base, 0, 0.6, 0.5), V(19.6, 1.2, 5), Kit.STONE, MARBLE_MAT, true)
	box(m, "BasePanel", at(base, 0, 2.6, 0.4), V(14.4, 2.8, 1.4), Kit.NAVY, nil, true)
	local board = box(m, "Board", at(base, 0, 13, 0), V(14, 18, 1), rgb(35, 30, 60), nil, true)
	Util.Tag(board, tag)
	-- Frame
	box(m, "FrameTop", at(base, 0, 22.4, 0.3), V(15.6, 1, 1.4), accent)
	box(m, "FrameBottom", at(base, 0, 3.6, 0.3), V(15.6, 1, 1.4), accent)
	for _, sx in { -1, 1 } do
		box(m, "FrameSide", at(base, sx * 7.4, 13, 0.3), V(1, 19.8, 1.4), accent)
		box(m, "Pilaster", at(base, sx * 8.9, 12.6, 0.4), V(1.8, 21, 1.8), MARBLE, MARBLE_MAT, true)
		box(m, "PilasterBase", at(base, sx * 8.9, 1.6, 0.4), V(2.4, 0.8, 2.4), accent, METAL)
		box(m, "PilasterCap", at(base, sx * 8.9, 23.4, 0.4), V(2.4, 0.8, 2.4), accent, METAL)
		for k = 0, 3 do
			Kit.neon(
				m,
				"MarqueeBulb",
				at(base, sx * 7.4, 6 + k * 4.4, -0.5),
				V(0.7, 0.7, 0.7),
				rgb(255, 214, 90),
				false,
				Enum.PartType.Ball
			)
		end
	end
	box(m, "Entablature", at(base, 0, 24.5, 0.4), V(20, 1.4, 2.8), MARBLE, MARBLE_MAT)
	Util.Sign(m, title, V(15.6, 3, 1), base * CFrame.new(0, 26.7, -0.4), {
		Name = "Header",
		BoardColor = accent,
	})
	Kit.gable(
		m,
		at(base, 0, 28.2, 0.4),
		18,
		2.6,
		3.6,
		MARBLE,
		{ Under = MARBLE, Trim = accent, Overhang = 0.6, EndOverhang = 0.1, Mat = MARBLE_MAT }
	)
	Kit.ball(m, "PedimentStar", (base * CFrame.new(0, 30, -0.9)).Position, 1.4, accent)
end

local function buildHallOfFame(parent: Instance)
	local m = Kit.model(parent, "HallOfFame")
	local mid = (Layout.LEADERBOARD_COINS + Layout.LEADERBOARD_DEPTH) / 2
	local base = Util.Facing(Kit.onSand(mid), Layout.SPAWNS[1])
	local gold = C.Gold
	box(m, "HallPlinth", at(base, 0, 0.4, 0.8), V(50, 0.8, 8), Kit.STONE_DARK, Enum.Material.Slate, true)
	box(m, "HallStep", at(base, 0, 0.2, -3.9), V(46, 0.4, 1.6), Kit.STONE, Enum.Material.Slate, true)
	box(m, "Column", at(base, 0, 9, 0.6), V(6, 16, 5), MARBLE, MARBLE_MAT, true)
	for _, y in { 1.6, 16.6 } do
		box(m, "ColumnBand", at(base, 0, y, 0.6), V(6.8, 0.9, 5.8), gold, METAL)
	end
	Util.Sign(m, "HALL OF FAME", V(10.6, 2.8, 0.5), at(base, 0, 12.4, -2.2), {
		Name = "HallSign",
		BoardColor = C.Coral,
	})
	-- giant trophy
	local function gp(p: BasePart)
		p.Reflectance = 0.3
		p.CastShadow = true
	end
	gp(box(m, "TrophyBase", at(base, 0, 17.7, 0.6), V(4.4, 1.2, 4.4), Kit.WOOD_DEEP, WOOD_MAT))
	gp(Kit.cyl(m, "TrophyStem", at(base, 0, 19.6, 0.6), 2.6, 1.4, gold, METAL))
	gp(Kit.ball(m, "TrophyKnob", (base * CFrame.new(0, 20.9, 0.6)).Position, 2, gold, METAL))
	gp(Kit.ball(m, "TrophyBowl", (base * CFrame.new(0, 23.6, 0.6)).Position, 6.4, gold, METAL))
	gp(Kit.cyl(m, "TrophyCup", at(base, 0, 25.2, 0.6), 3.2, 6.4, gold, METAL))
	gp(Kit.cyl(m, "TrophyRim", at(base, 0, 26.9, 0.6), 0.5, 7, rgb(255, 225, 110), METAL))
	for _, sx in { -1, 1 } do
		gp(box(m, "TrophyHandle", at(base, sx * 4.4, 24.6, 0.6), V(0.6, 3.4, 0.6), gold, METAL))
		gp(box(m, "TrophyHandle", at(base, sx * 3.8, 26.1, 0.6), V(1.6, 0.6, 0.6), gold, METAL))
		gp(box(m, "TrophyHandle", at(base, sx * 3.8, 23.1, 0.6), V(1.6, 0.6, 0.6), gold, METAL))
	end
	local star = Kit.neon(m, "TrophyStar", at(base, 0, 28.8, 0.6, 0, 0, 45), V(1.8, 1.8, 0.5), gold)
	Kit.neon(m, "TrophyStar", at(base, 0, 28.8, 0.6), V(1.6, 1.6, 0.55), rgb(255, 160, 40))
	Kit.light(star, rgb(255, 220, 120), 16, 1)
	-- banners hanging off the column sides
	for k, sx in { -1, 1 } do
		local banner = Kit.model(m, "HallBanner")
		local hinge = base * CFrame.new(sx * 1.5, 10.6, -2.3)
		local color = if k == 1 then C.Ocean else rgb(150, 220, 80)
		box(banner, "BannerRod", hinge, V(2.6, 0.25, 0.25), gold, METAL)
		box(banner, "Banner", hinge * CFrame.new(0, -2.6, 0), V(2.2, 5, 0.12), color, FABRIC)
		Kit.wedge(
			banner,
			"BannerTail",
			hinge * CFrame.new(0, -5.6, 0) * CFrame.Angles(0, 0, rad(180)) * CFrame.Angles(0, rad(90), 0),
			V(0.12, 1, 2.2),
			color,
			FABRIC
		)
		Kit.ambient(banner, "AmbientSway", hinge, { SwayDegrees = 4, SwayPeriod = 3.6 + k * 0.5 })
	end
end

function HubAttractions.Build(parent: Instance)
	buildLeaderboard(parent, "LeaderboardCoins", Layout.LEADERBOARD_COINS, "LeaderboardCoins", "TOP DIGGERS", C.Gold)
	buildLeaderboard(parent, "LeaderboardDepth", Layout.LEADERBOARD_DEPTH, "LeaderboardDepth", "DEEPEST", C.Ocean)
	buildHallOfFame(parent)
	buildEggs(parent)
	buildRebirth(parent)
	buildCrateYard(parent)
end

return HubAttractions
