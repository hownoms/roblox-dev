--!strict
--[[
	AdventureSettlement — the completion bridge between the adventure runtime and permanent
	player progression. Server-only; nothing a client sends reaches it.

	Wiring (codex/spring-vault-adventure):
		SpringVaultService.Start({
			OnStage = AdventureSettlement.OnStage,           -- frozen stage observation
			OnCompletion = AdventureSettlement.OnCompletion, -- frozen CompletionContext
			...
		})
	Both are called from the runtime's Heartbeat loop, so neither yields: rewards are applied to
	loaded saves synchronously and the durable writes run in their own threads.

	Two owners, one completion (owner decision: reuse TrophyService, never duplicate its grants):
	  * this bridge ("adv:" receipts, outbox AdventureRewardIntents_v1): fixed stage/final coins
	    with stage reconciliation, the clear count, cert_crew and the q_mara finish_event_vault
	    credit (Rewards.AdventureRewards). First clear is decided from AdventureProgress and
	    certification presence, never from the trophy.
	  * TrophyService ("trophy:" receipts, outbox TrophyPendingGrants_v1): the landmark trophy
	    and Mara's stand, through TrophyService.PrepareCompletionContext (its non-yielding
	    settlement) on the same frozen context, in the same frame as the adv mutation.
	One DataService.SaveAsync then makes both durable; if it fails each part goes to its own
	outbox. Every grant is idempotent by its own receipt plus permanent ownership flags.

	Durability. A grant is reported Saved only once the player's save holding it has been written,
	or Queued once its intent is in the durable outbox. An eligible player whose save is not
	loaded here gets both intents in the outboxes (PendingRejoin), applied on their next load on
	any server by Drain, which acknowledges only after the save that applied them succeeded. On
	shutdown, DataService's BindToClose writes every live save (which already holds applied
	grants) and this service waits for in-flight outbox writes.

	Outcomes. Each participant gets ONE truthful outcome per stage/final (SetOutcomeSender, see
	Outcome below), sent once the durable writes resolved, and a second "Resolved" outcome when
	a Pending one later becomes Accepted (a delayed save retry here, or the drain on rejoin).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rewards = require(ReplicatedStorage.Shared.Rewards.AdventureRewards)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local DurableOutbox = require(script.Parent.DurableOutbox)
local TrophyService = require(script.Parent.TrophyService)

export type Status =
	"Applied" -- in the live save; the durable write is in flight
	| "Saved" -- in the live save, and that save has been written
	| "Queued" -- in the live save; the save write failed but the intent is in the durable outbox
	| "Unconfirmed" -- in the live save only; both writes failed (retried; the next autosave/leave save carries it)
	| "Duplicate" -- this receipt was already settled; nothing changed
	| "PendingRejoin" -- eligible, not loaded here; durably queued for their next load anywhere
	| "Ineligible" -- Reason says why
	| "Refused" -- not loaded here and not stored (Reason: PendingFull / PendingWriteFailed)

-- What a participant is told. State is the only thing a client may treat as "you got it".
export type OutcomeState = "Accepted" | "Pending" | "Refused"

export type Outcome = {
	InstanceId: string,
	Kind: "Stage" | "Final",
	StageId: string?,
	State: OutcomeState, -- Accepted: durable (Saved / Queued / Duplicate). Pending: not yet
	-- durable or not yet applied (Applied / Unconfirmed / PendingRejoin). Refused: nothing granted.
	Status: string, -- the weakest component Status (see Status above)
	-- What is known to be granted. For PendingRejoin these stay 0/false: the amounts depend on
	-- the save they apply to, and the drain on rejoin reports them in a Resolved outcome. For
	-- other Pending outcomes they name what is in flight (not durable yet); only State ==
	-- "Accepted" may be presented as granted (the client card never lists them otherwise).
	Coins: number,
	Trophy: boolean, -- the landmark trophy was newly granted
	Stand: boolean, -- Mara's trophy stand was newly granted
	Certification: string?, -- newly granted certification id
	Reason: string?, -- why Refused / Ineligible, or "Trophy<reason>" when only the trophy part failed
	Resolved: boolean?, -- true: resolves an earlier Pending outcome (retry here or drain on rejoin)
	-- Set only when this server's store is not durable (DataService.StorageMode() "LocalOnly" for
	-- the Studio candidate, "Mock" for the Studio in-memory fallback). Status keeps its meaning
	-- for that store, but nothing outlives the session, so the card must not read as saved.
	Storage: string?,
}

