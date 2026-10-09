--!strict
--[[
	Lighting — sunny cartoon look (Atmosphere, Sky, ColorCorrection, Bloom, SunRays) and
	the visual side of timed events:
	  HighTide   -> a translucent "tide sheet" floods the lower beach, bigger waves, deeper water.
	  GoldenHour -> ClockTime 17.6, warm sun, peach haze and clouds (night lights switch on).
	Driven by World.ApplyEvent(ids) and by the workspace attribute "ActiveEvents"
	(comma-separated event ids, set by the server).

	Exposure budget (playtest: "anything that glows / white gets hard to see"): Future lighting
	+ pale sand + white parts blew out. Values below keep the sand mid-bright: low exposure,
	low environment diffuse/specular, only a soft atmosphere glare, and a bloom threshold (2.0)
	above lit sand / white plastic so only emissive Neon blooms. Golden Hour dims instead of
	brightening. A Clouds object (WorldClouds, under Terrain) gives the sky some life.

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

-- Bright tropical day: warm sun, cool-blue shadows, a pale haze that desaturates the far
-- islands, soft bloom so Neon glows without lifting lit sand over the threshold.
local BASE = {
	ClockTime = 14,
	Brightness = 2,
	Exposure = -0.3,
	Tint = Color3.new(1, 1, 1),
	Saturation = 0.18,
	SunShift = rgb(255, 242, 222),
	AtmosphereColor = rgb(200, 222, 235),
	AtmosphereDecay = rgb(110, 170, 205),
	AtmosphereHaze = 1.2,
	AtmosphereGlare = 0.3,
	AtmosphereDensity = 0.27,
	CloudColor = rgb(255, 255, 255),
	BloomIntensity = 0.5,
	WaterColor = rgb(35, 175, 200), -- keep in sync with Terrain.ApplyColors
	WaveSize = 0.18,
}
-- Golden Hour: low warm sun, peach haze and clouds, lamps and the lighthouse switch on
-- (AmbientNightLight, ClockTime >= 17.3). Dims slightly rather than brightening.
local GOLDEN = {
	ClockTime = 17.6,
	Brightness = 1.7,
	Exposure = -0.3,
	Tint = rgb(255, 232, 206),
	Saturation = 0.26,
	SunShift = rgb(255, 196, 140),
	AtmosphereColor = rgb(246, 192, 152),
	AtmosphereDecay = rgb(214, 118, 96),
	AtmosphereHaze = 1.9,
	AtmosphereGlare = 0.7,
	AtmosphereDensity = 0.31,
	CloudColor = rgb(255, 208, 178),
	BloomIntensity = 0.65,
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
local clouds: Clouds? = nil
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
	Lighting.OutdoorAmbient = rgb(126, 132, 150) -- cool shadows against the warm sun
	Lighting.ColorShift_Top = BASE.SunShift
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	Lighting.ExposureCompensation = BASE.Exposure

	local atm = getOrCreate("Atmosphere", "WorldAtmosphere", Lighting) :: Atmosphere
	atm.Density = BASE.AtmosphereDensity
	atm.Offset = 0.18
	atm.Color = BASE.AtmosphereColor
	atm.Decay = BASE.AtmosphereDecay
	atm.Glare = BASE.AtmosphereGlare -- soft sun halo only (high glare = blinding)
	atm.Haze = BASE.AtmosphereHaze
	atmosphere = atm

	-- Fluffy fair-weather clouds (the Clouds object must live under Terrain).
	local cl = getOrCreate("Clouds", "WorldClouds", Workspace.Terrain) :: Clouds
	cl.Cover = 0.55
	cl.Density = 0.6
	cl.Color = BASE.CloudColor
	clouds = cl

	local sky = getOrCreate("Sky", "WorldSky", Lighting) :: Sky
	sky.SunAngularSize = 11
	sky.MoonAngularSize = 9
	sky.StarCount = 1500

	local cc = getOrCreate("ColorCorrectionEffect", "WorldColorCorrection", Lighting) :: ColorCorrectionEffect
	cc.Brightness = -0.01
	cc.Contrast = 0.08
	cc.Saturation = BASE.Saturation
	cc.TintColor = BASE.Tint
	colorCorrection = cc

	local bl = getOrCreate("BloomEffect", "WorldBloom", Lighting) :: BloomEffect
	bl.Intensity = BASE.BloomIntensity
	bl.Size = 24
	bl.Threshold = 2 -- Neon blooms; lit white plastic / sand stays under it
	bloom = bl

	local rays = getOrCreate("SunRaysEffect", "WorldSunRays", Lighting) :: SunRaysEffect
	rays.Intensity = 0.04
	rays.Spread = 0.7

	-- High-tide sheet over the lower beach and shallows (invisible when the tide is low).
	local zTop = -Layout.ROW_FAR - 3
	local zBottom = Layout.BOUND_SOUTH_Z - 40
	tideSheet = Util.Part({
		Name = "TideSheet",
		-- Ends just inside the headland cliffs (they start at |x| ~ 410).
		Size = Vector3.new((Layout.BOUND_HALF_X + 18) * 2, 0.4, zTop - zBottom),
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
		tween(Lighting, t * 2, {
			ClockTime = g.ClockTime,
			Brightness = g.Brightness,
			ExposureCompensation = g.Exposure,
			ColorShift_Top = g.SunShift,
		})
		if colorCorrection then
			tween(colorCorrection, t * 2, { TintColor = g.Tint, Saturation = g.Saturation })
		end
		if atmosphere then
			tween(atmosphere, t * 2, {
				Color = g.AtmosphereColor,
				Decay = g.AtmosphereDecay,
				Haze = g.AtmosphereHaze,
				Glare = g.AtmosphereGlare,
				Density = g.AtmosphereDensity,
			})
		end
		if clouds then
			tween(clouds, t * 2, { Color = g.CloudColor })
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
