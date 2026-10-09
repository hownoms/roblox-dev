--!strict
--[[
	TrophyService — server-authoritative permanent adventure trophies and camp display.

	Grants happen only through SettleAdventureCompletion, a server-only module call made by the
	adventure/event owner after it has validated a completed run. There is no remote that grants,
	and camp remotes accept only small ids/cells for trophies the player already owns.

	Completion API (full contract: docs/TROPHY_INTEGRATION.md):

		TrophyService.SettleAdventureCompletion({
			EventId = "event_vault",                 -- completion context
			LandmarkId = "landmark_spring_vault",    -- trophy entitlement source
			InstanceId = "<server session GUID>:<sequence>",
			Outcome = "Completed",
			RewardVersion = 1,                       -- optional, default 1
			Participants = { { UserId, Points, ActiveSeconds, ObjectiveCompletions,
				PresentForObjective }, ... },
		}) -> SettlementReport

	Idempotency: each grant carries ReceiptId = Rules.ReceiptId(InstanceId, UserId,
	RewardVersion), written in the same synchronous save mutation as the TrophyRecords entry.
	Ownership itself is the permanent first-clear flag, so a repeat, retry, a second instance
	or a pruned receipt can never grant twice. Eligible players who are not loaded on this server
	(disconnected / rejoining) get a bounded in-memory pending grant that is applied when they
	load on THIS server; it does not survive a server shutdown (documented limitation).

	Ownership queries: Owns, GetTrophies, GetCampLayout, GetTrophySlots.
	Camp: PlaceTrophy(player, request), RemovePlacement(player, placementId). Removing a display
	only edits CampLayout; TrophyRecords are never touched by camp code.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Catalog = require(Shared.Trophies.Catalog)
local Rules = require(Shared.Trophies.Rules)
local Signal = require(Shared.Util.Signal)
local TableUtil = require(Shared.Util.TableUtil)

local TrophyData = require(script.Parent.TrophyData)
local Display = require(script.Parent.TrophyCampDisplay)

export type GrantStatus =
	"Granted" -- newly owned, saved with this settlement's receipt
	| "AlreadyOwned" -- owned before (earlier run / earlier instance); nothing changed
	| "Duplicate" -- this exact receipt was already settled; nothing changed
	| "PendingRejoin" -- eligible but not loaded here; applied if they load on this server
	| "Ineligible" -- did not meet the contribution rule (Reason says why)
	| "Refused" -- could not be stored (Reason: "RecordLimit" / "PendingFull")

export type PlayerResult = {
	UserId: number,
	Status: GrantStatus,
	Reason: string?,
}

export type SettlementReport = {
	Ok: boolean,
	Error: string?, -- set when Ok == false; then nothing was changed for anyone
	EventId: string?,
	LandmarkId: string?,
	InstanceId: string?,
	Results: { PlayerResult },
	ByUserId: { [number]: PlayerResult },
}

type Grant = {
	TrophyId: string,
	Source: string,
	RegionId: string,
	ReceiptId: string,
}

local TrophyService = {}

-- (player, trophyId, record) after a grant is applied to the live save
TrophyService.TrophyGranted = Signal.new() :: Signal.Signal<Player, string, { [string]: any }>
-- (player, layout) after a placement or removal
TrophyService.CampChanged = Signal.new() :: Signal.Signal<Player, Rules.CampLayout>

local MAX_PENDING_USERS = 64
local MAX_PENDING_PER_USER = 8

local enabled = true
local pending: { [number]: { Grant } } = {}
local pendingUsers = 0

-- Grants --------------------------------------------------------------------------------------

-- Applies one grant to a loaded player's save. Synchronous; never yields.
local function applyGrant(player: Player, grant: Grant): (GrantStatus, string?)
	local status: GrantStatus = "Refused"
	local reason: string? = nil
	local record: { [string]: any }? = nil
	local ok = TrophyData.Mutate(player, function(data)
		local records = data.TrophyRecords :: { [string]: any }
		local receipts = data.RewardReceipts :: { [string]: any }
		if receipts[grant.ReceiptId] ~= nil then
			status = "Duplicate"
			return
		end
		if records[grant.TrophyId] ~= nil then
			status = "AlreadyOwned"
			return
		end
		if TableUtil.Count(records) >= Rules.MAX_TROPHY_RECORDS then
			status, reason = "Refused", "RecordLimit"
			return
		end
		local now = os.time()
		local new = {
			Kind = "Landmark",
			Source = grant.Source,
			RegionId = grant.RegionId,
			AcquiredAt = now,
			ReceiptId = grant.ReceiptId,
			Legacy = false,
			ContentVersion = Rules.CONTENT_VERSION,
		}
		records[grant.TrophyId] = new
		receipts[grant.ReceiptId] = now
		Rules.PruneReceipts(receipts, now)
		record = new
		status = "Granted"
	end)
	if not ok then
		return "Refused", "NotLoaded"
	end
	if status == "Granted" then
		TrophyData.RequestSave(player)
		TrophyService.TrophyGranted:Fire(player, grant.TrophyId, TableUtil.DeepCopy(record :: any))
	end
	return status, reason
end

local function queuePending(userId: number, grant: Grant): (GrantStatus, string?)
	local list = pending[userId]
	if list then
		for _, g in list do
			if g.ReceiptId == grant.ReceiptId or g.TrophyId == grant.TrophyId then
				return "PendingRejoin", nil
			end
		end
		if #list >= MAX_PENDING_PER_USER then
			return "Refused", "PendingFull"
		end
	else
		if pendingUsers >= MAX_PENDING_USERS then
			return "Refused", "PendingFull"
		end
		list = {}
		pending[userId] = list
		pendingUsers += 1
	end
	table.insert(list :: { Grant }, grant)
	return "PendingRejoin", nil
end

local function applyPending(player: Player)
	local list = pending[player.UserId]
	if not list or TrophyData.Get(player) == nil then
		return
	end
	pending[player.UserId] = nil
	pendingUsers -= 1
	for _, grant in list do
		applyGrant(player, grant)
	end
end

local function fail(err: string, result: any?): SettlementReport
	local r = if type(result) == "table" then result else {}
	return {
		Ok = false,
		Error = err,
		EventId = if type(r.EventId) == "string" then r.EventId else nil,
		LandmarkId = if type(r.LandmarkId) == "string" then r.LandmarkId else nil,
		InstanceId = if type(r.InstanceId) == "string" then r.InstanceId else nil,
		Results = {},
		ByUserId = {},
	}
end

--[[
	Settles the permanent trophy for a validated, completed adventure. Server-only; call after
	the event has frozen scoring and snapshotted contributions. Safe to call again with the
	same arguments (retry): already-applied grants report "Duplicate". Never yields.
]]
function TrophyService.SettleAdventureCompletion(result: any): SettlementReport
	if not enabled then
		return fail("Disabled", result)
	end
	if type(result) ~= "table" then
		return fail("Malformed", result)
	end
	local eventId = result.EventId
	if type(eventId) ~= "string" or Catalog.EventLandmarks[eventId] == nil then
		return fail("UnknownEvent", result)
	end
	local landmarkId = result.LandmarkId
	local def = Catalog.Get(landmarkId)
	if Catalog.EventLandmarks[eventId] ~= landmarkId or not def or not def.Sources[eventId] then
		return fail("LandmarkMismatch", result)
	end
	local trophyDef = def :: Catalog.TrophyDef
	local instanceId = result.InstanceId
	if type(instanceId) ~= "string" or #instanceId == 0 or #instanceId > Rules.MAX_INSTANCE_ID_LENGTH then
		return fail("BadInstanceId", result)
	end
	if result.Outcome ~= "Completed" then
		-- failure / abandon keeps stage grants (event owner) and grants no completion trophy
		return fail("NotCompleted", result)
	end
	local rewardVersion = if result.RewardVersion == nil then 1 else result.RewardVersion
	if type(rewardVersion) ~= "number" or rewardVersion % 1 ~= 0 or rewardVersion < 1 or rewardVersion > 1000 then
		return fail("BadRewardVersion", result)
	end
	local participants = result.Participants
	if type(participants) ~= "table" or #participants < 1 or #participants > Rules.MAX_PARTICIPANTS then
		return fail("BadParticipants", result)
	end
	local seen: { [number]: boolean } = {}
	for i = 1, #participants do
		local p = participants[i]
		if not Rules.IsParticipant(p) or seen[p.UserId] then
			return fail("BadParticipants", result)
		end
		seen[p.UserId] = true
	end

	local report: SettlementReport = {
		Ok = true,
		EventId = eventId,
		LandmarkId = landmarkId,
		InstanceId = instanceId,
		Results = {},
		ByUserId = {},
	}
	for i = 1, #participants do
		local p = participants[i] :: Rules.Participant
		local entry: PlayerResult
		local eligible, why = Rules.IsEligible(p, #participants)
		if not eligible then
			entry = { UserId = p.UserId, Status = "Ineligible", Reason = why }
		else
			local grant: Grant = {
				TrophyId = trophyDef.Id,
				Source = eventId,
				RegionId = trophyDef.RegionId,
				ReceiptId = Rules.ReceiptId(instanceId, p.UserId, rewardVersion),
			}
			local player = Players:GetPlayerByUserId(p.UserId)
			local status: GrantStatus, reason: string?
			if player and TrophyData.Get(player) ~= nil then
				status, reason = applyGrant(player, grant)
			else
				status, reason = queuePending(p.UserId, grant)
			end
			entry = { UserId = p.UserId, Status = status, Reason = reason }
		end
		table.insert(report.Results, entry)
		report.ByUserId[p.UserId] = entry
	end
	return report
end

--[[
	Maps the adventure runtime's CompletionContext (codex/spring-vault-adventure,
	SpringVaultState.completionContext) onto SettleAdventureCompletion:
		EventInstanceId -> InstanceId, Success -> Outcome, and per participant
		ObjectiveIds (objectives they were present for) -> PresentForObjective,
		ObjectiveCompletions = #ObjectiveIds when they earned points (a solo player who earned
		points did the work), else 0.
	The context's own Eligible flag must ALSO be true (both rules must agree; it additionally
	requires being connected and present at completion). Anything unexpected is rejected by
	the normal validation, so a malformed context changes nothing.
]]
function TrophyService.SettleCompletionContext(context: any): SettlementReport
	if type(context) ~= "table" or type(context.Participants) ~= "table" then
		return fail("Malformed", context)
	end
	local participants = {}
	local vetoed: { [number]: boolean } = {}
	for i, p in context.Participants do
		if type(i) ~= "number" or type(p) ~= "table" or type(p.ObjectiveIds) ~= "table" then
			return fail("BadParticipants", context)
		end
		local witnessed = #p.ObjectiveIds
		participants[i] = {
			UserId = p.UserId,
			Points = p.Points,
			ActiveSeconds = p.ActiveSeconds,
			ObjectiveCompletions = if type(p.Points) == "number" and p.Points > 0 then witnessed else 0,
			PresentForObjective = witnessed > 0,
		}
		if p.Eligible ~= true and type(p.UserId) == "number" then
			vetoed[p.UserId] = true
		end
	end
	-- Apply the event's veto by zeroing the facts we pass, so a vetoed player cannot qualify
	-- under our rule either, then label the result honestly afterwards.
	for _, p in participants do
		if vetoed[p.UserId] then
			p.Points, p.ActiveSeconds, p.ObjectiveCompletions, p.PresentForObjective = 0, 0, 0, false
		end
	end
	local report = TrophyService.SettleAdventureCompletion({
		EventId = context.EventId,
		LandmarkId = context.LandmarkId,
		InstanceId = context.EventInstanceId,
		Outcome = if context.Success == true then "Completed" else "Failed",
		RewardVersion = 1,
		Participants = participants,
	})
	for _, entry in report.Results do
		if vetoed[entry.UserId] then
			entry.Reason = "EventIneligible"
		end
	end
	return report