export type PlayerResult = {
	UserId: number,
	Status: Status,
	Reason: string?,
	Coins: number?,
	FirstClear: boolean?,
	TrophyGranted: boolean?,
	StandGranted: boolean?,
	Certification: string?,
	TrophyStatus: string?, -- Final: TrophyService's status (Granted / AlreadyOwned / Duplicate / ...)
	TrophyDurable: Status?, -- Final: durability of the trophy/stand change, when there was one
	TrophyReason: string?, -- Final: why TrophyService refused the trophy part
	Outcome: Outcome?, -- the last outcome computed for this player (sent if they are in the server)
}

export type Report = {
	Ok: boolean,
	Error: string?, -- set when Ok == false; nothing changed for anyone
	Kind: "Stage" | "Final",
	InstanceId: string?,
	StageId: string?,
	Results: { PlayerResult },
	ByUserId: { [number]: PlayerResult },
	Trophy: TrophyService.SettlementReport?, -- Final: TrophyService's own report
	Done: boolean, -- every durable write has resolved
}

local KEYS = {
	"Coins",
	"RewardReceipts",
	"Certifications",
	"AdventureProgress",
}

local STAGE_TEXT: { [string]: string } = {
	excavation = "clearing the vault anchors",
	vault_open = "opening the Spring Vault",
	ball_return = "bringing the beach ball home",
}

-- Weakest first: a combined outcome is only as good as its weakest part.
local RANK: { [string]: number } = {
	Refused = 0,
	Ineligible = 0,
	Unconfirmed = 1,
	PendingRejoin = 2,
	Applied = 3,
	Queued = 4,
	Saved = 5,
	Duplicate = 6,
}
local STATE: { [string]: OutcomeState } = {
	Refused = "Refused",
	Ineligible = "Refused",
	Unconfirmed = "Pending",
	PendingRejoin = "Pending",
	Applied = "Pending",
	Queued = "Accepted",
	Saved = "Accepted",
	Duplicate = "Accepted",
}

local AdventureSettlement = {}

-- (report) once every durable write of a settlement has resolved
AdventureSettlement.Settled = Signal.new() :: Signal.Signal<Report>
-- (player, result, kind) when a grant reached a live save (UI / analytics / quest hooks)
AdventureSettlement.Granted = Signal.new() :: Signal.Signal<Player, PlayerResult, string>
-- (player, outcome) whenever an outcome is produced for a player in this server
AdventureSettlement.OutcomeSent = Signal.new() :: Signal.Signal<Player, Outcome>

local outbox = DurableOutbox.new("AdventureRewardIntents_v1", 16, Rewards.IsIntent)
AdventureSettlement.Outbox = outbox

-- Seconds between save retries for an Unconfirmed grant (then it rides the next autosave /
-- leave save). Tests shorten these.
AdventureSettlement.RetryDelays = { 5, 15, 30 }

local enabled = true
local notifier: ((Player, string) -> ())? = nil
local outcomeSender: ((Player, Outcome) -> ())? = nil
local inflight = 0
local draining: { [number]: boolean } = {}
local drainAgain: { [number]: boolean } = {}
local migrated: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function notify(player: Player, text: string)
	if notifier and player.Parent then
		local ok, err = pcall(notifier :: any, player, text)
		if not ok then
			warn("[AdventureSettlement] notify failed: " .. tostring(err))
		end
	end
end

-- The live save with adventure fields guaranteed, or nil if not loaded.
local function getData(player: Player): { [string]: any }?
	local data = DataService.Get(player) :: any
	if data == nil then
		return nil
	end
	if not migrated[data] then
		migrated[data] = true
		if Rewards.Migrate(data, os.time()) then
			DataService.MarkDirty(player, "Certifications", "AdventureProgress", "RewardReceipts")
		end
	end
	return data
end

-- Applies one intent to a loaded save in one synchronous mutation. nil when not loaded.
local function applyLive(player: Player, intent: Rewards.Intent): Rewards.Applied?
	local data = getData(player)
	if not data then
		return nil
	end
	local applied: Rewards.Applied? = nil
	DataService.Mutate(player, KEYS, function(d)
		applied = Rewards.Apply(d :: any, intent, os.time())
	end)
	local result = applied :: Rewards.Applied
	if result.Status == "Applied" and result.Coins > 0 then
		Analytics.Source(
			player,
			"Coins",
			result.Coins,
			(data :: any).Coins,
			Enum.AnalyticsEconomyTransactionType.Gameplay,
			string.format("Adventure:%s:%s", intent.EventId, intent.StageId or "final")
		)
	end
	return result
