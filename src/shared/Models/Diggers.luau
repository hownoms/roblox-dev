--!strict
--[[
	Diggers — chunky cartoon construction vehicles from primitives (no asset ids), one builder per
	vehicle Kind. Roughly 3-6 studs long at scale 1.

	v2.1: the Garage diggers became vehicle PETS (Config/Pets.luau, PetDef.VehicleKind = the Kind
	here, colours from PetDef.Look). Models.Pet(id) draws vehicle pets through Diggers.Build(id,
	Look.Size). The Ride agent may reuse these builders read-only (Diggers.FromLook / Kinds).

	API:
	  Diggers.Build(id, scale?)               id = a vehicle pet id (or a Kind name); scale default 1
	  Diggers.FromLook(name, look, scale?)    look = { Kind, Body: Color3, Accent: Color3, Glow }
	  Diggers.Kinds(): { string }             every Kind with a dedicated builder

	Conventions (Models/Build.luau):
	- PrimaryPart = invisible "Root" at the bottom-centre (pivot on the ground), front = -Z.
	- Every part Anchored, CanCollide / CanQuery / CanTouch false, so a digger never blocks the
	  dig raycasts or players. Static parts are welded to Root (inert while anchored).
	- Moving assemblies are sub-Models with an invisible PrimaryPart "Hinge" (NOT welded) and
	  the attributes the client animator reads:
	      Motion  "Swing"  rotate about the hinge's X axis by Amount * sin(pi * t)  (arms, buckets)
	              "Tip"    same as Swing, slower ease (dump beds)
	              "Spin"   rotate about the hinge's Y axis, Amount radians per second while digging
	              "Drill"  Spin + plunge along the hinge's +Y by Plunge studs * sin(pi * t)
	  Drill / Spin hinges have their Y axis along the bit (pointing where it digs).
	      Amount  number   radians (Swing / Tip) or radians per second (Spin / Drill)
	      Plunge  number?  studs (Drill)
	  Names: "Arm", "Loader", "Bed", "Blade", "Drill", "Cutter".
	- Model attributes "Kind" = Look.Kind and "Scale" = the build scale (Plunge is pre-scaled).
]]

local Config = require(script.Parent.Parent.Config)
local Build = require(script.Parent.Build)

local Diggers = {}

local V = Vector3.new
local CF = CFrame.new
local X = Vector3.xAxis
local Y = Vector3.yAxis
local Z = Vector3.zAxis
local WHITE = Color3.new(1, 1, 1)
local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local GLASS = Enum.Material.Glass

local TYRE = Color3.fromRGB(40, 38, 45)
local HUB = Color3.fromRGB(200, 200, 210)
local WINDOW = Color3.fromRGB(150, 220, 255)
local STEEL = Color3.fromRGB(150, 155, 165)
local SAND = Color3.fromRGB(240, 205, 130)

type Ctx = {
	m: Model,
	B: Color3, -- body
	A: Color3, -- accent
	am: Enum.Material, -- accent material (Neon when Glow)
	glow: boolean,
}

type KindBuilder = (c: Ctx) -> BasePart -- returns the main body part (for glow / sparkles)

local kinds: { [string]: KindBuilder } = {}

-- Helpers -----------------------------------------------------------------------------------

-- Moving sub-assembly. Parts built into the returned model are animated around `hinge`.
local function joint(parent: Instance, name: string, hinge: CFrame, motion: string, amount: number): Model
	local j = Instance.new("Model")
	j.Name = name
	local h = Build.part(j, "Hinge", V(0.2, 0.2, 0.2), hinge, WHITE)
	h.Transparency = 1
	h.CastShadow = false
	j.PrimaryPart = h
	j:SetAttribute("Motion", motion)
	j:SetAttribute("Amount", amount)
	j.Parent = parent
	return j
end

local function wheel(parent: Instance, pos: Vector3, diameter: number, width: number, hubColor: Color3?)
	Build.cyl(parent, "Wheel", width, diameter, Build.orient(pos, X), TYRE)
	local side = if pos.X >= 0 then 1 else -1
	Build.cyl(
		parent,
		"Hub",
		0.08,
		diameter * 0.5,
		Build.orient(pos + V(side * width / 2, 0, 0), X),
		hubColor or HUB,
		METAL
	)
