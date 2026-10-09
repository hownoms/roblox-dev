--!strict
--[[
	HubKit — part-building kit for the hub stations and plaza (World/Hub.luau, World/HubPlaza.luau).

	Everything takes world CFrames; station code composes them from a local frame whose -Z
	(LookVector) is the building's front. Parts are decorative (no collide / query / touch)
	unless `solid` is passed; shadows only on parts >= 4 studs (docs/MAP_ART_DIRECTION.md rule 7).
	Neon always goes through Build.neonSafe. Real lights are rare, shadowless, Range <= 16 and
	tagged AmbientNightLight so they only shine at night / Golden Hour.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(ReplicatedStorage.Shared.Models.Build)
local Layout = require(script.Parent.Layout)
local Util = require(script.Parent.Util)

local C = Config.Theme.Colors
local rgb = Color3.fromRGB
local rad = math.rad

local Kit = {}

Kit.WOOD = rgb(176, 122, 76)
Kit.WOOD_DARK = rgb(124, 84, 52)
Kit.WOOD_DEEP = rgb(92, 62, 40)
Kit.TRIM = rgb(250, 246, 236)
Kit.NAVY = rgb(31, 55, 73)
Kit.MARBLE = rgb(246, 242, 255)
Kit.STONE = rgb(226, 214, 190)
Kit.STONE_DARK = rgb(184, 168, 140)
Kit.THATCH = rgb(226, 182, 96)
Kit.THATCH_DARK = rgb(184, 136, 64)
Kit.STEEL = rgb(150, 160, 172)
Kit.STEEL_DARK = rgb(88, 96, 108)
Kit.HAZARD = rgb(255, 200, 40)
Kit.BLACK = rgb(40, 40, 46)
Kit.SAND = rgb(255, 224, 150)
Kit.BAMBOO = rgb(214, 186, 112)
Kit.LEAF = rgb(64, 168, 84)
Kit.LEAF_DARK = rgb(42, 128, 66)
Kit.WATER = rgb(70, 196, 240)
Kit.WHITE = Color3.new(1, 1, 1)
Kit.C = C

local SMOOTH = Enum.Material.SmoothPlastic

-- Local-frame CFrame helpers (degrees).
function Kit.at(base: CFrame, x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	local cf = base * CFrame.new(x, y, z)
	if rx or ry or rz then
		cf *= CFrame.Angles(rad(rx or 0), rad(ry or 0), rad(rz or 0))
	end
	return cf
end

local function finishShadow(p: BasePart, size: Vector3)
	p.CastShadow = math.max(size.X, size.Y, size.Z) >= 4
end

function Kit.box(
	parent: Instance,
	name: string,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	mat: Enum.Material?,
	solid: boolean?
): Part
	local p = Util.Part({
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = mat or SMOOTH,
		Decor = not solid,
		Parent = parent,
	})
	finishShadow(p, size)
	return p
end

function Kit.wedge(
	parent: Instance,
	name: string,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	mat: Enum.Material?,
	solid: boolean?
): WedgePart
	local p = Util.Wedge({
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = mat or SMOOTH,
		Decor = not solid,
		Parent = parent,
	})
	finishShadow(p, size)
	return p
end

-- Cylinder whose axis is `cf`'s Y axis.
function Kit.cyl(
	parent: Instance,
	name: string,
	cf: CFrame,
	height: number,
	diameter: number,
	color: Color3,
	mat: Enum.Material?,
	solid: boolean?
): Part
	local size = Vector3.new(height, diameter, diameter)
	local p = Util.Part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = size,
		CFrame = cf * CFrame.Angles(0, 0, rad(90)),
		Color = color,
		Material = mat or SMOOTH,
		Decor = not solid,
		Parent = parent,
	})
	finishShadow(p, size)
	return p
end

function Kit.ball(parent: Instance, name: string, pos: Vector3, d: number, color: Color3, mat: Enum.Material?): Part
	local p = Util.Ball(parent, name, pos, d, color, mat)
	p.CastShadow = d >= 4
	return p
end

-- Neon accent. `night` = only shown at night (AmbientNightLight).
function Kit.neon(
	parent: Instance,
	name: string,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	night: boolean?,
	shape: Enum.PartType?
): Part
	local p = Util.Part({
		Name = name,
		Shape = shape,
		Size = size,
		CFrame = cf,
		Color = Build.neonSafe(color),
		Material = Enum.Material.Neon,
		Decor = true,
		Parent = parent,
	})
	if night then
		Util.Tag(p, "AmbientNightLight")
	end
	return p
end

-- Rare, shadowless night light.
function Kit.light(part: BasePart, color: Color3, range: number, brightness: number?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.min(range, 16)
	light.Brightness = brightness or 1
	light.Shadows = false
	light.Parent = part
	Util.Tag(light, "AmbientNightLight")
	return light
end

-- A Layout position (Y = voxel-grid height) moved up onto the visible sand.
function Kit.onSand(pos: Vector3): Vector3
	return Vector3.new(pos.X, Util.TerrainY(pos), pos.Z)
end

-- Station frame on the visible sand, front (-Z) facing the boardwalk spawns.
function Kit.hubFacing(pos: Vector3): CFrame
	return Util.Facing(Kit.onSand(pos), Layout.HUB_LOOK_TARGET)
end

function Kit.model(parent: Instance, name: string): Model
	return Util.Model(name, parent)
end

-- Ambient motion contract (docs/MAP_ART_DIRECTION.md): tag the Model, attributes on it.
function Kit.ambient(model: Model, tag: string, pivot: CFrame, attrs: { [string]: any })
	model.WorldPivot = pivot
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false -- the motion controller skips models with colliding parts
		end
	end
	for k, v in attrs do
		model:SetAttribute(k, v)
	end
	Util.Tag(model, tag)
end

-- Roofs --------------------------------------------------------------------------------------

export type GableOpts = {
	Overhang: number?, -- past the eaves (along the slope)
	EndOverhang: number?, -- past the gable ends (along the ridge)
	Under: Color3?, -- wedge body colour (shows as the gable triangle)
	Trim: Color3?, -- barge boards on the front gable
	Mat: Enum.Material?,
	Thick: number?,
}

-- Gable roof. `cf` = centre of the eave line; ridge along cf's Z axis (`length`), slopes fall
-- towards ±X over `span`. The front gable triangle faces cf's -Z.
function Kit.gable(
	parent: Instance,
	cf: CFrame,
	span: number,
	length: number,
	rise: number,
	color: Color3,
	opts: GableOpts?
)
	local o: GableOpts = opts or {}
	local half = span / 2
	local under = o.Under or color:Lerp(Color3.new(0, 0, 0), 0.25)
	local thick = o.Thick or 0.6
	local over = o.Overhang or 1.6
	local endOver = o.EndOverhang or 1
	local mat = o.Mat or SMOOTH
	-- body (gable triangles)
	Kit.wedge(
		parent,
		"RoofBody",
		cf * CFrame.new(-half / 2, rise / 2, 0) * CFrame.Angles(0, rad(90), 0),
		Vector3.new(length, rise, half),
		under,
		mat
	)
	Kit.wedge(
		parent,
		"RoofBody",
		cf * CFrame.new(half / 2, rise / 2, 0) * CFrame.Angles(0, rad(-90), 0),
		Vector3.new(length, rise, half),
		under,
		mat
	)
	-- roof slabs with overhang
	local slope = math.sqrt(half * half + rise * rise)
	local ang = math.atan2(rise, half)
	for _, sx in { -1, 1 } do
		local len = slope + over
		-- slab centre: midpoint of the slope, pushed outward by over/2 and up by thick/2
		local mid = Vector3.new(sx * half / 2, rise / 2, 0)
		local outward = Vector3.new(sx * math.cos(ang), -math.sin(ang), 0) * (over / 2)
		local normal = Vector3.new(sx * math.sin(ang), math.cos(ang), 0) * (thick / 2)
		local p = mid + outward + normal
		Kit.box(
			parent,
			"Roof",
			cf * CFrame.new(p) * CFrame.Angles(0, 0, -sx * ang),
			Vector3.new(len, thick, length + endOver * 2),
			color,
			mat
		)
		if o.Trim then
			local q = mid + outward + normal * 1.6 + Vector3.new(0, 0, 0)
			Kit.box(
				parent,
				"BargeBoard",
				cf * CFrame.new(q.X, q.Y, -length / 2 - endOver - 0.15) * CFrame.Angles(0, 0, -sx * ang),
				Vector3.new(len, 0.7, 0.4),
				o.Trim
			)
		end
	end
	-- ridge cap
	Kit.box(
		parent,
		"Ridge",
		cf * CFrame.new(0, rise + thick * 0.9, 0),
		Vector3.new(1, 0.7, length + endOver * 2 + 0.2),
		o.Trim or color:Lerp(Color3.new(0, 0, 0), 0.15),
		mat
	)
end

-- Striped awning sloping down to the front. `cf` = centre of the back (high) edge.
function Kit.awning(
	parent: Instance,
	cf: CFrame,
	width: number,
	depth: number,
	stripes: number,
	c1: Color3,
	c2: Color3,
	drop: number?
)
	local w = width / stripes
	local tilt = math.atan2(drop or depth * 0.35, depth)
	local slab = math.sqrt(depth * depth + (drop or depth * 0.35) ^ 2)
	local frame = cf * CFrame.Angles(-tilt, 0, 0)
	for i = 0, stripes - 1 do
		local color = if i % 2 == 0 then c1 else c2
		local x = -width / 2 + w * (i + 0.5)
		Kit.box(
			parent,
			"Awning",
			frame * CFrame.new(x, 0, -slab / 2),
			Vector3.new(w + 0.02, 0.4, slab),
			color,
			Enum.Material.Fabric
		)
		-- scalloped valance
		Kit.box(
			parent,
			"Valance",
			frame * CFrame.new(x, -0.7, -slab + 0.1) * CFrame.Angles(tilt, 0, 0),
			Vector3.new(w * 0.86, 1.2, 0.2),
			color,
			Enum.Material.Fabric
		)
	end
end

-- Glass window with frame, sill and cross mullion. `cf` faces outward along -Z.
function Kit.window(parent: Instance, cf: CFrame, w: number, h: number, frame: Color3, glass: Color3?)
	Kit.box(parent, "WindowFrame", cf, Vector3.new(w + 0.8, h + 0.8, 0.3), frame)
	local g = Kit.box(
		parent,
		"Window",
		cf * CFrame.new(0, 0, -0.12),
		Vector3.new(w, h, 0.2),
		glass or rgb(150, 220, 255),
		Enum.Material.Glass
	)
	g.Transparency = 0.35
	g.Reflectance = 0.15
	Kit.box(parent, "Mullion", cf * CFrame.new(0, 0, -0.22), Vector3.new(0.25, h, 0.15), frame)
	Kit.box(parent, "Sill", cf * CFrame.new(0, -h / 2 - 0.5, -0.3), Vector3.new(w + 1.4, 0.35, 0.8), frame)
end

-- Sign hanging from a bracket arm. `cf` = sign centre, front = -Z. Returns the board.
function Kit.hangingSign(
	parent: Instance,
	text: string,
	cf: CFrame,
	size: Vector3,
	board: Color3,
	sub: string?,
	name: string?
): Part
	local arm = Kit.box(
		parent,
		"SignBracket",
		cf * CFrame.new(0, size.Y / 2 + 1.4, 0),
		Vector3.new(size.X + 1.6, 0.4, 0.4),
		Kit.BLACK,
		Enum.Material.Metal
	)
	arm.CastShadow = false
	for _, sx in { -1, 1 } do
		Kit.box(
			parent,
			"SignChain",
			cf * CFrame.new(sx * (size.X / 2 - 0.8), size.Y / 2 + 0.7, 0),
			Vector3.new(0.15, 1.4, 0.15),
			Kit.STEEL_DARK,
			Enum.Material.Metal
		)
	end
	local s =
		Util.Sign(parent, text, size, cf, { Name = name or "Sign", BoardColor = board, SubText = sub, Decor = true })
	return s
end

-- Props ---------------------------------------------------------------------------------------

function Kit.crate(parent: Instance, cf: CFrame, s: number, color: Color3?)
	local c = color or Kit.WOOD
	Kit.box(parent, "Crate", cf, Vector3.new(s, s, s), c, Enum.Material.WoodPlanks)
	Kit.box(
		parent,
		"CrateBand",
		cf,
		Vector3.new(s + 0.1, s * 0.22, s + 0.1),
		c:Lerp(Color3.new(0, 0, 0), 0.35),
		Enum.Material.Wood
	)
end

function Kit.sack(parent: Instance, cf: CFrame, s: number, color: Color3?)
	local c = color or rgb(222, 196, 150)
	Kit.box(parent, "Sack", cf * CFrame.new(0, s * 0.45, 0), Vector3.new(s, s * 0.9, s * 0.7), c, Enum.Material.Fabric)
	Kit.ball(parent, "SackTop", (cf * CFrame.new(0, s * 0.95, 0)).Position, s * 0.45, c:Lerp(Color3.new(0, 0, 0), 0.15))
end

function Kit.barrel(parent: Instance, cf: CFrame, h: number, d: number, color: Color3?)
	Kit.cyl(parent, "Barrel", cf * CFrame.new(0, h / 2, 0), h, d, color or Kit.WOOD, Enum.Material.Wood)
	for _, y in { 0.2, 0.8 } do
		Kit.cyl(parent, "Hoop", cf * CFrame.new(0, h * y, 0), h * 0.08, d + 0.1, Kit.STEEL_DARK, Enum.Material.Metal)
	end
end

function Kit.cooler(parent: Instance, cf: CFrame, color: Color3)
	Kit.box(parent, "Cooler", cf * CFrame.new(0, 0.8, 0), Vector3.new(3, 1.6, 2), color)
	Kit.box(parent, "CoolerLid", cf * CFrame.new(0, 1.75, 0), Vector3.new(3.1, 0.35, 2.1), Kit.TRIM)
	Kit.box(parent, "CoolerHandle", cf * CFrame.new(0, 2.1, 0), Vector3.new(1.6, 0.25, 0.3), Kit.NAVY)
end

-- Small palm (for planters). `pos` = base of the trunk.
function Kit.palm(parent: Instance, pos: Vector3, height: number, rng: Random)
	local m = Kit.model(parent, "PlanterPalm")
	local lean = rng:NextNumber(-8, 8)
	local yaw = rng:NextNumber(0, 360)
	local base = CFrame.new(pos) * CFrame.Angles(0, rad(yaw), 0) * CFrame.Angles(rad(lean), 0, 0)
	local segs = 3
	local seg = height / segs
	for i = 0, segs - 1 do
		local d = 1.3 - i * 0.18
		Kit.cyl(
			m,
			"Trunk",
			base * CFrame.Angles(rad(i * 3), 0, 0) * CFrame.new(0, seg * (i + 0.5), 0),
			seg + 0.2,
			d,
			if i % 2 == 0 then rgb(150, 110, 70) else rgb(128, 92, 58),
			Enum.Material.Wood
		)
	end
	local top = (base * CFrame.Angles(rad(segs * 3), 0, 0) * CFrame.new(0, height, 0)).Position
	local fronds = 5
	for k = 0, fronds - 1 do
		local a = k * 360 / fronds + rng:NextNumber(-12, 12)
		local len = height * rng:NextNumber(0.55, 0.7)
		Kit.box(
			m,
			"Frond",
			CFrame.new(top) * CFrame.Angles(0, rad(a), 0) * CFrame.Angles(rad(-28), 0, 0) * CFrame.new(0, 0, -len / 2),
			Vector3.new(len * 0.32, 0.25, len),
			if k % 2 == 0 then Kit.LEAF else Kit.LEAF_DARK,
			Enum.Material.Grass
		)
	end
	Kit.ball(m, "Coconut", top + Vector3.new(0.4, -0.5, 0.2), 0.9, rgb(120, 80, 50))
	return m
end

-- Flower clump: stem-less bloom balls on a leafy mound.
function Kit.flowers(parent: Instance, pos: Vector3, rng: Random, colors: { Color3 }, n: number)
	Kit.ball(parent, "Shrub", pos + Vector3.new(0, 0.3, 0), 2.2, Kit.LEAF_DARK, Enum.Material.Grass)
	for _ = 1, n do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.3, 0.9)
		Kit.ball(
			parent,
			"Bloom",
			pos + Vector3.new(math.cos(a) * r, rng:NextNumber(0.9, 1.4), math.sin(a) * r),
			rng:NextNumber(0.55, 0.8),
			colors[rng:NextInteger(1, #colors)]
		)
	end
end

-- Tiki torch. `flame` = Neon flame shown at night.
function Kit.torch(parent: Instance, pos: Vector3, height: number): Part
	Kit.cyl(
		parent,
		"TorchPole",
		CFrame.new(pos + Vector3.new(0, height / 2, 0)),
		height,
		0.45,
		Kit.BAMBOO,
		Enum.Material.Wood
	)
	Kit.cyl(
		parent,
		"TorchCup",
		CFrame.new(pos + Vector3.new(0, height + 0.4, 0)),
		1,
		1,
		Kit.WOOD_DEEP,
		Enum.Material.Wood
	)
	local flame = Kit.neon(
		parent,
		"TorchFlame",
		CFrame.new(pos + Vector3.new(0, height + 1.4, 0)) * CFrame.Angles(0, rad(45), 0),
		Vector3.new(0.7, 1.4, 0.7),
		rgb(255, 140, 30),
		true
	)
	return flame
end

-- Pennant bunting between two points with a gentle sag.
function Kit.bunting(parent: Instance, a: Vector3, b: Vector3, sag: number, colors: { Color3 }, count: number)
	local m = Kit.model(parent, "Bunting")
	local function point(t: number): Vector3
		return a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
	end
	local segs = 4
	for i = 0, segs - 1 do
		local p0, p1 = point(i / segs), point((i + 1) / segs)
		local cf = CFrame.lookAt((p0 + p1) / 2, p1)
		local rope = Kit.box(m, "Rope", cf, Vector3.new(0.12, 0.12, (p1 - p0).Magnitude + 0.1), Kit.TRIM)
		rope.CastShadow = false
	end
	local dir = (b - a) * Vector3.new(1, 0, 1)
	for i = 1, count do
		local t = i / (count + 1)
		local p = point(t)
		local cf = CFrame.lookAt(p, p + Vector3.new(-dir.Z, 0, dir.X)) -- face sideways
		Kit.wedge(
			m,
			"Pennant",
			cf * CFrame.new(0, -0.8, 0) * CFrame.Angles(0, 0, rad(180)) * CFrame.Angles(0, rad(90), 0),
			Vector3.new(0.1, 1.6, 1.3),
			colors[(i - 1) % #colors + 1],
			Enum.Material.Fabric
		)
	end
	return m
end

-- Flag on a pole; the cloth is an AmbientSway model hinged at the pole.
function Kit.flag(parent: Instance, pos: Vector3, height: number, yaw: number, c1: Color3, c2: Color3)
	local m = Kit.model(parent, "Flag")
	Kit.cyl(
		m,
		"FlagPole",
		CFrame.new(pos + Vector3.new(0, height / 2, 0)),
		height,
		0.5,
		Kit.TRIM,
		Enum.Material.Metal,
		true
	)
	Kit.box(m, "FlagFoot", CFrame.new(pos + Vector3.new(0, 0.3, 0)), Vector3.new(1.6, 0.6, 1.6), Kit.NAVY)
	Kit.ball(m, "Finial", pos + Vector3.new(0, height + 0.4, 0), 0.9, C.Gold)
	local cloth = Kit.model(m, "Cloth")
	local hinge = CFrame.new(pos + Vector3.new(0, height - 2, 0)) * CFrame.Angles(0, rad(yaw), 0)
	Kit.box(cloth, "FlagCloth", hinge * CFrame.new(2.3, 0, 0), Vector3.new(4.4, 2.8, 0.12), c1, Enum.Material.Fabric)
	Kit.box(cloth, "FlagStripe", hinge * CFrame.new(2.3, 0, 0), Vector3.new(4.42, 0.8, 0.14), c2, Enum.Material.Fabric)
	Kit.ambient(cloth, "AmbientSway", hinge, { SwayDegrees = 6, SwayPeriod = 3.2 })
	return m
end

-- Build a shared model (Models.Shovel / Pet / Backpack ...) as anchored, non-colliding decor.
-- Returns nil if the builder fails (decor only: never fatal, never warns).
function Kit.display(builder: (string) -> Model, id: string, parent: Instance, cf: CFrame, scale: number?): Model?
	local ok, result = pcall(builder, id)
	if not ok or typeof(result) ~= "Instance" or not result:IsA("Model") then
		return nil
	end
	local model = result :: Model
	Util.Finish(model, true)
	for _, d in model:GetDescendants() do
		if d:IsA("Light") or d:IsA("ParticleEmitter") then
			d:Destroy() -- hub light / emitter budget
		end
	end
	if scale and scale ~= 1 then
		pcall(function()
			model:ScaleTo(scale)
		end)
	end
	model:PivotTo(cf)
	local bbCF, bbSize = model:GetBoundingBox()
	local bottom = bbCF.Position.Y - bbSize.Y / 2
	model:PivotTo(cf + Vector3.new(0, cf.Position.Y - bottom, 0))
	model.Parent = parent
	return model
end

-- Steel lattice (TrussPart, sizes snap to 2 studs). Axis = cf's Y axis.
function Kit.truss(parent: Instance, name: string, cf: CFrame, length: number, color: Color3): TrussPart
	local t = Instance.new("TrussPart")
	t.Name = name
	t.Anchored = true
	t.Size = Vector3.new(2, length, 2)
	t.CFrame = cf
	t.Color = color
	t.Material = Enum.Material.Metal
	t.CanCollide = false
	t.CanQuery = false
	t.CanTouch = false
	t.CastShadow = true
	t.Parent = parent
	return t
end

return Kit
