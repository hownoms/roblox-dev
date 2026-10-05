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
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Signal = require(Shared.Util.Signal)

local Net = require(script.Parent.Net)

local EventService = {}

EventService.Changed = Signal.new() :: Signal.Signal<{ string }>

local activeIds: { string } = {}
local activeKey = ""

local function compute(): ({ string }, string)
	local ids = {}
	for _, event in Config.GetActiveEvents(os.time()) do
		table.insert(ids, event.Id)
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

function EventService.Init()
	Workspace:SetAttribute("ActiveEvents", "")
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
