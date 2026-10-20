--!strict
--[[
	Calendar — the dated content calendar (docs/SIX_MONTH_PLAN.md part C, owner guide
	docs/CALENDAR.md). Everything here switches on and off by UTC date from os.time(), so every
	server agrees and nothing needs a republish.

	A DROP is an event in Config/Events.luau whose id is listed here (Kind "Season" when it has no
	modifier of its own). While the drop's event is active (EventService / Workspace attribute
	"ActiveEvents"), its pieces are on:
	  Egg      a limited egg (Config/Eggs.luau, EggDef.Drop = the drop id), sold only then
	  Code     a code (Config/Codes.luau) with Starts / Expires on the drop's dates
	  Finds    limited treasures (Config/Treasures.luau, Seasonal = true) mixed into new
	           deposits: Chance = share of freshly seeded deposits in MinLayer..MaxLayer
	  Theme    beach decoration swap (CalendarService: bunting colours, snow, a pop-up egg stand)
	Its modifiers are separate events with Group = the drop id (Frozen Tide, Fireworks...).

	Live config overrides (no new switches, docs/LIVE_CONFIG.md):
	  events_off = "WinterBeach"   the whole drop: egg, finds, decor, advent and its events
	  events_off = "FrozenTide"    just that modifier
	  events_off = "WeekendFest" / "MonthlyMythic"   the weekend rotation / the monthly mythic
	  bonus_event = "WinterBeach"  runs a drop (egg, finds, decor) outside its dates, up to 7 days
	  codes_off = "SNOWDAY"        a drop's code

	TUNING: dates, chances, prices and pets are plain numbers here and in Eggs / Pets / Treasures;
	retune them once live data is in (the plan wanted ~2 weeks of numbers first).
]]

local Schedule = require(script.Parent.Schedule)
local Types = require(script.Parent.Parent.Types)

local utc = Schedule.Utc
local rgb = Color3.fromRGB

export type SeasonFind = {
	TreasureId: string,
	Chance: number, -- share of newly seeded deposits (0..1)
	MinLayer: number,
	MaxLayer: number,
}

export type Drop = {
	Id: string, -- the drop's event id in Config.Events
	Name: string,
	Starts: number, -- unix UTC, inclusive (00:00 of the first day)
	Ends: number, -- unix UTC, exclusive (00:00 of the day after the last day)
	Egg: string?, -- EggDef.Id (EggDef.Drop must name this drop)
	Code: string?, -- CodeDef.Code (Starts / Expires on these dates)
	Theme: string, -- CalendarService decoration theme
	Finds: { SeasonFind },
	Palette: { Color3 }, -- bunting / decoration colours
	Snow: boolean?, -- snow on the boardwalk deck
}

local Calendar = {}

