--!strict
--[[
	Events — server-wide timed events, deterministic from os.time() so every server agrees
	without messaging: active while (os.time() + OffsetSeconds) % IntervalSeconds < DurationSeconds.
	Use Config.GetActiveEvents(now) to evaluate. The UI should show a countdown banner
	("High Tide in 2:31!") — anticipation is half the fun and pulls players back online.
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Events: { Types.EventDef } = {
	{
		Id = "HighTide",
		Name = "High Tide",
		Description = "The tide washes treasure into the sand! 2x Luck for everyone.",
		Kind = "Luck",
		Multiplier = 2,
		IntervalSeconds = 20 * 60,
		DurationSeconds = 3 * 60,
		OffsetSeconds = 0,
		Color = rgb(50, 170, 255),
	},
	{
		Id = "GoldenHour",
		Name = "Golden Hour",
		Description = "The sunset makes everything shine. 2x Coins when you sell!",
		Kind = "Coins",
		Multiplier = 2,
		IntervalSeconds = 45 * 60,
		DurationSeconds = 5 * 60,
		OffsetSeconds = 10 * 60,
		Color = rgb(255, 160, 40),
	},
}

return Events
