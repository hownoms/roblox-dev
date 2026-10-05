--!strict
--[[
	Treasures — ~1.5 stud trinkets for reveal pop-ups and ViewportFrames.
	PrimaryPart = invisible "Root" at the visual centre (pivot), front -Z, each shape given a
	slight three-quarter tilt so it reads well from a camera placed in front (at -Z) looking at +Z.
	One builder per Types.TreasureShape plus a few id-specific specials (flip-flop, sunglasses,
	map, spyglass, ...). Glow -> Neon accents + PointLight; Legendary/Mythic -> sparkles.
]]

local Types = require(script.Parent.Parent.Types)
local Config = require(script.Parent.Parent.Config)
local Build = require(script.Parent.Build)

local Treasures = {}

local V = Vector3.new
local CF = CFrame.new
local X = Vector3.xAxis
local Y = Vector3.yAxis
local Z = Vector3.zAxis
local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(35, 30, 45)
local GOLD = Color3.fromRGB(255, 205, 40)
local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local FACE_Z = CFrame.Angles(math.pi / 2, 0, 0) -- cylinder axis Y -> Z (disc facing the camera)

type Ctx = {
	m: Model,
	id: string,
	c: Color3,
	mat: Enum.Material,
	ac: Color3, -- accent colour
	am: Enum.Material, -- accent material
	glow: boolean,
}

-- Returns the main part and an optional display tilt.
type ShapeBuilder = (x: Ctx) -> (BasePart, CFrame?)

local shapes: { [string]: ShapeBuilder } = {}
local specials: { [string]: ShapeBuilder } = {}

shapes.Coin = function(x)
	local main = Build.cyl(x.m, "Coin", 0.22, 1.4, FACE_Z, x.c, x.mat)
	Build.cyl(x.m, "Inner", 0.28, 1.0, FACE_Z, Build.lighten(x.c, 0.18), x.mat)
	Build.tri(x.m, "Emblem", CF(0, 0.02, -0.15), 0.5, 0.5, 0.06, x.ac, x.am)
	Build.tri(x.m, "Emblem", CF(0, -0.06, -0.15) * CFrame.Angles(0, 0, math.pi), 0.5, 0.5, 0.06, x.ac, x.am)
	return main, CFrame.Angles(0, 0.4, 0)
end

shapes.Cap = function(x)
	local main = Build.cyl(x.m, "Cap", 0.3, 1.2, FACE_Z, x.c, x.mat)
	Build.cyl(x.m, "Top", 0.32, 0.85, FACE_Z, Build.lighten(x.c, 0.2), x.mat)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		local dir = V(math.cos(a), math.sin(a), 0)
		Build.part(
			x.m,
			"Crimp",
			V(0.2, 0.22, 0.3),
			CF(dir * 0.62) * CFrame.Angles(0, 0, a),
			Build.darken(x.c, 0.1),
			x.mat
		)
	end
	return main, CFrame.Angles(0.35, 0.35, 0)
end

shapes.Shell = function(x)
	local hinge = V(0, -0.6, 0)
	local main = Build.ellipsoid(x.m, "Back", V(1.5, 1.15, 0.24), CF(0, 0.02, 0.08), Build.darken(x.c, 0.1), x.mat)
	for _, a in { -0.9, -0.45, 0, 0.45, 0.9 } do
		local dir = V(-math.sin(a), math.cos(a), 0)
		Build.ellipsoid(
			x.m,
			"Rib",
			V(0.38, 1.25, 0.3),
			CF(hinge + dir * 0.6) * CFrame.Angles(0, 0, a),
			Build.lighten(x.c, 0.12),
			x.mat
		)
	end
	Build.part(x.m, "Hinge", V(0.6, 0.25, 0.22), CF(0, -0.62, 0), x.c, x.mat)
	if x.glow then
		Build.ball(x.m, "Pearl", 0.35, CF(0, -0.35, -0.2), WHITE, NEON)
	end
	return main, CFrame.Angles(-0.25, 0.35, 0)
