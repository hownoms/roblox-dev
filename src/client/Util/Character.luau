--!strict
-- Character lookups shared by controllers.
local Players = game:GetService("Players")

local Character = {}

function Character.GetRoot(player: Player?): BasePart?
	local p = player or Players.LocalPlayer
	local character = p.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			return root
		end
	end
	return nil
end

function Character.GetHumanoid(player: Player?): Humanoid?
	local p = player or Players.LocalPlayer
	local character = p.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			return humanoid
		end
	end
	return nil
end

function Character.GetTool(player: Player?): Tool?
	local p = player or Players.LocalPlayer
	local character = p.Character
	if character then
		return character:FindFirstChildOfClass("Tool")
	end
	return nil
end

return Character
