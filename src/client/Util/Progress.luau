--!strict
-- Derived progress for quests / daily rewards / rebirth, mirroring the server rules in Config.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

local Progress = {}

function Progress.Now(): number
	return Workspace:GetServerTimeNow()
end

function Progress.Today(): number
	return math.floor(Progress.Now() // 86400)
end

-- (progress, claimed) for a quest, applying the daily reset rule client-side.
function Progress.Quest(quest: Types.QuestDef, data: Types.PlayerData): (number, boolean)
	local entry = data.Quests and data.Quests[quest.Id]
	local progress = 0
	local claimed = false
	if entry then
		if quest.Reset == "Daily" and entry.Day ~= nil and entry.Day ~= Progress.Today() then
			progress = 0
			claimed = false
		else
			progress = entry.Progress or 0
			claimed = entry.Claimed == true
		end
	end
	if quest.Kind == "ReachDepth" then
		progress = math.max(progress, data.MaxDepth or 0)
	elseif quest.Kind == "Rebirth" and quest.Reset == "Once" then
		progress = math.max(progress, data.Rebirths or 0)
	end
	return math.min(progress, quest.Target), claimed
end

function Progress.ClaimableQuests(data: Types.PlayerData): number
	local count = 0
	for _, quest in Config.Quests do
		local progress, claimed = Progress.Quest(quest, data)
		if not claimed and progress >= quest.Target then
			count += 1
		end
	end
	return count
end

function Progress.SecondsToDailyReset(): number
	local now = Progress.Now()
	return 86400 - (now % 86400)
end

export type DailyStatus = {
	CanClaim: boolean,
	NextIn: number, -- seconds until claimable (0 if now)
	NextStreak: number, -- DailyStreak after the next claim
	NextDay: number, -- 1..#DailyRewards reward index of the next claim
	ClaimedThroughDay: number, -- days already claimed in the current 7-day cycle
	Broken: boolean,
}

function Progress.Daily(data: Types.PlayerData): DailyStatus
	local now = Progress.Now()
	local last = data.LastDailyClaim or 0
	local streak = data.DailyStreak or 0
	local elapsed = now - last
	local canClaim = last == 0 or elapsed >= Config.DAILY_COOLDOWN_SECONDS
	local broken = last ~= 0 and elapsed > Config.DAILY_STREAK_GRACE_SECONDS
	local nextStreak = if broken then 1 else streak + 1
	local cycle = #Config.DailyRewards
	local nextDay = ((nextStreak - 1) % cycle) + 1
	return {
		CanClaim = canClaim,
		NextIn = if canClaim then 0 else Config.DAILY_COOLDOWN_SECONDS - elapsed,
		NextStreak = nextStreak,
		NextDay = nextDay,
		ClaimedThroughDay = nextDay - 1,
		Broken = broken,
	}
end

function Progress.CanRebirth(data: Types.PlayerData): boolean
	return (data.Coins or 0) >= Config.RebirthCost(data.Rebirths or 0)
end

return Progress
