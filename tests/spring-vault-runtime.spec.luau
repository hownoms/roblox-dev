--!nocheck
-- Actual adventure service/scene in the API-aware headless mock. This is not a network,
-- streaming, device, live-save or physical-avatar test. No production boot is loaded.
local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")
Mock.Init(Generated)
local Service = Mock.Require(Mock.ByPath["ServerScriptService/Server/Adventure/SpringVaultService"])
local Config = Mock.Require(Mock.ByPath["ReplicatedStorage/Shared/Adventure/SpringVaultConfig"])
local V, CF = Mock.Vector3.new, Mock.CFrame.new
local passed = 0
local function check(value, message)
	assert(value, message)
	passed += 1
end
local function player(id)
	local p = Mock.AddPlayer(id, "Runtime" .. id)
	p:LoadCharacter()
	return p
end
local function position(p, at)
	p.Character:PivotTo(CF(at))
end
local function request(runtime, p, action)
	runtime.Handle(p, { action = action, eventInstanceId = runtime.Event() and runtime.Event().EventInstanceId or "" })
end
local runtime = Service.Start({
	CanEnter = function()
		return true
	end,
})
local starter, helper = player(9101), player(9102)
position(starter, runtime.Scene.Targets.npc_mara)
request(runtime, starter, "Join")
Mock.Advance(5.1)
request(runtime, starter, "Start")
request(runtime, starter, "Ready")
Mock.Advance(0.1)
local event = runtime.Event()
check(event.Phase == "Active", "runtime reaches Active")
position(helper, runtime.Scene.Targets.npc_mara)
request(runtime, helper, "Join")
request(runtime, helper, "Ready")
Mock.Advance(0.1)
check(event.Participants[helper.UserId].Connected, "late helper admitted without changing solo work")
local now = Mock.Now()
for _, anchor in Config.AnchorIds do
	for hit = 1, 6 do
		assert(
			event:hitAnchor(
				if anchor == Config.AnchorIds[1] and hit == 1 then helper.UserId else starter.UserId,
				anchor,
				now
			)
		)
		now += Config.HitCooldownSeconds
	end
end
Mock.Advance(now - Mock.Now())
position(starter, runtime.Scene.Targets.vault_latch)
request(runtime, starter, "OpenVault")
check(event.Stage == "ball", "actual service opens ball stage")
local ball = runtime.Scene.Model:FindFirstChild("landmark_spring_vault_ball")
check(
	ball and ball:GetAttribute("BallGeometryMode") == "PrimitiveFallback",
	"mock explicitly exercises primitive fallback, not EditableMesh success"
)
local contact = ball:FindFirstChild("ContactSphere")
check(
	contact and contact.Size == V(7.6, 7.6, 7.6) and contact.CanQuery and not contact.CanCollide,
	"fallback preserves sole fixed noncolliding contact sphere"
)
for _, item in ball:GetDescendants() do
	if item:IsA("SpecialMesh") then
		assert(
			item.MeshId == "" and item.TextureId == "",
			"fallback must use built-in geometry without uploaded mesh or texture IDs"
		)
	end
end
position(starter, runtime.Scene.BallStart)
request(runtime, starter, "PushBall")
local path = runtime.Scene.Routes.Left
local targetIndex = 2
for _ = 1, 900 do
	local part = starter.Character.HumanoidRootPart
	local goal = path[targetIndex]
	local difference = goal - part.Position
	if difference.Magnitude < 0.05 then
		targetIndex = math.min(targetIndex + 1, 4)
		goal = path[targetIndex]
		difference = goal - part.Position
	end
	if difference.Magnitude > 0 then
		position(starter, part.Position + difference.Unit * math.min(0.2, difference.Magnitude))
	end
	Mock.Advance(1 / 30)
	if event.GateIndex == 1 then
		break
	end
end
check(event.GateIndex == 1, "validated mock avatar motion reaches gate 1")
local checkpoint = runtime.Scene.Targets.ball
local points = event.Participants[starter.UserId].Points
position(starter, runtime.Scene.Targets.ball_reset)
request(runtime, starter, "ResetBall")
for _ = 1, 7 do
	Mock.Advance(0.5)
	request(runtime, starter, "ResetBall")
