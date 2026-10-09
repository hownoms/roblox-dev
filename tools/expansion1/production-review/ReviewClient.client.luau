--!strict
-- PRODUCTION-INTEGRATION REVIEW ONLY (docs/integration/production-review.md). An on-screen banner
-- with the server review status, and a read-only print of AdventureOutcome payloads. Sends nothing
-- to the server and grants nothing. Never mapped by default.project.json.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BANNER =
	"PRODUCTION-INTEGRATION REVIEW: in-memory saves, review prerequisites; not production eligibility or persistence evidence"
local STATUS = "ProductionIntegrationReview"

local gui = Instance.new("ScreenGui")
gui.Name = "ProductionReviewBanner"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.IgnoreGuiInset = true
local label = Instance.new("TextLabel")
label.Name = "Banner"
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -4)
label.Size = UDim2.new(0.9, 0, 0, 18)
label.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
label.BackgroundTransparency = 0.25
label.TextColor3 = Color3.new(1, 1, 1)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Active = false
label.Parent = gui

local function refresh()
	local status = ReplicatedStorage:GetAttribute(STATUS)
	label.Text = if status == "running"
		then BANNER
		else "PRODUCTION-INTEGRATION REVIEW: " .. tostring(status or "waiting for server")
end
ReplicatedStorage:GetAttributeChangedSignal(STATUS):Connect(refresh)
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
			print(
				"[ProductionReview] AdventureOutcome received (review log): "
					.. (if ok then text else tostring(outcome))
			)
		end)
	end
end)
