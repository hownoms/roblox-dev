--!strict
--[[
	State — client-side store (DataStore-like) of everything the UI renders:
	- Data: merged Types.PlayerData (full snapshot from DataChanged/GetData, then {key=value} deltas)
	- Passes: owned game passes by Config.Monetization key (GetOwnedPasses + purchase events)
	- Dig zone: the shared diggable beach strip, from Workspace attributes "DigZoneCFrame" /
	  "DigZoneSize" set by the server's World (State.GetDigZone / InDigZone / NearestSand)
	- ActiveEvents: active event ids (EventChanged / Workspace attribute "ActiveEvents")
	- PaidRandomRestricted (v2.2): Player attribute set by the server's PolicyService. true until
	  the server says false, so paid random items (Config.IsPaidRandom) never flash on screen for
	  players who may not see them. State.GetStatsContext() feeds Util/Stats (true luck + odds).

	Every key has its own Changed signal: State.Changed("Coins"):Connect(fn(new, old)).
	State.Observe(key, fn) calls fn right away with the current value and again on every change,
	so UI built before the data arrives fixes itself when it does (robust to late data).
	Data starts as Config.NewPlayerData() so nothing ever indexes nil.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Util"):WaitForChild("Stats"))
local Signal = require(script.Parent.Parent.Util.Signal)

type Signal = Signal.Signal
type Connection = Signal.Connection

local State = {}

State.Data = Config.NewPlayerData()
State.Loaded = false
State.Passes = {} :: { [string]: boolean }
State.ActiveEvents = {} :: { string }
State.PaidRandomRestricted = true -- v2.2: until PolicyService's attribute says false

State.LoadedSignal = Signal.new() -- fired once when the first real data arrives
State.AnyChanged = Signal.new() -- (key, new, old)

local SPECIAL_KEYS = { Passes = true, ActiveEvents = true, PaidRandomRestricted = true }

local signals: { [string]: Signal } = {}
local gotSnapshot = false
local initialized = false

function State.Changed(key: string): Signal
	local signal = signals[key]
	if not signal then
		signal = Signal.new()
		signals[key] = signal
	end
	return signal
end

function State.Get(key: string): any
	if SPECIAL_KEYS[key] then
		return (State :: any)[key]
	end
	return (State.Data :: any)[key]
end

local function set(key: string, value: any)
	local old = State.Get(key)
	if SPECIAL_KEYS[key] then
		(State :: any)[key] = value
	else
		(State.Data :: any)[key] = value
	end
	local signal = signals[key]
	if signal then
		signal:Fire(value, old)
	end
	State.AnyChanged:Fire(key, value, old)
end

-- Calls fn(value) now and on every change. Returns the connection.
function State.Observe(key: string, fn: (any, any) -> ()): Connection
	task.spawn(fn, State.Get(key), nil)
	return State.Changed(key):Connect(fn)
end

-- Calls fn() now and whenever ANY of the keys change (coalesced to once per frame).
function State.ObserveMany(keys: { string }, fn: () -> ()): { Connection }
	local queued = false
	local function schedule()
		if queued then
			return
		end
		queued = true
		task.defer(function()
			queued = false
			fn()
		end)
	end
	local connections = {}
	for _, key in keys do
		table.insert(connections, State.Changed(key):Connect(schedule))
	end
	task.spawn(fn)
	return connections
end

local function markLoaded()
	if not State.Loaded then
		State.Loaded = true
		State.LoadedSignal:Fire(State.Data)
	end
end

-- Merge a full snapshot or partial delta into State.Data.
function State.Apply(delta: { [string]: any })
	for key, value in delta do
		if typeof(key) == "string" then
			set(key, value)
		end
	end
end

-- Resolves immediately when loaded, otherwise yields until the first data arrives.
function State.WaitForData(): Types.PlayerData
	if not State.Loaded then
		State.LoadedSignal:Wait()
	end
	return State.Data
end

-- Passes ------------------------------------------------------------------------------------

function State.OwnsPass(key: string): boolean
	return State.Passes[key] == true
end

-- v2.2 Rebirth perks (Config.RebirthPerks): level of a perk (0 = not bought).
function State.PerkLevel(perkId: string): number
	return Config.RebirthPerks.Level(State.Data.RebirthPerks, perkId)
end

-- Sell Anywhere: the game pass OR the earned rebirth perk (server: EconomyService.CanSellAnywhere).
function State.CanSellAnywhere(): boolean
	return State.OwnsPass("SellAnywhere") or Config.RebirthPerks.HasSellAnywhere(State.Data.RebirthPerks)
end

function State.SetPassOwned(key: string, owned: boolean)
	local copy = table.clone(State.Passes)
	copy[key] = owned
	set("Passes", copy)
end

function State.RefreshPasses()
	task.spawn(function()
		local ok, result = pcall(function()
			return Remotes.GetFunction("GetOwnedPasses"):InvokeServer()
		end)
		if ok and typeof(result) == "table" then
			local passes: { [string]: boolean } = {}
			for key, owned in result do
				if typeof(key) == "string" then
					passes[key] = owned == true
				end
			end
			set("Passes", passes)
		end
	end)
end

-- Settings ----------------------------------------------------------------------------------

function State.GetSetting(key: string, default: any): any
	local value = State.Data.Settings and State.Data.Settings[key]
	if value == nil then
		return default
	end
	return value
end

-- Optimistic: updates the local copy immediately, then tells the server.
function State.SetSetting(key: string, value: any)
	local settings = table.clone(State.Data.Settings or {})
	settings[key] = value
	set("Settings", settings)
	task.spawn(function()
		Remotes.Get("SetSetting"):FireServer(key, value)
	end)
end

-- Derived values ------------------------------------------------------------------------------

function State.ServerNow(): number
	return Workspace:GetServerTimeNow()
end

function State.GetShovel(): Types.ShovelDef
	return Config.GetShovel(State.Data.Shovel) or Config.Shovels[1]
end

function State.GetBackpack(): Types.BackpackDef
	return Config.GetBackpack(State.Data.Backpack) or Config.Backpacks[1]
end

-- Last effective capacity reported by the server (DigResult.Capacity). Preferred over the
-- local estimate because the server may apply bonuses the client doesn't know about.
State.ServerCapacity = nil :: number?

function State.GetCapacity(): number
	local serverCapacity = State.ServerCapacity
	if serverCapacity then
		return serverCapacity
	end
	local mega = if State.OwnsPass("MegaBackpack")
		then (Config.Monetization.GamePasses.MegaBackpack.CapacityMultiplier or 2)
		else 1
	local pockets = Config.RebirthPerks.CapacityFactor(State.Data.RebirthPerks) -- v2.2 Deep Pockets
	return math.floor(State.GetBackpack().Capacity * Config.RebirthMultiplier(State.Data.Rebirths) * mega * pockets)
end

function State.GetEquippedPetIds(): { string }
	local ids = {}
	local pets = State.Data.Pets
	if pets then
		for _, pet in pets do
			if pet.Equipped then
				table.insert(ids, pet.Id)
			end
		end
	end
	return ids
end

-- Base PetSlots + every owned pass's ExtraPetSlots (ExtraPets +2, AutoDig +1), like Stats.GetPetSlots.
function State.GetPetSlots(): number
	local extra = 0
	for key, pass in Config.Monetization.GamePasses do
		if pass.ExtraPetSlots and State.OwnsPass(key) then
			extra += pass.ExtraPetSlots
		end
	end
	extra += Config.RebirthPerks.ExtraPetSlots(State.Data.RebirthPerks) -- v2.2 Pet Den perk
	return (State.Data.PetSlots or Config.MAX_EQUIPPED_PETS) + extra
end

function State.GetPetMultiplier(): number
	local ids = {}
	local golden: { [number]: boolean } = {}
	for _, pet in State.Data.Pets or {} :: { [string]: Types.PetInstance } do
		if pet.Equipped then
			table.insert(ids, pet.Id)
			golden[#ids] = pet.Golden == true
		end
	end
	return Config.PetMultiplier(ids, golden)
end

-- v2.2: a Util/Stats context from the replicated state (same inputs the server uses), for true
-- odds / luck in the UI: Stats.GetLuck(State.GetStatsContext()).
function State.GetStatsContext(): Stats.Context
	local localPlayer = Players.LocalPlayer
	local friends = localPlayer:GetAttribute("FriendsInServer")
	return {
		Data = State.Data,
		Passes = State.Passes,
		IsPremium = localPlayer:GetAttribute("Premium") == true,
		InGroup = localPlayer:GetAttribute("InGroup") == true,
		FriendsInServer = if typeof(friends) == "number" then friends else 0,
		ActiveEvents = State.ActiveEvents,
		Now = State.ServerNow(),
	}
end

-- v2.2 policy: hide paid random items (Config.IsPaidRandom) for restricted players.
function State.IsPaidRandomRestricted(): boolean
	return State.PaidRandomRestricted ~= false
end

-- Can this pass / product be shown and prompted? kind: "GamePass" | "Product".
function State.CanBuy(kind: string, key: string): boolean
	return not (Config.IsPaidRandom(kind, key) and State.IsPaidRandomRestricted())
end

-- Seconds left on a boost (0 if inactive).
function State.GetBoostRemaining(boostId: string): number
	local expires = State.Data.Boosts and State.Data.Boosts[boostId]
	if not expires then
		return 0
	end
	return math.max(0, expires - State.ServerNow())
end

-- Local estimate of the dig cooldown (server is authoritative).
function State.GetCooldown(): number
	local cooldown = State.GetShovel().Cooldown
	for _, boost in Config.Boosts do
		if boost.Kind == "Speed" and State.GetBoostRemaining(boost.Id) > 0 then
			cooldown /= boost.Multiplier
		end
	end
	for key, pass in Config.Monetization.GamePasses do
		if pass.SpeedMultiplier and State.OwnsPass(key) then
			cooldown /= pass.SpeedMultiplier
		end
	end
	return cooldown
end

function State.IsEventActive(eventId: string): boolean
	return table.find(State.ActiveEvents, eventId) ~= nil
end

function State.SurfaceY(): number
	return Config.SURFACE_Y
end

-- The dig zone (CFrame at the centre of the flat surface, Size = X/Z footprint + depth), or nil
-- until the server's map attributes have replicated.
function State.GetDigZone(): (CFrame?, Vector3?)
	local cf = Workspace:GetAttribute("DigZoneCFrame")
	local size = Workspace:GetAttribute("DigZoneSize")
	if typeof(cf) == "CFrame" and typeof(size) == "Vector3" then
		return cf, size
	end
	return nil, nil
end

-- Is `position` (X/Z) inside the dig zone footprint (+ `margin` studs)? Unknown zone -> true
-- (let the server decide).
function State.InDigZone(position: Vector3, margin: number?): boolean
	local cf, size = State.GetDigZone()
	if not cf or not size then
		return true
	end
	local rel = (cf :: CFrame):PointToObjectSpace(position)
	local m = margin or 0
	return math.abs(rel.X) <= (size :: Vector3).X / 2 + m and math.abs(rel.Z) <= (size :: Vector3).Z / 2 + m
end

-- Closest surface point of the dig zone to `from`, `inset` studs inside its edges.
function State.NearestSand(from: Vector3, inset: number?): Vector3?
	local cf, size = State.GetDigZone()
	if not cf or not size then
		return nil
	end
	local zone = cf :: CFrame
	local half = (size :: Vector3) / 2
	local i = inset or 0
	local rel = zone:PointToObjectSpace(from)
	local x = math.clamp(rel.X, -math.max(0, half.X - i), math.max(0, half.X - i))
	local z = math.clamp(rel.Z, -math.max(0, half.Z - i), math.max(0, half.Z - i))
	return zone:PointToWorldSpace(Vector3.new(x, 0, z))
end

-- Init ----------------------------------------------------------------------------------------

local function parseEventAttribute()
	local value = Workspace:GetAttribute("ActiveEvents")
	if typeof(value) ~= "string" then
		return
	end
	local ids = {}
	for id in string.gmatch(value, "[^,%s]+") do
		table.insert(ids, id)
	end
	set("ActiveEvents", ids)
end

function State.Init()
	if initialized then
		return
	end
	initialized = true

	-- Events fired before we connect are queued by Roblox, so the snapshot is never lost.
	task.spawn(function()
		Remotes.Get("DataChanged").OnClientEvent:Connect(function(payload: any)
			if typeof(payload) ~= "table" then
				return
			end
			if payload.Version ~= nil and payload.FirstJoin ~= nil then
				gotSnapshot = true
			end
			State.Apply(payload)
			markLoaded()
		end)
	end)

	task.spawn(function()
		local getData = Remotes.GetFunction("GetData")
		for attempt = 1, 6 do
			if gotSnapshot then
				break
			end
			local ok, result = pcall(function()
				return getData:InvokeServer()
			end)
			if ok and typeof(result) == "table" then
				if not gotSnapshot then
					gotSnapshot = true
					State.Apply(result)
					markLoaded()
				end
				break
			end
			task.wait(attempt)
		end
	end)

	task.spawn(function()
		Remotes.Get("EventChanged").OnClientEvent:Connect(function(ids: any)
			if typeof(ids) == "table" then
				local list = {}
				for _, id in ids do
					if typeof(id) == "string" then
						table.insert(list, id)
					end
				end
				set("ActiveEvents", list)
			end
		end)
	end)

	-- equipment / rebirth / pass changes invalidate the server-reported capacity
	for _, key in { "Backpack", "Rebirths", "Passes", "RebirthPerks" } do
		State.Changed(key):Connect(function()
			State.ServerCapacity = nil
		end)
	end

	Workspace:GetAttributeChangedSignal("ActiveEvents"):Connect(parseEventAttribute)
	parseEventAttribute()

	-- The server checks pass ownership asynchronously after join (GetOwnedPasses may answer
	-- before that finished) and mirrors it as Player attributes "Pass_<Key>": follow them.
	local localPlayer = Players.LocalPlayer
	local function readPolicy()
		local restricted = localPlayer:GetAttribute("PaidRandomRestricted") ~= false
		if State.PaidRandomRestricted ~= restricted then
			set("PaidRandomRestricted", restricted)
		end
	end
	readPolicy()
	localPlayer.AttributeChanged:Connect(function(name: string)
		if name == "PaidRandomRestricted" then
			readPolicy()
		elseif string.sub(name, 1, 5) == "Pass_" then
			local key = string.sub(name, 6)
			local owned = localPlayer:GetAttribute(name) == true
			if State.OwnsPass(key) ~= owned then
				State.SetPassOwned(key, owned)
			end
		end
	end)

	State.RefreshPasses()
end

return State
