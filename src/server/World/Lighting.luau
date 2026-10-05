--!strict
--[[
	Lighting — sunny cartoon look (Atmosphere, Sky, ColorCorrection, Bloom, SunRays) and
	the visual side of timed events:
	  HighTide   -> a translucent "tide sheet" floods the lower beach, bigger waves, deeper water.
	  GoldenHour -> ClockTime 17.8, warm tint and haze.
	Driven by World.ApplyEvent(ids) and by the workspace attribute "ActiveEvents"
	(comma-separated event ids, set by the server).

	Exposure budget (playtest: "anything that glows / white gets hard to see"): Future lighting
	+ pale sand + white parts blew out. Values below keep the sand mid-bright: low exposure,
	low environment diffuse/specular, no atmosphere glare, and a high bloom threshold so only
	genuinely emissive Neon blooms (and only softly). Golden Hour dims instead of brightening.

	Effects are named "World*" so the client depth-tint controller can add its own instances
	(or tweak these) without fighting the server.
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Layout = require(script.Parent.Layout)
local Util = require(script.Parent.Util)

local rgb = Color3.fromRGB
local S = Layout.SURFACE_Y

local LightingBuilder = {}

local BASE = {
	ClockTime = 14,
	Brightness = 2,
	Exposure = -0.3,
	Tint = Color3.new(1, 1, 1),
	Saturation = 0.15,
	AtmosphereColor = rgb(190, 222, 245),
	AtmosphereDecay = rgb(110, 170, 215),
	AtmosphereHaze = 0.4,
	BloomIntensity = 0.22,
	WaterColor = rgb(24, 178, 226),
	WaveSize = 0.3,
}
local GOLDEN = {
	ClockTime = 17.8,
	Brightness = 1.6,
	Exposure = -0.4,
	Tint = rgb(255, 236, 214),
	Saturation = 0.2,
	AtmosphereColor = rgb(240, 196, 160),
	AtmosphereDecay = rgb(220, 135, 100),
	AtmosphereHaze = 1.1,
	BloomIntensity = 0.28,
}
local HIGH_TIDE = {
	WaterColor = rgb(14, 140, 214),
	WaveSize = 0.65,
	SheetY = S - 0.6, -- floods the flat beach up to just below the plot frames
}
local TIDE_LOW_Y = Layout.WATER_Y - 1.5

local atmosphere: Atmosphere? = nil
local colorCorrection: ColorCorrectionEffect? = nil
local bloom: BloomEffect? = nil
local tideSheet: Part? = nil
local current = { HighTide = false, GoldenHour = false }

local function getOrCreate(className: string, name: string, parent: Instance): Instance
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

local function tween(inst: Instance, seconds: number, goals: { [string]: any })
	TweenService:Create(inst, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), goals):Play()
end

function LightingBuilder.Build(parent: Instance)
	pcall(function()
		(Lighting :: any).Technology = Enum.Technology.Future
	end)
	Lighting.ClockTime = BASE.ClockTime
	Lighting.Brightness = BASE.Brightness
	Lighting.GeographicLatitude = 23
	Lighting.Ambient = rgb(95, 95, 110)
	Lighting.OutdoorAmbient = rgb(128, 128, 142)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	Lighting.ExposureCompensation = BASE.Exposure

	local atm = getOrCreate("Atmosphere", "WorldAtmosphere", Lighting) :: Atmosphere
	atm.Density = 0.24
	atm.Offset = 0.15
	atm.Color = BASE.AtmosphereColor
	atm.Decay = BASE.AtmosphereDecay
	atm.Glare = 0 -- glare = a blinding halo around the sun
	atm.Haze = BASE.AtmosphereHaze
	atmosphere = atm

	local sky = getOrCreate("Sky", "WorldSky", Lighting) :: Sky
	sky.SunAngularSize = 11
	sky.MoonAngularSize = 9
	sky.StarCount = 1500

	local cc = getOrCreate("ColorCorrectionEffect", "WorldColorCorrection", Lighting) :: ColorCorrectionEffect
	cc.Brightness = -0.02
	cc.Contrast = 0.04
	cc.Saturation = BASE.Saturation
	cc.TintColor = BASE.Tint
	colorCorrection = cc

	local bl = getOrCreate("BloomEffect", "WorldBloom", Lighting) :: BloomEffect
	bl.Intensity = BASE.BloomIntensity
	bl.Size = 12
	bl.Threshold = 2.4 -- only true emitters bloom; lit white plastic / sand never does
	bloom = bl

	local rays = getOrCreate("SunRaysEffect", "WorldSunRays", Lighting) :: SunRaysEffect
	rays.Intensity = 0.025
	rays.Spread = 0.7

	-- High-tide sheet over the lower beach and shallows (invisible when the tide is low).
	local zTop = -Layout.ROW_FAR - 3
	local zBottom = Layout.BOUND_SOUTH_Z - 40
	tideSheet = Util.Part({
		Name = "TideSheet",
		Size = Vector3.new(Layout.TERRAIN_HALF_X * 2, 0.4, zTop - zBottom),
		CFrame = CFrame.new(0, TIDE_LOW_Y, (zTop + zBottom) / 2),
		Color = rgb(70, 196, 240),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 1,
		Reflectance = 0.15,
		Decor = true,
		Parent = parent,
	})

	-- React to the server's event attribute.
	local function fromAttribute()
		local raw = Workspace:GetAttribute("ActiveEvents")
		local ids = {}
		if typeof(raw) == "string" then
			for id in string.gmatch(raw, "[^,%s]+") do
				table.insert(ids, id)
			end
		end
		LightingBuilder.ApplyEvent(ids)
	end
	Workspace:GetAttributeChangedSignal("ActiveEvents"):Connect(fromAttribute)
	fromAttribute()
end

function LightingBuilder.ApplyEvent(eventIds: { string })
	local golden = table.find(eventIds, "GoldenHour") ~= nil
	local high = table.find(eventIds, "HighTide") ~= nil
	local t = 4

	if golden ~= current.GoldenHour then
		current.GoldenHour = golden
		local g = if golden then GOLDEN else BASE
		tween(
			Lighting,
			t * 2,
			{ ClockTime = g.ClockTime, Brightness = g.Brightness, ExposureCompensation = g.Exposure }
		)
		if colorCorrection then
			tween(colorCorrection, t * 2, { TintColor = g.Tint, Saturation = g.Saturation })
		end
		if atmosphere then
			tween(atmosphere, t * 2, { Color = g.AtmosphereColor, Decay = g.AtmosphereDecay, Haze = g.AtmosphereHaze })
		end
		if bloom then
			tween(bloom, t * 2, { Intensity = g.BloomIntensity })
		end
	end

	if high ~= current.HighTide then
		current.HighTide = high
		local terrain = Workspace.Terrain
		tween(terrain, t, {
			WaterColor = if high then HIGH_TIDE.WaterColor else BASE.WaterColor,
			WaterWaveSize = if high then HIGH_TIDE.WaveSize else BASE.WaveSize,
		})
		local sheet = tideSheet
		if sheet then
			local cf = sheet.CFrame
			local y = if high then HIGH_TIDE.SheetY else TIDE_LOW_Y
			tween(sheet, t, {
				CFrame = CFrame.new(cf.X, y, cf.Z),
				Transparency = if high then 0.45 else 1,
			})
		end
	end
end

return LightingBuilder
