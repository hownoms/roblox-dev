--!strict
--[[
	Trophies.Rules — pure trophy/camp rules shared by TrophyService and the tests. No services,
	no Instances, no yields. Everything here operates on plain save tables.

	Persisted fields (top-level PlayerData keys named by game bible ch.04 "Persistence"):
		TrophyRecords  { [trophyId]: TrophyRecord }      one record per trophy id, never deleted
		CampLayout     { Placements: { Placement }, NextId: number }
		RewardReceipts { ["trophy:..."]: settledUnix }   only the "trophy:" namespace is ours
		Cosmetics      { camp_trophy_stand = record }    only the camp_trophy_stand key is ours

	Migrate() adds these fields to any existing save without touching any other key, repairs
	malformed values, and is idempotent (running it twice changes nothing the second time).
	It never removes an owned trophy and never invents one: legacy saves start with no
	adventure trophies, because no legacy evidence of a Spring Vault completion exists.
]]

local Catalog = require(script.Parent.Catalog)

export type TrophyRecord = {
	Kind: string,
	Source: string, -- completion context, e.g. "event_vault"
	RegionId: string,
	AcquiredAt: number, -- unix
	ReceiptId: string,
	Legacy: boolean,
	ContentVersion: number,
}

export type Placement = {
	Id: number,
	TrophyId: string,
	X: number, -- grid cell 0..CELLS-1 along the pad's X axis
	Z: number, -- grid cell 0..CELLS-1 along the pad's Z axis
	Rot: number, -- 0 / 90 / 180 / 270 degrees
}

export type CampLayout = {
	Placements: { Placement },
	NextId: number,
}

export type Participant = {
	UserId: number,
	Points: number, -- validated contribution points (bible ch.04 "Contribution points")
	ActiveSeconds: number, -- seconds of validated active participation
	ObjectiveCompletions: number, -- validated objectives this player completed
	PresentForObjective: boolean, -- present for at least one validated objective completion
}

local Rules = {}

-- Camp pad (bible ch.02 "Camps and trophies"): 24x24 pad, 2-stud grid, 4 rotations.
Rules.PAD_SIZE = 24
Rules.GRID = 2
Rules.CELLS = 12 -- PAD_SIZE / GRID
Rules.ROTATIONS = table.freeze({ 0, 90, 180, 270 })
Rules.TROPHY_SLOTS = 3 -- starting trophy slots; tier upgrades are later quest rewards
Rules.MAX_PLACEMENTS = 32 -- whole layout cap (bible ch.04 "Trophy records and camp storage")

-- Bounds on persisted tables.
Rules.MAX_TROPHY_RECORDS = 256 -- new grants beyond this are refused; loads never delete
Rules.RECEIPT_PREFIX = "trophy:"
Rules.RECEIPT_LIMIT = 512 -- rolling settled window (bible ch.04 "Persistence")
Rules.RECEIPT_TTL = 30 * 24 * 60 * 60
Rules.MAX_INSTANCE_ID_LENGTH = 80
Rules.MAX_PARTICIPANTS = 16 -- server capacity; admission limits per event belong to the event

-- Eligibility (bible ch.04 "Contribution and eligibility").
Rules.MIN_POINTS = 5
Rules.MIN_ACTIVE_SECONDS = 30

Rules.CONTENT_VERSION = 1

-- Mara's trophy stand (catalog camp_trophy_stand). Production display requires owning it; the
-- first eligible Spring Vault completion grants it together with the trophy.
Rules.STAND_ID = "camp_trophy_stand"

function Rules.HasStand(data: { [string]: any }): boolean
	local cosmetics = data.Cosmetics
	return type(cosmetics) == "table" and cosmetics[Rules.STAND_ID] ~= nil
end

local function isInteger(v: any, min: number, max: number): boolean
	return type(v) == "number" and v == v and v % 1 == 0 and v >= min and v <= max
end

local function isFiniteNonNegative(v: any): boolean
	return type(v) == "number" and v == v and v >= 0 and v ~= math.huge
end

function Rules.IsRotation(v: any): boolean
	return type(v) == "number" and table.find(Rules.ROTATIONS, v) ~= nil
end

-- Receipts ---------------------------------------------------------------------------------

