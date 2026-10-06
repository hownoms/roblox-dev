--!strict
-- Low-part-count silhouettes outside the playable beach. No collision/query or loot.
local Layout = require(script.Parent.Layout)
local Util = require(script.Parent.Util)

local Vistas = {}
local V, CF = Vector3.new, CFrame.new
local ROCK = Color3.fromRGB(91, 109, 119)
local CREAM = Color3.fromRGB(243, 226, 188)
local CORAL = Color3.fromRGB(208, 85, 69)
local NAVY = Color3.fromRGB(31, 55, 73)

function Vistas.Build(parent: Instance)
	local m = Instance.new("Model")
	m.Name = "CoastalVistas"
	-- A small skyline kit remains visible beyond the streaming radius (roughly 40 parts).
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	m.Parent = parent
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?)
		return Util.Part({
			Name = name,
			Size = size,
			CFrame = cf,
			Color = color,
			Material = material,
			Decor = true,
			CastShadow = true,
			Parent = m,
		})
	end
	local function cylinder(name: string, pos: Vector3, height: number, diameter: number, color: Color3)
		return Util.Cylinder(m, name, pos, height, diameter, color, Enum.Material.SmoothPlastic, true)
	end
	local function rock(name: string, size: Vector3, cf: CFrame, color: Color3)
		local p = part(name, size, cf, color, Enum.Material.Slate)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	-- Lighthouse on the eastern headland: a warm/cool silhouette visible above the dunes.
	local base = V(458, Layout.SURFACE_Y, 48)
	rock("Headland", V(78, 32, 76), CF(base + V(0, 1, 0)) * CFrame.Angles(0.12, 0.3, -0.08), ROCK)
	for k = 0, 4 do
		cylinder("TowerBand", base + V(0, 19 + k * 7, 0), 7, 19 - k * 1.5, if k % 2 == 0 then CREAM else CORAL)
	end
	cylinder("Gallery", base + V(0, 51, 0), 2, 19, NAVY)
	cylinder("Lantern", base + V(0, 56, 0), 8, 12, Color3.fromRGB(122, 186, 196))
	for k = 0, 7 do
		local a = k * math.pi / 4
		part("LanternFrame", V(0.6, 9, 0.6), CF(base + V(math.cos(a) * 5.7, 56, math.sin(a) * 5.7)), NAVY)
	end
	cylinder("Roof", base + V(0, 61, 0), 2, 16, CORAL)
	cylinder("Finial", base + V(0, 64, 0), 4, 1.4, NAVY)
	-- Offshore stacks frame the pier sightline. Broad silhouettes, no tiny distant details.
	for _, x in { -180, -116 } do
		local p = V(x, Layout.WATER_Y - 9, -310)
		rock("SeaStack", V(38, 65, 38), CF(p) * CFrame.Angles(0.08, x * 0.01, 0.1), ROCK)
		rock(
			"StackShoulder",
			V(25, 36, 32),
			CF(p + V(-12, -5, 4)) * CFrame.Angles(0, 0.3, -0.25),
			ROCK:Lerp(CREAM, 0.12)
		)
	end
	for k = 0, 6 do
		local t = k / 6
		rock(
			"ArchStone",
			V(19, 15, 27),
			CF(-180 + t * 64, Layout.WATER_Y + 18 + math.sin(t * math.pi) * 9, -310),
			ROCK:Lerp(CREAM, k % 2 * 0.08)
		)
	end
end

return Vistas
