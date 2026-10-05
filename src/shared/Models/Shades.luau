--!strict
-- STUB (coordinator). Owner agent replaces Build with real low-poly models (front = -Z, pivot bottom-centre).
local Shades = {}

function Shades.Build(id: string): Model
	local model = Instance.new("Model")
	model.Name = id
	local part = Instance.new("Part")
	part.Name = "Root"
	part.Anchored = true
	part.Size = Vector3.new(2, 2, 2)
	part.Parent = model
	model.PrimaryPart = part
	return model
end

return Shades
