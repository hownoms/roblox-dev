--!strict
-- Plays Config.Sounds by key (skips entries whose Id is ""), honours the SFX / Music settings.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local State = require(script.Parent.State)

local SoundController = {}

local folder: Folder? = nil
local cache: { [string]: Sound } = {}
local currentMusic: string? = nil
local musicSound: Sound? = nil
local wantedMusic = "MusicBeach"

local function getFolder(): Folder
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "ClientSounds"
		f.Parent = SoundService
		folder = f
	end
	return folder :: Folder
end

local function getSound(name: string): Sound?
	local def = Config.Sounds[name]
	if not def or def.Id == "" then
		return nil
	end
	local sound = cache[name]
	if not sound then
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = def.Id
		s.Volume = def.Volume
		s.PlaybackSpeed = def.PlaybackSpeed
		s.Looped = def.Looped
		s.Parent = getFolder()
		cache[name] = s
		sound = s
	end
	return sound
end

-- pitch: multiplier on the configured PlaybackSpeed (adds variety to repeated sounds).
function SoundController.Play(name: string, pitch: number?, volume: number?)
	if State.GetSetting("SFX", true) == false then
		return
	end
	local sound = getSound(name)
	if sound then
		local def = Config.Sounds[name]
		sound.PlaybackSpeed = def.PlaybackSpeed * (pitch or 1)
		sound.Volume = def.Volume * (volume or 1)
		SoundService:PlayLocalSound(sound)
	end
end

local function refreshMusic()
	local enabled = State.GetSetting("Music", true) ~= false
	local target = if enabled then wantedMusic else nil
	if target == currentMusic then
		return
	end
	if musicSound then
		musicSound:Stop()
	end
	currentMusic = target
	musicSound = nil
	if target then
		local sound = getSound(target)
		if sound then
			musicSound = sound
			sound:Play()
		end
	end
end

-- "MusicBeach" near the surface, "MusicDeep" underground (LayerController decides).
function SoundController.SetMusic(name: string)
	wantedMusic = name
	refreshMusic()
end

function SoundController.Init()
	State.Changed("Settings"):Connect(refreshMusic)
	refreshMusic()
end

return SoundController
