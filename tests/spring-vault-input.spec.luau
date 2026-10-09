--!nocheck
-- Real adventure client in the API-aware mock. This checks callback/cleanup behavior;
-- it is not controller hardware, touch-device or network acceptance evidence.
local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")
Mock.Init(Generated, { Client = true })
local E = Mock.Enum
local new = Mock.Env.Instance.new
local player = Mock.AddLocalPlayer(9510, "AdventureInput")
local character = Mock.SpawnCharacter(player, Mock.Vector3.new(0, 3, 6))
local scene = new("Model", Mock.Service("Workspace"))
scene.Name = "SpringVaultAdventure"
local target = new("Part", scene)
target:SetAttribute("AdventureAction", "Talk")
target:SetAttribute("TargetId", "npc_pip")
local remotes = new("Folder", Mock.Service("ReplicatedStorage"))
local intent = new("RemoteEvent", remotes)
intent.Name = "Intent"
local snapshot = new("RemoteEvent", remotes)
snapshot.Name = "Snapshot"
local effect = new("RemoteEvent", remotes)
effect.Name = "Effect"
local Client = Mock.Require(Mock.ByPath["StarterPlayer/StarterPlayerScripts/Client/Adventure/SpringVaultClient"])
local Ball = Mock.Require(Mock.ByPath["ReplicatedStorage/Shared/Adventure/BeachBallVisual"])
local ball = Ball.Create()
ball.Parent = scene
local handle = Client.Start(remotes, scene)
local passed = 0
local function check(value, message)
	assert(value, message)
	passed += 1
end
local function count(action)
	local total = 0
	for _, request in Mock.Remote.ToServer do
		if request.Name == "Intent" and request.Args[1].action == action then
			total += 1
		end
	end
	return total
