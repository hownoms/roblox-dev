--!strict
--[[
	Heat — the soft survival meter (owner: Survival). See docs/design/Survival.md.

	The server (SurvivalService) ticks every player's heat every TickSeconds:
	  underground (Depth >= UndergroundDepth)  -> falls UndergroundFallPerSecond
	  under any placed shade                   -> falls ShadeFallPerSecond x best shade Cooling
	  on the hot sand in the sun               -> rises SunRisePerSecond x event multiplier
	                                              + DigRisePerDig per dig (max DigRiseMaxPerSecond)
	  anywhere else (boardwalk, hub, the sea)  -> falls OffSandFallPerSecond
	At SunburntAt the player is Sunburnt (dig cooldown x SunburntCooldownMultiplier) until heat
	falls to RecoverAt. Never damage, never death.

	Tuning targets (fresh player, toy shovel at 2 digs/s, full sun, no shade / drinks):
	  0.45/s sun + 2 x 0.12/s digging = 0.69/s  ->  100 heat in ~145 s (~2.4 min) of digging,
	  ~220 s standing still. Fountain water (-70) fixes Sunburnt instantly; a Beach Umbrella
	  takes 100 -> 40 in 20 s. New players get NewPlayerGraceSeconds of total play time with no
	  heat gain (the FTUE stays heat-free until the first umbrella is nearly affordable).
]]
local Types = require(script.Parent.Parent.Types)

local Heat: Types.HeatConfig = {
	Max = 100,
	TickSeconds = 0.25,

	SunRisePerSecond = 0.45,
	DigRisePerDig = 0.12,
	DigRiseMaxPerSecond = 0.3,

	ShadeFallPerSecond = 3,
	UndergroundDepth = 12,
	UndergroundFallPerSecond = 2.5,
	OffSandFallPerSecond = 1.5,

	WarningAt = 75,
	SunburntAt = 100,
	RecoverAt = 40,
	SunburntCooldownMultiplier = 1.6,
	NewPlayerGraceSeconds = 180,

	-- Golden Hour: the low sun is hotter. High Tide: a cool sea breeze.
	EventSunMultipliers = {
		GoldenHour = 1.35,
		HighTide = 0.6,
	},

	FountainCooldownSeconds = 3,
	ConsumableMaxStack = 99,
	ConsumableBoostCapSeconds = 300,

	ShadeSlots = 1,
	ShadeSlotsVip = 2,
	ShadePlaceRange = 30,
	ShadeMinSpacing = 4,
	ShadeHubClearance = 10,
}

return Heat
