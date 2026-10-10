--!nocheck
-- Actual runtime with an absent first arena in API-aware mocks, not Studio input acceptance.
local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")
Mock.Init(Generated, { Client = true })
local new = Mock.Env.Instance.new
local E = Mock.Enum
local player = Mock.AddLocalPlayer(9512, "InitialStream")
local character = Mock.SpawnCharacter(player, Mock.Vector3.new(0, 3, 6))
local remotes = new("Folder", Mock.Service("ReplicatedStorage"))
for _, name in { "Intent", "Snapshot", "Effect" } do
	new("RemoteEvent", remotes).Name = name
end
local Client = Mock.Require(Mock.ByPath["StarterPlayer/StarterPlayerScripts/Client/Adventure/SpringVaultClient"])
local handle = Client.Start(remotes, nil)
local passed = 0
local function check(value, message)
	assert(value, message)
	passed += 1
end
local q = Mock.Input(E.UserInputType.Keyboard, E.KeyCode.Q)
local function action(state)
	return Mock.Actions.SpringVaultBroadwave.Fn("SpringVaultBroadwave", state, q)
end
local function latest()
	return Mock.Remote.ToServer[#Mock.Remote.ToServer].Args[1].action
end
check(latest() == "Sync", "absent first arena still starts snapshot lifecycle")
local loan = new("Tool", character)
loan:SetAttribute("AdventureLoan", true)
check(action(E.UserInputState.Begin) == E.ContextActionResult.Pass, "loan cannot charge before first arena")
loan.Parent = player.Backpack
local licensed = new("Tool", character)
licensed:SetAttribute("ToolId", "tool_broadwave")
check(action(E.UserInputState.Begin) == E.ContextActionResult.Pass, "unlicensed marker cannot charge before arena")
licensed:SetAttribute("LicensedBroadwave", true)
check(action(E.UserInputState.Begin) == E.ContextActionResult.Sink, "licensed input starts before first arena")
check(latest() == "ChargeBegin", "licensed ordinary charge reaches actual runtime intent callback")
Mock.Advance(0.9)
action(E.UserInputState.End)
check(latest() == "ChargeRelease", "licensed ordinary release works before arena")
action(E.UserInputState.Begin)
check(latest() == "ChargeBegin", "licensed next charge starts before first stream-in")
local scene = new("Model")
scene.Name = "SpringVaultAdventure"
local target = new("Part", scene)
target:SetAttribute("AdventureAction", "Talk")
target:SetAttribute("TargetId", "npc_pip")
scene.Parent = Mock.Service("Workspace")
Mock.Advance(0.01)
check(latest() == "ChargeCancel", "first real stream-in cancels active charge at the scene boundary")
check(
	action(E.UserInputState.End) == E.ContextActionResult.Pass,
	"cancelled charge cannot release after first stream-in"
)
check(target:FindFirstChildWhichIsA("ProximityPrompt"), "first real stream-in binds adventure prompts")
licensed.Parent = player.Backpack
loan.Parent = character
check(action(E.UserInputState.Begin) == E.ContextActionResult.Sink, "loan input starts only after real arena arrives")
scene.Parent = nil
check(latest() == "ChargeCancel", "stream-out cancels loan charge")
check(action(E.UserInputState.Begin) == E.ContextActionResult.Pass, "streamed-out loan returns input ownership")
handle.Destroy()
local lateScene = new("Model")
lateScene.Name = "SpringVaultAdventure"
local lateTarget = new("Part", lateScene)
lateTarget:SetAttribute("AdventureAction", "Talk")
lateTarget:SetAttribute("TargetId", "npc_pip")
lateScene.Parent = Mock.Service("Workspace")
Mock.Advance(0.01)
check(not lateTarget:FindFirstChildWhichIsA("ProximityPrompt"), "destroyed runtime cannot bind late first arena")
check(not Mock.Actions.SpringVaultBroadwave, "teardown removes input without requiring arena")
check(#Mock.Errors == 0, "no asynchronous errors: " .. table.concat(Mock.Errors, "; "))
print("Spring Vault initial stream: " .. passed .. " checks passed")
