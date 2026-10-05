--!strict
--[[
	Backpacks — worn on the character's back.
	PrimaryPart = invisible "Root" at the centre of the pack's CONTACT face (the face touching
	the torso's back). The pack extends towards +Z (behind the character, who faces -Z);
	shoulder straps reach forward to -Z. Weld Root to the torso at
	    torso.CFrame * CFrame.new(0, 0, torso.Size.Z / 2)
	(Root attribute "AttachOffset" = CFrame.new(0, 0, 0.5) for a 1-stud-deep torso).
	All parts Anchored (server unanchors), Massless, CanCollide false, welded to Root.
	A sand-coloured part named "SandFill" exists on open containers (decorative).
]]

local Types = require(script.Parent.Parent.Types)
local Config = require(script.Parent.Parent.Config)
local Build = require(script.Parent.Build)

local Backpacks = {}

local V = Vector3.new
local CF = CFrame.new
local Z = Vector3.zAxis
local SAND = Color3.fromRGB(255, 222, 140)
local TIRE = Color3.fromRGB(45, 45, 55)
local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

type Ctx = {
	m: Model,
	id: string,
	c: Color3,
	a: Color3,
	mat: Enum.Material,
	am: Enum.Material,
	glow: boolean,
}

type ShapeBuilder = (x: Ctx) -> BasePart

local shapes: { [string]: ShapeBuilder } = {}

shapes.Bucket = function(x)
	local zc = 0.85
	local main = Build.cyl(x.m, "Body", 1.6, 1.6, CF(0, 0, zc), x.c, x.mat)
	Build.cyl(x.m, "Base", 0.3, 1.4, CF(0, -0.85, zc), Build.darken(x.c, 0.1), x.mat)
	Build.cyl(x.m, "Rim", 0.18, 1.78, CF(0, 0.8, zc), x.a, x.am)
	Build.ellipsoid(x.m, "SandFill", V(1.45, 0.5, 1.45), CF(0, 0.82, zc), SAND, Enum.Material.Sand)
	Build.beam(x.m, "Handle", V(-0.84, 0.6, zc), V(-0.55, 1.25, zc), 0.1, 0.1, x.a, x.am, Z)
	Build.beam(x.m, "Handle", V(-0.6, 1.25, zc), V(0.6, 1.25, zc), 0.1, 0.1, x.a, x.am, Z)
	Build.beam(x.m, "Handle", V(0.55, 1.25, zc), V(0.84, 0.6, zc), 0.1, 0.1, x.a, x.am, Z)
	-- star on the outer side
	local back = CF(0, 0, zc + 0.8) * CFrame.Angles(0, math.pi, 0)
	Build.tri(x.m, "Star", back * CF(0, 0.08, 0), 0.6, 0.5, 0.06, x.a, x.am)
	Build.tri(x.m, "Star", back * CF(0, -0.08, 0) * CFrame.Angles(0, 0, math.pi), 0.6, 0.5, 0.06, x.a, x.am)
	return main
end

shapes.Bag = function(x)
	local sack = string.find(x.id, "sack") ~= nil
	local bc, bs = V(0, -0.05, 0.65), V(1.8, 1.9, 1.2)
	local main = Build.ellipsoid(x.m, "Body", bs, CF(bc), x.c, x.mat)
	Build.ellipsoid(x.m, "Pocket", V(1.0, 0.75, 0.3), Build.surface(bc, bs, V(0, -0.35, 1)), x.a, x.am)
	if sack then
		Build.cyl(x.m, "Rope", 0.3, 0.55, CF(0, 0.95, 0.65), x.a, x.am)
		Build.ellipsoid(x.m, "Top", V(0.95, 0.5, 0.95), CF(0, 1.22, 0.65), x.c, x.mat)
		Build.part(x.m, "Patch", V(0.45, 0.45, 0.1), Build.surface(bc, bs, V(0.6, 0.4, 1)), x.a, x.am)
	else
		Build.ellipsoid(x.m, "Flap", V(1.7, 0.6, 1.1), CF(0, 0.68, 0.66), Build.darken(x.c, 0.12), x.mat)
		Build.ball(x.m, "Button", 0.24, Build.surface(V(0, 0.68, 0.66), V(1.7, 0.6, 1.1), V(0, -0.3, 1)), x.a, x.am)
	end
	return main
