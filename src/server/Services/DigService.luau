--!strict
--[[
	DigService — the Dig remote (docs/ARCHITECTURE.md "Core mechanic").

	Dig(position: Vector3) validation, in order (first failure -> DigResult{Success=false,Reason}):
	  NoPlot       player has no plot (queue) / plot is being refilled
	  Cooldown     less than shovel cooldown / speed x COOLDOWN_LENIENCY since the last dig
	  OutOfPlot    point is not inside the player's own plot column
	  Bottom       point is at the very bottom of the plot (The Core floor is indestructible)
	  TooFar       point further than Config.REACH (+ small latency slack) from HumanoidRootPart
	  TooHard      shovel Power < Hardness of the layer at that depth
	  BackpackFull Sand >= effective capacity
	Points with no solid terrain near them are ignored silently (no result).
	The dig sphere center is clamped so the sphere never cuts plot walls or the floor.
	Success: FillBall(center, shovel.Radius, Air), sand (Stats) into the backpack (capped at
	capacity), MaxDepth / layer bookkeeping via PlotService, treasure roll (layer chance x luck,
	capped; luck boosts non-Common weights), DigResult to the digger.
	The 8th dig of a brand-new player's first session always finds a Common treasure (GDD §8).

	AutoDig pass: SetSetting("AutoDig", true|false). While on (and the pass is owned) the server
	digs straight down below the character's feet at the shovel's normal cooldown.

	Public API:
		DigService.TryDig(player, position, isAuto): Types.DigResult?
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Stats = require(Shared.Util.Stats)
local Weighted = require(Shared.Util.Weighted)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local MultiplierService = require(script.Parent.MultiplierService)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local ServerSignals = require(script.Parent.ServerSignals)
local SettingsService = require(script.Parent.SettingsService)

local REACH_SLACK = 2 -- studs of latency slack on top of Config.REACH
local SURFACE_SLACK = 4 -- how far above the plot surface a dig point may be
local WALL_MARGIN = 0.5 -- keep this much terrain between the sphere and the plot wall
local BOTTOM_FLOOR = 2 -- studs of indestructible floor kept at the bottom of the plot
local EDGE_SLACK = 1 -- dig points may be this far outside the footprint (surface rounding)
local FTUE_TREASURE_DIG = 8
local AUTO_TICK = 0.05

local DigService = {}

local terrain = Workspace.Terrain
local rng = Random.new()

local lastDig: { [Player]: number } = {}
local lastFailResult: { [Player]: number } = {}
local sessionDigs: { [Player]: number } = {}

local function baseResult(position: Vector3): Types.DigResult
	return {
		Success = false,
		Reason = nil,
		Position = position,
		Radius = 0,
		SandGained = 0,
		Sand = 0,
		Capacity = 0,
		Depth = 0,
		LayerIndex = 1,
		NewMaxDepth = false,
		NewLayer = false,
		TreasureId = nil,
	}
end

local function hasSolidTerrainNear(position: Vector3): boolean
	local half = Vector3.new(2, 2, 2)
	local region = Region3.new(position - half, position + half):ExpandToGrid(4)
	local ok, materials, occupancies = pcall(function()
		return terrain:ReadVoxels(region, 4)
	end)
	if not ok then
		return true -- don't block digging on an engine hiccup
	end
	local size: Vector3 = materials.Size
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				local material = materials[x][y][z]
				if material ~= Enum.Material.Air and material ~= Enum.Material.Water and occupancies[x][y][z] > 0 then
					return true
				end
			end
		end
	end
	return false
end

local function rollTreasure(
	player: Player,
	data: Types.PlayerData,
	ctx: Stats.Context,
	layerIndex: number
): Types.TreasureDef?
	local layer = Config.Layers[layerIndex]
	local digs = sessionDigs[player] or 0
	local forced = digs == FTUE_TREASURE_DIG and next(data.Index) == nil
	if forced then
		for _, entry in layer.LootTable do
			local def = Config.GetTreasure(entry.TreasureId)
			if def and def.Rarity == "Common" then
				return def
			end
		end
	end
	if rng:NextNumber() >= Stats.GetTreasureChance(ctx, layerIndex) then
		return nil
	end
	local luck = Stats.GetLuck(ctx)
	local entry = Weighted.Pick(layer.LootTable, function(e: Types.LootEntry): number
		local def = Config.GetTreasure(e.TreasureId)
		return Stats.LuckWeight(e.Weight, if def then def.Rarity else nil, luck)
	end, rng:NextNumber())
	return if entry then Config.GetTreasure(entry.TreasureId) else nil
end

local function awardTreasure(player: Player, treasure: Types.TreasureDef)
	DataService.Mutate(player, { "Treasures", "Index" }, function(d)
		d.Treasures[treasure.Id] = (d.Treasures[treasure.Id] or 0) + 1
		d.Index[treasure.Id] = true
	end)
	Net.FireClient("TreasureFound", player, treasure.Id, treasure.Rarity)
	local rarity = Config.GetRarity(treasure.Rarity)
	if rarity and rarity.Announce then
		Net.NotifyAll(
			"Announce",
			string.format("%s found a %s %s!", player.DisplayName, string.upper(treasure.Rarity), treasure.Name)
		)
	end
	ServerSignals.TreasureFound:Fire(player, treasure.Id)
end

local function fail(
	player: Player,
	result: Types.DigResult,
	reason: Types.DigFailReason,
	isAuto: boolean
): Types.DigResult
	result.Reason = reason
	if reason == "TooHard" then
		Net.NotifyThrottled(player, "Error", "Too hard! Need a better shovel!", "TooHard", 3)
	elseif reason == "BackpackFull" then
		Net.NotifyThrottled(player, "Error", "Backpack full! Go sell!", "BackpackFull", 3)
	elseif reason == "Bottom" then
		Net.NotifyThrottled(player, "Info", "You reached the bottom of the world!", "Bottom", 10)
	end
	-- Throttle failure replies so spamming the remote can't flood the client back.
	local now = os.clock()
	local last = lastFailResult[player]
	if not isAuto and (last == nil or now - last >= 0.2) then
		lastFailResult[player] = now
		Net.FireClient("DigResult", player, result)
	end
	return result
end

function DigService.TryDig(player: Player, position: Vector3, isAuto: boolean): Types.DigResult?
	local data = DataService.Get(player)
	local ctx = MultiplierService.GetContext(player)
	if not data or not ctx then
		return nil
	end
	local result = baseResult(position)
	local plot = PlotService.GetPlot(player)
	if not plot or PlotService.IsResetting(player) then
		return fail(player, result, "NoPlot", isAuto)
	end

	local shovel = Stats.GetShovel(data)
	local cooldown = Stats.GetCooldown(ctx) * (if isAuto then 1 else Config.COOLDOWN_LENIENCY)
	local now = os.clock()
	local last = lastDig[player]
	if last and now - last < cooldown then
		return fail(player, result, "Cooldown", isAuto)
	end

	-- Plot bounds (plot-local space: origin = surface center, -Y = down).
	local localPos = plot.Origin:PointToObjectSpace(position)
	local halfX, halfZ, totalDepth = plot.Size.X / 2, plot.Size.Z / 2, plot.Size.Y
	if
		math.abs(localPos.X) > halfX + EDGE_SLACK
		or math.abs(localPos.Z) > halfZ + EDGE_SLACK
		or localPos.Y > SURFACE_SLACK
		or localPos.Y < -totalDepth - EDGE_SLACK
	then
		return fail(player, result, "OutOfPlot", isAuto)
	end
	if -localPos.Y >= totalDepth - BOTTOM_FLOOR then
		return fail(player, result, "Bottom", isAuto)
	end

	-- Clamp the sphere inside the column so walls/floor of the plot never break.
	local radius = shovel.Radius
	local maxX = math.max(halfX - radius - WALL_MARGIN, 0)
	local maxZ = math.max(halfZ - radius - WALL_MARGIN, 0)
	local minY = -(totalDepth - BOTTOM_FLOOR - radius)
	local center = plot.Origin:PointToWorldSpace(
		Vector3.new(
			math.clamp(localPos.X, -maxX, maxX),
			math.clamp(localPos.Y, minY, SURFACE_SLACK),
			math.clamp(localPos.Z, -maxZ, maxZ)
		)
	)
	local depth = math.clamp(-localPos.Y, 0, totalDepth)
	local layerIndex = Config.GetLayerIndexAtDepth(depth)
	local layer = Config.Layers[layerIndex]
	result.Radius = radius
	result.Depth = depth
	result.LayerIndex = layerIndex

	if not isAuto then
		local root = Net.GetRoot(player)
		if not root or (root.Position - position).Magnitude > Config.REACH + REACH_SLACK then
			return fail(player, result, "TooFar", isAuto)
		end
	end

	if not hasSolidTerrainNear(position) then
		return nil
	end

	if shovel.Power < layer.Hardness then
		return fail(player, result, "TooHard", isAuto)
	end

	local capacity = Stats.GetCapacity(ctx)
	result.Capacity = capacity
	result.Sand = data.Sand
	if data.Sand >= capacity then
		return fail(player, result, "BackpackFull", isAuto)
	end

	-- Success ------------------------------------------------------------------------------------
	lastDig[player] = now
	sessionDigs[player] = (sessionDigs[player] or 0) + 1
	terrain:FillBall(center, radius, Enum.Material.Air)

	local gained = math.min(layer.SandValue * Stats.GetSandMultiplier(ctx), capacity - data.Sand)
	DataService.Mutate(player, { "Sand", "TotalSandDug" }, function(d)
		d.Sand += gained
		d.TotalSandDug += gained
	end)
	local newRecord, newLayer = PlotService.ReportDig(player, depth, depth + radius)

	local treasure = rollTreasure(player, data, ctx, layerIndex)
	if treasure then
		awardTreasure(player, treasure)
	end

	result.Success = true
	result.SandGained = gained
	result.Sand = data.Sand
	result.NewMaxDepth = newRecord
	result.NewLayer = newLayer
	result.TreasureId = if treasure then treasure.Id else nil
	Net.FireClient("DigResult", player, result)

	ServerSignals.Dug:Fire(player, depth, gained)
	Analytics.Funnel(player, Analytics.Steps.FirstDig)
	if data.Sand >= capacity then
		ServerSignals.BackpackFull:Fire(player)
		Net.NotifyThrottled(player, "Error", "Backpack full! Go sell!", "BackpackFull", 3)
	end
	return result
end

-- AutoDig ---------------------------------------------------------------------------------------

local function autoDigEnabled(player: Player): boolean
	return SettingsService.Get(player, "AutoDig") == true and MonetizationService.OwnsPass(player, "AutoDig")
end

local function autoDigStep(player: Player)
	local root = Net.GetRoot(player)
	if not root then
		return
	end
	local data = DataService.Get(player)
	local ctx = MultiplierService.GetContext(player)
	if not data or not ctx then
		return
	end
	if os.clock() - (lastDig[player] or 0) < Stats.GetCooldown(ctx) then
		return
	end
	if data.Sand >= Stats.GetCapacity(ctx) then
		Net.NotifyThrottled(player, "Error", "Backpack full! Go sell!", "BackpackFull", 10)
		return
	end
	local humanoid = (root.Parent :: Instance):FindFirstChildOfClass("Humanoid")
	local hip = if humanoid then humanoid.HipHeight else 2
	local below = root.Position - Vector3.new(0, root.Size.Y / 2 + hip + 0.5, 0)
	local result = DigService.TryDig(player, below, true)
	if result and not result.Success and result.Reason == "TooHard" then
		lastDig[player] = os.clock() -- back off; the notify is already throttled
	end
end

function DigService.Init()
	Net.On("Dig", function(player: Player, position: any)
		if not Net.IsVector3(position) then
			return
		end
		DigService.TryDig(player, position :: Vector3, false)
	end, { Rate = 20, Window = 1 })

	SettingsService.RegisterValidator("AutoDig", function(player: Player, value: any): (boolean, any)
		if type(value) ~= "boolean" then
			return false, nil
		end
		if value and not MonetizationService.OwnsPass(player, "AutoDig") then
			Net.Notify(player, "Error", "Get the Auto Dig pass to dig automatically!")
			return false, nil
		end
		return true, value
	end)
end

function DigService.Start()
	task.spawn(function()
		while true do
			task.wait(AUTO_TICK)
			for _, player in DataService.GetLoadedPlayers() do
				if autoDigEnabled(player) then
					local ok, err = pcall(autoDigStep, player)
					if not ok then
						warn("[DigService] auto dig error: " .. tostring(err))
					end
				end
			end
		end
	end)
end

function DigService.OnPlayerRemoving(player: Player)
	lastDig[player] = nil
	lastFailResult[player] = nil
	sessionDigs[player] = nil
end

return DigService
