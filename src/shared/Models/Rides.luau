--!strict
--[[
	Rides — the full-size ride-on vehicle for rideable pets (v2.1, Ride agent). Built from
	primitives only (Build.luau style, no asset ids). Currently every rideable pet is drawn as a
	big cartoon excavator (~18 studs nose to tail, tracks 12 long, roof ~10.6 high); VehicleKind
	other than "Excavator" falls back to it.

	Conventions (differ from the other builders because this model is DRIVEN by physics):
	- Front is -Z, up is +Y. PrimaryPart = invisible "Root" at the bottom-centre (pivot on the
	  ground under the tracks). Returned unparented with every part Anchored; RideService
	  unanchors it, so everything is joined: static parts WeldConstraint'ed to Root, moving
	  parts welded to their hinge, hinges joined by Motor6Ds.
	- "Chassis": the ONLY colliding part, an invisible hull (y 0.9..3.5, 8.9 x 11.6) that carries
	  the mass. It sits ~0.9 above the ground so it never drags on the sand. Every visible part is
	  Massless, CanCollide / CanQuery / CanTouch false.
	- "RideSeat" (Seat): CanTouch false so passers-by never sit down by touching it; RideService
	  seats the owner with Seat:Sit(humanoid).
	- Drive constraints in Root: Attachment "RideAttachment", AlignPosition "RideAlignPosition"
	  and AlignOrientation "RideAlignOrientation" (both OneAttachment). RideService sets the
	  initial targets and force; the rider's client (network owner) moves the targets.
	- Animated digging arm (RideController): Root -> Motor6D "BoomMotor" -> Model "Boom"
	  (PrimaryPart "BoomHinge") -> "StickMotor" -> Model "Stick" ("StickHinge") ->
	  "BucketMotor" -> Model "Bucket" ("BucketHinge"). Animate Motor6D.Transform with rotations
	  about the hinge's X axis (positive = raise the front). Part "BucketSand" (Transparency 1)
	  can be shown while the bucket carries a load.
	- Model attributes: "PetId", "VehicleKind".
]]

local Config = require(script.Parent.Parent.Config)
local Build = require(script.Parent.Build)

local Rides = {}

local V = Vector3.new
local CF = CFrame.new
local X = Vector3.xAxis
local SMOOTH = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal
local GLASS = Enum.Material.Glass
local NEON = Enum.Material.Neon

local TYRE = Color3.fromRGB(40, 38, 45)
local STEEL = Color3.fromRGB(150, 155, 165)
local DARK = Color3.fromRGB(60, 60, 70)
local SAND = Color3.fromRGB(240, 205, 130)
local DEFAULT_BODY = Color3.fromRGB(255, 190, 20)
local DEFAULT_ACCENT = Color3.fromRGB(255, 90, 160)

-- Geometry the services / controller rely on (studs, model space).
Rides.HULL_SIZE = V(8.9, 2.6, 11.6)
Rides.HULL_Y = 2.2 -- hull centre height above the pivot
Rides.SEAT_POSITION = V(-1.9, 5.7, 0)
Rides.BUCKET_TIP = V(1.6, 2.0, -11.2) -- bucket teeth at rest

-- Weld every BasePart that is a DIRECT child of `group` to `hinge`.
local function weldGroup(group: Instance, hinge: BasePart)
	for _, child in group:GetChildren() do
		if child:IsA("BasePart") and child ~= hinge then
			local w = Instance.new("WeldConstraint")
			w.Part0 = hinge
			w.Part1 = child
			w.Parent = child
		end
	end
end

-- Moving sub-assembly: Model `name` with an invisible hinge part as PrimaryPart.
local function group(parent: Instance, name: string, hinge: CFrame): (Model, Part)
	local g = Instance.new("Model")
	g.Name = name
	local h = Build.part(g, name .. "Hinge", V(0.4, 0.4, 0.4), hinge, Color3.new(1, 1, 1))
	h.Transparency = 1
	h.CastShadow = false
	g.PrimaryPart = h
	g.Parent = parent
	return g, h
end

local function motor(name: string, part0: BasePart, part1: BasePart): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
	m.C1 = CFrame.identity
	m.Parent = part1
	return m
end

