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
local floor = new("Part", scene)
floor.Name = "ProtectedArenaFloor"
floor.Size = Mock.Vector3.new(100, 2, 140)
floor.CFrame = Mock.Env.CFrame.new(0, 0, 0)
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
local productionEquipGui = new("ScreenGui", player.PlayerGui)
productionEquipGui.Name = "Dig_Broadwave"
Mock.Advance(0.01)
check(not equip.Visible, "shared production HUD owns equip presentation without a duplicate control")
Mock.FireEvent(equip, "Activated")
check(loan.Parent == player.Backpack, "review fallback cannot change tools while shared equip owns them")
productionEquipGui:Destroy()
Mock.Advance(0.01)
check(equip.Visible, "dedicated review fallback returns when no shared equip HUD exists")
Mock.FireEvent(equip, "Activated")
Mock.Advance(0.01)
check(loan.Parent == character and equip.Text == "Stow Broadwave", "equip button equips actual owned tool")
local humanoid = character:FindFirstChildOfClass("Humanoid")
action(E.UserInputState.Begin, q)
humanoid.Health = 0
Mock.Advance(0.01)
check(latest() == "ChargeCancel", "death cancels held charge before character removal")
local deathBegins = count("ChargeBegin")
for _, deadInput in { q, l1, touch1 } do
	check(
		action(E.UserInputState.Begin, deadInput) == E.ContextActionResult.Pass,
		"dead avatar cannot own charge input"
	)
end
check(count("ChargeBegin") == deathBegins, "dead avatar sends no charge begin")
humanoid.Health = 100
action(E.UserInputState.Begin, q)
humanoid.Health = 0
check(
	action(E.UserInputState.End, q) == E.ContextActionResult.Pass,
	"death before rendered frame releases input ownership"
)
check(latest() == "ChargeCancel", "death at release cancels instead of releasing work")
humanoid.Health = 100
Mock.Remote.ToServer = {}
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
check(not gui.Panel.Visible, "charging hides card so centered aim hint does not cover it")
check(
	gui.BroadwaveAimHint.Visible and string.find(gui.BroadwaveAimHint.Text, "Ready"),
	"full charge gets readiness cue"
)
action(E.UserInputState.End, input(E.UserInputType.Keyboard, E.KeyCode.Q))
check(latest() == "ChargeRelease" and not preview.Parent, "matching digital input releases and clears preview")
check(gui.Panel.Visible, "release restores the precharge card")
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
-- Permanent production tool works on ordinary sand even when the remote arena streams out.
local licensed = new("Tool", character)
licensed:SetAttribute("ToolId", "tool_broadwave")
licensed:SetAttribute("LicensedBroadwave", true)
loan.Parent = player.Backpack
Mock.FireEvent(snapshot, "OnClientEvent", { licensedEquipped = true, eventInstanceId = "input:1" })
local licensedBegins = count("ChargeBegin")
check(
	action(E.UserInputState.Begin, q) == E.ContextActionResult.Sink,
	"licensed ordinary charge owns Q without streamed arena"
)
check(count("ChargeBegin") == licensedBegins + 1, "licensed ordinary charge begins without streamed arena")
Mock.Advance(0.9)
check(gui.BroadwaveAimHint.Visible, "ordinary charge keeps local aim feedback without arena")
check(not gui.Panel.Visible, "licensed charge without arena keeps adventure panel hidden")
action(E.UserInputState.End, q)
check(latest() == "ChargeRelease", "licensed ordinary charge releases through actual callback")
check(not gui.Panel.Visible, "ordinary release cannot restore arena panel without scene")
licensed:SetAttribute("AdventureLoan", true)
check(
	action(E.UserInputState.Begin, q) == E.ContextActionResult.Pass,
	"loan with licensed markers still requires arena"
)
licensed:Destroy()
loan.Parent = character
check(not Mock.Service("Workspace"):FindFirstChild("SpringVaultLocalAim"), "scene stream-out clears local aim")
check(
	not Mock.Service("Workspace"):FindFirstChild("tool_broadwave_effect"),
	"scene stream-out clears wave before its normal expiry"
)
check(not Mock.Service("Workspace"):FindFirstChild("tool_broadwave_charge"), "scene stream-out clears charge dots")
check(not target:FindFirstChildWhichIsA("ProximityPrompt"), "scene stream-out removes owned prompt")
Mock.FireEvent(effect, "OnClientEvent", {
	kind = "Wave",
	playerUserId = 9511,
	frame = Mock.CFrame.new(0, 3, 6),
})
Mock.Advance(0.05)
check(
	not Mock.Service("Workspace"):FindFirstChild("tool_broadwave_effect"),
	"late network effect cannot recreate geometry while scene is absent"
)
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
-- Representative crowded *mock* workload: simultaneous nearby effect requests and
-- 32 actionable targets. This establishes bounded allocations, not device frame time
-- or uncoached prompt readability, and ancestry reload is not streaming eviction.
local workspace = Mock.Service("Workspace")
local function namedChildren(parent, name)
	local result = {}
	for _, child in parent:GetChildren() do
		if child.Name == name then
			table.insert(result, child)
		end
	end
	return result
