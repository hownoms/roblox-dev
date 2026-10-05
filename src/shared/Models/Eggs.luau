--!strict
--[[
	Eggs — ~3 studs tall, PrimaryPart = invisible "Root" at the bottom-centre, front -Z.
	Pattern (spots or zig-zag band) is picked deterministically from the egg id.
	Glow -> Neon pattern + PointLight + sparkles. Main shell part is named "Shell".
]]

local Types = require(script.Parent.Parent.Types)
local Config = require(script.Parent.Parent.Config)
local Build = require(script.Parent.Build)

local Eggs = {}

local V = Vector3.new
local CF = CFrame.new

local LOW_C, LOW_S = V(0, 1.2, 0), V(2.3, 2.4, 2.3)
local TOP_C, TOP_S = V(0, 1.75, 0), V(1.9, 2.4, 1.9)

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

function Eggs.Build(eggId: string): Model
	local def = Config.GetEgg(eggId)
	return build(eggId, if def then def.Look else FALLBACK)
end

function Eggs.FromLook(name: string, look: Types.EggLook): Model
	return build(name, look)
end

return Eggs
