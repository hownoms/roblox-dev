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
	RewardVersion), written in the same synchronous save mutation as the TrophyRecords entry and
	Mara's trophy stand (Cosmetics.camp_trophy_stand): the first eligible completion grants both
	together. Ownership itself is the permanent first-clear flag, so a repeat, retry, a second
	instance or a pruned receipt can never grant twice.

	Eligible players whose data is not loaded on this server are written to the durable outbox
	(TrophyPendingStore) BEFORE "PendingRejoin" is reported, and applied on their next load on
	any server. Settlement yields only for those outbox writes.

	Ownership queries: Owns, OwnsStand, GetTrophies, GetCampLayout, GetTrophySlots.
	Camp: PlaceTrophy(player, request), RemovePlacement(player, placementId). Production display
	requires the stand; SetReviewPreview(true) (Studio only) bypasses that for review. Removing a
	display only edits CampLayout; TrophyRecords are never touched by camp code.

	Camp display action (docs/integration/camp-display-action.md): GetCampStatus(player),
	DisplayAction(player), RemoveAction(player), and ConnectCampPrompts(net) which hangs two
	server-owned ProximityPrompts on every camp pad deck. Each player's status is published as
	read-only Player attributes CampStatus / CampQueue (Trophies/CampAction).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CampAction = require(Shared.Trophies.CampAction)
local Catalog = require(Shared.Trophies.Catalog)
local Rules = require(Shared.Trophies.Rules)
local Signal = require(Shared.Util.Signal)
local TableUtil = require(Shared.Util.TableUtil)

local DataService = require(script.Parent.DataService)
local TrophyData = require(script.Parent.TrophyData)
local Display = require(script.Parent.TrophyCampDisplay)
local Pending = require(script.Parent.TrophyPendingStore)

export type GrantStatus =
	"Granted" -- trophy newly owned (plus the stand if missing), saved with this receipt
	| "AlreadyOwned" -- trophy owned before; nothing changed except a missing stand (StandGranted)
	| "Duplicate" -- this exact receipt was already settled; nothing changed
	| "PendingRejoin" -- eligible, not loaded here; durably queued for their next load anywhere
	| "Ineligible" -- did not meet the contribution rule (Reason says why)
	| "Refused" -- not stored (Reason: RecordLimit / PendingFull / PendingWriteFailed / NotLoaded)

export type PlayerResult = {
	UserId: number,
	Status: GrantStatus,
	Reason: string?,
	StandGranted: boolean?, -- true when this settlement added Mara's trophy stand
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
	At: number,
}

local TrophyService = {}

-- (player, trophyId, record) after a trophy grant is applied to the live save
TrophyService.TrophyGranted = Signal.new() :: Signal.Signal<Player, string, { [string]: any }>
-- (player, layout) after a placement or removal
TrophyService.CampChanged = Signal.new() :: Signal.Signal<Player, Rules.CampLayout>

local enabled = true
local reviewPreview = false
local draining: { [number]: boolean } = {}
local notifier: any = nil -- the Net module, once ConnectRemotes / ConnectCampPrompts ran
local campPrompts: { ProximityPrompt } = {}

-- Camp display ----------------------------------------------------------------------------------
--[[
	Pad ownership (docs/TROPHY_INTEGRATION.md "Camp display"). A pad shows exactly one owner's
	camp. A loaded player claims a free pad only when they may display (stand, or the Studio
	review preview) and their layout is non-empty. Place/remove only ever edit the caller's own
	layout, and Display never takes a pad another player holds. A player who may display but
	finds every pad busy keeps their saved layout and joins a FIFO wait list; whenever a pad is
	released (owner leaves, empties their camp, or loses display rights) it is handed over
	automatically to the longest-waiting loaded player who is still eligible.
]]

local waiting: { [Player]: number } = {} -- player -> wait-list sequence (lower = earlier)
local waitSeq = 0

-- Shows or hides one player's camp. Returns true when this released a pad they held.
local function applyDisplay(player: Player, data: { [string]: any }): boolean
	local before = Display.GetPad(player)
	local layout = data.CampLayout :: Rules.CampLayout
	if Rules.HasStand(data) or reviewPreview then
		local pad = Display.Show(player, layout)
		if pad == nil and #layout.Placements > 0 then
			if waiting[player] == nil then
				waitSeq += 1
				waiting[player] = waitSeq
			end
		else
			waiting[player] = nil
		end
	else
		Display.Hide(player) -- layout is kept; it shows once the stand is owned
		waiting[player] = nil
	end
	return before ~= nil and Display.GetPad(player) == nil
