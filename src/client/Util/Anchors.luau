--!strict
--[[
	Anchors (v2.3): station positions that are always on the client, even when the station
	itself has streamed out. Written by the server's StreamingService as attributes on
	ReplicatedStorage.WorldAnchors.<Tag> (Count = n, P1..Pn = Vector3). Non-spatial folders always
	replicate, so these are present no matter where the player is.

	API
	  Anchors.Get(tag) -> { Vector3 }               every published position (may be empty)
	  Anchors.Nearest(tag, from?) -> Vector3?       closest published position
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Anchors = {}

Anchors.FOLDER = "WorldAnchors"

function Anchors.Get(tag: string): { Vector3 }
	local list: { Vector3 } = {}
	local root = ReplicatedStorage:FindFirstChild(Anchors.FOLDER)
	local holder = if root then root:FindFirstChild(tag) else nil
	if not holder then
		return list
	end
	local count = holder:GetAttribute("Count")
	if typeof(count) ~= "number" then
		return list
	end
	for i = 1, count do
		local value = holder:GetAttribute("P" .. i)
		if typeof(value) == "Vector3" then
			table.insert(list, value)
		end
	end
	return list
end

function Anchors.Nearest(tag: string, from: Vector3?): Vector3?
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, position in Anchors.Get(tag) do
		local distance = if from then (position - from).Magnitude else 0
		if distance < bestDistance then
			best = position
			bestDistance = distance
		end
	end
	return best
end

return Anchors