end

-- Crawler track along Z at x, bottom on the ground.
local function track(parent: Instance, x: number, length: number, height: number, width: number)
	local y = height / 2
	Build.part(parent, "Track", V(width, height, length - height), CF(x, y, 0), TYRE)
	for _, z in { -(length - height) / 2, (length - height) / 2 } do
		Build.cyl(parent, "Track", width, height, Build.orient(V(x, y, z), X), TYRE)
	end
	local side = if x >= 0 then 1 else -1
	local n = math.max(2, math.floor(length / 1.1))
	for i = 0, n - 1 do
		local z = -(length - height) / 2 + (length - height) * i / (n - 1)
		Build.cyl(parent, "Roller", 0.06, height * 0.55, Build.orient(V(x + side * width / 2, y, z), X), STEEL, METAL)
	end
end

-- Cab box with windows on front and sides and a pair of cartoon eyes on the windshield.
local function cab(parent: Instance, centre: Vector3, size: Vector3, color: Color3, eyes: boolean?)
	Build.part(parent, "Cab", size, CF(centre), color)
	Build.part(parent, "Roof", V(size.X + 0.2, 0.18, size.Z + 0.2), CF(centre + V(0, size.Y / 2 + 0.09, 0)), color)
	local wy = centre.Y + size.Y * 0.12
	local frontZ = centre.Z - size.Z / 2
	Build.part(parent, "Window", V(size.X * 0.8, size.Y * 0.5, 0.06), CF(centre.X, wy, frontZ - 0.02), WINDOW, GLASS)
	for side = -1, 1, 2 do
		Build.part(
			parent,
			"Window",
			V(0.06, size.Y * 0.5, size.Z * 0.7),
			CF(centre.X + side * (size.X / 2 + 0.02), wy, centre.Z),
			WINDOW,
			GLASS
		)
	end
	if eyes ~= false then
		Build.face(parent, CF(centre.X, wy, frontZ - 0.06), math.min(size.X, size.Y) * 0.75, {
			mouth = false,
			cheeks = false,
		})
	end
end

-- Spiral-looking drill bit along the Y axis of `base` (base of the bit at its origin).
local function drillBit(
	parent: Instance,
	base: CFrame,
	length: number,
	diameter: number,
	c1: Color3,
	c2: Color3,
	mat: Enum.Material?
)
	local steps = 4
	local seg = length * 0.75 / steps
	for i = 0, steps - 1 do
		local d = diameter * (1 - i / (steps + 0.6))
		Build.cyl(
			parent,
			"Drill",
			seg,
			d,
			base * CF(0, seg * (i + 0.5), 0) * CFrame.Angles(0, i * 0.6, 0),
			if i % 2 == 0 then c1 else c2,
			if i % 2 == 0 then METAL else mat
		)
	end
	local tipBase = (base * CF(0, length * 0.75, 0)).Position
	local tip = (base * CF(0, length, 0)).Position
	Build.spike(parent, "DrillTip", tipBase, tip, diameter * (1 - steps / (steps + 0.6)) * 1.1, c1, METAL)
end

local function exhaust(parent: Instance, pos: Vector3, height: number)
	Build.cyl(parent, "Exhaust", height, 0.22, CF(pos + V(0, height / 2, 0)), Color3.fromRGB(70, 70, 80), METAL)
	Build.cyl(parent, "Exhaust", 0.08, 0.3, CF(pos + V(0, height, 0)), Color3.fromRGB(40, 40, 45), METAL)
end

local function beacon(parent: Instance, pos: Vector3)
	Build.ball(parent, "Beacon", 0.32, CF(pos), Color3.fromRGB(255, 160, 30), NEON)
end

-- Kinds -------------------------------------------------------------------------------------

