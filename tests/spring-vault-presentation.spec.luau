--!nocheck
-- Actual client presentation in API-aware mocks, not Studio readability or device acceptance.
local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")
Mock.Init(Generated, { Client = true })
local new, V = Mock.Env.Instance.new, Mock.Vector3.new
local player = Mock.AddLocalPlayer(9520, "Presentation")
Mock.SpawnCharacter(player, V(0, 3, 0))
local scene = new("Model", Mock.Service("Workspace"))
scene.Name = "SpringVaultAdventure"
local targets = {}
local function target(id, action, distance)
	local p = new("Part", scene)
	p.Position = V(distance, 3, 0)
	p:SetAttribute("TargetId", id)
	p:SetAttribute("AdventureAction", action)
	targets[id] = p
end
target("npc_mara", "Talk", 9)
target("npc_pip", "Talk", 8)
target("vault_anchor_1", "Excavate", 1)
target("vault_anchor_2", "Excavate", 2)
target("vault_latch", "OpenVault", 3)
target("route_left", "RouteLeft", 4)
target("route_right", "RouteRight", 5)
target("ball", "PushBall", 1)
target("ball_reset", "ResetBall", 6)
target("adventure_exit", "Leave", 11)
target("trial_target_1", "Excavate", 1)
target("trial_target_2", "Excavate", 2)
local gateLabels = {}
for i = 1, 3 do
	local marker = new("Part", scene)
	marker.Name = "GateMarker" .. i
	gateLabels[i] = new("BillboardGui", marker)
end
local leftDash = new("Part", scene)
leftDash.Name = "RouteDashLeft"
local rightDash = new("Part", scene)
rightDash.Name = "RouteDashRight"
local remotes = new("Folder", Mock.Service("ReplicatedStorage"))
for _, name in { "Intent", "Snapshot", "Effect" } do
	new("RemoteEvent", remotes).Name = name
end
local Client = Mock.Require(Mock.ByPath["StarterPlayer/StarterPlayerScripts/Client/Adventure/SpringVaultClient"])
local handle = Client.Start(remotes, scene)
local gui = player.PlayerGui.SpringVaultAdventureReview
local card = gui.Panel
local passed = 0
local function check(value, message)
	assert(value, message)
	passed += 1
end
local function send(data)
	data.eventInstanceId = data.eventInstanceId or "presentation:1"
	Mock.FireEvent(remotes.Snapshot, "OnClientEvent", data)
	Mock.Advance(0.05)
end
local function prompt(id)
	return targets[id]:FindFirstChildWhichIsA("ProximityPrompt")
end
local function only(id)
	local enabled = 0
	for key in targets do
		if prompt(key).Enabled then
			enabled += 1
			check(key == id, "only intended prompt enabled: " .. id)
		end
	end
	check(enabled == 1, "one nearest valid prompt: " .. id)
end
send({ joined = false, outcomeOwner = "Review" })
local title = card:FindFirstChildWhichIsA("TextLabel")
check(string.find(title.Text, "Dedicated review", 1, true), "dedicated review remains truthfully labelled")
send({ joined = false, outcomeOwner = "External" })
check(title.Text == "SPRING VAULT", "external production header makes no review-only claim")
send({ joined = false })
only("npc_pip")
local tracked = prompt("npc_pip")
local late = new("ProximityPrompt")
late.Name = "AdventurePrompt"
late.Enabled = true
late.Parent = targets.npc_pip
Mock.Advance(0.05)
check(not late.Enabled and tracked.Enabled, "late server prompt cannot compete with selected tracked local prompt")
only("npc_pip")
check(
	card.Join.Visible and not card.Start.Visible and not card.Ready.Visible and not card.Guideball.Visible,
	"invitation shows join without later controls"
)
check(card.CanvasSize.Y.Offset == 348, "controls reserve stable cells and scroll canvas")
check(card.Options.Visible and not card.Motionon.Visible, "options accessible while motion controls stay tucked away")
Mock.FireEvent(card.Options, "Activated")
Mock.Advance(0.05)
check(card.Motionon.Visible and card.Puffson.Visible, "options exposes motion and particles")
Mock.FireEvent(card.Motionon, "Activated")
check(card.Motionon.Text == "Motion: low", "reduced motion can be selected")
Mock.FireEvent(card.Puffson, "Activated")
check(card.Puffson.Text == "Puffs: off", "particle suppression can be selected")
Mock.FireEvent(card.Options, "Activated")
send({ joined = true, phase = "Inviting", isStarter = true, startWaitSeconds = 3 })
only("adventure_exit")
check(
	card.Start.Visible and card.Start.Text == "Begin in 3s" and not card.Join.Visible,
	"joined invitation has contextual start countdown"
)
local function requests(action)
	local count = 0
	for _, request in Mock.Remote.ToServer do
		if request.Name == "Intent" and request.Args[1].action == action then
			count += 1
		end
	end
	return count