end

-- Hands free pads to waiting players, longest wait first.
local function handOver()
	local queue: { Player } = {}
	for player in waiting do
		table.insert(queue, player)
	end
	table.sort(queue, function(a: Player, b: Player): boolean
		return waiting[a] < waiting[b]
	end)
	for _, player in queue do
		if Display.FreePadCount() == 0 then
			return
		end
		local data = TrophyData.Get(player)
		if data then
			applyDisplay(player, data)
		else
			waiting[player] = nil
		end
	end
end

-- Camp status ----------------------------------------------------------------------------------

local function queuePosition(player: Player): number
	local mine = waiting[player]
	if mine == nil then
		return 0
	end
	local ahead = 0
	for _, seq in waiting do
		if seq < mine then
			ahead += 1
		end
	end
	return ahead + 1
end

local function campStatus(player: Player, data: { [string]: any }): (CampAction.Status, number)
	if not enabled then
		return "Off", 0
	end
	local layout = data.CampLayout :: Rules.CampLayout
	local mayDisplay = Rules.HasStand(data) or reviewPreview
	if #layout.Placements > 0 then
		if not mayDisplay then
			return "NoStand", 0
		elseif Display.GetPad(player) ~= nil then
			return "Displayed", 0
		elseif Display.GetPadCount() == 0 then
			return "NoPad", 0
		end
		return "Queued", queuePosition(player)
	end
	if CampAction.NextTrophy(data.TrophyRecords, layout) == nil then
		return "NoTrophy", 0
	elseif not mayDisplay then
		return "NoStand", 0
	end
	return "Ready", 0
end

-- Mirrors one player's status onto read-only Player attributes (server-written).
local function publishStatus(player: Player)
	local data = TrophyData.Get(player)
	if not data or player.Parent == nil then
		return
	end
	local status, queue = campStatus(player, data)
	player:SetAttribute(CampAction.STATUS_ATTR, status)
	player:SetAttribute(CampAction.QUEUE_ATTR, queue)
end

-- Queue places shift for everyone when anyone's camp changes, so publish all (<= 16 players).
local function publishAll(except: Player?)
	for _, player in Players:GetPlayers() do
		if player ~= except then
			publishStatus(player)
		end
	end
end

local function refreshDisplay(player: Player)
	local data = TrophyData.Get(player)
	if not data then
		return
	end
	if applyDisplay(player, data) then
		handOver()
	end
	publishAll()
end

-- Grants --------------------------------------------------------------------------------------

-- Applies one grant (trophy + stand) to a loaded player's save. Synchronous; never yields.
local function applyGrant(player: Player, grant: Grant): (GrantStatus, string?, boolean)
	local status: GrantStatus = "Refused"
	local reason: string? = nil
	local record: { [string]: any }? = nil
	local standGranted = false
	local ok = TrophyData.Mutate(player, function(data)
		local s, why, rec, stand = Rules.ApplyLandmarkGrant(data, grant, os.time())
		status, reason, record, standGranted = s :: GrantStatus, why, rec :: any, stand
	end)
	if not ok then
		return "Refused", "NotLoaded", false
	end
	if record or standGranted then
		TrophyData.RequestSave(player)
	end
	TrophyService.AfterGrantApplied(player, grant.TrophyId, record, standGranted)
	return status, reason, standGranted
end

--[[
	Display refresh + TrophyGranted signal after a grant was applied to the live save, either
	here or by another server-side settlement that ran Rules.ApplyLandmarkGrant inside its own
	save mutation (AdventureSettlement grants trophy, stand and progression together).
]]
function TrophyService.AfterGrantApplied(
	player: Player,
	trophyId: string,
	record: { [string]: any }?,
	standGranted: boolean
)
	if standGranted then
		refreshDisplay(player)
	elseif record then
		publishAll() -- NoTrophy -> NoStand / Ready
	end
	if record then
		TrophyService.TrophyGranted:Fire(player, trophyId, TableUtil.DeepCopy(record :: any))
	end
end