end

shapes.Box = function(x)
	local zc = 0.62
	local main = Build.part(x.m, "Body", V(1.9, 1.4, 1.2), CF(0, -0.1, zc), x.c, x.mat)
	Build.part(x.m, "Lid", V(2.0, 0.3, 1.3), CF(0, 0.72, zc), x.a, x.am)
	for side = -1, 1, 2 do
		Build.part(x.m, "HandlePost", V(0.12, 0.25, 0.12), CF(side * 0.5, 0.95, zc), Build.darken(x.a, 0.2))
	end
	Build.part(x.m, "Handle", V(1.12, 0.12, 0.16), CF(0, 1.08, zc), Build.darken(x.a, 0.2))
	Build.part(x.m, "Latch", V(0.3, 0.35, 0.1), CF(0, 0.45, zc + 0.62), x.a, x.am)
	Build.part(x.m, "Stripe", V(1.92, 0.18, 1.22), CF(0, -0.45, zc), x.a, x.am)
	return main
end

shapes.Barrel = function(x)
	local zc = 0.8
	local main = Build.cyl(x.m, "Body", 1.9, 1.5, CF(0, 0, zc), x.c, x.mat)
	Build.cyl(x.m, "Bulge", 1.0, 1.62, CF(0, 0, zc), x.c, x.mat)
	for _, y in { 0.62, -0.62 } do
		Build.cyl(x.m, "Hoop", 0.14, 1.6, CF(0, y, zc), x.a, if x.glow then NEON else Enum.Material.Metal)
	end
	Build.cyl(x.m, "Lid", 0.06, 1.38, CF(0, 0.94, zc), Build.darken(x.c, 0.2), x.mat)
	Build.ellipsoid(x.m, "SandFill", V(1.2, 0.4, 1.2), CF(0, 0.95, zc), SAND, Enum.Material.Sand)
	return main
end

local function wheel(m: Model, pos: Vector3, axis: Vector3, d: number, hub: Color3)
	Build.cylBetween(m, "Wheel", pos - axis * 0.09, pos + axis * 0.09, d, TIRE)
	Build.cylBetween(m, "Hub", pos - axis * 0.11, pos + axis * 0.11, d * 0.45, hub)
end

shapes.Cart = function(x)
	local zc = 0.7
	local main = Build.part(x.m, "Body", V(2.0, 1.0, 1.3), CF(0, 0, zc), x.c, x.mat)
	Build.part(x.m, "Lip", V(2.12, 0.16, 1.42), CF(0, 0.5, zc), x.a, x.am)
	Build.part(x.m, "Band", V(2.04, 0.14, 1.34), CF(0, -0.2, zc), Build.darken(x.c, 0.2), x.mat)
	Build.ellipsoid(x.m, "SandFill", V(1.8, 0.7, 1.1), CF(0, 0.55, zc), SAND, Enum.Material.Sand)
	for _, px in { -0.65, 0.65 } do
		for _, pz in { zc - 0.6, zc + 0.6 } do
			wheel(x.m, V(px, -0.55, pz), Z, 0.5, x.a)
		end
	end
	return main
end

