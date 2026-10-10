--!strict
-- LOCAL PRODUCTION CANDIDATE ONLY (docs/integration/production-candidate.md). A small
-- non-interactive label with the server's candidate profile, a read-only log of each
-- AdventureOutcome payload, and a read-only streaming log for the two-client / stream-out
-- checks (docs/integration/launch-readiness.md): "[Candidate] stream" lines whenever this
-- client's copy of the Spring Vault arena appears, disappears or changes part count
-- by a quarter, and whether the runtime ScreenGui is enabled. Sends nothing to the server and grants
-- nothing. Never mapped by default.project.json.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LABEL = "LOCAL CANDIDATE: in-memory storage only; rewards are local simulation"

local gui = Instance.new("ScreenGui")
gui.Name = "ProductionCandidateLabel"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.IgnoreGuiInset = true
local label = Instance.new("TextLabel")
label.Name = "Label"
label.AnchorPoint = Vector2.new(0, 1)
label.Position = UDim2.new(0, 4, 1, -2)
label.Size = UDim2.new(0, 420, 0, 14)
label.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
label.BackgroundTransparency = 0.3
label.TextColor3 = Color3.new(1, 1, 1)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Active = false
label.Parent = gui

local function refresh()
	local profile = ReplicatedStorage:GetAttribute("CandidateProfile")
	label.Text = if profile == "LocalOnly"
		then LABEL
		else "LOCAL CANDIDATE: " .. tostring(profile or "waiting for server")
end
ReplicatedStorage:GetAttributeChangedSignal("CandidateProfile"):Connect(refresh)
refresh()
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

task.spawn(function()
	local shared = ReplicatedStorage:WaitForChild("Shared", 30)
	local remotes = shared and shared:WaitForChild("Remotes", 30)
	local net = remotes and remotes:WaitForChild("Net", 30)
	local event = net and net:WaitForChild("AdventureOutcome", 30)
	if event and event:IsA("RemoteEvent") then
		event.OnClientEvent:Connect(function(outcome: any)
			local ok, text = pcall(HttpService.JSONEncode, HttpService, outcome)
			print("[Candidate] AdventureOutcome (local simulation): " .. (if ok then text else tostring(outcome)))
		end)
	end
end)

-- Streaming evidence: what THIS client has replicated (the server cannot see it).
task.spawn(function()
	local Workspace = game:GetService("Workspace")
	local player = Players.LocalPlayer
	local lastParts, lastPanel = -1, nil :: boolean?
	while true do
		local scene = Workspace:FindFirstChild("SpringVaultAdventure")
		local parts = 0
		if scene then
			for _, d in scene:GetDescendants() do
				if d:IsA("BasePart") then
					parts += 1
				end
			end
		end
		local playerGui = player:FindFirstChild("PlayerGui")
		local runtimeGui = playerGui and playerGui:FindFirstChild("SpringVaultAdventureReview")
		local panel = runtimeGui ~= nil and runtimeGui:IsA("ScreenGui") and runtimeGui.Enabled
		local changed = (parts == 0) ~= (lastParts <= 0)
			or (lastParts > 0 and math.abs(parts - lastParts) >= math.max(4, lastParts / 4))
			or panel ~= lastPanel
		if changed then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local where = if root and root:IsA("BasePart")
				then string.format("%d,%d,%d", root.Position.X, root.Position.Y, root.Position.Z)
				else "no character"
			print(
				string.format(
					"[Candidate] stream t=%.1f arena parts %d (was %d), runtime gui enabled %s, at %s",
					os.clock(),
					parts,
					math.max(lastParts, 0),
					tostring(panel),
					where
				)
			)
			lastParts, lastPanel = parts, panel
		end
		task.wait(1)
	end
end)