end
local crowdedTargets = {}
for index = 1, 32 do
	local part = new("Part")
	part:SetAttribute("AdventureAction", "Talk")
	part:SetAttribute("TargetId", "crowd_" .. index)
	part.Parent = replacement
	table.insert(crowdedTargets, part)
end
Mock.Advance(0.05)
for _, part in crowdedTargets do
	check(#namedChildren(part, "SpringVaultLocalPrompt") == 1, "crowded target owns exactly one prompt")
end
for _ = 1, 48 do
	Mock.FireEvent(effect, "OnClientEvent", { kind = "Wave", playerUserId = 9511, frame = Mock.CFrame.new(0, 3, 6) })
	Mock.FireEvent(effect, "OnClientEvent", { kind = "Bounce", frame = Mock.CFrame.new(0, 3, 6) })
end
Mock.Advance(0.05)
check(#namedChildren(workspace, "tool_broadwave_effect") == 2, "48 nearby wave requests allocate at most two groups")
check(
	#namedChildren(workspace, "landmark_spring_vault_ball_effect") == 1,
	"48 nearby bounce requests allocate one puff group"
)
for _, model in workspace:GetChildren() do
	if model.Name == "tool_broadwave_effect" or model.Name == "landmark_spring_vault_ball_effect" then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				check(
					not part.CanCollide and not part.CanTouch and not part.CanQuery,
					"crowded local effect has no contact/query authority"
				)
			end
		end
	end
end
Mock.Advance(0.7)
check(
	#namedChildren(workspace, "tool_broadwave_effect") == 0
		and #namedChildren(workspace, "landmark_spring_vault_ball_effect") == 0,
	"crowded burst expires fully"
)
Mock.FireEvent(gui:FindFirstChild("Motionon", true), "Activated")
Mock.FireEvent(effect, "OnClientEvent", { kind = "Wave", playerUserId = 9511, frame = Mock.CFrame.new(0, 3, 6) })
Mock.FireEvent(effect, "OnClientEvent", { kind = "Bounce", frame = Mock.CFrame.new(0, 3, 6) })
Mock.Advance(0.05)
local lowWave = workspace:FindFirstChild("tool_broadwave_effect")
local lowPuffs = workspace:FindFirstChild("landmark_spring_vault_ball_effect")
check(
	lowWave.Wave.Size.Y == 0.35 and #namedChildren(lowPuffs, "BouncePuff") == 4,
	"reduced motion uses low wave and four puffs"
)
local lowFrame = lowWave:GetPivot()
Mock.Advance(0.1)
check(lowWave:GetPivot() == lowFrame, "reduced motion wave remains stationary")
Mock.Advance(0.6)
Mock.FireEvent(gui:FindFirstChild("Puffson", true), "Activated")
Mock.FireEvent(effect, "OnClientEvent", { kind = "Bounce", frame = Mock.CFrame.new(0, 3, 6) })
Mock.FireEvent(effect, "OnClientEvent", { kind = "Wave", playerUserId = 9511, frame = Mock.CFrame.new(1000, 3, 6) })
Mock.Advance(0.05)
check(#namedChildren(workspace, "landmark_spring_vault_ball_effect") == 0, "particle reduction omits puff allocations")
check(#namedChildren(workspace, "tool_broadwave_effect") == 0, "distant crowded effects are culled")
for _ = 1, 10 do
	replacement.Parent = nil
	Mock.Advance(0.05)
	check(#replacement:GetDescendants() == #crowdedTargets + 1, "crowded ancestry removal releases every owned prompt")
	replacement.Parent = workspace
	Mock.Advance(0.05)
	check(
		#replacement:GetDescendants() == (#crowdedTargets + 1) * 2,
		"crowded ancestry reload recreates exactly one prompt per target"
	)
end
for _, part in crowdedTargets do
	part:Destroy()
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
