--!strict
--[[
	Build — shared procedural-geometry helpers for every model builder.
	Pure Instance construction: no services, safe on server and client.

	Conventions used by all builders:
	- Models are built around the world origin and returned unparented.
	- "Front" is -Z (LookVector), "up" is +Y, exactly like a Roblox character.
	- Every part is Anchored, CanCollide/CanQuery/CanTouch false by default; use Build.solid()
	  for parts players should stand on / bump into.
	- Cylinders: Build.cyl takes a CFrame whose **Y axis** is the cylinder axis (the helper
	  applies the Roblox X-axis correction internally).
	- Triangles: Build.tri builds a flat isosceles triangle (two WedgeParts) in the CFrame's XY
	  plane, apex towards +Y, thickness along Z.
]]

local Build = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local SMOOTH = Enum.Material.SmoothPlastic
local HALF_PI = math.pi / 2

Build.EYE = Color3.fromRGB(25, 22, 35)
Build.MOUTH = Color3.fromRGB(120, 30, 45)
Build.CHEEK = Color3.fromRGB(255, 140, 165)

-- Colour helpers ----------------------------------------------------------------------------

function Build.lighten(c: Color3, t: number): Color3
	return c:Lerp(WHITE, t)
end

function Build.darken(c: Color3, t: number): Color3
	return c:Lerp(BLACK, t)
end

-- Deterministic small hash for per-id variation.
function Build.hash(s: string): number
	local h = 7
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 1000003
	end
	return h
end

-- Part factories ----------------------------------------------------------------------------

local function setup(p: BasePart, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?)
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	local mat = material or SMOOTH
	p.Material = mat
	if mat == Enum.Material.Glass then
		p.Transparency = 0.3
	elseif mat == Enum.Material.Ice then
		p.Transparency = 0.15
	elseif mat == Enum.Material.ForceField then
		p.Transparency = 0.1
	end
	if math.max(size.X, size.Y, size.Z) < 0.6 then
		p.CastShadow = false
	end
end

function Build.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	setup(p, name, size, cf, color, material)
	p.Parent = parent
	return p
end