end

shapes.Bottle = function(x)
	local main = Build.cyl(x.m, "Bottle", 0.9, 0.7, CF(0, -0.25, 0), x.c, x.mat)
	Build.ball(x.m, "Shoulder", 0.7, CF(0, 0.2, 0), x.c, x.mat)
	Build.cyl(x.m, "Neck", 0.45, 0.3, CF(0, 0.55, 0), x.c, x.mat)
	Build.cyl(x.m, "Cork", 0.22, 0.32, CF(0, 0.85, 0), Color3.fromRGB(170, 120, 70), Enum.Material.Wood)
	Build.cyl(x.m, "Scroll", 0.7, 0.3, CF(0, -0.2, 0), Color3.fromRGB(245, 225, 175))
	return main, CFrame.Angles(0, 0, -0.35)
end

shapes.Chest = function(x)
	local main = Build.part(x.m, "Base", V(1.4, 0.75, 0.9), CF(0, -0.25, 0), x.c, x.mat)
	Build.cylBetween(x.m, "Lid", V(-0.7, 0.12, 0), V(0.7, 0.12, 0), 0.9, Build.lighten(x.c, 0.08), x.mat)
	for _, px in { -0.42, 0.42 } do
		Build.part(x.m, "Band", V(0.14, 0.78, 0.94), CF(px, -0.25, 0), GOLD, Enum.Material.Metal)
		Build.cylBetween(x.m, "Band", V(px - 0.07, 0.12, 0), V(px + 0.07, 0.12, 0), 0.94, GOLD, Enum.Material.Metal)
	end
	Build.part(x.m, "Lock", V(0.25, 0.3, 0.1), CF(0, 0.02, -0.47), GOLD, Enum.Material.Metal)
	Build.ball(x.m, "Gem", 0.2, CF(0.25, 0.5, -0.2), Color3.fromRGB(255, 60, 90), NEON)
	return main, CFrame.Angles(0.25, 0.5, 0)
end

shapes.Gem = function(x)
	local main = Build.cyl(x.m, "Girdle", 0.22, 1.1, CF(0, 0.1, 0), x.c, x.mat)
	Build.cyl(x.m, "Crown", 0.3, 0.78, CF(0, 0.35, 0), Build.lighten(x.c, 0.25), x.mat)
	Build.spike(x.m, "Pavilion", V(0, 0.02, 0), V(0, -0.75, 0), 1.05, Build.darken(x.c, 0.08), x.mat)
	if x.glow then
		Build.ball(x.m, "Glint", 0.3, CF(0, 0.05, 0), Build.lighten(x.c, 0.5), NEON)
	end
	return main, CFrame.Angles(0.3, math.pi / 4, 0)
end

shapes.Bone = function(x)
	local main = Build.cylBetween(x.m, "Shaft", V(-0.55, 0, 0), V(0.55, 0, 0), 0.3, x.c, x.mat)
	for sx = -1, 1, 2 do
		for sy = -1, 1, 2 do
			Build.ball(x.m, "Knob", 0.42, CF(sx * 0.62, sy * 0.14, 0), x.c, x.mat)
		end
	end
	return main, CFrame.Angles(0.2, 0.3, 0.5)
end

shapes.Skull = function(x)
	local main = Build.ball(x.m, "Cranium", 1.2, CF(0, 0.15, 0), x.c, x.mat)
	Build.part(x.m, "Jaw", V(0.75, 0.38, 0.65), CF(0, -0.38, -0.12), x.c, x.mat)
	local eye = if x.glow then Build.lighten(x.c, 0.4) else DARK
	local em = if x.glow then NEON else SMOOTH
	for side = -1, 1, 2 do
		Build.ball(x.m, "Socket", 0.34, CF(side * 0.24, 0.08, -0.47), eye, em)
	end
	Build.tri(x.m, "Nose", CF(0, -0.12, -0.53), 0.18, 0.18, 0.06, DARK)
	for i = -1, 1 do
		Build.part(x.m, "Tooth", V(0.14, 0.16, 0.08), CF(i * 0.18, -0.32, -0.45), Build.lighten(x.c, 0.3))
	end
	return main, CFrame.Angles(0.1, 0.35, 0)
