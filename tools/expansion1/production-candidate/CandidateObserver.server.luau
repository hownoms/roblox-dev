--!strict
--[[
	LOCAL PRODUCTION CANDIDATE ONLY (docs/integration/production-candidate.md,
	docs/integration/launch-readiness.md). A committed, read-only acceptance observer for the
	two-client, streaming and rejoin checks, replacing ad-hoc probes injected during Play.
	Mapped only by expansion1-production-candidate.project.json as
	ServerScriptService.ProductionCandidate.CandidateObserver; never by default.project.json.

	It runs in the server's own module cache (unlike the Studio command bar), so it reads the
	same DataService / AdventureBoot state the game uses. It is inert unless the server resolved
	the fail-closed LocalOnly profile AND DataService reports StorageMode "LocalOnly".

	Read-only by construction: it never writes player data, never calls a grant, eligibility
	seeding, settlement, entry or storage function, creates no remote, fires nothing to clients
	and sets no attribute outside its own server-only folder. Eligibility is evaluated with the
	pure Rules on the loaded save (no side effects). tests/candidate-storage.spec.luau checks
	the source for forbidden calls and runs it against the real Main.

	Output (both readable from the Studio server DataModel with Studio MCP):
	  * ServerScriptService.ProductionCandidate attribute "Observation": JSON snapshot, refreshed
	    every second, plus "ObservationSeq" (increments per snapshot);
	  * "[CandidateObserver]" console lines for joins, loads, leaves, rejoins and every
	    AdventureOutcome payload (participant delivery evidence for the two-client run).
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local TAG = "[CandidateObserver]"
local folder = script.Parent

-- Wait for Main to resolve the profile (it publishes CandidateProfile before any service).
local deadline = os.clock() + 60
while ReplicatedStorage:GetAttribute("CandidateProfile") == nil and os.clock() < deadline do
	task.wait(0.25)
end
if ReplicatedStorage:GetAttribute("CandidateProfile") ~= "LocalOnly" then
	print(TAG .. " inert: profile is " .. tostring(ReplicatedStorage:GetAttribute("CandidateProfile")))
	return
end
local Services = ServerScriptService:WaitForChild("Server"):WaitForChild("Services")
local Profile = require(Services:WaitForChild("CandidateProfile")) :: any
local DataService = require(Services:WaitForChild("DataService")) :: any
if not Profile.IsLocalOnly() or DataService.StorageMode() ~= "LocalOnly" then
	print(TAG .. " inert: not a LocalOnly candidate (" .. tostring(DataService.StorageMode()) .. ")")
	return
end
local StorageGate = require(Services:WaitForChild("StorageGate")) :: any
local Boot = require(Services:WaitForChild("AdventureBoot")) :: any
local Eligibility = require(Services:WaitForChild("AdventureEligibility")) :: any
local Entry = require(Services:WaitForChild("AdventureEntry")) :: any
local Settlement = require(Services:WaitForChild("AdventureSettlement")) :: any

local started = os.clock()
local function stamp(): number
	return math.floor((os.clock() - started) * 10) / 10
end

-- Per-UserId history across leave/rejoin in this server (same-account rejoin evidence).
type History = {
	Name: string,
	Joins: number,
	Leaves: number,
	FirstLoad: { [string]: any }?,
	Last: { [string]: any }?, -- latest summary while loaded (DataService may unload before PlayerRemoving reaches us)
	LastLeave: { [string]: any }?,
	Outcomes: { { [string]: any } }, -- the latest MAX_OUTCOMES rows; Dropped counts older ones
	Dropped: number,
}
local MAX_OUTCOMES = 20
-- Attribute strings have a size limit; past this the snapshot leaves out outcome rows (the
-- console lines still carry every outcome) and says so.
local MAX_JSON = 100000
local history: { [number]: History } = {}

local function count(t: any): number
	local n = 0
	if type(t) == "table" then
		for _ in t do
			n += 1
		end
	end
	return n
end

-- A small copy of what matters for acceptance; never a reference into the live save.
local function summary(player: Player): { [string]: any }?
	if not DataService.IsLoaded(player) then
		return nil
	end
	local data = DataService.Get(player)
	if type(data) ~= "table" then
		return nil
	end
	local canEnter, enterWhy = Eligibility.Rules.CanEnter(data)
	local canTrial, trialWhy = Eligibility.Rules.CanTrial(data)
	return {
		Coins = data.Coins,
		Sand = data.Sand,
		EquippedShovel = data.EquippedShovel,
		Licensed = Eligibility.Rules.HasBroadwaveLicense(data),
		CanEnter = canEnter,
		EnterReason = enterWhy,
		CanTrial = canTrial,
		TrialReason = trialWhy,
		Certifications = count(data.Certifications),
		Trophies = count(data.TrophyRecords),
	}
end

local function character(player: Player): { [string]: any }
	local out: { [string]: any } = {}
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") then
		local p = root.Position
		out.Position = { math.floor(p.X), math.floor(p.Y), math.floor(p.Z) }
		out.InArena = Entry.InArena(p)
		out.InPocket = Entry.InPocket(p)
	end
	if humanoid then
		out.WalkSpeed = humanoid.WalkSpeed
	end
	local held = char and char:FindFirstChildOfClass("Tool")
	if held then
		out.Held = held.Name
		out.HeldToolId = held:GetAttribute("ToolId")
		out.HeldLoan = held:GetAttribute("AdventureLoan") == true
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tools = {}
	if backpack then
		for _, tool in backpack:GetChildren() do
			if tool:IsA("Tool") then
				table.insert(tools, tool.Name)
			end
		end
	end
	table.sort(tools)
	out.Backpack = tools
	return out
end

local function eventState(): { [string]: any }?
	local runtime = Boot.Runtime()
	if not runtime then
		return nil
	end
	local out: { [string]: any } = { Settled = runtime.Settled }
	local ok, event = pcall(function()
		return runtime.Event()
	end)
	if ok and event then
		out.InstanceId = event.EventInstanceId
		out.Phase = event.Phase
		out.Stage = event.Stage
		out.GateIndex = event.GateIndex
		local participants = {}
		for userId, p in event.Participants or {} do
			participants[tostring(userId)] = {
				Connected = p.Connected,
				Present = p.Present,
				Left = p.Left,
				Ready = p.Ready,
				Attached = p.Attached,
				Points = p.Points,
			}
		end
		out.Participants = participants
	end
	return out
end

local function streaming(): { [string]: any }
	local out: { [string]: any } = { StreamingEnabled = Workspace.StreamingEnabled }
	for _, key in { "StreamingMinRadius", "StreamingTargetRadius", "StreamingIntegrityMode", "StreamOutBehavior" } do
		local ok, value = pcall(function()
			return (Workspace :: any)[key]
		end)
		out[key] = if not ok then "unreadable" elseif typeof(value) == "EnumItem" then value.Name else value
	end
	local scene = Workspace:FindFirstChild("SpringVaultAdventure")
	out.SceneOnServer = scene ~= nil
	return out
end

local seq = 0
local function snapshot()
	local players = {}
	for _, player in Players:GetPlayers() do
		local h = history[player.UserId]
		local save = summary(player)
		if h and save then
			h.Last = save
		end
		players[tostring(player.UserId)] = {
			Name = player.Name,
			Joins = h and h.Joins or 0,
			Loaded = DataService.IsLoaded(player),
			Save = save,
			Character = character(player),
			Invited = Entry.WasInvited(player),
		}
	end
	local leftPlayers = {}
	for userId, h in history do
		if not Players:GetPlayerByUserId(userId) then
			leftPlayers[tostring(userId)] =
				{ Name = h.Name, Joins = h.Joins, Leaves = h.Leaves, LastLeave = h.LastLeave }
		end
	end
	local outcomes = {}
	for userId, h in history do
		outcomes[tostring(userId)] = { Rows = h.Outcomes, Dropped = h.Dropped }
	end
	seq += 1
	local body: { [string]: any } = {
		Seq = seq,
		At = stamp(),
		Commit = folder:GetAttribute("CandidateInstalled"),
		Profile = Profile.Mode(),
		StorageMode = DataService.StorageMode(),
		Storage = StorageGate.Counters(),
		Flags = Profile.Flags(),
		Streaming = streaming(),
		Event = eventState(),
		Players = players,
		Departed = leftPlayers,
		Outcomes = outcomes,
	}
	local ok, json = pcall(HttpService.JSONEncode, HttpService, body)
	if ok and #json > MAX_JSON then
		body.Outcomes = nil
		body.OutcomesOmitted = "snapshot too large; see [CandidateObserver] outcome lines"
		ok, json = pcall(HttpService.JSONEncode, HttpService, body)
	end
	if ok then
		folder:SetAttribute("Observation", json)
		folder:SetAttribute("ObservationSeq", seq)
	end
end

local function log(text: string)
	print(string.format("%s t=%.1f %s", TAG, stamp(), text))
end

local function onAdded(player: Player)
	local h = history[player.UserId]
	if not h then
		h = { Name = player.Name, Joins = 0, Leaves = 0, Outcomes = {}, Dropped = 0 }
		history[player.UserId] = h
	end
	h.Joins += 1
	log(string.format("join %s (%d) #%d%s", player.Name, player.UserId, h.Joins, if h.Joins > 1 then " REJOIN" else ""))
	task.spawn(function()
		local data = DataService.WaitForData(player, 30)
		if data and player.Parent then
			local s = summary(player)
			if h.FirstLoad == nil then
				h.FirstLoad = s
			end
			log(
				string.format(
					"loaded %s #%d coins=%s licensed=%s canEnter=%s/%s canTrial=%s/%s",
					player.Name,
					h.Joins,
					tostring(s and s.Coins),
					tostring(s and s.Licensed),
					tostring(s and s.CanEnter),
					tostring(s and s.EnterReason),
					tostring(s and s.CanTrial),
					tostring(s and s.TrialReason)
				)
			)
			if h.Joins > 1 and h.LastLeave and s then
				log(
					string.format(
						"rejoin check %s: coins %s -> %s, licensed %s -> %s, trophies %s -> %s",
						player.Name,
						tostring(h.LastLeave.Coins),
						tostring(s.Coins),
						tostring(h.LastLeave.Licensed),
						tostring(s.Licensed),
						tostring(h.LastLeave.Trophies),
						tostring(s.Trophies)
					)
				)
			end
		end
	end)
end

Players.PlayerAdded:Connect(onAdded)
for _, player in Players:GetPlayers() do
	onAdded(player)
end
Players.PlayerRemoving:Connect(function(player: Player)
	local h = history[player.UserId]
	if h then
		h.Leaves += 1
		h.LastLeave = summary(player) or h.Last
	end
	log(string.format("leave %s (%d)", player.Name, player.UserId))
end)
Settlement.OutcomeSent:Connect(function(player: Player, outcome: any)
	local h = history[player.UserId]
	local row = {
		At = stamp(),
		InstanceId = outcome.InstanceId,
		Kind = outcome.Kind,
		StageId = outcome.StageId,
		State = outcome.State,
		Status = outcome.Status,
		Storage = outcome.Storage,
		Coins = outcome.Coins,
		Reason = outcome.Reason,
		Trophy = outcome.Trophy,
		Certification = outcome.Certification,
	}
	if h then
		table.insert(h.Outcomes, row)
		if #h.Outcomes > MAX_OUTCOMES then
			table.remove(h.Outcomes, 1)
			h.Dropped += 1
		end
	end
	log(
		string.format(
			"outcome %s: %s %s %s/%s storage=%s coins=%s reason=%s",
			player.Name,
			tostring(outcome.Kind),
			tostring(outcome.StageId or ""),
			tostring(outcome.State),
			tostring(outcome.Status),
			tostring(outcome.Storage),
			tostring(outcome.Coins),
			tostring(outcome.Reason)
		)
	)
end)

log("active (LocalOnly; read-only)")
while true do
	local ok: boolean, err: any = pcall(snapshot)
	if not ok then
		log("snapshot failed: " .. tostring(err))
	end
	task.wait(1)
end
