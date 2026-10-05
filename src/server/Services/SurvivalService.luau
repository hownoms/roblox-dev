--!strict
--[[
	SurvivalService — heat, shade and snacks (owner: Survival). Soft and kid-friendly: heat only
	ever slows digging down (Sunburnt), never damages. See docs/design/Survival.md and
	Config/Heat.luau for the numbers.

	Heat (server-authoritative, not persisted, ticked every Heat.TickSeconds):
	  underground (attribute Depth >= UndergroundDepth)  falls
	  under any placed shade (SurvivalShades.GetCoverAt) falls x shade Cooling
	  on the hot sand in the sun                          rises (+ per dig via ServerSignals.Dug),
	                                                      x event multiplier (Golden Hour / High Tide)
	  anywhere else (boardwalk, hub, swimming)            falls slowly
	New players (PlayerData.PlayTime < NewPlayerGraceSeconds) never heat up.
	Sunburnt at SunburntAt until heat <= RecoverAt (DigService reads the attribute).

	Player attributes set here:
	  Heat (number 0..Max), Sunburnt (bool), InShade (bool),
	  HeatZone ("Sun" | "Shade" | "Underground" | "Cool"), HeatGrace (bool)

	Remotes: BuyShade, PlaceShade, PickUpShade (SurvivalShades), BuyConsumable(id, count),
	UseConsumable(id), DrinkFountain() (near a part tagged "WaterFountain").
	Products: Reward.Consumables is granted by SurvivalService.GrantConsumables (Main's grant
	handler calls it after RewardsService.Grant).

	Public API:
		SurvivalService.GetHeat(player): number
		SurvivalService.SetHeat(player, heat)          -- dev / tests
		SurvivalService.Cool(player, amount)
		SurvivalService.IsSunburnt(player): boolean
		SurvivalService.BuyConsumable(player, id, count): boolean
		SurvivalService.UseConsumable(player, id): boolean
		SurvivalService.DrinkFountain(player): boolean
		SurvivalService.GrantConsumables(player, map, source?): boolean
		SurvivalService.Shades -> SurvivalShades
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Format = require(Shared.Util.Format)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local EventService = require(script.Parent.EventService)
local Net = require(script.Parent.Net)
local ServerSignals = require(script.Parent.ServerSignals)
local SurvivalShades = require(script.Parent.SurvivalShades)
local World = require(script.Parent.Parent.World)

type HeatState = {
	Heat: number,
	Sunburnt: boolean,
	PendingDig: number, -- dig heat queued since the last tick
	OnSand: boolean, -- last known "standing on hot sand" (kept while airborne)
	LastFountain: number,
}

export type Zone = "Sun" | "Shade" | "Underground" | "Cool"

local Heat = Config.Heat

local FOUNTAIN_REACH = 22
local MAX_BUY_COUNT = 50

local SurvivalService = {}
SurvivalService.Shades = SurvivalShades

local states: { [Player]: HeatState } = {}

-- Floors that count as "the hot sand" (top layers of the beach).
local HOT_FLOORS: { [Enum.Material]: boolean } = {
	[Enum.Material.Sand] = true,
	[Config.Layers[1].Material] = true,
}
if Config.Layers[2] then
	HOT_FLOORS[Config.Layers[2].Material] = true
end

local function getState(player: Player): HeatState
	local state = states[player]
	if not state then
		state = {
			Heat = 0,
			Sunburnt = false,
			PendingDig = 0,
			OnSand = false,
			LastFountain = -math.huge,
		}
		states[player] = state
	end
	return state
end

local function setAttr(player: Player, name: string, value: any)
	if player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

local function publish(player: Player, state: HeatState)
	if player.Parent == nil then
		return
	end
	if state.Sunburnt and state.Heat <= Heat.RecoverAt then
		state.Sunburnt = false
	elseif not state.Sunburnt and state.Heat >= Heat.SunburntAt then
		state.Sunburnt = true
	end
	setAttr(player, "Heat", math.floor(state.Heat * 10 + 0.5) / 10)
	setAttr(player, "Sunburnt", state.Sunburnt)
end

local function inGrace(player: Player): boolean
	local data = DataService.Get(player)
	return data ~= nil and data.PlayTime < Heat.NewPlayerGraceSeconds
end

local function sunMultiplier(): number
	local multiplier = 1
	for _, id in EventService.GetActiveIds() do
		local m = Heat.EventSunMultipliers[id]
		if m then
			multiplier *= m
		end
	end
	return multiplier
end

local function onHotSand(state: HeatState, root: BasePart, humanoid: Humanoid, depth: number): boolean
	if humanoid:GetState() == Enum.HumanoidStateType.Swimming then
		state.OnSand = false
		return false
	end
	if depth > 0 or World.IsInDigZone(root.Position) and root.Position.Y >= Config.SURFACE_Y - 2 then
		state.OnSand = true
		return true
	end
	local floor = humanoid.FloorMaterial
	if floor == Enum.Material.Air then
		return state.OnSand -- jumping / falling: keep the last answer
	end
	state.OnSand = HOT_FLOORS[floor] == true
	return state.OnSand
end

-- One heat step for one player. Returns the zone used (for the HUD).
local function step(player: Player, state: HeatState, dt: number, sun: number): Zone?
	local maybeRoot = Net.GetRoot(player)
	local character = player.Character
	local maybeHumanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not maybeRoot or not maybeHumanoid then
		state.PendingDig = 0
		return nil
	end
	local root = maybeRoot :: BasePart
	local humanoid = maybeHumanoid :: Humanoid
	local depthAttr = player:GetAttribute("Depth")
	local depth = if type(depthAttr) == "number" then depthAttr else 0
	local digHeat = math.min(state.PendingDig, Heat.DigRiseMaxPerSecond * dt)
	state.PendingDig = 0

	local zone: Zone
	local delta: number
	local cover = SurvivalShades.GetCoverAt(root.Position)
	if depth >= Heat.UndergroundDepth then
		zone = "Underground"
		delta = -Heat.UndergroundFallPerSecond * dt
	elseif cover then
		zone = "Shade"
		delta = -Heat.ShadeFallPerSecond * cover.Cooling * dt
	elseif onHotSand(state, root, humanoid, depth) then
		zone = "Sun"
		delta = if inGrace(player) then 0 else Heat.SunRisePerSecond * sun * dt + digHeat * sun
	else
		zone = "Cool"
		delta = -Heat.OffSandFallPerSecond * dt
	end
	state.Heat = math.clamp(state.Heat + delta, 0, Heat.Max)
	setAttr(player, "InShade", cover ~= nil)
	setAttr(player, "HeatZone", zone)
	setAttr(player, "HeatGrace", inGrace(player))
	publish(player, state)
	return zone
end

-- Public API ----------------------------------------------------------------------------------------

function SurvivalService.GetHeat(player: Player): number
	local state = states[player]
	return if state then state.Heat else 0
end

function SurvivalService.SetHeat(player: Player, heat: number)
	local state = getState(player)
	state.Heat = math.clamp(heat, 0, Heat.Max)
	publish(player, state)
end

function SurvivalService.Cool(player: Player, amount: number)
	local state = getState(player)
	state.Heat = math.clamp(state.Heat - amount, 0, Heat.Max)
	publish(player, state)
end

function SurvivalService.IsSunburnt(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.Sunburnt
end

local function applyBoost(player: Player, data: Types.PlayerData, boostId: string, seconds: number)
	local def = Config.GetBoost(boostId)
	if not def or seconds <= 0 then
		return
	end
	local now = os.time()
	local current = data.Boosts[boostId] or 0
	local extended = math.min(math.max(current, now) + seconds, now + Heat.ConsumableBoostCapSeconds)
	data.Boosts[boostId] = math.max(current, extended)
	DataService.MarkDirty(player, "Boosts")
end

function SurvivalService.BuyConsumable(player: Player, id: string, count: number): boolean
	local data = DataService.Get(player)
	local def = Config.GetConsumable(id)
	if not data or not def then
		return false
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(def) -- refine for the type checker (guarded above)
	if def.Price <= 0 then
		Net.Notify(player, "Info", def.Name .. " is free at the fountain!")
		return false
	end
	local have = data.Consumables[id] or 0
	local n = math.min(count, Heat.ConsumableMaxStack - have)
	if n <= 0 then
		Net.Notify(player, "Error", "Your cooler is full of " .. def.Name .. "!")
		return false
	end
	local cost = def.Price * n
	if data.Coins < cost then
		Net.Notify(player, "Error", "Not enough coins! Need " .. Format.Abbreviate(cost - data.Coins) .. " more.")
		return false
	end
	DataService.Mutate(player, { "Coins", "Consumables" }, function(d)
		d.Coins -= cost
		d.Consumables[id] = have + n
	end)
	Analytics.Sink(player, "Coins", cost, data.Coins, Enum.AnalyticsEconomyTransactionType.Shop, "Consumable:" .. id)
	Net.Notify(player, "Success", "+" .. n .. " " .. def.Icon .. " " .. def.Name .. "!")
	return true
end

function SurvivalService.UseConsumable(player: Player, id: string): boolean
	local data = DataService.Get(player)
	local def = Config.GetConsumable(id)
	if not data or not def then
		return false
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(def) -- refine for the type checker (guarded above)
	local have = data.Consumables[id] or 0
	if have <= 0 then
		Net.Notify(player, "Error", "You don't have any " .. def.Name .. "! Get some at the Beach Shop.")
		return false
	end
	local state = getState(player)
	if def.Boost == nil and state.Heat < 1 then
		Net.NotifyThrottled(player, "Info", "You're already nice and cool! 😎", "AlreadyCool", 3)
		return false
	end
	DataService.Mutate(player, { "Consumables" }, function(d)
		if have > 1 then
			d.Consumables[id] = have - 1
		else
			d.Consumables[id] = nil
		end
	end)
	SurvivalService.Cool(player, def.Cooling)
	if def.Boost and def.BoostSeconds then
		applyBoost(player, data, def.Boost, def.BoostSeconds)
	end
	return true
end

function SurvivalService.DrinkFountain(player: Player): boolean
	local maybeRoot = Net.GetRoot(player)
	if not maybeRoot then
		return false
	end
	local root = maybeRoot :: BasePart
	local near = false
	for _, inst in CollectionService:GetTagged("WaterFountain") do
		local position = if inst:IsA("BasePart")
			then inst.Position
			elseif inst:IsA("Model") then inst:GetPivot().Position
			else nil
		if position and (position - root.Position).Magnitude <= FOUNTAIN_REACH then
			near = true
			break
		end
	end
	if not near then
		return false
	end
	local state = getState(player)
	local now = os.clock()
	if now - state.LastFountain < Heat.FountainCooldownSeconds then
		return false
	end
	state.LastFountain = now
	local water = Config.GetConsumable("water")
	SurvivalService.Cool(player, if water then water.Cooling else 70)
	Net.NotifyThrottled(player, "Success", "Ahh, refreshing! 💧", "Fountain", 4)
	return true
end

-- Grants consumables from a product / reward. Unknown ids are ignored. Always returns true when
-- the player's data is loaded (so a receipt can be acknowledged).
function SurvivalService.GrantConsumables(player: Player, items: { [string]: number }, _source: string?): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local parts: { string } = {}
	DataService.Mutate(player, { "Consumables" }, function(d)
		for id, count in items do
			local def = Config.GetConsumable(id)
			if def and type(count) == "number" and count > 0 then
				-- products may exceed the shop stack cap a little; never above 2x
				local current = d.Consumables[id] or 0
				local new = math.min(current + math.floor(count), Heat.ConsumableMaxStack * 2)
				d.Consumables[id] = new
				if new > current then
					table.insert(parts, "+" .. (new - current) .. " " .. def.Icon .. " " .. def.Name)
				end
			end
		end
	end)
	if #parts > 0 then
		table.sort(parts)
		Net.Notify(player, "Reward", table.concat(parts, ", ") .. "!")
	end
	return true
end

-- Lifecycle -----------------------------------------------------------------------------------------

function SurvivalService.Init()
	SurvivalShades.Init()

	Net.On("BuyConsumable", function(player: Player, id: any, count: any)
		if not Net.IsString(id, 64) then
			return
		end
		if Net.IsInteger(count, 1, MAX_BUY_COUNT) then
			SurvivalService.BuyConsumable(player, id, count)
		end
	end, { Rate = 4, Window = 1 })

	Net.On("UseConsumable", function(player: Player, id: any)
		if Net.IsString(id, 64) then
			SurvivalService.UseConsumable(player, id)
		end
	end, { Rate = 4, Window = 1 })

	Net.On("DrinkFountain", function(player: Player)
		SurvivalService.DrinkFountain(player)
	end, { Rate = 2, Window = 1 })
end

function SurvivalService.Start()
	ServerSignals.Dug:Connect(function(player: Player, _depth: number, _gained: number, source: string?)
		local state = states[player]
		-- Diggers dig while their owner stands still: only the player's own swings heat them up.
		if state and source ~= "Digger" then
			state.PendingDig += Heat.DigRisePerDig
		end
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Heat.TickSeconds)
			local now = os.clock()
			local dt = math.min(now - last, 1)
			last = now
			local sun = sunMultiplier()
			for player, state in states do
				if player.Parent == nil then
					continue
				end
				local ok, err = pcall(step, player, state, dt, sun)
				if not ok then
					warn("[SurvivalService] heat tick failed for " .. player.Name .. ": " .. tostring(err))
				end
			end
		end
	end)
end

function SurvivalService.OnPlayerAdded(player: Player)
	local state = getState(player)
	player:SetAttribute("Heat", 0)
	player:SetAttribute("Sunburnt", false)
	player:SetAttribute("InShade", false)
	player:SetAttribute("HeatZone", "Cool")
	publish(player, state)
end

function SurvivalService.OnPlayerRemoving(player: Player)
	SurvivalShades.RemoveAll(player)
	states[player] = nil
end

return SurvivalService
