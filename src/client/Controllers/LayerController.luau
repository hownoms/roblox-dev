--!strict
--[[
	LayerController — tracks how deep the local character is (studs below the beach surface),
	fires DepthChanged / LayerEntered, shows the layer-enter banner and tints the world toward
	the layer's AmbientColor while underground via our OWN client-side ColorCorrectionEffect
	"DepthTint" in Lighting. The server owns WorldAtmosphere/WorldColorCorrection/WorldBloom
	(Golden Hour / High Tide) and Lighting properties, so we never touch those. Swaps music.
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local State = require(script.Parent.State)
local SoundController = require(script.Parent.SoundController)
local Signal = require(script.Parent.Parent.Util.Signal)
local Character = require(script.Parent.Parent.Util.Character)

local LayerController = {}

LayerController.Depth = 0
LayerController.LayerIndex = 1
LayerController.DepthChanged = Signal.new() -- (depth, layerIndex)
LayerController.LayerEntered = Signal.new() -- (layerIndex, isNew)

local UPDATE_INTERVAL = 0.15
local BANNER_COOLDOWN = 12 -- don't re-announce the same layer within this many seconds
local FULL_TINT_DEPTH = 14 -- studs underground at which the tint reaches full strength

local colorCorrection: ColorCorrectionEffect? = nil
local lastTintKey = ""
local lastAnnounced: { [number]: number } = {}
local newLayerShown: { [number]: boolean } = {}
local bannerCallback: ((number, boolean) -> ())? = nil

-- UI registers how to show the banner (keeps Controllers free of UI requires).
function LayerController.SetBannerCallback(fn: (number, boolean) -> ())
	bannerCallback = fn
end

local function getColorCorrection(): ColorCorrectionEffect
	if colorCorrection and colorCorrection.Parent then
		return colorCorrection
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "DepthTint"
	cc.Parent = Lighting
	colorCorrection = cc
	return cc
end

local function applyTint(depth: number, layerIndex: number)
	local strength = math.clamp((depth - 2) / FULL_TINT_DEPTH, 0, 1)
	local key = layerIndex .. ":" .. math.floor(strength * 8)
	if key == lastTintKey then
		return
	end
	lastTintKey = key
	local layer = Config.Layers[layerIndex]
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local cc = getColorCorrection()
	local tint = Color3.new(1, 1, 1):Lerp(layer.AmbientColor, 0.55 * strength)
	TweenService:Create(cc, info, {
		TintColor = tint,
		Saturation = 0.08 * strength,
		Contrast = 0.06 * strength,
		Brightness = -0.05 * strength,
	}):Play()
	SoundController.SetMusic(if depth > 20 then "MusicDeep" else "MusicBeach")
	SoundController.SetAmbience(depth <= 20)
end

-- Called by DigController when the server says this dig reached a never-seen layer.
function LayerController.AnnounceNewLayer(layerIndex: number)
	if newLayerShown[layerIndex] then
		return
	end
	newLayerShown[layerIndex] = true
	lastAnnounced[layerIndex] = os.clock()
	LayerController.LayerEntered:Fire(layerIndex, true)
	if bannerCallback then
		bannerCallback(layerIndex, true)
	end
end

local function update()
	local root = Character.GetRoot()
	if not root then
		return
	end
	local feetY = (root :: BasePart).Position.Y - 3
	local depth = math.max(0, State.SurfaceY() - feetY)
	-- Like the server (BeachService), depth only counts inside the dig zone: the beach slopes
	-- down to the ocean, which must not read as "underground". Unknown zone -> 0 as well.
	local cf = State.GetDigZone()
	if not cf or not State.InDigZone((root :: BasePart).Position, 2) then
		depth = 0
	end
	local index = Config.GetLayerIndexAtDepth(depth)
	local changed = math.abs(depth - LayerController.Depth) > 0.05 or index ~= LayerController.LayerIndex
	local previous = LayerController.LayerIndex
	LayerController.Depth = depth
	LayerController.LayerIndex = index
	if changed then
		LayerController.DepthChanged:Fire(depth, index)
	end
	if index ~= previous and depth > 1 then
		local last = lastAnnounced[index]
		if not last or os.clock() - last > BANNER_COOLDOWN then
			lastAnnounced[index] = os.clock()
			LayerController.LayerEntered:Fire(index, false)
			if bannerCallback and index > 1 then
				bannerCallback(index, false)
			end
		end
	end
	applyTint(depth, index)
end

function LayerController.Init()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= UPDATE_INTERVAL then
			acc = 0
			update()
		end
	end)
end

return LayerController
