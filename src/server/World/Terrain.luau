--!strict
--[[
	Terrain — material colours, the beach surface, the ocean and the layered underground block
	under the dig zone. Layer bands come from Config.Layers (snapped to the 4-stud voxel grid).

	Underground: one layered block, X in [-STRIP_HALF_X, STRIP_HALF_X], Z in
	[STRIP_Z_SEA, STRIP_Z_INLAND], Y from BOTTOM_Y to SURFACE_Y. It is the dig zone plus a WALL of
	solid layers on every side; the server clamps all carving to the dig zone, so the walls (and
	the hub / ocean beyond them) never break.

	FillLayered(min, max) refills any box with the right layer materials (tide refills).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)

local terrain = Workspace.Terrain
local S = Layout.SURFACE_Y
local rgb = Color3.fromRGB

local TerrainBuilder = {}

export type Band = { Top: number, Bottom: number, Material: Enum.Material }

-- Layer bands in world Y, top to bottom, snapped to the voxel grid.
local function computeBands(): { Band }
	local bands: { Band } = {}
	for i, layer in Config.Layers do
		local top = if i == 1 then S else Layout.SnapY(S - layer.DepthStart)
		local bottom = if i == #Config.Layers then Layout.BOTTOM_Y else Layout.SnapY(S - layer.DepthEnd)
		if top > bottom then
			table.insert(bands, { Top = top, Bottom = bottom, Material = layer.Material })
		end
	end
	return bands
end

TerrainBuilder.Bands = computeBands()

local function fillBox(minV: Vector3, maxV: Vector3, material: Enum.Material)
	local size = maxV - minV
	if size.X <= 0 or size.Y <= 0 or size.Z <= 0 then
		return
	end
	terrain:FillBlock(CFrame.new((minV + maxV) / 2), size, material)
end

function TerrainBuilder.ApplyColors()
	for _, layer in Config.Layers do
		terrain:SetMaterialColor(layer.Material, layer.Color)
	end
	-- Scenery-only materials (no layer uses these).
	terrain:SetMaterialColor(Enum.Material.Grass, rgb(110, 214, 92))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, rgb(86, 196, 88))
	terrain:SetMaterialColor(Enum.Material.Cobblestone, rgb(236, 206, 156))
	terrain:SetMaterialColor(Enum.Material.Concrete, rgb(250, 236, 206))

	terrain.WaterColor = rgb(24, 178, 226)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.45
	terrain.WaterWaveSize = 0.3
	terrain.WaterWaveSpeed = 12
	-- (Terrain.Decoration is NotScriptable: setting it errors at runtime. Leave it to the place.)
end