shapes.Vehicle = function(x)
	if string.find(x.id, "ship") then
		local zc = 0.6
		local main = Build.part(x.m, "Hull", V(2.3, 0.7, 1.1), CF(-0.05, -0.5, zc), x.c, x.mat)
		Build.triPts(x.m, "Bow", V(1.1, -0.5, zc), V(1.65, -0.5, zc), Z, 1.1, 0.7, x.c, x.mat)
		Build.part(x.m, "Stripe", V(2.32, 0.15, 1.12), CF(-0.05, -0.22, zc), x.a, x.am)
		local cols = { Color3.fromRGB(230, 60, 60), Color3.fromRGB(255, 200, 40), Color3.fromRGB(60, 190, 100) }
		for i, col in cols do
			Build.part(x.m, "Container", V(0.55, 0.45, 0.9), CF(-0.35 + (i - 1) * 0.6, 0.08, zc), col)
		end
		Build.part(x.m, "Bridge", V(0.45, 0.85, 0.85), CF(-0.95, 0.25, zc), Color3.fromRGB(245, 245, 245))
		Build.part(
			x.m,
			"Windows",
			V(0.47, 0.14, 0.87),
			CF(-0.95, 0.5, zc),
			Color3.fromRGB(120, 210, 255),
			if x.glow then NEON else Enum.Material.Glass
		)
		Build.cyl(x.m, "Funnel", 0.45, 0.3, CF(-0.95, 0.88, zc), x.a, x.am)
		return main
	end
	-- dump / sand truck, length along X, wheels on the ±Z sides
	local zc = 0.65
	local main = Build.part(x.m, "Bed", V(1.5, 0.7, 1.15), CF(0.4, -0.12, zc) * CFrame.Angles(0, 0, 0.15), x.c, x.mat)
	Build.ellipsoid(x.m, "SandFill", V(1.3, 0.55, 1.0), CF(0.42, 0.25, zc) * CFrame.Angles(0, 0, 0.15), SAND, Enum.Material.Sand)
	Build.part(x.m, "Chassis", V(2.4, 0.3, 1.2), CF(0, -0.62, zc), x.a, x.am)
	Build.part(x.m, "Cab", V(0.8, 0.95, 1.1), CF(-0.8, -0.1, zc), x.c, x.mat)
	Build.part(x.m, "Window", V(0.5, 0.35, 1.14), CF(-0.75, 0.08, zc), Color3.fromRGB(140, 210, 255), Enum.Material.Glass)
	Build.part(x.m, "Bumper", V(0.12, 0.2, 1.2), CF(-1.25, -0.55, zc), Color3.fromRGB(220, 220, 225), Enum.Material.Metal)
	for _, px in { -0.8, 0.75 } do
		for _, pz in { zc - 0.62, zc + 0.62 } do
			wheel(x.m, V(px, -0.8, pz), Z, 0.6, Color3.fromRGB(220, 220, 225))
		end
	end
	return main
end

shapes.Orb = function(x)
	local zc = 1.0
	Build.part(x.m, "Harness", V(0.8, 0.8, 0.3), CF(0, 0, 0.15), Color3.fromRGB(60, 55, 75), Enum.Material.Metal)
	local main = Build.ball(x.m, "Orb", 1.7, CF(0, 0.05, zc), x.c, x.mat)
	Build.ball(x.m, "Core", 0.9, CF(0, 0.05, zc), Build.darken(x.c, 0.5), SMOOTH)
	main.Transparency = math.max(main.Transparency, 0.25)
	Build.cyl(x.m, "Ring", 0.06, 2.5, CF(0, 0.05, zc) * CFrame.Angles(0.45, 0, 0.3), x.a, NEON)
	return main
end

local FALLBACK: Types.BackpackLook = {
	Color = Color3.fromRGB(60, 170, 255),
	AccentColor = Color3.fromRGB(255, 230, 60),
	Shape = "Bucket",
	Material = SMOOTH,
	Glow = false,
}

local function build(id: string, look: Types.BackpackLook): Model
	local m = Build.model(id)
	local root = Build.root(m, CFrame.identity, V(0.6, 0.6, 0.1))
	root:SetAttribute("AttachOffset", CF(0, 0, 0.5))
	local ctx: Ctx = {
		m = m,
		id = id,
		c = look.Color,
		a = look.AccentColor,
		mat = look.Material,
		am = if look.Glow then NEON else SMOOTH,
		glow = look.Glow,
	}
	local builder = shapes[look.Shape] or shapes.Bucket
	local main = builder(ctx)

	-- shoulder straps (over the shoulders onto the chest)
	local strap = Build.darken(look.AccentColor, 0.25)
	for side = -1, 1, 2 do
		Build.part(m, "Strap", V(0.25, 0.08, 1.05), CF(side * 0.5, 0.86, -0.48), strap)
		Build.part(m, "Strap", V(0.25, 1.1, 0.08), CF(side * 0.5, 0.33, -1.03), strap)
	end

	if look.Glow then
		Build.glow(main, look.AccentColor, 1.2, 8)
		Build.sparkle(main, look.AccentColor, 4)
	end
	Build.massless(m, root)
	root.Massless = true
	Build.weldAll(m, root)
	return m
end

function Backpacks.Build(backpackId: string): Model
	local def = Config.GetBackpack(backpackId)
	return build(backpackId, if def then def.Look else FALLBACK)
end

function Backpacks.FromLook(name: string, look: Types.BackpackLook): Model
	return build(name, look)
end

return Backpacks