end
local function latest()
	return Mock.Remote.ToServer[#Mock.Remote.ToServer].Args[1].action
end
local function input(inputType, key)
	return Mock.Input(inputType, key)
end
local function action(state, object)
	return Mock.Actions.SpringVaultBroadwave.Fn("SpringVaultBroadwave", state, object)
end
local q = input(E.UserInputType.Keyboard, E.KeyCode.Q)
local l1 = input(E.UserInputType.Gamepad1, E.KeyCode.ButtonL1)
local touch1 = input(E.UserInputType.Touch)
local touch2 = input(E.UserInputType.Touch)
check(table.find(Mock.Actions.SpringVaultBroadwave.Keys, E.KeyCode.Q), "keyboard bound")
check(table.find(Mock.Actions.SpringVaultBroadwave.Keys, E.KeyCode.ButtonL1), "controller bound")
action(E.UserInputState.Begin, q)
check(count("ChargeBegin") == 0, "no loan or membership cannot begin")
Mock.FireEvent(snapshot, "OnClientEvent", { loanAvailable = true, eventInstanceId = "input:1" })
Mock.Advance(0.01)
check(
	action(E.UserInputState.Begin, q) == E.ContextActionResult.Pass and count("ChargeBegin") == 0,
	"loan in Backpack does not own Q"
)
local loan = new("Tool", player.Backpack)
loan:SetAttribute("AdventureLoan", true)
Mock.Advance(0.01)
local equip = player.PlayerGui.SpringVaultAdventureReview:FindFirstChild("BroadwaveEquip", true)
check(equip.Visible, "equip control available with hidden Backpack")
Mock.FireEvent(equip, "Activated")
Mock.Advance(0.01)
check(loan.Parent == character and equip.Text == "Stow Broadwave", "equip button equips actual owned tool")
action(E.UserInputState.Begin, q)
check(latest() == "ChargeBegin", "keyboard begins through actual client callback")
action(E.UserInputState.Begin, l1)
action(E.UserInputState.End, l1)
check(count("ChargeBegin") == 1 and count("ChargeRelease") == 0, "overlapping L1 cannot release Q")
Mock.Advance(0.9)
local preview = Mock.Service("Workspace"):FindFirstChild("SpringVaultLocalAim")
check(
	preview and not preview.CanCollide and not preview.CanTouch and not preview.CanQuery,
	"aim preview has no geometry authority"
)
local gui = player.PlayerGui:FindFirstChild("SpringVaultAdventureReview")
check(not gui.ScrollingFrame.Visible, "charging hides card so centered aim hint does not cover it")
check(
	gui.BroadwaveAimHint.Visible and string.find(gui.BroadwaveAimHint.Text, "Ready"),
	"full charge gets readiness cue"
)
action(E.UserInputState.End, input(E.UserInputType.Keyboard, E.KeyCode.Q))
check(latest() == "ChargeRelease" and not preview.Parent, "matching digital input releases and clears preview")
check(gui.ScrollingFrame.Visible, "release restores the precharge card")
action(E.UserInputState.Begin, l1)
action(E.UserInputState.End, l1)
check(count("ChargeBegin") == 2 and count("ChargeRelease") == 2, "controller callback sends both requests")
action(E.UserInputState.Begin, touch1)
action(E.UserInputState.End, touch2)
check(count("ChargeRelease") == 2, "another finger cannot release touch charge")
action(E.UserInputState.End, touch1)
check(count("ChargeRelease") == 3, "originating touch releases")
action(E.UserInputState.Begin, q)
Mock.FireEvent(Mock.Service("UserInputService"), "WindowFocusReleased")
Mock.Advance(0.01)
check(latest() == "ChargeCancel" and not gui.BroadwaveAimHint.Visible, "focus loss cancels")
action(E.UserInputState.End, q)
check(latest() == "ChargeCancel", "release after cancellation sends no stale request")
action(E.UserInputState.Begin, q)
Mock.FireEvent(Mock.Service("UserInputService"), "TextBoxFocused", new("TextBox"))
Mock.Advance(0.01)
check(latest() == "ChargeCancel", "text entry cancels")
action(E.UserInputState.Begin, q)
Mock.Advance(10.1)
check(latest() == "ChargeCancel" and not gui.BroadwaveAimHint.Visible, "expired charge cancels without release")
action(E.UserInputState.Begin, q)
Mock.Advance(0.05)
Mock.FireEvent(effect, "OnClientEvent", {
	kind = "Wave",
	playerUserId = 9511,
	frame = Mock.CFrame.new(0, 3, 6),
})
Mock.Advance(0.05)
check(
	Mock.Service("Workspace"):FindFirstChild("tool_broadwave_effect"),
	"real effect factory produces active local wave"
)
scene.Parent = nil
Mock.Advance(0.05)
check(latest() == "ChargeCancel", "scene ancestry removal cancels charge")
local beginsBeforeAbsent = count("ChargeBegin")
action(E.UserInputState.Begin, q)
check(count("ChargeBegin") == beginsBeforeAbsent, "streamed-out scene cannot start another charge")
check(not Mock.Service("Workspace"):FindFirstChild("SpringVaultLocalAim"), "scene stream-out clears local aim")
check(
	not Mock.Service("Workspace"):FindFirstChild("tool_broadwave_effect"),
	"scene stream-out clears wave before its normal expiry"
)
check(not Mock.Service("Workspace"):FindFirstChild("tool_broadwave_charge"), "scene stream-out clears charge dots")
check(not target:FindFirstChildWhichIsA("ProximityPrompt"), "scene stream-out removes owned prompt")
local replacement = new("Model")
replacement.Name = "SpringVaultAdventure"
local replacementTarget = new("Part", replacement)
replacementTarget:SetAttribute("AdventureAction", "Talk")
replacementTarget:SetAttribute("TargetId", "npc_pip")
replacement.Parent = Mock.Service("Workspace")
Mock.Advance(0.05)
check(replacementTarget:FindFirstChildWhichIsA("ProximityPrompt"), "replacement scene installs fresh prompt")
for _ = 1, 50 do
	local repeatedBall = new("Model")
	repeatedBall.Name = "RepeatedBall"
	local contact = new("Part", repeatedBall)
	contact:SetAttribute("AdventureAction", "PushBall")
	contact:SetAttribute("TargetId", "ball")
	repeatedBall.Parent = replacement
	Mock.Advance(0.01)
	check(contact:FindFirstChildWhichIsA("ProximityPrompt"), "new attempt installs ball prompt")
	repeatedBall.Parent = nil
	-- Mock does not propagate ancestor AncestryChanged to descendants as Roblox does.
	Mock.FireEvent(contact, "AncestryChanged", contact, repeatedBall)
	Mock.Advance(0.01)
	check(not contact:FindFirstChildWhichIsA("ProximityPrompt"), "ball removal releases prompt before scene removal")
	contact.Parent = replacement
	Mock.Advance(0.01)
	check(contact:FindFirstChildWhichIsA("ProximityPrompt"), "reloaded target installs exactly one fresh prompt")
	contact:Destroy()
	repeatedBall:Destroy()
end
action(E.UserInputState.Begin, touch1)
Mock.FireEvent(player, "CharacterRemoving", character)
Mock.Advance(0.01)
check(latest() == "ChargeCancel", "character removal cancels held touch")
action(E.UserInputState.Begin, q)
Mock.FireEvent(equip, "Activated")
Mock.Advance(0.01)
check(latest() == "ChargeCancel" and loan.Parent == player.Backpack, "stow cancels held charge")
check(action(E.UserInputState.Begin, l1) == E.ContextActionResult.Pass, "unequipped L1 belongs to other actions")
check(action(E.UserInputState.Begin, touch1) == E.ContextActionResult.Pass, "unequipped touch cannot charge")
local licensed = new("Tool", character)
licensed:SetAttribute("ToolId", "tool_broadwave")
Mock.FireEvent(snapshot, "OnClientEvent", { licensedEquipped = true })
Mock.Advance(0.01)
action(E.UserInputState.Begin, q)
Mock.FireEvent(snapshot, "OnClientEvent", { licensedEquipped = true })
Mock.Advance(0.01)
check(latest() == "ChargeBegin", "licensed snapshot supports charging without review loan membership")
licensed.Parent = nil
action(E.UserInputState.End, q)
check(latest() == "ChargeCancel", "tool replacement before release cancels even without a rendered frame")
Mock.FireEvent(equip, "Activated")
Mock.Advance(0.01)
action(E.UserInputState.Begin, q)
Mock.FireEvent(snapshot, "OnClientEvent", { loanAvailable = false, joined = false })
Mock.Advance(0.01)
check(latest() == "ChargeCancel", "server loan removal cancels held input")
handle.Destroy()
handle.Destroy()
Mock.Advance(0.1)
check(not Mock.Actions.SpringVaultBroadwave and not gui.Parent, "idempotent teardown unbinds action and removes GUI")
check(#Mock.Errors == 0, "no asynchronous client errors: " .. table.concat(Mock.Errors, "; "))
check(
	ball:GetAttribute("BallGeometryMode") == "PrimitiveFallback",
	"unsupported client mesh retains primitive fallback"
)
check(ball.ContactSphere.LocalTransparencyModifier ~= 1, "mesh refusal leaves authority sphere visible")
check(#Mock.Warnings == 1, "unsupported client mesh reports one bounded fallback warning")
check(
	string.find(Mock.Warnings[1], "Spring Vault local ball mesh unavailable; primitive fallback:", 1, true) == 1,
	"fallback is explicit rather than a fake mesh success"
)
print("Spring Vault input: " .. passed .. " checks passed")
