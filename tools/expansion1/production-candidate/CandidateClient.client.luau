--!strict
-- LOCAL PRODUCTION CANDIDATE ONLY (docs/integration/production-candidate.md). A small
-- non-interactive label with the server's candidate profile, and a read-only log of each
-- AdventureOutcome payload. Sends nothing to the server and grants nothing. Never mapped by
-- default.project.json.
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
	label.Text = if profile == "LocalOnly" then LABEL else "LOCAL CANDIDATE: " .. tostring(profile or "waiting for server")
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
