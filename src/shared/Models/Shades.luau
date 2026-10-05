--!strict
--[[
	Shades — placeable shade items (Config.Shades), chunky low-poly cartoon style.
	PrimaryPart = invisible "Root" at the bottom-centre (the ground point under the pole).
	Front is -Z. Everything is anchored; only the poles/posts are CanCollide (players walk under
	the canopy and bump into the poles). The canopy underside sits at ShadeDef.Height studs so it
	visibly covers the shaded circle (gameplay Radius is a little wider than the cloth).
	Model attributes: ShadeId, Radius, Height (handy for placement ghosts / owner labels).
]]

local Types = require(script.Parent.Parent.Types)
local Config = require(script.Parent.Parent.Config)
local Build = require(script.Parent.Build)

local ShadesModels = {}

local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB
local PI = math.pi
local M = Enum.Material

local WHITE = rgb(255, 255, 255)
local SAND = rgb(255, 222, 140)
local WOOD = rgb(176, 120, 72)
local WOOD_DARK = rgb(130, 85, 50)
local METAL = rgb(235, 235, 240)
local GOLD = rgb(255, 205, 40)
local STRAW = rgb(225, 190, 110)

local solid = Build.solid

type Look = { Color: Color3, Accent: Color3 }
type Builder = (m: Model, def: Types.ShadeDef, look: Look) -> ()

