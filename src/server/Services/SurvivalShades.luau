--!strict
--[[
	SurvivalShades — buying, placing and picking up shade items (part of SurvivalService).

	Placement rules (server-authoritative; the client only sends shadeId, a raycast hit point and
	a yaw — the server resolves the ground itself from the terrain voxels):
	  - the shade is owned (PlayerData.OwnedShades),
	  - the point is within Heat.ShadePlaceRange studs (horizontal) of the player,
	  - it is on the beach surface: inside the dig zone, or on Sand / a layer material,
	    not in the sea, not deep in a hole,
	  - there is solid ground right under it (not floating over a hole),
	  - it keeps Heat.ShadeHubClearance studs from hub stations and Heat.ShadeMinSpacing studs
	    from other shades, and nothing solid stands in the way.
	Each player has Heat.ShadeSlots active shades (VIP pass: ShadeSlotsVip); placing one more
	replaces the oldest. Shades despawn when the owner leaves. If the sand under a shade is dug
	away later, it simply stays where it is (anchored).

	Placed shades live in Workspace.Shades as Models (Models.Shade) with attributes
	OwnerUserId, OwnerName, ShadeId, Radius, Cooling, Height and the CollectionService tag
	"PlacedShade".

	API (used by SurvivalService and tests):
		SurvivalShades.Buy(player, shadeId): boolean
		SurvivalShades.Place(player, shadeId, position, yaw): (boolean, string?)
		SurvivalShades.PickUp(player, shadeId?): number      -- shades removed
		SurvivalShades.RemoveAll(player)
		SurvivalShades.GetPlaced(player?): { Placed }
		SurvivalShades.GetCoverAt(position): Placed?         -- best-cooling shade covering it
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Format = require(Shared.Util.Format)
local Models = require(Shared.Models)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local Net = require(script.Parent.Net)
local World = require(script.Parent.Parent.World)

export type Placed = {
	Model: Model,
	Owner: Player,
	ShadeId: string,
	Position: Vector3,
	Radius: number,
	Cooling: number,
	Height: number,
	PlacedAt: number,
}

local Heat = Config.Heat
local terrain = Workspace.Terrain

local SurvivalShades = {}

SurvivalShades.TAG = "PlacedShade"
-- Stations players gather at: no shades on top of them.
SurvivalShades.HUB_TAGS = {
	"SellZone",
	"ShovelShop",
	"BackpackShop",
	"EggShop",
	"RebirthStatue",
	"WaterFountain",
	"BeachShop",
	"Garage",
	"SpawnLocation",
	"LeaderboardCoins",
	"LeaderboardDepth",
}

local SURFACE_BELOW = 6 -- placement may not be more than this many studs below SURFACE_Y
local SURFACE_ABOVE = 30
local MAX_GROUND_GAP = 4 -- client point may sit at most this far above the solid voxel top
local MAX_GROUND_SINK = 3 -- ...or this far below it (smooth-terrain surface rounding)
local VERTICAL_RANGE = 24
local COVER_BELOW = 6 -- a player this far below the shade's ground still counts (shallow holes)

local placed: { Placed } = {}
local folder: Folder? = nil
local placeCounter = 0

local beachMaterials: { [Enum.Material]: boolean } = { [Enum.Material.Sand] = true }
for _, layer in Config.Layers do
	beachMaterials[layer.Material] = true
end

local function getFolder(): Folder
	local existing = folder
	if existing and existing.Parent then
		return existing
	end
	local f = Workspace:FindFirstChild("Shades")
	if not (f and f:IsA("Folder")) then
		f = Instance.new("Folder")
		f.Name = "Shades"
		f.Parent = Workspace
	end
	folder = f :: Folder
	return f :: Folder
end

local function horizontal(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function positionOf(inst: Instance): Vector3?
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetPivot().Position
	elseif inst:IsA("Attachment") then
		return inst.WorldPosition
	end
	return nil
end

-- Top of the solid terrain in the 4-stud voxel column under `position` (scans from 8 studs above
-- to 12 below). Returns (topY, material) or nil when there is no ground there.
local function groundAt(position: Vector3): (number?, Enum.Material?)
	local lo = Vector3.new(position.X - 0.5, position.Y - 12, position.Z - 0.5)
	local hi = Vector3.new(position.X + 0.5, position.Y + 8, position.Z + 0.5)
	local region = Region3.new(lo, hi):ExpandToGrid(4)
	local ok, materials, occupancies = pcall(function()
		return terrain:ReadVoxels(region, 4)
	end)
	if not ok then
		return nil, nil
	end
	local size: Vector3 = materials.Size
	local minY = region.CFrame.Position.Y - region.Size.Y / 2
	for y = size.Y, 1, -1 do
		for x = 1, size.X do
			for z = 1, size.Z do
				local material = materials[x][y][z]
				local occ = occupancies[x][y][z]
				if material ~= Enum.Material.Air and occ > 0.3 then
					return minY + (y - 1) * 4 + occ * 4, material
				end
			end
		end
	end
	return nil, nil
end

local function shadeSlots(player: Player): number
	if MonetizationService.OwnsPass(player, "VIP") then
		return Heat.ShadeSlotsVip
	end
	return Heat.ShadeSlots
end

local function blocked(position: Vector3): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { getFolder() }
	for _, other in game:GetService("Players"):GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local parts =
		Workspace:GetPartBoundsInBox(CFrame.new(position + Vector3.new(0, 3, 0)), Vector3.new(2, 4, 2), params)
	for _, part in parts do
		if not part:IsA("Terrain") and part.CanCollide and part.Transparency < 1 then
			return true
		end
	end
	return false
end

-- Validates and resolves the final ground point. Returns (position, nil) or (nil, reason).
local function resolvePlacement(player: Player, position: Vector3): (Vector3?, string?)
	local maybeRoot = Net.GetRoot(player)
	if not maybeRoot then
		return nil, "Respawn first!"
	end
	local root = maybeRoot :: BasePart
	if
		horizontal(root.Position, position) > Heat.ShadePlaceRange
		or math.abs(root.Position.Y - position.Y) > VERTICAL_RANGE
	then
		return nil, "Too far away! Get closer."
	end
	if position.Y < Config.SURFACE_Y - SURFACE_BELOW or position.Y > Config.SURFACE_Y + SURFACE_ABOVE then
		return nil, "Put it on the beach surface, not down a hole!"
	end
	local groundTop, groundMaterial = groundAt(position)
	if groundTop == nil or groundMaterial == nil then
		return nil, "Can't place it over a hole!"
	end
	local top = groundTop :: number
	local material = groundMaterial :: Enum.Material
	if material == Enum.Material.Water then
		return nil, "Not in the water! Put it on the sand."
	end
	if position.Y - top > MAX_GROUND_GAP then
		return nil, "Can't place it over a hole!"
	end
	if top - position.Y > MAX_GROUND_SINK then
		return nil, "Can't place it there!"
	end
	if not (World.IsInDigZone(position) or beachMaterials[material]) then
		return nil, "Place it on the beach sand!"
	end
	for _, tag in SurvivalShades.HUB_TAGS do
		for _, inst in CollectionService:GetTagged(tag) do
			local p = positionOf(inst)
			if p and horizontal(p, position) < Heat.ShadeHubClearance and math.abs(p.Y - position.Y) < 30 then
				return nil, "Too close to the shops! Find a sunny spot on the sand."
			end
		end
	end
	for _, other in placed do
		if horizontal(other.Position, position) < Heat.ShadeMinSpacing then
			return nil, "Too close to another shade!"
		end
	end
	if blocked(position) then
		return nil, "Something is in the way!"
	end
	-- Sit on the visible surface: trust the client's raycast height only within the voxel bounds.
	local y = math.clamp(position.Y, top - MAX_GROUND_SINK, top + MAX_GROUND_GAP)
	return Vector3.new(position.X, y, position.Z), nil
end

local function ownerLabel(model: Model, player: Player, def: Types.ShadeDef)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "OwnerLabel"
	gui.Size = UDim2.fromOffset(220, 34)
	gui.StudsOffset = Vector3.new(0, def.Height + 4, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "⛱️ " .. player.DisplayName .. "'s " .. def.Name
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(40, 30, 50)
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = root
end

local function destroy(entry: Placed)
	local i = table.find(placed, entry)
	if i then
		table.remove(placed, i)
	end
	if entry.Model.Parent then
		entry.Model:Destroy()
	end
end

-- Public --------------------------------------------------------------------------------------------

function SurvivalShades.GetPlaced(player: Player?): { Placed }
	local list = {}
	for _, entry in placed do
		if player == nil or entry.Owner == player then
			table.insert(list, entry)
		end
	end
	return list
end

-- Best-cooling shade whose circle covers `position` (horizontal), with the player roughly at or
-- above the shade's ground and below its canopy.
function SurvivalShades.GetCoverAt(position: Vector3): Placed?
	local best: Placed? = nil
	for _, entry in placed do
		local dy = position.Y - entry.Position.Y
		if dy >= -COVER_BELOW and dy <= entry.Height + 2 and horizontal(position, entry.Position) <= entry.Radius then
			if best == nil or entry.Cooling > (best :: Placed).Cooling then
				best = entry
			end
		end
	end
	return best
end

function SurvivalShades.Buy(player: Player, shadeId: string): boolean
	local data = DataService.Get(player)
	local def = Config.GetShade(shadeId)
	if not data or not def then
		return false
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(def) -- refine for the type checker (guarded above)
	if data.OwnedShades[shadeId] then
		Net.Notify(player, "Info", "You already own the " .. def.Name .. "! Tap Place to put it down.")
		return false
	end
	local rebirths = def.RebirthsRequired or 0
	if data.Rebirths < rebirths then
		Net.Notify(player, "Error", string.format("Needs %d rebirth%s!", rebirths, if rebirths == 1 then "" else "s"))
		return false
	end
	if data.Coins < def.Price then
		Net.Notify(player, "Error", "Not enough coins! Need " .. Format.Abbreviate(def.Price - data.Coins) .. " more.")
		return false
	end
	DataService.Mutate(player, { "Coins", "OwnedShades" }, function(d)
		d.Coins -= def.Price
		d.OwnedShades[shadeId] = true
	end)
	Analytics.Sink(
		player,
		"Coins",
		def.Price,
		data.Coins,
		Enum.AnalyticsEconomyTransactionType.Shop,
		"Shade:" .. shadeId
	)
	Net.Notify(player, "Success", "You got the " .. def.Name .. "! Place it on the sand for shade.")
	return true
end

function SurvivalShades.Place(player: Player, shadeId: string, position: Vector3, yaw: number): (boolean, string?)
	local data = DataService.Get(player)
	local def = Config.GetShade(shadeId)
	if not data or not def then
		return false, "Unknown shade"
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(def) -- refine for the type checker (guarded above)
	if not data.OwnedShades[shadeId] then
		return false, "You don't own that shade yet!"
	end
	-- Moving your own shade: ignore its current spot for the spacing check.
	local mine = SurvivalShades.GetPlaced(player)
	local moving: Placed? = nil
	for _, entry in mine do
		if entry.ShadeId == shadeId then
			moving = entry
			break
		end
	end
	local movingIndex = if moving then table.find(placed, moving) else nil
	if movingIndex then
		table.remove(placed, movingIndex)
	end
	local ground, reason = resolvePlacement(player, position)
	if movingIndex and moving then
		table.insert(placed, movingIndex, moving)
	end
	if not ground then
		return false, reason
	end
	local at = ground :: Vector3

	if moving then
		destroy(moving)
	end
	-- Slot limit: drop the oldest.
	mine = SurvivalShades.GetPlaced(player)
	table.sort(mine, function(a: Placed, b: Placed)
		return a.PlacedAt < b.PlacedAt
	end)
	local slots = shadeSlots(player)
	while #mine >= slots and #mine > 0 do
		destroy(table.remove(mine, 1) :: Placed)
	end

	local model = Models.Shade(shadeId)
	model.Name = player.Name .. "_" .. shadeId
	model:PivotTo(CFrame.new(at) * CFrame.Angles(0, yaw % (math.pi * 2), 0))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("OwnerName", player.DisplayName)
	model:SetAttribute("ShadeId", shadeId)
	model:SetAttribute("Radius", def.Radius)
	model:SetAttribute("Cooling", def.Cooling)
	model:SetAttribute("Height", def.Height)
	ownerLabel(model, player, def)
	CollectionService:AddTag(model, SurvivalShades.TAG)
	-- v2.3 streaming: the owner always has their shade (BeachShop "placed" state, GetMyShades);
	-- everyone else streams it in and out as one unit.
	model.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
	model:AddPersistentPlayer(player)
	model.Parent = getFolder()

	placeCounter += 1
	table.insert(placed, {
		Model = model,
		Owner = player,
		ShadeId = shadeId,
		Position = at,
		Radius = def.Radius,
		Cooling = def.Cooling,
		Height = def.Height,
		PlacedAt = placeCounter,
	})
	return true, nil
end

function SurvivalShades.PickUp(player: Player, shadeId: string?): number
	local removed = 0
	for _, entry in SurvivalShades.GetPlaced(player) do
		if shadeId == nil or entry.ShadeId == shadeId then
			destroy(entry)
			removed += 1
		end
	end
	return removed
end

function SurvivalShades.RemoveAll(player: Player)
	SurvivalShades.PickUp(player, nil)
end

-- Remotes -------------------------------------------------------------------------------------------

function SurvivalShades.Init()
	getFolder()
	Net.On("BuyShade", function(player: Player, shadeId: any)
		if Net.IsString(shadeId, 64) then
			SurvivalShades.Buy(player, shadeId)
		end
	end, { Rate = 4, Window = 1 })

	Net.On("PlaceShade", function(player: Player, shadeId: any, position: any, yaw: any)
		if not Net.IsString(shadeId, 64) or not Net.IsVector3(position) then
			return
		end
		local angle = if Net.IsNumber(yaw) then yaw else 0
		local ok, reason = SurvivalShades.Place(player, shadeId, position, angle)
		if ok then
			local def = Config.GetShade(shadeId)
			Net.Notify(
				player,
				"Success",
				(if def then def.Name else "Shade") .. " placed! Stand under it to cool down."
			)
		else
			Net.Notify(player, "Error", reason or "Can't place it there!")
		end
	end, { Rate = 3, Window = 1 })

	Net.On("PickUpShade", function(player: Player, shadeId: any)
		local id: string? = if Net.IsString(shadeId, 64) then shadeId else nil
		if SurvivalShades.PickUp(player, id) > 0 then
			Net.Notify(player, "Info", "Shade picked up.")
		end
	end, { Rate = 3, Window = 1 })
end

return SurvivalShades
