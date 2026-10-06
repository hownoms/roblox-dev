--!strict
--[[
	DataService — session-locked player persistence + client replication.

	Storage record (DataStore Config.DATASTORE_NAME, key "Player_<UserId>"):
		{ Data = PlayerData, Lock = { Owner = <session id>, Time = unix }?, SavedAt = unix }
	- Load takes the lock with UpdateAsync. A lock held by another live server is respected
	  (retry with backoff, then kick); a lock older than Config.SESSION_LOCK_SECONDS is stolen.
	- Every save refreshes the lock; the final save on leave releases it. A save that finds the
	  lock owned by someone else aborts (the other server owns the truth now).
	- Studio without API access: in-memory store (warns once).

	Replication: every mutation marks top-level keys dirty; once per resumption cycle the service
	fires DataChanged(delta) with delta = { [TopLevelKey] = <full current value of that key> }.
	The first DataChanged after load is the full PlayerData. Clients just merge top-level keys.

	Public API:
		DataService.Get(player): PlayerData?
		DataService.IsLoaded(player): boolean
		DataService.WaitForData(player, timeout?): PlayerData?
		DataService.Update(player, key, fn(old) -> new): any
		DataService.Set(player, key, value)
		DataService.Increment(player, key, amount): number
		DataService.Mutate(player, keys, fn(data))   -- in-place edit of several keys
		DataService.MarkDirty(player, ...keys)
		DataService.SaveAsync(player): boolean
		DataService.IsMock(): boolean
		DataService.PlayerLoaded: Signal<Player, PlayerData>
		DataService.Changed: Signal<Player, { string }>  (batched keys, after replication)
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Util.Format)
local Signal = require(Shared.Util.Signal)
local TableUtil = require(Shared.Util.TableUtil)

type PlayerData = Types.PlayerData

type Session = {
	Player: Player,
	Key: string,
	Data: PlayerData,
	Dirty: { [string]: boolean },
	FlushScheduled: boolean,
	Released: boolean,
	Leaderstats: {
		Coins: StringValue,
		Depth: IntValue,
		Rebirths: IntValue,
	}?,
}

local LOAD_ATTEMPTS = 6
local SAVE_ATTEMPTS = 4
local SHUTDOWN_TIMEOUT = 25

local DataService = {}

DataService.PlayerLoaded = Signal.new() :: Signal.Signal<Player, PlayerData>
DataService.Changed = Signal.new() :: Signal.Signal<Player, { string }>

local SESSION_ID = (if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false))
	.. ":"
	.. tostring(os.time())

local store: DataStore? = nil
local useMock = false
local mockStore: { [string]: any } = {}

local sessions: { [Player]: Session } = {}
local releasing: { [number]: boolean } = {} -- userId -> final save in flight
local activeSaves = 0
local shuttingDown = false

-- v1 -> v2 (v2.1 companions merge): every owned Garage digger becomes ONE vehicle pet with the
-- same id (Config/Pets.luau keeps the old digger ids). Upgrade levels do not carry over (pets have
-- no levels). A digger that was equipped is equipped as a pet while the save's base PetSlots
-- allow (pass slots are unknown at load; PetService trims/fills later). Converted pets may push
-- the inventory over PET_INVENTORY_LIMIT: nothing a player bought is lost. data.Diggers is
-- emptied (the field stays so old code paths and Reconcile see a table).
local function migrateDiggersToPets(data: { [string]: any })
	local diggers = data.Diggers
	if type(diggers) ~= "table" then
		data.Diggers = {}
		return
	end
	if type(data.Pets) ~= "table" then
		data.Pets = {}
	end
	local pets = data.Pets :: { [string]: any }
	local slots = if type(data.PetSlots) == "number" then data.PetSlots else Config.MAX_EQUIPPED_PETS
	local equipped = 0
	for _, pet in pets do
		if type(pet) == "table" and pet.Equipped == true then
			equipped += 1
		end
	end
	-- most valuable first (Config order = crate order = old Garage price order), so the best
	-- converted vehicles get the free equip slots
	local ids = {}
	for id in diggers do
		if type(id) == "string" and Config.GetPet(id) and Config.GetPetDig(id) then
			table.insert(ids, id)
		end
	end
	local order: { [string]: number } = {}
	for i, def in Config.Pets do
		order[def.Id] = i
	end
	table.sort(ids, function(a: string, b: string): boolean
		return order[a] > order[b]
	end)
	for _, id in ids do
		local inst = diggers[id]
		local wasEquipped = type(inst) == "table" and inst.Equipped == true
		local equip = wasEquipped and equipped < slots
		if equip then
			equipped += 1
		end
		pets[HttpService:GenerateGUID(false)] = { Id = id, Equipped = equip }
	end
	data.Diggers = {}