end

-- Outcomes ------------------------------------------------------------------------------------

local function weakest(a: string, b: string?): string
	if b == nil or RANK[a] <= RANK[b] then
		return a
	end
	return b
end

-- One combined, truthful outcome for a participant (adv part + trophy part).
local function outcomeFor(report: Report, entry: PlayerResult): Outcome
	local outcome: Outcome = {
		InstanceId = report.InstanceId or "",
		Kind = report.Kind,
		StageId = report.StageId,
		State = "Refused",
		Status = entry.Status,
		Coins = 0,
		Trophy = false,
		Stand = false,
	}
	if entry.Status == "Ineligible" or entry.Status == "Refused" then
		outcome.Reason = entry.Reason
		return outcome
	end
	-- a failed trophy part does not take back the accepted coins/cert; it is named in Reason
	local trophyOk = entry.TrophyDurable ~= nil and entry.TrophyDurable ~= "Refused"
	local status = weakest(entry.Status, if trophyOk then entry.TrophyDurable else nil)
	outcome.Status = status
	outcome.State = STATE[status]
	outcome.Coins = if entry.Status == "PendingRejoin" then 0 else entry.Coins or 0
	outcome.Certification = entry.Certification
	outcome.Trophy = trophyOk and entry.TrophyGranted == true
	outcome.Stand = trophyOk and entry.StandGranted == true
	if report.Kind == "Final" and (entry.TrophyDurable == "Refused" or entry.TrophyStatus == "Refused") then
		outcome.Reason = "Trophy" .. tostring(entry.TrophyReason or "Refused")
	elseif report.Kind == "Final" and entry.TrophyStatus == "Unavailable" then
		outcome.Reason = "TrophyUnavailable"
	end
	return outcome
end

local function describe(outcome: Outcome): string?
	if outcome.State ~= "Accepted" then
		return nil
	end
	local parts: { string } = {}
	if outcome.Coins > 0 then
		table.insert(parts, string.format("+%d Coins", outcome.Coins))
	end
	if outcome.Kind == "Stage" then
		if #parts == 0 then
			return nil
		end
		return parts[1] .. " for " .. (STAGE_TEXT[outcome.StageId or ""] or "that stage") .. "!"
	end
	local unlocks: { string } = {}
	if outcome.Trophy then
		table.insert(unlocks, "the Spring Vault trophy")
	end
	if outcome.Stand then
		table.insert(unlocks, "Mara's trophy stand")
	end
	if outcome.Certification then
		table.insert(unlocks, "Crew certification")
	end
	if #unlocks > 0 then
		table.insert(parts, "You earned " .. table.concat(unlocks, ", "))
	end
	if #parts == 0 then
		return nil
	end
	local text = table.concat(parts, " · ") .. "!"
	return if outcome.Resolved then text .. " (from your last adventure)" else text
end

-- Delivers an outcome to the player if they are in this server: the outcome remote when wired,
-- otherwise the legacy reward text (accepted grants only).
local function deliver(userId: number, outcome: Outcome)
	local player = Players:GetPlayerByUserId(userId)
	if not player or not player.Parent then
		return
	end
	local storage = DataService.StorageMode()
	if storage == "LocalOnly" or storage == "Mock" then
		outcome.Storage = storage
	end
	AdventureSettlement.OutcomeSent:Fire(player, outcome)
	if outcomeSender then
		local ok, err = pcall(outcomeSender :: any, player, outcome)
		if not ok then
			warn("[AdventureSettlement] outcome send failed: " .. tostring(err))
		end
	else
		local text = describe(outcome)
		if text then
			notify(player, text)
		end
	end
end

local function publish(report: Report, entry: PlayerResult, resolved: boolean?)
	local outcome = outcomeFor(report, entry)
	if resolved then
		outcome.Resolved = true
	end
	entry.Outcome = outcome
	deliver(entry.UserId, outcome)
end

-- Durable writes ----------------------------------------------------------------------------