end

-- Drop-in for SpringVaultService.Start({ OnCompletion = ... }): returns (accepted, message).
-- The message is broadcast to every player by the runtime, so it stays generic; per-player
-- outcomes are in TrophyGranted and in the report from SettleCompletionContext.
function TrophyService.OnCompletion(context: any): (boolean, string)
	local report = TrophyService.SettleCompletionContext(context)
	if not report.Ok then
		warn("[TrophyService] completion refused: " .. tostring(report.Error))
		return false, "Adventure complete. Trophy rewards are unavailable right now."
	end
	for _, entry in report.Results do
		if entry.Status ~= "Ineligible" and entry.Status ~= "Refused" then
			return true, "Adventure complete! The Spring Vault trophy is in the crew's collection."
		end
	end
	return true, "Adventure complete!"
end

-- Ownership queries ---------------------------------------------------------------------------

-- nil when the player's data is not loaded (unknown), never a guessed false.
function TrophyService.Owns(player: Player, trophyId: string): boolean?
	local data = TrophyData.Get(player)
	if not data then
		return nil
	end
	return (data.TrophyRecords :: { [string]: any })[trophyId] ~= nil
end

-- Copy of the player's trophy records ({ [trophyId] = record }), or nil if not loaded.
function TrophyService.GetTrophies(player: Player): { [string]: { [string]: any } }?
	local data = TrophyData.Get(player)
	return if data then TableUtil.DeepCopy(data.TrophyRecords) else nil