end

shapes.Orb = function(x)
	local main = Build.ball(x.m, "Orb", 1.2, CF(), x.c, x.mat)
	if x.glow and x.mat ~= NEON then
		Build.ball(x.m, "Core", 0.55, CF(), Build.lighten(x.c, 0.5), NEON)
	end
	Build.ellipsoid(
		x.m,
		"Shine",
		V(0.3, 0.2, 0.08),
		Build.surface(Vector3.zero, V(1.2, 1.2, 1.2), V(-0.5, 0.55, -0.7)),
		WHITE
	)
	return main, nil
end

shapes.Crown = function(x)
	local main = Build.cyl(x.m, "Band", 0.45, 1.3, CF(0, -0.25, 0), x.c, x.mat)
	Build.cyl(x.m, "Inside", 0.04, 1.16, CF(0, -0.02, 0), Build.darken(x.c, 0.45))
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		local dir = V(math.sin(a), 0, -math.cos(a))
		local tangent = V(-dir.Z, 0, dir.X)
		Build.triPts(
			x.m,
			"Point",
			dir * 0.6 + V(0, -0.05, 0),
			dir * 0.62 + V(0, 0.5, 0),
			tangent,
			0.55,
			0.1,
			x.c,
			x.mat
		)
		local gem = if k % 2 == 0 then Color3.fromRGB(255, 60, 90) else Color3.fromRGB(60, 140, 255)
		Build.ball(x.m, "Jewel", 0.2, CF(dir * 0.66 + V(0, -0.25, 0)), gem, if x.glow then NEON else SMOOTH)
	end
	return main, CFrame.Angles(0.35, 0.2, 0)
end

shapes.Tablet = function(x)
	local main = Build.part(x.m, "Slab", V(1.0, 1.1, 0.2), CF(0, -0.15, 0), x.c, x.mat)
	Build.cyl(x.m, "Arch", 0.2, 1.0, CF(0, 0.4, 0) * FACE_Z, x.c, x.mat)
	for i, y in { 0.35, 0.1, -0.15, -0.4 } do
		local w = if i % 2 == 0 then 0.5 else 0.66
		Build.part(x.m, "Glyph", V(w, 0.08, 0.05), CF(0, y, -0.11), x.ac, x.am)
	end
	return main, CFrame.Angles(0, 0.35, 0)
end

shapes.Egg = function(x)
	local main = Build.ellipsoid(x.m, "Egg", V(0.95, 1.0, 0.95), CF(0, -0.15, 0), x.c, x.mat)
	Build.ellipsoid(x.m, "EggTop", V(0.8, 1.0, 0.8), CF(0, 0.1, 0), x.c, x.mat)
	for _, d in { V(0.2, 0.2, -1), V(-0.8, -0.2, -0.6), V(0.8, -0.4, -0.3) } do
		Build.ellipsoid(
			x.m,
			"Spot",
			V(0.25, 0.25, 0.08),
			Build.surface(V(0, -0.15, 0), V(0.95, 1.0, 0.95), d),
			x.ac,
			x.am
		)
	end
	return main, CFrame.Angles(0, 0, -0.2)
end

shapes.Anchor = function(x)
	local main = Build.part(x.m, "Shank", V(0.2, 1.2, 0.2), CF(0, 0.05, 0), x.c, x.mat)
	Build.cyl(x.m, "Ring", 0.14, 0.44, CF(0, 0.75, 0) * FACE_Z, x.c, x.mat)
	Build.cyl(x.m, "Hole", 0.16, 0.2, CF(0, 0.75, 0) * FACE_Z, DARK)
	Build.part(x.m, "Stock", V(0.8, 0.15, 0.16), CF(0, 0.45, 0), Build.darken(x.c, 0.1), x.mat)
	for side = -1, 1, 2 do
		Build.beam(x.m, "Arm", V(0, -0.55, 0), V(side * 0.5, -0.25, 0), 0.18, 0.18, x.c, x.mat, Z)
		Build.triPts(x.m, "Fluke", V(side * 0.48, -0.32, 0), V(side * 0.62, 0.05, 0), X, 0.3, 0.14, x.c, x.mat)
	end
	Build.ball(x.m, "Crown", 0.26, CF(0, -0.55, 0), x.c, x.mat)
	return main, CFrame.Angles(0, 0.4, 0.15)