-- Outbox fallback for parts that are only in the live save. Yields.
local function queueParts(userId: number, intent: Rewards.Intent?, entry: PlayerResult, grant: any?)
	if intent and (entry.Status == "Applied" or entry.Status == "Unconfirmed") then
		local receiptId = Rewards.ReceiptFor(intent)
		entry.Status = if outbox.Add(userId, receiptId, intent :: any) then "Queued" else "Unconfirmed"
	end
	if grant and (entry.TrophyDurable == "Applied" or entry.TrophyDurable == "Unconfirmed") then
		entry.TrophyDurable = if TrophyService.QueueGrant(userId, grant) then "Queued" else "Unconfirmed"
	end
end

-- Durable write for one live-applied result: one save for both parts, else each outbox. Yields.
local function confirmLive(player: Player, intent: Rewards.Intent?, entry: PlayerResult, grant: any?)
	if DataService.SaveAsync(player) then
		if entry.Status == "Applied" then
			entry.Status = "Saved"
		end
		if entry.TrophyDurable == "Applied" then
			entry.TrophyDurable = "Saved"
		end
		return
	end
	queueParts(player.UserId, intent, entry, grant)
	if entry.Status == "Unconfirmed" or entry.TrophyDurable == "Unconfirmed" then
		warn(
			string.format(
				"[AdventureSettlement] %s not yet durable for %d (save and outbox failed)",
				if intent then Rewards.ReceiptFor(intent) else "trophy grant",
				player.UserId
			)
		)
	end
end

-- Keeps trying an Unconfirmed grant while the player is here; tells them once it is durable.
local function retryUnconfirmed(
	player: Player,
	report: Report,
	intent: Rewards.Intent?,
	entry: PlayerResult,
	grant: any?
)
	for _, delay in AdventureSettlement.RetryDelays do
		task.wait(delay)
		if not player.Parent or not DataService.IsLoaded(player) then
			-- Left: the leave save should carry it, but that save can fail too. One more outbox
			-- attempt makes it durable either way (a Duplicate on their next load if the leave
			-- save did land). Nobody is left here to tell.
			queueParts(player.UserId, intent, entry, grant)
			return
		end
		if entry.Status == "Unconfirmed" then
			entry.Status = "Applied"
		end
		if entry.TrophyDurable == "Unconfirmed" then
			entry.TrophyDurable = "Applied"
		end
		confirmLive(player, intent, entry, grant)
		if entry.Status ~= "Unconfirmed" and entry.TrophyDurable ~= "Unconfirmed" then
			publish(report, entry, true)
			return
		end
	end
end

-- Durable write for a player not loaded here. Yields.
local function queueOffline(intent: Rewards.Intent, entry: PlayerResult)
	local receiptId = Rewards.ReceiptFor(intent)
	local ok, reason = outbox.Add(intent.UserId, receiptId, intent :: any)
	if ok then
		entry.Status, entry.Reason = "PendingRejoin", nil
	else
		entry.Status, entry.Reason = "Refused", reason
		warn(
			string.format("[AdventureSettlement] %s not stored for %d: %s", receiptId, intent.UserId, tostring(reason))
		)
	end
end

local function toResult(userId: number, applied: Rewards.Applied): PlayerResult
	return {
		UserId = userId,
		Status = if applied.Status == "Duplicate" then "Duplicate" else "Applied",
		Coins = applied.Coins,
		FirstClear = applied.FirstClear,
		Certification = applied.Certification,
	}
end

-- Copies TrophyService's result for this player onto the combined entry.
local function attachTrophy(entry: PlayerResult, trophyEntry: TrophyService.PlayerResult?, available: boolean)
	if not available then
		entry.TrophyStatus = "Unavailable"
		return
	end
	if not trophyEntry then
		return
	end
	entry.TrophyStatus = trophyEntry.Status
	entry.TrophyGranted = trophyEntry.Status == "Granted"
	entry.StandGranted = trophyEntry.StandGranted == true
	if trophyEntry.Status == "Refused" then
		entry.TrophyReason = trophyEntry.Reason
	end
end

local requestDrain: (Player, boolean) -> ()

