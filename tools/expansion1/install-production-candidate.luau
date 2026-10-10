--[[
	LOCAL PRODUCTION CANDIDATE installer: run in the Roblox Studio command bar (plugin context) in
	EDIT mode, with tools/expansion1/inject-production-candidate.py running
	(docs/integration/production-candidate.md). Not a game script; never mapped by any project.

	Refuses unless the open place is the unpublished Expansion1Review file (PlaceId 0, GameId 0,
	name Expansion1Review.rbxlx) and Play is stopped. Fetches every source first (a failed fetch
	leaves the place untouched), then in one undo waypoint:
	  * parks the dedicated review boots (AdventureReview, ExpansionReview, ...) and any existing
	    install roots in ServerStorage.PreProductionCandidateBackup, each tagged with its original
	    path (OriginalPath attribute); nothing is deleted;
	  * applies the production Workspace / SoundService / Lighting properties, recording the old
	    values on the backup folder;
	  * creates the candidate tree: production Server (Main enabled, exactly as default.project.json
	    maps it), Shared, Client, ProductionCandidate.CandidateConfig and the client label.
	tools/expansion1/uninstall-production-candidate.luau reverses all of it.
]]
local PORT = 34874
local PLACE = "Expansion1Review.rbxlx"
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")
local TAG = "[CandidateInstall]"
local BACKUP = "PreProductionCandidateBackup"

assert(not RunService:IsRunning(), TAG .. " stop Play first: install into the Edit DataModel")
assert(game.PlaceId == 0 and game.GameId == 0, TAG .. " refused: this place is published (PlaceId/GameId not 0)")
assert(game.Name == PLACE, TAG .. " refused: open place is " .. game.Name .. ", only " .. PLACE .. " is authorized")
assert(not ServerStorage:FindFirstChild(BACKUP), TAG .. " a candidate is already installed: uninstall it first")

local base = "http://127.0.0.1:" .. PORT
local wasHttp = HttpService.HttpEnabled
pcall(function()
	HttpService.HttpEnabled = true
end)
local fetched, result = pcall(function()
	local manifest = HttpService:JSONDecode(HttpService:GetAsync(base .. "/manifest.json", true))
	local sources = {}
	for _, entry in manifest.entries do
		if entry.source then
			sources[entry.source] = HttpService:GetAsync(base .. "/source/" .. entry.source, true)
		end
	end
	return { Manifest = manifest, Sources = sources }
end)
pcall(function()
	HttpService.HttpEnabled = wasHttp
end)
if not fetched then
	error(TAG .. " could not fetch from " .. base .. ": " .. tostring(result))
end
local manifest, sources = result.Manifest, result.Sources

local function find(path, last)
	local node = game:GetService(path[1])
	for i = 2, last do
		node = node and node:FindFirstChild(path[i])
	end
	return node
end

local recording = ChangeHistoryService:TryBeginRecording("Install local production candidate")
local parked, applied = {}, {}
local ok, err = pcall(function()
	local backup = Instance.new("Folder")
	backup.Name = BACKUP
	backup:SetAttribute("CandidateCommit", manifest.commit)
	backup:SetAttribute("InstalledAt", os.date("!%Y-%m-%dT%H:%M:%SZ"))
	backup.Parent = ServerStorage
	local function park(path)
		local existing = find(path, #path)
		while existing do
			existing:SetAttribute("OriginalPath", table.concat(path, "/"))
			existing.Parent = backup
			table.insert(parked, table.concat(path, "."))
			existing = find(path, #path)
		end
	end
	for _, path in manifest.park do
		park(path)
	end
	for _, root in manifest.roots do
		park(root)
	end
	for _, item in manifest.serviceProperties do
		local service = find(item.path, #item.path)
		for key, value in item.properties do
			local okRead, old = pcall(function()
				return service[key]
			end)
			if okRead then
				local stored = if typeof(old) == "EnumItem" then old.Name else old
				backup:SetAttribute("Prop_" .. table.concat(item.path, "_") .. "_" .. key, stored)
			end
			local okSet, setErr = pcall(function()
				service[key] = value
			end)
			table.insert(applied, table.concat(item.path, ".") .. "." .. key .. (if okSet then "" else " FAILED " .. tostring(setErr)))
		end
	end
	local rootSet = {}
	for _, root in manifest.roots do
		rootSet[table.concat(root, "/")] = true
	end
	for _, entry in manifest.entries do
		local path = entry.path
		local inst = Instance.new(entry.class)
		inst.Name = path[#path]
		if entry.source then
			inst.Source = sources[entry.source]
		end
		for key, value in entry.properties do
			if key == "Disabled" then
				inst.Enabled = not value
			else
				inst[key] = value
			end
		end
		for key, value in entry.attributes do
			inst:SetAttribute(key, value)
		end
		if rootSet[table.concat(path, "/")] then
			inst:SetAttribute("CandidateInstalled", manifest.commit)
		end
		inst.Parent = find(path, #path - 1)
	end
end)
if recording then
	ChangeHistoryService:FinishRecording(
		recording,
		if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
	)
end
if not ok then
	error(TAG .. " install failed (changes cancelled): " .. tostring(err))
end
local main = game:GetService("ServerScriptService").Server.Main
print(string.format("%s installed %d instances from %s @ %s", TAG, #manifest.entries, manifest.project, manifest.commit))
print(TAG .. " production Main enabled = " .. tostring(main.Enabled) .. " (expected true)")
print(TAG .. " parked: " .. (if #parked > 0 then table.concat(parked, ", ") else "(none)"))
print(TAG .. " service properties: " .. table.concat(applied, ", "))
return {
	Commit = manifest.commit,
	Instances = #manifest.entries,
	Parked = parked,
	Applied = applied,
	MainEnabled = main.Enabled,
}