kinds.ToyTruck = function(c)
	local m, B, A = c.m, c.B, c.A
	local body = Build.part(m, "Body", V(1.9, 0.5, 3.2), CF(0, 0.75, 0), B)
	for _, z in { -1.05, 1.05 } do
		for side = -1, 1, 2 do
			wheel(m, V(side * 1.0, 0.45, z), 0.9, 0.36)
		end
	end
	cab(m, V(0, 1.45, -0.95), V(1.6, 1.0, 1.1), A)
	Build.part(m, "Bumper", V(1.9, 0.25, 0.2), CF(0, 0.65, -1.65), Color3.fromRGB(255, 255, 255))
	-- tipping bed with a pile of sand, hinge at the rear bottom edge
	local bed = joint(m, "Bed", CF(0, 1.0, 1.55), "Tip", 0.55)
	Build.part(bed, "Bed", V(1.8, 0.12, 1.9), CF(0, 1.06, 0.6), A)
	for side = -1, 1, 2 do
		Build.part(bed, "Bed", V(0.12, 0.55, 1.9), CF(side * 0.84, 1.33, 0.6), A)
	end
	Build.part(bed, "Bed", V(1.8, 0.55, 0.12), CF(0, 1.33, -0.29), A)
	Build.part(bed, "Bed", V(1.8, 0.55, 0.12), CF(0, 1.33, 1.49), A)
	Build.ellipsoid(bed, "Sand", V(1.5, 0.7, 1.5), CF(0, 1.3, 0.6), SAND, Enum.Material.Sand)
	return body
end

kinds.DumpTruck = function(c)
	local m, B, A = c.m, c.B, c.A
	local body = Build.part(m, "Body", V(2.3, 0.55, 4.4), CF(0, 0.95, 0), A)
	for _, z in { -1.5, 0.8, 1.6 } do
		for side = -1, 1, 2 do
			wheel(m, V(side * 1.15, 0.6, z), 1.2, 0.45)
		end
	end
	Build.part(m, "Hood", V(2.1, 0.8, 0.9), CF(0, 1.6, -1.75), B)
	Build.part(m, "Grille", V(1.6, 0.5, 0.06), CF(0, 1.55, -2.22), Color3.fromRGB(60, 60, 70), METAL)
	cab(m, V(0, 2.25, -0.95), V(2.0, 1.2, 1.0), B)
	beacon(m, V(0, 2.98, -0.95))
	local bed = joint(m, "Bed", CF(0, 1.25, 2.15), "Tip", 0.6)
	Build.part(bed, "Bed", V(2.3, 0.16, 2.6), CF(0, 1.33, 0.85), B)
	for side = -1, 1, 2 do
		Build.part(bed, "Bed", V(0.16, 0.95, 2.6), CF(side * 1.07, 1.85, 0.85), B)
	end
	Build.part(bed, "Bed", V(2.3, 1.15, 0.16), CF(0, 1.95, -0.37), B)
	Build.wedge(bed, "Bed", V(2.3, 0.4, 0.6), CF(0, 2.7, -0.6) * CFrame.Angles(0, math.pi, 0), B)
	Build.part(bed, "Bed", V(2.3, 0.85, 0.12), CF(0, 1.8, 2.09), Build.darken(B, 0.15))
	Build.ellipsoid(bed, "Sand", V(1.9, 0.9, 2.2), CF(0, 2.15, 0.85), SAND, Enum.Material.Sand)
	return body
end