end

shapes.Wheel = function(x)
	local R = 0.6
	local seg = 2 * R * math.tan(math.pi / 8) + 0.04
	for k = 0, 7 do
		local a = (k + 0.5) / 8 * math.pi * 2
		Build.part(
			x.m,
			"Rim",
			V(seg, 0.14, 0.16),
			CFrame.Angles(0, 0, a) * CF(0, R * math.cos(math.pi / 8), 0),
			x.c,
			x.mat
		)
	end
	for k = 0, 3 do
		local a = k / 8 * math.pi * 2
		local dir = V(math.cos(a), math.sin(a), 0)
		Build.beam(x.m, "Spoke", -dir * 0.72, dir * 0.72, 0.1, 0.1, Build.darken(x.c, 0.1), x.mat, Z)
	end
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		Build.ball(x.m, "Knob", 0.17, CF(math.cos(a) * 0.78, math.sin(a) * 0.78, 0), x.ac, x.am)
	end
	local hub = Build.cyl(x.m, "Hub", 0.22, 0.32, FACE_Z, x.ac, x.am)
	return hub, CFrame.Angles(0, 0.35, 0)
end

shapes.Shard = function(x)
	local main = Build.ellipsoid(
		x.m,
		"Base",
		V(0.9, 0.3, 0.7),
		CF(0, -0.58, 0),
		Color3.fromRGB(110, 100, 115),
		Enum.Material.Slate
	)
	Build.spike(x.m, "Crystal", V(0, -0.6, 0), V(0, 0.72, 0), 0.55, x.c, x.mat)
	Build.spike(x.m, "Crystal", V(-0.1, -0.55, 0), V(-0.55, 0.25, 0), 0.38, Build.lighten(x.c, 0.15), x.mat)
	Build.spike(x.m, "Crystal", V(0.1, -0.55, 0.05), V(0.5, 0.1, -0.1), 0.34, Build.darken(x.c, 0.1), x.mat)
	return main, CFrame.Angles(0, 0.3, 0)
end

shapes.Box = function(x)
	local main = Build.part(x.m, "Box", V(1.1, 1.1, 1.1), CF(), x.c, x.mat)
	Build.part(x.m, "Ribbon", V(1.12, 1.12, 0.22), CF(), x.ac, x.am)
	Build.part(x.m, "Ribbon", V(0.22, 1.12, 1.12), CF(), x.ac, x.am)
	for side = -1, 1, 2 do
		Build.ellipsoid(
			x.m,
			"Bow",
			V(0.4, 0.25, 0.25),
			CF(side * 0.18, 0.66, 0) * CFrame.Angles(0, 0, side * 0.5),
			x.ac,
			x.am
		)
	end
	return main, CFrame.Angles(0.3, 0.6, 0)
end

-- Specials keyed by treasure id ---------------------------------------------------------------

specials.lost_flip_flop = function(x)
	local main = Build.ellipsoid(x.m, "Sole", V(0.65, 1.5, 0.14), CF(), x.c, x.mat)
	local strap = Build.lighten(x.c, 0.5)
	Build.ball(x.m, "ToePost", 0.14, CF(0, 0.4, -0.08), strap)
	for side = -1, 1, 2 do
		Build.beam(x.m, "Strap", V(0, 0.4, -0.1), V(side * 0.28, -0.12, -0.08), 0.1, 0.08, strap, SMOOTH, Z)
	end
	return main, CFrame.Angles(-0.3, 0.3, 0.25)
