--!strict
--[[
	Terrain — material colours, the beach surface, the ocean, the layered underground strips and
	plot refills. Layer bands come from Config.Layers (snapped to the 4-stud voxel grid).

	Underground: one layered block per plot row, X in [-STRIP_HALF_X, STRIP_HALF_X], Z between
	STRIP_INNER_Z and STRIP_OUTER_Z (both signs), Y from BOTTOM_Y to SURFACE_Y. The walls between
	plots are the same layers, so dug shafts always show the right layer; the server enforces
	that only plot columns are diggable.
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
	terrain.Decoration = false
end

-- Beach, path, plaza, dunes and ocean. Synchronous (cheap: ~150k voxels).
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

	-- Central path (cobblestone) and round hub plaza (concrete), painted into the top voxels.
	local stripX = Layout.STRIP_HALF_X
	fillBox(Vector3.new(-stripX, S - 4, -8), Vector3.new(stripX, S, 8), Enum.Material.Cobblestone)
	terrain:FillCylinder(CFrame.new(0, S - 2, 0), 4, 30, Enum.Material.Concrete)

	-- Grassy dunes behind the boardwalk
	fillBox(Vector3.new(-hx, S - 4, Layout.DUNES_Z0), Vector3.new(hx, S, Layout.TERRAIN_NORTH_Z), Enum.Material.Grass)
	for _ = 1, 26 do
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
		local dz = rng:NextNumber(-50, 80)
		local r = rng:NextNumber(10, 18)
		terrain:FillBall(Vector3.new(x, S - r * 0.6, dz), r, sand)
	end
end

-- Fill the layered bands inside an X/Z rectangle. Optionally yields between bands.
local function fillColumn(
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	yieldEvery: number?,
	bottomUp: boolean?
)
	local count = 0
	local n = #TerrainBuilder.Bands
	for k = 1, n do
		local band = TerrainBuilder.Bands[if bottomUp then n - k + 1 else k]
		fillBox(Vector3.new(minX, band.Bottom, minZ), Vector3.new(maxX, band.Top, maxZ), band.Material)
		count += 1
		if yieldEvery and count % yieldEvery == 0 then
			task.wait()
		end
	end
end

-- Top bands (layers 1-2) of both row strips synchronously, so the surface is solid immediately.
function TerrainBuilder.BuildStripTops()
	local hx = Layout.STRIP_HALF_X
	local zi, zo = Layout.STRIP_INNER_Z, Layout.STRIP_OUTER_Z
	for i = 1, math.min(2, #TerrainBuilder.Bands) do
		local band = TerrainBuilder.Bands[i]
		for _, sign in { 1, -1 } do
			local z0 = math.min(sign * zi, sign * zo)
			local z1 = math.max(sign * zi, sign * zo)
			fillBox(Vector3.new(-hx, band.Bottom, z0), Vector3.new(hx, band.Top, z1), band.Material)
		end
	end
end

-- All bands of both strips, chunked along X with a yield per chunk (call in a task).
function TerrainBuilder.BuildStripsDeep()
	local hx = Layout.STRIP_HALF_X
	local zi, zo = Layout.STRIP_INNER_Z, Layout.STRIP_OUTER_Z
	local chunk = 108
	for i = 3, #TerrainBuilder.Bands do
		local band = TerrainBuilder.Bands[i]
		for _, sign in { 1, -1 } do
			local z0 = math.min(sign * zi, sign * zo)
			local z1 = math.max(sign * zi, sign * zo)
			local x = -hx
			while x < hx do
				local x1 = math.min(x + chunk, hx)
				fillBox(Vector3.new(x, band.Bottom, z0), Vector3.new(x1, band.Top, z1), band.Material)
				x = x1
			end
		end
		task.wait()
	end
end

-- Refill one plot column (footprint + `margin` studs each side), bottom-up, yielding every
-- `bandsPerFrame` bands so a reset never spikes the server.
function TerrainBuilder.RefillColumn(center: Vector3, footprint: number, margin: number, bandsPerFrame: number?)
	local h = footprint / 2 + margin
	fillColumn(center.X - h, center.X + h, center.Z - h, center.Z + h, bandsPerFrame or 2, true)
end

return TerrainBuilder