kinds.Excavator = function(c)
	local m, B, A = c.m, c.B, c.A
	for side = -1, 1, 2 do
		track(m, side * 0.95, 3.4, 0.75, 0.6)
	end
	Build.part(m, "Turntable", V(1.4, 0.2, 1.4), CF(0, 0.85, 0.1), A, METAL)
	local body = Build.part(m, "Body", V(2.2, 0.9, 2.4), CF(0, 1.4, 0.35), B)
	Build.part(m, "Counterweight", V(2.2, 0.7, 0.5), CF(0, 1.3, 1.65), A)
	cab(m, V(-0.5, 2.35, -0.25), V(1.1, 1.1, 1.1), B)
	exhaust(m, V(0.7, 1.85, 1.0), 0.6)
	-- boom + stick + bucket swing about the boom foot
	local arm = joint(m, "Arm", CF(0.45, 1.7, -0.75), "Swing", -0.5)
	local foot = V(0.45, 1.7, -0.75)
	local elbow = V(0.45, 3.1, -2.1)
	local wrist = V(0.45, 1.3, -3.0)
	Build.beam(arm, "Boom", foot, elbow, 0.45, 0.4, B, SMOOTH, X)
	Build.beam(arm, "Stick", elbow, wrist, 0.35, 0.32, B, SMOOTH, X)
	Build.cylBetween(arm, "Piston", foot + V(0, 0.3, 0.1), elbow + V(0, -0.4, 0.35), 0.16, STEEL, METAL)
	Build.ball(arm, "Elbow", 0.45, CF(elbow), A, METAL)
	local bucket = CF(wrist) * CFrame.Angles(-0.5, 0, 0)
	Build.part(arm, "Bucket", V(0.9, 0.12, 0.8), bucket * CF(0, -0.35, -0.1), A, METAL)
	Build.part(arm, "Bucket", V(0.9, 0.7, 0.12), bucket * CF(0, 0, 0.3), A, METAL)
	for side = -1, 1, 2 do
		Build.part(arm, "Bucket", V(0.1, 0.7, 0.8), bucket * CF(side * 0.45, 0, -0.1), A, METAL)
	end
	for i = -1, 1 do
		Build.spike(
			arm,
			"Tooth",
			(bucket * CF(i * 0.28, -0.4, -0.45)).Position,
			(bucket * CF(i * 0.28, -0.45, -0.75)).Position,
			0.14,
			STEEL,
			METAL
		)
	end
	return body
end

kinds.SkidSteer = function(c)
	local m, B, A = c.m, c.B, c.A
	local body = Build.part(m, "Body", V(1.9, 1.0, 2.4), CF(0, 1.0, 0.3), B)
	for _, z in { -0.55, 1.05 } do
		for side = -1, 1, 2 do
			wheel(m, V(side * 1.1, 0.55, z), 1.1, 0.42)
		end
	end
	cab(m, V(0, 2.1, 0.15), V(1.4, 1.2, 1.3), A)
	Build.part(m, "Engine", V(1.7, 0.5, 0.7), CF(0, 1.75, 1.2), B)
	exhaust(m, V(0.55, 2.0, 1.3), 0.45)
	-- lift arms + bucket pivot behind the cab
	local hinge = V(0, 2.3, 1.1)
	local arm = joint(m, "Arm", CF(hinge), "Swing", -0.35)
	for side = -1, 1, 2 do
		Build.beam(arm, "LiftArm", V(side * 0.95, 2.3, 1.1), V(side * 0.95, 0.85, -1.15), 0.18, 0.3, B, SMOOTH, Z)
	end
	local bucket = CF(0, 0.6, -1.45)
	Build.part(arm, "Bucket", V(2.1, 0.12, 0.8), bucket * CF(0, -0.3, 0), STEEL, METAL)
	Build.part(arm, "Bucket", V(2.1, 0.8, 0.12), bucket * CF(0, 0.05, 0.4), STEEL, METAL)
	for side = -1, 1, 2 do
		Build.part(arm, "Bucket", V(0.1, 0.6, 0.8), bucket * CF(side * 1.05, -0.05, 0), STEEL, METAL)
	end
	Build.ellipsoid(arm, "Sand", V(1.6, 0.45, 0.6), bucket * CF(0, -0.15, 0.05), SAND, Enum.Material.Sand)
	return body
end

kinds.Bulldozer = function(c)
	local m, B, A = c.m, c.B, c.A
	for side = -1, 1, 2 do
		track(m, side * 1.05, 3.8, 0.9, 0.7)
	end
	local body = Build.part(m, "Body", V(1.7, 1.1, 3.0), CF(0, 1.45, 0.2), B)
	Build.part(m, "Hood", V(1.5, 0.35, 1.5), CF(0, 2.15, -0.55), B)
	cab(m, V(0, 2.6, 0.95), V(1.6, 1.2, 1.2), B)
	exhaust(m, V(0.5, 2.3, -0.9), 0.7)
	beacon(m, V(0.55, 3.35, 1.3))
	-- blade on push arms, hinged at the track middle
	local blade = joint(m, "Blade", CF(0, 0.9, 0.2), "Swing", -0.22)
	for side = -1, 1, 2 do
		Build.beam(blade, "PushArm", V(side * 1.5, 0.9, 0.2), V(side * 1.5, 0.75, -2.1), 0.18, 0.28, A, SMOOTH, Z)
	end
	Build.part(blade, "Blade", V(3.4, 1.3, 0.22), CF(0, 0.95, -2.25) * CFrame.Angles(0.15, 0, 0), B)
	Build.part(blade, "BladeEdge", V(3.4, 0.16, 0.3), CF(0, 0.22, -2.35), STEEL, METAL)
	for side = -1, 1, 2 do
		Build.part(blade, "BladeSide", V(0.12, 1.2, 0.5), CF(side * 1.7, 0.95, -2.1), B)
	end
	-- rear ripper
	Build.beam(m, "Ripper", V(0, 1.2, 1.8), V(0, 0.35, 2.3), 0.22, 0.22, A, METAL, X)
	return body
