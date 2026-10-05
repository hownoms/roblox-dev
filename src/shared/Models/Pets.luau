--!strict
--[[
	Pets — cute low-poly creatures, one builder per Types.PetShape.
	Built at unit scale (~2-2.5 studs) then scaled by Look.Size about the bottom-centre.

	PrimaryPart = invisible "Root" at the bottom-centre (pivot), facing -Z (the pet's front).
	All parts Anchored, CanCollide/CanQuery false, welded to Root (client may unanchor).
	Glow -> Neon accents + PointLight. Legendary/Mythic -> "Sparkles" emitter on "Body";
	Mythic also gets a floating halo of neon orbs (parts named "Halo").
]]

local Types = require(script.Parent.Parent.Types)
local Config = require(script.Parent.Parent.Config)
local Build = require(script.Parent.Build)

local Pets = {}

local V = Vector3.new
local CF = CFrame.new
local X = Vector3.xAxis
local Y = Vector3.yAxis
local Z = Vector3.zAxis
local WHITE = Color3.new(1, 1, 1)
local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

type Ctx = {
	m: Model,
	id: string,
	B: Color3, -- body
	A: Color3, -- accent
	am: Enum.Material, -- accent material (Neon when Glow)
	glow: boolean,
}

-- Each builder returns the main body part and the Y of the top of the head (for the halo).
type ShapeBuilder = (c: Ctx) -> (BasePart, number)

local shapes: { [string]: ShapeBuilder } = {}

shapes.Crab = function(c)
	local m, B, A = c.m, c.B, c.A
	local body = Build.ellipsoid(m, "Body", V(2.0, 1.1, 1.5), CF(0, 0.85, 0), B)
	Build.ellipsoid(m, "Belly", V(1.7, 0.5, 1.3), CF(0, 0.55, 0), A)
	for side = -1, 1, 2 do
		Build.cylBetween(m, "Stalk", V(side * 0.3, 1.25, -0.42), V(side * 0.36, 1.72, -0.48), 0.12, B)
		local eye = CF(side * 0.36, 1.82, -0.5)
		Build.ball(m, "Eye", 0.36, eye, Build.EYE)
		Build.ball(m, "EyeShine", 0.13, eye * CF(0.07, 0.07, -0.13), WHITE, NEON)
		-- claw
		local shoulder = V(side * 0.85, 0.75, -0.35)
		local wrist = V(side * 1.2, 0.95, -0.85)
		Build.cylBetween(m, "Arm", shoulder, wrist, 0.22, B)
		Build.ball(m, "Pincer", 0.62, CF(side * 1.25, 1.0, -0.95), B)
		local jaw = Build.lighten(B, 0.15)
		Build.triPts(m, "Jaw", V(side * 1.25, 1.1, -1.12), V(side * 1.25, 1.2, -1.55), X, 0.36, 0.18, jaw)
		Build.triPts(m, "Jaw", V(side * 1.25, 0.9, -1.12), V(side * 1.25, 0.82, -1.45), X, 0.3, 0.16, jaw)
		-- legs
		for _, z in { -0.1, 0.25, 0.55 } do
			Build.beam(
				m,
				"Leg",
				V(side * 0.8, 0.7, z),
				V(side * 1.3, 0.05, z + 0.1),
				0.16,
				0.16,
				Build.darken(B, 0.1),
				SMOOTH,
				Z
			)
		end
	end
	Build.face(m, CF(0, 0.85, -0.72), 1, { eyes = false, radius = 0.8 })
	return body, 2.0
end

shapes.Bird = function(c)
	local m, B, A, am = c.m, c.B, c.A, c.am
	local wing = Build.darken(B, 0.12)
	local body = Build.ellipsoid(m, "Body", V(1.3, 1.35, 1.45), CF(0, 1.05, 0.05), B)
	Build.ellipsoid(
		m,
		"Breast",
		V(0.95, 0.95, 0.3),
		Build.surface(V(0, 1.05, 0.05), V(1.3, 1.35, 1.45), V(0, -0.25, -1)),
		Build.lighten(B, 0.35)
	)
	local headC = V(0, 1.95, -0.3)
	Build.ball(m, "Head", 1.1, CF(headC), B)
	Build.face(m, CF(0, 1.98, -0.84), 0.85, { mouth = false, radius = 0.55 })
	Build.ellipsoid(m, "Beak", V(0.4, 0.24, 0.55), CF(0, 1.8, -0.86), A, am)
	Build.triPts(m, "Crest", V(0, 2.4, -0.35), V(0, 2.85, -0.12), Z, 0.36, 0.12, A, am)
	Build.triPts(m, "Crest", V(0, 2.38, -0.1), V(0, 2.72, 0.22), Z, 0.3, 0.12, A, am)
	for side = -1, 1, 2 do
		Build.ellipsoid(
			m,
			"Wing",
			V(0.22, 0.85, 1.15),
			CF(side * 0.7, 1.15, 0.12) * CFrame.Angles(0.15, 0, -side * 0.28),
			wing
		)
		Build.cylBetween(m, "Leg", V(side * 0.28, 0.06, 0), V(side * 0.28, 0.55, 0.05), 0.12, A)
		Build.ellipsoid(m, "Foot", V(0.3, 0.1, 0.42), CF(side * 0.28, 0.05, -0.1), A)
	end
	Build.triPts(m, "Tail", V(0, 0.95, 0.6), V(0, 0.75, 1.35), X, 0.75, 0.12, if c.glow then A else wing, am)
	return body, 2.9
end

shapes.Star = function(c)
	local m, B, A, am = c.m, c.B, c.A, c.am
	local centre = V(0, 1.1, 0)
	local body = Build.ellipsoid(m, "Body", V(1.2, 1.2, 0.6), CF(centre), B)
	for k = 0, 4 do
		local a = math.rad(90 + 72 * k)
		local dir = V(math.cos(a), math.sin(a), 0)
		Build.tri(m, "Arm", CF(centre) * CFrame.Angles(0, 0, a - math.pi / 2) * CF(0, 0.85, 0), 0.8, 1.0, 0.42, B)
		Build.ball(m, "Dot", 0.2, CF(centre + dir * 0.85 + V(0, 0, -0.2)), A, am)
	end
	Build.face(m, CF(0, 1.1, -0.3), 1, { radius = 1.2 })
	return body, 2.4
end

shapes.Turtle = function(c)
	local m, B, A = c.m, c.B, c.A
	local shellC, shellS = V(0, 0.9, 0.1), V(1.9, 1.15, 2.0)
	local body = Build.ellipsoid(m, "Body", shellS, CF(shellC), A)
	Build.cyl(m, "Rim", 0.18, 2.05, CF(0, 0.55, 0.1), Build.lighten(A, 0.25))
	local plate = if c.glow then Build.lighten(A, 0.3) else Build.darken(A, 0.2)
	for _, dir in { V(0, 1, 0), V(0.7, 0.8, 0.5), V(-0.7, 0.8, 0.5), V(0, 0.8, -0.7) } do
		Build.ellipsoid(m, "Plate", V(0.62, 0.62, 0.2), Build.surface(shellC, shellS, dir), plate, c.am)
	end
	Build.ellipsoid(m, "Belly", V(1.7, 0.35, 1.8), CF(0, 0.45, 0.1), Build.lighten(B, 0.35))
	Build.ball(m, "Head", 0.95, CF(0, 1.0, -1.4), B)
	Build.face(m, CF(0, 1.02, -1.87), 0.8, { radius = 0.48 })
	for side = -1, 1, 2 do
		for _, z in { -0.6, 0.75 } do
			Build.ellipsoid(m, "Leg", V(0.5, 0.36, 0.62), CF(side * 0.78, 0.2, z) * CFrame.Angles(0, side * 0.4, 0), B)
		end
	end
	Build.triPts(m, "Tail", V(0, 0.5, 1.0), V(0, 0.4, 1.45), X, 0.3, 0.15, B)
	return body, 1.6
end

shapes.Fish = function(c)
	local m, B, A, am = c.m, c.B, c.A, c.am
	local shark = string.find(c.id, "shark") ~= nil
	local fin = Build.lighten(B, 0.15)
	local body = Build.ellipsoid(m, "Body", V(1.2, 1.3, 2.0), CF(0, 1.3, 0), B)
	Build.triPts(m, "Tail", V(0, 1.3, 1.75), V(0, 1.3, 0.85), Y, 1.3, 0.14, fin)
	local dorsalH = if shark then 0.85 else 0.5
	Build.triPts(m, "Dorsal", V(0, 1.85, 0.1), V(0, 1.9 + dorsalH, 0.4), Z, 0.8, 0.12, fin)
	for side = -1, 1, 2 do
		Build.ellipsoid(
			m,
			"Fin",
			V(0.12, 0.35, 0.55),
			CF(side * 0.6, 1.1, -0.05) * CFrame.Angles(0.4, 0, side * 0.6),
			fin
		)
	end
	for _, z in { -0.35, 0.4 } do
		local k = math.sqrt(1 - (z / 1.0) ^ 2) * 1.05
		Build.ellipsoid(m, "Stripe", V(1.2 * k, 1.3 * k, 0.22), CF(0, 1.3, z), A, am)
	end
	Build.face(m, CF(0, 1.36, -0.96), 0.75, { radius = 0.45, cheeks = not shark })
	return body, 1.95 + dorsalH
end

shapes.Squid = function(c)
	local m, B, A, am = c.m, c.B, c.A, c.am
	local domeC, domeS = V(0, 1.6, 0), V(1.6, 1.8, 1.6)
	local body = Build.ellipsoid(m, "Body", domeS, CF(domeC), B)
	for _, dir in { V(0.5, 0.6, 0.4), V(-0.6, 0.5, 0.3), V(0.1, 0.9, 0.5) } do
		Build.ellipsoid(m, "Spot", V(0.36, 0.36, 0.1), Build.surface(domeC, domeS, dir), A, am)
	end
	local tent = Build.darken(B, 0.06)
	for k = 0, 5 do
		local a = math.rad(30 + 60 * k)
		local dir = V(math.sin(a), 0, -math.cos(a))
		local p0 = V(0, 0.9, 0) + dir * 0.45
		local p1 = V(0, 0.38, 0) + dir * 0.85
		local p2 = V(0, 0.16, 0) + dir * 1.18
		Build.cylBetween(m, "Tentacle", p0, p1, 0.34, tent)
		Build.cylBetween(m, "Tentacle", p1, p2, 0.26, tent)
		Build.ball(m, "TentacleTip", 0.28, CF(p2 + V(0, 0.08, 0)), A, am)
	end
	Build.face(m, CF(0, 1.4, -0.78), 1, { radius = 0.8 })
	return body, 2.5
end

shapes.Blob = function(c)
	local m, B, A, am = c.m, c.B, c.A, c.am
	local puffer = string.find(c.id, "puffer") ~= nil
	local ghost = string.find(c.id, "ghost") ~= nil or string.find(c.id, "spirit") ~= nil
	local bc, bs = V(0, 0.78, 0), V(1.9, 1.55, 1.8)
	local body = Build.ellipsoid(m, "Body", bs, CF(bc), B)
	if c.glow then
		body.Transparency = 0.25
		Build.ball(m, "Core", 0.8, CF(0, 0.8, 0.15), A, NEON)
	end
	Build.ellipsoid(m, "Shine", V(0.4, 0.24, 0.1), Build.surface(bc, bs, V(-0.5, 0.75, -0.45)), WHITE)
	Build.face(m, CF(0, 0.8, -0.9), 1.1, { radius = 0.92 })
	if puffer then
		for k = 0, 7 do
			local a = math.rad(45 * k + 22.5)
			local dir = V(math.cos(a), if k % 2 == 0 then 0.35 else -0.05, math.sin(a))
			local cf = Build.surface(bc, bs, dir)
			local n = cf.LookVector
			Build.triPts(m, "Spike", cf.Position - n * 0.08, cf.Position + n * 0.35, Y:Cross(n), 0.3, 0.1, A)
		end
	else
		if not ghost then
			for side = -1, 1, 2 do
				Build.ellipsoid(m, "Foot", V(0.5, 0.22, 0.55), CF(side * 0.45, 0.1, -0.25), Build.darken(B, 0.15))
			end
		end
		Build.cylBetween(m, "Antenna", V(0, 1.45, 0.05), V(0.15, 1.95, 0.1), 0.08, A)
		Build.ball(m, "Bobble", 0.3, CF(0.17, 2.02, 0.1), A, am)
	end
	return body, 2.1
end

shapes.Mole = function(c)
	local m, B, A = c.m, c.B, c.A
	local bc, bs = V(0, 0.75, 0), V(1.6, 1.5, 1.7)
	local body = Build.ellipsoid(m, "Body", bs, CF(bc), B)
	Build.ellipsoid(m, "Belly", V(0.9, 0.9, 0.16), Build.surface(bc, bs, V(0, -0.35, -1)), Build.lighten(B, 0.35))
	Build.ellipsoid(m, "Snout", V(0.6, 0.42, 0.5), CF(0, 0.66, -0.82), Build.lighten(B, 0.2))
	Build.ball(m, "Nose", 0.3, CF(0, 0.7, -1.1), A)
	Build.face(m, CF(0, 1.0, -0.8), 0.8, { mouth = false, radius = 0.8 })
	for side = -1, 1, 2 do
		Build.ellipsoid(m, "Paw", V(0.5, 0.18, 0.45), CF(side * 0.5, 0.09, -0.68) * CFrame.Angles(0, side * 0.3, 0), A)
	end
	-- mining helmet
	local yellow = Color3.fromRGB(255, 200, 40)
	Build.ellipsoid(m, "Helmet", V(1.3, 0.8, 1.35), CF(0, 1.38, 0.02), yellow)
	Build.cyl(m, "Brim", 0.1, 1.5, CF(0, 1.32, 0.02), Build.darken(yellow, 0.12))
	Build.cyl(m, "Lamp", 0.2, 0.32, CF(0, 1.55, -0.62) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(90, 90, 100))
	local bulb = Build.ball(m, "Bulb", 0.24, CF(0, 1.55, -0.73), Color3.fromRGB(255, 250, 200), NEON)
	Build.glow(bulb, Color3.fromRGB(255, 240, 190), 0.8, 6)
	return body, 1.8
end

shapes.Dino = function(c)
	local m, B, A, am = c.m, c.B, c.A, c.am
	local steg = string.find(c.id, "steg") ~= nil
	local rex = string.find(c.id, "rex") ~= nil
	local sala = string.find(c.id, "salamander") ~= nil
	local bc, bs = V(0, 1.0, 0.1), V(1.3, 1.2, 1.7)
	local body = Build.ellipsoid(m, "Body", bs, CF(bc), B)
	Build.ellipsoid(m, "Belly", V(0.85, 0.85, 0.2), Build.surface(bc, bs, V(0, -0.3, -1)), Build.lighten(A, 0.1))
	Build.cylBetween(m, "Neck", V(0, 1.2, -0.4), V(0, 1.75, -0.7), 0.55, B)
	local hs = if rex then 1.15 else 1.0
	Build.ellipsoid(m, "Head", V(1.0, 0.9, 1.15) * hs, CF(0, 1.85, -0.78), B)
	Build.face(m, CF(0, 1.9, -0.78 - 0.56 * hs), 0.9 * hs, { radius = 0.5 * hs })
	Build.cylBetween(m, "Tail", V(0, 1.0, 0.8), V(0, 0.7, 1.5), 0.55, B)
	Build.triPts(m, "TailTip", V(0, 0.72, 1.45), V(0, 0.45, 2.1), X, 0.45, 0.3, B)
	for side = -1, 1, 2 do
		Build.ellipsoid(m, "Leg", V(0.45, 0.75, 0.6), CF(side * 0.48, 0.42, 0.3), B)
		Build.ellipsoid(m, "Foot", V(0.42, 0.16, 0.6), CF(side * 0.48, 0.08, 0.15), Build.darken(B, 0.15))
		local armLen = if rex then 0.22 else 0.38
		Build.beam(
			m,
			"Arm",
			V(side * 0.42, 1.05, -0.55),
			V(side * 0.48, 1.05 - armLen, -0.55 - armLen * 0.8),
			0.15,
			0.15,
			B,
			SMOOTH,
			X
		)
	end
	if sala then
		for _, dir in { V(0.5, 0.8, 0.2), V(-0.5, 0.8, -0.1), V(0.1, 0.9, 0.7), V(-0.3, 0.7, 0.8) } do
			Build.ellipsoid(m, "Spot", V(0.3, 0.3, 0.1), Build.surface(bc, bs, dir), A, am)
		end
	else
		local count = if steg then 5 else 3
		local h = if steg then 0.55 else 0.3
		for i = 1, count do
			local z = -0.4 + (i - 1) * (1.1 / (count - 1))
			local rel = math.clamp((z - bc.Z) / (bs.Z / 2), -1, 1)
			local y = bc.Y + bs.Y / 2 * math.sqrt(1 - rel * rel)
			local hh = h * (1 - math.abs(i - (count + 1) / 2) / count)
			Build.triPts(m, "Plate", V(0, y - 0.06, z), V(0, y + hh, z + 0.1), Z, hh * 1.1, 0.12, A, am)
		end
	end
	return body, 1.85 + 0.45 * hs
end

shapes.Dragon = function(c)
	local m, B, A, am = c.m, c.B, c.A, c.am
	local bc, bs = V(0, 1.05, 0.1), V(1.4, 1.35, 1.8)
	local body = Build.ellipsoid(m, "Body", bs, CF(bc), B)
	Build.ellipsoid(m, "Belly", V(0.95, 0.95, 0.2), Build.surface(bc, bs, V(0, -0.3, -1)), Build.lighten(A, 0.2))
	Build.cylBetween(m, "Neck", V(0, 1.35, -0.45), V(0, 1.95, -0.7), 0.6, B)
	Build.ellipsoid(m, "Head", V(1.15, 1.0, 1.1), CF(0, 2.2, -0.75), B)
	Build.ellipsoid(m, "Snout", V(0.75, 0.5, 0.6), CF(0, 2.04, -1.25), Build.lighten(B, 0.1))
	Build.face(m, CF(0, 2.42, -1.25), 0.85, { mouth = false, cheeks = false, radius = 0.55 })
	for side = -1, 1, 2 do
		Build.triPts(m, "Horn", V(side * 0.3, 2.58, -0.6), V(side * 0.42, 3.1, -0.3), Z, 0.3, 0.14, A, am)
		Build.triPts(m, "Wing", V(side * 0.62, 1.55, 0.1), V(side * 1.8, 2.4, 0.4), Z, 1.3, 0.1, A, am)
		for _, z in { -0.45, 0.6 } do
			Build.ellipsoid(m, "Leg", V(0.45, 0.6, 0.5), CF(side * 0.5, 0.3, z), B)
		end
	end
	Build.cylBetween(m, "Tail", V(0, 1.0, 0.85), V(0, 0.6, 1.6), 0.5, B)
	Build.triPts(m, "TailTip", V(0, 0.6, 1.55), V(0, 0.68, 2.1), X, 0.55, 0.12, A, am)
	for _, z in { 0.0, 0.5 } do
		local rel = (z - bc.Z) / (bs.Z / 2)
		local y = bc.Y + bs.Y / 2 * math.sqrt(1 - rel * rel)
		Build.triPts(m, "Spine", V(0, y - 0.06, z), V(0, y + 0.32, z + 0.12), Z, 0.32, 0.1, A, am)
	end
	return body, 3.1
end

shapes.Golem = function(c)
	local m, B, A, am = c.m, c.B, c.A, c.am
	local dark = Build.darken(B, 0.12)
	local body = Build.part(m, "Body", V(1.6, 1.3, 1.1), CF(0, 1.3, 0), B)
	Build.part(m, "Head", V(1.0, 0.85, 0.9), CF(0, 2.35, -0.05), B)
	Build.face(m, CF(0, 2.33, -0.5), 0.85)
	for side = -1, 1, 2 do
		Build.part(m, "Arm", V(0.5, 1.1, 0.55), CF(side * 1.08, 1.3, 0) * CFrame.Angles(0, 0, side * 0.12), dark)
		Build.part(m, "Fist", V(0.7, 0.6, 0.7), CF(side * 1.18, 0.55, 0), B)
		Build.part(m, "Leg", V(0.55, 0.65, 0.6), CF(side * 0.42, 0.33, 0), dark)
	end
	Build.spike(m, "Crystal", V(-0.6, 1.85, 0.1), V(-0.95, 2.6, 0.25), 0.38, A, am)
	Build.spike(m, "Crystal", V(0.65, 1.85, 0.05), V(0.98, 2.45, 0.2), 0.32, A, am)
	Build.spike(m, "Crystal", V(0, 1.6, 0.45), V(0, 2.35, 0.95), 0.42, A, am)
	Build.ball(m, "Gem", 0.36, CF(0, 1.45, -0.55), A, am)
	return body, 2.8
end

shapes.Seal = function(c)
	local m, B, A = c.m, c.B, c.A
	local fl = Build.darken(B, 0.1)
	local body = Build.ellipsoid(m, "Body", V(1.5, 1.25, 2.0), CF(0, 0.62, 0.15), B)
	Build.ball(m, "Head", 1.2, CF(0, 1.4, -0.55), B)
	Build.face(m, CF(0, 1.52, -1.13), 0.85, { mouth = false, radius = 0.6 })
	Build.ellipsoid(m, "Snout", V(0.55, 0.32, 0.3), CF(0, 1.28, -1.1), Build.lighten(B, 0.5))
	Build.ball(m, "Nose", 0.2, CF(0, 1.38, -1.24), Build.EYE)
	for side = -1, 1, 2 do
		Build.ellipsoid(
			m,
			"Flipper",
			V(0.2, 0.3, 0.7),
			CF(side * 0.72, 0.3, -0.35) * CFrame.Angles(0.3, 0, side * 0.8),
			fl
		)
		Build.ellipsoid(
			m,
			"TailFlipper",
			V(0.6, 0.15, 0.4),
			CF(side * 0.3, 0.12, 1.15) * CFrame.Angles(0, side * 0.5, 0),
			fl
		)
	end
	-- beach ball balanced on its head
	Build.ball(m, "Ball", 0.6, CF(0, 2.28, -0.6), A, c.am)
	Build.ellipsoid(m, "BallStripe", V(0.63, 0.63, 0.22), CF(0, 2.28, -0.6) * CFrame.Angles(0, 0.6, 0.3), WHITE)
	return body, 2.6
end

local FALLBACK: Types.PetLook = {
	BodyColor = Color3.fromRGB(255, 170, 120),
	AccentColor = Color3.fromRGB(255, 240, 200),
	Shape = "Blob",
	Size = 1,
	Glow = false,
}

local function build(id: string, look: Types.PetLook, rarity: Types.Rarity): Model
	local m = Build.model(id)
	local root = Build.root(m, CFrame.identity, V(1, 0.1, 1))
	local ctx: Ctx = {
		m = m,
		id = id,
		B = look.BodyColor,
		A = look.AccentColor,
		am = if look.Glow then NEON else SMOOTH,
		glow = look.Glow,
	}
	local builder = shapes[look.Shape] or shapes.Blob
	local body, top = builder(ctx)

	if look.Glow then
		Build.glow(body, look.AccentColor, 1, 7)
	end
	if rarity == "Legendary" or rarity == "Mythic" then
		Build.sparkle(body, look.AccentColor, if rarity == "Mythic" then 8 else 4)
	end
	if rarity == "Mythic" then
		for k = 0, 5 do
			local a = math.rad(60 * k)
			Build.ball(
				m,
				"Halo",
				0.2,
				CF(math.cos(a) * 0.55, top + 0.35, math.sin(a) * 0.55),
				Color3.fromRGB(255, 240, 150),
				NEON
			)
		end
	end

	Build.scale(m, CFrame.identity, math.clamp(look.Size, 0.3, 3))
	Build.weldAll(m, root)
	return m
end

function Pets.Build(petId: string): Model
	local def = Config.GetPet(petId)
	if def then
		return build(petId, def.Look, def.Rarity)
	end
	return build(petId, FALLBACK, "Common")
end

function Pets.FromLook(name: string, look: Types.PetLook, rarity: Types.Rarity?): Model
	return build(name, look, rarity or "Common")
end

return Pets
