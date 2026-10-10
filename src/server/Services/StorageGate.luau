--!strict
--[[
	StorageGate — the only module under src/ that touches the engine's DataStore service.

	Every persistent store (player saves, reward outboxes, purchase history, ordered leaderboards)
	and every request-budget query goes through here, so the storage mode is enforced in one place:
	  Production  the service is fetched lazily on first use and each acquisition is counted.
	  LocalOnly   (CandidateProfile) the service is never even fetched; each attempt is counted
	              as refused and errors with "StorageGate: LocalOnly ...". Callers already pcall,
	              but in LocalOnly they check CandidateProfile / DataService.IsMock first and use
	              memory, so a correct boot records zero refusals too.
	  Refused     Main starts nothing; should anything still ask, it is refused the same way.

	Public API:
		StorageGate.GetDataStore(name, scope?): DataStore
		StorageGate.GetOrderedDataStore(name, scope?): OrderedDataStore
		StorageGate.GetRequestBudget(requestType): number
		StorageGate.Counters(): { Acquired = { ["<Kind>:<name>"] = n }, Refused = { ... } }
		StorageGate._Reset()   tests only: clear the counters
]]

local CandidateProfile = require(script.Parent.CandidateProfile)

local StorageGate = {}

local service: DataStoreService? = nil
local acquired: { [string]: number } = {}
local refused: { [string]: number } = {}

-- Errors (after counting) unless this server may use real storage.
local function gate(kind: string, name: string)
	local mode = CandidateProfile.Mode()
	if mode == "Production" then
		local key = kind .. ":" .. name
		acquired[key] = (acquired[key] or 0) + 1
		return
	end
	local key = kind .. ":" .. name
	refused[key] = (refused[key] or 0) + 1
	error(string.format("StorageGate: %s server refuses %s %s (no DataStore in this mode)", mode, kind, name), 3)
end

local function engine(): DataStoreService
	local current = service
	if current == nil then
		current = game:GetService("DataStoreService")
		service = current
	end
	return current :: DataStoreService
end

function StorageGate.GetDataStore(name: string, scope: string?): DataStore
	gate("DataStore", name)
	if scope ~= nil then
		return engine():GetDataStore(name, scope)
	end
	return engine():GetDataStore(name)
end

function StorageGate.GetOrderedDataStore(name: string, scope: string?): OrderedDataStore
	gate("OrderedDataStore", name)
	if scope ~= nil then
		return engine():GetOrderedDataStore(name, scope)
	end
	return engine():GetOrderedDataStore(name)
end

function StorageGate.GetRequestBudget(requestType: Enum.DataStoreRequestType): number
	gate("RequestBudget", requestType.Name)
	return engine():GetRequestBudgetForRequestType(requestType)
end

function StorageGate.Counters(): { Acquired: { [string]: number }, Refused: { [string]: number } }
	return { Acquired = table.clone(acquired), Refused = table.clone(refused) }
end

-- Tests only.
function StorageGate._Reset()
	table.clear(acquired)
	table.clear(refused)
end

return StorageGate