end

kinds.Backhoe = function(c)
	local m, B, A = c.m, c.B, c.A
	local body = Build.part(m, "Body", V(1.9, 0.8, 3.6), CF(0, 1.15, 0), B)
	wheel(m, V(-1.05, 0.55, -1.1), 1.1, 0.45)
	wheel(m, V(1.05, 0.55, -1.1), 1.1, 0.45)
	wheel(m, V(-1.05, 0.8, 1.0), 1.6, 0.5)
	wheel(m, V(1.05, 0.8, 1.0), 1.6, 0.5)
	Build.part(m, "Hood", V(1.5, 0.6, 1.3), CF(0, 1.85, -1.1), B)
	cab(m, V(0, 2.35, 0.55), V(1.7, 1.4, 1.4), B)
	exhaust(m, V(0.5, 2.15, -1.3), 0.6)
	beacon(m, V(0, 3.2, 0.55))
	-- front loader
	local loader = joint(m, "Loader", CF(0, 1.9, -0.3), "Swing", 0.3)
	for side = -1, 1, 2 do
		Build.beam(loader, "LoaderArm", V(side * 1.0, 1.9, -0.3), V(side * 1.0, 0.75, -2.3), 0.16, 0.26, A, SMOOTH, Z)
	end
	Build.part(loader, "Loader", V(2.2, 0.75, 0.14), CF(0, 0.75, -2.5), STEEL, METAL)
	Build.part(loader, "Loader", V(2.2, 0.12, 0.6), CF(0, 0.4, -2.3), STEEL, METAL)
	-- rear arm (the "hoe")
	local arm = joint(m, "Arm", CF(0, 1.5, 1.85), "Swing", 0.45)
	local foot = V(0, 1.5, 1.85)
	local elbow = V(0, 2.9, 2.9)
	local wrist = V(0, 1.0, 3.5)
	Build.beam(arm, "Boom", foot, elbow, 0.35, 0.32, A, SMOOTH, X)
	Build.beam(arm, "Stick", elbow, wrist, 0.3, 0.28, A, SMOOTH, X)
	Build.ball(arm, "Elbow", 0.4, CF(elbow), B, METAL)
	local bucket = CF(wrist) * CFrame.Angles(0.5, math.pi, 0)
	Build.part(arm, "Bucket", V(0.7, 0.1, 0.6), bucket * CF(0, -0.3, -0.1), STEEL, METAL)
	Build.part(arm, "Bucket", V(0.7, 0.6, 0.1), bucket * CF(0, 0, 0.2), STEEL, METAL)
	for side = -1, 1, 2 do
		Build.part(arm, "Bucket", V(0.08, 0.6, 0.6), bucket * CF(side * 0.35, 0, -0.1), STEEL, METAL)
	end
	return body
end

