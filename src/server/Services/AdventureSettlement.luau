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

	Rules (Rewards.AdventureRewards, bible ch.04): each completed major stage grants its share
	to contributors at that moment; a successful completion grants the remainder to eligible
	players, and the first eligible completion grants the trophy, Mara's stand, cert_crew and the
	q_mara credit in the same save mutation. Receipts ("adv:" namespace) make every settlement
	idempotent: a replayed stage/final, a retry or a drained outbox intent is a Duplicate.

	Durability. A grant is reported Saved only once the player's save holding it has been written
	(DataService.SaveAsync), or Queued once its intent is in the durable outbox
	(AdventureRewardIntents_v1). An eligible player whose save is not loaded here gets the intent
	in the outbox (PendingRejoin), applied on their next load on any server. Outbox intents are
	acknowledged only after the save that applied them succeeded. On shutdown, DataService's
	BindToClose writes every live save (which already holds applied grants) and this service
	waits for in-flight outbox writes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rewards = require(ReplicatedStorage.Shared.Rewards.AdventureRewards)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local DurableOutbox = require(script.Parent.DurableOutbox)
local TrophyData = require(script.Parent.TrophyData)
local TrophyService = require(script.Parent.TrophyService)

export type Status =
	"Applied" -- in the live save; the durable write is in flight
	| "Saved" -- in the live save, and that save has been written
	| "Queued" -- in the live save; the save write failed but the intent is in the durable outbox
	| "Unconfirmed" -- in the live save only; both writes failed (the next autosave/leave save carries it)
	| "Duplicate" -- this receipt was already settled; nothing changed
	| "PendingRejoin" -- eligible, not loaded here; durably queued for their next load anywhere
	| "Ineligible" -- Reason says why
	| "Refused" -- not loaded here and not stored (Reason: PendingFull / PendingWriteFailed)

export type PlayerResult = {
	UserId: number,
	Status: Status,
	Reason: string?,
	Coins: number?,
	FirstClear: boolean?,
	TrophyGranted: boolean?,
	StandGranted: boolean?,
	Certification: string?,
}

export type Report = {
	Ok: boolean,
	Error: string?, -- set when Ok == false; nothing changed for anyone
	Kind: "Stage" | "Final",
	InstanceId: string?,
	StageId: string?,
	Results: { PlayerResult },
	ByUserId: { [number]: PlayerResult },
	Done: boolean, -- every durable write has resolved
}

local KEYS = {
	"Coins",
	"TrophyRecords",
	"CampLayout",
	"RewardReceipts",
	"Cosmetics",
	"Certifications",
	"AdventureProgress",
}

local STAGE_TEXT: { [string]: string } = {
	excavation = "clearing the vault anchors",
	vault_open = "opening the Spring Vault",
	ball_return = "bringing the beach ball home",
}

local AdventureSettlement = {}

-- (report) once every durable write of a settlement has resolved
AdventureSettlement.Settled = Signal.new() :: Signal.Signal<Report>
-- (player, result, kind) when a grant reached a live save (UI / analytics / quest hooks)
AdventureSettlement.Granted = Signal.new() :: Signal.Signal<Player, PlayerResult, string>

local outbox = DurableOutbox.new("AdventureRewardIntents_v1", 16, Rewards.IsIntent)
AdventureSettlement.Outbox = outbox

local enabled = true
local notifier: ((Player, string) -> ())? = nil
local inflight = 0
local draining: { [number]: boolean } = {}
local migrated: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function notify(player: Player, text: string)
	if notifier and player.Parent then
		local ok, err = pcall(notifier :: any, player, text)
		if not ok then
			warn("[AdventureSettlement] notify failed: " .. tostring(err))
		end
	end
end

