--!strict
--[[
	Events — server-wide timed events, deterministic from os.time() so every server agrees
	without messaging. Schedules (Config/Schedule.luau) combine a periodic part
	((os.time() + OffsetSeconds) % IntervalSeconds < DurationSeconds), a UTC date window
	(Starts / Ends), weekends only and a week rotation. Use Config.GetActiveEvents(now) to
	evaluate. The UI shows a countdown banner ("High Tide in 2:31!") — anticipation is half the
	fun and pulls players back online.

	Content calendar (Config/Calendar.luau, docs/CALENDAR.md): every drop is an event here (the
	drop marker, Kind "Season" when it has no modifier) and its modifiers carry Group = the drop
	id, so `events_off = "<drop id>"` stops the whole drop. Kinds "Hatch" (egg luck) and
	"Material" (find material luck) only exist on calendar events.
]]

local Calendar = require(script.Parent.Calendar)
local Types = require(script.Parent.Parent.Types)

local MINUTE = 60
local DAY = 86400

local dropById: { [string]: Calendar.Drop } = {}
for _, drop in Calendar.Drops do
	dropById[drop.Id] = drop
end
-- The date window of a drop (its Starts / Ends).
local function window(dropId: string): (number, number)
	local drop = dropById[dropId]
	assert(drop, "Events: unknown drop " .. dropId)
	return drop.Starts, drop.Ends