end

-- v2 -> v3 (discovery slice): unsold treasures (data.Treasures, id -> count) become plain finds
-- (Normal size, no material, Good quality = exactly the old SellValue each), and every treasure
-- already in the Index gets its default variants (Normal, None) ticked in FindVariants.
-- data.Treasures is emptied (the field stays for Reconcile / old code paths).
local function migrateTreasuresToFinds(data: { [string]: any })
	local finds = if type(data.Finds) == "table" then data.Finds else {}
	data.Finds = finds
	local variants = if type(data.FindVariants) == "table" then data.FindVariants else {}
	data.FindVariants = variants
	if type(data.Treasures) == "table" then
		for id, count in data.Treasures do
			if type(id) == "string" and Config.GetTreasure(id) and type(count) == "number" and count >= 1 then
				local key = id .. "|Normal|None|Good"
				finds[key] = (if type(finds[key]) == "number" then finds[key] else 0) + math.floor(count)
			end
		end
	end
	data.Treasures = {}
	if type(data.Index) == "table" then
		for id, found in data.Index do
			if type(id) == "string" and found == true and Config.GetTreasure(id) then
				variants[id .. "/Normal"] = true
				variants[id .. "/None"] = true
			end
		end
	end
end

-- Migrations: MIGRATIONS[v] upgrades a save from version v to v + 1.
local MIGRATIONS: { [number]: (data: { [string]: any }) -> ...any } = {
	[1] = migrateDiggersToPets,
	[2] = migrateTreasuresToFinds,
}

DataService._MigrateDiggersToPets = migrateDiggersToPets -- tests
DataService._MigrateTreasuresToFinds = migrateTreasuresToFinds -- tests

local dataChanged: RemoteEvent
local getDataFunction: RemoteFunction

-- Helpers ---------------------------------------------------------------------------------------

local function keyFor(userId: number): string
	return "Player_" .. tostring(userId)
end

local function backoff(attempt: number): number
	return math.min(2 ^ attempt, 15) + math.random()
end

local function migrate(raw: { [string]: any }): { [string]: any }
	local version = if type(raw.Version) == "number" then raw.Version else 0
	while version < Config.DATA_VERSION do
		local step = MIGRATIONS[version]
		if step then
			local ok, err = pcall(step, raw)
			if not ok then
				warn(string.format("[DataService] migration %d failed: %s", version, tostring(err)))
			end
		end
		version += 1
	end
	raw.Version = math.max(version, Config.DATA_VERSION)
	return raw
end

-- Make a loaded save safe to use: fill missing fields, repair invalid equipment refs.
local function sanitize(raw: any): PlayerData
	local template = Config.NewPlayerData()
	if type(raw) ~= "table" then
		return template
	end
	migrate(raw)
	TableUtil.Reconcile(raw, template :: any)
	local data = raw :: PlayerData

	if not Config.GetShovel(data.Shovel) or not data.OwnedShovels[data.Shovel] then
		data.Shovel = template.Shovel
	end
	if not Config.GetBackpack(data.Backpack) or not data.OwnedBackpacks[data.Backpack] then
		data.Backpack = template.Backpack
	end
	for uid, pet in data.Pets do
		if type(pet) ~= "table" or type(pet.Id) ~= "string" or not Config.GetPet(pet.Id) then
			data.Pets[uid] = nil
		elseif type(pet.Equipped) ~= "boolean" then
			pet.Equipped = false
		end
	end
	for _, field in { "Coins", "Sand", "TotalSandDug", "RebirthTokens", "MaxDepth" } do
		local value = (data :: any)[field]
		if value < 0 then
			(data :: any)[field] = 0
		end
	end
	data.Rebirths = math.max(0, math.floor(data.Rebirths))
	return data
end

-- Leaderstats -----------------------------------------------------------------------------------

local function createLeaderstats(session: Session)
	local player = session.Player
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Parent = folder

	local depth = Instance.new("IntValue")
	depth.Name = "Depth"
	depth.Parent = folder

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = folder

	session.Leaderstats = { Coins = coins, Depth = depth, Rebirths = rebirths }
	folder.Parent = player
end

local function updateLeaderstats(session: Session)
	local stats = session.Leaderstats
	if not stats then
		return
	end
	local values = stats :: { Coins: StringValue, Depth: IntValue, Rebirths: IntValue }
	local data = session.Data
	values.Coins.Value = Format.Abbreviate(data.Coins)
	values.Depth.Value = Config.DepthToMeters(data.MaxDepth)
	values.Rebirths.Value = data.Rebirths
end

-- Replication -----------------------------------------------------------------------------------