-- The live save with trophy and adventure fields guaranteed, or nil if not loaded.
local function getData(player: Player): { [string]: any }?
	local data = TrophyData.Get(player) -- runs the trophy migration once per save table
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
	if result.Status == "Applied" then
		local trophy = result.Trophy
		if trophy and (trophy.Record ~= nil or trophy.StandGranted) then
			local def = Rewards.Events[intent.EventId]
			TrophyService.AfterGrantApplied(player, def.LandmarkId, trophy.Record, trophy.StandGranted)
		end
		if result.Coins > 0 then
			Analytics.Source(
				player,
				"Coins",
				result.Coins,
				(data :: any).Coins,
				Enum.AnalyticsEconomyTransactionType.Gameplay,
				string.format("Adventure:%s:%s", intent.EventId, intent.StageId or "final")
			)
		end
	end
	return result
end

local function describe(result: PlayerResult, kind: string, stageId: string?): string?
	local parts: { string } = {}
	if result.Coins and result.Coins > 0 then
		table.insert(parts, string.format("+%d Coins", result.Coins))
	end
	if kind == "Stage" then
		if #parts == 0 then
			return nil
		end
		return parts[1] .. " for " .. (STAGE_TEXT[stageId or ""] or "that stage") .. "!"
	end
	local unlocks: { string } = {}
	if result.TrophyGranted then
		table.insert(unlocks, "the Spring Vault trophy")
	end
	if result.StandGranted then
		table.insert(unlocks, "Mara's trophy stand")
	end
	if result.Certification then
		table.insert(unlocks, "Crew certification")
	end
	if #unlocks > 0 then
		table.insert(parts, "You earned " .. table.concat(unlocks, ", "))
	end
	if #parts == 0 then
		return nil
	end
	return table.concat(parts, " · ") .. "!"
end

local function toResult(userId: number, applied: Rewards.Applied): PlayerResult
	local trophy = applied.Trophy
	return {
		UserId = userId,
		Status = if applied.Status == "Duplicate" then "Duplicate" else "Applied",
		Coins = applied.Coins,
		FirstClear = applied.FirstClear,
		TrophyGranted = trophy ~= nil and trophy.Status == "Granted",
		StandGranted = trophy ~= nil and trophy.StandGranted,
		Certification = applied.Certification,
	}
end

-- Durable write for one live-applied result: save first, else the outbox. Yields.
local function confirmLive(player: Player, receiptId: string, intent: Rewards.Intent, entry: PlayerResult)
	if DataService.SaveAsync(player) then
		entry.Status = "Saved"
	else
		local ok = outbox.Add(intent.UserId, receiptId, intent :: any)
		if ok then
			entry.Status = "Queued"
		else
			entry.Status = "Unconfirmed"
			warn(
				string.format(
					"[AdventureSettlement] %s not yet durable for %d (save and outbox failed)",
					receiptId,
					intent.UserId
				)
			)
		end
	end
end

-- Durable write for a player not loaded here. Yields.
local function queueOffline(intent: Rewards.Intent, entry: PlayerResult)
	local receiptId = Rewards.ReceiptFor(intent)
	local ok, reason = outbox.Add(intent.UserId, receiptId, intent :: any)
	if ok then
		entry.Status, entry.Reason = "PendingRejoin", nil
		-- they may have finished loading here while the write was in flight
		local player = Players:GetPlayerByUserId(intent.UserId)
		if player and getData(player) ~= nil then
			task.spawn(AdventureSettlement.Drain, player)
		end
	else
		entry.Status, entry.Reason = "Refused", reason
		warn(
			string.format("[AdventureSettlement] %s not stored for %d: %s", receiptId, intent.UserId, tostring(reason))
		)
	end
