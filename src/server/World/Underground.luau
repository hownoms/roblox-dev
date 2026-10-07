--!strict
-- Authored wall alcoves. All air and geometry stay inland of the dig/refill footprint.
-- Open only AFTER deep terrain has finished, otherwise its fill would bury the scenery.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Build = require(ReplicatedStorage.Shared.Models.Build)
local Layout = require(script.Parent.Layout)
local Util = require(script.Parent.Util)

local Underground = {}
local V = Vector3.new
local rgb = Color3.fromRGB

export type Pocket = { Layer: string, Min: Vector3, Max: Vector3 }
Underground.Pockets = {} :: { Pocket }

for index, layer: Types.LayerDef in Config.Layers do
	-- Four-stud margins keep even the shallowest pocket within its own layer.
	local height = math.min(24, math.floor((layer.DepthEnd - layer.DepthStart - 8) / 4) * 4)
	local floor = Layout.SnapY(Layout.SURFACE_Y - (layer.DepthStart + layer.DepthEnd) / 2 - height / 2)
	local positions: { number } = if index % 2 == 1 then { -192, 0, 192 } else { -288, -96, 96 }
	-- Preserve the already reviewed crystal placement.
	if layer.Id == "crystal_caverns" then
		positions = { -288, -96, 96 }
	end
	for _, x in positions do
		table.insert(Underground.Pockets, {
			Layer = layer.Id,
			Min = V(x - 16, floor, Layout.DIG_Z_INLAND),
			Max = V(x + 16, floor + height, Layout.STRIP_Z_INLAND),
		})
	end
end