local function flush(session: Session)
	session.FlushScheduled = false
	local delta: { [string]: any } = {}
	local keys: { string } = {}
	for key in session.Dirty do
		delta[key] = (session.Data :: any)[key]
		table.insert(keys, key)
	end
	table.clear(session.Dirty)
	if #keys == 0 then
		return
	end
	if session.Player.Parent and sessions[session.Player] == session then
		dataChanged:FireClient(session.Player, delta)
	end
	if delta.Coins ~= nil or delta.MaxDepth ~= nil or delta.Rebirths ~= nil then
		updateLeaderstats(session)
	end
	DataService.Changed:Fire(session.Player, keys)
end

local function markDirty(session: Session, key: string)
	session.Dirty[key] = true
	if not session.FlushScheduled then
		session.FlushScheduled = true
		task.defer(flush, session)
	end
end

-- Storage ---------------------------------------------------------------------------------------

local function detectStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if not ok then
		useMock = true
		warn("[DataService] DataStores unavailable (" .. tostring(result) .. "); using in-memory data.")
		return
	end
	if RunService:IsStudio() then
		local probeOk, err = pcall(function()
			return (result :: DataStore):GetAsync("__probe")
		end)
		if not probeOk then
			useMock = true
			warn("[DataService] Studio has no DataStore access (" .. tostring(err) .. "); using in-memory data.")
			return
		end
	end
	store = result
end

-- Returns (data, failReason). failReason is "locked" or "error" when data is nil.
local function loadAsync(player: Player): (PlayerData?, string?)
	local key = keyFor(player.UserId)
	if useMock or not store then
		return sanitize(TableUtil.DeepCopy(mockStore[key])), nil
	end
	local dataStore = store :: DataStore
	local lastReason = "error"
	for attempt = 1, LOAD_ATTEMPTS do
		local lockedBy: string? = nil
		local ok, result = pcall(function()
			return dataStore:UpdateAsync(key, function(old: any)
				lockedBy = nil
				local record = if type(old) == "table" then old else {}
				local lock = record.Lock
				local now = os.time()
				if
					type(lock) == "table"
					and lock.Owner ~= SESSION_ID
					and type(lock.Time) == "number"
					and now - lock.Time < Config.SESSION_LOCK_SECONDS
				then
					lockedBy = tostring(lock.Owner)
					return nil -- abort: another live server owns this save
				end
				record.Lock = { Owner = SESSION_ID, Time = now }
				return record, { player.UserId }
			end)
		end)
		if ok and lockedBy == nil and type(result) == "table" then
			return sanitize(result.Data), nil
		elseif ok then
			lastReason = "locked"
		else
			lastReason = "error"
			warn(string.format("[DataService] load %s attempt %d failed: %s", key, attempt, tostring(result)))
		end
		if player.Parent == nil then
			return nil, "left"
		end
		task.wait(backoff(attempt))
	end
	return nil, lastReason
end

-- Writes the session's data. Returns false if the write failed or the lock was stolen.
local function saveAsync(session: Session, release: boolean): boolean
	local payload = TableUtil.DeepCopy(session.Data)
	if useMock or not store then
		mockStore[session.Key] = payload
		return true
	end
	local dataStore = store :: DataStore
	activeSaves += 1
	local success = false
	for attempt = 1, SAVE_ATTEMPTS do
		local stolen = false
		local ok, err = pcall(function()
			dataStore:UpdateAsync(session.Key, function(old: any)
				stolen = false
				local record = if type(old) == "table" then old else {}
				local lock = record.Lock
				if type(lock) == "table" and lock.Owner ~= SESSION_ID then
					stolen = true
					return nil
				end
				record.Data = payload
				record.SavedAt = os.time()
				record.Lock = if release then nil else { Owner = SESSION_ID, Time = os.time() }
				return record, { session.Player.UserId }
			end)
		end)
		if ok then
			if stolen then
				warn("[DataService] session lock for " .. session.Key .. " was taken by another server; not saving")
				if not release and session.Player.Parent then
					session.Player:Kick("Your data was opened on another server. Please rejoin.")
				end
			else
				success = true
			end
			break
		end
		warn(string.format("[DataService] save %s attempt %d failed: %s", session.Key, attempt, tostring(err)))
		if attempt < SAVE_ATTEMPTS then
			task.wait(if shuttingDown then 1 else backoff(attempt))
		end
	end
	activeSaves -= 1
	return success
end

local function release(player: Player)
	local session = sessions[player]
	if not session or session.Released then
		return
	end
	session.Released = true
	sessions[player] = nil
	releasing[player.UserId] = true
	saveAsync(session, true)
	releasing[player.UserId] = nil
end

