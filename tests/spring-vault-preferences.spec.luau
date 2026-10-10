--!nocheck
-- Actual runtime + production State in headless mocks; no device acceptance claim.
local Mock = require("./mock/Roblox")
Mock.Init(require("../build/test/generated"), { Client = true })
local new, V = Mock.Env.Instance.new, Mock.Vector3.new
local player = Mock.AddLocalPlayer(9523, "Preferences")
Mock.SpawnCharacter(player, V(0, 3, 0))
local scene = new("Model", Mock.Service("Workspace"))
scene.Name = "SpringVaultAdventure"
local floor = new("Part", scene)
floor.Name = "ProtectedArenaFloor"
floor.Size = V(100, 2, 140)
floor.CFrame = Mock.Env.CFrame.new()
local ball = new("Model", scene)
ball.Name = "landmark_spring_vault_ball"
local colorPanel = new("Part", ball)
colorPanel.Name = "ColorPanel"
colorPanel.Size = V(4, 4, 4)
local contact = new("Part", ball)
contact.Name = "ContactSphere"
contact.Size = V(8, 8, 8)
local remotes = new("Folder", Mock.Service("ReplicatedStorage"))
for _, name in { "Intent", "Snapshot", "Effect" } do
	new("RemoteEvent", remotes).Name = name
end
local State = Mock.Require(Mock.ByPath["StarterPlayer/StarterPlayerScripts/Client/Controllers/State"])
local Client = Mock.Require(Mock.ByPath["StarterPlayer/StarterPlayerScripts/Client/Adventure/SpringVaultClient"])
local passed = 0
local function check(value, label)
	assert(value, label)
	passed += 1
end
local function settings(motion, graphics)
	State.Apply({ Settings = { ReducedMotion = motion, LowGraphics = graphics } })
end
settings(true, false)
local handle = Client.Start(remotes, scene)
local card = player.PlayerGui.SpringVaultAdventureReview.Panel
check(card.Motionon.Text == "Motion: low", "initial saved reduced motion is applied")
check(card.Puffson.Text == "Puffs: off", "reduced motion also suppresses particles")
settings(false, true)
check(card.Motionon.Text == "Motion: on", "live motion change is applied")
check(card.Puffson.Text == "Puffs: off", "LowGraphics suppresses particles independently")
settings(false, false)
check(card.Motionon.Text == "Motion: on" and card.Puffson.Text == "Puffs: on", "live settings re-enable effects")
local workspace = Mock.Service("Workspace")
local function effect(kind)
	Mock.FireEvent(remotes.Effect, "OnClientEvent", { kind = kind, frame = Mock.Env.CFrame.new() })
	Mock.Advance(0.01)
end
effect("Wave")
check(workspace:FindFirstChild("tool_broadwave_effect") ~= nil, "full graphics creates wave feedback")
settings(true, false)
check(workspace:FindFirstChild("tool_broadwave_effect") == nil, "live reduced motion retires an active effect")
effect("Wave")
effect("Bounce")
check(workspace:FindFirstChild("tool_broadwave_effect") == nil, "saved reduction suppresses future waves")
check(workspace:FindFirstChild("landmark_spring_vault_ball_effect") == nil, "saved reduction suppresses future puffs")
Mock.FireEvent(card.Motionon, "Activated")
Mock.FireEvent(card.Puffson, "Activated")
check(
	card.Motionon.Text == "Motion: on" and card.Puffson.Text == "Puffs: on",
	"session override controls remain usable"
)
check(State.GetSetting("ReducedMotion", false) == true, "session overrides never change saved settings")
settings(true, false)
check(
	card.Motionon.Text == "Motion: low" and card.Puffson.Text == "Puffs: off",
	"next production change resets session overrides"
)
settings(false, false)
Mock.Advance(0.7)
effect("Bounce")
check(colorPanel.Size ~= V(4, 4, 4), "normal motion animates decorative panels")
settings(true, false)
check(colorPanel.Size == V(4, 4, 4), "live reduced motion immediately restores decorative panels")
check(contact.Size == V(8, 8, 8), "contact geometry is unchanged by bounce and preference update")
settings(false, false)
Mock.FireEvent(remotes.Effect, "OnClientEvent", { kind = "Wave", frame = Mock.Env.CFrame.new() })
settings(false, true)
Mock.Advance(0.01)
check(workspace:FindFirstChild("tool_broadwave_effect") == nil, "queued effect cannot escape a live particle change")
settings(true, false)
handle.SetPreferences({ ReducedParticles = false })
check(
	card.Motionon.Text == "Motion: low" and card.Puffson.Text == "Puffs: on",
	"partial preference updates preserve unspecified field"
)
local destroyedMotionText = card.Motionon.Text
local destroyedMotion = card.Motionon
handle.Destroy()
settings(false, false)
check(destroyedMotion.Text == destroyedMotionText, "destroyed runtime no longer receives production settings changes")
handle.SetPreferences({ ReducedMotion = true })
check(
	player.PlayerGui:FindFirstChild("SpringVaultAdventureReview") == nil,
	"destroy unsubscribes and later preference changes stay inert"
)
local controllers = Mock.ByPath["StarterPlayer/StarterPlayerScripts/Client/Controllers"]
local parent = controllers.Parent
controllers.Parent = nil
local review = Client.Start(remotes, scene, { ReducedMotion = true, ReducedParticles = true })
local reviewCard = player.PlayerGui.SpringVaultAdventureReview.Panel
check(
	reviewCard.Motionon.Text == "Motion: low" and reviewCard.Puffson.Text == "Puffs: off",
	"standalone review accepts initial preferences without production State"
)
review.SetPreferences({ ReducedMotion = false, ReducedParticles = false })
check(
	reviewCard.Motionon.Text == "Motion: on" and reviewCard.Puffson.Text == "Puffs: on",
	"standalone handle accepts live preferences"
)
review.Destroy()
controllers.Parent = parent
print("spring-vault-preferences: " .. passed .. " checks passed")