-- Large, supported silhouettes rather than collectible-sized treasure props.
local function landmark(model: Model, origin: Vector3, id: string)
	local cream, stone, dark = rgb(236, 215, 171), rgb(130, 139, 151), rgb(65, 57, 79)
	local function block(name: string, size: Vector3, at: Vector3, color: Color3, material: Enum.Material?)
		return Build.part(model, name, size, CFrame.new(origin + at), color, material)
	end
	local function beam(name: string, a: Vector3, b: Vector3, width: number, color: Color3)
		Build.beam(model, name, origin + a, origin + b, width, 0.7, color)
	end
	if id == "dry_sand" then
		Build.cyl(model, "Bucket", 4, 5, CFrame.new(origin + V(-6, 5, -4)), rgb(70, 169, 180))
		beam("SpadeHandle", V(-2, 3, -4), V(1, 9, -4), 0.6, cream)
		block("SpadeBlade", V(2.2, 2, 0.5), V(-2, 4, -4), rgb(216, 119, 95))
		block("CastleWall", V(10, 3, 3), V(7, 4.5, -4), cream)
		for _, x in { 3, 11 } do
			Build.cyl(model, "CastleTurret", 5, 3, CFrame.new(origin + V(x, 5.5, -4)), cream)
			block("Battlement", V(3, 1, 3), V(x, 8.5, -4), cream)
		end
	elseif id == "wet_sand" then
		for _, x in { -10, 10 } do
			Build.ellipsoid(model, "TideStone", V(5, 5, 4), CFrame.new(origin + V(x, 4.5, -4)), stone)
		end
		beam("Driftwood", V(-10, 7, -4), V(9, 10, -4), 2, rgb(161, 116, 78))
		block("TideBasin", V(13, 0.5, 4), V(0, 3.25, -4), rgb(77, 156, 172))
		for i = -2, 2 do
			Build.ellipsoid(model, "BasinShell", V(2, 1, 1.5), CFrame.new(origin + V(i * 2.6, 3.7, -6)), cream)
		end
	elseif id == "shell_bed" then
		for side = -1, 1, 2 do
			for i = -2, 2 do
				beam("ClamFan", V(0, 3, -4), V(i * 3, 8 + side * 3, -4 + side * 1.2), 2, rgb(232, 174, 180))
			end
		end
		Build.ball(model, "Pearl", 4, CFrame.new(origin + V(0, 5, -5)), cream)
	elseif id == "tidal_clay" then
		beam("DinghyKeel", V(-12, 3.5, -4), V(2, 5, -4), 2, rgb(143, 101, 69))
		for i = 0, 3 do
			block("DinghyRib", V(1, 5 + i, 4), V(-10 + i * 3, 6, -4), cream)
		end
		beam("AnchorShaft", V(8, 3, -4), V(8, 16, -4), 1.2, stone)
		beam("AnchorStock", V(4, 13, -4), V(12, 13, -4), 1, stone)
		beam("AnchorFluke", V(8, 4, -4), V(3, 7, -4), 1.2, stone)
		beam("AnchorFluke", V(8, 4, -4), V(13, 7, -4), 1.2, stone)
	elseif id == "shipwreck" then
		local wood = rgb(146, 96, 58)
		for _, x in { -9, 3 } do
			block("DoorPost", V(2, 14, 3), V(x, 10, -4), wood)
		end
		block("DoorLintel", V(14, 2, 3), V(-3, 17, -4), cream)
		for i = 0, 3 do
			block("DeckStep", V(15, 0.8, 1), V(-3, 3.4 + i * 0.8, -6 + i), wood)
		end
		for _, y in { 5, 9 } do
			Build.cyl(model, "Barrel", 4, 4, CFrame.new(origin + V(10, y, -4)), wood)
			Build.cyl(model, "BarrelBand", 0.4, 4.2, CFrame.new(origin + V(10, y + 1, -4)), stone)
		end
	elseif id == "fossil_bed" then
		beam("FossilSpine", V(-11, 7, -3), V(10, 7, -3), 1.5, cream)
		for i = -2, 2 do
			for side = -1, 1, 2 do
				beam("FossilRib", V(i * 4, 7, -3), V(i * 4 + side, 4, -5), 1, cream)
			end
		end
		block("FossilJaw", V(8, 1.5, 3), V(6, 3.75, -4), cream)
		for i = 0, 3 do
			Build.tri(model, "FossilTooth", CFrame.new(origin + V(3 + i * 2, 5.5, -4)), 1.3, 2, 0.8, cream)
		end
	elseif id == "bedrock" then
		for i = -2, 2 do
			block("FaultSlab", V(4, 7 + (i + 2) * 2, 4), V(i * 5, 6.5 + i + 2, -4), stone, Enum.Material.Slate)
			block("OreSeam", V(1, 5, 0.4), V(i * 5, 6, -6.2), rgb(176, 112, 68), Enum.Material.Metal)
		end
	elseif id == "frozen_abyss" then
		Build.ellipsoid(
			model,
			"FrozenMass",
			V(13, 8, 4),
			CFrame.new(origin + V(0, 7, -3.5)),
			rgb(152, 206, 217),
			Enum.Material.Ice
		)
		for side = -1, 1, 2 do
			beam("TuskBase", V(side * 4, 3, -5), V(side * 8, 10, -5), 1.5, cream)
			beam("TuskTip", V(side * 8, 10, -5), V(side * 4, 16, -5), 1, cream)
		end
		for _, x in { -11, 11 } do
			Build.spike(
				model,
				"IceBlade",
				origin + V(x, 3, -4),
				origin + V(x, 12, -4),
				3,
				rgb(127, 189, 216),
				Enum.Material.Ice
			)
		end
	elseif id == "ancient_ruins" then
		for side = -1, 1, 2 do
			for i = 0, 2 do
				block("RuinsPillar", V(4 - i * 0.4, 4, 3), V(side * 9, 5 + i * 4, -4), cream)
			end
			block("BrokenLintel", V(7, 2, 3), V(side * 6, 16, -4), cream)
		end
		block("StoneTablet", V(7, 7, 1), V(0, 6.5, -4), rgb(191, 157, 95))
		for i = 0, 2 do
			block("TabletGlyph", V(4 - i, 0.5, 0.3), V(0, 5 + i * 2, -4.7), dark)
		end
	elseif id == "magma_chamber" then
		for i = -2, 2 do
			local h = 9 - math.abs(i) * 2
			block("BasaltVent", V(4, h, 4), V(i * 4.5, 3 + h / 2, -4), dark, Enum.Material.Basalt)
			block("VentSeam", V(0.5, h - 1, 0.3), V(i * 4.5, 3 + h / 2, -6.2), rgb(239, 110, 45), Enum.Material.Neon)
		end
		block("LavaBasin", V(18, 0.6, 3), V(0, 3.3, -4), rgb(228, 111, 43), Enum.Material.Neon)
	elseif id == "obsidian_depths" then
		for i = -1, 1 do
			block(
				"ObsidianMonolith",
				V(5, 14 + i * 3, 3),
				V(i * 8, 10 + i * 1.5, -3),
				dark,
				Enum.Material.SmoothPlastic
			)
			block("VioletInset", V(0.7, 8, 0.3), V(i * 8, 10, -4.7), rgb(144, 97, 189))
		end
		for i = -2, 2 do
			Build.ellipsoid(
				model,
				"StrangeFootprint",
				V(2.3, 0.3, 1.3),
				CFrame.new(origin + V(i * 4, 3.1, -5.5)),
				rgb(140, 109, 163)
			)
		end
	elseif id == "alien_hive" then
		for i = -1, 1 do
			Build.ellipsoid(
				model,
				"HivePod",
				V(6, 9 + i * 2, 4),
				CFrame.new(origin + V(i * 8, 7.5 + i, -4)),
				rgb(101, 176, 123)
			)
			block("PodWindow", V(2, 3, 0.4), V(i * 8, 8, -6.2), rgb(109, 204, 139), Enum.Material.Neon)
		end
		beam("HiveConduit", V(-8, 5, -4), V(8, 5, -4), 1.3, rgb(73, 135, 97))
		block("CrashedHull", V(9, 2, 3), V(5, 14, -3), stone, Enum.Material.Metal)
	elseif id == "the_core" then
		for i = 0, 2 do
			block("CoreFoundation", V(22 - i * 5, 1, 4), V(0, 3.5 + i, -4), rgb(195, 148, 64))
		end
		local center = V(0, 12, -3)
		Build.cyl(
			model,
			"CoreRelief",
			1,
			8,
			CFrame.new(origin + center) * CFrame.Angles(math.pi / 2, 0, 0),
			rgb(237, 185, 65),
			Enum.Material.Metal
		)
		beam("CoreSupport", V(0, 5, -3), V(0, 12, -3), 2, cream)
		for i = 0, 7 do
			local a = i * math.pi / 4
			local radial = V(math.sin(a), math.cos(a), 0)
			beam("CoreRay", center + radial * 3, center + radial * 7, 1, rgb(245, 202, 102))
		end
	else
		error("Missing underground landmark: " .. id)
	end
