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

for _, entry in
	{
		{ Layer = "pirate_cove", X = { -192, 0, 192 } },
		{ Layer = "crystal_caverns", X = { -288, -96, 96 } },
	}
do
	local layer: Types.LayerDef? = nil
	for _, candidate in Config.Layers do
		if candidate.Id == entry.Layer then
			layer = candidate
			break
		end
	end
	assert(layer, "Missing scenery layer: " .. entry.Layer)
	local floor = Layout.SnapY(Layout.SURFACE_Y - (layer.DepthStart + layer.DepthEnd) / 2 - 12)
	for _, x in entry.X do
		table.insert(Underground.Pockets, {
			Layer = entry.Layer,
			Min = V(x - 16, floor, Layout.DIG_Z_INLAND),
			Max = V(x + 16, floor + 24, Layout.STRIP_Z_INLAND),
		})
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
		Build.part(
			model,
			"BackRock",
			V(31, 23, 1),
			CFrame.new(origin + V(0, 12, -0.5)),
			if isPirate then rgb(78, 62, 50) else rgb(45, 43, 67),
			Enum.Material.Slate
		)
		Build.part(
			model,
			"RockShelf",
			V(29, 3, 6),
			CFrame.new(origin + V(0, 1.5, -4)),
			if isPirate then rgb(108, 84, 62) else rgb(72, 68, 95),
			Enum.Material.Slate
		)
		if isPirate then
			pirate(model, origin)
		else
			crystal(model, origin)
		end
		-- Local fill keeps the authored shapes readable under the actual depth lighting.
		-- One shadowless light per streamed alcove; no global exposure change.
		Build.part(
			model,
			"LampPost",
			V(0.6, 12, 0.6),
			CFrame.new(origin + V(-13, 7, -6.5)),
			if isPirate then rgb(126, 78, 47) else rgb(57, 56, 86)
		)
		local lamp = Build.part(
			model,
			"AlcoveLamp",
			V(0.8, 1.2, 0.8),
			CFrame.new(origin + V(-13, 13.5, -6.5)),
			if isPirate then rgb(224, 169, 77) else rgb(86, 193, 215),
			Enum.Material.Neon
		)
		local light = Instance.new("PointLight")
		light.Name = "AlcoveFill"
		light.Color = if isPirate then rgb(255, 221, 166) else rgb(188, 212, 255)
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
