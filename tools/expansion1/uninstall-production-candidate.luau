--[[
	Reverses install-production-candidate.luau in the open Expansion1Review place (EDIT mode,
	command bar / plugin context). Removes every candidate root (CandidateInstalled attribute),
	returns each parked instance to its OriginalPath and restores the recorded service properties.
	One undo waypoint.
]]
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")
local TAG = "[CandidateUninstall]"

assert(not RunService:IsRunning(), TAG .. " stop Play first")
local backup = ServerStorage:FindFirstChild("PreProductionCandidateBackup")
assert(backup, TAG .. " no candidate installed")

local removed, restored, props = {}, {}, {}
local recording = ChangeHistoryService:TryBeginRecording("Uninstall local production candidate")
local ok, err = pcall(function()
	for _, service in { "ReplicatedStorage", "ServerScriptService", "StarterPlayer" } do
		for _, d in game:GetService(service):GetDescendants() do
			if d:GetAttribute("CandidateInstalled") ~= nil and d.Parent then
				table.insert(removed, d:GetFullName())
				d:Destroy()
			end
		end
	end
	for _, item in backup:GetChildren() do
		local path = string.split(item:GetAttribute("OriginalPath") or "", "/")
		local node = game:GetService(path[1])
		for i = 2, #path - 1 do
			node = node:FindFirstChild(path[i])
		end
		item:SetAttribute("OriginalPath", nil)
		item.Parent = node
		table.insert(restored, item:GetFullName())
	end
	for key, value in backup:GetAttributes() do
		local parts = string.split(key, "_")
		if parts[1] == "Prop" then
			local property = parts[#parts]
			local service = game:GetService(parts[2])
			for i = 3, #parts - 1 do
				service = service:FindFirstChild(parts[i])
			end
			local current = service[property]
			if typeof(current) == "EnumItem" then
				service[property] = (Enum :: any)[tostring(current.EnumType)][value]
			else
				service[property] = value
			end
			table.insert(props, service.Name .. "." .. property .. "=" .. tostring(value))
		end
	end
	backup:Destroy()
end)
if recording then
	ChangeHistoryService:FinishRecording(
		recording,
		if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
	)
end
if not ok then
	error(TAG .. " failed (changes cancelled): " .. tostring(err))
end
print(TAG .. " removed: " .. table.concat(removed, ", "))
print(TAG .. " restored: " .. table.concat(restored, ", "))
print(TAG .. " properties: " .. table.concat(props, ", "))
return { Removed = removed, Restored = restored, Properties = props }
