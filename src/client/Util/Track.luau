--!strict
--[[
	Track — fire-and-forget client UI analytics ("Track" remote -> server Analytics.OnTrack,
	which whitelists names/arguments and rate-limits; see docs/ANALYTICS.md).
		Track.Send("panel_opened", "Shop")
		Track.Send("purchase_prompted", "GamePass", "AutoDig")
		Track.Send("menu_unlocked", "Eggs")
	A small client-side budget keeps a stuck UI loop from spamming the remote.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Track = {}

local BUDGET = 6 -- events per WINDOW seconds (server allows 8 per 5 s)
local WINDOW = 5
local windowStart = 0
local used = 0

function Track.Send(name: string, a: string?, b: string?)
	local now = os.clock()
	if now - windowStart >= WINDOW then
		windowStart = now
		used = 0
	end
	if used >= BUDGET then
		return
	end
	used += 1
	task.spawn(function()
		pcall(function()
			Remotes.Get("Track"):FireServer(name, a, b)
		end)
	end)
end

return Track