end

function TrophyService.GetCampLayout(player: Player): Rules.CampLayout?
	local data = TrophyData.Get(player)
	return if data then TableUtil.DeepCopy(data.CampLayout) else nil
end

function TrophyService.GetTrophySlots(_player: Player): number
	return Rules.TROPHY_SLOTS
end

function TrophyService.HasPendingGrant(userId: number): boolean
	return pending[userId] ~= nil
end

-- Camp placement ------------------------------------------------------------------------------

local function refreshDisplay(player: Player)
	local data = TrophyData.Get(player)
	if data then
		Display.Show(player, data.CampLayout)
	end
end

--[[
	request = { TrophyId: string, X: 0..11, Z: 0..11, Rot: 0|90|180|270 } (untrusted).
	Returns (true, placementId) or (false, reason).
]]
function TrophyService.PlaceTrophy(player: Player, request: any): (boolean, any)
	if not enabled then
		return false, "Disabled"
	end
	local data = TrophyData.Get(player)
	if not data then
		return false, "NotLoaded"
	end
	local ok, clean = Rules.ValidatePlacement(data.TrophyRecords, data.CampLayout, request, Rules.TROPHY_SLOTS)
	if not ok then
		return false, clean
	end
	local placementId = 0
	TrophyData.Mutate(player, function(d)
		local layout = d.CampLayout :: Rules.CampLayout
		placementId = layout.NextId
		layout.NextId += 1
		clean.Id = placementId
		table.insert(layout.Placements, clean)
	end)
	refreshDisplay(player)
	TrophyService.CampChanged:Fire(player, TableUtil.DeepCopy(data.CampLayout))
	return true, placementId