end

local function pirate(model: Model, origin: Vector3)
	local wood = rgb(126, 78, 47)
	local pale = rgb(208, 157, 94)
	local metal = rgb(172, 128, 54)
	-- A broken fishing hull: keel, rising ribs and staggered planks read before small details.
	Build.part(model, "Keel", V(21, 1.2, 3), CFrame.new(origin + V(0, 2.6, -4)), wood, Enum.Material.Wood)
	for i = -2, 2 do
		local x = i * 4
		Build.part(model, "HullRib", V(0.9, 6, 3.6), CFrame.new(origin + V(x, 5.2, -4)), pale, Enum.Material.Wood)
	end
	for i = 1, 3 do
		Build.part(
			model,
			"HullPlank",
			V(22 - i * 2, 1, 0.7),
			CFrame.new(origin + V(-1, 3 + i * 1.5, -6)),
			wood,
			Enum.Material.Wood
		)
	end
	Build.part(model, "BrokenMast", V(1.1, 13, 1.1), CFrame.new(origin + V(-5, 8, -3)), pale, Enum.Material.Wood)
	Build.part(model, "Crossbar", V(9, 0.7, 0.8), CFrame.new(origin + V(-5, 13, -3)), wood, Enum.Material.Wood)
	Build.tri(model, "TornSail", CFrame.new(origin + V(-2.5, 10.5, -3)), 5, 5, 0.25, rgb(239, 211, 158))
	-- Brass helm mounted against the back rock, distinct from collectible treasure chests.
	local centre = origin + V(8, 13, -1.5)
	Build.cyl(
		model,
		"HelmHub",
		0.7,
		1.4,
		CFrame.new(centre) * CFrame.Angles(math.pi / 2, 0, 0),
		metal,
		Enum.Material.Metal
	)
	for i = 0, 7 do
		local a = i * math.pi / 4
		local radial = V(math.sin(a), math.cos(a), 0)
		local nextRadial = V(math.sin(a + math.pi / 4), math.cos(a + math.pi / 4), 0)
		Build.beam(model, "HelmSpoke", centre, centre + radial * 3.4, 0.35, 0.35, metal, Enum.Material.Metal)
		Build.beam(
			model,
			"HelmRim",
			centre + radial * 2.6,
			centre + nextRadial * 2.6,
			0.4,
			0.4,
			pale,
			Enum.Material.Wood
		)
	end
