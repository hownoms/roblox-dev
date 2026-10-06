--!strict
--[[
	Sounds — SOUND_IDS. Only `rbxasset://` built-ins (shipped with every Roblox client) are used;
	"" means "not set yet": skip playing it. To upgrade, upload or pick licensed audio from the
	Creator Store and paste "rbxassetid://<id>" here. Never paste ids we don't have rights to.
	Built-ins below exist in the client content folder; verify by ear in Studio.
	(swoosh.wav was removed: Studio reports it "not approved for the requester".)
]]

local Types = require(script.Parent.Parent.Types)

local function sound(id: string, volume: number, speed: number?, looped: boolean?): Types.SoundDef
	return {
		Id = id,
		Volume = volume,
		PlaybackSpeed = speed or 1,
		Looped = looped or false,
	}
end

local Sounds: { [string]: Types.SoundDef } = {
	Dig = sound("rbxasset://sounds/action_footsteps_plastic.mp3", 0.6, 0.8),
	DigBlocked = sound("rbxasset://sounds/clickfast.wav", 0.5, 0.6),
	Sell = sound("rbxasset://sounds/electronicpingshort.wav", 0.7, 1.2),
	Coin = sound("rbxasset://sounds/electronicpingshort.wav", 0.5, 1.6),
	Treasure = sound("rbxasset://sounds/electronicpingshort.wav", 0.8, 0.9),
	RareTreasure = sound("rbxasset://sounds/electronicpingshort.wav", 1, 0.7),
	Purchase = sound("rbxasset://sounds/electronicpingshort.wav", 0.8, 1.4),
	Error = sound("rbxasset://sounds/clickfast.wav", 0.6, 0.5),
	Click = sound("rbxasset://sounds/clickfast.wav", 0.5, 1),
	Whoosh = sound("rbxasset://sounds/action_jump.mp3", 0.5, 1.2),
	EggShake = sound("rbxasset://sounds/clickfast.wav", 0.5, 0.8),
	Hatch = sound("rbxasset://sounds/electronicpingshort.wav", 0.8, 0.8),
	NewLayer = sound("rbxasset://sounds/electronicpingshort.wav", 0.9, 0.6),
	Rebirth = sound("rbxasset://sounds/electronicpingshort.wav", 1, 0.5),
	Splash = sound("rbxasset://sounds/impact_water.mp3", 0.7, 1),
	Teleport = sound("rbxasset://sounds/action_jump.mp3", 0.6, 1.4),
	-- v3 discovery (detector beep, excavation taps, find stings)
	DetectorBeep = sound("rbxasset://sounds/electronicpingshort.wav", 0.35, 2.2),
	ExcavateHit = sound("rbxasset://sounds/clickfast.wav", 0.7, 1.3),
	ExcavatePerfect = sound("rbxasset://sounds/electronicpingshort.wav", 0.7, 1.8),
	FindEmerge = sound("rbxasset://sounds/action_footsteps_plastic.mp3", 0.9, 0.55),
	-- Placeholders: paste licensed rbxassetid:// ids (music is not shipped as a built-in).
	MusicBeach = sound("", 0.3, 1, true),
	MusicDeep = sound("", 0.3, 1, true),
	Ambience = sound("", 0.25, 1, true),
}

return Sounds