end
local beforeStart = requests("Start")
Mock.FireEvent(card.Start, "Activated")
check(requests("Start") == beforeStart, "countdown cannot send an early Begin request")
send({ joined = true, phase = "Inviting", isStarter = false, startWaitSeconds = 3 })
check(not card.Start.Visible, "nonhost never sees a misleading Begin countdown")
send({ joined = true, phase = "Inviting", isStarter = true, canStart = true })
local beforeReady = requests("Ready")
local leavePosition = card.Leave.Position
local startPosition = card.Start.Position
local readyPosition = card.Ready.Position
local canvasHeight = card.CanvasSize.Y.Offset
local function samePosition(a, b)
	return a.X.Scale == b.X.Scale and a.X.Offset == b.X.Offset and a.Y.Offset == b.Y.Offset
end
Mock.FireEvent(card.Start, "Activated")
check(requests("Start") == beforeStart + 1, "Begin uses ordinary Activated request")
send({ joined = true, phase = "Preparing", stage = "anchors", canReady = true })
check(requests("Ready") == beforeReady + 1, "accepted Begin confirms readiness after preparation snapshot")
check(samePosition(card.Leave.Position, leavePosition), "Leave stays in its reserved cell after Begin")
check(not samePosition(card.Leave.Position, startPosition), "second Begin click cannot land on Leave")
check(card.CanvasSize.Y.Offset == canvasHeight, "Begin transition cannot clamp scroll and shift controls")
send({ joined = true, phase = "Preparing", stage = "anchors", canReady = true })
check(requests("Ready") == beforeReady + 1, "repeated snapshot cannot repeat readiness")
send({ joined = true, phase = "Inviting", isStarter = true, canStart = true })
Mock.FireEvent(card.Start, "Activated")
send({ joined = true, phase = "Preparing", canReady = true, eventInstanceId = "presentation:replacement" })
check(requests("Ready") == beforeReady + 1, "Begin cannot confirm readiness for a replacement attempt")
send({ joined = true, phase = "Active", stage = "anchors", canReady = true, ready = false })
only("adventure_exit")
check(
	card.Ready.Visible and not card.Start.Visible and not card.Guideball.Visible,
	"unready player sees ready without late actions"
)
send({
	joined = true,
	phase = "Active",
	stage = "anchors",
	ready = true,
	Anchors = {
		vault_anchor_1 = { Work = 2, Required = 6, Completed = false },
		vault_anchor_2 = {
			Work = 0,
			Required = 6,
			Completed = false,
		},
	},
})
only("vault_anchor_1")
check(samePosition(card.Leave.Position, leavePosition), "Leave stays in its reserved cell after Ready")
check(not samePosition(card.Leave.Position, readyPosition), "second Ready click cannot land on Leave")
check(card.Leave.Visible, "Leave remains immediately accessible after readiness")
local beforeLeave = requests("Leave")
Mock.FireEvent(card.Leave, "Activated")
check(requests("Leave") == beforeLeave + 1, "reserved Leave retains immediate cancellation")
check(prompt("vault_anchor_1").ActionText == "Scoop · 2/6", "nearest shaped anchor shows authoritative count")
send({
	joined = true,
	phase = "Active",
	stage = "anchors",
	ready = true,
	Anchors = {
		vault_anchor_1 = { Work = 6, Required = 6, Completed = true },
		vault_anchor_2 = {
			Work = 0,
			Required = 6,
			Completed = false,
		},
	},
})
only("vault_anchor_2")
send({ joined = true, phase = "Active", stage = "vault", ready = true, routeSelectable = true, route = "Right" })
only("vault_latch")
check(
	card.Leftroute.Visible and card.Rightroute.Visible and card.Rightroute.Text == "Selected: Right",
	"route controls show selected branch"
)
send({ joined = true, phase = "Active", stage = "ball", ready = true, hauling = false })
only("ball")
check(
	prompt("ball").ActionText == "Attach and guide" and card.Guideball.Visible,
	"ball attachment invitation is explicit"
)
send({ joined = true, phase = "Active", stage = "ball", ready = true, hauling = true })
only("ball")
check(
	prompt("ball").ActionText == "Release ball" and card.Guideball.Text == "Release ball",
	"hauling presents release action"
)
check(
	not card.Join.Visible and not card.Start.Visible and not card.Ready.Visible,
	"haul stage hides previous stage controls"
)
send({ joined = true, phase = "Active", stage = "ball", ready = true, route = "Right", GateIndex = 1 })
check(
	not gateLabels[1].Enabled and gateLabels[2].Enabled and not gateLabels[3].Enabled,
	"only next gate label competes for attention"
)
check(leftDash.Transparency == 0.7 and rightDash.Transparency == 0, "selected route receives strongest floor cue")
Mock.FireEvent(
	remotes.Effect,
	"OnClientEvent",
	{ kind = "Gate", position = V(0, 3, 0), message = "Continue to gate 2." }
)
Mock.Advance(0.05)
local feedback
for _, child in card:GetChildren() do
	if child:IsA("TextLabel") and string.find(child.Text, "checkpoint saved", 1, true) then
		feedback = child
	end