-- Beach, path, plaza, dunes and ocean. Synchronous (cheap).
function TerrainBuilder.BuildSurface(rng: Random)
	local hx = Layout.TERRAIN_HALF_X
	local sand = Enum.Material.Sand
	local seabedTop = Layout.SEABED_Y + 4 -- 1008

	-- Ocean water first; sand written afterwards overwrites it where solid.
	fillBox(
		Vector3.new(-hx, Layout.SEABED_Y, Layout.OCEAN_FAR_Z),
		Vector3.new(hx, Layout.WATER_Y, Layout.BEACH_FLAT_END_Z + 4),
		Enum.Material.Water
	)
	-- Seabed
	fillBox(
		Vector3.new(-hx, Layout.SEABED_Y - 8, Layout.OCEAN_FAR_Z),
		Vector3.new(hx, seabedTop, Layout.BEACH_SLOPE_END_Z),
		sand
	)
	-- Flat beach / land slab at surface height
	fillBox(Vector3.new(-hx, S - 16, Layout.BEACH_FLAT_END_Z), Vector3.new(hx, S, Layout.TERRAIN_NORTH_Z), sand)
	-- Beach slope: 4-stud slices whose height falls linearly (smooth terrain blends the steps).
	local z = Layout.BEACH_FLAT_END_Z
	local span = Layout.BEACH_FLAT_END_Z - Layout.BEACH_SLOPE_END_Z
	while z > Layout.BEACH_SLOPE_END_Z do
		local t = (Layout.BEACH_FLAT_END_Z - (z - 2)) / span
		local top = S + (seabedTop - S) * t
		fillBox(Vector3.new(-hx, Layout.SEABED_Y - 8, z - 4), Vector3.new(hx, top, z), sand)
		z -= 4
	end

	-- Path from the boardwalk to the hub (cobblestone) and the round hub plaza (concrete),
	-- painted into the top voxels.
	local hub = Layout.HUB_CENTER
	fillBox(Vector3.new(-8, S - 4, Layout.BOARDWALK_Z1), Vector3.new(8, S, hub.Z), Enum.Material.Cobblestone)
	terrain:FillCylinder(CFrame.new(hub.X, S - 2, hub.Z), 4, Layout.HUB_RADIUS, Enum.Material.Concrete)

	-- Grassy dunes behind the hub
	fillBox(Vector3.new(-hx, S - 4, Layout.DUNES_Z0), Vector3.new(hx, S, Layout.TERRAIN_NORTH_Z), Enum.Material.Grass)
	for _ = 1, 34 do
		local x = rng:NextNumber(-hx + 20, hx - 20)
		local dz = rng:NextNumber(Layout.DUNES_Z0 + 14, Layout.TERRAIN_NORTH_Z - 4)
		local r = rng:NextNumber(10, 22)
		local mat = if rng:NextNumber() < 0.5 then Enum.Material.Grass else Enum.Material.LeafyGrass
		terrain:FillBall(Vector3.new(x, S - r * 0.55, dz), r, mat)
	end
	-- Sandy dunes on the far east/west beach (outside the playable boundary)
	for _ = 1, 10 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x = side * rng:NextNumber(Layout.BOUND_HALF_X + 20, hx - 20)
		local dz = rng:NextNumber(Layout.STRIP_Z_INLAND + 20, 100)
		local r = rng:NextNumber(10, 18)
		terrain:FillBall(Vector3.new(x, S - r * 0.6, dz), r, sand)
	end
end

-- Fill the layered materials into the box [minV, maxV] (Y clamped to the layer range).
-- Synchronous: callers chunk large boxes themselves.
function TerrainBuilder.FillLayered(minV: Vector3, maxV: Vector3)
	for _, band in TerrainBuilder.Bands do
		local y0 = math.max(minV.Y, band.Bottom)
		local y1 = math.min(maxV.Y, band.Top)
		if y1 > y0 then
			fillBox(Vector3.new(minV.X, y0, minV.Z), Vector3.new(maxV.X, y1, maxV.Z), band.Material)
		end
	end
end

local function stripBand(band: Band, x0: number, x1: number)
	fillBox(
		Vector3.new(x0, band.Bottom, Layout.STRIP_Z_SEA),
		Vector3.new(x1, band.Top, Layout.STRIP_Z_INLAND),
		band.Material
	)
end

-- Top bands (layers 1-2) synchronously, so the surface is solid immediately.
function TerrainBuilder.BuildStripTops()
	local hx = Layout.STRIP_HALF_X
	for i = 1, math.min(2, #TerrainBuilder.Bands) do
		stripBand(TerrainBuilder.Bands[i], -hx, hx)
	end
end

-- The remaining bands, chunked along X with a yield per chunk (call in a task).
function TerrainBuilder.BuildStripsDeep()
	local hx = Layout.STRIP_HALF_X
	local chunk = 112
	for i = 3, #TerrainBuilder.Bands do
		local band = TerrainBuilder.Bands[i]
		local x = -hx
		while x < hx do
			local x1 = math.min(x + chunk, hx)
			stripBand(band, x, x1)
			x = x1
			task.wait()
		end
	end
end

return TerrainBuilder
