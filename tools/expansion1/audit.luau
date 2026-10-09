--!nocheck
-- Execute real factories against the repo's API-aware headless mock.
local Mock = require("../../tests/mock/Roblox")
Mock.Init(require("../../build/test/generated"))
local Kit = Mock.Require(Mock.ByPath["ReplicatedStorage/Shared/Models/Expansion1"])
local entries = {}
for _, id in { "npc_mara", "npc_pip" } do
	for _, pose in { "Idle", "Point", "Celebrate" } do
		table.insert(entries, { id .. "_" .. pose, Kit.NPC(id, pose) })
	end
end
table.insert(entries, { "tool_broadwave", Kit.Broadwave() })
table.insert(entries, { "tool_broadwave_charge", Kit.ChargeEffect(1) })
for _, state in { "Covered", "Partial", "Opened" } do
	table.insert(entries, { "landmark_spring_vault_" .. state, Kit.SpringVault(state) })
end
table.insert(entries, { "landmark_spring_vault_ball", Kit.BeachBall() })
table.insert(entries, { "camp_trophy_stand", Kit.TrophyStand() })
table.insert(entries, { "landmark_spring_vault_trophy", Kit.TrophyReplica() })
table.insert(entries, { "tool_broadwave_effect", Kit.AbilityEffect(0.5) })
table.insert(entries, { "landmark_spring_vault_ball_effect", Kit.BallEffect() })
table.insert(entries, { "tool_broadwave_effect_reduced", Kit.AbilityEffect(0.5, true) })
table.insert(entries, { "landmark_spring_vault_ball_effect_reduced", Kit.BallEffect(true) })
for _, entry in entries do
	local id, m = entry[1], entry[2]
	assert(m.PrimaryPart, id .. " missing PrimaryPart")
	local count = 0
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			count += 1
			assert(p.Anchored, id .. " unanchored construction")
			if id == "landmark_spring_vault_trophy" then
				assert(not p.CanCollide and not p.CanTouch and not p.CanQuery)
			end
			if id == "camp_trophy_stand" then
				assert(p.Size.X <= 2 and p.Size.Z <= 2)
			end
			local shape = Mock.Internal(p).props.Shape
			local values = { id, p.Name, p.ClassName, if shape then shape.Name else "Block", tostring(p.Transparency) }
			for _, n in { p.Size.X, p.Size.Y, p.Size.Z, p.Color.R, p.Color.G, p.Color.B } do
				table.insert(values, tostring(n))
			end
			for _, n in { p.CFrame:GetComponents() } do
				table.insert(values, tostring(n))
			end
			local mesh = p:FindFirstChildOfClass("SpecialMesh")
			table.insert(values, if mesh then mesh.MeshType.Name else "None")
			print("PART\t" .. table.concat(values, "\t"))
		end
	end
	assert(count < 100, id .. " exceeds first-slice per-model budget")
	print("PASS\t" .. id .. "\t" .. count)
end
local tool = Kit.Broadwave()
local vault = Kit.SpringVault("Covered")
local anchor = vault:FindFirstChild("vault_anchor_1")
for _, progress in { 0, 0.25, 0.5, 0.75, 1 } do
	Kit.SetAnchorProgress(anchor, progress)
	assert(anchor:GetAttribute("VisualProgress") == progress)
end
assert(anchor.SandCover.Transparency == 1, "Completed cover still visible")
vault:PivotTo(Mock.CFrame.new(40, 1024, 80) * Mock.CFrame.Angles(0, math.pi / 2, 0))
Kit.SetAnchorProgress(anchor, 0.5)
assert(anchor.SandCover.Position.Y > 1024, "Moved-vault progress escaped its world frame")
local h = tool.PrimaryPart
for _, key in { "GripOffset", "TwoHanded", "ShaftAxis", "CupAxis", "LeftHand", "BladePoint" } do
	assert(h:GetAttribute(key) ~= nil, key)
end
local welds = 0
for _, d in tool:GetDescendants() do
	if d:IsA("WeldConstraint") then
		welds += 1
	end
end
assert(welds == #tool:GetChildren() - 1, "Tool is not one welded assembly")
print("ALL EXPANSION ASSET CONSTRUCTION CHECKS PASSED")
