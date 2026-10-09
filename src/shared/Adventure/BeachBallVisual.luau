--!strict
-- Decorative near-spherical panels have shallow seams, unlike the kit's deep ellipsoid intersections.
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
	for index, color in { Kit.Palette.Blue, Kit.Palette.Coral, Kit.Palette.Gold } do
		Build.ellipsoid(
			model,
			"ColorPanel",
			Vector3.new(diameter + 0.012, diameter + 0.012, diameter * 0.96),
			CFrame.new(center) * CFrame.Angles(0, (index - 1) * math.pi / 3, 0),
			color
		)
	end
	Build.ball(model, "TopCap", 0.8, CFrame.new(0, diameter - 0.32, 0), Kit.Palette.Cream)
	Build.ball(model, "BottomCap", 0.8, CFrame.new(0, 0.32, 0), Kit.Palette.Cream)
	local attachment = Instance.new("Attachment")
	attachment.Name = "RollEffectOrigin"
	attachment.Parent = contact
	return model
end

return Ball