-- Lifecycle -------------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	-- Same-server rejoin while the previous session is still saving: wait for it.
	local waitUntil = os.clock() + 30
	while releasing[player.UserId] and os.clock() < waitUntil do
		task.wait(0.25)
	end

	local data, reason = loadAsync(player)
	if not data then
		if reason ~= "left" and player.Parent then
			player:Kick(
				if reason == "locked"
					then "Your save is still in use by another server. Please rejoin in a minute!"
					else "We couldn't load your save (Roblox data servers are busy). Please rejoin!"
			)
		end
		return
	end
	local loaded = data :: PlayerData

	local session: Session = {
		Player = player,
		Key = keyFor(player.UserId),
		Data = loaded,
		Dirty = {},
		FlushScheduled = false,
		Released = false,
		Leaderstats = nil,
	}

	if player.Parent == nil then
		-- Left while loading: give the lock back without keeping a session.
		releasing[player.UserId] = true
		saveAsync(session, true)
		releasing[player.UserId] = nil
		return
	end

	sessions[player] = session
	createLeaderstats(session)
	updateLeaderstats(session)
	dataChanged:FireClient(player, loaded)
	DataService.PlayerLoaded:Fire(player, loaded)
end

-- Public API ------------------------------------------------------------------------------------

function DataService.Get(player: Player): PlayerData?
	local session = sessions[player]
	return if session then session.Data else nil
end

function DataService.IsLoaded(player: Player): boolean
	return sessions[player] ~= nil
end

function DataService.IsMock(): boolean
	return useMock
end

function DataService.WaitForData(player: Player, timeout: number?): PlayerData?
	local deadline = os.clock() + (timeout or 30)
	while player.Parent and os.clock() < deadline do
		local session = sessions[player]
		if session then
			return session.Data
		end
		task.wait(0.1)
	end
	local session = sessions[player]
	return if session then session.Data else nil
end

function DataService.MarkDirty(player: Player, ...: string)
	local session = sessions[player]
	if not session then
		return
	end
	for i = 1, select("#", ...) do
		markDirty(session, (select(i, ...)))
	end
end

function DataService.Update(player: Player, key: string, fn: (any) -> any): any
	local session = sessions[player]
	if not session then
		return nil
	end
	local data = session.Data :: any
	local value = fn(data[key])
	data[key] = value
	markDirty(session, key)
	return value
end

function DataService.Set(player: Player, key: string, value: any)
	DataService.Update(player, key, function()
		return value
	end)
end

-- Adds `amount` to a numeric field (never below 0). Returns the new value.
function DataService.Increment(player: Player, key: string, amount: number): number
	if amount ~= amount or math.abs(amount) == math.huge then
		return DataService.Get(player) and (DataService.Get(player) :: any)[key] or 0
	end
	return DataService.Update(player, key, function(old: any)
		local current = if type(old) == "number" then old else 0
		return math.max(0, current + amount)
	end) or 0
end

-- In-place edit of several keys at once: DataService.Mutate(player, {"Coins","Sand"}, function(d) ... end)
function DataService.Mutate(player: Player, keys: { string }, fn: (PlayerData) -> ()): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	fn(session.Data)
	for _, key in keys do
		markDirty(session, key)
	end
	return true
end

function DataService.SaveAsync(player: Player): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	return saveAsync(session, false)
end

-- Service lifecycle -----------------------------------------------------------------------------

function DataService.Init()
	dataChanged = Remotes.Get("DataChanged")
	getDataFunction = Remotes.GetFunction("GetData")
	detectStore()

	getDataFunction.OnServerInvoke = function(player: Player): any
		return DataService.WaitForData(player, 20)
	end
end

function DataService.Start()
	-- Autosave: each player every AUTOSAVE_SECONDS, staggered across the interval.
	task.spawn(function()
		while true do
			local list = {}
			for player in sessions do
				table.insert(list, player)
			end
			local gap = Config.AUTOSAVE_SECONDS / math.max(#list, 1)
			for _, player in list do
				local session = sessions[player]
				if session and not session.Released then
					task.spawn(saveAsync, session, false)
				end
				task.wait(gap)
			end
			if #list == 0 then
				task.wait(Config.AUTOSAVE_SECONDS)
			end
		end
	end)

	game:BindToClose(function()
		shuttingDown = true
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				release(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + SHUTDOWN_TIMEOUT
		while (pending > 0 or activeSaves > 0) and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

function DataService.OnPlayerAdded(player: Player)
	task.spawn(onPlayerAdded, player)
end

function DataService.OnPlayerRemoving(player: Player)
	task.spawn(release, player)
end

-- For other services: all currently loaded players.
function DataService.GetLoadedPlayers(): { Player }
	local list = {}
	for player in sessions do
		table.insert(list, player)
	end
	return list
end

return DataService
