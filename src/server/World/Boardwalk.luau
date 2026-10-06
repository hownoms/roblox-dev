--!strict
--[[
	Boardwalk — the wooden promenade between the dig zone and the hub (players spawn on it), the
	"dig anywhere" signs and zone-end flags, the big title sign with a giant shovel in the dunes,
	the photo-spot pier running from the wet sand out to sea, and the invisible boundary walls.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)
local Util = require(script.Parent.Util)

local C = Config.Theme.Colors
local rgb = Color3.fromRGB
local S = Layout.SURFACE_Y

local WOOD_A = rgb(184, 132, 86)
local WOOD_B = rgb(168, 118, 74)
local WOOD_DARK = rgb(120, 82, 52)
local WHITE = Color3.new(1, 1, 1)

local Boardwalk = {}

local HUB_GAP = 96 -- no inland railing within this |x| (the way up to the hub)

local function lamp(parent: Instance, ground: Vector3)
	Util.Part({
		Name = "LampPost",
		Size = Vector3.new(0.8, 10, 0.8),
		CFrame = CFrame.new(ground + Vector3.new(0, 5, 0)),
		Color = rgb(60, 70, 90),
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	Util.Ball(
		parent,
		"LampGlobe",
		ground + Vector3.new(0, 10.6, 0),
		1.8,
		rgb(230, 170, 100),
		Enum.Material.SmoothPlastic
	)
end

local function buildPromenade(parent: Instance)
	local S = Layout.DECK_TOP - 1 -- deck base: everything below is built relative to it
	local m = Util.Model("Promenade", parent)
	local z0, z1 = Layout.BOARDWALK_Z0, Layout.BOARDWALK_Z1
	local zc, depth = (z0 + z1) / 2, z1 - z0
	local half = Layout.BOUND_HALF_X - 4
	local seg = 16
	local x = -half
	local i = 0
	while x < half do
		local x1 = math.min(x + seg, half)
		i += 1
		Util.Part({
			Name = "Deck",
			Size = Vector3.new(x1 - x, 1, depth),
			CFrame = CFrame.new((x + x1) / 2, S + 0.5, zc),
			Color = if i % 2 == 0 then WOOD_A else WOOD_B,
			Material = Enum.Material.WoodPlanks,
			Parent = m,
		})
		-- Railing post on the inland edge (open in front of the hub)
		if math.abs(x) >= HUB_GAP then
			Util.Part({
				Name = "RailPost",
				Size = Vector3.new(0.7, 3.4, 0.7),
				CFrame = CFrame.new(x, S + 2.7, z1 - 0.4),
				Color = WHITE,
				Parent = m,
			})
		end
		x = x1
	end
	for _, sx in { -1, 1 } do
		local len = half - HUB_GAP
		Util.Part({
			Name = "Rail",
			Size = Vector3.new(len, 0.5, 0.6),
			CFrame = CFrame.new(sx * (HUB_GAP + len / 2), S + 4.2, z1 - 0.4),
			Color = WHITE,
			Parent = m,
		})
	end
	Util.Part({
		Name = "Trim",
		Size = Vector3.new(half * 2, 1.2, 0.8),
		CFrame = CFrame.new(0, S + 0.4, z0 - 0.4),
		Color = C.Ocean,
		Decor = true,
		Parent = m,
	})
	-- Lamps every 32 studs along the sand-side edge, skipping the spawns
	local lx = -half + 8
	while lx < half do
		if math.abs(lx) > 24 then
			lamp(m, Vector3.new(lx, S + 1, z0 + 1.2))
		end
		lx += 32
	end
end

local function buildTitle(parent: Instance)
	local m = Util.Model("TitleSign", parent)
	local p = Layout.TITLE_SIGN
	local base = Util.Facing(p, Vector3.new(p.X, p.Y, 0))
	for _, x in { -20, 20 } do
		Util.Part({
			Name = "Post",
			Size = Vector3.new(1.6, 26, 1.6),
			CFrame = base * CFrame.new(x, 13, 0.8),
			Color = WOOD_DARK,
			Material = Enum.Material.Wood,
			Parent = m,
		})
	end
	local board = Util.Sign(m, "DIG TO THE CORE!", Vector3.new(46, 11, 1.2), base * CFrame.new(0, 21, 0), {
		Name = "TitleBoard",
		BoardColor = C.Ocean,
		SubText = "BEACH SIMULATOR",
	})
	board.CastShadow = true
	Util.Part({
		Name = "TitleFrame",
		Size = Vector3.new(48, 13, 0.8),
		CFrame = base * CFrame.new(0, 21, 0.8),
		Color = C.Gold,
		Parent = m,
	})

	-- Giant shovel stuck in the dunes next to the sign
	local sp = p + Vector3.new(34, 0, 2)
	local tilt = CFrame.new(sp) * CFrame.Angles(0, math.rad(-20), math.rad(-14))
	Util.Part({
		Name = "GiantShovelHandle",
		Size = Vector3.new(1.4, 22, 1.4),
		CFrame = tilt * CFrame.new(0, 14, 0),
		Color = rgb(170, 110, 60),
		Material = Enum.Material.Wood,
		Parent = m,
	})
	Util.Part({
		Name = "GiantShovelGrip",
		Size = Vector3.new(5, 1.4, 1.4),
		CFrame = tilt * CFrame.new(0, 25.5, 0),
		Color = C.Coral,
		Parent = m,
	})
	Util.Part({
		Name = "GiantShovelBlade",
		Size = Vector3.new(7, 8, 1),
		CFrame = tilt * CFrame.new(0, 1.5, 0),
		Color = rgb(200, 210, 225),
		Material = Enum.Material.Metal,
		Reflectance = 0.2,
		Parent = m,
	})
end

local function buildPier(parent: Instance)
	local S = Layout.DECK_TOP - 1 -- deck base (same height as the promenade)
	local m = Util.Model("Pier", parent)
	local hw = Layout.PIER_HALF_W
	local z0, z1 = Layout.PIER_Z0, Layout.PIER_Z1
	local deckY = S + 0.5 -- top at S + 1 = DECK_TOP
	-- Deck segments
	local z = z0
	local i = 0
	while z > z1 do
		local zn = math.max(z - 8, z1)
		i += 1
		Util.Part({
			Name = "Deck",
			Size = Vector3.new(hw * 2, 1, z - zn),
			CFrame = CFrame.new(0, deckY, (z + zn) / 2),
			Color = if i % 2 == 0 then WOOD_A else WOOD_B,
			Material = Enum.Material.WoodPlanks,
			Parent = m,
		})
		z = zn
	end
	-- Pilings every 16 studs and rails
	local postBottom = Layout.SEABED_Y - 4
	z = z0 - 8
	while z > z1 do
		for _, sx in { -1, 1 } do
			local h = S - postBottom
			Util.Cylinder(
				m,
				"Piling",
				Vector3.new(sx * (hw - 0.6), postBottom + h / 2, z),
				h,
				1.6,
				WOOD_DARK,
				Enum.Material.Wood
			)
		end
		z -= 16
	end
	z = z0 - 4
	while z >= z1 do
		for _, sx in { -1, 1 } do
			Util.Part({
				Name = "RailPost",
				Size = Vector3.new(0.6, 3, 0.6),
				CFrame = CFrame.new(sx * (hw - 0.3), S + 2.5, z),
				Color = WHITE,
				Parent = m,
			})
		end
		z -= 8
	end
	local railLen = (z0 - 4) - z1
	for _, sx in { -1, 1 } do
		Util.Part({
			Name = "Rail",
			Size = Vector3.new(0.5, 0.5, railLen),
			CFrame = CFrame.new(sx * (hw - 0.3), S + 4, (z0 - 4 + z1) / 2),
			Color = WHITE,
			Parent = m,
		})
	end

	-- End platform (photo spot)
	local eh, ed = Layout.PIER_END_HALF, Layout.PIER_END_DEPTH
	local ec = Vector3.new(0, S, z1 - ed / 2)
	Util.Part({
		Name = "Platform",
		Size = Vector3.new(eh * 2, 1, ed),
		CFrame = CFrame.new(ec.X, deckY, ec.Z),
		Color = WOOD_A,
		Material = Enum.Material.WoodPlanks,
		Parent = m,
	})
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local p = Vector3.new(sx * (eh - 0.6), 0, ec.Z + sz * (ed / 2 - 0.6))
			local h = S - postBottom
			Util.Cylinder(m, "Piling", Vector3.new(p.X, postBottom + h / 2, p.Z), h, 2, WOOD_DARK, Enum.Material.Wood)
			Util.Part({
				Name = "CornerPost",
				Size = Vector3.new(0.9, 3.4, 0.9),
				CFrame = CFrame.new(p.X, S + 2.7, p.Z),
				Color = WHITE,
				Parent = m,
			})
		end
	end
	-- Rails on the three open sides
	Util.Part({
		Name = "Rail",
		Size = Vector3.new(eh * 2, 0.5, 0.5),
		CFrame = CFrame.new(0, S + 4, ec.Z - ed / 2 + 0.6),
		Color = WHITE,
		Parent = m,
	})
	for _, sx in { -1, 1 } do
		Util.Part({
			Name = "Rail",
			Size = Vector3.new(0.5, 0.5, ed),
			CFrame = CFrame.new(sx * (eh - 0.6), S + 4, ec.Z),
			Color = WHITE,
			Parent = m,
		})
	end

	-- Gazebo
	local gz = ec + Vector3.new(0, 1, -2)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Util.Part({
				Name = "GazeboPost",
				Size = Vector3.new(0.9, 10, 0.9),
				CFrame = CFrame.new(gz + Vector3.new(sx * 6, 5, sz * 6)),
				Color = WHITE,
				Parent = m,
			})
		end
	end
	Util.Part({
		Name = "GazeboRoof",
		Size = Vector3.new(15, 1, 15),
		CFrame = CFrame.new(gz + Vector3.new(0, 10.5, 0)),
		Color = C.Coral,
		Parent = m,
	})
	Util.Part({
		Name = "GazeboRoofTop",
		Size = Vector3.new(9, 1.2, 9),
		CFrame = CFrame.new(gz + Vector3.new(0, 11.6, 0)),
		Color = WHITE,
		Parent = m,
	})
	Util.Ball(m, "GazeboFinial", gz + Vector3.new(0, 12.8, 0), 1.6, C.Gold, Enum.Material.SmoothPlastic)
	Util.Sign(
		m,
		"SUNSET PIER",
		Vector3.new(11, 2.2, 0.5),
		CFrame.lookAt(gz + Vector3.new(0, 8.6, 6.4), gz + Vector3.new(0, 8.6, 20)),
		{
			Name = "PierSign",
			BoardColor = C.Sunset,
		}
	)
	-- Benches facing the sea
	for _, sx in { -1, 1 } do
		local b = gz + Vector3.new(sx * 3.2, 0, -3)
		Util.Part({
			Name = "BenchSeat",
			Size = Vector3.new(4.5, 0.5, 1.6),
			CFrame = CFrame.new(b + Vector3.new(0, 1.6, 0)),
			Color = C.Ocean,
			Parent = m,
		})
		Util.Part({
			Name = "BenchBack",
			Size = Vector3.new(4.5, 1.6, 0.4),
			CFrame = CFrame.new(b + Vector3.new(0, 2.6, 0.8)),
			Color = C.Ocean,
			Parent = m,
		})
		Util.Part({
			Name = "BenchLegs",
			Size = Vector3.new(4, 1.4, 1.2),
			CFrame = CFrame.new(b + Vector3.new(0, 0.7, 0)),
			Color = WHITE,
			Parent = m,
		})
	end
	-- Telescope at the tip
	local tp = Vector3.new(eh - 3, S + 1, ec.Z - ed / 2 + 3)
	Util.Part({
		Name = "TelescopeStand",
		Size = Vector3.new(0.5, 3.4, 0.5),
		CFrame = CFrame.new(tp + Vector3.new(0, 1.7, 0)),
		Color = rgb(60, 70, 90),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	Util.Part({
		Name = "Telescope",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.6, 0.9, 0.9),
		CFrame = CFrame.new(tp + Vector3.new(0, 3.7, 0)) * CFrame.Angles(0, math.rad(90), math.rad(15)),
		Color = C.Gold,
		Material = Enum.Material.Metal,
		Decor = true,
		Parent = m,
	})
	-- Pier lamps
	for _, sx in { -1, 1 } do
		lamp(m, Vector3.new(sx * (eh - 1.5), S + 1, ec.Z + ed / 2 - 2))
		lamp(m, Vector3.new(sx * (hw - 0.8), S + 1, (z0 + z1) / 2))
	end
end

local function buildBoundaries(parent: Instance)
	local f = Util.Folder("Boundaries", parent)
	local hx, zn, zs = Layout.BOUND_HALF_X, Layout.BOUND_NORTH_Z, Layout.BOUND_SOUTH_Z
	local y0, y1 = Layout.SEABED_Y - 10, S + 90
	local h, yc = y1 - y0, (y0 + y1) / 2
	local walls: { { Vector3 } } = {
		{ Vector3.new(4, h, zn - zs), Vector3.new(-hx - 2, yc, (zn + zs) / 2) },
		{ Vector3.new(4, h, zn - zs), Vector3.new(hx + 2, yc, (zn + zs) / 2) },
		{ Vector3.new(hx * 2 + 8, h, 4), Vector3.new(0, yc, zn + 2) },
		{ Vector3.new(hx * 2 + 8, h, 4), Vector3.new(0, yc, zs - 2) },
	}
	for _, w in walls do
		local p = Util.Part({
			Name = "Boundary",
			Size = w[1],
			CFrame = CFrame.new(w[2]),
			Transparency = 1,
			CastShadow = false,
			Parent = f,
		})
		p.CanQuery = false
	end
end

-- "Dig anywhere" signs on the deck and flags marking both ends of the dig zone.
local function buildDigMarkers(parent: Instance)
	local m = Util.Model("DigMarkers", parent)
	local z = Layout.BOARDWALK_Z0 + 2
	for _, x in { -40, 40, -200, 200 } do
		local p = Vector3.new(x, Layout.DECK_TOP, z)
		Util.Part({
			Name = "SignPost",
			Size = Vector3.new(0.8, 5, 0.8),
			CFrame = CFrame.new(p + Vector3.new(0, 2.5, 0.6)),
			Color = WOOD_DARK,
			Material = Enum.Material.Wood,
			Parent = m,
		})
		-- Faces inland so it reads while walking down from the hub.
		Util.Sign(
			m,
			"DIG ANYWHERE!",
			Vector3.new(9, 2.6, 0.4),
			CFrame.lookAt(p + Vector3.new(0, 5.4, 0.6), p + Vector3.new(0, 5.4, 10)),
			{
				Name = "DigSign",
				BoardColor = C.Gold,
				SubText = "ON THE SAND",
			}
		)
	end
	-- Striped flags at the four corners of the dig zone
	for _, sx in { -1, 1 } do
		for _, zEdge in { Layout.DIG_Z_INLAND, Layout.DIG_Z_SEA } do
			local p = Vector3.new(sx * (Layout.DIG_HALF_X + 2), S, zEdge)
			Util.Part({
				Name = "ZoneFlagPole",
				Size = Vector3.new(0.5, 9, 0.5),
				CFrame = CFrame.new(p + Vector3.new(0, 4.5, 0)),
				Color = WHITE,
				Parent = m,
			})
			Util.Wedge({
				Name = "ZoneFlag",
				Size = Vector3.new(0.2, 2.2, 3.4),
				CFrame = CFrame.new(p + Vector3.new(0, 7.6, -sx * 1.7)),
				Color = C.Coral,
				Decor = true,
				Parent = m,
			})
		end
	end
end

function Boardwalk.Build(parent: Instance)
	buildPromenade(parent)
	buildDigMarkers(parent)
	buildTitle(parent)
	buildPier(parent)
	buildBoundaries(parent)
end

return Boardwalk