kinds.DrillRig = function(c)
	local m, B, A = c.m, c.B, c.A
	local body = Build.part(m, "Body", V(2.1, 0.6, 3.8), CF(0, 0.95, 0.2), Color3.fromRGB(70, 70, 80))
	for _, z in { -1.2, 0.6, 1.5 } do
		for side = -1, 1, 2 do
			wheel(m, V(side * 1.1, 0.6, z), 1.2, 0.45)
		end
	end
	cab(m, V(0, 1.9, 1.3), V(1.9, 1.3, 1.2), B)
	-- mast
	for side = -1, 1, 2 do
		Build.part(m, "Mast", V(0.18, 4.6, 0.18), CF(side * 0.45, 3.4, -1.5), A, METAL)
	end
	for i = 0, 5 do
		Build.part(m, "Rung", V(0.9, 0.1, 0.1), CF(0, 1.5 + i * 0.75, -1.5), A, METAL)
	end
	Build.part(m, "MastTop", V(1.2, 0.35, 0.6), CF(0, 5.8, -1.5), B)
	beacon(m, V(0, 6.1, -1.5))
	Build.part(m, "Motor", V(0.8, 0.7, 0.7), CF(0, 2.35, -1.5), B)
	local drill = joint(m, "Drill", CFrame.fromMatrix(V(0, 1.95, -1.5), X, -Y), "Drill", 14)
	drill:SetAttribute("Plunge", 0.8)
	Build.cyl(drill, "Shaft", 1.0, 0.25, CF(0, 1.5, -1.5), STEEL, METAL)
	drillBit(drill, CFrame.fromMatrix(V(0, 1.15, -1.5), X, -Y), 1.1, 0.7, STEEL, B)
	return body
end

kinds.MiningDrill = function(c)
	local m, B, A, am = c.m, c.B, c.A, c.am
	-- mine cart body with metal bands on little rail wheels
	local body = Build.part(m, "Body", V(2.0, 1.3, 2.8), CF(0, 1.2, 0.4), B, Enum.Material.WoodPlanks)
	for _, z in { -0.6, 0.4, 1.4 } do
		Build.part(m, "Band", V(2.08, 1.36, 0.14), CF(0, 1.2, z), STEEL, METAL)
	end
	Build.part(m, "Rim", V(2.1, 0.14, 2.9), CF(0, 1.9, 0.4), STEEL, METAL)
	Build.ellipsoid(m, "Ore", V(1.6, 0.8, 2.2), CF(0, 1.9, 0.5), Color3.fromRGB(120, 110, 105), Enum.Material.Slate)
	for _, p in { V(-0.4, 2.2, 0.2), V(0.45, 2.15, 0.9), V(0.1, 2.25, -0.2) } do
		Build.ball(m, "Gem", 0.35, CF(p), A, am)
	end
	for _, z in { -0.5, 1.3 } do
		for side = -1, 1, 2 do
			wheel(m, V(side * 0.85, 0.35, z), 0.7, 0.25, A)
		end
	end
	Build.part(m, "Nose", V(1.6, 1.1, 0.5), CF(0, 1.15, -1.2), STEEL, METAL)
	beacon(m, V(0.7, 2.05, -0.9))
	-- forward drill tilted slightly down
	local axis = V(0, -0.25, -1).Unit
	local drill = joint(m, "Drill", Build.orient(V(0, 1.1, -1.45), axis, X), "Spin", 12)
	drillBit(drill, Build.orient(V(0, 1.1, -1.45), axis, X), 1.6, 1.0, STEEL, A, am)
	return body
end

kinds.TunnelBorer = function(c)
	local m, B, A, am = c.m, c.B, c.A, c.am
	for side = -1, 1, 2 do
		track(m, side * 1.0, 3.6, 0.7, 0.55)
	end
	local body = Build.cyl(m, "Body", 3.4, 2.3, Build.orient(V(0, 1.85, 0.3), Z), B)
	for _, z in { -0.6, 0.6, 1.6 } do
		Build.cyl(m, "Ring", 0.18, 2.45, Build.orient(V(0, 1.85, z), Z), A, am)
	end
	Build.part(m, "Hatch", V(0.9, 0.3, 1.0), CF(0, 3.05, 0.8), Build.darken(B, 0.2))
	beacon(m, V(0, 3.3, 0.8))
	-- round cutter face spinning about the body axis
	local face = Build.orient(V(0, 1.85, -1.5), -Z, X)
	local cutter = joint(m, "Cutter", face, "Spin", 6)
	Build.cyl(cutter, "Cutter", 0.3, 2.6, face, STEEL, METAL)
	Build.cyl(cutter, "Cutter", 0.2, 0.7, face * CF(0, 0.22, 0), A, am)
	for k = 0, 5 do
		local a = k * math.pi / 3
		local dir = (face * CFrame.Angles(0, a, 0)).RightVector
		local base = face.Position + dir * 0.9 - Z * 0.15
		Build.spike(cutter, "Tooth", base, base - Z * 0.45, 0.3, STEEL, METAL)
		Build.beam(cutter, "Spoke", face.Position - Z * 0.17, face.Position + dir * 1.2 - Z * 0.17, 0.18, 0.1, A, am, Z)
	end
	return body