local function settle(kind: "Stage" | "Final", context: any, decisions: { Rewards.Decision }?, err: string?): Report
	local report: Report = {
		Ok = decisions ~= nil,
		Error = err,
		Kind = kind,
		InstanceId = if type(context) == "table" and type(context.EventInstanceId) == "string"
			then context.EventInstanceId
			else nil,
		StageId = if kind == "Stage"
				and type(context) == "table"
				and type(context.StageId) == "string"
			then context.StageId
			else nil,
		Results = {},
		ByUserId = {},
		Done = decisions == nil,
	}
	if not decisions then
		return report
	end
	-- 1. Synchronous: apply to every loaded save (no yields, so a save snapshot never sees half).
	-- The trophy + stand go through TrophyService's own settlement, in this same frame.
	local trophyReport: TrophyService.SettlementReport? = nil
	local trophyWrites: TrophyService.OutboxWrites = {}
	if kind == "Final" then
		-- A throw in the trophy part must not take the coins/cert settlement (or the runtime's
		-- completion) down with it: the trophy part then reports TrophyUnavailable.
		local prepared, r, w = pcall(TrophyService.PrepareCompletionContext, context, { CallerSaves = true })
		if prepared then
			trophyReport, trophyWrites = r, w
			report.Trophy = r
			if not r.Ok then
				warn("[AdventureSettlement] trophy settlement refused: " .. tostring(r.Error))
			end
		else
			warn("[AdventureSettlement] trophy settlement failed: " .. tostring(r))
		end
	end
	local trophyAvailable = trophyReport ~= nil and trophyReport.Ok
	local work: { () -> () } = {}
	for _, decision in decisions do
		local entry: PlayerResult
		local intent = decision.Intent
		local userId = decision.UserId
		local trophyEntry = if trophyReport then trophyReport.ByUserId[userId] else nil
		if not intent then
			entry = { UserId = userId, Status = "Ineligible", Reason = decision.Reason }
			if trophyEntry and trophyEntry.Status ~= "Ineligible" then
				-- both rules are the same; this would be a bug, so say it loudly
				warn(string.format("[AdventureSettlement] eligibility mismatch for %d", userId))
			end
			table.insert(work, function()
				publish(report, entry)
			end)
		else
			local player = Players:GetPlayerByUserId(userId)
			local applyOk, applied = true, nil
			if player then
				applyOk, applied = pcall(applyLive, player, intent)
			end
			if not applyOk then
				-- one bad save must not abort everyone else's settlement; say so truthfully
				warn(string.format("[AdventureSettlement] apply failed for %d: %s", userId, tostring(applied)))
				entry = { UserId = userId, Status = "Refused", Reason = "SettlementError" }
				local failedEntry = entry
				table.insert(work, function()
					publish(report, failedEntry)
				end)
			elseif player and applied then
				entry = toResult(userId, applied)
				if kind == "Final" then
					attachTrophy(entry, trophyEntry, trophyAvailable)
				end
				local grant = if trophyEntry then trophyEntry.Grant else nil
				if grant then
					entry.TrophyDurable = "Applied"
				elseif trophyEntry and trophyEntry.Status == "Duplicate" then
					entry.TrophyDurable = "Duplicate"
				end
				if entry.Status == "Applied" then
					AdventureSettlement.Granted:Fire(player, entry, kind)
				end
				local livePlayer, liveEntry = player, entry
				local liveIntent = if entry.Status == "Applied" then intent else nil
				table.insert(work, function()
					if liveIntent or grant then
						confirmLive(livePlayer, liveIntent, liveEntry, grant)
					end
					publish(report, liveEntry)
					if liveEntry.Status == "Unconfirmed" or liveEntry.TrophyDurable == "Unconfirmed" then
						task.spawn(retryUnconfirmed, livePlayer, report, liveIntent, liveEntry, grant)
					end
				end)
			else
				-- provisional until the durable writes below succeed
				entry = { UserId = userId, Status = "Refused", Reason = "PendingWriteFailed" }
				local offlineEntry = entry
				local trophyWrite = trophyWrites[userId]
				table.insert(work, function()
					queueOffline(intent, offlineEntry)
					if kind == "Final" then
						if trophyWrite then
							trophyWrite()
						end
						attachTrophy(offlineEntry, trophyEntry, trophyAvailable)
						if trophyWrite and trophyEntry then
							-- what it grants is only known when it is applied (drain on rejoin)
							offlineEntry.TrophyGranted, offlineEntry.StandGranted = false, false
							offlineEntry.TrophyDurable = if trophyEntry.Status == "PendingRejoin"
								then "PendingRejoin"
								else "Refused"
						end
					end
					publish(report, offlineEntry)
					-- they may have finished loading here while the writes were in flight
					local loaded = Players:GetPlayerByUserId(userId)
					if loaded and getData(loaded) ~= nil and offlineEntry.Status == "PendingRejoin" then
						requestDrain(loaded, true)
					end
				end)
			end
		end
		table.insert(report.Results, entry)
		report.ByUserId[entry.UserId] = entry
	end
	-- 2. Asynchronous: durable writes and outcomes, then the Settled signal.
	if #work == 0 then
		report.Done = true
		AdventureSettlement.Settled:Fire(report)
		return report
	end
	local remaining = #work
	inflight += #work
	for _, job in work do
		task.spawn(function()
			local ok, jobErr = pcall(job :: any)
			if not ok then
				warn("[AdventureSettlement] durable write failed: " .. tostring(jobErr))
			end
			inflight -= 1
			remaining -= 1
			if remaining == 0 then
				report.Done = true
				AdventureSettlement.Settled:Fire(report)
			end
		end)
	end
	return report
