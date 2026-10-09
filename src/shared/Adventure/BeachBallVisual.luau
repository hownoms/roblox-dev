--!strict
-- Smooth spherical color caps are separated by actual cream gutters; no nearly coplanar seams.
-- The fixed contact sphere never squashes. No physics impulse or gameplay authority lives here.
local Build = require(script.Parent.Parent.Models.Build)
local Kit = require(script.Parent.Parent.Models.Expansion1)
local Ball = {}

function Ball.Create(): Model
	local model = Build.model("landmark_spring_vault_ball")
	Build.root(model, CFrame.new())
	model:SetAttribute("ParentEntityId", "landmark_spring_vault")
	model:SetAttribute("EventId", "event_vault")
	model:SetAttribute("MovementMode", "ServerKinematic")
	local diameter = Kit.Spec.BallDiameter
	local center = Vector3.new(0, diameter / 2, 0)
	local contact = Build.ball(model, "ContactSphere", diameter, CFrame.new(center), Kit.Palette.Cream)
	-- Players can walk beside/through the visual cargo; it cannot pin or shove avatars.
	contact.CanCollide = false
	contact.CanQuery = true
	-- Caps extend just 0.1 studs beyond the contact sphere at their centers.
	-- At adjacent-panel bisectors their surface is inside the cream sphere, so
	-- no two colored surfaces meet outside it. Wider gutters mask curved-edge
	-- faceting without meshes, uploads, CSG or additional seam overlays.
	for index, color in
		{ Kit.Palette.Blue, Kit.Palette.Coral, Kit.Palette.Gold, Kit.Palette.Blue, Kit.Palette.Coral, Kit.Palette.Gold }
	do
		local angle = (index - 1) * math.pi / 3
		local offset = Vector3.new(math.sin(angle), 0, math.cos(angle)) * (diameter / 2 - 2.9)
		Build.ball(model, "ColorPanel", 6, CFrame.new(center + offset), color)
	end
	-- The contact sphere supplies smooth cream poles; separate balls protrude
	-- beyond its surface and introduce another visible intersection seam.
	local attachment = Instance.new("Attachment")
	attachment.Name = "RollEffectOrigin"
	attachment.Parent = contact
	return model
end

return Ball