end

specials.cool_sunglasses = function(x)
	local frame = Build.part(x.m, "Bridge", V(0.3, 0.1, 0.1), CF(0, 0.1, 0), x.c, x.mat)
	for side = -1, 1, 2 do
		Build.cyl(
			x.m,
			"Lens",
			0.1,
			0.6,
			CF(side * 0.38, 0, 0) * FACE_Z,
			Color3.fromRGB(40, 50, 90),
			Enum.Material.Glass
		)
		Build.cyl(x.m, "Frame", 0.08, 0.68, CF(side * 0.38, 0, 0.05) * FACE_Z, x.c, x.mat)
		Build.part(x.m, "Arm", V(0.06, 0.08, 0.9), CF(side * 0.7, 0.1, 0.45), x.c, x.mat)
		Build.ellipsoid(x.m, "Shine", V(0.18, 0.1, 0.04), CF(side * 0.38 - 0.1, 0.12, -0.06), WHITE)
	end
	return frame, CFrame.Angles(0.15, 0.45, 0)
end

specials.frozen_fish = function(x)
	local ice = Build.part(x.m, "Ice", V(1.3, 0.95, 0.7), CF(), x.c, Enum.Material.Ice)
	ice.Transparency = 0.45
	local fish = Color3.fromRGB(255, 140, 60)
	Build.ellipsoid(x.m, "Fish", V(0.85, 0.45, 0.25), CF(-0.08, 0, 0), fish)
	Build.triPts(x.m, "Tail", V(0.55, 0, 0), V(0.25, 0, 0), Y, 0.4, 0.06, fish)
	Build.ball(x.m, "Eye", 0.1, CF(-0.36, 0.06, -0.12), DARK)
	return ice, CFrame.Angles(0.2, 0.4, 0)
end

specials.treasure_map = function(x)
	local main = Build.part(x.m, "Paper", V(1.25, 1.0, 0.05), CF(), x.c, x.mat)
	for _, y in { 0.5, -0.5 } do
		Build.cylBetween(x.m, "Roll", V(-0.66, y, 0), V(0.66, y, 0), 0.18, Build.darken(x.c, 0.1), x.mat)
	end
	local red = Color3.fromRGB(220, 40, 40)
	Build.part(x.m, "X", V(0.4, 0.08, 0.04), CF(0.3, -0.15, -0.04) * CFrame.Angles(0, 0, 0.785), red)
	Build.part(x.m, "X", V(0.4, 0.08, 0.04), CF(0.3, -0.15, -0.04) * CFrame.Angles(0, 0, -0.785), red)
	for i = 0, 2 do
		Build.part(x.m, "Path", V(0.12, 0.05, 0.04), CF(-0.4 + i * 0.2, 0.15 - i * 0.1, -0.04), Build.darken(x.c, 0.5))
	end
	return main, CFrame.Angles(0.2, 0.3, 0.05)
end

specials.captains_spyglass = function(x)
	local main = Build.cylBetween(x.m, "Tube", V(-0.75, 0, 0), V(-0.1, 0, 0), 0.42, x.c, x.mat)
	Build.cylBetween(x.m, "Tube", V(-0.15, 0, 0), V(0.35, 0, 0), 0.34, Build.darken(x.c, 0.15), x.mat)
	Build.cylBetween(x.m, "Tube", V(0.3, 0, 0), V(0.75, 0, 0), 0.26, x.c, x.mat)
	Build.cylBetween(x.m, "Ring", V(-0.12, 0, 0), V(-0.04, 0, 0), 0.46, Color3.fromRGB(90, 55, 30), Enum.Material.Wood)
	Build.cylBetween(
		x.m,
		"Lens",
		V(-0.77, 0, 0),
		V(-0.74, 0, 0),
		0.36,
		Color3.fromRGB(150, 220, 255),
		Enum.Material.Glass
	)
	return main, CFrame.Angles(0.2, 0.5, 0.35)
