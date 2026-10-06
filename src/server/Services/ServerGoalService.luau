--!strict
--[[
	ServerGoalService — a server-wide co-op dig goal (v2.2 SOCIAL, Status & Social agent).
	"Server dig goal: 12.4K / 50K sand": every player's dug sand (ServerSignals.Dug, any source:
	shovel, pets, ride) counts. When the bar fills, Config.Social.ServerGoal.EventId (Golden
	Hour) starts early on this server for EventSeconds (EventService.StartEarly) and everyone gets
	an "Announce" banner. Counting pauses while that event runs plus CooldownSeconds, then a new
	round starts from 0.

	Target: Config.ServerGoalTarget(MaxDepth of every loaded player): scales with the player count
	and with how deep the server is. Recomputed on join / leave and every few seconds while
	counting (progress is never reset mid-round).

	Replicated state (Workspace attributes, the client draws the bar from these):
		"ServerGoalProgress"  number  sand dug this round (floored)
		"ServerGoalTarget"    number  sand needed
		"ServerGoalResumeAt"  number  unix time counting resumes (0 while counting)

	Public API:
		ServerGoalService.Add(sand)        count sand (DigService path calls this via ServerSignals)
		ServerGoalService.GetState(): { Progress, Target, ResumeAt, Completed }
		ServerGoalService.Recompute()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local EventService = require(script.Parent.EventService)
local Net = require(script.Parent.Net)
local ServerSignals = require(script.Parent.ServerSignals)

local GOAL = Config.Social.ServerGoal
local PUBLISH_INTERVAL = 1 -- seconds between attribute updates (dig spam is coalesced)

local ServerGoalService = {}

local progress = 0
local target = GOAL.MinSand
local resumeAt = 0
local completed = 0 -- goals reached on this server
local dirty = false

local function publish()
	dirty = false
	Workspace:SetAttribute("ServerGoalProgress", math.floor(progress))
	Workspace:SetAttribute("ServerGoalTarget", target)
	Workspace:SetAttribute("ServerGoalResumeAt", resumeAt)
end

function ServerGoalService.Recompute()
	local depths = {}
	for _, player in DataService.GetLoadedPlayers() do
		local data = DataService.Get(player)
		if data then
			table.insert(depths, data.MaxDepth)
		end
	end
	local newTarget = Config.ServerGoalTarget(depths)
	if newTarget ~= target then
		target = newTarget
		dirty = true
	end
end

local function reached()
	completed += 1
	local def = Config.GetEvent(GOAL.EventId)
	EventService.StartEarly(GOAL.EventId, GOAL.EventSeconds)
	resumeAt = os.time() + EventService.GetSecondsLeft(GOAL.EventId) + GOAL.CooldownSeconds
	local eventName = if def then string.upper(def.Name) else "BONUS"
	Net.NotifyAll(
		"Announce",
		string.format(
			"SERVER GOAL REACHED! %s sand dug together: %s for everyone!",
			Format.Abbreviate(target),
			eventName
		)
	)
	progress = 0
	publish()
end

function ServerGoalService.Add(sand: number)
	if type(sand) ~= "number" or sand ~= sand or sand <= 0 or sand == math.huge then
		return
	end
	if resumeAt > 0 then
		if os.time() < resumeAt then
			return -- the reward event is running / cooling down
		end
		resumeAt = 0
		ServerGoalService.Recompute()
	end
	progress += sand
	dirty = true
	if progress >= target then
		reached()
	end
end

function ServerGoalService.GetState(): { Progress: number, Target: number, ResumeAt: number, Completed: number }
	return { Progress = progress, Target = target, ResumeAt = resumeAt, Completed = completed }
end

function ServerGoalService.Init()
	publish()
	ServerSignals.Dug:Connect(function(_player: Player, _depth: number, gained: number, _source: string)
		ServerGoalService.Add(gained)
	end)
end

function ServerGoalService.Start()
	DataService.PlayerLoaded:Connect(function()
		ServerGoalService.Recompute()
		publish()
	end)
	task.spawn(function()
		local sinceRecompute = 0
		while true do
			task.wait(PUBLISH_INTERVAL)
			sinceRecompute += PUBLISH_INTERVAL
			if sinceRecompute >= 10 then
				sinceRecompute = 0
				ServerGoalService.Recompute()
			end
			if resumeAt > 0 and os.time() >= resumeAt then
				resumeAt = 0
				ServerGoalService.Recompute()
				dirty = true
			end
			if dirty then
				publish()
			end
			if resumeAt == 0 and progress >= target then
				reached() -- a player left and the target dropped below the progress
			end
		end
	end)
end

function ServerGoalService.OnPlayerRemoving(_player: Player)
	-- DataService still lists the leaving player; recompute once they are gone.
	task.delay(1, function()
		ServerGoalService.Recompute()
	end)
end

return ServerGoalService
