--!strict
--[[
	PipQuest — q_pip's permanent reward (docs/integration/pip-quest-license.md). Completing Pip's
	Broadwave trial in the Spring Vault grants the saved ToolLicenses.tool_broadwave record, once.
	Owner instruction: q_pip completion grants the license (the bible puts it at cert_explorer).
	The bible's 150-coin first-clear q_pip reward is NOT implemented (owner decision).

	Started only by AdventureBoot, after SpringVaultService.Start succeeded, and only when the
	ordinary licensed Broadwave path is wired (AdventureFlags.BroadwaveOrdinary on and the bridge
	present). Otherwise it is never started and Pip's trial stays a demo that grants nothing.

	Server-validated: the trial lives in Codex's runtime (SpringVaultService, never edited here).
	Check(player) reads ONLY server state:
	  * runtime.ReviewPlayer(player).Trial: Wave == true, Cleared >= 3 and trial_target_1..3 all
	    cleared (Rules.TrialComplete);
	  * AdventureEligibility.CanTrial(player) (still owns a bought shovel);
	  * DataService.IsLoaded(player) and ordinary Broadwave still enabled.
	A runtime Intent from the client only schedules a deferred Check; its payload is never read.
	A 1-second poll over present players with an active trial is the safety net (e.g. a trial
	finished through runtime.Handle).

	Grant: DataService.Mutate(player, {"ToolLicenses"}) writes
	  ToolLicenses.tool_broadwave = { Source = "q_pip", ReceiptId = "quest:q_pip", At = os.time() }
	(Rules.Grant, idempotent: an existing record is a "Duplicate" and left untouched), then a
	spawned SaveAsync, BroadwaveLicense.Sync (the licensed tool is issued at once) and a toast.
	Nothing else in the save is touched (no shovels, coins, quests or certifications).
	The trial loan never confers ordinary rights: CanUseBroadwave accepts only server-issued
	licensed tools, never the loan, before and after the grant.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataService = require(script.Parent.DataService)
local Eligibility = require(script.Parent.AdventureEligibility)
local BroadwaveLicense = require(script.Parent.BroadwaveLicense)
local Net = require(script.Parent.Net)

local PipQuest = {}

PipQuest.QUEST_ID = "q_pip"
PipQuest.RECEIPT_ID = "quest:q_pip"
PipQuest.TARGETS = { "trial_target_1", "trial_target_2", "trial_target_3" }
PipQuest.POLL_INTERVAL = 1
PipQuest.GRANT_TEXT = "Pip: Broadwave license earned! It is yours to dig with on the beach."

local Rules = {}
PipQuest.Rules = Rules

-- A trial snapshot (runtime.ReviewPlayer(player).Trial) that finished: wave + all three targets.
function Rules.TrialComplete(trial: any): boolean
	if type(trial) ~= "table" or trial.Wave ~= true then
		return false
	end
	if type(trial.Cleared) ~= "number" or trial.Cleared < 3 or type(trial.Targets) ~= "table" then
		return false
	end
	for _, id in PipQuest.TARGETS do
		if trial.Targets[id] ~= true then
			return false
		end
	end
	return true
end

-- Pure: writes the license record into `data` unless one exists. Touches only ToolLicenses.
function Rules.Grant(data: any, now: number): (boolean, string)
	if type(data) ~= "table" then
		return false, "NotLoaded"
	end
	if Eligibility.Rules.HasBroadwaveLicense(data) then
		return false, "Duplicate"
	end
	if type(data.ToolLicenses) ~= "table" then
		data.ToolLicenses = {}
	end
	data.ToolLicenses[Eligibility.TOOL_ID] = {
		Source = PipQuest.QUEST_ID,
		ReceiptId = PipQuest.RECEIPT_ID,
		At = now,
	}
	return true, "Granted"
end

local running = false
local runtime: any = nil
local connections: { RBXScriptConnection } = {}
local accumulator = 0

local function review(player: Player): any
	local ok, result = pcall(runtime.ReviewPlayer, player)
	if ok and type(result) == "table" then
		return result.Trial
	end
	return nil
end

-- Grants when the server-side trial is complete. Returns (granted, reason).
function PipQuest.Check(player: Player): (boolean, string)
	if not running or not runtime then
		return false, "NotRunning"
	end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then
		return false, "NoPlayer"
	end
	if not Eligibility.IsOrdinaryEnabled() then
		return false, "Disabled"
	end
	if not DataService.IsLoaded(player) then
		return false, "NotLoaded"
	end
	if Eligibility.Rules.HasBroadwaveLicense(DataService.Get(player)) then
		return false, "Duplicate"
	end
	if not Rules.TrialComplete(review(player)) then
		return false, "Incomplete"
	end
	if not Eligibility.CanTrial(player) then
		return false, "NoShovelPurchase"
	end
	local granted, reason = false, "NotLoaded"
	DataService.Mutate(player, { "ToolLicenses" }, function(data)
		granted, reason = Rules.Grant(data, os.time())
	end)
	if not granted then
		return false, reason
	end
	task.spawn(DataService.SaveAsync, player)
	BroadwaveLicense.Sync(player)
	Net.Notify(player, "Success", PipQuest.GRANT_TEXT)
	return true, reason
end

local function safeCheck(player: Player)
	local ok, err = pcall(function(): boolean
		PipQuest.Check(player)
		return true
	end)
	if not ok then
		warn("[PipQuest] check failed: " .. tostring(err))
	end
end

local function poll()
	for _, player in Players:GetPlayers() do
		if review(player) ~= nil then
			safeCheck(player)
		end
	end
end

-- AdventureBoot only, after SpringVaultService.Start succeeded with the ordinary path wired.
function PipQuest.Start(runtimeHandle: any): boolean
	if running then
		return true
	end
	if type(runtimeHandle) ~= "table" or type(runtimeHandle.ReviewPlayer) ~= "function" then
		warn("[PipQuest] runtime has no ReviewPlayer; not started")
		return false
	end
	running = true
	runtime = runtimeHandle
	local folder = ReplicatedStorage:FindFirstChild("SpringVaultAdventure")
	local intent = folder and folder:FindFirstChild("Intent")
	if intent and intent:IsA("RemoteEvent") then
		-- The payload is never read: an intent only schedules a server-state check, after the
		-- runtime's own handler (connected first) has applied it.
		table.insert(
			connections,
			intent.OnServerEvent:Connect(function(player: Player)
				task.defer(function()
					if running then
						safeCheck(player)
					end
				end)
			end)
		)
	else
		warn("[PipQuest] runtime Intent remote missing; polling only")
	end
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			accumulator += dt
			if accumulator < PipQuest.POLL_INTERVAL then
				return
			end
			accumulator = 0
			poll()
		end)
	)
	return true
end

-- AdventureBoot.Disable. Granted licenses stay owned.
function PipQuest.Stop()
	running = false
	runtime = nil
	accumulator = 0
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
end

function PipQuest.IsRunning(): boolean
	return running
end

return PipQuest
