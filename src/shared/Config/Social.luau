--!strict
--[[
	Social — tuning for status & social features (v2.2, Status & Social agent):
	nameplates, rare-find announcements, leaderboard scopes and the server dig goal.
	Read-only at runtime.
]]

export type SocialConfig = {
	Nameplate: {
		MaxDistance: number, -- studs; BillboardGui.MaxDistance
		StarsInline: number, -- up to this many rebirths show as "★★★", above it "★x12"
	},
	Announce: {
		Duration: number, -- seconds each banner stays on screen
		Gap: number, -- seconds between two banners (rate limit)
		MaxQueued: number, -- older queued announcements are dropped beyond this
	},
	Leaderboard: {
		CycleSeconds: number, -- each board flips scope this often
		WeeklyPrefix: { Coins: string, Depth: string }, -- + "_W<ISO year>_<ISO week>"
		WriteBackoffMax: number, -- seconds; a failing store is skipped for up to this long
	},
	-- Goal = round_up(max(MinSand, sum over players of max(PerPlayerSand,
	--        RewardScale(layer at the player's MaxDepth) * DigSeconds)), Round).
	-- So it grows with the player count AND with how deep the server is (a late-game digger
	-- earns ~1000x more sand per dig than a beginner, so a flat number would be trivial or
	-- impossible). Recomputed while counting; progress never resets mid-round.
	ServerGoal: {
		MinSand: number,
		PerPlayerSand: number, -- a beginner's share (~10-15 min of Dry/Wet Sand digging)
		DigSeconds: number, -- seconds of "typical" income at each player's deepest layer
		Round: number, -- goal is rounded up to a multiple of this
		EventId: string, -- event started early for everyone when the goal is reached
		EventSeconds: number, -- how long that event runs
		CooldownSeconds: number, -- after the event ends, wait this long before counting again
	},
}

local Social: SocialConfig = {
	Nameplate = {
		MaxDistance = 60,
		StarsInline = 5,
	},
	Announce = {
		Duration = 4,
		Gap = 0.6,
		MaxQueued = 4,
	},
	Leaderboard = {
		CycleSeconds = 10,
		WeeklyPrefix = { Coins = "Leaderboard_Sand", Depth = "Leaderboard_Depth" },
		WriteBackoffMax = 600,
	},
	ServerGoal = {
		MinSand = 5000,
		PerPlayerSand = 3000,
		DigSeconds = 480,
		Round = 1000,
		EventId = "GoldenHour",
		EventSeconds = 5 * 60,
		CooldownSeconds = 60,
	},
}

return Social