end

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
	local work: { () -> () } = {}
	for _, decision in decisions do
		local entry: PlayerResult
		local intent = decision.Intent
		if not intent then
			entry = { UserId = decision.UserId, Status = "Ineligible", Reason = decision.Reason }
		else
			local player = Players:GetPlayerByUserId(decision.UserId)
			local applied = if player then applyLive(player, intent) else nil
			if player and applied then
				entry = toResult(decision.UserId, applied)
				if entry.Status == "Applied" then
					local livePlayer, receiptId, liveEntry = player, Rewards.ReceiptFor(intent), entry
					AdventureSettlement.Granted:Fire(player, entry, kind)
					table.insert(work, function()
						confirmLive(livePlayer, receiptId, intent, liveEntry)
						local text = describe(liveEntry, kind, intent.StageId)
						if text then
							notify(livePlayer, text)
						end
					end)
				end
			else
				-- provisional until the durable write below succeeds
				entry = { UserId = decision.UserId, Status = "Refused", Reason = "PendingWriteFailed" }
				local offlineEntry = entry
				table.insert(work, function()
					queueOffline(intent, offlineEntry)
				end)
			end
		end
		table.insert(report.Results, entry)
		report.ByUserId[entry.UserId] = entry
	end
	-- 2. Asynchronous: durable writes, then the Settled signal.
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

-- Drop-in for SpringVaultService.Start({ OnCompletion = ... }): returns (accepted, message).
-- The runtime broadcasts the message to everyone, so it stays generic; each participant gets
-- their own reward notification once it is durable.
function AdventureSettlement.OnCompletion(context: any): (boolean, string)
	local report = AdventureSettlement.SettleCompletion(context)
	if not report.Ok then
		warn("[AdventureSettlement] completion refused: " .. tostring(report.Error))
		return false, "Adventure complete. Rewards are unavailable right now."
	end
	return true, "Adventure complete! Rewards are on their way."
end

--[[
	Applies the player's durable intents to their live save, saves, then acknowledges. Yields.
	Runs on every load (any server), and after an offline intent lands for a player who loaded
	meanwhile.
]]
function AdventureSettlement.Drain(player: Player)
	local userId = player.UserId
	if draining[userId] or not outbox.IsAvailable() then
		return
	end
	draining[userId] = true
	local stored = outbox.Read(userId)
	if stored and next(stored) ~= nil and getData(player) ~= nil then
		local intents: { Rewards.Intent } = {}
		for _, intent in stored do
			table.insert(intents, intent :: any)
		end
		Rewards.SortIntents(intents)
		local appliedIds: { string } = {}
		local coins = 0
		for _, intent in intents do
			local applied = applyLive(player, intent)
			if not applied then
				break -- left mid-drain; the rest stay queued
			end
			table.insert(appliedIds, Rewards.ReceiptFor(intent))
			if applied.Status == "Applied" then
				coins += applied.Coins
				AdventureSettlement.Granted:Fire(player, toResult(userId, applied), intent.Kind)
			end
		end
		-- Acknowledge only once the save holding them is written; otherwise the next load
		-- re-applies them as Duplicates and acknowledges then.
		if #appliedIds > 0 and DataService.SaveAsync(player) then
			outbox.Ack(userId, appliedIds)
			if coins > 0 then
				notify(player, string.format("+%d Coins from your last adventure!", coins))
			end
		end
	end
	draining[userId] = nil
end

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

-- fn(player, text): per-player reward message (Main wires Net.Notify(player, "Reward", text)).
function AdventureSettlement.SetNotifier(fn: ((Player, string) -> ())?)
	notifier = fn
end

-- Lifecycle -----------------------------------------------------------------------------------

local SHUTDOWN_WAIT = 20

function AdventureSettlement.Init()
	outbox.Init()
	DataService.PlayerLoaded:Connect(function(player: Player)
		if getData(player) ~= nil then
			task.spawn(AdventureSettlement.Drain, player)
		end
	end)
end

function AdventureSettlement.Start()
	-- DataService's BindToClose writes every live save (they already hold applied grants);
	-- this one keeps the server up until offline intents reach the outbox.
	game:BindToClose(function()
		local deadline = os.clock() + SHUTDOWN_WAIT
		while inflight > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

function AdventureSettlement.OnPlayerAdded(player: Player)
	-- PlayerLoaded covers the normal async load; this covers a service started late.
	if DataService.IsLoaded(player) and getData(player) ~= nil then
		task.spawn(AdventureSettlement.Drain, player)
	end
end

return AdventureSettlement
