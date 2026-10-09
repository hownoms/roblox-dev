--!strict
--[[
	TrophyPendingStore — durable outbox for accepted trophy grants that could not be applied to
	a loaded save on this server (the player's data is not loaded here).

	This is not player progress storage: it holds at most MAX_PER_USER small grant intents per
	user until the owner's next load on ANY server applies them to the normal DataService save.
	Protocol (exactly-once together with the save's receipts):
		1. Settlement writes the intent here (UpdateAsync, keyed by receipt id, idempotent) and
		   only then reports PendingRejoin.
		2. On load, TrophyService reads the intents, applies them to the live save (receipt /
		   ownership dedupe makes re-application a no-op), saves the player via DataService.
		3. Only after that save succeeds are the applied receipt ids acknowledged (removed) here.
		A crash between 2 and 3 re-applies on the next load as a Duplicate, then acknowledges.

	Storage: DataStore STORE_NAME, key "Pending_<UserId>", value { Grants = { [receiptId] =
	{ TrophyId, Source, RegionId, At } } }. Studio without DataStore access (DataService.IsMock)
	uses an in-memory table, like DataService. A live server whose store is unavailable refuses
	to accept pending grants rather than pretending they are durable.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.Shared.Trophies.Rules)
local DataService = require(script.Parent.DataService)

export type PendingGrant = {
	TrophyId: string,
	Source: string,
	RegionId: string,
	At: number,
}

local Pending = {}

Pending.STORE_NAME = "TrophyPendingGrants_v1"
Pending.MAX_PER_USER = 8
local ATTEMPTS = 3

local store: DataStore? = nil
local memory: { [string]: any }? = nil

local function keyFor(userId: number): string
	return "Pending_" .. tostring(userId)
end

function Pending.Init()
	store, memory = nil, nil
	if DataService.IsMock() then
		memory = {}
		return
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Pending.STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[TrophyPendingStore] store unavailable (" .. tostring(result) .. "); pending grants will be refused")
	end
end

function Pending.IsAvailable(): boolean
	return store ~= nil or memory ~= nil
end

-- Runs transform(record) -> record? atomically on the user's entry, with retries.
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
		warn(string.format("[TrophyPendingStore] %s attempt %d failed: %s", key, attempt, tostring(err)))
		if attempt < ATTEMPTS and coroutine.isyieldable() then
			task.wait(attempt)
		end
	end
	return false
end

-- Durably records one grant. Yields. Returns (true) or (false, "PendingFull" | "PendingWriteFailed").
function Pending.Add(userId: number, receiptId: string, grant: PendingGrant): (boolean, string?)
	local full = false
	local done = update(userId, function(record)
		full = false
		if record.Grants[receiptId] ~= nil then
			return false -- already durable (retry)
		end
		local count = 0
		for _ in record.Grants do
			count += 1
		end
		if count >= Pending.MAX_PER_USER then
			full = true
			return false
		end
		record.Grants[receiptId] = {
			TrophyId = grant.TrophyId,
			Source = grant.Source,
			RegionId = grant.RegionId,
			At = grant.At,
		}
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

-- Latest pending grants for a user (validated), or nil if the read failed. Yields.
function Pending.Read(userId: number): { [string]: PendingGrant }?
	local snapshot: { [string]: any } = {}
	local done = update(userId, function(record)
		snapshot = {}
		for receiptId, grant in record.Grants do
			if Rules.IsPendingGrant(receiptId, grant) then
				snapshot[receiptId] = grant
			end
		end
		return false -- read only
	end)
	return if done then snapshot else nil
end

-- Removes applied (or invalid) receipt ids. Yields. Returns success.
function Pending.Ack(userId: number, receiptIds: { string }): boolean
	return update(userId, function(record)
		local changed = false
		for _, receiptId in receiptIds do
			if record.Grants[receiptId] ~= nil then
				record.Grants[receiptId] = nil
				changed = true
			end
		end
		for receiptId, grant in record.Grants do
			if not Rules.IsPendingGrant(receiptId, grant) then
				record.Grants[receiptId] = nil -- unreadable entries never block the bound
				changed = true
			end
		end
		return changed
	end)
end

return Pending
