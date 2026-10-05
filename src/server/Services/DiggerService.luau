--!strict
--[[
	DiggerService — digger companions (docs/V2.md "Diggers", docs/design/Diggers.md).

	Remotes (client -> server, id: string): BuyDigger, UpgradeDigger, EquipDigger, UnequipDigger.
	  Buy      coins + RebirthsRequired; auto-equips while a slot is free. One of each digger.
	  Upgrade  Config.GetDiggerUpgradeCost(def, level) coins, up to MaxLevel.
	  Equip    owned and a free slot (Config.GetDiggerSlots: 1 + AutoDig pass + rebirth 2 / 5).
	PlayerData.Diggers[id] = { Level, Equipped }. Diggers are kept on rebirth.

	Player attributes (server -> every client):
	  "EquippedDiggers"  "id:level,id:level"  the ACTIVE diggers (equipped, capped at the slot count,
	                     most expensive first if a save has more equipped than slots), config order.
	                     "" when none. Parsers must accept a bare "id" (level 1).
	  "DiggerSlots"      number  current slot count.

	Dig loop (every TICK): for each active digger whose Interval elapsed, pick a point near the
	owner (under the feet or on a ring a few studs out, so the owner's hole widens / deepens; never
	near another player; must be inside the dig zone) and call
	DigService.DigAt(player, point, { Power, Radius, SandMultiplier, Source = "Digger", Silent = true }).
	Diggers idle while the owner has no character, stands outside the dig zone (hub, boardwalk), or
	the backpack is full (one gentle Info notify per full backpack). Diggers never get Sunburnt.
	Success -> DiggerDug(player, diggerId, position, sandGained) to all clients.

	Public API:
		DiggerService.GetSlots(player): number
		DiggerService.GetActive(player): { { Id: string, Level: number } }
		DiggerService.Buy / Upgrade / Equip / Unequip (player, id): boolean
		DiggerService.Step(player)   one dig-loop tick for a player (tests)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local Stats = require(Shared.Util.Stats)
local Types = require(Shared.Types)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local DigService = require(script.Parent.DigService)
local MonetizationService = require(script.Parent.MonetizationService)
local MultiplierService = require(script.Parent.MultiplierService)
local Net = require(script.Parent.Net)
local ServerSignals = require(script.Parent.ServerSignals)
local World = require(script.Parent.Parent.World)

export type ActiveDigger = { Id: string, Level: number }

local TICK = 0.1
local RING_MIN = 2.5 -- studs from the owner's feet for ring digs
local RING_MAX = 4
local UNDER_FEET_CHANCE = 0.35 -- share of digs right under the owner (deepens the hole)
local OTHER_PLAYER_CLEARANCE = 5 -- never dig this close (horizontally) to another player
local MAX_DROP = 10 -- ignore surfaces further than this below the feet (no separate shafts)
local TOO_HARD_NOTIFY_SECONDS = 60

local DiggerService = {}

type PlayerState = {
	NextDig: { [string]: number },
	FullNotified: boolean,
	LastTooHard: number,
	Angle: number,
}

local states: { [Player]: PlayerState } = {}
local rng = Random.new()
local loopStarted = false
local lastLoopWarn = -math.huge

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { Workspace.Terrain }

local function getState(player: Player): PlayerState
	local state = states[player]
	if not state then
		state = { NextDig = {}, FullNotified = false, LastTooHard = -math.huge, Angle = rng:NextNumber() * math.pi * 2 }
		states[player] = state
	end
	return state :: PlayerState
end

-- Slots & active list ---------------------------------------------------------------------------

function DiggerService.GetSlots(player: Player): number
	local data = DataService.Get(player)
	local rebirths = if data then data.Rebirths else 0
	return Config.GetDiggerSlots(rebirths, MonetizationService.OwnsPass(player, "AutoDig"))
end

local function countEquipped(data: Types.PlayerData): number
	local n = 0
	for id, inst in data.Diggers do
		if inst.Equipped and Config.GetDigger(id) then
			n += 1
		end
	end
	return n
end

-- Equipped diggers capped at the slot count (most expensive kept), returned in config order.
function DiggerService.GetActive(player: Player): { ActiveDigger }
	local data = DataService.Get(player)
	if not data then
		return {}
	end
	assert(data) -- refine for the type checker (guarded above)
	local slots = DiggerService.GetSlots(player)
	local keep: { [string]: boolean } = {}
	local kept = 0
	for i = #Config.Diggers, 1, -1 do
		local def = Config.Diggers[i]
		local inst = data.Diggers[def.Id]
		if inst and inst.Equipped and kept < slots then
			keep[def.Id] = true
			kept += 1
		end
	end
	local list: { ActiveDigger } = {}
	for _, def in Config.Diggers do
		if keep[def.Id] then
			table.insert(list, { Id = def.Id, Level = data.Diggers[def.Id].Level })
		end
	end
	return list
end

local function publish(player: Player)
	if player.Parent == nil or not DataService.IsLoaded(player) then
		return
	end
	local parts = {}
	for _, active in DiggerService.GetActive(player) do
		table.insert(parts, active.Id .. ":" .. active.Level)
	end
	local value = table.concat(parts, ",")
	if player:GetAttribute("EquippedDiggers") ~= value then
		player:SetAttribute("EquippedDiggers", value)
	end
	local slots = DiggerService.GetSlots(player)
	if player:GetAttribute("DiggerSlots") ~= slots then
		player:SetAttribute("DiggerSlots", slots)
	end
end

-- Repairs a loaded save: unknown ids, bad levels / flags.
local function sanitize(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	assert(data) -- refine for the type checker (guarded above)
	local dirty = false
	if type(data.Diggers) ~= "table" then
		data.Diggers = {}
		dirty = true
	end
	for id, inst in data.Diggers do
		local def = Config.GetDigger(id)
		if not def or type(inst) ~= "table" then
			data.Diggers[id] = nil
			dirty = true
			continue
		end
		assert(def) -- refine for the type checker (guarded above)
		local level = if type(inst.Level) == "number" and inst.Level == inst.Level then inst.Level else 1
		local clamped = math.clamp(math.floor(level), 1, def.MaxLevel)
		if clamped ~= inst.Level then
			inst.Level = clamped
			dirty = true
		end
		if type(inst.Equipped) ~= "boolean" then
			inst.Equipped = false
			dirty = true
		end
	end
	if dirty then
		DataService.MarkDirty(player, "Diggers")
	end
end

-- Purchases / equipment ---------------------------------------------------------------------------

function DiggerService.Buy(player: Player, id: string): boolean
	local data = DataService.Get(player)
	local def = Config.GetDigger(id)
	if not data or not def then
		return false
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(def) -- refine for the type checker (guarded above)
	if data.Diggers[id] then
		Net.Notify(player, "Info", "You already own the " .. def.Name .. "!")
		return false
	end
	local needed = def.RebirthsRequired or 0
	if data.Rebirths < needed then
		Net.Notify(player, "Error", string.format("Needs %d rebirths!", needed))
		return false
	end
	if data.Coins < def.Price then
		Net.Notify(player, "Error", "Not enough coins! Need " .. Format.Abbreviate(def.Price - data.Coins) .. " more.")
		return false
	end
	local equip = countEquipped(data) < DiggerService.GetSlots(player)
	DataService.Mutate(player, { "Coins", "Diggers" }, function(d)
		d.Coins -= def.Price
		d.Diggers[id] = { Level = 1, Equipped = equip }
	end)
	Analytics.Sink(player, "Coins", def.Price, data.Coins, Enum.AnalyticsEconomyTransactionType.Shop, "Digger:" .. id)
	Net.Notify(
		player,
		"Success",
		"You got the " .. def.Name .. "!" .. (if equip then " It follows you and digs!" else "")
	)
	ServerSignals.UpgradeBought:Fire(player, "Digger", id)
	publish(player)
	return true
end

function DiggerService.Upgrade(player: Player, id: string): boolean
	local data = DataService.Get(player)
	local def = Config.GetDigger(id)
	if not data or not def then
		return false
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(def) -- refine for the type checker (guarded above)
	local inst = data.Diggers[id]
	if not inst then
		Net.Notify(player, "Error", "You don't own that yet!")
		return false
	end
	local cost = Config.GetDiggerUpgradeCost(def, inst.Level)
	if not cost then
		Net.Notify(player, "Info", def.Name .. " is already max level!")
		return false
	end
	assert(cost) -- refine for the type checker (guarded above)
	if data.Coins < cost then
		Net.Notify(player, "Error", "Not enough coins! Need " .. Format.Abbreviate(cost - data.Coins) .. " more.")
		return false
	end
	DataService.Mutate(player, { "Coins", "Diggers" }, function(d)
		d.Coins -= cost
		inst.Level += 1
	end)
	Analytics.Sink(player, "Coins", cost, data.Coins, Enum.AnalyticsEconomyTransactionType.Shop, "DiggerUpgrade:" .. id)
	Net.Notify(player, "Success", string.format("%s upgraded to level %d!", def.Name, inst.Level))
	ServerSignals.UpgradeBought:Fire(player, "Digger", id)
	publish(player)
	return true
end

function DiggerService.Equip(player: Player, id: string): boolean
	local data = DataService.Get(player)
	local def = Config.GetDigger(id)
	if not data or not def then
		return false
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(def) -- refine for the type checker (guarded above)
	local inst = data.Diggers[id]
	if not inst then
		Net.Notify(player, "Error", "You don't own that yet!")
		return false
	end
	if inst.Equipped then
		return true
	end
	if countEquipped(data) >= DiggerService.GetSlots(player) then
		Net.Notify(player, "Error", "All digger slots are full! Unequip one first.")
		return false
	end
	DataService.Mutate(player, { "Diggers" }, function()
		inst.Equipped = true
	end)
	getState(player).NextDig[id] = nil
	Net.Notify(player, "Success", def.Name .. " equipped!")
	publish(player)
	return true
end

function DiggerService.Unequip(player: Player, id: string): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	assert(data) -- refine for the type checker (guarded above)
	local inst = data.Diggers[id]
	if not inst or not inst.Equipped then
		return false
	end
	DataService.Mutate(player, { "Diggers" }, function()
		inst.Equipped = false
	end)
	publish(player)
	return true
end

-- Dig loop -----------------------------------------------------------------------------------------

local function feetOf(root: BasePart): Vector3
	local humanoid = (root.Parent :: Instance):FindFirstChildOfClass("Humanoid")
	local hip = if humanoid then humanoid.HipHeight else 2
	return root.Position - Vector3.new(0, root.Size.Y / 2 + hip, 0)
end

local function nearOtherPlayer(owner: Player, point: Vector3): boolean
	for _, other in Players:GetPlayers() do
		if other ~= owner then
			local root = Net.GetRoot(other)
			if root then
				local d = root.Position - point
				if Vector3.new(d.X, 0, d.Z).Magnitude < OTHER_PLAYER_CLEARANCE and math.abs(d.Y) < 10 then
					return true
				end
			end
		end
	end
	return false
end

-- A point on the terrain near the owner (or nil if none is suitable this tick).
local function pickPoint(player: Player, feet: Vector3, slot: number, count: number): Vector3?
	local state = getState(player)
	state.Angle += 2.39996 -- golden angle: successive digs spread evenly around the owner
	for attempt = 1, 6 do
		local offset = Vector3.zero
		if not (attempt == 1 and rng:NextNumber() < UNDER_FEET_CHANCE) then
			local angle = state.Angle + (slot - 1) * (2 * math.pi / math.max(count, 1)) + attempt * 1.1
			local radius = RING_MIN + rng:NextNumber() * (RING_MAX - RING_MIN)
			offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		else
			offset = Vector3.new(rng:NextNumber() * 2 - 1, 0, rng:NextNumber() * 2 - 1)
		end
		local spot = feet + offset
		if not World.IsInDigZone(spot) or nearOtherPlayer(player, spot) then
			continue
		end
		local origin = spot + Vector3.new(0, 3, 0)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -(3 + MAX_DROP), 0), terrainOnly)
		if hit then
			if hit.Position.Y > feet.Y + 2.5 then
				-- the ray started inside the hole wall: dig the wall at foot level (widens the hole)
				return Vector3.new(spot.X, feet.Y + 1, spot.Z)
			end
			return hit.Position
		end
	end
	return nil
end

function DiggerService.Step(player: Player)
	local data = DataService.Get(player)
	local root = Net.GetRoot(player)
	if not data or not root then
		return
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(root) -- refine for the type checker (guarded above)
	local active = DiggerService.GetActive(player)
	if #active == 0 then
		return
	end
	local state = getState(player)
	local now = os.clock()
	local feet = feetOf(root)
	if not World.IsInDigZone(feet) then
		-- idle in the hub / on the boardwalk; start digging soon after stepping onto the sand
		for _, a in active do
			state.NextDig[a.Id] = math.max(state.NextDig[a.Id] or 0, now + 0.5)
		end
		return
	end
	local ctx = MultiplierService.GetContext(player)
	if not ctx then
		return
	end
	assert(ctx) -- refine for the type checker (guarded above)
	if data.Sand >= Stats.GetCapacity(ctx) then
		if not state.FullNotified then
			state.FullNotified = true
			Net.Notify(player, "Info", "Your diggers are resting: backpack full! Sell to wake them up.")
		end
		return
	end
	state.FullNotified = false

	for slot, a in active do
		local def = Config.GetDigger(a.Id)
		if not def then
			continue
		end
		assert(def) -- refine for the type checker (guarded above)
		local stats = Config.GetDiggerStats(def, a.Level)
		local nextDig = state.NextDig[a.Id]
		if nextDig == nil then
			-- stagger freshly equipped diggers so several never fire on the same frame
			state.NextDig[a.Id] = now + stats.Interval * (0.3 + 0.7 * rng:NextNumber())
			continue
		end
		if now < nextDig then
			continue
		end
		state.NextDig[a.Id] = now + stats.Interval
		local point = pickPoint(player, feet, slot, #active)
		if not point then
			continue
		end
		local result = DigService.DigAt(player, point :: Vector3, {
			Power = stats.Power,
			Radius = stats.Radius,
			SandMultiplier = stats.SandMultiplier,
			Source = "Digger",
			Silent = true,
		})
		if result and result.Success then
			Net.FireAll("DiggerDug", player, a.Id, result.Position, result.SandGained)
		elseif result and result.Reason == "TooHard" and now - state.LastTooHard > TOO_HARD_NOTIFY_SECONDS then
			state.LastTooHard = now
			Net.Notify(player, "Info", def.Name .. " can't dig this layer. Upgrade to a stronger digger!")
		elseif result and result.Reason == "BackpackFull" then
			break
		end
	end
end

-- Lifecycle ----------------------------------------------------------------------------------------

local function idHandler(fn: (Player, string) -> boolean): (Player, any) -> ()
	return function(player: Player, id: any)
		if Net.IsString(id, 64) then
			fn(player, id)
		end
	end
end

function DiggerService.Init()
	Net.On("BuyDigger", idHandler(DiggerService.Buy), { Rate = 4, Window = 1 })
	Net.On("UpgradeDigger", idHandler(DiggerService.Upgrade), { Rate = 6, Window = 1 })
	Net.On("EquipDigger", idHandler(DiggerService.Equip), { Rate = 6, Window = 1 })
	Net.On("UnequipDigger", idHandler(DiggerService.Unequip), { Rate = 6, Window = 1 })
end

function DiggerService.Start()
	DataService.PlayerLoaded:Connect(function(player: Player)
		sanitize(player)
		publish(player)
	end)
	for _, player in DataService.GetLoadedPlayers() do
		sanitize(player)
		publish(player)
	end
	DataService.Changed:Connect(function(player: Player, keys: { string })
		if table.find(keys, "Diggers") or table.find(keys, "Rebirths") then
			publish(player)
		end
	end)
	MonetizationService.PassesChanged:Connect(function(player: Player)
		publish(player)
	end)
	if loopStarted then
		return
	end
	loopStarted = true
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in DataService.GetLoadedPlayers() do
				local ok, err = pcall(function(): any
					DiggerService.Step(player)
					return nil
				end)
				if not ok and os.clock() - lastLoopWarn > 10 then
					lastLoopWarn = os.clock()
					warn("[DiggerService] dig loop error: " .. tostring(err))
				end
			end
		end
	end)
end

function DiggerService.OnPlayerRemoving(player: Player)
	states[player] = nil
end

return DiggerService