end
check((runtime.Scene.Targets.ball - checkpoint).Magnitude < 0.001, "repeated reset returns exact gate1 checkpoint")
check(
	event.GateIndex == 1 and event.Participants[starter.UserId].Points == points,
	"reset preserves gate1 and contribution"
)
check(not event.Participants[starter.UserId].Attached, "reset releases cargo")
check(starter.Character.Humanoid.WalkSpeed == 16, "reset restores original speed")
position(helper, checkpoint)
request(runtime, helper, "PushBall")
Mock.Advance(0.1)
check(helper.Character.Humanoid.WalkSpeed == Config.SoloSpeed, "helper hauling override applied")
local oldHelper = helper
local helperPoints = event.Participants[helper.UserId].Points
local helperLastHit = event.Participants[helper.UserId].LastHitAt
Mock.RemovePlayer(helper)
check(
	not event.Participants[9102].Connected and not event.Participants[9102].Attached,
	"disconnect holds identity but releases cargo"
)
helper = player(9102)
check(helper ~= oldHelper, "reconnect uses replacement Player object with same UserId")
position(helper, runtime.Scene.Targets.npc_mara)
request(runtime, helper, "Join")
Mock.Advance(0.1)
check(event.Participants[9102].Connected and event.Participants[9102].Ready, "service reconnects held same identity")
check(
	helperPoints > 0 and event.Participants[9102].Points == helperPoints,
	"replacement keeps earned work contribution"
)
check(event.Participants[9102].LastHitAt == helperLastHit, "replacement preserves authoritative work cooldown")
check(not event.Participants[9102].Attached, "replacement player must explicitly attach")
check(helper.Character.Humanoid.WalkSpeed == 16, "old humanoid override does not transfer to replacement")
request(runtime, starter, "Leave")
request(runtime, helper, "Leave")
Mock.Advance(30.1)
check(runtime.Event() == nil, "abandoned runtime destroys event")
check(not starter.Backpack:FindFirstChild("Broadwave (Adventure Loan)"), "cleanup destroys starter loan")
check(not helper.Backpack:FindFirstChild("Broadwave (Adventure Loan)"), "cleanup destroys replacement loan")
runtime.Destroy()
runtime.Destroy()
for _ = 1, 100 do
	local cycle = Service.Start({
		CanEnter = function()
			return true
		end,
	})
	position(starter, cycle.Scene.Targets.npc_mara)
	request(cycle, starter, "Join")
	Mock.Advance(5.1)
	request(cycle, starter, "Start")
	request(cycle, starter, "Ready")
	Mock.Advance(0.1)
	local state = cycle.Event()
	local workAt = Mock.Now()
	for _, anchor in Config.AnchorIds do
		for _ = 1, 6 do
			assert(state:hitAnchor(starter.UserId, anchor, workAt))
			workAt += Config.HitCooldownSeconds
		end
	end
	Mock.Advance(workAt - Mock.Now())
	position(starter, cycle.Scene.Targets.vault_latch)
	request(cycle, starter, "OpenVault")
	position(starter, cycle.Scene.BallStart)
	request(cycle, starter, "PushBall")
	Mock.Advance(0.1)
	-- Progression is assisted here; this loop tests runtime settlement/cleanup lifecycle,
	-- not traversal. The earlier fixture drives actual validated motion through gate 1.
	for _, gate in Config.GateIds do
		assert(state:advanceBallGate(gate, Mock.Now(), { [starter.UserId] = 1 }))
	end
	Mock.Advance(12.1)
	assert(cycle.Event() == nil and cycle.LastCompletion and cycle.Settled == false)
	assert(starter.Character.Humanoid.WalkSpeed == 16)
	assert(not starter.Backpack:FindFirstChild("Broadwave (Adventure Loan)"))
	cycle.Destroy()
end
Mock.Advance(1)
check(
	Mock.Game:GetService("ReplicatedStorage"):FindFirstChild("SpringVaultAdventure") == nil,
	"100 assisted activity/cleanup lifecycles leave no remote namespace"
)
check(
	Mock.Game:GetService("Workspace"):FindFirstChild("SpringVaultAdventure") == nil,
	"100 assisted activity/cleanup lifecycles leave no scene"
)
check(#Mock.Errors == 0, "no asynchronous runtime errors")
check(#Mock.Warnings == 0, "server builds safe primitives without requiring a local mesh API")
print("Spring Vault runtime mock: " .. passed .. " checks passed")