-- Applies the player's durable pending grants, saves, then acknowledges them. Yields.
local function drainPending(player: Player)
	local userId = player.UserId
	if draining[userId] or not Pending.IsAvailable() then
		return
	end
	draining[userId] = true
	local grants = Pending.Read(userId)
	if grants and next(grants) ~= nil and TrophyData.Get(player) ~= nil then
		local applied: { string } = {}
		for receiptId, g in grants do
			local status = applyGrant(player, {
				TrophyId = g.TrophyId,
				Source = g.Source,
				RegionId = g.RegionId,
				ReceiptId = receiptId,
				At = g.At,
			})
			if status ~= "Refused" then
				table.insert(applied, receiptId)
			end
		end
		-- Acknowledge only once the save holding them is written; otherwise the next load
		-- re-applies them as Duplicates and acknowledges then.
		if #applied > 0 and DataService.SaveAsync(player) then
			Pending.Ack(userId, applied)
		end
	end
	draining[userId] = nil
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
	Settles the permanent trophy (and Mara's stand) for a validated, completed adventure.
	Server-only; call after the event has frozen scoring and snapshotted contributions. Safe to
	call again with the same arguments (retry): already-applied grants report "Duplicate".
	Loaded players are settled synchronously first; it then yields only to durably queue
	eligible players whose data is not loaded here.
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
	local now = os.time()
	local offline: { { Entry: PlayerResult, Grant: Grant } } = {}
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
				At = now,
			}
			local player = Players:GetPlayerByUserId(p.UserId)
			if player and TrophyData.Get(player) ~= nil then
				local status: GrantStatus, reason: string?, stand: boolean = applyGrant(player, grant)
				entry = { UserId = p.UserId, Status = status, Reason = reason, StandGranted = stand }
			else
				-- provisional until the durable write below succeeds
				entry = { UserId = p.UserId, Status = "Refused", Reason = "PendingWriteFailed" }
				table.insert(offline, { Entry = entry, Grant = grant })
			end
		end
		table.insert(report.Results, entry)
		report.ByUserId[p.UserId] = entry
	end
	-- Durable outbox writes (these yield) happen after every loaded player is settled.
	for _, item in offline do
		local entry, grant = item.Entry, item.Grant
		local ok, reason = Pending.Add(entry.UserId, grant.ReceiptId, {
			TrophyId = grant.TrophyId,
			Source = grant.Source,
			RegionId = grant.RegionId,
			At = grant.At,
		})
		if ok then
			entry.Status, entry.Reason = "PendingRejoin", nil
			-- they may have finished loading here while the write was in flight
			local player = Players:GetPlayerByUserId(entry.UserId)
			if player and TrophyData.Get(player) ~= nil then
				task.spawn(drainPending, player)
			end
		else
			entry.Reason = reason
		end
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
	requires being connected and present at completion, so disconnected players are never
	granted the final trophy). Anything unexpected is rejected by the normal validation.
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
		if entry.Status == "Refused" then
			warn(string.format("[TrophyService] %d not stored: %s", entry.UserId, tostring(entry.Reason)))
		end
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

-- Mara's trophy stand (required for production display). nil when not loaded.
function TrophyService.OwnsStand(player: Player): boolean?
	local data = TrophyData.Get(player)
	if not data then
		return nil
	end
	return Rules.HasStand(data)
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

-- Durable pending grants for a user (receiptId -> grant). Yields; nil if unreadable.
function TrophyService.GetPendingGrants(userId: number): { [string]: any }?
	return Pending.Read(userId)
end

-- Camp placement ------------------------------------------------------------------------------

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
	local hasStand = Rules.HasStand(data) or reviewPreview
	local ok, clean =
		Rules.ValidatePlacement(data.TrophyRecords, data.CampLayout, request, Rules.TROPHY_SLOTS, hasStand)
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
	for _, prompt in campPrompts do
		prompt.Enabled = on
	end
	publishAll()
end

function TrophyService.IsEnabled(): boolean
	return enabled
end

-- Review preview: lets camp placement/display skip the stand requirement. Studio only; a live
-- server refuses it. Returns whether preview is now on.
function TrophyService.SetReviewPreview(on: boolean): boolean
	if on and not RunService:IsStudio() then
		warn("[TrophyService] review preview is Studio-only; refused on a live server")
		on = false
	end
	reviewPreview = on
	for _, player in Players:GetPlayers() do
		refreshDisplay(player)
	end
	return reviewPreview