end

kinds.Mole = function(c)
	local m, B, A, am = c.m, c.B, c.A, c.am
	for side = -1, 1, 2 do
		track(m, side * 0.9, 3.2, 0.6, 0.5)
	end
	local body = Build.ellipsoid(m, "Body", V(2.4, 2.0, 3.4), CF(0, 1.6, 0.3), B, METAL)
	Build.ellipsoid(m, "Belly", V(1.8, 1.2, 2.4), CF(0, 1.3, -0.1), Build.lighten(B, 0.25))
	Build.ellipsoid(m, "Head", V(1.6, 1.4, 1.5), CF(0, 1.8, -1.2), B, METAL)
	Build.ball(m, "Nose", 0.45, CF(0, 1.7, -1.98), Color3.fromRGB(255, 130, 170))
	Build.face(m, CF(0, 2.05, -1.86), 0.9, { mouth = false, radius = 0.75 })
	-- Keep the visor above the eye spheres and their highlights; a matte brow avoids neon bloom.
	Build.part(m, "Visor", V(1.2, 0.18, 0.4), CF(0, 2.44, -1.7), Build.darken(A, 0.12), SMOOTH)
	Build.cylBetween(m, "Antenna", V(0.3, 2.5, 0.2), V(0.45, 3.3, 0.4), 0.08, STEEL, METAL)
	Build.ball(m, "AntennaTip", 0.25, CF(0.45, 3.35, 0.4), A, am)
	for side = -1, 1, 2 do
		Build.ellipsoid(m, "Ear", V(0.5, 0.5, 0.2), CF(side * 0.6, 2.5, -1.0), B)
		local axis = V(side * 0.2, -0.3, -1).Unit
		local base = Build.orient(V(side * 1.05, 1.2, -1.3), axis, X)
		local drill = joint(m, "Drill", base, "Spin", 14)
		Build.cyl(drill, "Shoulder", 0.3, 0.6, base, A, am)
		drillBit(drill, base, 1.2, 0.6, STEEL, A, am)
	end
	return body
end

kinds.LavaDrill = function(c)
	local m, B, A, am = c.m, c.B, c.A, c.am
	for side = -1, 1, 2 do
		track(m, side * 1.15, 4.0, 0.9, 0.7)
	end
	local body = Build.part(m, "Body", V(2.0, 1.3, 3.2), CF(0, 1.55, 0.5), B, Enum.Material.Basalt)
	for _, z in { -0.4, 0.5, 1.4 } do
		Build.part(m, "LavaStripe", V(2.06, 0.18, 0.2), CF(0, 1.7, z), A, am)
	end
	Build.part(m, "Tank", V(1.4, 0.9, 1.2), CF(0, 2.6, 1.4), Build.darken(B, 0.2), Enum.Material.CrackedLava)
	cab(m, V(0, 2.75, 0.0), V(1.6, 1.1, 1.1), B)
	exhaust(m, V(-0.6, 2.2, 1.9), 1.0)
	exhaust(m, V(0.6, 2.2, 1.9), 1.0)
	-- frame holding a big downward-angled drill at the front
	for side = -1, 1, 2 do
		Build.beam(m, "Frame", V(side * 0.7, 2.0, -1.0), V(side * 0.7, 2.6, -2.0), 0.22, 0.22, A, am, X)
	end
	Build.part(m, "DrillHead", V(1.6, 0.8, 0.8), CF(0, 2.5, -2.1), B, METAL)
	local base = Build.orient(V(0, 2.1, -2.3), V(0, -1, -0.45).Unit, X)
	local drill = joint(m, "Drill", base, "Drill", 16)
	drill:SetAttribute("Plunge", 0.5)
	drillBit(drill, base, 2.1, 1.1, Color3.fromRGB(90, 80, 80), A, am)
	return body
end

