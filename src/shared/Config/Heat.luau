--!strict
-- STUB (coordinator). Survival agent owns and tunes this file.
local Types = require(script.Parent.Parent.Types)

local Heat: Types.HeatConfig = {
	Max = 100,
	SunRisePerSecond = 1,
	DigRisePerDig = 0.3,
	ShadeFallPerSecond = 4,
	UndergroundDepth = 20,
	UndergroundFallPerSecond = 3,
	SunburntAt = 100,
	RecoverAt = 40,
	SunburntCooldownMultiplier = 2,
	NewPlayerGraceSeconds = 180,
}

return Heat