end
local harvestStarts, harvestEnds = window("HarvestDig")
local winterStarts, winterEnds = window("WinterBeach")
local newYearStarts, newYearEnds = window("NewYear")
local lunarStarts, lunarEnds = window("LunarLove")
local luckyStarts, luckyEnds = window("LuckyDig")
local springStarts, springEnds = window("SpringHatch")

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

	-- Content calendar drops (markers) and their modifiers ------------------------------------
	{
		Id = "HarvestDig",
		Name = "Harvest Dig",
		Description = "Harvest Dig is here! Hatch the limited Cornucopia Egg and dig up harvest treasures.",
		Kind = "Season",
		Multiplier = 1,
		Starts = harvestStarts,
		Ends = harvestEnds,
		Color = rgb(230, 130, 40),
	},
	{
		Id = "HarvestWeekend",
		Name = "Harvest Weekend",
		Description = "A bumper crop of sand! 1.5x Sand all weekend.",
		Kind = "Sand",
		Multiplier = 1.5,
		Starts = harvestStarts,
		Ends = harvestEnds,
		Weekend = true,
		Group = "HarvestDig",
		Color = rgb(240, 180, 60),
	},
	{
		Id = "WinterBeach",
		Name = "Winter Beach",
		Description = "Snow on the boardwalk! Limited Gift Egg, and a present hides in the sand every day.",
		Kind = "Season",
		Multiplier = 1,
		Starts = winterStarts,
		Ends = winterEnds,
		Color = rgb(150, 210, 255),
	},
	{
		Id = "FrozenTide",
		Name = "Frozen Tide",
		Description = "An icy tide churns up the beach. 2x Sand for everyone!",
		Kind = "Sand",
		Multiplier = 2,
		IntervalSeconds = 30 * MINUTE,
		DurationSeconds = 4 * MINUTE,
		OffsetSeconds = 25 * MINUTE, -- :05-:09 and :35-:39, clear of High Tide (:00 / :20 / :40, 3 min)
		Starts = winterStarts,
		Ends = winterEnds,
		Group = "WinterBeach",
		Color = rgb(170, 230, 255),
	},
	{
		Id = "NewYear",
		Name = "New Year",
		Description = "Happy New Year! 2x Luck for everyone until 3 January.",
		Kind = "Luck",
		Multiplier = 2,
		Starts = newYearStarts,
		Ends = newYearEnds,
		Color = rgb(255, 215, 80),
	},
	{
		Id = "Fireworks",
		Name = "Fireworks",
		Description = "Midnight fireworks over the sea! 2x Coins when you sell.",
		Kind = "Coins",
		Multiplier = 2,
		IntervalSeconds = DAY,
		DurationSeconds = 15 * MINUTE, -- 00:00 .. 00:15 UTC each night of New Year
		OffsetSeconds = 0,
		Starts = newYearStarts,
		Ends = newYearEnds,
		Group = "NewYear",
		Color = rgb(200, 140, 255),
	},
	{
		Id = "LunarLove",
		Name = "Lanterns & Hearts",
		Description = "Lunar New Year and Valentine's! Limited Lantern Egg and heart treasures in the sand.",
		Kind = "Season",
		Multiplier = 1,
		Starts = lunarStarts,
		Ends = lunarEnds,
		Color = rgb(230, 50, 70),
	},
	{
		Id = "LanternNight",
		Name = "Lantern Night",
		Description = "Lanterns light up the beach. 2x Coins when you sell!",
		Kind = "Coins",
		Multiplier = 2,
		IntervalSeconds = 30 * MINUTE,
		DurationSeconds = 5 * MINUTE,
		OffsetSeconds = 5 * MINUTE, -- :25 and :55 past the hour
		Starts = lunarStarts,
		Ends = lunarEnds,
		Group = "LunarLove",
		Color = rgb(255, 190, 60),
	},
	{
		Id = "LuckyDig",
		Name = "Lucky Dig",
		Description = "Lucky Dig! Limited Clover Egg, and 2x odds of Golden, Crystal and Fossilized finds.",
		Kind = "Material",
		Multiplier = 2,
		Starts = luckyStarts,
		Ends = luckyEnds,
		Color = rgb(60, 190, 80),
	},
	{
		Id = "SpringHatch",
		Name = "Spring Hatch",
		Description = "Spring Hatch! Limited Pastel Egg, 1.5x egg luck and painted eggs hidden in the first layers.",
		Kind = "Hatch",
		Multiplier = 1.5,
		Starts = springStarts,
		Ends = springEnds,
		Color = rgb(255, 170, 210),
	},

	-- Weekend Dig Fest: one of four, every weekend, picked by week number (Schedule.WeekIndex % 4)
	{
		Id = "FestSand",
		Name = "Sand Fest",
		Description = "Weekend Dig Fest: 1.5x Sand all weekend!",
		Kind = "Sand",
		Multiplier = 1.5,
		Weekend = true,
		WeekCycle = 4,
		WeekSlot = 0,
		Group = Calendar.WEEKEND_FEST_GROUP,
		Color = rgb(255, 200, 90),
	},
	{
		Id = "FestLuck",
		Name = "Luck Fest",
		Description = "Weekend Dig Fest: 1.5x Luck all weekend!",
		Kind = "Luck",
		Multiplier = 1.5,
		Weekend = true,
		WeekCycle = 4,
		WeekSlot = 1,
		Group = Calendar.WEEKEND_FEST_GROUP,
		Color = rgb(90, 200, 255),
	},
	{
		Id = "FestCoins",
		Name = "Coin Fest",
		Description = "Weekend Dig Fest: 1.5x Coins when you sell, all weekend!",
		Kind = "Coins",
		Multiplier = 1.5,
		Weekend = true,
		WeekCycle = 4,
		WeekSlot = 2,
		Group = Calendar.WEEKEND_FEST_GROUP,
		Color = rgb(255, 170, 50),
	},
	{
		-- Hatching is instant, so the "hatch speed" weekend gives egg luck instead.
		Id = "FestHatch",
		Name = "Hatch Fest",
		Description = "Weekend Dig Fest: 1.5x egg luck all weekend!",
		Kind = "Hatch",
		Multiplier = 1.5,
		Weekend = true,
		WeekCycle = 4,
		WeekSlot = 3,
		Group = Calendar.WEEKEND_FEST_GROUP,
		Color = rgb(255, 140, 200),
	},
}

return Events