kinds.CoreDriller = function(c)
	local m, B, A, am = c.m, c.B, c.A, c.am
	for side = -1, 1, 2 do
		track(m, side * 1.25, 4.4, 1.0, 0.75)
	end
	local body = Build.part(m, "Body", V(2.2, 1.4, 3.4), CF(0, 1.7, 0.6), B, METAL)
	for side = -1, 1, 2 do
		Build.wedge(m, "Fin", V(0.15, 0.9, 1.4), CF(side * 1.12, 2.8, 1.8), A, am)
	end
	cab(m, V(0, 3.0, 0.4), V(1.7, 1.2, 1.3), B)
	Build.ball(m, "Orb", 0.7, CF(0, 3.9, 1.4), A, am)
	for side = -1, 1, 2 do
		Build.beam(m, "Frame", V(side * 0.8, 2.0, -0.9), V(side * 0.8, 2.6, -2.2), 0.25, 0.25, B, METAL, X)
	end
	Build.cyl(m, "DrillHousing", 0.9, 1.6, Build.orient(V(0, 2.4, -2.2), V(0, -1, -0.5).Unit, X), B, METAL)
	local base = Build.orient(V(0, 2.0, -2.45), V(0, -1, -0.5).Unit, X)
	local drill = joint(m, "Drill", base, "Drill", 18)
	drill:SetAttribute("Plunge", 0.6)
	drillBit(drill, base, 2.4, 1.3, B, A, am)
	for k = 1, 3 do
		Build.cyl(drill, "DrillRing", 0.12, 1.3 * (1 - k * 0.2) + 0.15, base * CF(0, 0.45 * k, 0), A, am)
	end
	return body
end

export type VehicleLook = {
	Kind: string,
	Body: Color3,
	Accent: Color3,
	Glow: boolean,
}

local FALLBACK_LOOK: VehicleLook =
	{ Kind = "ToyTruck", Body = Color3.fromRGB(255, 210, 50), Accent = Color3.fromRGB(240, 70, 70), Glow = false }

-- Builder -----------------------------------------------------------------------------------

function Diggers.FromLook(name: string, look: VehicleLook, scale: number?): Model
	local kind = look.Kind
	local glow = look.Glow == true
	local s = math.clamp(scale or 1, 0.2, 5)

	local m = Build.model(name)
	m:SetAttribute("Kind", kind)
	m:SetAttribute("Scale", s)
	local root = Build.root(m, CFrame.identity, V(1, 0.1, 1))
	local ctx: Ctx = { m = m, B = look.Body, A = look.Accent, am = if glow then NEON else SMOOTH, glow = glow }
	local builder = kinds[kind] or kinds.ToyTruck
	local main = builder(ctx)
	if glow then
		Build.glow(main, look.Accent, 1, 9)
		Build.sparkle(main, look.Accent, 2)
	end
	if math.abs(s - 1) > 1e-4 then
		Build.scale(m, CFrame.identity, s)
		for _, d in m:GetDescendants() do
			if d:IsA("Model") and typeof(d:GetAttribute("Plunge")) == "number" then
				d:SetAttribute("Plunge", (d:GetAttribute("Plunge") :: number) * s)
			end
		end
	end

	-- Weld static parts only: hinge assemblies are re-posed by the client every frame.
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= root and d:FindFirstAncestorWhichIsA("Model") == m then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
		end
	end
	return m
end

-- `id` = a vehicle pet id (Config.GetPet(id).VehicleKind, colours from its Look), or a Kind name.
function Diggers.Build(id: string, scale: number?): Model
	local pet = Config.GetPet(id)
	local look: VehicleLook = FALLBACK_LOOK
	if pet and pet.VehicleKind then
		look = {
			Kind = pet.VehicleKind :: string,
			Body = pet.Look.BodyColor,
			Accent = pet.Look.AccentColor,
			Glow = pet.Look.Glow,
		}
	elseif kinds[id] then
		look = { Kind = id, Body = FALLBACK_LOOK.Body, Accent = FALLBACK_LOOK.Accent, Glow = false }
	end
	return Diggers.FromLook(id, look, scale)
end

-- Ids with a dedicated builder (QA / tests).
function Diggers.Kinds(): { string }
	local list = {}
	for kind in kinds do
		table.insert(list, kind)
	end
	table.sort(list)
	return list
end

return Diggers