end

local function disabled(kind: "Stage" | "Final", context: any): Report
	return settle(kind, context, nil, "Disabled")
end

--[[
	Settles one completed stage from the runtime's frozen stage observation. Never yields.
	Returns the report; statuses of applied/queued entries are updated in place as durable
	writes resolve (report.Done, AdventureSettlement.Settled).
]]
function AdventureSettlement.SettleStage(observation: any): Report
	if not enabled then
		return disabled("Stage", observation)
	end
	local decisions, err = Rewards.StageDecisions(observation, os.time())
	return settle("Stage", observation, decisions, err)
end

-- Settles a successful completion from the runtime's frozen CompletionContext. Never yields.
function AdventureSettlement.SettleCompletion(context: any): Report
	if not enabled then
		return disabled("Final", context)
	end
	local decisions, err = Rewards.FinalDecisions(context, os.time())
	return settle("Final", context, decisions, err)
end

-- Drop-in for SpringVaultService.Start({ OnStage = ... }).
function AdventureSettlement.OnStage(observation: any)
	local report = AdventureSettlement.SettleStage(observation)
	if not report.Ok then
		warn("[AdventureSettlement] stage refused: " .. tostring(report.Error))
	end
end

-- Broadcast texts. The runtime sends the message to EVERY player in the server (participants,
-- refused watchers, ineligible players and bystanders), so it must be true for all of them:
-- it never says that anyone was rewarded or that anything was saved. Each participant's own
-- truthful result is their outcome card, sent once their durable writes resolve.
AdventureSettlement.COMPLETION_MESSAGE = "Adventure complete! Crew members: your reward card shows what you earned."
AdventureSettlement.REFUSED_MESSAGE =
	"Adventure complete. Completion rewards are unavailable right now; stage rewards already earned are kept."

-- Drop-in for SpringVaultService.Start({ OnCompletion = ... }): returns (accepted, message).
function AdventureSettlement.OnCompletion(context: any): (boolean, string)
	local report = AdventureSettlement.SettleCompletion(context)
	if not report.Ok then
		warn("[AdventureSettlement] completion refused: " .. tostring(report.Error))
		return false, AdventureSettlement.REFUSED_MESSAGE
	end
	return true, AdventureSettlement.COMPLETION_MESSAGE
end

-- Drain ---------------------------------------------------------------------------------------

type Drained = { Intent: Rewards.Intent, Applied: Rewards.Applied }

-- What an earlier drain applied to the live save but could not acknowledge (its save failed),
-- by user and receipt. The retry re-applies them as Duplicates, so these are what it announces.
local owedIntents: { [number]: { [string]: Drained } } = {}
local owedTrophies: { [number]: { [string]: TrophyService.DrainedGrant } } = {}
local drainRetries: { [number]: number } = {}

