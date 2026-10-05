--!strict
-- STUB (coordinator). Modeling agent replaces the implementation; keep these signatures.
local Models = {}

local function placeholder(name: string, color: Color3, size: Vector3): Model
	local model = Instance.new("Model")
	model.Name = name
	local part = Instance.new("Part")
	part.Name = "Root"
	part.Anchored = true
	part.Size = size
	part.Color = color
	part.Parent = model
	model.PrimaryPart = part
	return model
end

function Models.Shovel(shovelId: string): Model
	return placeholder(shovelId, Color3.fromRGB(200, 120, 40), Vector3.new(0.4, 4, 0.4))
end

function Models.Pet(petId: string): Model
	return placeholder(petId, Color3.fromRGB(255, 120, 90), Vector3.new(1.5, 1.5, 1.5))
end

function Models.Egg(eggId: string): Model
	return placeholder(eggId, Color3.fromRGB(255, 240, 200), Vector3.new(2, 2.6, 2))
end

function Models.Treasure(treasureId: string): Model
	return placeholder(treasureId, Color3.fromRGB(255, 210, 60), Vector3.new(1, 1, 1))
end

function Models.Prop(name: string): Model
	return placeholder(name, Color3.fromRGB(120, 200, 120), Vector3.new(2, 2, 2))
end

function Models.ListProps(): { string }
	return {}
end

return Models
