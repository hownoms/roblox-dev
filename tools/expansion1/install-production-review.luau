--[[
	PRODUCTION-INTEGRATION REVIEW installer: paste into the Roblox Studio command bar in EDIT mode
	(docs/integration/production-review.md). Needs tools/expansion1/inject-production-review.py
	running on this machine. Not a game script; never mapped by any project file.

	Fetches every source first (a fetch failure leaves the place untouched), moves any existing
	install roots (e.g. ReplicatedStorage.Shared) to ServerStorage.PreProductionReviewBackup, then
	creates the review tree with production Main DISABLED. One undo waypoint (Ctrl+Z reverts).
	Sources are set through .Source from the command bar's plugin context; no loadstring.
]]
local PORT = 34873
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")
local TAG = "[ReviewInstall]"

assert(not RunService:IsRunning(), TAG .. " stop Play first: install into the Edit DataModel")
if game.PlaceId ~= 0 then
	warn(TAG .. " PlaceId is " .. game.PlaceId .. ": the review boot will REFUSE to run in a published place")
end

local base = "http://127.0.0.1:" .. PORT
local wasHttp = HttpService.HttpEnabled
pcall(function()
	HttpService.HttpEnabled = true
end)
local function get(route)
	return HttpService:GetAsync(base .. route, true)
end
local fetched, result = pcall(function()
	local manifest = HttpService:JSONDecode(get("/manifest.json"))
	local sources = {}
	for _, entry in manifest.entries do
		if entry.source then
			sources[entry.source] = get("/source/" .. entry.source)
		end
	end
	return { Manifest = manifest, Sources = sources }
end)
pcall(function()
	HttpService.HttpEnabled = wasHttp
end)
if not fetched then
	error(TAG .. " could not fetch from " .. base .. " (is the injector running? HTTP allowed?): " .. tostring(result))
end
local manifest, sources = result.Manifest, result.Sources

local function resolve(path, last)
	local node = game:GetService(path[1])
	for i = 2, last do
		local child = node:FindFirstChild(path[i])
		assert(child, TAG .. " missing container " .. table.concat(path, ".", 1, i))
		node = child
	end
	return node
end

local recording = ChangeHistoryService:TryBeginRecording("Install production-integration review")
local ok, err = pcall(function()
	local backup = ServerStorage:FindFirstChild("PreProductionReviewBackup")
	if not backup then
		backup = Instance.new("Folder")
		backup.Name = "PreProductionReviewBackup"
		backup.Parent = ServerStorage
	end
	local stamp = os.date("!%Y%m%dT%H%M%S")
	for _, root in manifest.roots do
		local parent = resolve(root, #root - 1)
		local name = root[#root]
		local existing = parent:FindFirstChild(name)
		while existing do
			existing.Name = name .. "_" .. stamp
			existing.Parent = backup
			print(
				TAG
					.. " backed up "
					.. table.concat(root, ".")
					.. " -> ServerStorage.PreProductionReviewBackup."
					.. existing.Name
			)
			existing = parent:FindFirstChild(name)
		end
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
		inst.Parent = resolve(path, #path - 1)
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
print(
	string.format(
		"%s installed %d instances from %s @ %s; production Main enabled = %s (must be false). Press Play.",
		TAG,
		#manifest.entries,
		manifest.project,
		tostring(manifest.commit),
		tostring(main.Enabled)
	)
)
for _, item in manifest.ignoredServiceProperties do
	print(
		TAG
			.. " not applied (place keeps its own): "
			.. table.concat(item.path, ".")
			.. " "
			.. HttpService:JSONEncode(item.properties)
	)
end
