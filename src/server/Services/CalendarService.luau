--!strict
--[[
	CalendarService — the content calendar's world side (Config/Calendar.luau, owner guide
	docs/CALENDAR.md). Which drops run comes from EventService (a drop is an event, so live
	config's events_off / bonus_event already steer it); this service only reacts:

	  - Pop-up egg stand: while a drop with a limited egg runs, a pedestal at Layout.SEASON_STAND
	    (tag "EggShop", attribute EggId, prompt "Hatch") holds that egg, with a LIMITED label.
	  - Decoration swap: every bunting "Pennant" under Workspace.Map takes the drop's palette, and
	    a Snow drop covers the boardwalk "Deck" planks in snow. Originals are kept in attributes
	    ("CalendarColor" / "CalendarMaterial") and restored when the drop ends. A few themed props
	    stand round the egg stand. When drops overlap (New Year inside Winter Beach) the later
	    drop in Drops sets the palette; snow stays while any running drop has Snow.
	  - Fireworks: while the "Fireworks" event runs, bursts over the sea every FIREWORK_INTERVAL.
	  - Advent: while Calendar.Advent.Drop runs, a player's first Shovel / Auto dig of each UTC day
	    digs up a present (Config.GetAdventReward), once per day (PlayerData.Calendar.AdventDay).

	Workspace attribute "SeasonTheme" = the theme in use ("" when none), for clients and tests.

	Public API (tests / dev):
		CalendarService.Refresh()                 re-apply the world for the current active drops
		CalendarService.GetTheme(): string?
		CalendarService.TryAdvent(player): boolean   grants today's present if due (true = granted)
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Models = require(Shared.Models)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local EventService = require(script.Parent.EventService)
local Net = require(script.Parent.Net)
local RewardsService = require(script.Parent.RewardsService)
local ServerSignals = require(script.Parent.ServerSignals)
local Layout = require(script.Parent.Parent.World.Layout)
local Util = require(script.Parent.Parent.World.Util)

local CalendarConfig = require(Shared.Config.Calendar)
local Calendar = Config.Calendar
local Schedule = Config.Schedule

type Drop = CalendarConfig.Drop

local CalendarService = {}

local FIREWORK_INTERVAL = 1.2
local FIREWORK_EVENT = "Fireworks"
local ADVENT_SOURCES: { [string]: boolean } = { Shovel = true, Auto = true }
local WHITE = Color3.fromRGB(255, 255, 255)
local SNOW = Color3.fromRGB(240, 246, 252)

local theme: string? = nil
local snowOn = false
local standEgg: string? = nil
local standModel: Model? = nil

local function activeDrops(): { Drop }
	local list = {}
	for _, drop in Calendar.Drops do
		if EventService.IsActive(drop.Id) then
			table.insert(list, drop)
		end
	end
	return list
end

local function mapFolder(): Instance?
	return Workspace:FindFirstChild("Map")
end

-- Recolours every descendant named `name` under Map, remembering the original look once.
local function restyle(name: string, color: ((number) -> Color3)?, material: Enum.Material?)
	local map = mapFolder()
	if not map then
		return
	end
	local i = 0
	for _, d in map:GetDescendants() do
		if d.Name == name and d:IsA("BasePart") then
			i += 1
			if d:GetAttribute("CalendarColor") == nil then
				d:SetAttribute("CalendarColor", d.Color)
				d:SetAttribute("CalendarMaterial", d.Material.Name)
			end
			if color then
				d.Color = color(i)
				d.Material = material or d.Material
			else
				local original = d:GetAttribute("CalendarColor")
				local originalMaterial = d:GetAttribute("CalendarMaterial")
				if typeof(original) == "Color3" then
					d.Color = original
				end
				if type(originalMaterial) == "string" then
					local ok, enumItem = pcall(function(): any
						return (Enum.Material :: any)[originalMaterial]
					end)
					if ok and enumItem then
						d.Material = enumItem
					end
				end
			end
		end
	end
end

-- Pop-up egg stand ------------------------------------------------------------------------------

local function propsFor(drop: Drop, parent: Model, centre: Vector3)
	-- six small themed props on a ring round the stand: palette balls / cones, no collisions
	local palette = drop.Palette
	for k = 1, 6 do
		local a = math.rad(30 + (k - 1) * 60)
		local pos = centre + Vector3.new(math.sin(a) * 6.5, 0, math.cos(a) * 6.5)
		local color = palette[(k - 1) % #palette + 1]
		local base = pos + Vector3.new(0, Layout.VISIBLE_SURFACE_OFFSET, 0)
		if drop.Theme == "Winter" then
			-- snowmen
			Util.Ball(parent, "Snowman", base + Vector3.new(0, 1.1, 0), 2.2, SNOW, Enum.Material.Snow)
			Util.Ball(parent, "Snowman", base + Vector3.new(0, 2.7, 0), 1.5, SNOW, Enum.Material.Snow)
			Util.Ball(parent, "SnowmanNose", base + Vector3.new(0, 2.7, -0.75), 0.35, Color3.fromRGB(255, 140, 40))
		elseif drop.Theme == "Lunar" then
			-- hanging lanterns on short posts
			Util.Cylinder(
				parent,
				"LanternPost",
				base + Vector3.new(0, 1.5, 0),
				3,
				0.3,
				Color3.fromRGB(90, 50, 30),
				nil,
				true
			)
			local lantern = Util.Ball(parent, "Lantern", base + Vector3.new(0, 3.4, 0), 1.4, color, Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 8
			light.Brightness = 0.8
			light.Parent = lantern
		elseif drop.Theme == "Spring" or drop.Theme == "Lucky" then
			-- giant painted eggs / clover pots
			local egg =
				Util.Ball(parent, "SeasonProp", base + Vector3.new(0, 1.1, 0), 2, color, Enum.Material.SmoothPlastic)
			egg.Size = Vector3.new(1.6, 2.2, 1.6)
		else
			-- Harvest pumpkins / New Year party balls
			Util.Ball(parent, "SeasonProp", base + Vector3.new(0, 0.9, 0), 1.8, color, Enum.Material.SmoothPlastic)
			Util.Cylinder(
				parent,
				"SeasonPropStem",
				base + Vector3.new(0, 2, 0),
				0.6,
				0.3,
				Color3.fromRGB(80, 140, 50),
				nil,
				true
			)
		end
	end
end

local function removeStand()
	if standModel then
		standModel:Destroy()
		standModel = nil
	end
	standEgg = nil
end

local function buildStand(drop: Drop, egg: Types.EggDef)
	removeStand()
	local map = mapFolder() or Workspace
	local m = Util.Model("SeasonEggStand", map)
	local centre = Layout.SEASON_STAND
	local top = centre + Vector3.new(0, Layout.VISIBLE_SURFACE_OFFSET, 0)
	local pedestal = Util.Cylinder(m, "EggPedestal_" .. egg.Id, top + Vector3.new(0, 1, 0), 2, 4.4, WHITE)
	pedestal:SetAttribute("EggId", egg.Id)
	Util.Tag(pedestal, "EggShop")
	local prompt = Util.Prompt(pedestal, "Hatch", egg.Name .. " (limited)", 10)
	prompt:SetAttribute("EggId", egg.Id)
	Util.Cylinder(m, "Ring", top + Vector3.new(0, 2.05, 0), 0.3, 4.8, egg.Look.ShellColor, Enum.Material.Neon, true)
	local ok, result = pcall(Models.Egg, egg.Id)
	if ok and typeof(result) == "Instance" and result:IsA("Model") then
		local eggModel = result :: Model
		Util.Finish(eggModel, true)
		eggModel:PivotTo(CFrame.new(top + Vector3.new(0, 4, 0)))
		eggModel.Parent = m
	else
		warn("[CalendarService] Models.Egg failed for", egg.Id, result)
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "EggInfo"
	bb.Size = UDim2.fromScale(8, 2.4)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	bb.MaxDistance = 60
	bb.LightInfluence = 0
	bb.Adornee = pedestal
	bb.Parent = pedestal
	Util.Label(
		bb,
		"LIMITED: " .. string.upper(egg.Name),
		egg.Look.ShellColor,
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 0.55)
	)
	Util.Label(bb, drop.Name .. " only!", WHITE, UDim2.fromScale(0, 0.55), UDim2.fromScale(1, 0.45))
	propsFor(drop, m, centre)
	Util.Finish(m, false)
	standModel = m
	standEgg = egg.Id
end

-- Apply ------------------------------------------------------------------------------------------

function CalendarService.Refresh()
	local drops = activeDrops()
	local paletteDrop: Drop? = nil
	local eggDrop: Drop? = nil
	local wantSnow = false
	for _, drop in drops do
		paletteDrop = drop -- the later drop in date order wins (New Year inside Winter Beach)
		if drop.Egg then
			eggDrop = drop
		end
		wantSnow = wantSnow or drop.Snow == true
	end
	local wantTheme = if paletteDrop then paletteDrop.Theme else nil
	if wantTheme ~= theme then
		theme = wantTheme
		local pd = paletteDrop
		if pd then
			local palette = pd.Palette
			restyle("Pennant", function(i: number): Color3
				return palette[(i - 1) % #palette + 1]
			end)
		else
			restyle("Pennant", nil)
		end
		Workspace:SetAttribute("SeasonTheme", theme or "")
	end
	if wantSnow ~= snowOn then
		snowOn = wantSnow
		if wantSnow then
			restyle("Deck", function(): Color3
				return SNOW
			end, Enum.Material.Snow)
		else
			restyle("Deck", nil)
		end
	end
	local ed = eggDrop
	local wantEgg = if ed then ed.Egg else nil
	if wantEgg ~= standEgg then
		local egg = if wantEgg then Config.GetEgg(wantEgg) else nil
		if ed and egg then
			buildStand(ed, egg)
		else
			removeStand()
		end
	end
end

function CalendarService.GetTheme(): string?
	return theme
end

-- Fireworks --------------------------------------------------------------------------------------

local fireworkRng = Random.new()

local function burst()
	local folder = mapFolder() or Workspace
	local S = Config.SURFACE_Y
	local pos = Vector3.new(
		fireworkRng:NextNumber(-90, 90),
		S + fireworkRng:NextNumber(55, 95),
		fireworkRng:NextNumber(-190, -120)
	)
	local palette = {
		Color3.fromRGB(255, 215, 80),
		Color3.fromRGB(200, 140, 255),
		Color3.fromRGB(120, 220, 255),
		Color3.fromRGB(255, 110, 150),
	}
	local color = palette[fireworkRng:NextInteger(1, #palette)]
	local core = Util.Part({
		Name = "Firework",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.5, 1.5, 1.5),
		CFrame = CFrame.new(pos),
		Color = color,
		Material = Enum.Material.Neon,
		Decor = true,
		Parent = folder,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Speed = NumberRange.new(25, 40)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(1, 1.6)
	emitter.Size = NumberSequence.new(1.2, 0)
	emitter.Drag = 3
	emitter.Rate = 0
	emitter.Parent = core
	emitter:Emit(60)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 40
	light.Brightness = 3
	light.Parent = core
	Debris:AddItem(core, 2.5)
end

-- Advent -----------------------------------------------------------------------------------------

function CalendarService.TryAdvent(player: Player): boolean
	if not EventService.IsActive(Calendar.Advent.Drop) then
		return false
	end
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local now = os.time()
	local today = Schedule.Day(now)
	local state = data.Calendar
	if type(state) ~= "table" then
		return false
	end
	if state.AdventDay == today then
		return false
	end
	state.AdventDay = today
	DataService.MarkDirty(player, "Calendar")
	local reward, day = Config.GetAdventReward(now)
	Net.Notify(player, "Event", string.format("ADVENT GIFT! Day %d: you dug up a present!", day + 1))
	RewardsService.Grant(player, reward, "Advent")
	return true
end

-- Lifecycle --------------------------------------------------------------------------------------

local function safeRefresh()
	local err = Util.Try(CalendarService.Refresh)
	if err then
		warn("[CalendarService] refresh failed: " .. tostring(err))
	end
end

function CalendarService.Init()
	Workspace:SetAttribute("SeasonTheme", "")
	EventService.Changed:Connect(safeRefresh)
	ServerSignals.Dug:Connect(function(player: Player, _depth: number, _sand: number, source: string)
		if ADVENT_SOURCES[source] then
			CalendarService.TryAdvent(player)
		end
	end)
end

function CalendarService.Start()
	safeRefresh()
	task.spawn(function()
		while true do
			task.wait(FIREWORK_INTERVAL)
			if EventService.IsActive(FIREWORK_EVENT) then
				pcall(burst)
			end
		end
	end)
end

return CalendarService