-- Drops in date order. Ends = 00:00 UTC of the day AFTER the last day in the plan's table.
Calendar.Drops = {
	{
		Id = "HarvestDig",
		Name = "Harvest Dig",
		Starts = utc(2026, 11, 26),
		Ends = utc(2026, 12, 7),
		Egg = "cornucopia_egg",
		Code = "HARVEST",
		Theme = "Harvest",
		Finds = {
			{ TreasureId = "golden_acorn", Chance = 0.03, MinLayer = 1, MaxLayer = 15 },
			{ TreasureId = "prize_pumpkin", Chance = 0.01, MinLayer = 1, MaxLayer = 15 },
		},
		Palette = { rgb(230, 120, 40), rgb(200, 60, 40), rgb(240, 190, 60), rgb(140, 90, 50) },
	},
	{
		Id = "WinterBeach",
		Name = "Winter Beach",
		Starts = utc(2026, 12, 12),
		Ends = utc(2027, 1, 5),
		Egg = "gift_egg",
		Code = "SNOWDAY",
		Theme = "Winter",
		Finds = {
			{ TreasureId = "snow_globe", Chance = 0.03, MinLayer = 1, MaxLayer = 15 },
			{ TreasureId = "frozen_ornament", Chance = 0.01, MinLayer = 1, MaxLayer = 15 },
		},
		Palette = { rgb(240, 250, 255), rgb(120, 200, 255), rgb(220, 50, 60), rgb(60, 170, 90) },
		Snow = true,
	},
	{
		-- Inside Winter Beach: no egg of its own (the Gift Egg keeps running), 2x Luck all four
		-- days and Fireworks (2x Coins) for 15 minutes from every midnight UTC.
		Id = "NewYear",
		Name = "New Year",
		Starts = utc(2026, 12, 31),
		Ends = utc(2027, 1, 4),
		Code = "HAPPY2027",
		Theme = "NewYear",
		Finds = {},
		Palette = { rgb(255, 215, 80), rgb(250, 250, 255), rgb(170, 110, 255), rgb(40, 40, 70) },
	},
	{
		Id = "LunarLove",
		Name = "Lanterns & Hearts",
		Starts = utc(2027, 2, 6),
		Ends = utc(2027, 2, 21),
		Egg = "lantern_egg",
		Code = "LANTERN",
		Theme = "Lunar",
		Finds = {
			{ TreasureId = "candy_heart", Chance = 0.05, MinLayer = 1, MaxLayer = 15 },
			{ TreasureId = "ruby_heart", Chance = 0.012, MinLayer = 1, MaxLayer = 15 },
			{ TreasureId = "golden_lantern", Chance = 0.003, MinLayer = 1, MaxLayer = 15 },
		},
		Palette = { rgb(220, 30, 40), rgb(255, 200, 40), rgb(255, 120, 170), rgb(255, 240, 220) },
	},
	{
		Id = "LuckyDig",
		Name = "Lucky Dig",
		Starts = utc(2027, 3, 12),
		Ends = utc(2027, 3, 23),
		Egg = "clover_egg",
		Code = "LUCKYDIG",
		Theme = "Lucky",
		Finds = {
			{ TreasureId = "four_leaf_clover", Chance = 0.04, MinLayer = 1, MaxLayer = 15 },
			{ TreasureId = "pot_of_gold", Chance = 0.004, MinLayer = 1, MaxLayer = 15 },
		},
		Palette = { rgb(40, 170, 70), rgb(120, 220, 90), rgb(255, 210, 50), rgb(250, 250, 240) },
	},
	{
		Id = "SpringHatch",
		Name = "Spring Hatch",
		Starts = utc(2027, 3, 26),
		Ends = utc(2027, 4, 13),
		Egg = "pastel_egg",
		Code = "SPRING",
		Theme = "Spring",
		Finds = {
			-- egg hunt: hidden in the first five layers only
			{ TreasureId = "painted_egg", Chance = 0.06, MinLayer = 1, MaxLayer = 5 },
			{ TreasureId = "jeweled_egg", Chance = 0.015, MinLayer = 1, MaxLayer = 5 },
		},
		Palette = { rgb(255, 180, 210), rgb(170, 220, 255), rgb(200, 255, 180), rgb(255, 240, 160) },
	},
} :: { Drop }

-- Monthly mythic: one limited Mythic treasure in the whole dig zone, a new one every PeriodDays
-- from Epoch (a Monday). The list covers 8 x 28 days (~7 months), then repeats from the top.
-- Live config: events_off = "MonthlyMythic" stops it.
Calendar.MonthlyMythic = {
	Group = "MonthlyMythic",
	Epoch = utc(2026, 11, 2),
	PeriodDays = 28,
	Chance = 1 / 500, -- share of newly seeded deposits, any layer (Relics are 1 / 400)
	Treasures = {
		"harvest_moon_orb", -- from 2 Nov 2026
		"frostfire_crown", -- 30 Nov
		"starfall_shard", -- 28 Dec
		"dragon_pearl", -- 25 Jan 2027
		"emerald_tablet", -- 22 Feb
		"sunstone_egg", -- 22 Mar
		"abyssal_anchor", -- 19 Apr
		"comet_gem", -- 17 May
	} :: { string },
}

-- Weekend Dig Fest: events FestSand / FestLuck / FestCoins / FestHatch (Config/Events.luau,
-- Weekend = true, WeekCycle = 4, WeekSlot 0..3), one per weekend picked by Schedule.WeekIndex.
Calendar.WEEKEND_FEST_GROUP = "WeekendFest"

-- Advent: during the drop, the first dig of each UTC day digs up a present (CalendarService).
-- Day n of the drop (0 = first day) gives Special[n] if set, else Cycle[n % #Cycle + 1].
Calendar.Advent = {
	Drop = "WinterBeach",
	Cycle = {
		{ ScaledCoins = 200 },
		{ Boost = "LuckBoost", BoostSeconds = 600 },
		{ Egg = "gift_egg", EggCount = 1 },
		{ Boost = "SandBoost", BoostSeconds = 600 },
		{ ScaledCoins = 400 },
		{ Boost = "CoinBoost", BoostSeconds = 600 },
	} :: { Types.Reward },
	Special = {
		[13] = { Egg = "gift_egg", EggCount = 3, RebirthTokens = 1 }, -- 25 Dec
		[20] = { RebirthTokens = 1, ScaledCoins = 600 }, -- 1 Jan
	} :: { [number]: Types.Reward },
}

return Calendar
