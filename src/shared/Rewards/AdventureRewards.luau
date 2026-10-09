--!strict
--[[
	Rewards.AdventureRewards — pure stage/final settlement rules for adventure events (the
	completion bridge between the adventure runtime and permanent player progression). No
	services, no Instances, no yields: everything operates on plain save tables and on the
	frozen contexts the adventure runtime hands over.

	Game bible ch.04 "Rewards per stage": each unique major stage grants 10% of the event's base
	completion reward when it completes (30% cap). A successful final completion grants the
	remainder, reconciled against stage grants already received for that run, so an eligible late
	helper still reaches the defined base total. Failure keeps stage grants and grants no trophy.
	Reward ids are EventInstanceId + UserId + Stage/Final + RewardVersion.

	The first eligible completion also grants, in the SAME save mutation as the coins and the
	receipt, the event's certification and its story-quest credit. First clear is decided from
	AdventureProgress (FirstClearAt) and certification presence only; both are permanent flags,
	so pruning a receipt can never re-grant them. The landmark trophy and Mara's stand are NOT
	granted here: TrophyService settles them from the same completion context under its own
	"trophy:" receipt and outbox (AdventureSettlement runs both in the same frame).

	Persisted fields (top-level PlayerData keys named by bible ch.04 "Persistence"):
		Certifications    { [certId] = { At, Source, ReceiptId } }
		AdventureProgress { Events = { [eventId] = { Clears, FirstClearAt?, FirstClearReceipt?,
		                    LastClearAt? } }, QuestCredit = { [questId] = { [objectiveId] =
		                    { At, ReceiptId } } } }
		RewardReceipts    { ["adv:..."] = settledUnix }  only the "adv:" namespace is ours
		Coins             fixed event awards (no multipliers, bible ch.04 "Economy and rewards")
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrophyCatalog = require(ReplicatedStorage.Shared.Trophies.Catalog)
local TrophyRules = require(ReplicatedStorage.Shared.Trophies.Rules)

export type EventRewards = {
	EventId: string,
	LandmarkId: string, -- trophy granted on an eligible completion
	RegionId: string,
	BoundaryVersion: number, -- adventure runtime context version this table understands
	RewardVersion: number,
	BaseCoins: number, -- full completion total (stage grants + final remainder)
	StageCoins: number, -- per unique major stage
	Stages: { string },
	Certification: string, -- granted on the first eligible completion
	QuestId: string, -- story quest credited on the first eligible completion
	QuestObjective: string,
}

export type Intent = {
	Kind: "Stage" | "Final",
	UserId: number,
	EventId: string,
	InstanceId: string,
	StageId: string?, -- Stage only
	RewardVersion: number,
	Coins: number, -- Stage: the stage grant. Final: the base total before reconciliation
	StageCoins: number, -- Final: per-stage amount to reconcile against
	At: number,
}

export type Decision = {
	UserId: number,
	Intent: Intent?, -- nil when ineligible
	Reason: string?, -- why not eligible
}

export type Applied = {
	Status: "Applied" | "Duplicate",
	Coins: number,
	FirstClear: boolean,
	Certification: string?, -- newly granted certification
	QuestCredit: boolean,
}

local Rewards = {}

Rewards.RECEIPT_PREFIX = "adv:"
Rewards.RECEIPT_LIMIT = 512 -- rolling settled window (bible ch.04 "Persistence")
Rewards.RECEIPT_TTL = 30 * 24 * 60 * 60
Rewards.MAX_PARTICIPANTS = TrophyRules.MAX_PARTICIPANTS
Rewards.MAX_INSTANCE_ID_LENGTH = TrophyRules.MAX_INSTANCE_ID_LENGTH

-- Spring Surprise (bible ch.03 event_vault; ch.04 "Intro event base = 60 coins"; q_mara
-- "cert_crew at finish"). Mara's stand comes with the trophy (owner decision, 9 Oct 2026).
local vault: EventRewards = {
	EventId = "event_vault",
	LandmarkId = "landmark_spring_vault",
	RegionId = "sunshine_shore",
	BoundaryVersion = 1,
	RewardVersion = 1,
	BaseCoins = 60,
	StageCoins = 6,
	Stages = table.freeze({ "excavation", "vault_open", "ball_return" }),
	Certification = "cert_crew",
	QuestId = "q_mara",
	QuestObjective = "finish_event_vault",
}

Rewards.Events = table.freeze({
	event_vault = table.freeze(vault),
}) :: { [string]: EventRewards }

local function isInteger(v: any, min: number, max: number): boolean
	return type(v) == "number" and v == v and v % 1 == 0 and v >= min and v <= max
end

local function isFiniteNonNegative(v: any): boolean
	return type(v) == "number" and v == v and v >= 0 and v ~= math.huge
end

local function isId(v: any, maxLength: number): boolean
	return type(v) == "string" and #v > 0 and #v <= maxLength
end

-- Receipts ---------------------------------------------------------------------------------

function Rewards.StageReceiptId(instanceId: string, userId: number, stageId: string, rewardVersion: number): string
	return string.format("%s%s:%d:stage:%s:v%d", Rewards.RECEIPT_PREFIX, instanceId, userId, stageId, rewardVersion)
end

function Rewards.FinalReceiptId(instanceId: string, userId: number, rewardVersion: number): string
	return string.format("%s%s:%d:final:v%d", Rewards.RECEIPT_PREFIX, instanceId, userId, rewardVersion)
end

function Rewards.ReceiptFor(intent: Intent): string
	if intent.Kind == "Stage" then
		return Rewards.StageReceiptId(intent.InstanceId, intent.UserId, intent.StageId :: string, intent.RewardVersion)
	end
	return Rewards.FinalReceiptId(intent.InstanceId, intent.UserId, intent.RewardVersion)
end

function Rewards.IsReceipt(key: any): boolean
	return type(key) == "string" and string.sub(key, 1, #Rewards.RECEIPT_PREFIX) == Rewards.RECEIPT_PREFIX
end

-- Drops our receipts older than RECEIPT_TTL, then the oldest beyond RECEIPT_LIMIT. Other
-- namespaces are never touched. First-clear grants are guarded by permanent flags, so pruning
-- can only ever matter for a replay of a month-old run, which the runtime cannot produce.
function Rewards.PruneReceipts(receipts: { [string]: any }, now: number): boolean
	local ours: { { Key: string, At: number } } = {}
	local changed = false
	for key, at in receipts do
		if Rewards.IsReceipt(key) then
			if not isFiniteNonNegative(at) or now - at > Rewards.RECEIPT_TTL then
				receipts[key] = nil
				changed = true
			else
				table.insert(ours, { Key = key, At = at })
			end
		end
	end
	if #ours > Rewards.RECEIPT_LIMIT then
		table.sort(ours, function(a, b)
			if a.At ~= b.At then
				return a.At < b.At
			end
			return a.Key < b.Key
		end)
		for i = 1, #ours - Rewards.RECEIPT_LIMIT do
			receipts[ours[i].Key] = nil
		end
		changed = true
	end
	return changed
end

-- Migration --------------------------------------------------------------------------------

-- Adds/repairs Certifications and AdventureProgress (and RewardReceipts) in place. Touches no
-- other key, never removes an earned certification or clear, invents nothing. Idempotent.
function Rewards.Migrate(data: { [string]: any }, now: number): boolean
	local changed = false
	local certs = data.Certifications
	if type(certs) ~= "table" then
		data.Certifications = {}
		changed = true
	else
		for id, rec in certs do
			if type(id) ~= "string" then
				certs[id] = nil
				changed = true
			elseif type(rec) ~= "table" then
				certs[id] = { Repaired = true } -- keep the certification
				changed = true
			end
		end
	end
	local progress = data.AdventureProgress
	if type(progress) ~= "table" then
		progress = {}
		data.AdventureProgress = progress
		changed = true
	end
	for _, key in { "Events", "QuestCredit" } do
		if type(progress[key]) ~= "table" then
			progress[key] = {}
			changed = true
		end
	end
	for id, rec in progress.Events do
		if type(rec) ~= "table" then
			progress.Events[id] = { Clears = 1, Repaired = true }
			changed = true
		elseif not isInteger(rec.Clears, 0, 2 ^ 31) then
			rec.Clears = if rec.FirstClearAt ~= nil then 1 else 0
			changed = true
		end
	end
	for id, rec in progress.QuestCredit do
		if type(rec) ~= "table" then
			progress.QuestCredit[id] = {}
			changed = true
		end
	end
	local receipts = data.RewardReceipts
	if type(receipts) ~= "table" then
		receipts = {}
		data.RewardReceipts = receipts
		changed = true
	end
	if Rewards.PruneReceipts(receipts, now) then
		changed = true
	end
	return changed
end

-- Contexts from the adventure runtime ------------------------------------------------------

-- Common checks for the runtime's frozen stage observation and completion context. Returns
-- (rewards) or (nil, error).
local function validateContext(context: any): (EventRewards?, string?)
	if type(context) ~= "table" then
		return nil, "Malformed"
	end
	local def = if type(context.EventId) == "string" then Rewards.Events[context.EventId] else nil
	if not def then
		return nil, "UnknownEvent"
	end
	local rewards = def :: EventRewards
	if context.BoundaryVersion ~= rewards.BoundaryVersion then
		return nil, "BoundaryVersion"
	end
	if context.LandmarkId ~= rewards.LandmarkId or context.RegionId ~= rewards.RegionId then
		return nil, "LandmarkMismatch"
	end
	local trophy = TrophyCatalog.Get(rewards.LandmarkId)
	if not trophy or not trophy.Sources[rewards.EventId] then
		return nil, "LandmarkMismatch"
	end
	if not isId(context.EventInstanceId, Rewards.MAX_INSTANCE_ID_LENGTH) then
		return nil, "BadInstanceId"
	end
	local participants = context.Participants
	if type(participants) ~= "table" or #participants < 1 or #participants > Rewards.MAX_PARTICIPANTS then
		return nil, "BadParticipants"
	end
	local seen: { [number]: boolean } = {}
	for i, p in participants do
		if
			type(i) ~= "number"
			or type(p) ~= "table"
			or not isInteger(p.UserId, 1, 2 ^ 53)
			or seen[p.UserId]
			or not isFiniteNonNegative(p.Points)
			or type(p.ObjectiveIds) ~= "table"
		then
			return nil, "BadParticipants"
		end
		seen[p.UserId] = true
	end
	return rewards, nil
end

--[[
	Stage observation (SpringVaultService OnStage): { BoundaryVersion, EventInstanceId, EventId,
	LandmarkId, RegionId, StageId, CompletedStages, Participants = { { UserId, Points,
	ObjectiveIds, Connected, Left } } }.
	A participant earns the stage grant when, at the moment the stage completes, they are
	connected, have not left, and have earned contribution points in this run. Presence alone
	earns nothing (bible ch.04), and a late helper who has not contributed yet gets no credit for
	stages finished before they did.
	Returns (decisions) or (nil, error).
]]
function Rewards.StageDecisions(observation: any, now: number): ({ Decision }?, string?)
	local def, err = validateContext(observation)
	if not def then
		return nil, err
	end
	local stageId = observation.StageId
	if type(stageId) ~= "string" or table.find(def.Stages, stageId) == nil then
		return nil, "UnknownStage"
	end
	if type(observation.CompletedStages) ~= "table" or table.find(observation.CompletedStages, stageId) == nil then
		return nil, "StageNotCompleted"
	end
	local decisions: { Decision } = {}
	for _, p in observation.Participants do
		local decision: Decision = { UserId = p.UserId }
		if p.Left == true then
			decision.Reason = "Left"
		elseif p.Connected ~= true then
			decision.Reason = "Disconnected"
		elseif p.Points <= 0 then
			decision.Reason = "NoContribution"
		else
			decision.Intent = {
				Kind = "Stage",
				UserId = p.UserId,
				EventId = def.EventId,
				InstanceId = observation.EventInstanceId,
				StageId = stageId,
				RewardVersion = def.RewardVersion,
				Coins = def.StageCoins,
				StageCoins = def.StageCoins,
				At = now,
			}
		end
		table.insert(decisions, decision)
	end
	return decisions, nil
end

--[[
	Completion context (SpringVaultState.completionContext): adds Success and per participant
	Eligible / ActiveSeconds. Both rules must agree: the runtime's Eligible flag (which also
	requires being connected and present at completion, so disconnected players never get the
	final grant) AND the trophy contribution rule (Trophies.Rules.IsEligible, bible ch.04).
	Returns (decisions) or (nil, error).
]]
function Rewards.FinalDecisions(context: any, now: number): ({ Decision }?, string?)
	local def, err = validateContext(context)
	if not def then
		return nil, err
	end
	if context.Success ~= true then
		return nil, "NotCompleted"
	end
	local participants = context.Participants
	for _, p in participants do
		if not isFiniteNonNegative(p.ActiveSeconds) or type(p.Eligible) ~= "boolean" then
			return nil, "BadParticipants"
		end
	end
	local decisions: { Decision } = {}
	for _, p in participants do
		local witnessed = #p.ObjectiveIds
		local eligible, why = TrophyRules.IsEligible({
			UserId = p.UserId,
			Points = p.Points,
			ActiveSeconds = p.ActiveSeconds,
			ObjectiveCompletions = if p.Points > 0 then witnessed else 0,
			PresentForObjective = witnessed > 0,
		}, #participants)
		local decision: Decision = { UserId = p.UserId }
		if p.Eligible ~= true then
			decision.Reason = "EventIneligible"
		elseif not eligible then
			decision.Reason = why
		else
			decision.Intent = {
				Kind = "Final",
				UserId = p.UserId,
				EventId = def.EventId,
				InstanceId = context.EventInstanceId,
				RewardVersion = def.RewardVersion,
				Coins = def.BaseCoins,
				StageCoins = def.StageCoins,
				At = now,
			}
		end
		table.insert(decisions, decision)
	end
	return decisions, nil
end

-- Intents read back from the durable outbox are re-validated before they are applied.
function Rewards.IsIntent(receiptId: any, intent: any): boolean
	if type(intent) ~= "table" or (intent.Kind ~= "Stage" and intent.Kind ~= "Final") then
		return false
	end
	local def = if type(intent.EventId) == "string" then Rewards.Events[intent.EventId] else nil
	if not def then
		return false
	end
	if
		not isInteger(intent.UserId, 1, 2 ^ 53)
		or not isId(intent.InstanceId, Rewards.MAX_INSTANCE_ID_LENGTH)
		or not isInteger(intent.RewardVersion, 1, 1000)
		or not isInteger(intent.Coins, 0, (def :: EventRewards).BaseCoins)
		or not isInteger(intent.StageCoins, 0, (def :: EventRewards).BaseCoins)
		or not isFiniteNonNegative(intent.At)
	then
		return false
	end
	if intent.Kind == "Stage" and table.find((def :: EventRewards).Stages, intent.StageId) == nil then
		return false
	end
	return receiptId == Rewards.ReceiptFor(intent)
end

-- Application ------------------------------------------------------------------------------

local function stageReceiptsFor(receipts: { [string]: any }, instanceId: string, userId: number): number
	local prefix = string.format("%s%s:%d:stage:", Rewards.RECEIPT_PREFIX, instanceId, userId)
	local n = 0
	for key in receipts do
		if type(key) == "string" and string.sub(key, 1, #prefix) == prefix then
			n += 1
		end
	end
	return n
end

--[[
	Applies one intent to a save table that has been through Trophies.Rules.Migrate and
	Rewards.Migrate. Pure and synchronous; the caller runs it inside one save mutation.
	Stage: +stage coins, unless the run's final grant was already settled (then 0: the final
	already paid the full total). Final: +(base - stage coins already received for this run,
	never below 0), a clear, and on the first eligible completion the certification and quest
	credit together. A missing certification or quest credit is repaired on a later completion.
	Touches only Coins, RewardReceipts ("adv:" keys), Certifications and AdventureProgress.
]]
function Rewards.Apply(data: { [string]: any }, intent: Intent, now: number): Applied
	local receipts = data.RewardReceipts :: { [string]: any }
	local receiptId = Rewards.ReceiptFor(intent)
	local applied: Applied = { Status = "Duplicate", Coins = 0, FirstClear = false, QuestCredit = false }
	if receipts[receiptId] ~= nil then
		return applied
	end
	local def = Rewards.Events[intent.EventId]
	applied.Status = "Applied"
	if intent.Kind == "Stage" then
		local final = Rewards.FinalReceiptId(intent.InstanceId, intent.UserId, intent.RewardVersion)
		applied.Coins = if receipts[final] ~= nil then 0 else intent.Coins
	else
		local already = stageReceiptsFor(receipts, intent.InstanceId, intent.UserId) * intent.StageCoins
		applied.Coins = math.max(0, intent.Coins - already)

		local progress = data.AdventureProgress :: { [string]: any }
		local events = progress.Events :: { [string]: any }
		local record = events[intent.EventId]
		if type(record) ~= "table" then
			record = { Clears = 0 }
			events[intent.EventId] = record
		end
		record.Clears += 1
		record.LastClearAt = intent.At
		if record.FirstClearAt == nil then
			record.FirstClearAt = intent.At
			record.FirstClearReceipt = receiptId
			applied.FirstClear = true
		end

		local certs = data.Certifications :: { [string]: any }
		if certs[def.Certification] == nil then
			certs[def.Certification] = { At = intent.At, Source = intent.EventId, ReceiptId = receiptId }
			applied.Certification = def.Certification
		end
		local credit = progress.QuestCredit :: { [string]: any }
		local quest = credit[def.QuestId]
		if type(quest) ~= "table" then
			quest = {}
			credit[def.QuestId] = quest
		end
		if quest[def.QuestObjective] == nil then
			quest[def.QuestObjective] = { At = intent.At, ReceiptId = receiptId }
			applied.QuestCredit = true
		end
	end
	if applied.Coins > 0 then
		data.Coins = (if type(data.Coins) == "number" then data.Coins else 0) + applied.Coins
	end
	receipts[receiptId] = now
	Rewards.PruneReceipts(receipts, now)
	return applied
end

-- Outbox drain order: per run, stages before the final, so reconciliation sees them.
function Rewards.SortIntents(intents: { Intent })
	table.sort(intents, function(a, b)
		if a.InstanceId ~= b.InstanceId then
			return a.InstanceId < b.InstanceId -- runs reconcile independently; any run order works
		end
		if a.Kind ~= b.Kind then
			return a.Kind == "Stage"
		end
		return (a.StageId or "") < (b.StageId or "")
	end)
end

return table.freeze(Rewards)