end
check(feedback ~= nil, "gate success gives visible checkpoint feedback")
send({ joined = true, phase = "Active", stage = "ball", ready = true, route = "Right", GateIndex = 1 })
check(
	string.find(feedback.Text, "checkpoint saved", 1, true),
	"routine snapshot does not immediately erase gate confirmation"
)
send({ joined = false, trialActive = true, trialWave = false, trialComplete = false, trialTargets = {} })
check(card.Leave.Visible and card.Leave.Text == "End trial", "optional practice has an explicit exit")
local beforeLeave = requests("Leave")
Mock.FireEvent(card.Leave, "Activated")
check(requests("Leave") == beforeLeave + 1, "End trial uses the existing validated Leave action")
check(
	not prompt("trial_target_1").Enabled and not prompt("trial_target_2").Enabled,
	"trial scoops stay hidden before accepted wave"
)
send({
	joined = false,
	trialActive = true,
	trialWave = true,
	trialComplete = false,
	trialTargets = {
		trial_target_1 = true,
	},
})
only("trial_target_2")
send({ joined = false, trialActive = true, trialWave = true, trialComplete = true })
only("npc_pip")
check(gui.Panel.Join.Visible, "optional trial still allows joining beside Mara")
check(gui.Panel.AnchorPoint.X == 0.5, "compact panel stays clear of chat at top center")
send({ joined = true, phase = "Resolving", stage = "complete", objective = "Ball rescued · 3/3 gates." })
send({ joined = false, phase = "Dormant", stage = "Optional", objective = "Talk to Mara." })
local endingVisible = false
for _, child in card:GetChildren() do
	if child:IsA("TextLabel") and string.find(child.Text, "Rescue complete", 1, true) then
		endingVisible = true
	end
end
check(endingVisible, "automatic safe return retains the ending instead of replacing it with arrival instructions")
handle.Destroy()
check(#Mock.Errors == 0, "no asynchronous mock errors")
print("Spring Vault presentation mock: " .. passed .. " checks passed")