end

specials.pocket_watch = function(x)
	local main = Build.cyl(x.m, "Case", 0.24, 1.2, FACE_Z, x.c, x.mat)
	Build.cyl(x.m, "Dial", 0.26, 0.95, FACE_Z, Color3.fromRGB(255, 250, 235))
	Build.part(x.m, "Hand", V(0.06, 0.38, 0.04), CF(0, 0.17, -0.14), DARK)
	Build.part(x.m, "Hand", V(0.06, 0.28, 0.04), CF(0.11, 0.05, -0.14) * CFrame.Angles(0, 0, -1.2), DARK)
	Build.cyl(x.m, "Crown", 0.16, 0.2, CF(0, 0.66, 0), x.c, x.mat)
	Build.cyl(x.m, "Bow", 0.06, 0.32, CF(0, 0.82, 0) * FACE_Z, x.c, x.mat)
	return main, CFrame.Angles(0, 0.35, 0)
end

specials.sun_mask = function(x)
	local main = Build.cyl(x.m, "Mask", 0.24, 1.05, FACE_Z, x.c, x.mat)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local dir = V(math.cos(a), math.sin(a), 0)
		Build.triPts(x.m, "Ray", dir * 0.48, dir * 0.85, V(-dir.Y, dir.X, 0), 0.32, 0.12, Build.lighten(x.c, 0.2), x.am)
	end
	Build.face(x.m, CF(0, 0.02, -0.12), 1.0, { cheeks = true })
	return main, CFrame.Angles(0, 0.3, 0)
end

specials.beach_ball_of_creation = function(x)
	local main = Build.ball(x.m, "Ball", 1.3, CF(), WHITE)
	local stripes = { Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 215, 50), Color3.fromRGB(60, 150, 255) }
	for i, col in stripes do
		Build.ellipsoid(x.m, "Stripe", V(1.32, 1.32, 0.36), CFrame.Angles(0, (i - 1) * math.pi / 3, 0), col, NEON)
	end
	Build.ball(x.m, "Cap", 0.3, CF(0, 0.62, 0), WHITE, NEON)
	return main, CFrame.Angles(0.3, 0.2, 0)
end

local RAINBOW_GLOW = Color3.fromRGB(255, 230, 160)

local FALLBACK: Types.TreasureLook = {
	Color = Color3.fromRGB(255, 205, 60),
	Shape = "Coin",
	Material = Enum.Material.Metal,
	Glow = false,
}

local function build(id: string, look: Types.TreasureLook, rarity: Types.Rarity): Model
	local m = Build.model(id)
	local root = Build.root(m, CFrame.identity, V(0.2, 0.2, 0.2))
	local ctx: Ctx = {
		m = m,
		id = id,
		c = look.Color,
		mat = look.Material,
		ac = if look.Glow then Build.lighten(look.Color, 0.45) else Build.darken(look.Color, 0.3),
		am = if look.Glow then NEON else look.Material,
		glow = look.Glow,
	}
	local builder = specials[id] or shapes[look.Shape] or shapes.Coin
	local main, tilt = builder(ctx)
	if tilt then
		Build.transform(m, tilt, root)
	end
	if look.Glow then
		Build.glow(main, if id == "beach_ball_of_creation" then RAINBOW_GLOW else look.Color, 1.3, 7)
	end
	if rarity == "Legendary" or rarity == "Mythic" then
		Build.sparkle(main, Build.lighten(look.Color, 0.3), if rarity == "Mythic" then 10 else 5)
	end
	Build.weldAll(m, root)
	return m
end

function Treasures.Build(treasureId: string): Model
	local def = Config.GetTreasure(treasureId)
	if def then
		return build(treasureId, def.Look, def.Rarity)
	end
	return build(treasureId, FALLBACK, "Common")
end

function Treasures.FromLook(name: string, look: Types.TreasureLook, rarity: Types.Rarity?): Model
	return build(name, look, rarity or "Common")
end

return Treasures
