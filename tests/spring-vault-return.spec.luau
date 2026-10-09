--!nocheck
-- Actual service/scene with API-aware mocks. No physics, networking, streaming or device pass.
local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")
Mock.Init(Generated)
local Service = Mock.Require(Mock.ByPath["ServerScriptService/Server/Adventure/SpringVaultService"])
local V, CF = Mock.Vector3.new, Mock.CFrame.new
local origin, surface = V(-200, 970, 106), V(-112, 1030.5, 76)
local passed, identity = 0, 9400
local function check(value, message)
	assert(value, message)
	passed += 1
end
local function run(label, resolver, setup, expected)
	identity += 1
	local p = Mock.AddPlayer(identity, label)
	p:LoadCharacter()
	local calls = 0
	local runtime = Service.Start({
		Origin = origin,
		CanEnter = function()
			return true
		end,
		ReturnFrame = if resolver
			then function(who)
				calls += 1
				check(who == p, label .. ": callback receives the joined identity")
				return resolver(p)
			end
			else nil,
	})
	p.Character:PivotTo(CF(runtime.Scene.Targets.npc_mara))
	local join = p.Character:GetPivot().Position
	runtime.Handle(p, { action = "Join", eventInstanceId = "" })
	check(runtime.Event().Participants[p.UserId] ~= nil, label .. ": joins actual service")
	check(p.Backpack:FindFirstChild("Broadwave (Adventure Loan)") ~= nil, label .. ": owns review loan")
	if setup then
		setup(p, runtime)
	end
	local before = p.Character:GetPivot().Position
	runtime.Destroy()
	local wanted = if expected == "join" then join elseif expected == "unchanged" then before else expected
	check(p.Character:GetPivot().Position == wanted, label .. ": cleanup destination")
	check(not p.Backpack:FindFirstChild("Broadwave (Adventure Loan)"), label .. ": cleanup still removes loan")
	check(Mock.Game:GetService("Workspace"):FindFirstChild("SpringVaultAdventure") == nil, label .. ": scene removed")
	Mock.RemovePlayer(p)
	return calls
end
run("trusted surface", function()
	return CF(surface)
end, nil, surface)
run("explicit Leave", function()
	return CF(surface)
end, function(p, runtime)
	runtime.Handle(p, { action = "Leave", eventInstanceId = runtime.Event().EventInstanceId })
	check(p.Character:GetPivot().Position == surface, "Leave returns to trusted surface immediately")
end, surface)
run("reset without ready crew", function()
	return CF(surface)
end, function(p, runtime)
	Mock.Advance(46)
	check(runtime.Event() == nil, "unready crew expires and rebuilds scene")
	check(p.Character:GetPivot().Position == surface, "reset returns directly to surface")
end, surface)
run("nil fallback", function()
	return nil
end, nil, "join")
run("invalid fallback", function()
	return V(1, 2, 3)
end, nil, "join")
run("error fallback", function()
	error("destination unavailable")
end, nil, "join")
local calls = run("surface directly above pocket", function()
	return CF(surface)
end, function(p)
	p.Character:PivotTo(CF(origin + V(0, 54, -36)))
end, "unchanged")
check(calls == 0, "surface character skips destination callback")
calls = run("respawn on beach", function()
	return CF(surface)
end, function(p)
	p:LoadCharacter()
	p.Character:PivotTo(CF(surface))
end, "unchanged")
check(calls == 0, "respawned surface character skips destination callback")
run("callback moves surface", function(p)
	p.Character:PivotTo(CF(surface))
	return CF(origin)
end, nil, surface)
run("callback replaces character", function(p)
	p:LoadCharacter()
	p.Character:PivotTo(CF(surface))
	return CF(origin)
end, nil, surface)
run("dedicated review default", nil, function(p)
	p.Character:PivotTo(CF(surface))
end, "join")
local runtime = Service.Start({ Origin = origin })
local wall = runtime.Scene.Model:FindFirstChild("NearBoundary")
check(
	wall and wall.CanCollide and wall.Anchored and wall:GetAttribute("ProtectedGeometry"),
	"near wall is collidable and protected"
)
check(wall.Position == origin + V(0, 4, 33) and wall.Size == V(100, 8, 2), "near wall closes entire open floor edge")
check(runtime.Scene.Targets.adventure_exit.Z + 2 < wall.Position.Z - wall.Size.Z / 2, "existing exit pad clears wall")
check(origin.Z + 29 + 2 < wall.Position.Z - wall.Size.Z / 2, "Claude return pad clears wall")
runtime.Destroy()
local practice = Service.Start({
	Origin = origin,
	CanTrial = function()
		return true
	end,
	CanEnter = function()
		return true
	end,
})
local student = Mock.AddPlayer(9499, "OptionalPractice")
student:LoadCharacter()
local function talkPip()
	student.Character:PivotTo(CF(practice.Scene.Targets.npc_pip))
	practice.Handle(student, { action = "Talk", targetId = "npc_pip" })
end
talkPip()
local trialStart = student.Character:GetPivot().Position
student.Character:PivotTo(CF(practice.Scene.Targets.trial_patch))
practice.Handle(student, { action = "Leave" })
check(not practice.ReviewPlayer(student).Trial, "standalone Leave ends optional practice without event membership")
check(student.Character:GetPivot().Position == trialStart, "practice Leave restores its entry position")
Mock.Advance(1.1)
check(
	not student.Backpack:FindFirstChild("Broadwave (Adventure Loan)"),
	"practice Leave cannot recreate a loan on heartbeat"
)
talkPip()
student.Character:PivotTo(CF(practice.Scene.Targets.npc_mara))
practice.Handle(student, { action = "Join", eventInstanceId = "" })
check(not practice.ReviewPlayer(student).Trial, "joining the rescue ends practice authority")
check(student.Backpack:FindFirstChild("Broadwave (Adventure Loan)") ~= nil, "rescue retains its own event loan")
talkPip()
practice.Handle(student, { action = "Leave", eventInstanceId = practice.Event().EventInstanceId })
Mock.Advance(1.1)
check(not practice.ReviewPlayer(student).Trial, "event Leave also ends overlapping practice")
check(
	not student.Backpack:FindFirstChild("Broadwave (Adventure Loan)"),
	"event Leave cannot recreate practice equipment"
)
Mock.Advance(31)
student.Character:PivotTo(CF(practice.Scene.Targets.npc_mara))
practice.Handle(student, { action = "Join", eventInstanceId = "" })
talkPip()
Mock.Advance(46)
check(not practice.ReviewPlayer(student).Trial, "event rebuild cleans practice session with its restored equipment")
practice.Destroy()
Mock.RemovePlayer(student)
check(#Mock.Errors == 0, "no asynchronous mock errors")
print("Spring Vault return mock: " .. passed .. " checks passed")
