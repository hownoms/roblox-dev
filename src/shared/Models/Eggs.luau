--!strict
--[[
	Eggs — ~3 studs tall, PrimaryPart = invisible "Root" at the bottom-centre, front -Z.
	Pattern (spots or zig-zag band) is picked deterministically from the egg id.
	Glow -> Neon pattern + PointLight + sparkles. Main shell part is named "Shell".

	v2.1: Construction Crates (EggDef.Kind == "Crate") are chunky wooden / metal crates instead:
	~2.8 studs wide, plank box ("Shell", ShellColor) with a dark frame, steel corner brackets and a
	band of hazard tape (SpotColor / black). The lid is a sub-Model "Lid" (PrimaryPart "LidPlate",
	NOT welded to Root) so the hatch animation can pop it off. Model attribute "Crate" = true.
]]

local Types = require(script.Parent.Parent.Types)
local Config = require(script.Parent.Parent.Config)
local Build = require(script.Parent.Build)

local Eggs = {}

local V = Vector3.new
local CF = CFrame.new
local X = Vector3.xAxis

local LOW_C, LOW_S = V(0, 1.2, 0), V(2.3, 2.4, 2.3)
local TOP_C, TOP_S = V(0, 1.65, 0), V(2.05, 2.6, 2.05)

local FALLBACK: Types.EggLook = {
	ShellColor = Color3.fromRGB(255, 245, 220),
	SpotColor = Color3.fromRGB(255, 150, 120),
	Glow = false,
}

-- Width (diameter) of the egg silhouette at height y.
local function widthAt(y: number): number
	local function w(c: Vector3, s: Vector3): number
		local rel = (y - c.Y) / (s.Y / 2)
		if math.abs(rel) >= 1 then
			return 0
		end
		return s.X * math.sqrt(1 - rel * rel)
	end
	return math.max(w(LOW_C, LOW_S), w(TOP_C, TOP_S))
end

local function build(id: string, look: Types.EggLook): Model
	local m = Build.model(id)
	local root = Build.root(m, CFrame.identity, V(1, 0.1, 1))
	local shellMat = Enum.Material.SmoothPlastic
	local shell = Build.ellipsoid(m, "Shell", LOW_S, CF(LOW_C), look.ShellColor, shellMat)
	Build.ellipsoid(m, "ShellTop", TOP_S, CF(TOP_C), look.ShellColor, shellMat)
	local pm = if look.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local sc = look.SpotColor

	if Build.hash(id) % 2 == 0 then
		-- Spots
		local dirs = {
			V(0, 0.1, -1),
			V(0.85, 0.45, -0.4),
			V(-0.8, -0.2, -0.55),
			V(0.7, -0.35, 0.6),
			V(-0.6, 0.5, 0.65),
			V(0.1, 0.25, 1),
			V(-0.95, 0.15, 0.1),
			V(0.95, -0.05, 0.15),
		}
		for i, d in dirs do
			local size = if i % 3 == 0 then 0.42 else 0.6
			Build.ellipsoid(m, "Spot", V(size, size * 0.9, 0.14), Build.surface(LOW_C, LOW_S, d), sc, pm)
		end
		Build.ellipsoid(m, "Spot", V(0.5, 0.45, 0.14), Build.surface(TOP_C, TOP_S, V(0.3, 1, -0.35)), sc, pm)
	else
		-- Zig-zag band like a cracked shell
		local y = 1.45
		local d = widthAt(y) + 0.04
		Build.cyl(m, "Band", 0.38, d, CF(0, y, 0), sc, pm)
		local n = 8
		for k = 0, n - 1 do
			local a = (k + 0.5) / n * math.pi * 2
			local dir = V(math.sin(a), 0, -math.cos(a))
			local base = V(0, y + 0.17, 0) + dir * (widthAt(y + 0.17) / 2 - 0.02)
			local apexY = y + 0.55
			local apex = V(0, apexY, 0) + dir * (widthAt(apexY) / 2 - 0.02)
			Build.triPts(m, "Zig", base, apex, V(-dir.Z, 0, dir.X), 0.75, 0.08, sc, pm)
		end
		Build.ellipsoid(m, "Spot", V(0.55, 0.5, 0.14), Build.surface(TOP_C, TOP_S, V(0, 1, -0.2)), sc, pm)
	end

	Build.ellipsoid(
		m,
		"Shine",
		V(0.35, 0.6, 0.1),
		Build.surface(LOW_C, LOW_S, V(-0.55, 0.45, -0.7)),
		Build.lighten(look.ShellColor, 0.7)
	)

	if look.Glow then
		Build.glow(shell, sc, 1.2, 9)
		Build.sparkle(shell, sc, 4)
	end
	Build.weldAll(m, root)
	return m
end

-- Construction Crate ------------------------------------------------------------------------

local CRATE_W, CRATE_H = 2.8, 2.2
local BLACK = Color3.fromRGB(35, 35, 40)
local STEEL = Color3.fromRGB(165, 170, 182)