-- One receipt per (adventure instance, player, final stage, reward version).
function Rules.ReceiptId(instanceId: string, userId: number, rewardVersion: number): string
	return string.format("%s%s:%d:final:v%d", Rules.RECEIPT_PREFIX, instanceId, userId, rewardVersion)
end

function Rules.IsTrophyReceipt(key: any): boolean
	return type(key) == "string" and string.sub(key, 1, #Rules.RECEIPT_PREFIX) == Rules.RECEIPT_PREFIX
end

-- Drops our own receipts older than RECEIPT_TTL, then the oldest beyond RECEIPT_LIMIT.
-- Receipts from other namespaces are never touched. Safe because ownership of the trophy
-- itself (TrophyRecords) is the permanent first-clear flag: a pruned receipt cannot lead
-- to a second grant. Returns true if anything was removed.
function Rules.PruneReceipts(receipts: { [string]: any }, now: number): boolean
	local ours: { { Key: string, At: number } } = {}
	local changed = false
	for key, at in receipts do
		if Rules.IsTrophyReceipt(key) then
			if not isFiniteNonNegative(at) then
				receipts[key] = nil
				changed = true
			elseif now - at > Rules.RECEIPT_TTL then
				receipts[key] = nil
				changed = true
			else
				table.insert(ours, { Key = key, At = at })
			end
		end
	end
	if #ours > Rules.RECEIPT_LIMIT then
		table.sort(ours, function(a, b)
			if a.At ~= b.At then
				return a.At < b.At
			end
			return a.Key < b.Key
		end)
		for i = 1, #ours - Rules.RECEIPT_LIMIT do
			receipts[ours[i].Key] = nil
		end
		changed = true
	end
	return changed
end

-- Migration --------------------------------------------------------------------------------

local function sanitizeLayout(layout: any, records: { [string]: any }): (CampLayout, boolean)
	if type(layout) ~= "table" then
		return { Placements = {}, NextId = 1 }, true
	end
	local changed = false
	local raw = layout.Placements
	if type(raw) ~= "table" then
		raw = {}
		changed = true
	end
	local kept: { Placement } = {}
	local ids: { [number]: boolean } = {}
	local cells: { [number]: boolean } = {}
	local shown: { [string]: boolean } = {}
	local maxId = 0
	-- Iterate the array part in order, so the result is deterministic and idempotent.
	local count = 0
	for _ in raw do
		count += 1
	end
	if count ~= #raw then
		changed = true -- holes or non-array keys: rebuilt as a clean array below
	end
	for i = 1, #raw do
		local p = raw[i]
		local cell = if type(p) == "table"
				and isInteger(p.X, 0, Rules.CELLS - 1)
				and isInteger(p.Z, 0, Rules.CELLS - 1)
			then p.Z * Rules.CELLS + p.X
			else nil
		local ok = type(p) == "table"
			and isInteger(p.Id, 1, 2 ^ 31)
			and type(p.TrophyId) == "string"
			and records[p.TrophyId] ~= nil -- only owned trophies can stay on display
			and cell ~= nil
			and Rules.IsRotation(p.Rot)
			and not ids[p.Id]
			and not cells[cell :: number]
			and not shown[p.TrophyId]
			and #kept < Rules.MAX_PLACEMENTS
		if ok then
			ids[p.Id] = true
			cells[cell :: number] = true
			shown[p.TrophyId] = true
			maxId = math.max(maxId, p.Id)
			table.insert(kept, { Id = p.Id, TrophyId = p.TrophyId, X = p.X, Z = p.Z, Rot = p.Rot })
			-- extra unknown fields on a placement are dropped (layout entries are small records)
			for key in p do
				if key ~= "Id" and key ~= "TrophyId" and key ~= "X" and key ~= "Z" and key ~= "Rot" then
					changed = true
				end
			end
		else
			changed = true
		end
	end
	local nextId = layout.NextId
	if not isInteger(nextId, 1, 2 ^ 31) or nextId <= maxId then
		nextId = maxId + 1
		changed = true
	end
	if changed then
		return { Placements = kept, NextId = nextId }, true
	end
	return layout :: CampLayout, false
end

-- Adds/repairs the trophy fields in place. Touches no other key. Returns true if anything
-- changed. Idempotent.
function Rules.Migrate(data: { [string]: any }, now: number): boolean
	local changed = false

	local records = data.TrophyRecords
	if type(records) ~= "table" then
		records = {}
		data.TrophyRecords = records
		changed = true
	end
	for id, rec in records do
		if type(id) ~= "string" then
			records[id] = nil
			changed = true
		elseif type(rec) ~= "table" then
			-- never drop an owned id: keep ownership with a minimal repaired record
			records[id] = { Repaired = true }
			changed = true
		end
	end

	local layout, layoutChanged = sanitizeLayout(data.CampLayout, records)
	if layoutChanged then
		data.CampLayout = layout
		changed = true
	end

	-- Cosmetics is the bible's shared cosmetic inventory; trophy code owns only the stand key.
	local cosmetics = data.Cosmetics
	if type(cosmetics) ~= "table" then
		cosmetics = {}
		data.Cosmetics = cosmetics
		changed = true
	end
	local stand = cosmetics[Rules.STAND_ID]
	if stand ~= nil and type(stand) ~= "table" then
		cosmetics[Rules.STAND_ID] = { Repaired = true } -- keep ownership
		changed = true
	end

	local receipts = data.RewardReceipts
	if type(receipts) ~= "table" then
		receipts = {}
		data.RewardReceipts = receipts
		changed = true
	end
	if Rules.PruneReceipts(receipts, now) then
		changed = true
	end

	return changed
end

-- Eligibility ------------------------------------------------------------------------------

function Rules.IsParticipant(p: any): boolean
	return type(p) == "table"
		and isInteger(p.UserId, 1, 2 ^ 53)
		and isFiniteNonNegative(p.Points)
		and isFiniteNonNegative(p.ActiveSeconds)
		and isFiniteNonNegative(p.ObjectiveCompletions)
		and type(p.PresentForObjective) == "boolean"
end

--[[
	Bible ch.04: final eligibility needs at least 5 points plus either presence for a
	validated objective completion or 30 seconds of active participation. In a solo activity
	one meaningful objective completion qualifies. Movement/presence alone earns nothing.
	Returns (eligible, reason).
]]
function Rules.IsEligible(p: Participant, participantCount: number): (boolean, string)
	if participantCount == 1 and p.ObjectiveCompletions >= 1 then
		return true, "SoloObjective"
	end
	if p.Points < Rules.MIN_POINTS then
		return false, "LowContribution"
	end
	if p.PresentForObjective then
		return true, "Contributor"
	end
	if p.ActiveSeconds >= Rules.MIN_ACTIVE_SECONDS then
		return true, "ActiveParticipant"
	end
	return false, "NotPresent"
end

-- Grant mutation ---------------------------------------------------------------------------

export type LandmarkGrant = {
	TrophyId: string,
	Source: string,
	RegionId: string,
	ReceiptId: string, -- a "trophy:" receipt
	At: number,
}

--[[
	Applies one landmark trophy grant (and Mara's stand when missing) to a migrated save table.
	Pure and synchronous, so a caller can run it inside a larger save mutation (the adventure
	completion bridge grants the trophy, stand and progression in one mutation).
	Returns (status, reason?, newRecord?, standGranted):
		"Duplicate"    the receipt was already settled; nothing changed
		"AlreadyOwned" the trophy was owned; only a missing stand was added
		"Granted"      the trophy is newly owned
		"Refused"      RecordLimit; nothing changed
]]
function Rules.ApplyLandmarkGrant(
	data: { [string]: any },
	grant: LandmarkGrant,
	now: number
): (string, string?, TrophyRecord?, boolean)
	local records = data.TrophyRecords :: { [string]: any }
	local receipts = data.RewardReceipts :: { [string]: any }
	local cosmetics = data.Cosmetics :: { [string]: any }
	if receipts[grant.ReceiptId] ~= nil then
		return "Duplicate", nil, nil, false
	end
	local hadTrophy = records[grant.TrophyId] ~= nil
	local hadStand = cosmetics[Rules.STAND_ID] ~= nil
	if hadTrophy and hadStand then
		return "AlreadyOwned", nil, nil, false
	end
	local count = 0
	for _ in records do
		count += 1
	end
	if not hadTrophy and count >= Rules.MAX_TROPHY_RECORDS then
		return "Refused", "RecordLimit", nil, false
	end
	local record: TrophyRecord? = nil
	if not hadTrophy then
		local new: TrophyRecord = {
			Kind = "Landmark",
			Source = grant.Source,
			RegionId = grant.RegionId,
			AcquiredAt = grant.At,
			ReceiptId = grant.ReceiptId,
			Legacy = false,
			ContentVersion = Rules.CONTENT_VERSION,
		}
		records[grant.TrophyId] = new
		record = new
	end
	if not hadStand then
		cosmetics[Rules.STAND_ID] = {
			Kind = "CampFurniture",
			Source = grant.Source,
			AcquiredAt = grant.At,
			ReceiptId = grant.ReceiptId,
		}
	end
	receipts[grant.ReceiptId] = now
	Rules.PruneReceipts(receipts, now)
	return if hadTrophy then "AlreadyOwned" else "Granted", nil, record, not hadStand
end

-- Durable pending grants -------------------------------------------------------------------

-- A pending grant read back from the outbox store is re-validated before it is applied.
function Rules.IsPendingGrant(receiptId: any, grant: any): boolean
	return Rules.IsTrophyReceipt(receiptId)
		and type(grant) == "table"
		and type(grant.TrophyId) == "string"
		and Catalog.Get(grant.TrophyId) ~= nil
		and type(grant.Source) == "string"
		and (Catalog.Get(grant.TrophyId) :: Catalog.TrophyDef).Sources[grant.Source] == true
		and type(grant.RegionId) == "string"
		and isFiniteNonNegative(grant.At)
end

-- Camp placement ---------------------------------------------------------------------------

-- Pad-local centre of a grid cell, in studs (pad centre = 0,0).
function Rules.CellOffset(x: number, z: number): (number, number)
	local half = Rules.PAD_SIZE / 2
	return -half + x * Rules.GRID + Rules.GRID / 2, -half + z * Rules.GRID + Rules.GRID / 2
end

--[[
	Validates a client placement request against the owner's save. The request is untrusted:
	{ TrophyId: string, X: integer cell, Z: integer cell, Rot: 0|90|180|270 }. Returns
	(true, cleanPlacementWithoutId) or (false, reason). The trophy must be owned and
	displayable; asset ids or positions in studs are never accepted from the client.
]]
function Rules.ValidatePlacement(
	records: { [string]: any },
	layout: CampLayout,
	request: any,
	trophySlots: number?,
	hasStand: boolean?
): (boolean, any)
	if type(request) ~= "table" then
		return false, "Malformed"
	end
	local trophyId = request.TrophyId
	if type(trophyId) ~= "string" or #trophyId > 64 then
		return false, "Malformed"
	end
	if not isInteger(request.X, -2 ^ 31, 2 ^ 31) or not isInteger(request.Z, -2 ^ 31, 2 ^ 31) then
		return false, "Malformed"
	end
	if not Rules.IsRotation(request.Rot) then
		return false, "BadRotation"
	end
	if request.X < 0 or request.X >= Rules.CELLS or request.Z < 0 or request.Z >= Rules.CELLS then
		return false, "OutOfBounds"
	end
	if records[trophyId] == nil then
		return false, "NotOwned"
	end
	if not Catalog.IsDisplayable(trophyId) then
		return false, "NotDisplayable"
	end
	if hasStand == false then
		return false, "NoStand"
	end
	if #layout.Placements >= Rules.MAX_PLACEMENTS then
		return false, "LayoutFull"
	end
	local trophies = 0
	for _, p in layout.Placements do
		if p.TrophyId == trophyId then
			return false, "AlreadyDisplayed"
		end
		if p.X == request.X and p.Z == request.Z then
			return false, "Occupied"
		end
		trophies += 1
	end
	if trophies >= (trophySlots or Rules.TROPHY_SLOTS) then
		return false, "NoSlots"
	end
	return true, { TrophyId = trophyId, X = request.X, Z = request.Z, Rot = request.Rot }
end

return table.freeze(Rules)