-- Faceted cone / pyramid roof: n triangles from the rim (circumradius R at height rimY) to the
-- apex. `offset` rotates the facets (-PI/4 with n = 4 gives an axis-aligned square roof).
local function roof(
	m: Model,
	name: string,
	centre: Vector3,
	rimY: number,
	apexY: number,
	R: number,
	n: number,
	offset: number,
	colors: { Color3 },
	material: Enum.Material?
): { { Base: Vector3, Tangent: Vector3, Width: number } }
	local apex = centre + V(0, apexY, 0)
	local apothem = R * math.cos(PI / n)
	local width = 2 * R * math.sin(PI / n)
	local edges = {}
	for k = 0, n - 1 do
		local a = offset + (k + 0.5) / n * PI * 2
		local base = centre + V(apothem * math.cos(a), rimY, apothem * math.sin(a))
		local tangent = V(-math.sin(a), 0, math.cos(a))
		Build.triPts(m, name, base, apex, tangent, width + 0.06, 0.14, colors[k % #colors + 1], material)
		table.insert(edges, { Base = base, Tangent = tangent, Width = width })
	end
	return edges
end

-- Hanging valance / scallops along every roof edge.
local function valance(
	m: Model,
	edges: { { Base: Vector3, Tangent: Vector3, Width: number } },
	depth: number,
	colors: { Color3 },
	scallops: number,
	material: Enum.Material?
)
	for i, e in edges do
		local strip = e.Width / scallops
		for s = 0, scallops - 1 do
			local along = (s + 0.5) * strip - e.Width / 2
			local pos = e.Base + e.Tangent * along - V(0, depth / 2, 0)
			local col = colors[(i + s) % #colors + 1]
			local cf = CFrame.fromMatrix(pos, e.Tangent, Vector3.yAxis)
			-- little pennant: a block with a downward triangle tip
			Build.part(m, "Valance", V(strip * 0.96, depth * 0.55, 0.1), cf * CF(0, depth * 0.22, 0), col, material)
			Build.tri(
				m,
				"Valance",
				cf * CF(0, -depth * 0.28, 0) * CFrame.Angles(0, 0, PI),
				strip * 0.96,
				depth * 0.45,
				0.1,
				col,
				material
			)
		end
	end
end

local function pole(m: Model, a: Vector3, b: Vector3, d: number, color: Color3, material: Enum.Material?): BasePart
	return solid(Build.cylBetween(m, "Pole", a, b, d, color, material))
end

local function mound(m: Model, size: number)
	Build.ellipsoid(m, "Mound", V(size, size * 0.3, size), CF(), SAND, M.Sand)
end

-- Builders ----------------------------------------------------------------------------------------

local builders: { [string]: Builder } = {}

builders.Umbrella = function(m, def, look)
	local H = def.Height
	local R = def.Radius * 0.75
	mound(m, 1.6)
	pole(m, V(0, 0, 0), V(0, H + 1.6, 0), 0.32, METAL)
	local edges = roof(m, "Canopy", Vector3.zero, H, H + 1.5, R, 10, 0, { look.Color, look.Accent }, M.Fabric)
	valance(m, edges, 0.5, { look.Color, look.Accent }, 1, M.Fabric)
	Build.ball(m, "Finial", 0.5, CF(0, H + 1.75, 0), look.Color)
	-- hub ring + a few ribs under the canopy
	Build.cyl(m, "Hub", 0.35, 0.6, CF(0, H - 0.4, 0), WHITE)
end

builders.Striped = function(m, def, look)
	local H = def.Height
	local R = def.Radius * 0.72
	mound(m, 1.8)
	for i = 0, 3 do
		local y0 = i * (H + 1.6) / 4
		local y1 = (i + 1) * (H + 1.6) / 4
		pole(m, V(0, y0, 0), V(0, y1, 0), 0.36, if i % 2 == 0 then WHITE else look.Color)
	end
	local stripes = { look.Color, WHITE, look.Accent, WHITE }
	local edges = roof(m, "Canopy", Vector3.zero, H, H + 1.8, R, 12, 0, stripes, M.Fabric)
	valance(m, edges, 0.6, { look.Accent, look.Color }, 2, M.Fabric)
	Build.ball(m, "Finial", 0.6, CF(0, H + 2.05, 0), look.Accent)
	Build.cyl(m, "Hub", 0.4, 0.7, CF(0, H - 0.4, 0), WHITE)
end

builders.Tarp = function(m, def, look)
	local H = def.Height
	local sx, sz = def.Radius * 0.6, def.Radius * 0.5
	local corners = { V(-sx, 0, -sz), V(sx, 0, -sz), V(-sx, 0, sz), V(sx, 0, sz) }
	for i, c in corners do
		local top = H + (if c.Z < 0 then 0.9 else 0) -- front edge higher: slanted tarp
		pole(m, c, c + V(0, top + 0.4, 0), 0.5, if i % 2 == 0 then WOOD else WOOD_DARK, M.Wood)
		Build.ball(m, "PoleCap", 0.6, CF(c + V(0, top + 0.45, 0)), WOOD_DARK, M.Wood)
		-- guy rope to a stake outside the corner
		local out = V(math.sign(c.X), 0, math.sign(c.Z))
		local stake = c + out * 2.2
		Build.cylBetween(m, "Rope", c + V(0, top, 0), stake + V(0, 0.4, 0), 0.08, rgb(240, 230, 200))
		Build.part(m, "Stake", V(0.3, 0.8, 0.3), CF(stake + V(0, 0.3, 0)), WOOD_DARK, M.Wood)
	end
	-- tarp sheet, tilted (front higher)
	local front = V(0, H + 0.9, -sz)
	local back = V(0, H, sz)
	local mid = front:Lerp(back, 0.5)
	local depth = (back - front).Magnitude
	local tarpCf = CFrame.lookAt(mid, mid + (back - front), Vector3.yAxis)
	Build.part(m, "Tarp", V(sx * 2 + 1.2, 0.18, depth + 1.2), tarpCf, look.Color, M.Fabric)
	-- two lighter stripes across the sheet
	for _, t in { -0.25, 0.25 } do
		Build.part(
			m,
			"TarpStripe",
			V(sx * 2 + 1.22, 0.2, 0.9),
			tarpCf * CF(0, 0, t * depth),
			Build.lighten(look.Color, 0.45),
			M.Fabric
		)
	end
	-- palm leaves tucked on top for the island look
	for k = 0, 2 do
		local a = k / 3 * PI * 2 + 0.3
		local base = mid + V(0, 0.25, 0)
		local tip = base + V(math.cos(a) * 3.2, 0.3, math.sin(a) * 3.2)
		Build.triPts(m, "Leaf", base, tip, V(-math.sin(a), 0, math.cos(a)), 1.3, 0.12, rgb(70, 190, 95))
	end
end

builders.Canopy = function(m, def, look)
	local H = def.Height
	local s = def.Radius * 0.62
	for _, c in { V(-s, 0, -s), V(s, 0, -s), V(-s, 0, s), V(s, 0, s) } do
		pole(m, c, c + V(0, H + 0.2, 0), 0.4, METAL, M.Metal)
		Build.part(m, "Foot", V(0.9, 0.2, 0.9), CF(c + V(0, 0.1, 0)), rgb(120, 120, 130), M.Metal)
	end
	-- frame
	for _, pair in { { V(-s, H, -s), V(s, H, -s) }, { V(-s, H, s), V(s, H, s) } } do
		Build.cylBetween(m, "Frame", pair[1], pair[2], 0.25, METAL, M.Metal)
	end
	for _, pair in { { V(-s, H, -s), V(-s, H, s) }, { V(s, H, -s), V(s, H, s) } } do
		Build.cylBetween(m, "Frame", pair[1], pair[2], 0.25, METAL, M.Metal)
	end
	local R = s / math.cos(PI / 4)
	local edges = roof(m, "Canopy", Vector3.zero, H + 0.1, H + 2.6, R, 4, -PI / 4, { look.Color }, M.Fabric)
	valance(m, edges, 0.9, { look.Color, look.Accent }, 6, M.Fabric)
	-- bunting between front poles
	local n = 7
	for i = 0, n - 1 do
		local t = (i + 0.5) / n
		local x = -s + t * 2 * s
		local sag = math.sin(t * PI) * 0.7
		local col = ({ rgb(255, 90, 90), rgb(255, 210, 60), rgb(60, 170, 255), rgb(90, 210, 120) })[i % 4 + 1]
		Build.tri(m, "Bunting", CF(x, H - 1.2 - sag, -s - 0.1) * CFrame.Angles(0, 0, PI), 0.8, 0.8, 0.08, col)
	end
	Build.cylBetween(m, "BuntingRope", V(-s, H - 0.75, -s - 0.1), V(s, H - 0.75, -s - 0.1), 0.05, WHITE)
end

builders.Cabana = function(m, def, look)
	local H = def.Height
	local s = def.Radius * 0.55
	for _, c in { V(-s, 0, -s), V(s, 0, -s), V(-s, 0, s), V(s, 0, s) } do
		pole(m, c, c + V(0, H + 0.4, 0), 0.8, WOOD, M.Wood)
		-- tied-back curtain on each post
		local inward = -V(math.sign(c.X), 0, math.sign(c.Z)) * 0.6
		Build.part(
			m,
			"Curtain",
			V(0.9, H - 1.4, 0.9),
			CF(c + inward + V(0, (H - 1.4) / 2 + 0.9, 0)),
			look.Accent,
			M.Fabric
		)
		Build.cyl(m, "Tie", 0.3, 1.05, CF(c + inward + V(0, H * 0.45, 0)), GOLD)
	end
	-- beams
	for _, pair in { { V(-s, H, -s), V(s, H, -s) }, { V(-s, H, s), V(s, H, s) } } do
		Build.beam(m, "Beam", pair[1], pair[2], 0.7, 0.7, WOOD_DARK, M.Wood, Vector3.zAxis)
	end
	-- thatched pyramid roof (two layers for a chunky straw look)
	local R = (s + 1.4) / math.cos(PI / 4)
	local edges =
		roof(m, "Thatch", Vector3.zero, H + 0.3, H + 4, R, 4, -PI / 4, { STRAW, Build.darken(STRAW, 0.1) }, M.Grass)
	roof(m, "Thatch", Vector3.zero, H + 1.6, H + 4.4, R * 0.62, 4, -PI / 4, { Build.lighten(STRAW, 0.1) }, M.Grass)
	valance(m, edges, 0.9, { Build.darken(STRAW, 0.15), STRAW }, 7, M.Grass)
	-- tiki top + rug
	Build.ball(m, "Topper", 0.9, CF(0, H + 4.3, 0), rgb(255, 120, 60))
	Build.part(m, "Rug", V(s * 1.6, 0.08, s * 1.6), CF(0, 0.05, 0), look.Accent, M.Fabric)
	Build.part(m, "RugStripe", V(s * 1.62, 0.09, 0.6), CF(0, 0.06, 0), WHITE, M.Fabric)
end

builders.Tent = function(m, def, look)
	local H = def.Height
	local R = def.Radius * 0.62
	local n = 8
	pole(m, V(0, 0, 0), V(0, H + 3.4, 0), 0.5, GOLD, M.Metal)
	for k = 0, n - 1 do
		local a = (k / n) * PI * 2
		local c = V(math.cos(a) * R, 0, math.sin(a) * R)
		pole(m, c, c + V(0, H, 0), 0.38, GOLD, M.Metal)
		Build.ball(m, "PoleCap", 0.6, CF(c + V(0, H + 0.1, 0)), GOLD, M.Metal)
		-- drapes on alternating poles
		if k % 2 == 0 then
			Build.part(
				m,
				"Drape",
				V(1.1, H - 1, 0.25),
				CFrame.lookAt(c + V(0, (H - 1) / 2 + 0.8, 0), V(0, (H - 1) / 2 + 0.8, 0)) * CF(0, 0, 0.4),
				Build.darken(look.Color, 0.05),
				M.Fabric
			)
		end
	end
	-- the polygon roof: corners at the poles (offset so facets meet at pole tops)
	local edges = roof(
		m,
		"Canopy",
		Vector3.zero,
		H,
		H + 3.2,
		R,
		n,
		-PI / n,
		{ look.Color, Build.darken(look.Color, 0.06) },
		M.Fabric
	)
	valance(m, edges, 0.8, { look.Accent, look.Color }, 3, M.Fabric)
	Build.ball(m, "Finial", 0.9, CF(0, H + 3.6, 0), GOLD, M.Metal)
	Build.part(m, "Flag", V(0.08, 0.7, 1.2), CF(0, H + 4.6, 0.6), rgb(255, 90, 120), M.Fabric)
	Build.cylBetween(m, "FlagPole", V(0, H + 3.6, 0), V(0, H + 5.1, 0), 0.1, GOLD)
end

builders.Pavilion = function(m, def, look)
	local H = def.Height
	local R = def.Radius * 0.58
	local n = 8
	-- low marble-ish base ring (decorative, non-colliding so you can walk on the sand)
	Build.cyl(m, "Base", 0.3, R * 2 + 1.5, CF(0, 0.15, 0), rgb(245, 235, 215), M.Marble)
	for k = 0, n - 1 do
		local a = (k / n) * PI * 2
		local c = V(math.cos(a) * R, 0, math.sin(a) * R)
		pole(m, c, c + V(0, H, 0), 1, rgb(250, 245, 235), M.Marble)
		Build.part(m, "Capital", V(1.6, 0.5, 1.6), CF(c + V(0, H + 0.1, 0)), GOLD, M.Metal)
		Build.part(m, "Plinth", V(1.6, 0.5, 1.6), CF(c + V(0, 0.45, 0)), GOLD, M.Metal)
	end
	-- ring beam
	for k = 0, n - 1 do
		local a0 = (k / n) * PI * 2
		local a1 = ((k + 1) / n) * PI * 2
		local p0 = V(math.cos(a0) * R, H + 0.5, math.sin(a0) * R)
		local p1 = V(math.cos(a1) * R, H + 0.5, math.sin(a1) * R)
		Build.beam(m, "RingBeam", p0, p1, 0.8, 0.8, GOLD, M.Metal)
	end
	-- two-tier roof
	local edges = roof(
		m,
		"Roof",
		Vector3.zero,
		H + 0.8,
		H + 3.4,
		R + 1.4,
		n,
		-PI / n,
		{ look.Color, Build.darken(look.Color, 0.12) },
		M.Fabric
	)
	valance(m, edges, 0.9, { look.Accent, look.Color }, 3, M.Fabric)
	roof(m, "Roof", Vector3.zero, H + 3, H + 5.4, R * 0.55, n, -PI / n, { look.Color }, M.Fabric)
	-- crown
	Build.ball(m, "Orb", 1.4, CF(0, H + 5.8, 0), GOLD, M.Metal)
	for k = 0, 4 do
		local a = (k / 5) * PI * 2
		Build.spike(
			m,
			"CrownSpike",
			V(math.cos(a) * 0.5, H + 6.1, math.sin(a) * 0.5),
			V(math.cos(a) * 0.7, H + 7.1, math.sin(a) * 0.7),
			0.5,
			GOLD,
			M.Metal
		)
	end
	local gem = Build.ball(m, "Gem", 0.5, CF(0, H + 6.6, 0), rgb(255, 80, 200), M.Neon)
	Build.glow(gem, rgb(255, 120, 220), 1, 10)
end

local function fallback(m: Model, def: Types.ShadeDef, look: Look)
	builders.Umbrella(m, def, look)
end

-- Public --------------------------------------------------------------------------------------------

local DEFAULT_DEF: Types.ShadeDef = {
	Id = "unknown",
	Name = "Shade",
	Price = 0,
	Radius = 6,
	Cooling = 1,
	Height = 7.5,
	Description = "",
	Look = {},
}

function ShadesModels.Build(id: string): Model
	local def = Config.GetShade(id) or DEFAULT_DEF
	local m = Build.model(id)
	Build.root(m, CFrame.identity, V(1, 0.1, 1))
	local raw = def.Look
	local look: Look = {
		Color = if typeof(raw.Color) == "Color3" then raw.Color else rgb(255, 80, 90),
		Accent = if typeof(raw.Accent) == "Color3" then raw.Accent else WHITE,
	}
	local style = if type(raw.Style) == "string" then raw.Style else "Umbrella"
	local builder: Builder = builders[style] or fallback
	builder(m, def, look)
	m:SetAttribute("ShadeId", id)
	m:SetAttribute("Radius", def.Radius)
	m:SetAttribute("Height", def.Height)
	return m
end

return ShadesModels
