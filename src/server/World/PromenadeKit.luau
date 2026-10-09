--!strict
--[[
	PromenadeKit — bespoke builders for the boardwalk, pier and pier-end carnival (Stream B):
	vintage lamps (crook / twin-head / tall flagpole), sagging string lights and bunting on Beam
	wires, benches, planters, bins, lifebuoys, shower posts, signposts, snack carts and swaying
	flags. Everything is world-space and decorative unless a builder says otherwise.

	Conventions:
	- Frames (`cf`) sit on the floor, Y up; a frame's LookVector (-Z) is the item's "front".
	- Parts are anchored and non-colliding (Build.part); small ones cast no shadow. Kit.solid()
	  turns collision back on for things players should bump into or stand on.
	- Neon goes through Build (neonSafe) and is tagged AmbientNightLight. PointLights are
	  capped by Kit.MAX_LIGHTS for the whole stream (Shadows off, Range <= 16).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Models.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(script.Parent.Util)

local C = Config.Theme.Colors
local rgb = Color3.fromRGB
local NEON = Enum.Material.Neon
local DOWN = Vector3.new(0, -1, 0)

local Kit = {}

Kit.WOOD = rgb(176, 122, 76)
Kit.WOOD_DARK = rgb(124, 84, 52)
Kit.WHITE = rgb(250, 246, 236)
Kit.NAVY = rgb(31, 55, 73)
Kit.BRASS = rgb(204, 162, 74)
Kit.IRON = rgb(52, 60, 72)
Kit.WARM = rgb(255, 196, 110)
Kit.GLASS = rgb(255, 238, 200)
Kit.ROPE = rgb(60, 52, 46)

Kit.NIGHT_TAG = "AmbientNightLight"
Kit.MAX_LIGHTS = 18
Kit.MAX_EMITTERS = 6
Kit.Stats = { lights = 0, emitters = 0 }

-- Party colours for bulbs and bunting.
Kit.BULBS = { C.Gold, C.Coral, C.Ocean, C.Palm, C.Sunset, C.Purple }
Kit.FLAGS = { C.Coral, C.Gold, C.Ocean, C.Palm, C.Purple, C.Sunset, Kit.WHITE }

-- Primitives ---------------------------------------------------------------------------------

local function finish(p: BasePart)
	local s = p.Size
	if math.max(s.X, s.Y, s.Z) < 4 then
		p.CastShadow = false
	end
end

function Kit.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Build.part(parent, name, size, cf, color, material)
	finish(p)
	return p
end

function Kit.ball(
	parent: Instance,
	name: string,
	d: number,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Build.ball(parent, name, d, CFrame.new(pos), color, material)
	finish(p)
	return p
end

function Kit.ellipsoid(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Build.ellipsoid(parent, name, size, cf, color, material)
	finish(p)
	return p
end

-- Cylinder whose axis is the Y axis of `cf`.
function Kit.cyl(
	parent: Instance,
	name: string,
	len: number,
	d: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Build.cyl(parent, name, len, d, cf, color, material)
	finish(p)
	return p
end

function Kit.rod(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	d: number,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Build.cylBetween(parent, name, a, b, d, color, material)
	finish(p)
	return p
end

-- Box from a to b (length), `w` along xHint, `t` along the remaining axis.
function Kit.bar(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	w: number,
	t: number,
	color: Color3,
	material: Enum.Material?,
	xHint: Vector3?
): Part
	local p = Build.beam(parent, name, a, b, w, t, color, material, xHint)
	finish(p)
	return p
end

function Kit.wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local p = Build.wedge(parent, name, size, cf, color, material)
	finish(p)
	return p
end

-- Isosceles triangle from base-centre to apex, width along widthDir (two wedges).
function Kit.tri(
	parent: Instance,
	name: string,
	base: Vector3,
	apex: Vector3,
	widthDir: Vector3,
	w: number,
	t: number,
	color: Color3,
	material: Enum.Material?
)
	local d = apex - base
	local a, b =
		Build.tri(parent, name, Build.orient(base:Lerp(apex, 0.5), d, widthDir), w, d.Magnitude, t, color, material)
	finish(a)
	finish(b)
end

-- Players bump into / stand on this part.
function Kit.solid(p: BasePart): BasePart
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = false
	return p
end

function Kit.model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Kit.tag(inst: Instance, tag: string)
	CollectionService:AddTag(inst, tag)
end

-- Motion-tagged model (client ambient controller): streamed atomically, never collidable.
function Kit.motion(m: Model, tag: string)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	Kit.tag(m, tag)
end

-- Neon bulb tagged for the night-light controller.
function Kit.bulb(parent: Instance, name: string, d: number, pos: Vector3, color: Color3, tag: boolean?): Part
	local b = Kit.ball(parent, name, d, pos, color, NEON)
	if tag ~= false then
		Kit.tag(b, Kit.NIGHT_TAG)
	end
	return b
end

-- Neon box/strip tagged for the night-light controller.
function Kit.neon(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Kit.part(parent, name, size, cf, color, NEON)
	Kit.tag(p, Kit.NIGHT_TAG)
	return p
end

-- PointLight within the stream budget (nil once the budget is spent).
function Kit.light(part: BasePart, color: Color3, range: number?, brightness: number?): PointLight?
	if Kit.Stats.lights >= Kit.MAX_LIGHTS then
		return nil
	end
	Kit.Stats.lights += 1
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = math.min(range or 14, 16)
	l.Brightness = brightness or 1.2
	l.Shadows = false
	l.Parent = part
	Kit.tag(l, Kit.NIGHT_TAG)
	return l
end

function Kit.sparkle(part: BasePart, color: Color3, rate: number?): ParticleEmitter?
	if Kit.Stats.emitters >= Kit.MAX_EMITTERS then
		return nil
	end
	Kit.Stats.emitters += 1
	return Build.sparkle(part, color, rate)
end

-- Text on a part face (both faces when `back` is given).
function Kit.label(part: BasePart, face: Enum.NormalId, text: string, color: Color3?, font: Enum.Font?): TextLabel
	local gui = Util.SurfaceGui(part, face)
	gui.Name = "SignGui" .. face.Name
	return Util.Label(gui, text, color or C.Text, UDim2.fromScale(0.05, 0.08), UDim2.fromScale(0.9, 0.84), font)
end

-- Catenary wires (Beam with CurveSize) ------------------------------------------------------

-- Attachment on `part` at world `pos` whose axis (X) points straight down.
local function downAttachment(part: BasePart, pos: Vector3, name: string): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = part.CFrame:ToObjectSpace(CFrame.fromMatrix(pos, DOWN, Vector3.xAxis))
	a.Parent = part
	return a
end

export type Curve = (t: number) -> Vector3

-- Sagging wire from a (on anchorA) to b (on anchorB); `sag` = drop at the midpoint.
-- Returns the wire's curve so bulbs / pennants can sit exactly on it.
function Kit.wire(
	anchorA: BasePart,
	a: Vector3,
	anchorB: BasePart,
	b: Vector3,
	sag: number,
	color: Color3,
	width: number?
): Curve
	local s = sag / 0.75 -- cubic Bezier midpoint drop = 0.75 * control offset
	local a0 = downAttachment(anchorA, a, "WireA")
	local a1 = downAttachment(anchorB, b, "WireB")
	local beam = Instance.new("Beam")
	beam.Name = "Wire"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.CurveSize0 = s
	beam.CurveSize1 = -s
	beam.Width0 = width or 0.12
	beam.Width1 = width or 0.12
	beam.Segments = 20
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new(0)
	beam.LightInfluence = 1
	beam.Parent = anchorA
	local p1, p2 = a + DOWN * s, b + DOWN * s
	return function(t: number): Vector3
		local u = 1 - t
		return a * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + b * (t * t * t)
	end
end

export type StringOpts = {
	spacing: number?,
	size: number?,
	colors: { Color3 }?,
	offset: number?, -- colour cycle start
}

-- String of party bulbs: wire + Neon bulbs (Model "StringLights" of bulbs, tagged).
function Kit.stringLights(
	parent: Instance,
	anchorA: BasePart,
	a: Vector3,
	anchorB: BasePart,
	b: Vector3,
	sag: number,
	opts: StringOpts?
): Model
	local o: StringOpts = opts or {}
	local curve = Kit.wire(anchorA, a, anchorB, b, sag, Kit.ROPE, 0.1)
	local m = Kit.model("StringLights", parent)
	local colors = o.colors or Kit.BULBS
	local n = math.max(2, math.floor((b - a).Magnitude / (o.spacing or 3.8)))
	for i = 1, n - 1 do
		local p = curve(i / n) + Vector3.new(0, -0.22, 0)
		Build.ball(m, "Bulb", o.size or 0.42, CFrame.new(p), colors[(i + (o.offset or 0)) % #colors + 1], NEON)
	end
	for _, d in m:GetChildren() do
		if d:IsA("BasePart") then
			d.CastShadow = false
		end
	end
	Kit.tag(m, Kit.NIGHT_TAG)
	return m
end

export type BuntingOpts = {
	spacing: number?,
	w: number?,
	h: number?,
	colors: { Color3 }?,
}

-- Triangular bunting pennants hanging from a sagging cord.
function Kit.bunting(
	parent: Instance,
	anchorA: BasePart,
	a: Vector3,
	anchorB: BasePart,
	b: Vector3,
	sag: number,
	opts: BuntingOpts?
): Model
	local o: BuntingOpts = opts or {}
	local curve = Kit.wire(anchorA, a, anchorB, b, sag, Kit.WHITE, 0.09)
	local m = Kit.model("Bunting", parent)
	local colors = o.colors or Kit.FLAGS
	local spacing = (o.spacing or 2.2) * 1.55
	local n = math.max(2, math.floor((b - a).Magnitude / spacing))
	local w, h = o.w or spacing * 0.78, o.h or 1.5
	for i = 0, n - 1 do
		local t0 = (i + 0.12) / n
		local t1 = (i + 0.12) / n + (w / (b - a).Magnitude)
		local p0, p1 = curve(t0), curve(math.min(t1, 1))
		local T = (p1 - p0).Unit
		local up = (Vector3.yAxis - T * Vector3.yAxis:Dot(T)).Unit
		local X = T:Cross(up)
		local centre = p0 + T * (w / 2) - up * (h / 2)
		Kit.wedge(m, "Pennant", Vector3.new(0.08, w, h), CFrame.fromMatrix(centre, X, T, up), colors[i % #colors + 1])
	end
	return m
end

-- Swaying flags ------------------------------------------------------------------------------

-- Rectangular striped flag hinged at `hinge` (world point on the pole), flying along `dir`.
-- Model tagged AmbientSway, PrimaryPart = the hinge clip.
function Kit.flag(
	parent: Instance,
	hinge: Vector3,
	dir: Vector3,
	w: number,
	h: number,
	stripes: { Color3 },
	sway: number?
): Model
	local m = Kit.model("Flag", parent)
	local clip = Kit.part(m, "FlagHinge", Vector3.new(0.35, 0.5, 0.35), CFrame.new(hinge), Kit.BRASS)
	m.PrimaryPart = clip
	local d = Vector3.new(dir.X, 0, dir.Z).Unit
	local n = #stripes
	for i, col in stripes do
		local y = h / 2 - (i - 0.5) * h / n
		Kit.part(
			m,
			"FlagCloth",
			Vector3.new(w, h / n, 0.1),
			CFrame.fromMatrix(hinge + d * (w / 2 + 0.15) + Vector3.new(0, y - h / 2 + 0.2, 0), d, Vector3.yAxis),
			col
		)
	end
	m:SetAttribute("SwayDegrees", sway or 7)
	m:SetAttribute("SwayPeriod", 2.6 + (math.abs(hinge.X * 0.37 + hinge.Z * 0.11) % 1.4))
	Kit.motion(m, "AmbientSway")
	return m
end

-- Triangular pennant hinged at `hinge`, pointing along `dir`.
function Kit.pennant(parent: Instance, hinge: Vector3, dir: Vector3, len: number, h: number, color: Color3): Model
	local m = Kit.model("Pennant", parent)
	local clip = Kit.part(m, "PennantHinge", Vector3.new(0.3, 0.4, 0.3), CFrame.new(hinge), Kit.BRASS)
	m.PrimaryPart = clip
	local d = Vector3.new(dir.X, 0, dir.Z).Unit
	local base = hinge + Vector3.new(0, -h / 2 + 0.2, 0) + d * 0.1
	Kit.tri(m, "PennantCloth", base, base + d * len, Vector3.yAxis, h, 0.1, color)
	m:SetAttribute("SwayDegrees", 9)
	m:SetAttribute("SwayPeriod", 2.2 + (math.abs(hinge.X * 0.29 + hinge.Z * 0.17) % 1.2))
	Kit.motion(m, "AmbientSway")
	return m
end

-- Vintage lamps ------------------------------------------------------------------------------

export type Scheme = { post: Color3, base: Color3, trim: Color3, cap: Color3 }

Kit.SCHEMES = {
	Navy = { post = Kit.NAVY, base = rgb(24, 42, 56), trim = Kit.BRASS, cap = Kit.NAVY } :: Scheme,
	White = { post = Kit.WHITE, base = rgb(214, 208, 196), trim = C.Coral, cap = Kit.NAVY } :: Scheme,
	Carnival = { post = rgb(232, 72, 98), base = rgb(150, 40, 64), trim = C.Gold, cap = Kit.WHITE } :: Scheme,
}

export type LampOpts = {
	scheme: Scheme?,
	light: boolean?,
	height: number?, -- shaft top (default 9.6 crook/twin, 14 tall)
	pennant: Color3?,
	wind: Vector3?, -- direction the Tall lamp's pennant flies (default: the frame's right)
}

export type LampInfo = {
	model: Model,
	anchor: BasePart, -- collar part (wires attach here)
	top: Vector3, -- wire attach point (world)
	heads: { Vector3 },
}

-- Glass lantern hanging below `hook` (world). Returns the bulb.
local function hangingLantern(m: Model, frame: CFrame, hook: Vector3, sc: Scheme): Part
	local rot = frame.Rotation
	local function at(dy: number): CFrame
		return CFrame.new(hook + Vector3.new(0, dy, 0)) * rot
	end
	Kit.ellipsoid(m, "LanternDome", Vector3.new(1.25, 0.75, 1.25), at(-0.2), sc.cap)
	local glass = Kit.part(m, "LanternGlass", Vector3.new(1.05, 1.3, 1.05), at(-1.25), Kit.GLASS, Enum.Material.Glass)
	glass.Transparency = 0.45
	Kit.part(m, "LanternBase", Vector3.new(1.25, 0.22, 1.25), at(-2.0), sc.trim)
	return Kit.bulb(m, "LampBulb", 0.62, at(-1.25).Position, Kit.WARM)
end

-- Post-top lantern sitting on `seat` (world).
local function postTopLantern(m: Model, frame: CFrame, seat: Vector3, sc: Scheme): (Part, Vector3)
	local rot = frame.Rotation
	local function at(dy: number): CFrame
		return CFrame.new(seat + Vector3.new(0, dy, 0)) * rot
	end
	Kit.part(m, "LanternBase", Vector3.new(1.3, 0.24, 1.3), at(0.12), sc.trim)
	local glass = Kit.part(m, "LanternGlass", Vector3.new(1.1, 1.5, 1.1), at(1.0), Kit.GLASS, Enum.Material.Glass)
	glass.Transparency = 0.45
	Kit.part(m, "LanternBrim", Vector3.new(1.75, 0.24, 1.75), at(1.86), sc.trim)
	Kit.ellipsoid(m, "LanternDome", Vector3.new(1.35, 0.9, 1.35), at(2.2), sc.cap)
	return Kit.bulb(m, "LampBulb", 0.7, at(1.0).Position, Kit.WARM), seat + Vector3.new(0, 2.6, 0)
end

-- Plinth + fluted post + collar. Returns the collar part and the collar top (world).
local function lampPost(m: Model, cf: CFrame, h: number, sc: Scheme, rings: number): (BasePart, Vector3)
	local function at(y: number): CFrame
		return cf * CFrame.new(0, y, 0)
	end
	Kit.solid(Kit.part(m, "LampPlinth", Vector3.new(1.9, 0.55, 1.9), at(0.275), sc.base))
	Kit.cyl(m, "LampFlare", 1.7, 1.05, at(1.4), sc.post)
	Kit.solid(Kit.cyl(m, "LampPost", h - 2.3, 0.55, at((h + 2.3) / 2), sc.post))
	for r = 1, rings do
		Kit.cyl(m, "LampRing", 0.24, 0.82, at(2.3 + (h - 2.3) * r / (rings + 1)), sc.trim)
	end
	local collar = Kit.cyl(m, "LampCollar", 0.45, 0.98, at(h + 0.1), sc.trim)
	return collar, at(h + 0.33).Position
end

-- kind: "Crook" (curved arm over the walkway, arm towards the frame's -Z), "Twin" (crossbar
-- along the frame's X with two hanging lanterns), "Tall" (post-top lantern + flag pennant).
function Kit.lamp(parent: Instance, kind: string, cf: CFrame, opts: LampOpts?): LampInfo
	local o: LampOpts = opts or {}
	local sc = o.scheme or Kit.SCHEMES.Navy
	local m = Kit.model("Lamp" .. kind, parent)
	local heads: { Vector3 } = {}
	local bulbs: { Part } = {}
	local collar: BasePart, top: Vector3
	if kind == "Twin" then
		local h = o.height or 9.8
		collar, top = lampPost(m, cf, h, sc, 1)
		local function L(x: number, y: number, z: number): Vector3
			return cf:PointToWorldSpace(Vector3.new(x, y, z))
		end
		Kit.rod(m, "LampCrossbar", L(-2.5, h + 0.5, 0), L(2.5, h + 0.5, 0), 0.32, sc.post)
		Kit.rod(m, "LampFinial", L(0, h + 0.5, 0), L(0, h + 2.1, 0), 0.26, sc.post)
		Kit.ball(m, "LampFinialBall", 0.6, L(0, h + 2.3, 0), sc.trim)
		for _, sx in { -1, 1 } do
			Kit.rod(m, "LampBrace", L(0, h - 1.4, 0), L(sx * 1.8, h + 0.5, 0), 0.2, sc.post)
			local hook = L(sx * 2.4, h + 0.4, 0)
			table.insert(bulbs, hangingLantern(m, cf, hook, sc))
			table.insert(heads, hook)
		end
		top = L(0, h + 0.5, 0)
	elseif kind == "Tall" then
		local h = o.height or 14
		collar, top = lampPost(m, cf, h, sc, 2)
		local bulb, crown = postTopLantern(m, cf, top, sc)
		table.insert(bulbs, bulb)
		table.insert(heads, top)
		local poleTop = crown + Vector3.new(0, 4.6, 0)
		Kit.rod(m, "LampFlagpole", crown, poleTop, 0.22, Kit.WHITE)
		Kit.ball(m, "LampFlagBall", 0.55, poleTop + Vector3.new(0, 0.25, 0), C.Gold)
		Kit.pennant(m, poleTop - Vector3.new(0, 0.5, 0), o.wind or cf.RightVector, 3.6, 1.7, o.pennant or C.Coral)
	else
		local h = o.height or 9.6
		collar, top = lampPost(m, cf, h, sc, 1)
		local function L(y: number, z: number): Vector3
			return cf:PointToWorldSpace(Vector3.new(0, y, z))
		end
		-- Shepherd's-crook arm towards the frame's front, lantern hanging from its tip.
		local pts = { L(h + 0.4, 0), L(h + 1.7, -0.7), L(h + 1.75, -2.0), L(h + 0.85, -2.7) }
		for i = 1, #pts - 1 do
			Kit.rod(m, "LampArm", pts[i], pts[i + 1], 0.3, sc.post)
		end
		local hook = L(h + 0.85, -2.7)
		table.insert(bulbs, hangingLantern(m, cf, hook, sc))
		table.insert(heads, hook)
	end
	if o.light and bulbs[1] then
		Kit.light(bulbs[1], Kit.WARM, 15, 1.3)
	end
	return { model = m, anchor = collar, top = top, heads = heads }
end

-- Street furniture ---------------------------------------------------------------------------

-- Park bench facing the frame's -Z. Seat slats collide.
function Kit.bench(parent: Instance, cf: CFrame, slat: Color3?): Model
	local m = Kit.model("Bench", parent)
	local wood = slat or Kit.WOOD
	for _, sx in { -1, 1 } do
		Kit.part(m, "BenchFrame", Vector3.new(0.3, 1.5, 1.7), cf * CFrame.new(sx * 2.25, 0.75, 0), Kit.IRON)
		Kit.part(
			m,
			"BenchBackFrame",
			Vector3.new(0.3, 1.9, 0.3),
			cf * CFrame.new(sx * 2.25, 2.0, 0.78) * CFrame.Angles(math.rad(12), 0, 0),
			Kit.IRON
		)
	end
	for i, z in { -0.4, 0.38 } do
		local s = Kit.part(m, "BenchSeat", Vector3.new(4.8, 0.2, 0.72), cf * CFrame.new(0, 1.55, z), wood)
		if i == 1 then
			Kit.solid(s)
		end
	end
	for _, y in { 2.25, 2.85 } do
		Kit.part(
			m,
			"BenchBack",
			Vector3.new(4.8, 0.4, 0.14),
			cf * CFrame.new(0, y, 0.75 + (y - 1.6) * 0.21) * CFrame.Angles(math.rad(12), 0, 0),
			wood
		)
	end
	return m
end

-- Wooden planter with a small palm ("Palm") or a flower bed ("Flowers").
function Kit.planter(parent: Instance, cf: CFrame, kind: string, rng: Random): Model
	local m = Kit.model("Planter", parent)
	local w, d = 3.6 + rng:NextNumber(-0.3, 0.6), 2.4 + rng:NextNumber(-0.2, 0.3)
	Kit.solid(
		Kit.part(
			m,
			"PlanterBox",
			Vector3.new(w, 1.5, d),
			cf * CFrame.new(0, 0.75, 0),
			Kit.WOOD_DARK,
			Enum.Material.Wood
		)
	)
	Kit.part(m, "PlanterRim", Vector3.new(w + 0.3, 0.25, d + 0.3), cf * CFrame.new(0, 1.55, 0), Kit.WHITE)
	Kit.part(
		m,
		"PlanterSoil",
		Vector3.new(w - 0.3, 0.12, d - 0.3),
		cf * CFrame.new(0, 1.62, 0),
		rgb(92, 66, 44),
		Enum.Material.Ground
	)
	if kind == "Palm" then
		local lean = rng:NextNumber(-0.18, 0.18)
		local base = cf:PointToWorldSpace(Vector3.new(0, 1.6, 0))
		local hgt = rng:NextNumber(7.5, 9.5)
		local pts = {
			base,
			base + Vector3.new(lean * 2, hgt * 0.36, 0.15),
			base + Vector3.new(lean * 5, hgt * 0.7, 0.4),
			base + Vector3.new(lean * 8, hgt, 0.7),
		}
		for i = 1, 3 do
			Kit.rod(m, "PalmTrunk", pts[i], pts[i + 1], 0.75 - i * 0.12, rgb(150, 110, 70), Enum.Material.Wood)
		end
		local crown = pts[4]
		local yaw0 = rng:NextNumber(0, math.pi * 2)
		for f = 1, 5 do
			local a = yaw0 + f * math.pi * 2 / 5
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local tip = crown + dir * 3.6 + Vector3.new(0, -1.6 + rng:NextNumber(-0.3, 0.4), 0)
			Kit.bar(
				m,
				"PalmFrond",
				crown,
				tip,
				1.2,
				0.12,
				if f % 2 == 0 then C.Palm else Build.darken(C.Palm, 0.18),
				nil,
				dir:Cross(Vector3.yAxis)
			)
		end
		Kit.ball(m, "Coconut", 0.6, crown + Vector3.new(0.3, -0.4, 0.2), rgb(110, 80, 50))
		Kit.ball(m, "Coconut", 0.55, crown + Vector3.new(-0.3, -0.45, -0.1), rgb(120, 86, 52))
	else
		local flowers = { C.Coral, C.Gold, C.Purple, Kit.WHITE, C.Sunset }
		for i = 1, 3 do
			local x = (i - 2) * (w / 3.2)
			Kit.ellipsoid(
				m,
				"Shrub",
				Vector3.new(1.6, 1.2, 1.5),
				cf * CFrame.new(x, 2.1, rng:NextNumber(-0.3, 0.3)),
				Build.darken(C.Palm, rng:NextNumber(0.05, 0.3))
			)
		end
		for i = 1, 4 do
			Kit.ball(
				m,
				"Flower",
				0.55,
				cf:PointToWorldSpace(
					Vector3.new(
						rng:NextNumber(-w / 2 + 0.5, w / 2 - 0.5),
						rng:NextNumber(2.4, 2.9),
						rng:NextNumber(-d / 2 + 0.4, d / 2 - 0.4)
					)
				),
				flowers[(i + rng:NextInteger(0, 4)) % #flowers + 1]
			)
		end
	end
	return m
end

-- Trash ("Trash") or recycling ("Recycle") bin.
function Kit.bin(parent: Instance, pos: Vector3, kind: string): Model
	local m = Kit.model(kind .. "Bin", parent)
	local col = if kind == "Recycle" then C.OceanDark else Build.darken(C.Palm, 0.35)
	Kit.solid(Kit.cyl(m, "BinBody", 2.3, 1.6, CFrame.new(pos + Vector3.new(0, 1.15, 0)), col))
	Kit.cyl(m, "BinBand", 0.3, 1.7, CFrame.new(pos + Vector3.new(0, 1.7, 0)), Kit.WHITE)
	Kit.ellipsoid(
		m,
		"BinLid",
		Vector3.new(1.75, 0.6, 1.75),
		CFrame.new(pos + Vector3.new(0, 2.35, 0)),
		Build.darken(col, 0.2)
	)
	return m
end

-- Red-and-white lifebuoy ring in the frame's XY plane (facing -Z), centred at `cf`.
function Kit.lifebuoy(parent: Instance, cf: CFrame, r: number?): Model
	local m = Kit.model("Lifebuoy", parent)
	local rad = r or 1.0
	local n = 6
	for i = 0, n - 1 do
		local a0, a1 = i * math.pi * 2 / n, (i + 1) * math.pi * 2 / n
		local p0 = cf:PointToWorldSpace(Vector3.new(math.cos(a0) * rad, math.sin(a0) * rad, 0))
		local p1 = cf:PointToWorldSpace(Vector3.new(math.cos(a1) * rad, math.sin(a1) * rad, 0))
		Kit.rod(m, "BuoyRing", p0, p1, 0.5, if i % 2 == 0 then C.Danger else Kit.WHITE)
	end
	return m
end

-- Lifebuoy on its own post (facing -Z of `cf`).
function Kit.lifebuoyPost(parent: Instance, cf: CFrame): Model
	local m = Kit.model("LifebuoyStand", parent)
	Kit.solid(Kit.part(m, "BuoyPost", Vector3.new(0.5, 4.6, 0.5), cf * CFrame.new(0, 2.3, 0.35), Kit.WHITE))
	Kit.part(m, "BuoyPostCap", Vector3.new(0.7, 0.25, 0.7), cf * CFrame.new(0, 4.7, 0.35), C.Danger)
	Kit.lifebuoy(m, cf * CFrame.new(0, 3.2, 0), 0.95)
	return m
end

-- Sandy-feet shower: grate, pole, arm and rose, and a little sign.
function Kit.shower(parent: Instance, cf: CFrame): Model
	local m = Kit.model("FootShower", parent)
	local metal = rgb(150, 205, 215)
	Kit.part(
		m,
		"ShowerGrate",
		Vector3.new(2.6, 0.12, 2.6),
		cf * CFrame.new(0, 0.06, -0.6),
		rgb(120, 126, 134),
		Enum.Material.DiamondPlate
	)
	Kit.solid(Kit.cyl(m, "ShowerPole", 7.2, 0.42, cf * CFrame.new(0, 3.6, 0.4), metal, Enum.Material.Metal))
	Kit.rod(
		m,
		"ShowerArm",
		cf:PointToWorldSpace(Vector3.new(0, 7.0, 0.4)),
		cf:PointToWorldSpace(Vector3.new(0, 7.0, -0.9)),
		0.28,
		metal,
		Enum.Material.Metal
	)
	Kit.cyl(m, "ShowerRose", 0.3, 0.95, cf * CFrame.new(0, 6.75, -0.95), Kit.WHITE)
	Kit.ball(m, "ShowerTap", 0.45, cf:PointToWorldSpace(Vector3.new(0, 1.2, 0.05)), C.Ocean)
	local sign = Kit.part(m, "ShowerSign", Vector3.new(2.0, 0.9, 0.12), cf * CFrame.new(0, 4.9, 0.2), C.Ocean)
	Kit.label(sign, Enum.NormalId.Front, "RINSE OFF!")
	return m
end

-- Wooden signpost; arrows = { {text, targetWorldPos, colour} }.
export type Arrow = { text: string, target: Vector3, color: Color3 }

function Kit.signpost(parent: Instance, pos: Vector3, arrows: { Arrow }): Model
	local m = Kit.model("Signpost", parent)
	local n = #arrows
	local h = 3.6 + n * 1.15
	Kit.part(
		m,
		"SignpostFoot",
		Vector3.new(1.4, 0.5, 1.4),
		CFrame.new(pos + Vector3.new(0, 0.25, 0)),
		Kit.WOOD_DARK,
		Enum.Material.Wood
	)
	Kit.solid(
		Kit.part(
			m,
			"SignpostPole",
			Vector3.new(0.6, h, 0.6),
			CFrame.new(pos + Vector3.new(0, h / 2, 0)),
			Kit.WOOD,
			Enum.Material.Wood
		)
	)
	Kit.ellipsoid(m, "SignpostCap", Vector3.new(0.9, 0.6, 0.9), CFrame.new(pos + Vector3.new(0, h + 0.1, 0)), C.Coral)
	for i, a in arrows do
		local d = Vector3.new(a.target.X - pos.X, 0, a.target.Z - pos.Z).Unit
		local y = h - 0.7 - (i - 1) * 1.15
		local len = 3.6
		local centre = pos + Vector3.new(0, y, 0) + d * (len / 2 + 0.3)
		local frame = CFrame.fromMatrix(centre, d, Vector3.yAxis)
		local board = Kit.part(m, "SignArrow", Vector3.new(len, 0.9, 0.2), frame, a.color, Enum.Material.Wood)
		Kit.label(board, Enum.NormalId.Front, a.text)
		Kit.label(board, Enum.NormalId.Back, a.text)
		local tipBase = centre + d * (len / 2)
		Kit.tri(m, "SignArrowTip", tipBase, tipBase + d * 0.75, Vector3.yAxis, 1.25, 0.2, a.color, Enum.Material.Wood)
	end
	return m
end

-- Striped beach umbrella (8 panels) with its pole; `top` = canopy apex (world).
function Kit.umbrella(parent: Instance, base: Vector3, top: Vector3, radius: number, colors: { Color3 })
	Kit.rod(parent, "UmbrellaPole", base, top + Vector3.new(0, 0.4, 0), 0.22, Kit.WHITE)
	local rimY = top.Y - radius * 0.38
	for i = 0, 7 do
		local a = (i + 0.5) * math.pi / 4
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local rimMid = Vector3.new(top.X, rimY, top.Z) + dir * radius * math.cos(math.pi / 8)
		Kit.tri(
			parent,
			"UmbrellaPanel",
			rimMid,
			top,
			dir:Cross(Vector3.yAxis),
			2 * radius * math.sin(math.pi / 8) + 0.05,
			0.1,
			colors[i % #colors + 1]
		)
	end
	Kit.ball(parent, "UmbrellaFinial", 0.45, top + Vector3.new(0, 0.45, 0), C.Gold)
end

-- Snack cart (front = frame -Z): "IceCream" (giant cone) or "Lemonade" (giant lemon + glass).
function Kit.cart(parent: Instance, cf: CFrame, kind: string): Model
	local ice = kind == "IceCream"
	local m = Kit.model(kind .. "Cart", parent)
	local body = if ice then rgb(255, 236, 246) else rgb(255, 250, 220)
	local stripe = if ice then rgb(255, 130, 170) else C.Gold
	local function L(x: number, y: number, z: number): Vector3
		return cf:PointToWorldSpace(Vector3.new(x, y, z))
	end
	local box = Kit.solid(Kit.part(m, "CartBody", Vector3.new(5.2, 2.5, 2.7), cf * CFrame.new(0, 2.15, 0), body))
	Kit.part(m, "CartStripe", Vector3.new(5.25, 0.5, 2.75), cf * CFrame.new(0, 2.65, 0), stripe)
	Kit.part(m, "CartSkirt", Vector3.new(5.3, 0.3, 2.8), cf * CFrame.new(0, 0.95, 0), Build.darken(stripe, 0.25))
	Kit.part(m, "CartCounter", Vector3.new(5.5, 0.25, 3.0), cf * CFrame.new(0, 3.5, 0), if ice then C.Ocean else C.Palm)
	local menu = Kit.part(m, "CartMenu", Vector3.new(3.4, 1.0, 0.1), cf * CFrame.new(-0.4, 1.95, -1.4), Kit.WHITE)
	Kit.label(
		menu,
		Enum.NormalId.Front,
		if ice then "ICE CREAM" else "LEMONADE",
		if ice then rgb(255, 120, 165) else C.Gold
	)
	for _, sz in { -1, 1 } do
		Kit.cyl(
			m,
			"CartWheel",
			0.35,
			2.3,
			CFrame.new(L(1.5, 1.15, sz * 1.55)) * cf.Rotation * CFrame.Angles(math.rad(90), 0, 0),
			Kit.NAVY
		)
		Kit.cyl(
			m,
			"CartHub",
			0.45,
			0.7,
			CFrame.new(L(1.5, 1.15, sz * 1.6)) * cf.Rotation * CFrame.Angles(math.rad(90), 0, 0),
			C.Gold
		)
	end
	Kit.part(m, "CartLeg", Vector3.new(0.35, 0.9, 2.2), cf * CFrame.new(-2.2, 0.45, 0), Kit.NAVY)
	Kit.rod(m, "CartHandle", L(-2.6, 3.0, -1.0), L(-3.6, 3.6, -1.0), 0.22, Kit.NAVY)
	Kit.rod(m, "CartHandle", L(-2.6, 3.0, 1.0), L(-3.6, 3.6, 1.0), 0.22, Kit.NAVY)
	Kit.rod(m, "CartGrip", L(-3.6, 3.6, -1.1), L(-3.6, 3.6, 1.1), 0.3, C.Coral)
	Kit.umbrella(
		m,
		L(1.2, 3.6, 0.4),
		L(1.2, 8.6, 0.4),
		3.4,
		if ice then { rgb(255, 130, 170), Kit.WHITE } else { C.Gold, Kit.WHITE }
	)
	if ice then
		-- Giant cone sign on the counter
		local cb = L(-1.3, 3.65, 0)
		for _, wd in { cf.RightVector, cf.LookVector } do
			Kit.tri(
				m,
				"GiantCone",
				cb + Vector3.new(0, 2.2, 0),
				cb,
				wd,
				1.8,
				0.5,
				rgb(222, 166, 92),
				Enum.Material.Sand
			)
		end
		Kit.ball(m, "GiantScoop", 1.9, cb + Vector3.new(0, 2.6, 0), rgb(255, 160, 195))
		Kit.ball(m, "GiantScoop", 1.6, cb + Vector3.new(0, 3.75, 0), rgb(160, 235, 200))
		Kit.ball(m, "GiantCherry", 0.55, cb + Vector3.new(0, 4.7, 0), C.Danger)
		-- freezer lids
		Kit.part(m, "FreezerLid", Vector3.new(1.4, 0.18, 1.8), cf * CFrame.new(0.5, 3.7, 0), Kit.WHITE)
	else
		local gb = L(-1.4, 3.65, 0)
		local glass = Kit.cyl(
			m,
			"GiantGlass",
			2.4,
			1.6,
			CFrame.new(gb + Vector3.new(0, 1.2, 0)),
			rgb(255, 245, 160),
			Enum.Material.Glass
		)
		glass.Transparency = 0.35
		Kit.cyl(m, "GiantLemonade", 1.8, 1.4, CFrame.new(gb + Vector3.new(0, 1.0, 0)), rgb(255, 228, 90))
		Kit.rod(m, "GiantStraw", gb + Vector3.new(0.2, 1.2, 0), gb + Vector3.new(0.6, 3.4, 0.2), 0.22, C.Coral)
		Kit.cyl(
			m,
			"LemonSlice",
			0.2,
			1.2,
			CFrame.new(gb + Vector3.new(-0.75, 2.35, 0)) * cf.Rotation * CFrame.Angles(math.rad(90), 0, 0),
			C.Gold
		)
		Kit.ellipsoid(
			m,
			"GiantLemon",
			Vector3.new(2.0, 1.5, 1.5),
			CFrame.new(L(0.6, 4.5, 0)) * cf.Rotation,
			rgb(255, 222, 60)
		)
	end
	m.PrimaryPart = box
	return m
end

return Kit