local function buildCrate(id: string, look: Types.EggLook): Model
	local m = Build.model(id)
	m:SetAttribute("Crate", true)
	local root = Build.root(m, CFrame.identity, V(1, 0.1, 1))
	local metal = look.Glow
	local wood = if metal then Enum.Material.DiamondPlate else Enum.Material.WoodPlanks
	local frame = Build.darken(look.ShellColor, 0.35)
	local stripeMat = if look.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local w, h = CRATE_W, CRATE_H

	local shell = Build.part(m, "Shell", V(w, h, w), CF(0, h / 2, 0), look.ShellColor, wood)
	-- frame: vertical posts + top / bottom rims
	local e = 0.28
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			Build.part(
				m,
				"Post",
				V(e, h + 0.04, e),
				CF(x * (w / 2 - e / 2 + 0.03), h / 2, z * (w / 2 - e / 2 + 0.03)),
				frame,
				wood
			)
			-- steel corner brackets top and bottom
			for _, y in { 0.2, h - 0.2 } do
				Build.part(
					m,
					"Bracket",
					V(e + 0.12, 0.32, e + 0.12),
					CF(x * (w / 2 - e / 2 + 0.03), y, z * (w / 2 - e / 2 + 0.03)),
					STEEL,
					Enum.Material.Metal
				)
			end
		end
	end
	for _, y in { 0.12, h - 0.12 } do
		for _, z in { -1, 1 } do
			Build.part(m, "Rim", V(w + 0.06, 0.24, e * 0.8), CF(0, y, z * (w / 2 + 0.02)), frame, wood)
			Build.part(m, "Rim", V(e * 0.8, 0.24, w + 0.06), CF(z * (w / 2 + 0.02), y, 0), frame, wood)
		end
	end
	-- diagonal braces on the sides and the back (the front carries the warning sign)
	for _, x in { -1, 1 } do
		local brace = Build.part(m, "Brace", V(0.12, h * 1.15, 0.24), CF(x * (w / 2 + 0.05), h / 2, 0), frame, wood)
		brace.CFrame = brace.CFrame * CFrame.Angles(math.rad(42), 0, 0)
	end
	local back = Build.part(m, "Brace", V(0.24, h * 1.15, 0.12), CF(0, h / 2, w / 2 + 0.05), frame, wood)
	back.CFrame = back.CFrame * CFrame.Angles(0, 0, math.rad(42))
	-- hazard tape band around the middle (alternating SpotColor / black blocks)
	local bandY = h * 0.62
	local n = 6
	local seg = w / n
	for face = 0, 3 do
		local yaw = CFrame.Angles(0, face * math.pi / 2, 0)
		for k = 0, n - 1 do
			local x = -w / 2 + seg * (k + 0.5)
			local color = if k % 2 == 0 then look.SpotColor else BLACK
			local mat = if k % 2 == 0 then stripeMat else Enum.Material.SmoothPlastic
			Build.part(m, "Tape", V(seg, 0.42, 0.08), yaw * CF(x, bandY, -(w / 2 + 0.1)), color, mat)
		end
	end
	-- stencilled warning triangle on the front
	Build.triPts(
		m,
		"Warning",
		V(0, h * 0.18, -(w / 2 + 0.1)),
		V(0, h * 0.46, -(w / 2 + 0.1)),
		X,
		0.6,
		0.06,
		look.SpotColor,
		stripeMat
	)

	-- lid (separate sub-Model so the hatch animation can pop it off)
	local lid = Instance.new("Model")
	lid.Name = "Lid"
	lid.Parent = m
	local plate = Build.part(lid, "LidPlate", V(w + 0.24, 0.3, w + 0.24), CF(0, h + 0.15, 0), frame, wood)
	lid.PrimaryPart = plate
	for _, x in { -0.8, 0, 0.8 } do
		Build.part(lid, "LidPlank", V(0.5, 0.12, w + 0.1), CF(x, h + 0.36, 0), look.ShellColor, wood)
	end
	Build.part(lid, "LidStripe", V(w + 0.1, 0.14, 0.4), CF(0, h + 0.38, 0), look.SpotColor, stripeMat)
	Build.part(lid, "Handle", V(0.9, 0.22, 0.22), CF(0, h + 0.55, 0), STEEL, Enum.Material.Metal)
	for _, d in lid:GetDescendants() do
		if d:IsA("BasePart") and d ~= plate then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = plate
			weld.Part1 = d
			weld.Parent = d
		end
	end

	if look.Glow then
		Build.glow(shell, look.SpotColor, 1.2, 9)
		Build.sparkle(shell, look.SpotColor, 4)
	end
	-- weld the static crate to Root (the Lid stays free)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= root and d:FindFirstAncestorWhichIsA("Model") == m then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		end
	end
	return m
end

function Eggs.Build(eggId: string): Model
	local def = Config.GetEgg(eggId)
	if def and def.Kind == "Crate" then
		return buildCrate(eggId, def.Look)
	end
	return build(eggId, if def then def.Look else FALLBACK)
end

-- A crate drawn from a look (previews / tests).
function Eggs.CrateFromLook(name: string, look: Types.EggLook): Model
	return buildCrate(name, look)
end

function Eggs.FromLook(name: string, look: Types.EggLook): Model
	return build(name, look)
end

return Eggs
