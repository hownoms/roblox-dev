--!nocheck
-- Actual isolated scene with API-aware mocks; geometry checks are not physics/device QA.
local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")
Mock.Init(Generated)
local Scene = Mock.Require(Mock.ByPath["ServerScriptService/Server/Adventure/SpringVaultScene"])
local V = Mock.Vector3.new
local origin = V(700, 20, 0)
local passed = 0
local function check(value, message)
	assert(value, message)
	passed += 1
end
local scene = Scene.Build(Mock.Service("Workspace"), origin, true)
local spawn = scene.Model:FindFirstChild("AdventureReviewSpawn")
check((spawn.Position - scene.Targets.npc_mara).Magnitude < 10, "arrival is within Mara talk distance")
check(
	spawn.CFrame.LookVector:Dot((origin + V(0, 0.5, -4) - spawn.Position).Unit) > 0.99,
	"arrival faces vault with Mara beside approach"
)
check(scene.Targets.vault_latch.Z > origin.Z - 4, "latch faces lobby approach")
for id, anchor in scene.Anchors do
	check(scene.Targets[id].Z > origin.Z - 4, "shaped anchor faces lobby: " .. id)
	check(
		anchor:FindFirstChild("AnchorBase").Position == scene.Targets[id],
		"work target follows actual anchor: " .. id
	)
	local arrivalShapes = 0
	for _, child in anchor:GetChildren() do
		if string.find(child.Name, "Arrival", 1, true) then
			arrivalShapes += 1
			check(child.Position.Z > scene.Targets[id].Z + 0.7, "shape faces arrival outside sand cover")
			check(child.Position.Y < origin.Y + 6.5, "shape can be read below top sand marker")
			check(not child.CanCollide and not child.CanQuery, "arrival shape is presentation only")
		end
	end
	check(arrivalShapes > 0, "each anchor exposes its actual shape to arrivals")
end
local bounds = {}
for _, child in scene.Vault:GetDescendants() do
	if child:IsA("BasePart") then
		bounds[child.Name] = child.Position
	end
end
scene.OpenVault()
check(scene.Vault:FindFirstChild("Latch").Position.Z > origin.Z - 4, "opened vault retains arrival-facing latch")
check(scene.Vault:FindFirstChild("BackWall").Position == bounds.BackWall, "replacement retains wall footprint")
local dashes = 0
for _, child in scene.Model:GetDescendants() do
	if string.find(child.Name, "RouteDash", 1, true) or string.find(child.Name, "RouteArrow", 1, true) then
		check(
			not child.CanCollide and not child.CanTouch and not child.CanQuery,
			"route cues cannot block avatars or ball"
		)
		check(child:GetAttribute("ProtectedGeometry"), "route cues remain protected")
		if string.find(child.Name, "RouteDash", 1, true) then
			dashes += 1
		end
	elseif child:IsA("BillboardGui") then
		check(
			not child.AlwaysOnTop and child.MaxDistance == (if child.Name == "AdventureHostLabel" then 35 else 40),
			"labels cannot show through scenery or from far away"
		)
	end
end
check(dashes == 18, "both routes have restrained floor cues")
check(scene.Routes.Left[3] == origin + V(-8, 3.8, -36), "left gate route authority stays unchanged")
check(scene.Routes.Right[3] == origin + V(8, 3.8, -36), "right gate route authority stays unchanged")
local ball = scene.SpawnBall()
local contact = ball:FindFirstChild("ContactSphere")
check(contact.Size == V(7.6, 7.6, 7.6) and not contact.CanCollide, "fixed noncolliding ball contact geometry remains")
scene.Destroy()
scene = Scene.Build(Mock.Service("Workspace"), origin)
check(not scene.Model:FindFirstChild("AdventureReviewSpawn"), "production scene never opts into review spawn")
scene.Destroy()
check(#Mock.Errors == 0, "no asynchronous mock errors")
print("Spring Vault scene mock: " .. passed .. " checks passed")
