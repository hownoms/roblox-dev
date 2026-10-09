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

-- Licensed boundary executes actual runtime charge handling without boot or saves.
local licensed = player(9199)
local issued = Mock.Env.Instance.new("Tool")
issued:SetAttribute("ToolId", Config.ToolId)
issued.Parent = licensed.Character
local allowed, resolverError, calls = true, false, 0
local ordinary = Service.Start({
	ResolveTool = function(p)
		if resolverError then
			error("eligibility unavailable")
		end
		return if p == licensed and allowed then issued else nil
	end,
	CanTrial = function()
		return true
	end,
	OnOrdinaryBroadwave = function()
		calls += 1
		return true
	end,
})
check(
	not ordinary.Scene.Model:FindFirstChildWhichIsA("SpawnLocation", true),
	"production-default runtime creates no review spawn"
)
position(licensed, V(0, 50, 0))
local function charge()
	Mock.Advance(3)
	request(ordinary, licensed, "ChargeBegin")
	Mock.Advance(0.9)
end
charge()
request(ordinary, licensed, "ChargeRelease")
check(calls == 1, "authoritatively resolved equipped licensed tool releases ordinary ability")
charge()
allowed = false
request(ordinary, licensed, "ChargeRelease")
check(calls == 1, "license revocation during charge refuses release")
allowed = true
charge()
local replacement = Mock.Env.Instance.new("Tool")
replacement:SetAttribute("ToolId", Config.ToolId)
issued.Parent = licensed.Backpack
replacement.Parent = licensed.Character
local original = issued
issued = replacement
request(ordinary, licensed, "ChargeRelease")
check(calls == 1, "same-ID equipped replacement cannot inherit charge")
charge()
issued.Unequipped:_fire()
request(ordinary, licensed, "ChargeRelease")
check(calls == 1, "licensed unequip signal cancels held charge")
resolverError = true
charge()
request(ordinary, licensed, "ChargeRelease")
check(calls == 1, "resolver failure refuses safely without ordinary callback")
resolverError = false
issued:SetAttribute("AdventureLoan", true)
charge()
request(ordinary, licensed, "ChargeRelease")
check(calls == 1, "external loan is refused even when resolver returns it")
issued:SetAttribute("AdventureLoan", false)
issued.Parent = licensed.Backpack
position(licensed, ordinary.Scene.Targets.npc_pip)
ordinary.Handle(licensed, { action = "Talk", targetId = "npc_pip" })
local loan = licensed.Backpack:FindFirstChild("Broadwave (Adventure Loan)")
assert(loan, "review trial provides runtime-owned loan")
loan.Parent = licensed.Character
position(licensed, V(0, 50, 0))
charge()
check(
	not ordinary.ReviewPlayer(licensed).Charging,
	"review loan cannot start ordinary charge away from trial even with adapter"
)
request(ordinary, licensed, "ChargeRelease")
check(calls == 1, "runtime-owned review loan never reaches ordinary adapter")
position(licensed, ordinary.Scene.Targets.trial_patch + V(0, 0, 6))
charge()
check(ordinary.ReviewPlayer(licensed).Charging, "review loan still charges in eligible trial corridor")
request(ordinary, licensed, "ChargeCancel")
loan.Parent = licensed.Backpack
issued.Parent = licensed.Character
position(licensed, ordinary.Scene.Targets.trial_patch + V(0, 0, 6))
charge()
request(ordinary, licensed, "ChargeRelease")
check(
	ordinary.ReviewPlayer(licensed).Trial.Wave and calls == 1,
	"licensed tool accepts trial target without also invoking ordinary digging"
)
issued.Parent = licensed.Backpack
ordinary.Destroy()
check(
	issued.Parent == licensed.Backpack and original.Parent == licensed.Backpack,
	"runtime cleanup preserves external licensed possessions"
)
issued:Destroy()
original:Destroy()
local review = Service.Start({ ReviewSpawn = true })
check(
	review.Scene.Model:FindFirstChildWhichIsA("SpawnLocation", true) ~= nil,
	"review spawn exists only with explicit opt-in"
)
review.Destroy()
check(#Mock.Errors == 0, "no asynchronous runtime errors")
check(#Mock.Warnings == 0, "server builds safe primitives without requiring a local mesh API")
print("Spring Vault runtime mock: " .. passed .. " checks passed")
