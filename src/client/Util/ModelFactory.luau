--!strict
-- Safe wrappers around Shared.Models: the Modeling area may still be in progress, so every
-- builder call is pcall'd and falls back to a simple coloured placeholder from Config.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Models = require(Shared:WaitForChild("Models"))

local ModelFactory = {}

local function placeholder(name: string, color: Color3, size: Vector3, shape: Enum.PartType?): Model
	local model = Instance.new("Model")
	model.Name = name
	local part = Instance.new("Part")
	part.Name = "Root"
	part.Anchored = true
	part.CanCollide = false
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	model.PrimaryPart = part
	return model
end

local function build(builder: (string) -> Model, id: string, fallback: () -> Model): Model
	local ok, result = pcall(builder, id)
	if ok and typeof(result) == "Instance" and result:IsA("Model") then
		return result
	end
	if not ok then
		warn("[ModelFactory] builder failed for", id, result)
	end
	return fallback()
end

-- Anchors everything, disables collisions/queries so client-side visuals never interfere.
function ModelFactory.MakeVisualOnly(model: Model, castShadow: boolean?)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = castShadow == true
			d.Massless = true
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
end

function ModelFactory.Shovel(id: string): Model
	return build(Models.Shovel, id, function()
		local def = Config.GetShovel(id)
		return placeholder(id, if def then def.Look.HeadColor else Color3.new(1, 0.5, 0.2), Vector3.new(0.6, 4, 0.6))
	end)
end

function ModelFactory.Pet(id: string): Model
	return build(Models.Pet, id, function()
		local def = Config.GetPet(id)
		local size = if def then def.Look.Size * 1.6 else 1.6
		return placeholder(
			id,
			if def then def.Look.BodyColor else Color3.new(1, 0.5, 0.4),
			Vector3.new(size, size, size),
			Enum.PartType.Ball
		)
	end)
end

-- v2.2 Golden pets (PetInstance.Golden): tint every part toward gold, add a little shine and a
-- gold sparkle on the biggest part. Client-side only (followers and viewports). Idempotent.
local GOLD = Color3.fromRGB(255, 205, 60)

function ModelFactory.MakeGolden(model: Model): Model
	if model:GetAttribute("Golden") == true then
		return model
	end
	model:SetAttribute("Golden", true)
	local biggest: BasePart? = nil
	local biggestVolume = -1
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = d.Color:Lerp(GOLD, 0.6)
			d.Reflectance = math.max(d.Reflectance, 0.25)
			local volume = d.Size.X * d.Size.Y * d.Size.Z
			if volume > biggestVolume then
				biggest, biggestVolume = d, volume
			end
		end
	end
	if biggest then
		local sparkles = Instance.new("Sparkles")
		sparkles.Name = "GoldenSparkles"
		sparkles.SparkleColor = GOLD
		sparkles.Parent = biggest
	end
	return model
end

-- Endgame C2 Rainbow pets (PetInstance.Rainbow): every part gets its own hue around the colour
-- wheel (kept a little of its own colour so the pet stays readable), more shine than Golden and
-- white-violet sparkles. Distinct from Golden at a glance. Client-side only. Idempotent.
local RAINBOW_SPARKLE = Color3.fromRGB(235, 200, 255)

function ModelFactory.MakeRainbow(model: Model): Model
	if model:GetAttribute("Rainbow") == true then
		return model
	end
	model:SetAttribute("Rainbow", true)
	local parts: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(parts, d)
		end
	end
	table.sort(parts, function(a: BasePart, b: BasePart): boolean
		return a.Position.Y < b.Position.Y -- hues climb the pet bottom to top
	end)
	local biggest: BasePart? = nil
	local biggestVolume = -1
	for i, part in parts do
		local hue = ((i - 1) / math.max(#parts, 1)) % 1
		part.Color = part.Color:Lerp(Color3.fromHSV(hue, 0.75, 1), 0.7)
		part.Reflectance = math.max(part.Reflectance, 0.35)
		local volume = part.Size.X * part.Size.Y * part.Size.Z
		if volume > biggestVolume then
			biggest, biggestVolume = part, volume
		end
	end
	if biggest then
		local sparkles = Instance.new("Sparkles")
		sparkles.Name = "RainbowSparkles"
		sparkles.SparkleColor = RAINBOW_SPARKLE
		sparkles.Parent = biggest
	end
	return model
end

-- Golden or Rainbow look for a pet instance's tier (Stats.PetTier: 1 Golden, 2 Rainbow).
function ModelFactory.ApplyTier(model: Model, golden: boolean?, rainbow: boolean?): Model
	if rainbow then
		return ModelFactory.MakeRainbow(model)
	elseif golden then
		return ModelFactory.MakeGolden(model)
	end
	return model
end

function ModelFactory.Egg(id: string): Model
	return build(Models.Egg, id, function()
		local def = Config.GetEgg(id)
		return placeholder(
			id,
			if def then def.Look.ShellColor else Color3.new(1, 0.95, 0.8),
			Vector3.new(2, 2.6, 2),
			Enum.PartType.Ball
		)
	end)
end

function ModelFactory.Treasure(id: string): Model
	return build(Models.Treasure, id, function()
		local def = Config.GetTreasure(id)
		return placeholder(id, if def then def.Look.Color else Color3.new(1, 0.8, 0.2), Vector3.new(1.2, 1.2, 1.2))
	end)
end

function ModelFactory.Backpack(id: string): Model
	return build(Models.Backpack, id, function()
		local def = Config.GetBackpack(id)
		return placeholder(id, if def then def.Look.Color else Color3.new(0.3, 0.6, 1), Vector3.new(1.6, 1.8, 1))
	end)
end

return ModelFactory