end

-- Optional explicit pads (pad-centre CFrames on the ground) instead of "TrophyCampPad" tags.
-- Set this at boot; it does not move camps already shown.
function TrophyService.SetCampPads(pads: { CFrame }?)
	Display.SetPads(pads)
end

-- Read-only pad queries. Owner = UserId of the player whose camp is on pad `padIndex`, or nil
-- when it is free. The tagged pad part mirrors it as attributes OwnerUserId (0 = free) and
-- OwnerName for clients.
function TrophyService.GetCampPadOwner(padIndex: number): number?
	local owner = Display.GetPadOwner(padIndex)
	return if owner then owner.UserId else nil
end

function TrophyService.GetCampPadCount(): number
	return Display.GetPadCount()
end

-- Pad index showing this player's camp, or nil (no layout, no stand, or waiting for a pad).
function TrophyService.GetCampPad(player: Player): number?
	return Display.GetPad(player)
end

-- Camp display action -------------------------------------------------------------------------

local PLACE_TEXT: { [string]: string } = {
	NotOwned = "You don't own that trophy yet.",
	NoStand = "You need Mara's trophy stand first.",
	OutOfBounds = "That spot is outside your camp.",
	Occupied = "Something is already there.",
	AlreadyDisplayed = "That trophy is already on display.",
	NoSlots = "All your trophy slots are full.",
	LayoutFull = "Your camp is full.",
}

--[[
	The one small camp action (docs/integration/camp-display-action.md). Both calls act only on
	the caller's own CampLayout through PlaceTrophy / RemovePlacement, so every validation, the
	stand rule, pad ownership and the wait list apply unchanged. They take no client input.
]]

-- (status, queuePosition). nil status when the player's data is not loaded.
function TrophyService.GetCampStatus(player: Player): (CampAction.Status?, number)
	local data = TrophyData.Get(player)
	if not data then
		return nil, 0
	end
	return campStatus(player, data)
end

--[[
	Displays the player's next owned trophy on the first free cell of their camp, facing the
	plaza. Returns (ok, statusOrReason, text): on success the status afterwards (Displayed,
	Queued or NoPad: the layout is saved in every case); on refusal the status or placement
	reason that stopped it. `text` is the player-facing sentence.
]]
function TrophyService.DisplayAction(player: Player): (boolean, string, string)
	local data = TrophyData.Get(player)
	if not data then
		return false, "NotLoaded", ""
	end
	local status, queue = campStatus(player, data)
	if status ~= "Ready" then
		return false, status, CampAction.Text(status, queue)
	end
	local request, why = CampAction.Request(data.TrophyRecords, data.CampLayout)
	if not request then
		return false, why or "NoTrophy", PLACE_TEXT[why or ""] or CampAction.Text("NoTrophy")
	end
	local ok, reason = TrophyService.PlaceTrophy(player, request)
	if not ok then
		return false, reason, PLACE_TEXT[reason] or "That trophy can't go on display right now."
	end
	local after, place = TrophyService.GetCampStatus(player)
	local final: string = after or "NotLoaded"
	return true, final, CampAction.ResultText(true, final, place)
end

-- Puts away the player's newest display (ownership untouched). Returns (ok, statusOrReason, text).
function TrophyService.RemoveAction(player: Player): (boolean, string, string)
	local data = TrophyData.Get(player)
	if not data then
		return false, "NotLoaded", ""
	end
	local status = campStatus(player, data)
	if status == "Off" then
		return false, status, ""
	end
	local newest: number? = nil
	for _, p in (data.CampLayout :: Rules.CampLayout).Placements do
		if newest == nil or p.Id > (newest :: number) then
			newest = p.Id
		end
	end
	if newest == nil then
		return false, "NothingDisplayed", "Nothing of yours is on display."
	end
	local ok, reason = TrophyService.RemovePlacement(player, newest)
	if not ok then
		return false, reason or "Refused", ""
	end
	local after = TrophyService.GetCampStatus(player)
	return true, after or "NotLoaded", CampAction.ResultText(false)
end

-- Remotes -------------------------------------------------------------------------------------

