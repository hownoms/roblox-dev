--!strict
-- Isolated review only. Never loads production services or saves.
local Kit = require(game:GetService("ReplicatedStorage").Shared.Models.Expansion1)
local group = Instance.new("Folder")
group.Name = "Expansion1Review"
group.Parent = workspace
local floor = Instance.new("Part")
floor.Name = "ReviewFloor"
floor.Size = Vector3.new(130, 1, 90)
floor.Position = Vector3.new(30, -0.5, 15)
floor.Color = Kit.Palette.Sand
floor.Anchored = true
floor.Parent = group
local spawn = Instance.new("SpawnLocation")
spawn.Size = Vector3.new(6, 1, 6)
spawn.Position = Vector3.new(0, 0.5, -16)
spawn.Anchored = true
spawn.Parent = group

local function show(m: Model, x: number, z: number)
	m:PivotTo(CFrame.new(x, 0, z))
	m.Parent = group
	assert(m.PrimaryPart, m.Name .. " lacks a pivot")
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 48)
	gui.StudsOffset = Vector3.new(0, 10, 0)
	gui.MaxDistance = 100
	gui.Parent = m.PrimaryPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Kit.Palette.Navy
	label.TextColor3 = Kit.Palette.Cream
	label.Text = m.Name
	label.TextSize = 16
	label.Parent = gui
	print("EXPANSION ASSET", m.Name, m:GetExtentsSize())
end

for i, pose in { "Idle", "Point", "Celebrate" } do
	show(Kit.NPC("npc_mara", pose), (i - 1) * 8, 0)
	show(Kit.NPC("npc_pip", pose), (i - 1) * 8, 12)
end
show(Kit.Broadwave(), 28, 0)
for i, stage in { "Covered", "Partial", "Opened" } do
	local m = Kit.SpringVault(stage)
	local size = m:GetExtentsSize()
	assert(size.X <= 12.01 and size.Y <= 10.01 and size.Z <= 8.4, "Vault envelope exceeded")
	show(m, (i - 1) * 20, 32)
end
show(Kit.BeachBall(), 62, 32)
show(Kit.TrophyStand(), 34, 12)
local trophy = Kit.TrophyReplica()
trophy:PivotTo(CFrame.new(34, 1.75, 12))
trophy.Parent = group
show(Kit.AbilityEffect(0.5), 62, 0)
show(Kit.BallEffect(), 62, 32)

-- Equipable copy in review StarterPack for R6/R15 grip and moving strike inspection.
local held = Kit.Broadwave()
local handle = held.PrimaryPart :: BasePart
local tool = Instance.new("Tool")
tool.Name = "Broadwave Visual Contact Review"
tool.RequiresHandle = true
tool.CanBeDropped = false
tool.Grip = handle:GetAttribute("GripOffset") :: CFrame
tool:SetAttribute("TwoHanded", true)
for _, child in held:GetChildren() do
	child.Parent = tool
end
for _, d in tool:GetDescendants() do
	if d:IsA("BasePart") then
		d.Anchored = false
	end
end
held:Destroy()
tool.Parent = game:GetService("StarterPack")
