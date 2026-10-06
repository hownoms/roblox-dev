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