function Build.ball(
	parent: Instance,
	name: string,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	setup(p, name, Vector3.new(diameter, diameter, diameter), cf, color, material)
	p.Parent = parent
	return p
end

-- Stretched sphere (Part + built-in Sphere SpecialMesh, no asset ids).
function Build.ellipsoid(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	setup(p, name, size, cf, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	p.Parent = parent
	return p
end

-- Cylinder whose axis is the Y axis of `cf`.
function Build.cyl(
	parent: Instance,
	name: string,
	length: number,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	setup(p, name, Vector3.new(length, diameter, diameter), cf * CFrame.Angles(0, 0, HALF_PI), color, material)
	p.Parent = parent
	return p
end

function Build.wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local p = Instance.new("WedgePart")
	setup(p, name, size, cf, color, material)
	p.Parent = parent
	return p
end

-- Orientation helpers -----------------------------------------------------------------------

-- CFrame at `pos` whose Y axis points along `yDir`; X axis follows `xHint` as closely as possible.
function Build.orient(pos: Vector3, yDir: Vector3, xHint: Vector3?): CFrame
	local y = yDir.Unit
	local hint = xHint
	if hint == nil or math.abs(hint.Unit:Dot(y)) > 0.98 then
		hint = if math.abs(y.Y) < 0.95 then Vector3.yAxis:Cross(y) else Vector3.xAxis
	end
	local h = hint :: Vector3
	local x = (h - y * h:Dot(y)).Unit
	return CFrame.fromMatrix(pos, x, y)
end

-- Cylinder from point a to point b.
function Build.cylBetween(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): Part
	local d = b - a
	return Build.cyl(parent, name, d.Magnitude, diameter, Build.orient(a:Lerp(b, 0.5), d), color, material)
end

-- Block from a to b (Y = length), `width` along xHint, `thick` along the remaining axis.
function Build.beam(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	thick: number,
	color: Color3,
	material: Enum.Material?,
	xHint: Vector3?
): Part
	local d = b - a
	return Build.part(
		parent,
		name,
		Vector3.new(width, d.Magnitude, thick),
		Build.orient(a:Lerp(b, 0.5), d, xHint),
		color,
		material
	)
end

-- Flat isosceles triangle centred on `cf`: apex at +Y (h/2), base at -Y, width along X,
-- thickness along Z. Two WedgeParts.
function Build.tri(
	parent: Instance,
	name: string,
	cf: CFrame,
	w: number,
	h: number,
	t: number,
	color: Color3,
	material: Enum.Material?
): (WedgePart, WedgePart)
	local size = Vector3.new(t, h, w / 2)
	-- Wedge local: full height at +Z (back), zero at -Z (front). Map local +Z to -X / +X.
	local right = cf * CFrame.fromMatrix(Vector3.new(w / 4, 0, 0), Vector3.zAxis, Vector3.yAxis, -Vector3.xAxis)
	local left = cf * CFrame.fromMatrix(Vector3.new(-w / 4, 0, 0), -Vector3.zAxis, Vector3.yAxis, Vector3.xAxis)
	local a = Build.wedge(parent, name, size, right, color, material)
	local b = Build.wedge(parent, name, size, left, color, material)
	return a, b
end

-- Triangle from a base-centre point to an apex point, width along widthDir.
function Build.triPts(
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
	Build.tri(parent, name, Build.orient(base:Lerp(apex, 0.5), d, widthDir), w, d.Magnitude, t, color, material)
end

-- Cheap low-poly cone / horn / crystal: two crossed triangles (4 wedges).
function Build.spike(
	parent: Instance,
	name: string,
	base: Vector3,
	apex: Vector3,
	w: number,
	color: Color3,
	material: Enum.Material?
)
	local d = apex - base
	local cf = Build.orient(base:Lerp(apex, 0.5), d)
	local h = d.Magnitude
	Build.tri(parent, name, cf, w, h, w * 0.28, color, material)
	Build.tri(parent, name, cf * CFrame.Angles(0, HALF_PI, 0), w, h, w * 0.28, color, material)
end

-- Point on the surface of an axis-aligned ellipsoid (centre, full size) in direction `dir`,
-- oriented so LookVector is the outward surface normal. Use for spots, plates, patches.
function Build.surface(centre: Vector3, size: Vector3, dir: Vector3): CFrame
	local a, b, c = size.X / 2, size.Y / 2, size.Z / 2
	local d = dir.Unit
	local t = 1 / math.sqrt((d.X / a) ^ 2 + (d.Y / b) ^ 2 + (d.Z / c) ^ 2)
	local p = centre + d * t
	local rel = d * t
	local n = Vector3.new(rel.X / (a * a), rel.Y / (b * b), rel.Z / (c * c)).Unit
	local up = if math.abs(n.Y) > 0.99 then Vector3.zAxis else Vector3.yAxis
	return CFrame.lookAt(p, p + n, up)
end

-- Faces -------------------------------------------------------------------------------------

export type FaceOpts = {
	spacing: number?, -- eye half-distance at scale 1 (default 0.28)
	eye: number?, -- eye diameter at scale 1 (default 0.3)
	mouth: boolean?, -- default true
	cheeks: boolean?, -- default true
	eyeColor: Color3?,
	radius: number?, -- surface curvature radius in studs (features sink to follow it); nil = flat
	eyes: boolean?, -- default true
}

-- Cute face. `cf` sits on the surface, LookVector pointing out of the face.
function Build.face(parent: Instance, cf: CFrame, s: number, opts: FaceOpts?)
	local o: FaceOpts = opts or {}
	local spacing = (o.spacing or 0.28) * s
	local eyeD = (o.eye or 0.3) * s
	local eyeColor = o.eyeColor or Build.EYE
	local radius = o.radius
	local function sink(dx: number, dy: number): number
		local r = radius
		if r == nil then
			return 0
		end
		local d2 = dx * dx + dy * dy
		local r2 = r * r
		return if d2 < r2 then r - math.sqrt(r2 - d2) else r
	end
	for side = -1, 1, 2 do
		local ex, ey = side * spacing, 0.08 * s
		local eyeCf = cf * CFrame.new(ex, ey, sink(ex, ey) - 0.02 * s)
		if o.eyes ~= false then
			Build.ball(parent, "Eye", eyeD, eyeCf, eyeColor)
			Build.ball(
				parent,
				"EyeShine",
				eyeD * 0.38,
				eyeCf * CFrame.new(0.22 * eyeD, 0.22 * eyeD, -0.36 * eyeD),
				WHITE,
				Enum.Material.Neon
			)
		end
		if o.cheeks ~= false then
			local cx, cy = side * (spacing + 0.2 * s), -0.1 * s
			Build.ellipsoid(
				parent,
				"Cheek",
				Vector3.new(0.22, 0.12, 0.08) * s,
				cf
					* CFrame.new(cx, cy, sink(cx, cy) - 0.005 * s)
					* CFrame.Angles(0, -math.asin(math.clamp(if radius then cx / radius else 0, -0.9, 0.9)), 0),
				Build.CHEEK
			)
		end
	end
	if o.mouth ~= false then
		local my = -0.14 * s
		Build.ellipsoid(
			parent,
			"Mouth",
			Vector3.new(0.24, 0.12, 0.08) * s,
			cf * CFrame.new(0, my, sink(0, my) - 0.01 * s),
			Build.MOUTH
		)
	end
end

-- Model plumbing ----------------------------------------------------------------------------

function Build.model(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	return m
end

-- Invisible pivot part (becomes PrimaryPart).
function Build.root(model: Model, cf: CFrame, size: Vector3?): Part
	local r = Build.part(model, "Root", size or Vector3.new(1, 0.2, 1), cf, WHITE)
	r.Transparency = 1
	r.CastShadow = false
	model.PrimaryPart = r
	return r
end

function Build.setPivot(model: Model, primary: BasePart)
	model.PrimaryPart = primary
end

-- Players collide with / stand on this part.
function Build.solid(p: BasePart): BasePart
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = true
	return p
end

function Build.glow(p: BasePart, color: Color3, brightness: number?, range: number?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness or 1.5
	light.Range = range or 8
	light.Shadows = false
	light.Parent = p
	return light
end

-- Texture-less sparkle emitter (uses the engine's default particle).
function Build.sparkle(p: BasePart, color: Color3, rate: number?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkles"
	e.Color = ColorSequence.new(color, WHITE)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = rate or 5
	e.Lifetime = NumberRange.new(0.8, 1.5)
	e.Speed = NumberRange.new(0.4, 1.2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.4, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Parent = p
	return e
end

-- Uniformly scale every part about `origin` (call BEFORE weldAll).
function Build.scale(model: Model, origin: CFrame, s: number)
	if math.abs(s - 1) < 1e-4 then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = origin:ToObjectSpace(d.CFrame)
			d.Size = d.Size * s
			d.CFrame = origin * CFrame.new(rel.Position * s) * rel.Rotation
		elseif d:IsA("PointLight") then
			d.Range = d.Range * s
		end
	end
end

-- Apply a rigid transform (about the world origin) to every part except `except`.
function Build.transform(model: Model, cf: CFrame, except: BasePart?)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= except then
			d.CFrame = cf * d.CFrame
		end
	end
end

-- WeldConstraint every BasePart to `root` (inert while anchored; ready for unanchoring).
function Build.weldAll(model: Model, root: BasePart)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
		end
	end
end

-- Mark everything except `root` massless (worn / held models).
function Build.massless(model: Model, root: BasePart)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			d.Massless = true
		end
	end
end

-- Text on a part face (SurfaceGui, no assets). The TextLabel is named "Label".
function Build.label(p: BasePart, face: Enum.NormalId, text: string, textColor: Color3?, strokeColor: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LabelGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	local t = Instance.new("TextLabel")
	t.Name = "Label"
	t.Size = UDim2.fromScale(0.92, 0.86)
	t.Position = UDim2.fromScale(0.04, 0.07)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = textColor or WHITE
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = strokeColor or Color3.fromRGB(35, 30, 60)
	stroke.Parent = t
	t.Parent = gui
	gui.Parent = p
end

-- Count BaseParts (QA / budgets).
function Build.count(model: Model): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

return Build