end

local function crystal(model: Model, origin: Vector3)
	local rock = rgb(57, 56, 86)
	for i, height in { 6, 11, 16, 9, 5 } do
		local x = (i - 3) * 4.5
		local base = origin + V(x, 2.4, -4)
		Build.ellipsoid(model, "GeodeBase", V(6, 2, 5), CFrame.new(base), rock, Enum.Material.Slate)
		local tip = base + V(if i % 2 == 0 then 1.2 else -0.8, height, 0.4)
		Build.spike(
			model,
			"CrystalSpire",
			base,
			tip,
			3,
			if i % 2 == 0 then rgb(82, 184, 205) else rgb(157, 110, 211),
			Enum.Material.SmoothPlastic
		)
		-- Small emissive nodes support the silhouette without particles or whole-neon spires.
		Build.ball(model, "CrystalTip", 0.45, CFrame.new(tip), rgb(86, 193, 215), Enum.Material.Neon)
	end
end

function Underground.Build(parent: Instance)
	for i, pocket in Underground.Pockets do
		local size = pocket.Max - pocket.Min
		Workspace.Terrain:FillBlock(CFrame.new((pocket.Min + pocket.Max) / 2), size, Enum.Material.Air)
		local model = Util.Model(pocket.Layer .. "_" .. i, parent)
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		model:SetAttribute("SceneryLayer", pocket.Layer)
		model:SetAttribute("PocketMin", pocket.Min)
		model:SetAttribute("PocketMax", pocket.Max)
		local origin = V((pocket.Min.X + pocket.Max.X) / 2, pocket.Min.Y, 0)
		local isPirate = pocket.Layer == "pirate_cove"
		local isCrystal = pocket.Layer == "crystal_caverns"
		local palette = rgb(130, 139, 151)
		for _, layer in Config.Layers do
			if layer.Id == pocket.Layer then
				palette = layer.Color
				break
			end
		end
		local back = if isPirate
			then rgb(78, 62, 50)
			elseif isCrystal then rgb(45, 43, 67)
			else Build.darken(palette, 0.55)
		local shelf = if isPirate
			then rgb(108, 84, 62)
			elseif isCrystal then rgb(72, 68, 95)
			else Build.darken(palette, 0.3)
		local lampHeight = math.min(13.5, size.Y - 2)
		Build.part(
			model,
			"BackRock",
			V(31, size.Y - 1, 1),
			CFrame.new(origin + V(0, size.Y / 2, -0.5)),
			back,
			Enum.Material.Slate
		)
		Build.part(model, "RockShelf", V(29, 3, 6), CFrame.new(origin + V(0, 1.5, -4)), shelf, Enum.Material.Slate)
		if isPirate then
			pirate(model, origin)
		elseif isCrystal then
			crystal(model, origin)
		else
			landmark(model, origin, pocket.Layer)
		end
		-- Local fill keeps the authored shapes readable under the actual depth lighting.
		-- One shadowless light per streamed alcove; no global exposure change.
		Build.part(
			model,
			"LampPost",
			V(0.6, lampHeight - 1.5, 0.6),
			CFrame.new(origin + V(-13, (lampHeight + 0.5) / 2, -6.5)),
			if isPirate then rgb(126, 78, 47) elseif isCrystal then rgb(57, 56, 86) else shelf
		)
		local lamp = Build.part(
			model,
			"AlcoveLamp",
			V(0.8, 1.2, 0.8),
			CFrame.new(origin + V(-13, lampHeight, -6.5)),
			if isPirate then rgb(224, 169, 77) elseif isCrystal then rgb(86, 193, 215) else Build.lighten(palette, 0.2),
			Enum.Material.Neon
		)
		local light = Instance.new("PointLight")
		light.Name = "AlcoveFill"
		light.Color = if isPirate
			then rgb(255, 221, 166)
			elseif isCrystal then rgb(188, 212, 255)
			else Build.lighten(palette, 0.65)
		light.Brightness = 2.5
		light.Range = 32
		light.Shadows = false
		light.Parent = lamp
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CastShadow = false
			end
		end
	end
end

return Underground