local function track(parent: Instance, x: number)
	local length, height, width = 12, 2.2, 1.9
	local y = height / 2
	local inner = length - height
	Build.part(parent, "Track", V(width, height, inner), CF(x, y, 0), TYRE)
	for _, z in { -inner / 2, inner / 2 } do
		Build.cyl(parent, "Track", width, height, Build.orient(V(x, y, z), X), TYRE)
	end
	local side = if x >= 0 then 1 else -1
	-- road wheels on the outside + cleats on top
	for i = 0, 4 do
		local z = -inner / 2 + inner * i / 4
		Build.cyl(parent, "Roller", 0.12, 1.3, Build.orient(V(x + side * (width / 2 + 0.04), y, z), X), STEEL, METAL)
	end
	for i = 0, 6 do
		local z = -inner / 2 + inner * i / 6
		Build.part(parent, "Cleat", V(width + 0.06, 0.18, 0.4), CF(x, height + 0.05, z), DARK)
	end
end

local function build(m: Model, root: BasePart, body: Color3, accent: Color3, glow: boolean)
	-- Collision hull (the only colliding part; carries the mass)
	local hull = Build.part(m, "Chassis", Rides.HULL_SIZE, CF(0, Rides.HULL_Y, 0), body)
	hull.Transparency = 1
	hull.CanCollide = true
	hull.CastShadow = false
	hull.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0, 1, 1)

	-- Undercarriage
	for side = -1, 1, 2 do
		track(m, side * 3.5)
	end
	Build.part(m, "Frame", V(5, 1.2, 9), CF(0, 1.6, 0), DARK)
	Build.cyl(m, "Turntable", 0.4, 5, CF(0, 2.4, 0.4), STEEL, METAL)

	-- House: body, accent stripe, counterweight, engine
	local house = Build.part(m, "Body", V(7.2, 2.8, 7.4), CF(0, 4.0, 1.2), body)
	Build.part(m, "Stripe", V(7.3, 0.4, 7.5), CF(0, 4.7, 1.2), accent, if glow then NEON else SMOOTH)
	Build.part(m, "Counterweight", V(7.2, 2.2, 1.4), CF(0, 3.9, 5.6), Build.darken(body, 0.25))
	Build.part(m, "EngineGrille", V(0.1, 1.2, 2.6), CF(3.62, 4.0, 3.2), DARK, METAL)
	Build.cyl(m, "Exhaust", 2.4, 0.45, CF(2.6, 6.6, 4.2), DARK, METAL)
	Build.cyl(m, "Exhaust", 0.2, 0.6, CF(2.6, 7.8, 4.2), Color3.fromRGB(35, 35, 40), METAL)
	Build.face(m, CF(-1.9, 3.9, -2.52) * CFrame.Angles(0, 0, 0), 2.4, { radius = 0 })

	-- Open cab (canopy on four posts) so the rider stays visible
	Build.part(m, "CabFloor", V(3.4, 0.2, 3.8), CF(-1.9, 5.5, -0.5), Build.darken(body, 0.15))
	for _, x in { -3.45, -0.35 } do
		for _, z in { -2.25, 1.25 } do
			Build.cyl(m, "CabPost", 4.6, 0.3, CF(x, 7.9, z), DARK, METAL)
		end
	end
	Build.part(m, "CabRoof", V(3.8, 0.4, 4.2), CF(-1.9, 10.4, -0.5), body)
	Build.part(m, "RoofStripe", V(3.85, 0.15, 1.0), CF(-1.9, 10.6, -0.5), accent)
	local windshield =
		Build.part(m, "Windshield", V(3.0, 2.4, 0.12), CF(-1.9, 8.8, -2.3), Color3.fromRGB(150, 220, 255), GLASS)
	windshield.Transparency = 0.65
	local beacon = Build.ball(m, "Beacon", 0.6, CF(-1.9, 10.85, -0.5), Color3.fromRGB(255, 160, 30), NEON)
	if glow then
		Build.glow(beacon, accent, 1.2, 12)
		Build.sparkle(house, accent, 2)
	end
	-- seat + back + levers
	local seat = Instance.new("Seat")
	seat.Name = "RideSeat"
	seat.Size = V(2.2, 0.5, 2.2)
	seat.CFrame = CF(Rides.SEAT_POSITION)
	seat.Color = DARK
	seat.Material = SMOOTH
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Anchored = true
	seat.CanCollide = false
	seat.CanQuery = false
	seat.CanTouch = false -- only Seat:Sit(owner) seats anyone
	seat.Parent = m
	Build.part(m, "SeatBack", V(2.2, 2.0, 0.4), CF(-1.9, 6.9, 1.05), DARK)
	for side = -1, 1, 2 do
		Build.cylBetween(
			m,
			"Lever",
			V(-1.9 + side * 0.7, 5.7, -1.6),
			V(-1.9 + side * 0.7, 7.0, -1.3),
			0.14,
			STEEL,
			METAL
		)
		Build.ball(m, "LeverKnob", 0.32, CF(-1.9 + side * 0.7, 7.05, -1.28), accent)
	end

	-- Digging arm: boom -> stick -> bucket
	local foot = V(1.6, 5.0, -2.2)
	local elbow = V(1.6, 10.0, -7.0)
	local wrist = V(1.6, 4.2, -10.0)
	local boom, boomHinge = group(m, "Boom", CF(foot))
	Build.beam(boom, "BoomBeam", foot, elbow, 1.0, 0.9, body, SMOOTH, X)
	Build.cylBetween(boom, "Piston", foot + V(0, -0.8, -0.4), foot:Lerp(elbow, 0.55) + V(0, -0.6, 0), 0.4, STEEL, METAL)
	Build.ball(boom, "BoomFoot", 1.2, CF(foot), accent, METAL)
	local stick, stickHinge = group(boom, "Stick", CF(elbow))
	Build.beam(stick, "StickBeam", elbow, wrist, 0.8, 0.8, body, SMOOTH, X)
	Build.ball(stick, "Elbow", 1.2, CF(elbow), accent, METAL)
	Build.cylBetween(stick, "Piston", elbow + V(0, 0.6, 0.5), wrist + V(0, 1.6, 0.6), 0.32, STEEL, METAL)
	local bucket, bucketHinge = group(stick, "Bucket", CF(wrist))
	local bk = CF(wrist) * CFrame.Angles(-0.35, 0, 0)
	Build.part(bucket, "BucketBottom", V(2.8, 0.2, 2.0), bk * CF(0, -1.7, -0.9), accent, METAL)
	Build.part(bucket, "BucketBack", V(2.8, 1.9, 0.2), bk * CF(0, -0.8, 0.1), accent, METAL)
	for side = -1, 1, 2 do
		Build.part(bucket, "BucketSide", V(0.2, 1.9, 2.0), bk * CF(side * 1.4, -0.8, -0.9), accent, METAL)
	end
	for i = 0, 3 do
		local x = -1.05 + i * 0.7
		local base = (bk * CF(x, -1.7, -1.85)).Position
		local tip = (bk * CF(x, -1.75, -2.45)).Position
		Build.spike(bucket, "Tooth", base, tip, 0.35, STEEL, METAL)
	end
	Build.ball(bucket, "Wrist", 0.9, CF(wrist), accent, METAL)
	local load =
		Build.ellipsoid(bucket, "BucketSand", V(2.4, 1.0, 1.6), bk * CF(0, -1.2, -0.9), SAND, Enum.Material.Sand)
	load.Transparency = 1

	-- Joints: statics -> Root, groups -> their hinge, hinges -> Motor6D chain
	weldGroup(m, root)
	weldGroup(boom, boomHinge)
	weldGroup(stick, stickHinge)
	weldGroup(bucket, bucketHinge)
	motor("BoomMotor", root, boomHinge)
	motor("StickMotor", boomHinge, stickHinge)
	motor("BucketMotor", stickHinge, bucketHinge)

	-- Only the hull has mass; nothing else collides or blocks raycasts.
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= hull then
			d.Massless = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end

	-- Drive constraints (targets + force set by RideService / RideController)
	local attachment = Instance.new("Attachment")
	attachment.Name = "RideAttachment"
	attachment.Parent = root
	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Name = "RideAlignPosition"
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment
	alignPosition.ApplyAtCenterOfMass = true
	alignPosition.Responsiveness = Config.Ride.Responsiveness
	alignPosition.MaxVelocity = Config.Ride.MaxSpeed * 2
	alignPosition.MaxForce = 1e6
	alignPosition.Parent = root
	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "RideAlignOrientation"
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.Responsiveness = Config.Ride.Responsiveness
	alignOrientation.MaxTorque = 1e9
	alignOrientation.MaxAngularVelocity = 6
	alignOrientation.Parent = root
end

function Rides.Build(petId: string): Model
	local def = Config.GetPet(petId)
	if not def then
		for _, candidate in Config.Pets do
			if candidate.Id == petId then
				def = candidate
				break
			end
		end
	end
	local look = if def then def.Look else nil
	local body = if look then look.BodyColor else DEFAULT_BODY
	local accent = if look then look.AccentColor else DEFAULT_ACCENT
	local glow = if look then look.Glow == true else false
	local kind = if def and def.VehicleKind then def.VehicleKind else "Excavator"

	local m = Build.model("Ride_" .. petId)
	m:SetAttribute("PetId", petId)
	m:SetAttribute("VehicleKind", kind)
	local root = Build.root(m, CFrame.identity, V(1, 0.2, 1))
	build(m, root, body, accent, glow)
	return m
end

return Rides
