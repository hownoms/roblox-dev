--!strict
--[[
	EventService — server-wide timed events (Config.Events: High Tide, Golden Hour).
	Events are deterministic from os.time() (Config.GetActiveEvents), so every server agrees.
	When the active set changes the service:
	  - sets Workspace attribute "ActiveEvents" = comma separated ids ("" when none),
	  - fires EventChanged(activeIds) to all clients (and to each player on join),
	  - notifies everyone ("Event" kind) when an event starts,
	  - fires EventService.Changed for server consumers (MultiplierService).

	Public API:
		EventService.GetActiveIds(): { string }
		EventService.IsActive(eventId): boolean
		EventService.Changed: Signal<{ string }>
		EventService.StartEarly(eventId, seconds): boolean
			Starts an event now for `seconds` on THIS server (server dig goal, v2.2), on top of
			the deterministic schedule. Sets Workspace attribute "EventEnds_<id>" = unix end time
			(cleared when it ends) so clients count down the real remaining time. If the event
			is already running it is extended to last at least `seconds` more. Returns false for
			an unknown id or a non-positive duration.
		EventService.GetSecondsLeft(eventId): number   (0 when inactive)

	Live config (LiveConfig): events in `events_off` never run (scheduled or started early), and
	Workspace attribute "EventsOff" lists them for the HUD. `bonus_event` runs that event on every
	server until `bonus_event_ends`, the same way as StartEarly; removing it ends the bonus.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Signal = require(Shared.Util.Signal)

local LiveConfig = require(script.Parent.LiveConfig)
local Net = require(script.Parent.Net)

local EventService = {}

EventService.Changed = Signal.new() :: Signal.Signal<{ string }>

local activeIds: { string } = {}
local activeKey = ""
local forcedUntil: { [string]: number } = {} -- event id -> unix end time (StartEarly)
local bonus: { Id: string, Ends: number }? = nil -- the live-config bonus event in forcedUntil

local function compute(): ({ string }, string)
	local now = os.time()
	local ids = {}
	local off = LiveConfig.Get().EventsOff
	for _, event in Config.GetActiveEvents(now) do
		if not off[event.Id] then
			table.insert(ids, event.Id)
		end
	end
	for id, ends in forcedUntil do
		if ends <= now then
			forcedUntil[id] = nil
			Workspace:SetAttribute("EventEnds_" .. id, nil)
		elseif not off[id] and not table.find(ids, id) then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids, table.concat(ids, ",")
end

local function update(announce: boolean)
	local ids, key = compute()
	if key == activeKey then
		return
	end
	local previous = {}
	for _, id in activeIds do
		previous[id] = true
	end
	activeIds = ids
	activeKey = key
	Workspace:SetAttribute("ActiveEvents", key)
	Net.FireAll("EventChanged", table.clone(ids))
	if announce then
		for _, id in ids do
			local def = Config.GetEvent(id)
			if def and not previous[id] then
				Net.NotifyAll("Event", string.upper(def.Name) .. "! " .. def.Description)
			end
		end
	end
	EventService.Changed:Fire(table.clone(ids))
end

function EventService.GetActiveIds(): { string }
	return table.clone(activeIds)
end

function EventService.IsActive(eventId: string): boolean
	return table.find(activeIds, eventId) ~= nil
end

function EventService.GetSecondsLeft(eventId: string): number
	if not EventService.IsActive(eventId) then
		return 0
	end
	local now = os.time()
	local forced = forcedUntil[eventId]
	local scheduled = 0
	local def = Config.GetEvent(eventId)
	if def and Config.GetSecondsUntilEvent(eventId, now) == 0 then
		scheduled = def.DurationSeconds - (now + def.OffsetSeconds) % def.IntervalSeconds
	end
	return math.max(scheduled, if forced then forced - now else 0)
end

function EventService.StartEarly(eventId: string, seconds: number): boolean
	if not Config.GetEvent(eventId) or not (seconds > 0) then
		return false
	end
	local now = os.time()
	local ends = math.max(now + math.floor(seconds), now + EventService.GetSecondsLeft(eventId))
	forcedUntil[eventId] = ends
	Workspace:SetAttribute("EventEnds_" .. eventId, ends)
	update(true)
	return true
end

local function applyLive(snap: LiveConfig.Snapshot)
	local offList = {}
	for id in snap.EventsOff do
		table.insert(offList, id)
	end
	table.sort(offList)
	Workspace:SetAttribute("EventsOff", table.concat(offList, ","))
	local wanted = snap.BonusEvent
	local wantedEnds = snap.BonusEventEnds
	local current = bonus
	if current and (current.Id ~= wanted or current.Ends ~= wantedEnds) then
		-- end the old bonus, unless something else (server goal) has pushed it further
		if forcedUntil[current.Id] == current.Ends then
			forcedUntil[current.Id] = nil
			Workspace:SetAttribute("EventEnds_" .. current.Id, nil)
		end
		bonus = nil
	end
	if wanted and wantedEnds and wantedEnds > os.time() and not bonus then
		local ends = math.max(wantedEnds, forcedUntil[wanted] or 0)
		forcedUntil[wanted] = ends
		Workspace:SetAttribute("EventEnds_" .. wanted, ends)
		bonus = { Id = wanted, Ends = ends }
	end
end

function EventService.Init()
	Workspace:SetAttribute("ActiveEvents", "")
	applyLive(LiveConfig.Get())
	LiveConfig.Changed:Connect(function(snap: LiveConfig.Snapshot)
		applyLive(snap)
		update(true)
	end)
	update(false)
end

function EventService.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			update(true)
		end
	end)
end

function EventService.OnPlayerAdded(player: Player)
	Net.FireClient("EventChanged", player, table.clone(activeIds))
end

return EventService