--[[
	Connects the camp remotes. Call from Main only after the integration patch has added
	"PlaceCampItem" and "RemoveCampItem" to Remotes.Events (Remotes.Get asserts unknown names).
	Clients send only (trophyId, x, z, rot) and (placementId); nothing a client sends can grant.
]]
function TrophyService.ConnectRemotes(net: any)
	notifier = net
	net.On("PlaceCampItem", function(player: Player, trophyId: any, x: any, z: any, rot: any)
		if not net.IsString(trophyId, 64) then
			return
		end
		local ok, reason = TrophyService.PlaceTrophy(player, { TrophyId = trophyId, X = x, Z = z, Rot = rot })
		if not ok and PLACE_TEXT[reason] then
			net.Notify(player, "Error", PLACE_TEXT[reason])
		elseif ok then
			-- say honestly whether it is shown, queued, or there is no pad at all
			local status, queue = TrophyService.GetCampStatus(player)
			net.Notify(
				player,
				if status == "Displayed" then "Success" else "Info",
				CampAction.ResultText(true, status, queue)
			)
		end
	end, { Rate = 4, Window = 1 })
	net.On("RemoveCampItem", function(player: Player, placementId: any)
		if not net.IsInteger(placementId, 1, 2 ^ 31) then
			return
		end
		TrophyService.RemovePlacement(player, placementId)
	end, { Rate = 4, Window = 1 })
end

--[[
	Hangs the camp display action on every camp pad deck (parts tagged TrophyCampPad, including
	ones built later): two server-owned ProximityPrompts. The client (CampDisplayController)
	shows only the one that applies to its own status and draws the local preview; the server
	decides everything from the triggering player's own save. Call from Main after Init.
]]
function TrophyService.ConnectCampPrompts(net: any?)
	if net then
		notifier = net
	end
	local function say(player: Player, ok: boolean, status: string, text: string)
		if notifier and text ~= "" then
			local kind = if not ok then "Error" elseif status == "Displayed" then "Success" else "Info"
			notifier.Notify(player, kind, text)
		end
	end
	local function attach(inst: Instance)
		if not inst:IsA("BasePart") or inst:FindFirstChild(CampAction.DISPLAY_PROMPT) then
			return
		end
		local show = Instance.new("ProximityPrompt")
		show.Name = CampAction.DISPLAY_PROMPT
		show.ActionText = "Display trophy"
		show.ObjectText = "Trophy Camp"
		show.HoldDuration = 0.5
		show.MaxActivationDistance = 18
		show.RequiresLineOfSight = false
		show.Enabled = enabled
		show.Parent = inst
		local put = Instance.new("ProximityPrompt")
		put.Name = CampAction.REMOVE_PROMPT
		put.ActionText = "Put trophy away"
		put.ObjectText = "Trophy Camp"
		put.HoldDuration = 0.75
		put.MaxActivationDistance = 18
		put.RequiresLineOfSight = false
		put.Enabled = enabled
		put.Parent = inst
		table.insert(campPrompts, show)
		table.insert(campPrompts, put)
		show.Triggered:Connect(function(player: Player)
			say(player, TrophyService.DisplayAction(player))
		end)
		put.Triggered:Connect(function(player: Player)
			say(player, TrophyService.RemoveAction(player))
		end)
		inst.Destroying:Connect(function()
			for i = #campPrompts, 1, -1 do
				if campPrompts[i] == show or campPrompts[i] == put then
					table.remove(campPrompts, i)
				end
			end
		end)
	end
	CollectionService:GetInstanceAddedSignal(Display.PAD_TAG):Connect(attach)
	for _, inst in CollectionService:GetTagged(Display.PAD_TAG) do
		attach(inst)
	end
end

-- Lifecycle -----------------------------------------------------------------------------------

local function onLoaded(player: Player)
	if TrophyData.Get(player) == nil then
		return
	end
	refreshDisplay(player)
	task.spawn(drainPending, player)
end

function TrophyService.Init()
	Pending.Init()
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
	local wasWaiting = waiting[player] ~= nil
	waiting[player] = nil
	local held = Display.GetPad(player) ~= nil
	Display.Hide(player)
	if held then
		handOver() -- the freed pad goes to the longest-waiting eligible player
	end
	if held or wasWaiting then
		publishAll(player) -- queue places moved up
	end
end

return TrophyService
