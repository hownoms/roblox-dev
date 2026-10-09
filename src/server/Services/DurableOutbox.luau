--!strict
--[[
	DurableOutbox — a small per-user DataStore outbox for accepted reward intents that are not
	(yet) durable in the player's own save. Shared by TrophyPendingStore and AdventureSettlement.

	It is not player progress storage: each user holds at most MaxPerUser small intents, keyed by
	receipt id, until the owner's next load on ANY server applies them to the normal DataService
	save. Protocol (exactly-once together with the receipts in the save):
		1. Settlement writes the intent (UpdateAsync, keyed by receipt id, so a retry is a no-op)
		   and only then reports it as durable.
		2. On load the owning service reads the intents, applies them to the live save (receipt
		   dedupe makes re-application a no-op) and saves the player through DataService.
		3. Only after that save succeeds are the applied receipt ids acknowledged (removed).
		   A crash between 2 and 3 re-applies on the next load as a Duplicate, then acknowledges.

	Storage: DataStore <StoreName>, key "Pending_<UserId>", value { Grants = { [receiptId] =
	entry } }. Studio without DataStore access (DataService.IsMock) uses an in-memory table, like
	DataService. A live server whose store is unavailable refuses new intents rather than
	pretending they are durable.
]]

local DataStoreService = game:GetService("DataStoreService")

local DataService = require(script.Parent.DataService)

export type Outbox = {
	StoreName: string,
	MaxPerUser: number,
	Init: () -> (),
	IsAvailable: () -> boolean,
	Add: (userId: number, receiptId: string, entry: { [string]: any }) -> (boolean, string?),
	Read: (userId: number) -> { [string]: any }?,
	Ack: (userId: number, receiptIds: { string }) -> boolean,
}

local ATTEMPTS = 3

local DurableOutbox = {}

--[[
	storeName: DataStore name. maxPerUser: bound on stored intents per user.
	isValid(receiptId, entry): re-validates entries read back (invalid ones are never returned and
	are dropped on the next acknowledgement, so they cannot hold the bound).
]]
function DurableOutbox.new(storeName: string, maxPerUser: number, isValid: (any, any) -> boolean): Outbox
	local store: DataStore? = nil
	local memory: { [string]: any }? = nil

	local function keyFor(userId: number): string
		return "Pending_" .. tostring(userId)
	end

	-- Runs transform(record) -> wrote? atomically on the user's entry, with retries.
	-- Returns true when the call completed (whether or not the transform chose to write).
	local function update(userId: number, transform: ({ Grants: { [string]: any } }) -> boolean): boolean
		local key = keyFor(userId)
		if memory then
			local mem = memory :: { [string]: any }
			local record = mem[key]
			if type(record) ~= "table" or type(record.Grants) ~= "table" then
				record = { Grants = {} }
			end
			if transform(record) then
				mem[key] = record
			end
			return true
		end
		if not store then
			return false
		end
		local dataStore = store :: DataStore
		for attempt = 1, ATTEMPTS do
			local ok, err = pcall(function()
				dataStore:UpdateAsync(key, function(old: any)
					local record = if type(old) == "table" and type(old.Grants) == "table" then old else { Grants = {} }
					if transform(record) then
						return record, { userId }
					end
					return nil -- nothing to write
				end)
			end)
			if ok then
				return true
			end
			warn(string.format("[DurableOutbox] %s/%s attempt %d failed: %s", storeName, key, attempt, tostring(err)))
			if attempt < ATTEMPTS and coroutine.isyieldable() then
				task.wait(attempt)
			end
		end
		return false
	end

	local outbox = {} :: Outbox
	outbox.StoreName = storeName
	outbox.MaxPerUser = maxPerUser

	function outbox.Init()
		store, memory = nil, nil
		if DataService.IsMock() then
			memory = {}
			return
		end
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(storeName)
		end)
		if ok then
			store = result
		else
			warn(
				"[DurableOutbox] " .. storeName .. " unavailable (" .. tostring(result) .. "); intents will be refused"
			)
		end
	end

	function outbox.IsAvailable(): boolean
		return store ~= nil or memory ~= nil
	end

	-- Durably records one intent. Yields. Returns (true) or (false, "PendingFull" | "PendingWriteFailed").
	-- Re-adding a receipt id that is already stored is a successful no-op (retry).
	function outbox.Add(userId: number, receiptId: string, entry: { [string]: any }): (boolean, string?)
		local full = false
		local done = update(userId, function(record)
			full = false
			if record.Grants[receiptId] ~= nil then
				return false -- already durable
			end
			local count = 0
			for id, existing in record.Grants do
				if isValid(id, existing) then
					count += 1
				end
			end
			if count >= maxPerUser then
				full = true
				return false
			end
			record.Grants[receiptId] = table.clone(entry)
			return true
		end)
		if not done then
			return false, "PendingWriteFailed"
		end
		if full then
			return false, "PendingFull"
		end
		return true, nil
	end

	-- Latest valid intents for a user (receiptId -> entry), or nil if the read failed. Yields.
	function outbox.Read(userId: number): { [string]: any }?
		local snapshot: { [string]: any } = {}
		local done = update(userId, function(record)
			snapshot = {}
			for receiptId, entry in record.Grants do
				if isValid(receiptId, entry) then
					snapshot[receiptId] = entry
				end
			end
			return false -- read only
		end)
		return if done then snapshot else nil
	end

	-- Removes applied (and any invalid) receipt ids. Yields. Returns success.
	function outbox.Ack(userId: number, receiptIds: { string }): boolean
		return update(userId, function(record)
			local changed = false
			for _, receiptId in receiptIds do
				if record.Grants[receiptId] ~= nil then
					record.Grants[receiptId] = nil
					changed = true
				end
			end
			for receiptId, entry in record.Grants do
				if not isValid(receiptId, entry) then
					record.Grants[receiptId] = nil
					changed = true
				end
			end
			return changed
		end)
	end

	return outbox
end

return DurableOutbox