end

-- Removes a display only. Ownership (TrophyRecords) is untouched. Returns (ok, reason?).
function TrophyService.RemovePlacement(player: Player, placementId: any): (boolean, string?)
	if not enabled then
		return false, "Disabled"
	end
	if type(placementId) ~= "number" or placementId ~= placementId or placementId % 1 ~= 0 then
		return false, "Malformed"
	end
	local data = TrophyData.Get(player)
	if not data then
		return false, "NotLoaded"
	end
	local layout = data.CampLayout :: Rules.CampLayout
	local index: number? = nil
	for i, p in layout.Placements do
		if p.Id == placementId then
			index = i
			break
		end
	end
	if not index then
		return false, "NoSuchPlacement"
	end
	TrophyData.Mutate(player, function(d)
		table.remove((d.CampLayout :: Rules.CampLayout).Placements, index :: number)
	end)
	refreshDisplay(player)
	TrophyService.CampChanged:Fire(player, TableUtil.DeepCopy(data.CampLayout))
	return true, nil
end

-- Feature flag ("Trophies", bible ch.05). Off blocks NEW grants and camp edits only; owned
-- trophies stay owned and queries keep working.
function TrophyService.SetEnabled(on: boolean)
	enabled = on
end

function TrophyService.IsEnabled(): boolean
	return enabled
end

-- Optional explicit pads (pad-centre CFrames on the ground) instead of "TrophyCampPad" tags.
function TrophyService.SetCampPads(pads: { CFrame }?)
	Display.SetPads(pads)
end

-- Remotes -------------------------------------------------------------------------------------

local PLACE_TEXT: { [string]: string } = {
	NotOwned = "You don't own that trophy yet.",
	OutOfBounds = "That spot is outside your camp.",
	Occupied = "Something is already there.",
	AlreadyDisplayed = "That trophy is already on display.",
	NoSlots = "All your trophy slots are full.",
	LayoutFull = "Your camp is full.",
}

--[[
	Connects the camp remotes. Call from Main only after the integration patch has added
	"PlaceCampItem" and "RemoveCampItem" to Remotes.Events (Remotes.Get asserts unknown names).
	Clients send only (trophyId, x, z, rot) and (placementId); nothing a client sends can grant.
]]
function TrophyService.ConnectRemotes(net: any)
	net.On("PlaceCampItem", function(player: Player, trophyId: any, x: any, z: any, rot: any)
		if not net.IsString(trophyId, 64) then
			return
		end
		local ok, reason = TrophyService.PlaceTrophy(player, { TrophyId = trophyId, X = x, Z = z, Rot = rot })
		if not ok and PLACE_TEXT[reason] then
			net.Notify(player, "Error", PLACE_TEXT[reason])
		end
	end, { Rate = 4, Window = 1 })
	net.On("RemoveCampItem", function(player: Player, placementId: any)
		if not net.IsInteger(placementId, 1, 2 ^ 31) then
			return
		end
		TrophyService.RemovePlacement(player, placementId)
	end, { Rate = 4, Window = 1 })
end

-- Lifecycle -----------------------------------------------------------------------------------

local function onLoaded(player: Player)
	if TrophyData.Get(player) == nil then
		return
	end
	applyPending(player)
	refreshDisplay(player)
end

function TrophyService.Init()
	TrophyData.PlayerLoaded:Connect(function(player: Player)
		onLoaded(player)
	end)
end

function TrophyService.OnPlayerAdded(player: Player)
	-- Main runs OnPlayerAdded before the async load finishes; PlayerLoaded covers that case.
	-- This covers a service started after the player already loaded.
	if TrophyData.IsLoaded(player) then
		onLoaded(player)
	end
end

function TrophyService.OnPlayerRemoving(player: Player)
	Display.Hide(player)
end

return TrophyService