-- Applies this bridge's durable intents, saves, then acknowledges. Yields. Returns (what was
-- applied and acknowledged, or nil; retry: the read or the save failed, try again later).
local function drainIntents(player: Player): ({ Drained }?, boolean)
	local userId = player.UserId
	local stored = outbox.Read(userId)
	if stored == nil then
		return nil, true -- unreadable right now
	end
	if next(stored) == nil or getData(player) == nil then
		return nil, false
	end
	local intents: { Rewards.Intent } = {}
	for _, intent in stored do
		table.insert(intents, intent :: any)
	end
	Rewards.SortIntents(intents)
	local done: { Drained } = {}
	local ids: { string } = {}
	for _, intent in intents do
		local applied = applyLive(player, intent)
		if not applied then
			break -- left mid-drain; the rest stay queued
		end
		table.insert(ids, Rewards.ReceiptFor(intent))
		table.insert(done, { Intent = intent, Applied = applied })
		if applied.Status == "Applied" then
			AdventureSettlement.Granted:Fire(player, toResult(userId, applied), intent.Kind)
		end
	end
	if #ids == 0 then
		return nil, false
	end
	-- Acknowledge only once the save holding them is written; otherwise the next drain
	-- re-applies them as Duplicates and acknowledges then.
	if DataService.SaveAsync(player) then
		outbox.Ack(userId, ids)
		local owed = owedIntents[userId]
		if owed then
			for i, item in done do
				local earlier = owed[Rewards.ReceiptFor(item.Intent)]
				if earlier and item.Applied.Status == "Duplicate" then
					done[i] = earlier
				end
			end
			owedIntents[userId] = nil
		end
		return done, false
	end
	if getData(player) == nil then
		return nil, false -- left: the leave save carries it, the next load acknowledges it
	end
	local owed = owedIntents[userId] or {}
	for _, item in done do
		if item.Applied.Status == "Applied" then
			owed[Rewards.ReceiptFor(item.Intent)] = item
		end
	end
	owedIntents[userId] = owed
	return nil, true
end

-- "trophy:<InstanceId>:<UserId>:final:v<n>" -> InstanceId (InstanceIds may contain ':').
local function instanceOfTrophyReceipt(receiptId: string): string?
	return string.match(receiptId, "^trophy:(.+):%d+:final:v%d+$")
end

-- One Resolved outcome per run for what a drain newly granted (Duplicates were told before).
local function publishDrained(player: Player, intents: { Drained }?, trophies: { TrophyService.DrainedGrant }?)
	local runs: { [string]: Outcome } = {}
	local order: { string } = {}
	local function run(instanceId: string): Outcome
		local outcome = runs[instanceId]
		if not outcome then
			outcome = {
				InstanceId = instanceId,
				Kind = "Stage",
				State = "Accepted",
				Status = "Saved",
				Coins = 0,
				Trophy = false,
				Stand = false,
				Resolved = true,
			}
			runs[instanceId] = outcome
			table.insert(order, instanceId)
		end
		return outcome
	end
	local stages: { [string]: { string } } = {}
	for _, item in intents or ({} :: { Drained }) do
		if item.Applied.Status == "Applied" then
			local outcome = run(item.Intent.InstanceId)
			outcome.Coins += item.Applied.Coins
			if item.Intent.Kind == "Final" then
				outcome.Kind = "Final"
				outcome.Certification = item.Applied.Certification or outcome.Certification
			else
				stages[item.Intent.InstanceId] = stages[item.Intent.InstanceId] or {}
				table.insert(stages[item.Intent.InstanceId], item.Intent.StageId :: string)
			end
		end
	end
	for _, grant in trophies or ({} :: { TrophyService.DrainedGrant }) do
		local instanceId = instanceOfTrophyReceipt(grant.ReceiptId)
		if instanceId and (grant.Status == "Granted" or grant.StandGranted) then
			local outcome = run(instanceId)
			outcome.Kind = "Final"
			outcome.Trophy = outcome.Trophy or grant.Status == "Granted"
			outcome.Stand = outcome.Stand or grant.StandGranted
		end
	end
	for _, instanceId in order do
		local outcome = runs[instanceId]
		local stageIds = stages[instanceId]
		if outcome.Kind == "Stage" and stageIds and #stageIds == 1 then
			outcome.StageId = stageIds[1]
		end
		deliver(player.UserId, outcome)
	end
end

-- Returns true when the last pass could not finish (a read or save failed).
local function drainLoop(player: Player): boolean
	local userId = player.UserId
	local retry = false
	repeat
		drainAgain[userId] = nil
		local trophies, trophyRetry, trophyUnacked = TrophyService.DrainPending(player)
		if trophyUnacked then
			local owed = owedTrophies[userId] or {}
			for _, grant in trophyUnacked do
				if grant.Status == "Granted" or grant.StandGranted then
					owed[grant.ReceiptId] = grant
				end
			end
			owedTrophies[userId] = owed
		end
		local owedGrants = owedTrophies[userId]
		if trophies and owedGrants then
			for i, grant in trophies do
				trophies[i] = owedGrants[grant.ReceiptId] or grant
			end
			owedTrophies[userId] = nil
		end
		local intents, intentRetry = nil, false
		if outbox.IsAvailable() then
			intents, intentRetry = drainIntents(player)
		end
		publishDrained(player, intents, trophies)
		retry = trophyRetry or intentRetry
	until not drainAgain[userId] or not player.Parent
	drainAgain[userId] = nil
	return retry
end

-- again = true when new intents may have landed since a drain that is already running started.
requestDrain = function(player: Player, again: boolean)
	local userId = player.UserId
	if draining[userId] then
		if again then
			drainAgain[userId] = true
		end
		return
	end
	draining[userId] = true
	local ok, result = pcall(drainLoop, player)
	draining[userId] = nil
	if not ok then
		warn("[AdventureSettlement] drain failed: " .. tostring(result))
	end
	-- A failed read or save leaves intents queued; try again while they are here (else their
	-- next load anywhere does it).
	if (not ok or result == true) and player.Parent then
		local attempt = (drainRetries[userId] or 0) + 1
		local delay = AdventureSettlement.RetryDelays[attempt]
		if delay then
			drainRetries[userId] = attempt
			task.spawn(function()
				task.wait(delay)
				if player.Parent and DataService.IsLoaded(player) then
					requestDrain(player, true)
				end
			end)
		end
	else
		drainRetries[userId] = nil
	end
end

--[[
	Applies the player's durable intents from BOTH outboxes (this bridge's and TrophyService's)
	to their live save, saves, then acknowledges, and tells them what it granted. Yields. Runs on
	every load (any server), and after an offline intent lands for a player who loaded meanwhile.
]]
function AdventureSettlement.Drain(player: Player)
	requestDrain(player, true)
end

-- Queries --------------------------------------------------------------------------------------

-- Durable intents for a user (receiptId -> intent). Yields; nil if unreadable.
function AdventureSettlement.GetPending(userId: number): { [string]: any }?
	return outbox.Read(userId)
end

-- nil when not loaded (unknown, never a guessed false).
function AdventureSettlement.HasCertification(player: Player, certId: string): boolean?
	local data = getData(player)
	if not data then
		return nil
	end
	return (data.Certifications :: { [string]: any })[certId] ~= nil
end

function AdventureSettlement.GetProgress(player: Player, eventId: string): { [string]: any }?
	local data = getData(player)
	if not data then
		return nil
	end
	local record = (data.AdventureProgress :: any).Events[eventId]
	return if type(record) == "table" then table.clone(record) else nil
end

-- Number of durable writes still in flight (shutdown waits for these).
function AdventureSettlement.InFlight(): number
	return inflight
end

-- Feature flag. Off refuses NEW settlements; earned grants stay and outbox drains continue.
function AdventureSettlement.SetEnabled(on: boolean)
	enabled = on
end

-- fn(player, text): legacy per-player reward text, used only while no outcome sender is set
-- (Main wired it to Net.Notify(player, "Reward", text)).
function AdventureSettlement.SetNotifier(fn: ((Player, string) -> ())?)
	notifier = fn
end

--[[
	fn(player, outcome): per-player outcome (Outcome above) for the AdventureOutcome remote:
	Main wires Net.FireClient("AdventureOutcome", player, outcome). While set, it replaces the
	reward text from SetNotifier, so a player never gets both.
]]
function AdventureSettlement.SetOutcomeSender(fn: ((Player, Outcome) -> ())?)
	outcomeSender = fn
end

-- Lifecycle -----------------------------------------------------------------------------------

local SHUTDOWN_WAIT = 20

local function onLoaded(player: Player)
	if getData(player) ~= nil then
		task.spawn(requestDrain, player, false)
	end
end

function AdventureSettlement.Init()
	outbox.Init()
	-- One drain covers both outboxes. TrophyService's own load trigger is ignored here because
	-- PlayerLoaded below already drains; its "an offline grant just landed" trigger re-drains.
	TrophyService.SetDrainHandler(function(player: Player, why: string?)
		if why ~= "Load" then
			requestDrain(player, true)
		end
	end)
	DataService.PlayerLoaded:Connect(onLoaded)
end

function AdventureSettlement.Start()
	-- DataService's BindToClose writes every live save (they already hold applied grants);
	-- this one keeps the server up until offline intents reach the outboxes.
	game:BindToClose(function()
		local deadline = os.clock() + SHUTDOWN_WAIT
		while inflight > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

function AdventureSettlement.OnPlayerAdded(player: Player)
	-- PlayerLoaded covers the normal async load; this covers a service started late.
	if DataService.IsLoaded(player) then
		onLoaded(player)
	end
end

return AdventureSettlement
